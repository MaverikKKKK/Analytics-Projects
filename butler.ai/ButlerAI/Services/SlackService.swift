import Foundation

// MARK: - Slack Service

@MainActor
final class SlackService: ObservableObject {

    static let shared = SlackService()

    @Published var isConnected = false
    @Published var channels: [SlackChannel] = []
    @Published var lastError: String?

    private var botToken: String {
        UserDefaults.standard.string(forKey: Constants.Storage.slackTokenKey) ?? ""
    }

    private var lastMessageTimestamp: String = "0"

    // MARK: - API Requests

    private func request<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        guard !botToken.isEmpty else { throw SlackError.missingToken }

        var components = URLComponents(string: "\(Constants.API.slackBaseURL)/\(endpoint)")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SlackError.httpError
        }

        let decoded = try JSONDecoder().decode(T.self, from: data)
        return decoded
    }

    // MARK: - Authentication Test

    func testConnection() async -> Bool {
        do {
            let response: SlackAuthTestResponse = try await request(endpoint: "auth.test")
            isConnected = response.ok
            if !response.ok {
                lastError = response.error
            }
            return response.ok
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Fetch Channels

    func fetchChannels() async throws {
        let response: SlackChannelsResponse = try await request(
            endpoint: "conversations.list",
            params: ["types": "public_channel,private_channel,im", "limit": "100"]
        )

        if response.ok {
            channels = response.channels ?? []
        } else {
            throw SlackError.apiError(response.error ?? "Unknown error")
        }
    }

    // MARK: - Fetch New Messages

    func fetchNewMessages(since timestamp: String = "0") async throws -> [NotificationItem] {
        var notifications: [NotificationItem] = []

        // Fetch messages from all joined channels
        let targetChannels = channels.filter { $0.isMember == true }.prefix(5)

        for channel in targetChannels {
            do {
                let response: SlackHistoryResponse = try await request(
                    endpoint: "conversations.history",
                    params: [
                        "channel": channel.id,
                        "oldest": timestamp,
                        "limit": "10",
                        "inclusive": "false"
                    ]
                )

                if response.ok, let messages = response.messages {
                    for msg in messages {
                        // Skip bot messages
                        guard msg.subtype == nil || msg.subtype == "bot_message" else { continue }

                        var notification = NotificationItem(
                            source: .slack,
                            sourceMessageID: msg.ts,
                            sender: msg.username ?? msg.user ?? "Unknown",
                            title: "#\(channel.name ?? channel.id)",
                            body: msg.text,
                            channel: channel.name,
                            receivedAt: Date(timeIntervalSince1970: Double(msg.ts) ?? Date().timeIntervalSince1970)
                        )

                        // Resolve username if needed
                        if let userId = msg.user, notification.sender == userId {
                            if let name = await resolveUsername(userId: userId) {
                                notification.sender = name
                            }
                        }

                        notifications.append(notification)
                    }
                }
            } catch {
                // Continue with other channels if one fails
                continue
            }
        }

        return notifications.sorted { $0.receivedAt > $1.receivedAt }
    }

    // MARK: - Resolve Username

    private func resolveUsername(userId: String) async -> String? {
        do {
            let response: SlackUserInfoResponse = try await request(
                endpoint: "users.info",
                params: ["user": userId]
            )
            return response.user?.profile?.displayName ?? response.user?.realName
        } catch {
            return nil
        }
    }

    // MARK: - Fetch DMs

    func fetchDirectMessages() async throws -> [NotificationItem] {
        let response: SlackChannelsResponse = try await request(
            endpoint: "conversations.list",
            params: ["types": "im", "limit": "20"]
        )

        guard response.ok, let dmChannels = response.channels else {
            throw SlackError.apiError(response.error ?? "Unknown error")
        }

        var notifications: [NotificationItem] = []
        for channel in dmChannels.prefix(5) {
            let history: SlackHistoryResponse = try await request(
                endpoint: "conversations.history",
                params: ["channel": channel.id, "limit": "5"]
            )

            if history.ok, let messages = history.messages {
                for msg in messages.prefix(3) {
                    notifications.append(NotificationItem(
                        source: .slack,
                        sourceMessageID: msg.ts,
                        sender: msg.username ?? "Direct Message",
                        title: "Direct Message",
                        body: msg.text,
                        receivedAt: Date(timeIntervalSince1970: Double(msg.ts) ?? Date().timeIntervalSince1970)
                    ))
                }
            }
        }
        return notifications
    }
}

// MARK: - Slack API Response Models

struct SlackAuthTestResponse: Codable {
    let ok: Bool
    let error: String?
    let team: String?
    let user: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case ok, error, team, user
        case userId = "user_id"
    }
}

struct SlackChannelsResponse: Codable {
    let ok: Bool
    let error: String?
    let channels: [SlackChannel]?
}

struct SlackChannel: Codable, Identifiable {
    let id: String
    let name: String?
    let isMember: Bool?
    let isIm: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isMember = "is_member"
        case isIm = "is_im"
    }
}

struct SlackHistoryResponse: Codable {
    let ok: Bool
    let error: String?
    let messages: [SlackHistoryMessage]?
}

struct SlackHistoryMessage: Codable {
    let ts: String
    let user: String?
    let username: String?
    let text: String
    let subtype: String?
}

struct SlackUserInfoResponse: Codable {
    let ok: Bool
    let user: SlackUserDetail?
}

struct SlackUserDetail: Codable {
    let id: String?
    let realName: String?
    let profile: SlackUserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case realName = "real_name"
        case profile
    }
}

struct SlackUserProfile: Codable {
    let displayName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
    }
}

// MARK: - Errors

enum SlackError: LocalizedError {
    case missingToken
    case httpError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Slack bot token is not configured. Please add it in Settings."
        case .httpError:
            return "Network error connecting to Slack."
        case .apiError(let msg):
            return "Slack API error: \(msg)"
        }
    }
}
