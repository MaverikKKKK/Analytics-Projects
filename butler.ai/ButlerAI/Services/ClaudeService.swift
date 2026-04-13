import Foundation

// MARK: - Claude Service

@MainActor
final class ClaudeService: ObservableObject {

    static let shared = ClaudeService()

    private var apiKey: String {
        UserDefaults.standard.string(forKey: Constants.Storage.anthropicKeyKey) ?? ""
    }

    private let systemPrompt = """
    You are Butler, an intelligent personal assistant AI embedded in a mobile app. Your job is to:
    1. Help users manage their daily tasks extracted from Slack, email, SMS, and WhatsApp notifications
    2. Plan their day intelligently based on priorities, deadlines, and context
    3. Extract actionable tasks from raw messages when asked
    4. Respond to user requests to add, modify, or remove tasks
    5. Provide concise, actionable responses with clear formatting

    When extracting tasks from messages, return JSON in this format:
    {"tasks": [{"title": "...", "description": "...", "priority": "urgent|high|medium|low", "category": "work|personal|health|finance|other", "estimatedDuration": <minutes>, "dueDate": "ISO8601 or null"}]}

    When planning a day, be realistic about time — include breaks and transitions.
    Always format responses using markdown for clarity. Be concise but thorough.
    Address the user in a friendly, professional tone.
    """

    // MARK: - Chat Completion (Streaming)

    func streamChat(
        messages: [ChatMessage],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !apiKey.isEmpty else {
            onError(ClaudeError.missingAPIKey)
            return
        }

        let url = URL(string: "\(Constants.API.anthropicBaseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.API.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let claudeMessages = messages
            .filter { $0.role != .system }
            .map { ClaudeMessage(role: $0.role.rawValue, content: $0.content) }

        let body = ClaudeRequest(
            model: Constants.API.claudeModel,
            maxTokens: 2048,
            system: systemPrompt,
            messages: claudeMessages,
            stream: true
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            onError(error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { onError(error) }
                return
            }

            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { onError(ClaudeError.invalidResponse) }
                return
            }

            // Parse SSE stream
            var fullText = ""
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" { continue }
                    if let data = jsonString.data(using: .utf8),
                       let event = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: data) {
                        if let delta = event.delta?.text {
                            fullText += delta
                            DispatchQueue.main.async { onToken(delta) }
                        }
                    }
                }
            }
            DispatchQueue.main.async { onComplete(fullText) }
        }
        task.resume()
    }

    // MARK: - Non-Streaming Chat

    func chat(messages: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }

        let url = URL(string: "\(Constants.API.anthropicBaseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.API.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let claudeMessages = messages
            .filter { $0.role != .system }
            .map { ClaudeMessage(role: $0.role.rawValue, content: $0.content) }

        let body = ClaudeRequest(
            model: Constants.API.claudeModel,
            maxTokens: 2048,
            system: systemPrompt,
            messages: claudeMessages,
            stream: false
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorText = String(data: data, encoding: .utf8) {
                throw ClaudeError.apiError(errorText)
            }
            throw ClaudeError.invalidResponse
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return claudeResponse.text
    }

    // MARK: - Task Extraction from Messages

    func extractTasks(from messages: [NotificationItem]) async throws -> [ButlerTask] {
        guard !messages.isEmpty else { return [] }

        let messagesText = messages.map { msg in
            "[\(msg.source.rawValue) from \(msg.sender)]: \(msg.body)"
        }.joined(separator: "\n\n")

        let prompt = """
        Extract actionable tasks from these messages. Return ONLY valid JSON, no other text.

        Messages:
        \(messagesText)

        Return format:
        {"tasks": [{"title": "...", "description": "...", "priority": "urgent|high|medium|low", "category": "work|personal|health|finance|other", "estimatedDuration": <minutes>, "source": "<source>", "originalMessage": "..."}]}
        """

        let chatMessages = [ChatMessage(role: .user, content: prompt)]
        let response = try await chat(messages: chatMessages)

        // Extract JSON from response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return []
        }

        let jsonString = String(response[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }

        let extraction = try JSONDecoder().decode(TaskExtraction.self, from: jsonData)
        return extraction.tasks.map { extracted in
            ButlerTask(
                title: extracted.title,
                description: extracted.description,
                priority: TaskPriority(rawValue: extracted.priority.capitalized) ?? .medium,
                category: TaskCategory(rawValue: extracted.category.capitalized) ?? .work,
                source: NotificationSource(rawValue: extracted.source) ?? .manual,
                estimatedDuration: extracted.estimatedDuration,
                isAIGenerated: true,
                originalMessage: extracted.originalMessage
            )
        }
    }

    // MARK: - Day Planning

    func planDay(tasks: [ButlerTask], context: String = "") async throws -> String {
        let taskList = tasks.prefix(10).enumerated().map { i, task in
            "\(i+1). [\(task.priority.rawValue)] \(task.title) (~\(task.estimatedDuration ?? 30) min) - \(task.category.rawValue)"
        }.joined(separator: "\n")

        let prompt = """
        Plan my day based on these tasks. Current time: \(Date().formatted(date: .omitted, time: .shortened)).
        \(context.isEmpty ? "" : "Additional context: \(context)\n")

        Tasks:
        \(taskList)

        Create a practical schedule from now until 6 PM. Include focus time, breaks, and buffer time.
        Format as a clean timeline with times and brief notes for each block.
        """

        let chatMessages = [ChatMessage(role: .user, content: prompt)]
        return try await chat(messages: chatMessages)
    }
}

// MARK: - Supporting Types

private struct TaskExtraction: Codable {
    let tasks: [ExtractedTask]
}

private struct ExtractedTask: Codable {
    let title: String
    let description: String
    let priority: String
    let category: String
    let estimatedDuration: Int?
    let source: String
    let originalMessage: String?
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is not set. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}
