import Foundation

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var errorMessage: String?
    @Published var suggestedPrompts: [String] = []

    // MARK: - Services

    private let claude = ClaudeService.shared
    private let persistence = PersistenceService.shared
    private let dashboard: DashboardViewModel

    // Stream task for cancellation
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(dashboard: DashboardViewModel) {
        self.dashboard = dashboard
        loadHistory()
        generateSuggestedPrompts()

        // Show welcome if no history
        if messages.isEmpty {
            addWelcomeMessage()
        }
    }

    // MARK: - Welcome Message

    private func addWelcomeMessage() {
        let taskCount = dashboard.tasks.filter { $0.status == .pending }.count
        let urgentCount = dashboard.urgentCount

        var welcome = "Hey there! I'm **Butler**, your AI assistant. "

        if taskCount > 0 {
            welcome += "You have **\(taskCount) tasks** waiting"
            if urgentCount > 0 {
                welcome += ", including **\(urgentCount) urgent** ones"
            }
            welcome += ".\n\nAsk me to plan your day, add a task, or just chat about what you need to get done."
        } else {
            welcome += "Your slate is clean! Tell me what you need to accomplish today, or connect Slack and Gmail in Settings to start monitoring your messages automatically."
        }

        let msg = ChatMessage(role: .assistant, content: welcome)
        messages.append(msg)
        persistence.saveChatHistory(messages)
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Check for quick commands
        if handleQuickCommand(text) { return }

        // Stream from Claude
        streamResponse(userText: text)
    }

    // MARK: - Quick Commands (local, no API needed)

    private func handleQuickCommand(_ text: String) -> Bool {
        let lower = text.lowercased()

        if lower.contains("clear") && lower.contains("task") {
            dashboard.clearCompleted()
            addAssistantMessage("Done! I've cleared all completed tasks from your list. ✓")
            return true
        }

        if lower == "/tasks" || lower == "show tasks" || lower == "list tasks" {
            let taskList = dashboard.tasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            addAssistantMessage("Here are your current tasks:\n\n\(taskList)\n\nYou have \(dashboard.tasks.count) total tasks.")
            return true
        }

        if lower == "/plan" || lower == "plan my day" {
            Task { await generateDayPlan() }
            return false  // Let Claude handle this with context
        }

        return false
    }

    // MARK: - Stream Response

    private func streamResponse(userText: String) {
        isStreaming = true
        streamingContent = ""

        // Build context-aware system injection
        let contextMessage = buildContextMessage()
        var apiMessages = messages.dropLast()  // Exclude the user message we just added
            .suffix(20)  // Keep last 20 messages for context
            .map { $0 }

        // Add context as a system-flavored message
        if !contextMessage.isEmpty {
            apiMessages.insert(ChatMessage(role: .user, content: contextMessage), at: 0)
            apiMessages.insert(ChatMessage(role: .assistant, content: "I've reviewed your current tasks and schedule. How can I help?"), at: 1)
        }

        apiMessages.append(messages.last!)  // Re-add the user message

        streamTask = Task {
            var fullResponse = ""

            claude.streamChat(
                messages: Array(apiMessages),
                onToken: { [weak self] token in
                    guard let self = self else { return }
                    self.streamingContent += token
                    fullResponse += token
                },
                onComplete: { [weak self] complete in
                    guard let self = self else { return }
                    self.isStreaming = false
                    self.streamingContent = ""

                    let assistantMessage = ChatMessage(role: .assistant, content: complete)
                    self.messages.append(assistantMessage)
                    self.persistence.saveChatHistory(self.messages)

                    // Extract any tasks mentioned in response
                    Task { await self.extractTasksFromResponse(complete) }
                    self.generateSuggestedPrompts()
                },
                onError: { [weak self] error in
                    guard let self = self else { return }
                    self.isStreaming = false
                    self.streamingContent = ""
                    self.errorMessage = error.localizedDescription

                    let errMsg = ChatMessage(
                        role: .assistant,
                        content: "I encountered an error: \(error.localizedDescription)\n\nPlease check your API key in Settings.",
                        isError: true
                    )
                    self.messages.append(errMsg)
                }
            )
        }
    }

    // MARK: - Context Building

    private func buildContextMessage() -> String {
        let pendingTasks = dashboard.tasks.filter { $0.status == .pending }.prefix(8)
        guard !pendingTasks.isEmpty else { return "" }

        let taskList = pendingTasks.enumerated().map { i, t in
            "[\(i+1)] \(t.priority.rawValue.uppercased()): \(t.title) (from \(t.source.rawValue))"
        }.joined(separator: "\n")

        return """
        [CONTEXT - Current user tasks]:
        \(taskList)

        Today: \(Date().formatted(date: .complete, time: .omitted))
        Urgent count: \(dashboard.urgentCount)
        Today's tasks: \(dashboard.todayCount)
        """
    }

    // MARK: - Task Extraction from Assistant Response

    private func extractTasksFromResponse(_ response: String) async {
        // Look for task creation signals in Claude's response
        let taskSignals = ["I've added", "I've created", "added a task", "created a task", "scheduling", "I'll add"]
        let hasTaskSignal = taskSignals.contains { response.lowercased().contains($0.lowercased()) }

        guard hasTaskSignal else { return }

        // Create a notification item from the user's last message and extract task
        if let lastUserMessage = messages.last(where: { $0.isUser }) {
            let notification = NotificationItem(
                source: .manual,
                sender: "Chat",
                title: "Task from Chat",
                body: lastUserMessage.content
            )
            do {
                let tasks = try await claude.extractTasks(from: [notification])
                for task in tasks {
                    dashboard.addTask(task)
                }
            } catch {
                // Silently fail - task extraction is best-effort
            }
        }
    }

    // MARK: - Day Plan Generation

    func generateDayPlan() async {
        let pendingTasks = Array(dashboard.tasks.filter { $0.status == .pending }.prefix(10))

        addUserMessage("Plan my day around my current tasks.")

        isStreaming = true
        streamingContent = ""

        do {
            let planText = try await claude.planDay(tasks: pendingTasks)
            isStreaming = false
            streamingContent = ""

            let assistantMessage = ChatMessage(role: .assistant, content: planText)
            messages.append(assistantMessage)
            persistence.saveChatHistory(messages)

            // Also regenerate the structured day plan
            await dashboard.regenerateDayPlan()
        } catch {
            isStreaming = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func addAssistantMessage(_ text: String) {
        let msg = ChatMessage(role: .assistant, content: text)
        messages.append(msg)
        persistence.saveChatHistory(messages)
    }

    private func addUserMessage(_ text: String) {
        let msg = ChatMessage(role: .user, content: text)
        messages.append(msg)
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingContent = ""
    }

    func clearHistory() {
        messages.removeAll()
        persistence.saveChatHistory([])
        addWelcomeMessage()
    }

    // MARK: - Suggested Prompts

    private func generateSuggestedPrompts() {
        let urgentCount = dashboard.urgentCount
        var prompts: [String] = []

        if urgentCount > 0 {
            prompts.append("Help me tackle my \(urgentCount) urgent tasks")
        }
        prompts.append(contentsOf: [
            "Plan my day",
            "What should I focus on first?",
            "Add a task to call my doctor",
            "Show me my work tasks only",
            "Reschedule all overdue tasks"
        ])

        suggestedPrompts = Array(prompts.prefix(4))
    }

    // MARK: - Persistence

    private func loadHistory() {
        messages = persistence.loadChatHistory()
    }
}
