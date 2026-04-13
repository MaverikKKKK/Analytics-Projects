import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    var attachedTaskIDs: [UUID]    // Tasks created/modified in this message
    var isError: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        attachedTaskIDs: [UUID] = [],
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.attachedTaskIDs = attachedTaskIDs
        self.isError = isError
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}

// MARK: - Claude API Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case stream
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }

    var text: String {
        content.compactMap { $0.text }.joined()
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
}

// MARK: - Streaming Event

struct ClaudeStreamEvent: Codable {
    let type: String
    let index: Int?
    let delta: ClaudeDelta?
    let message: ClaudeResponse?
}

struct ClaudeDelta: Codable {
    let type: String?
    let text: String?
}

// MARK: - Sample Data

extension ChatMessage {
    static var sampleConversation: [ChatMessage] {
        [
            ChatMessage(
                role: .assistant,
                content: "Good morning! I'm Butler, your AI personal assistant. I've processed your morning notifications and found **5 tasks** that need your attention today.\n\n• 🔴 **Urgent**: Review Q4 report from Sarah (due in 3hrs)\n• 🟠 **High**: Reply to client proposal\n• 🟡 **Medium**: Team standup at 10 AM\n\nShall I plan your day around these priorities?"
            ),
            ChatMessage(
                role: .user,
                content: "Yes, plan my day. Also add a task to call the bank about my account."
            ),
            ChatMessage(
                role: .assistant,
                content: "I've created the bank call task and planned your day:\n\n**8:00 AM** - Review emails & Slack (15 min)\n**9:00 AM** - Review Q4 report from Sarah (45 min)\n**10:00 AM** - Team standup (30 min)\n**11:00 AM** - Reply to client proposal (60 min)\n**12:00 PM** - Lunch break\n**2:00 PM** - Call bank about account (20 min)\n**3:00 PM** - Free time / catch up\n\nI've scheduled your tasks based on priority and energy levels. The bank is open 9-5, so 2 PM works well. Anything else to adjust?",
                attachedTaskIDs: [UUID()]
            )
        ]
    }
}
