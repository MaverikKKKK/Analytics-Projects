import Foundation
import UserNotifications

// MARK: - Notification Monitor

/// Monitors iOS system notifications from WhatsApp, SMS, and other apps.
/// Note: iOS restricts reading full notification content from other apps.
/// This monitor captures notification previews (typically first ~100 chars)
/// from known bundle IDs when the app is in the foreground.
@MainActor
final class NotificationMonitor: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationMonitor()

    @Published var capturedNotifications: [NotificationItem] = []
    @Published var permissionGranted = false

    // Callback for new notifications
    var onNewNotification: ((NotificationItem) -> Void)?

    // MARK: - Setup

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        checkPermissions()
    }

    func requestPermissions() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    func checkPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Called when a notification is delivered while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        processNotification(notification.request.content, id: notification.request.identifier)
        completionHandler([.banner, .badge, .sound])
    }

    // Called when user taps a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        processNotification(response.notification.request.content, id: response.notification.request.identifier)
        completionHandler()
    }

    // MARK: - Process Incoming Notification

    private func processNotification(_ content: UNNotificationContent, id: String) {
        let bundleId = content.userInfo["bundle_id"] as? String
            ?? content.userInfo["source"] as? String
            ?? ""

        let source = detectSource(bundleId: bundleId, title: content.title)
        let sender = extractSender(from: content, source: source)

        let notification = NotificationItem(
            source: source,
            sourceMessageID: id,
            sender: sender,
            title: content.title.isEmpty ? source.displayName : content.title,
            body: content.body,
            receivedAt: Date()
        )

        capturedNotifications.insert(notification, at: 0)
        // Keep only last 100 notifications in memory
        if capturedNotifications.count > 100 {
            capturedNotifications = Array(capturedNotifications.prefix(100))
        }

        onNewNotification?(notification)
    }

    // MARK: - Source Detection

    private func detectSource(bundleId: String, title: String) -> NotificationSource {
        switch bundleId {
        case Constants.Notifications.whatsAppBundleID:
            return .whatsApp
        case Constants.Notifications.slackAppBundleID:
            return .slack
        case Constants.Notifications.gmailBundleID, Constants.Notifications.mailBundleID:
            return .email
        case "com.apple.MobileSMS":
            return .sms
        default:
            // Try to detect from title
            let lower = title.lowercased()
            if lower.contains("whatsapp") { return .whatsApp }
            if lower.contains("slack") { return .slack }
            if lower.contains("mail") || lower.contains("email") { return .email }
            if lower.contains("message") || lower.contains("sms") { return .sms }
            return .manual
        }
    }

    private func extractSender(from content: UNNotificationContent, source: NotificationSource) -> String {
        // Different apps format notifications differently
        switch source {
        case .whatsApp:
            // WhatsApp format: "Sender Name" in title, message in body
            return content.title.isEmpty ? "WhatsApp" : content.title
        case .sms:
            // SMS: title is the contact name or phone number
            return content.title.isEmpty ? "Unknown" : content.title
        case .slack:
            // Slack: subtitle contains channel, title contains sender or channel
            return content.subtitle.isEmpty ? content.title : content.subtitle
        case .email:
            return content.title.isEmpty ? "Unknown Sender" : content.title
        case .manual:
            return content.title.isEmpty ? "System" : content.title
        }
    }

    // MARK: - Background Notification Processing

    /// Called from AppDelegate when a silent push arrives
    func processRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: String] else { return }

        let title = alert["title"] ?? ""
        let body = alert["body"] ?? ""
        let source = detectSource(bundleId: userInfo["bundle_id"] as? String ?? "", title: title)

        let notification = NotificationItem(
            source: source,
            sourceMessageID: UUID().uuidString,
            sender: title,
            title: title,
            body: body,
            receivedAt: Date()
        )

        capturedNotifications.insert(notification, at: 0)
        onNewNotification?(notification)
    }

    // MARK: - Clear Processed Notifications

    func markAsProcessed(id: UUID) {
        if let index = capturedNotifications.firstIndex(where: { $0.id == id }) {
            capturedNotifications[index].isProcessed = true
        }
    }

    func clearAll() {
        capturedNotifications.removeAll()
    }
}

// MARK: - AppDelegate Extension (to be called from AppDelegate)

extension NotificationMonitor {
    /// Schedule a local notification (for task reminders)
    func scheduleTaskReminder(for task: ButlerTask) {
        guard let date = task.scheduledDate ?? task.dueDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "Task Due: \(task.title)"
        content.body = task.description.isEmpty ? task.title : task.description
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "task_id": task.id.uuidString,
            "category": task.category.rawValue
        ]

        // Remind 30 minutes before
        let reminderDate = date.addingTimeInterval(-30 * 60)
        guard reminderDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for taskID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task-\(taskID.uuidString)"]
        )
    }
}
