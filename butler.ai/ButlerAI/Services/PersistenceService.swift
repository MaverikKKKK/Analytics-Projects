import Foundation

// MARK: - Persistence Service (UserDefaults-based)

/// Simple persistence layer using UserDefaults + JSON encoding.
/// In production, replace with CoreData + CloudKit for sync across devices.
@MainActor
final class PersistenceService: ObservableObject {

    static let shared = PersistenceService()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Tasks

    func saveTasks(_ tasks: [ButlerTask]) {
        if let data = try? encoder.encode(tasks) {
            UserDefaults.standard.set(data, forKey: Constants.Storage.tasksKey)
        }
    }

    func loadTasks() -> [ButlerTask] {
        guard let data = UserDefaults.standard.data(forKey: Constants.Storage.tasksKey),
              let tasks = try? decoder.decode([ButlerTask].self, from: data) else {
            return []
        }
        return tasks
    }

    func addTask(_ task: ButlerTask) {
        var tasks = loadTasks()
        tasks.insert(task, at: 0)
        saveTasks(tasks)
    }

    func updateTask(_ task: ButlerTask) {
        var tasks = loadTasks()
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks(tasks)
        }
    }

    func deleteTask(id: UUID) {
        var tasks = loadTasks()
        tasks.removeAll { $0.id == id }
        saveTasks(tasks)
    }

    // MARK: - Day Plan

    func saveDayPlan(_ plan: DayPlan) {
        if let data = try? encoder.encode(plan) {
            UserDefaults.standard.set(data, forKey: Constants.Storage.dayPlanKey)
        }
    }

    func loadDayPlan() -> DayPlan? {
        guard let data = UserDefaults.standard.data(forKey: Constants.Storage.dayPlanKey),
              let plan = try? decoder.decode(DayPlan.self, from: data) else {
            return nil
        }
        // Only return plan if it's for today
        guard Calendar.current.isDateInToday(plan.date) else { return nil }
        return plan
    }

    // MARK: - Notifications Cache

    func saveNotifications(_ notifications: [NotificationItem]) {
        if let data = try? encoder.encode(notifications) {
            UserDefaults.standard.set(data, forKey: "cached_notifications")
        }
    }

    func loadNotifications() -> [NotificationItem] {
        guard let data = UserDefaults.standard.data(forKey: "cached_notifications"),
              let notifications = try? decoder.decode([NotificationItem].self, from: data) else {
            return []
        }
        // Only return notifications from the last 24 hours
        let cutoff = Date().addingTimeInterval(-86400)
        return notifications.filter { $0.receivedAt > cutoff }
    }

    // MARK: - Chat History

    func saveChatHistory(_ messages: [ChatMessage]) {
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: "chat_history")
        }
    }

    func loadChatHistory() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: "chat_history"),
              let messages = try? decoder.decode([ChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    // MARK: - Settings

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Constants.Storage.anthropicKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Constants.Storage.anthropicKeyKey) }
    }

    var slackToken: String {
        get { UserDefaults.standard.string(forKey: Constants.Storage.slackTokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Constants.Storage.slackTokenKey) }
    }

    var isOnboardingComplete: Bool {
        get { UserDefaults.standard.bool(forKey: Constants.Storage.onboardingCompleteKey) }
        set { UserDefaults.standard.set(newValue, forKey: Constants.Storage.onboardingCompleteKey) }
    }

    var lastSyncDate: Date? {
        get {
            guard let ts = UserDefaults.standard.object(forKey: Constants.Storage.lastSyncKey) as? Double else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: Constants.Storage.lastSyncKey)
        }
    }

    // MARK: - Clear All Data

    func clearAll() {
        let keys = [
            Constants.Storage.tasksKey,
            Constants.Storage.dayPlanKey,
            "cached_notifications",
            "chat_history"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
