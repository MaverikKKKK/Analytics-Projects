import Foundation
import SwiftUI

// MARK: - Enums

enum TaskPriority: String, Codable, CaseIterable {
    case urgent = "Urgent"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.circle.fill"
        case .high: return "arrow.up.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case work = "Work"
    case personal = "Personal"
    case health = "Health"
    case finance = "Finance"
    case other = "Other"

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .finance: return "dollarsign.circle.fill"
        case .other: return "tag.fill"
        }
    }
}

enum TaskStatus: String, Codable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case snoozed = "Snoozed"
    case cancelled = "Cancelled"
}

enum NotificationSource: String, Codable, CaseIterable {
    case slack = "Slack"
    case whatsApp = "WhatsApp"
    case email = "Email"
    case sms = "SMS"
    case manual = "Manual"

    var icon: String {
        switch self {
        case .slack: return "message.fill"
        case .whatsApp: return "phone.bubble.left.fill"
        case .email: return "envelope.fill"
        case .sms: return "bubble.left.fill"
        case .manual: return "pencil.circle.fill"
        }
    }

    var displayName: String { rawValue }
}

// MARK: - Task Model

struct ButlerTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var category: TaskCategory
    var status: TaskStatus
    var source: NotificationSource
    var sourceID: String?              // Original message/notification ID
    var scheduledDate: Date?
    var scheduledTime: Date?
    var dueDate: Date?
    var estimatedDuration: Int?        // Minutes
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var isAIGenerated: Bool
    var originalMessage: String?       // The raw message that triggered this task

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        priority: TaskPriority = .medium,
        category: TaskCategory = .work,
        status: TaskStatus = .pending,
        source: NotificationSource = .manual,
        sourceID: String? = nil,
        scheduledDate: Date? = nil,
        scheduledTime: Date? = nil,
        dueDate: Date? = nil,
        estimatedDuration: Int? = nil,
        tags: [String] = [],
        isAIGenerated: Bool = false,
        originalMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.status = status
        self.source = source
        self.sourceID = sourceID
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isAIGenerated = isAIGenerated
        self.originalMessage = originalMessage
    }

    var isOverdue: Bool {
        guard let due = dueDate, status != .completed else { return false }
        return due < Date()
    }

    var isScheduledToday: Bool {
        guard let scheduled = scheduledDate else { return false }
        return Calendar.current.isDateInToday(scheduled)
    }

    var timeDisplay: String? {
        guard let time = scheduledTime else { return nil }
        return time.formatted(date: .omitted, time: .shortened)
    }

    mutating func markComplete() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    mutating func snooze(until date: Date) {
        status = .snoozed
        scheduledDate = date
        updatedAt = Date()
    }
}

// MARK: - Sample Data
extension ButlerTask {
    static var samples: [ButlerTask] {
        [
            ButlerTask(
                title: "Review Q4 report from Sarah",
                description: "Sarah sent the quarterly report for review. Need to provide feedback by EOD.",
                priority: .urgent,
                category: .work,
                source: .email,
                dueDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()),
                estimatedDuration: 45,
                isAIGenerated: true,
                originalMessage: "Hey, please review the Q4 report I attached and get back to me ASAP"
            ),
            ButlerTask(
                title: "Team standup - discuss sprint blockers",
                description: "John mentioned blockers in Slack that need to be addressed in standup.",
                priority: .high,
                category: .work,
                source: .slack,
                scheduledDate: Date(),
                scheduledTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()),
                estimatedDuration: 30,
                isAIGenerated: true
            ),
            ButlerTask(
                title: "Schedule dentist appointment",
                description: "Reminder from personal calendar - overdue for 6-month checkup",
                priority: .medium,
                category: .health,
                source: .manual,
                estimatedDuration: 15
            ),
            ButlerTask(
                title: "Reply to client proposal",
                description: "Client is waiting on revised proposal with updated pricing.",
                priority: .high,
                category: .work,
                source: .email,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                estimatedDuration: 60,
                isAIGenerated: true
            ),
            ButlerTask(
                title: "Pick up groceries",
                description: "Mom texted asking to grab groceries on the way home",
                priority: .low,
                category: .personal,
                source: .sms,
                estimatedDuration: 30,
                isAIGenerated: true
            )
        ]
    }
}
