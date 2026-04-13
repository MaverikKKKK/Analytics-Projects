import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @State private var anthropicKey = ""
    @State private var slackToken = ""
    @State private var showAnthropicKey = false
    @State private var showSlackToken = false
    @State private var isTestingSlack = false
    @State private var slackTestResult: String? = nil
    @State private var showClearConfirm = false

    private let persistence = PersistenceService.shared
    private let slackService = SlackService.shared
    private let notificationMonitor = NotificationMonitor.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    // AI Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Claude API Key", systemImage: "key.fill")
                                .font(.subheadline)
                                .foregroundColor(.purple)

                            HStack {
                                if showAnthropicKey {
                                    TextField("sk-ant-...", text: $anthropicKey)
                                        .font(.caption)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("sk-ant-...", text: $anthropicKey)
                                        .font(.caption)
                                }
                                Button {
                                    showAnthropicKey.toggle()
                                } label: {
                                    Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }

                            HStack {
                                Circle()
                                    .fill(anthropicKey.isEmpty ? Color.red : Color.green)
                                    .frame(width: 6, height: 6)
                                Text(anthropicKey.isEmpty ? "Not configured" : "Configured")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 4)

                        Button("Save API Key") {
                            persistence.apiKey = anthropicKey
                            appState.updateApiKeyStatus()
                            hideKeyboard()
                        }
                        .foregroundColor(.purple)
                    } header: {
                        Text("AI Assistant (Claude)")
                    } footer: {
                        Text("Get your API key from console.anthropic.com. Using claude-opus-4-6 model.")
                            .font(.caption2)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // Slack Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Slack Bot Token", systemImage: "message.fill")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.slackColor)

                            HStack {
                                if showSlackToken {
                                    TextField("xoxb-...", text: $slackToken)
                                        .font(.caption)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("xoxb-...", text: $slackToken)
                                        .font(.caption)
                                }
                                Button {
                                    showSlackToken.toggle()
                                } label: {
                                    Image(systemName: showSlackToken ? "eye.slash" : "eye")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }

                            HStack {
                                Circle()
                                    .fill(slackService.isConnected ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                Text(slackService.isConnected ? "Connected" : (slackToken.isEmpty ? "Not configured" : "Disconnected"))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))

                                if let result = slackTestResult {
                                    Spacer()
                                    Text(result)
                                        .font(.caption2)
                                        .foregroundColor(result.contains("✓") ? .green : .red)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Button("Save Token") {
                                persistence.slackToken = slackToken
                                hideKeyboard()
                            }
                            .foregroundColor(.purple)

                            Divider().frame(height: 16)

                            Button {
                                Task {
                                    isTestingSlack = true
                                    UserDefaults.standard.set(slackToken, forKey: Constants.Storage.slackTokenKey)
                                    let ok = await slackService.testConnection()
                                    slackTestResult = ok ? "✓ Connected" : "✗ Failed"
                                    isTestingSlack = false
                                }
                            } label: {
                                if isTestingSlack {
                                    ProgressView().tint(.purple).scaleEffect(0.7)
                                } else {
                                    Text("Test Connection")
                                }
                            }
                            .foregroundColor(.purple)
                            .disabled(slackToken.isEmpty || isTestingSlack)
                        }
                    } header: {
                        Text("Slack Integration")
                    } footer: {
                        Text("Create a Slack app at api.slack.com and install it to your workspace. Required scopes: channels:history, channels:read, groups:history, im:history.")
                            .font(.caption2)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // Gmail Section
                    Section {
                        HStack {
                            Label("Gmail", systemImage: "envelope.fill")
                                .foregroundColor(AppTheme.emailColor)
                            Spacer()
                            Circle()
                                .fill(EmailService.shared.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(EmailService.shared.isConnected ? "Connected" : "Not connected")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Button("Connect Gmail via OAuth") {
                            // In production, this would open Safari with Google OAuth URL
                            // The URL scheme callback would be handled by SceneDelegate
                        }
                        .foregroundColor(.purple)

                        Text("Gmail OAuth requires a Google Cloud project with Gmail API enabled. Set the OAuth callback URL to: butlerai://oauth/gmail")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    } header: {
                        Text("Gmail Integration")
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // Notifications Section
                    Section {
                        HStack {
                            Label("Notifications Permission", systemImage: "bell.fill")
                            Spacer()
                            Circle()
                                .fill(notificationMonitor.permissionGranted ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(notificationMonitor.permissionGranted ? "Granted" : "Denied")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        if !notificationMonitor.permissionGranted {
                            Button("Request Permission") {
                                Task { await notificationMonitor.requestPermissions() }
                            }
                            .foregroundColor(.purple)
                        }

                        infoRow(icon: "message.fill", color: AppTheme.whatsAppColor, title: "WhatsApp", status: "Preview monitoring only")
                        infoRow(icon: "bubble.left.fill", color: AppTheme.smsColor, title: "SMS/iMessage", status: "Notification previews")
                    } header: {
                        Text("iOS Notification Monitoring")
                    } footer: {
                        Text("iOS only provides notification previews (~100 chars) for WhatsApp and SMS. Full message content requires users to forward messages.")
                            .font(.caption2)
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // Background Sync Section
                    Section {
                        HStack {
                            Label("Background Sync", systemImage: "arrow.clockwise.circle.fill")
                            Spacer()
                            Text("Every 15 min")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        if let lastSync = persistence.lastSyncDate {
                            HStack {
                                Label("Last Sync", systemImage: "clock")
                                Spacer()
                                Text(lastSync.timeAgoDisplay)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        Button("Sync Now") {
                            Task { await appState.dashboardVM.syncAll() }
                        }
                        .foregroundColor(.purple)
                    } header: {
                        Text("Sync")
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // Data Section
                    Section {
                        Button("Clear All Data", role: .destructive) {
                            showClearConfirm = true
                        }
                    } header: {
                        Text("Data Management")
                    }
                    .listRowBackground(Color.white.opacity(0.06))

                    // About Section
                    Section {
                        HStack {
                            Text("Butler.AI")
                            Spacer()
                            Text("v1.0.0")
                                .foregroundColor(.white.opacity(0.4))
                        }
                        HStack {
                            Text("AI Model")
                            Spacer()
                            Text(Constants.API.claudeModel)
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        HStack {
                            Text("Powered by")
                            Spacer()
                            Text("Anthropic Claude")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } header: {
                        Text("About")
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            anthropicKey = persistence.apiKey
            slackToken = persistence.slackToken
        }
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                persistence.clearAll()
                appState.dashboardVM.loadLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all tasks, notifications, and chat history. API keys will be kept.")
        }
    }

    // MARK: - Info Row

    func infoRow(icon: String, color: Color, title: String, status: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
