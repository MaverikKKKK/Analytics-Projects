import Foundation

// MARK: - Time Block

struct TimeBlock: Identifiable, Codable, Equatable {
    var id: UUID
    var taskID: UUID?
    var title: String
    var startTime: Date
    var endTime: Date
    var category: TaskCategory
    var isFocusTime: Bool
    var isBreak: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        title: String,
        startTime: Date,
        endTime: Date,
        category: TaskCategory = .work,
        isFocusTime: Bool = false,
        isBreak: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.isFocusTime = isFocusTime
        self.isBreak = isBreak
        self.note = note
    }

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var timeRangeDisplay: String {
        "\(startTime.shortTimeString) – \(endTime.shortTimeString)"
    }

    var isCurrentBlock: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }

    var isPast: Bool {
        endTime < Date()
    }
}

// MARK: - Day Plan

struct DayPlan: Identifiable, Codable {
    var id: UUID
    var date: Date
    var blocks: [TimeBlock]
    var aiSummary: String?
    var totalFocusMinutes: Int
    var totalBreakMinutes: Int
    var createdAt: Date
    var lastUpdatedAt: Date
    var isAIGenerated: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        blocks: [TimeBlock] = [],
        aiSummary: String? = nil,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.date = date
        self.blocks = blocks
        self.aiSummary = aiSummary
        self.totalFocusMinutes = blocks.filter { $0.isFocusTime }.reduce(0) { $0 + $1.durationMinutes }
        self.totalBreakMinutes = blocks.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes }
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.isAIGenerated = isAIGenerated
    }

    var currentBlock: TimeBlock? {
        blocks.first { $0.isCurrentBlock }
    }

    var nextBlock: TimeBlock? {
        blocks.first { $0.startTime > Date() }
    }

    var completionPercentage: Double {
        guard !blocks.isEmpty else { return 0 }
        let now = Date()
        let past = blocks.filter { $0.endTime <= now }.count
        return Double(past) / Double(blocks.count)
    }

    mutating func addBlock(_ block: TimeBlock) {
        blocks.append(block)
        blocks.sort { $0.startTime < $1.startTime }
        lastUpdatedAt = Date()
    }

    mutating func removeBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        lastUpdatedAt = Date()
    }
}

// MARK: - Day Plan Builder

struct DayPlanBuilder {
    static func buildFromTasks(_ tasks: [ButlerTask], for date: Date = Date()) -> DayPlan {
        var blocks: [TimeBlock] = []
        let calendar = Calendar.current

        // Morning review block
        let morningStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
        let morningEnd = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!
        blocks.append(TimeBlock(
            title: "Morning Review",
            startTime: morningStart,
            endTime: morningEnd,
            isFocusTime: false,
            isBreak: false,
            note: "Check emails, Slack, and plan the day"
        ))

        // Sort tasks by priority
        let sortedTasks = tasks
            .filter { $0.status == .pending || $0.status == .inProgress }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }

        // Schedule tasks starting at 9 AM
        var currentTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let lunchStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let lunchEnd = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!
        var lunchAdded = false

        for task in sortedTasks.prefix(6) {
            let duration = task.estimatedDuration ?? 30
            let endTime = currentTime.addingTimeInterval(TimeInterval(duration * 60))

            // Add lunch if needed
            if !lunchAdded && currentTime >= lunchStart {
                blocks.append(TimeBlock(
                    title: "Lunch Break",
                    startTime: lunchStart,
                    endTime: lunchEnd,
                    isBreak: true
                ))
                lunchAdded = true
                currentTime = lunchEnd
            }

            // Skip to after lunch if block would overlap
            if currentTime < lunchStart && endTime > lunchStart {
                blocks.append(TimeBlock(
                    title: "Lunch Break",
                    startTime: lunchStart,
                    endTime: lunchEnd,
                    isBreak: true
                ))
                lunchAdded = true
                currentTime = lunchEnd
            }

            blocks.append(TimeBlock(
                taskID: task.id,
                title: task.title,
                startTime: currentTime,
                endTime: endTime,
                category: task.category,
                isFocusTime: true
            ))

            // 10-minute break between focus blocks
            currentTime = endTime.addingTimeInterval(10 * 60)
        }

        if !lunchAdded {
            blocks.append(TimeBlock(
                title: "Lunch Break",
                startTime: lunchStart,
                endTime: lunchEnd,
                isBreak: true
            ))
        }

        var plan = DayPlan(date: date, blocks: blocks, isAIGenerated: true)
        plan.totalFocusMinutes = blocks.filter { $0.isFocusTime }.reduce(0) { $0 + $1.durationMinutes }
        plan.totalBreakMinutes = blocks.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes }
        return plan
    }
}
