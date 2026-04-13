import SwiftUI

enum AppTheme {

    // MARK: - Brand Colors
    static let primaryGradient = LinearGradient(
        colors: [Color("AccentStart"), Color("AccentEnd")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color("CardBackground")
    static let surfaceBackground = Color("SurfaceBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")

    // MARK: - Source Colors
    static let slackColor = Color(red: 0.27, green: 0.20, blue: 0.34)       // Slack purple
    static let whatsAppColor = Color(red: 0.07, green: 0.62, blue: 0.37)    // WhatsApp green
    static let emailColor = Color(red: 0.20, green: 0.44, blue: 0.85)       // Gmail blue
    static let smsColor = Color(red: 0.18, green: 0.80, blue: 0.44)         // iMessage green
    static let manualColor = Color(red: 0.60, green: 0.33, blue: 0.87)      // Purple for manual

    // MARK: - Priority Colors
    static let urgentColor = Color(red: 0.96, green: 0.26, blue: 0.21)      // Red
    static let highColor = Color(red: 1.0, green: 0.58, blue: 0.0)          // Orange
    static let mediumColor = Color(red: 1.0, green: 0.84, blue: 0.0)        // Yellow
    static let lowColor = Color(red: 0.30, green: 0.85, blue: 0.39)         // Green

    // MARK: - Category Colors
    static let workColor = Color(red: 0.20, green: 0.44, blue: 0.85)
    static let personalColor = Color(red: 0.60, green: 0.33, blue: 0.87)
    static let healthColor = Color(red: 0.30, green: 0.85, blue: 0.39)
    static let financeColor = Color(red: 1.0, green: 0.58, blue: 0.0)
}

// MARK: - Color Extensions
extension Color {
    static func forSource(_ source: NotificationSource) -> Color {
        switch source {
        case .slack: return AppTheme.slackColor
        case .whatsApp: return AppTheme.whatsAppColor
        case .email: return AppTheme.emailColor
        case .sms: return AppTheme.smsColor
        case .manual: return AppTheme.manualColor
        }
    }

    static func forPriority(_ priority: TaskPriority) -> Color {
        switch priority {
        case .urgent: return AppTheme.urgentColor
        case .high: return AppTheme.highColor
        case .medium: return AppTheme.mediumColor
        case .low: return AppTheme.lowColor
        }
    }

    static func forCategory(_ category: TaskCategory) -> Color {
        switch category {
        case .work: return AppTheme.workColor
        case .personal: return AppTheme.personalColor
        case .health: return AppTheme.healthColor
        case .finance: return AppTheme.financeColor
        case .other: return AppTheme.secondaryText
        }
    }
}

// MARK: - View Modifiers
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
    }
}

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCardModifier()) }
    func pulsing() -> some View { modifier(PulsingModifier()) }
}
