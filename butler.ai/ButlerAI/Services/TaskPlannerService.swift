import Foundation

// MARK: - Task Planner Service

/// Orchestrates the full pipeline: fetch messages → extract tasks → plan day
@MainActor
final class TaskPlannerService: ObservableObject {

    static let shared = TaskPlannerService()

    @Published var isProcessing = false
    @Published var lastProcessedAt: Date?
    @Published var processingStatus: String = ""

    private let claude = ClaudeService.shared
    private let slack = SlackService.shared
    private let email = EmailService.shared
    private let notificationMonitor = NotificationMonitor.shared

    // MARK: - Full Sync & Process

    /// Main entry point: fetch all sources, extract tasks, build day plan
    func syncAndProcess() async throws -> (tasks: [ButlerTask], plan: DayPlan) {
        isProcessing = true
        defer { isProcessing = false }

        var allNotifications: [NotificationItem] = []

        // 1. Fetch from all connected sources in parallel
        processingStatus = "Fetching messages..."

        async let slackMessages = fetchSlackMessages()
        async let emailMessages = fetchEmailMessages()

        let (slackResult, emailResult) = await (slackMessages, emailMessages)
        allNotifications.append(contentsOf: slackResult)
        allNotifications.append(contentsOf: emailResult)

        // 2. Add captured iOS notifications (SMS/WhatsApp)
        let iosNotifications = notificationMonitor.capturedNotifications.filter { !$0.isProcessed }
        allNotifications.append(contentsOf: iosNotifications)

        // 3. Filter to only "actionable" messages (keyword pre-filter to save API calls)
        let actionable = allNotifications.filter { isActionable($0) }

        processingStatus = "Extracting tasks with AI..."

        // 4. Extract tasks using Claude
        var newTasks: [ButlerTask] = []
        if !actionable.isEmpty {
            do {
                newTasks = try await claude.extractTasks(from: actionable)
            } catch {
                // If extraction fails, create basic tasks from messages
                newTasks = createFallbackTasks(from: actionable)
            }
        }

        processingStatus = "Planning your day..."

        // 5. Mark iOS notifications as processed
        for notification in iosNotifications {
            notificationMonitor.markAsProcessed(id: notification.id)
        }

        // 6. Build day plan
        let plan = DayPlanBuilder.buildFromTasks(newTasks)

        lastProcessedAt = Date()
        processingStatus = "Done"

        return (newTasks, plan)
    }

    // MARK: - Individual Source Fetchers

    private func fetchSlackMessages() async -> [NotificationItem] {
        guard slack.isConnected else { return [] }
        do {
            return try await slack.fetchNewMessages(since: lastSlackTimestamp())
        } catch {
            return []
        }
    }

    private func fetchEmailMessages() async -> [NotificationItem] {
        guard email.isConnected else { return [] }
        do {
            return try await email.fetchUnreadEmails(maxResults: 10)
        } catch {
            return []
        }
    }

    // MARK: - Actionability Filter

    /// Pre-filter messages before sending to Claude API (cost optimization)
    private func isActionable(_ notification: NotificationItem) -> Bool {
        let body = notification.body.lowercased()
        let actionKeywords = [
            "please", "can you", "could you", "would you",
            "need", "needs to", "must", "required", "deadline",
            "by tomorrow", "by eod", "by end of", "asap", "urgent",
            "schedule", "meeting", "call", "review", "approve",
            "action required", "follow up", "reminder", "don't forget",
            "pick up", "buy", "get", "send", "submit", "complete",
            "fix", "resolve", "check", "confirm", "reply"
        ]
        return actionKeywords.contains(where: { body.contains($0) })
    }

    // MARK: - Fallback Task Creation

    private func createFallbackTasks(from notifications: [NotificationItem]) -> [ButlerTask] {
        notifications.map { notification in
            let title = String(notification.body.prefix(80))
            return ButlerTask(
                title: title.isEmpty ? notification.title : title,
                description: notification.body,
                priority: .medium,
                category: notification.source == .slack || notification.source == .email ? .work : .personal,
                source: notification.source,
                sourceID: notification.sourceMessageID,
                isAIGenerated: false,
                originalMessage: notification.body
            )
        }
    }

    // MARK: - State Persistence

    private func lastSlackTimestamp() -> String {
        UserDefaults.standard.string(forKey: "last_slack_ts") ?? "0"
    }

    func saveLastSlackTimestamp(_ ts: String) {
        UserDefaults.standard.set(ts, forKey: "last_slack_ts")
    }

    // MARK: - Background Refresh Entry Point

    func handleBackgroundRefresh() async {
        do {
            _ = try await syncAndProcess()
        } catch {
            // Silently fail in background — don't crash
        }
    }

    // MARK: - Daily Plan Generation

    func generateDailyPlan(for tasks: [ButlerTask]) async throws -> DayPlan {
        let planText = try await claude.planDay(tasks: tasks)

        // Parse Claude's text response into a structured DayPlan
        // Claude returns a formatted text schedule, we build the plan from tasks
        var plan = DayPlanBuilder.buildFromTasks(tasks)
        plan.aiSummary = planText
        return plan
    }

    // MARK: - Smart Rescheduling

    func rescheduleOverdueTasks(_ tasks: [ButlerTask]) async throws -> [ButlerTask] {
        let overdue = tasks.filter { $0.isOverdue }
        guard !overdue.isEmpty else { return [] }

        let prompt = """
        I have \(overdue.count) overdue tasks. Help me prioritize them for today.
        Tasks: \(overdue.map { "- \($0.title)" }.joined(separator: "\n"))
        Return a brief prioritization recommendation.
        """

        let messages = [ChatMessage(role: .user, content: prompt)]
        _ = try await claude.chat(messages: messages)

        // Re-schedule each overdue task to today
        return overdue.map { task in
            var updated = task
            updated.scheduledDate = Date()
            return updated
        }
    }
}
