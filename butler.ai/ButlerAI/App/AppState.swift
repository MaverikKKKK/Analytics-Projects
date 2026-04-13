import SwiftUI
import BackgroundTasks

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published

    @Published var selectedTab: Tab = .dashboard
    @Published var isOnboardingComplete: Bool
    @Published var hasApiKey: Bool

    // Child ViewModels (shared across tabs)
    let dashboardVM: DashboardViewModel
    let notificationVM: NotificationViewModel
    lazy var chatVM: ChatViewModel = ChatViewModel(dashboard: dashboardVM)

    // MARK: - Services

    private let persistence = PersistenceService.shared
    private let notificationMonitor = NotificationMonitor.shared
    private let planner = TaskPlannerService.shared

    // MARK: - Init

    init() {
        isOnboardingComplete = PersistenceService.shared.isOnboardingComplete
        hasApiKey = !PersistenceService.shared.apiKey.isEmpty
        dashboardVM = DashboardViewModel()
        notificationVM = NotificationViewModel()
    }

    // MARK: - App Lifecycle

    func onAppLaunch() {
        notificationMonitor.setup()
        registerBackgroundTasks()
        scheduleBackgroundRefresh()
        dashboardVM.onAppear()
        notificationVM.onAppear()
    }

    func completeOnboarding() {
        persistence.isOnboardingComplete = true
        isOnboardingComplete = true
        hasApiKey = !persistence.apiKey.isEmpty
    }

    func updateApiKeyStatus() {
        hasApiKey = !persistence.apiKey.isEmpty
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.butlerai.app.refresh",
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handleBackgroundRefresh(task: refreshTask)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()  // Schedule next refresh

        let handle = Task {
            await planner.handleBackgroundRefresh()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            handle.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.butlerai.app.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: Constants.UI.backgroundRefreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case dashboard = "Dashboard"
    case planner = "Planner"
    case notifications = "Inbox"
    case chat = "Butler"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2.fill"
        case .planner: return "calendar.badge.clock"
        case .notifications: return "tray.full.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
