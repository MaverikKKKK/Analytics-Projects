import Foundation

// MARK: - Notification Item

struct NotificationItem: Identifiable, Codable, Equatable {
    var id: UUID
    var source: NotificationSource
    var sourceMessageID: String        // Unique ID from the source system
    var sender: String
    var senderAvatar: String?          // URL or initials
    var title: String
    var body: String
    var channel: String?               // Slack channel, email thread, etc.
    var receivedAt: Date
    var isRead: Bool
    var isProcessed: Bool              // Whether AI has processed this
    var extractedTaskID: UUID?         // If a task was created from this
    var rawPayload: [String: String]?  // Original data from API

    init(
        id: UUID = UUID(),
        source: NotificationSource,
        sourceMessageID: String = UUID().uuidString,
        sender: String,
        senderAvatar: String? = nil,
        title: String,
        body: String,
        channel: String? = nil,
        receivedAt: Date = Date(),
        isRead: Bool = false,
        isProcessed: Bool = false,
        extractedTaskID: UUID? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceMessageID = sourceMessageID
        self.sender = sender
        self.senderAvatar = senderAvatar
        self.title = title
        self.body = body
        self.channel = channel
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.isProcessed = isProcessed
        self.extractedTaskID = extractedTaskID
    }

    var initials: String {
        let parts = sender.components(separatedBy: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        return (first + last).uppercased()
    }

    var hasTask: Bool { extractedTaskID != nil }
}

// MARK: - Slack Message

struct SlackMessage: Codable {
    let ts: String
    let user: String?
    let text: String
    let channel: String?
    let username: String?

    var toNotificationItem: NotificationItem {
        let timestamp = Double(ts) ?? Date().timeIntervalSince1970
        return NotificationItem(
            source: .slack,
            sourceMessageID: ts,
            sender: username ?? user ?? "Unknown",
            title: "Slack Message",
            body: text,
            channel: channel,
            receivedAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}

// MARK: - Email Message

struct EmailMessage: Codable {
    let id: String
    let threadId: String
    let snippet: String
    let payload: EmailPayload?
    let internalDate: String?

    struct EmailPayload: Codable {
        let headers: [EmailHeader]?

        var subject: String? {
            headers?.first(where: { $0.name.lowercased() == "subject" })?.value
        }
        var from: String? {
            headers?.first(where: { $0.name.lowercased() == "from" })?.value
        }
        var senderName: String? {
            guard let from = from else { return nil }
            // Parse "Name <email@example.com>" format
            if let range = from.range(of: "<") {
                return String(from[from.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return from
        }
    }

    struct EmailHeader: Codable {
        let name: String
        let value: String
    }

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
            sender: payload?.senderName ?? "Unknown",
            title: payload?.subject ?? "New Email",
            body: snippet,
            receivedAt: date
        )
    }
}

// MARK: - Sample Data

extension NotificationItem {
    static var samples: [NotificationItem] {
        [
            NotificationItem(
                source: .slack,
                sender: "John Smith",
                title: "#engineering",
                body: "Hey, can someone review my PR before EOD? It's blocking the release.",
                channel: "#engineering",
                receivedAt: Date().addingTimeInterval(-900)
            ),
            NotificationItem(
                source: .email,
                sender: "Sarah Johnson",
                title: "Q4 Report - Needs Review",
                body: "Hi, I've attached the Q4 report. Please review and send feedback ASAP as the board meeting is tomorrow.",
                receivedAt: Date().addingTimeInterval(-1800)
            ),
            NotificationItem(
                source: .whatsApp,
                sender: "Mom",
                title: "WhatsApp",
                body: "Can you pick up milk and bread on your way home? Also we need eggs.",
                receivedAt: Date().addingTimeInterval(-3600)
            ),
            NotificationItem(
                source: .sms,
                sender: "Dr. Miller's Office",
                title: "Appointment Reminder",
                body: "This is a reminder for your appointment tomorrow at 2:00 PM. Reply CONFIRM or CANCEL.",
                receivedAt: Date().addingTimeInterval(-7200)
            ),
            NotificationItem(
                source: .slack,
                sender: "Alex Chen",
                title: "#general",
                body: "All-hands meeting moved to 3 PM today. Please update your calendars.",
                channel: "#general",
                receivedAt: Date().addingTimeInterval(-300),
                isProcessed: true
            )
        ]
    }
}
