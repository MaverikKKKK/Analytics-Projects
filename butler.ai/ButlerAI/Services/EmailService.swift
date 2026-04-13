import Foundation

// MARK: - Gmail Service

@MainActor
final class EmailService: ObservableObject {

    static let shared = EmailService()

    @Published var isConnected = false
    @Published var lastError: String?

    private var accessToken: String {
        UserDefaults.standard.string(forKey: Constants.Storage.gmailAccessTokenKey) ?? ""
    }

    private var refreshToken: String {
        UserDefaults.standard.string(forKey: Constants.Storage.gmailRefreshTokenKey) ?? ""
    }

    private var lastHistoryId: String = "0"

    // MARK: - API Request

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard !accessToken.isEmpty else { throw EmailError.notAuthenticated }

        var components = URLComponents(string: "\(Constants.API.gmailBaseURL)/\(path)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                // Token expired - attempt refresh
                try await refreshAccessToken()
                throw EmailError.tokenExpired
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw EmailError.httpError(httpResponse.statusCode)
            }
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else { throw EmailError.notAuthenticated }

        var request = URLRequest(url: URL(string: Constants.API.googleOAuthURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Note: In production, client_id and client_secret would be loaded from a config file
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

        UserDefaults.standard.set(tokenResponse.accessToken, forKey: Constants.Storage.gmailAccessTokenKey)
        isConnected = true
    }

    // MARK: - Save Tokens (called after OAuth flow completes)

    func saveTokens(accessToken: String, refreshToken: String) {
        UserDefaults.standard.set(accessToken, forKey: Constants.Storage.gmailAccessTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: Constants.Storage.gmailRefreshTokenKey)
        isConnected = true
    }

    // MARK: - Fetch Unread Emails

    func fetchUnreadEmails(maxResults: Int = 20) async throws -> [NotificationItem] {
        let listResponse: GmailListResponse = try await request(
            path: "users/me/messages",
            queryItems: [
                URLQueryItem(name: "q", value: "is:unread"),
                URLQueryItem(name: "maxResults", value: "\(maxResults)")
            ]
        )

        guard let messageRefs = listResponse.messages, !messageRefs.isEmpty else {
            return []
        }

        var notifications: [NotificationItem] = []

        // Fetch metadata for each message
        await withTaskGroup(of: NotificationItem?.self) { group in
            for ref in messageRefs.prefix(20) {
                group.addTask {
                    try? await self.fetchMessageMetadata(id: ref.id)
                }
            }

            for await notification in group {
                if let notification = notification {
                    notifications.append(notification)
                }
            }
        }

        return notifications.sorted { $0.receivedAt > $1.receivedAt }
    }

    // MARK: - Fetch Message Metadata

    private func fetchMessageMetadata(id: String) async throws -> NotificationItem {
        let message: GmailMessage = try await request(
            path: "users/me/messages/\(id)",
            queryItems: [
                URLQueryItem(name: "format", value: "metadata"),
                URLQueryItem(name: "metadataHeaders", value: "Subject"),
                URLQueryItem(name: "metadataHeaders", value: "From"),
                URLQueryItem(name: "metadataHeaders", value: "Date")
            ]
        )

        return message.toNotificationItem
    }

    // MARK: - Fetch Full Message Body

    func fetchFullMessageBody(id: String) async throws -> String {
        let message: GmailMessage = try await request(
            path: "users/me/messages/\(id)",
            queryItems: [URLQueryItem(name: "format", value: "full")]
        )

        return message.extractBody()
    }

    // MARK: - Check Connection

    func checkConnection() async -> Bool {
        do {
            let _: GmailProfileResponse = try await request(path: "users/me/profile")
            isConnected = true
            return true
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            return false
        }
    }
}

// MARK: - Gmail API Response Models

struct GmailListResponse: Codable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let internalDate: String?
    let payload: GmailPayload?

    var toNotificationItem: NotificationItem {
        let date: Date
        if let ms = Double(internalDate ?? "0") {
            date = Date(timeIntervalSince1970: ms / 1000)
        } else {
            date = Date()
        }

        return NotificationItem(
            source: .email,
            sourceMessageID: id,
            sender: payload?.senderDisplayName ?? "Unknown",
            title: payload?.subject ?? "New Email",
            body: snippet ?? "",
            receivedAt: date
        )
    }

    func extractBody() -> String {
        guard let payload = payload else { return snippet ?? "" }
        return extractText(from: payload) ?? snippet ?? ""
    }

    private func extractText(from payload: GmailPayload) -> String? {
        // Direct body
        if let body = payload.body, let data = body.data {
            return decodeBase64URL(data)
        }
        // Multipart
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain", let body = part.body, let data = body.data {
                    return decodeBase64URL(data)
                }
            }
        }
        return nil
    }

    private func decodeBase64URL(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct GmailPayload: Codable {
    let mimeType: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?

    var subject: String? {
        headers?.first(where: { $0.name.lowercased() == "subject" })?.value
    }

    var from: String? {
        headers?.first(where: { $0.name.lowercased() == "from" })?.value
    }

    var senderDisplayName: String? {
        guard let from = from else { return nil }
        if let range = from.range(of: "<") {
            return String(from[from.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\"")))
        }
        return from
    }
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailBody: Codable {
    let size: Int?
    let data: String?
}

struct GmailProfileResponse: Codable {
    let emailAddress: String?
    let messagesTotal: Int?
}

struct GoogleTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Errors

enum EmailError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Gmail is not connected. Please sign in via Settings."
        case .tokenExpired:
            return "Gmail session expired. Please reconnect."
        case .httpError(let code):
            return "Gmail API error (HTTP \(code))."
        case .parseError:
            return "Failed to parse email data."
        }
    }
}
