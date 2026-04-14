import Foundation

@MainActor
final class NotificationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var notifications: [NotificationItem] = []
    @Published var isLoading = false
    @Published var selectedSource: NotificationSource? = nil
    @Published var showUnreadOnly = false
    @Published var errorMessage: String?

    // MARK: - Computed

    var filteredNotifications: [NotificationItem] {
        var result = notifications

        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }

        if showUnreadOnly {
            result = result.filter { !$0.isRead }
        }

        return result.sorted { $0.receivedAt > $1.receivedAt }
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var unprocessedCount: Int {
        notifications.filter { !$0.isProcessed }.count
    }

    var notificationsBySource: [NotificationSource: [NotificationItem]] {
        Dictionary(grouping: notifications, by: \.source)
    }

    var sourceCountSummary: [(source: NotificationSource, count: Int)] {
        NotificationSource.allCases.compactMap { source in
            let count = notifications.filter { $0.source == source && !$0.isRead }.count
            return count > 0 ? (source, count) : nil
        }
    }

    // MARK: - Services

    private let persistence = PersistenceService.shared
    private let slack = SlackService.shared
    private let email = EmailService.shared
    private let monitor = NotificationMonitor.shared

    // MARK: - Init

    init() {
        loadCached()
        setupNotificationMonitorCallback()
    }

    // MARK: - Setup

    private func setupNotificationMonitorCallback() {
        monitor.onNewNotification = { [weak self] notification in
            Task { @MainActor in
                self?.insertNotification(notification)
            }
        }
    }

    // MARK: - Load

    func onAppear() {
        loadCached()

        if notifications.isEmpty {
            notifications = NotificationItem.samples
        }
    }

    func loadCached() {
        notifications = persistence.loadNotifications()
    }

    // MARK: - Refresh

    func refreshAll() async {
        isLoading = true
        errorMessage = nil

        var newNotifications: [NotificationItem] = []

        // Fetch from Slack
        if slack.isConnected {
            do {
                let slackMessages = try await slack.fetchNewMessages()
                newNotifications.append(contentsOf: slackMessages)
            } catch {
                // Continue with other sources
            }
        }

        // Fetch from Gmail
        if email.isConnected {
            do {
                let emails = try await email.fetchUnreadEmails(maxResults: 15)
                newNotifications.append(contentsOf: emails)
            } catch {
                // Continue with other sources
            }
        }

        // Add iOS notifications (already captured via delegate)
        let iosNotifications = monitor.capturedNotifications
        newNotifications.append(contentsOf: iosNotifications)

        // Merge with existing (avoid duplicates by sourceMessageID)
        let existingIDs = Set(notifications.map(\.sourceMessageID))
        let unique = newNotifications.filter { !existingIDs.contains($0.sourceMessageID) }
        notifications.insert(contentsOf: unique, at: 0)

        // Keep only last 200
        if notifications.count > 200 {
            notifications = Array(notifications.prefix(200))
        }

        persistence.saveNotifications(notifications)
        isLoading = false
    }

    // MARK: - Actions

    func markAsRead(_ notification: NotificationItem) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
        persistence.saveNotifications(notifications)
    }

    func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        persistence.saveNotifications(notifications)
    }

    func delete(_ notification: NotificationItem) {
        notifications.removeAll { $0.id == notification.id }
        persistence.saveNotifications(notifications)
    }

    func linkTask(notificationID: UUID, taskID: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[index].extractedTaskID = taskID
            notifications[index].isProcessed = true
        }
        persistence.saveNotifications(notifications)
    }

    // MARK: - Helpers

    private func insertNotification(_ notification: NotificationItem) {
        // Don't add duplicates
        guard !notifications.contains(where: { $0.sourceMessageID == notification.sourceMessageID }) else { return }
        notifications.insert(notification, at: 0)
        persistence.saveNotifications(notifications)
    }
}
