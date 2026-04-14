import SwiftUI

@main
struct ButlerAIApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isOnboardingComplete {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(appState.dashboardVM)
                        .environmentObject(appState.notificationVM)
                        .environmentObject(appState.chatVM)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .onAppear {
                appState.onAppLaunch()
            }
            .preferredColorScheme(.dark)
        }
    }
}
