import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notificationVM: NotificationViewModel

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                }
                .tag(Tab.dashboard)

            DayPlannerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar.badge.clock")
                }
                .tag(Tab.planner)

            NotificationsView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.full.fill")
                }
                .badge(notificationVM.unreadCount > 0 ? notificationVM.unreadCount : 0)
                .tag(Tab.notifications)

            ChatView()
                .tabItem {
                    Label("Butler", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.chat)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.purple)
        .background(Color.black)
    }
}
