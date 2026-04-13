import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var apiKey = ""
    @State private var slackToken = ""
    @State private var permissionsRequested = false

    private let persistence = PersistenceService.shared

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.04, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // Step indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= currentStep ? Color.purple : Color.white.opacity(0.2))
                            .frame(width: i == currentStep ? 24 : 8, height: 6)
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: permissionsStep
                    case 2: apiKeyStep
                    case 3: integrationsStep
                    default: welcomeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.4), value: currentStep)

                Spacer()

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 80)
                    }

                    Button(currentStep < 3 ? "Continue" : "Get Started") {
                        withAnimation {
                            if currentStep < 3 {
                                currentStep += 1
                            } else {
                                finishOnboarding()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Steps

    var welcomeStep: some View {
        VStack(spacing: 24) {
            // App icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Text("B")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .purple.opacity(0.6), radius: 20)

            VStack(spacing: 12) {
                Text("Meet Butler")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("Your AI-powered personal command center that monitors your Slack, email, SMS, and WhatsApp — so you never miss what matters.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 30)
            }

            // Feature highlights
            VStack(spacing: 12) {
                featureRow(icon: "sparkles", color: .purple, text: "AI extracts tasks from your messages automatically")
                featureRow(icon: "calendar.badge.clock", color: .blue, text: "Plans your day around your priorities")
                featureRow(icon: "bubble.left.and.bubble.right.fill", color: .green, text: "Chat with Butler to add tasks naturally")
            }
            .padding(.horizontal, 30)
        }
    }

    var permissionsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Allow Notifications")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Butler needs notification access to capture messages from WhatsApp, SMS, and other apps when they arrive.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 30)

            if !permissionsRequested {
                Button("Grant Notification Access") {
                    Task {
                        await NotificationMonitor.shared.requestPermissions()
                        permissionsRequested = true
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.2))
                .foregroundColor(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.4), lineWidth: 1))
                .padding(.horizontal, 30)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permissions requested!")
                        .foregroundColor(.green)
                }
            }

            Text("You can also grant this later in Settings → Notifications")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    var apiKeyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Connect Claude AI")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Butler uses Claude AI to extract tasks from your messages and plan your day. Add your Anthropic API key to get started.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 30)

            VStack(spacing: 8) {
                SecureField("sk-ant-api...", text: $apiKey)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !apiKey.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("API key ready")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 30)

            Text("Get your API key at console.anthropic.com")
                .font(.caption)
                .foregroundColor(.purple.opacity(0.7))
        }
    }

    var integrationsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Connect Your Apps")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Connect Slack and Gmail to start monitoring messages. You can skip this and add tokens in Settings later.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 30)

            VStack(spacing: 12) {
                // Slack
                VStack(alignment: .leading, spacing: 6) {
                    Label("Slack Bot Token", systemImage: "message.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.slackColor)
                    SecureField("xoxb-...", text: $slackToken)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Text("Gmail connection available in Settings after setup")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 30)
        }
    }

    // MARK: - Helper

    func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }

    // MARK: - Finish Onboarding

    func finishOnboarding() {
        if !apiKey.isEmpty {
            persistence.apiKey = apiKey
        }
        if !slackToken.isEmpty {
            persistence.slackToken = slackToken
        }
        appState.completeOnboarding()
    }
}
