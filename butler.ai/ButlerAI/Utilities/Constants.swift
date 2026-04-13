import Foundation

enum Constants {

    enum API {
        static let anthropicBaseURL = "https://api.anthropic.com/v1"
        static let anthropicVersion = "2023-06-01"
        static let claudeModel = "claude-opus-4-6"

        static let slackBaseURL = "https://slack.com/api"
        static let gmailBaseURL = "https://gmail.googleapis.com/gmail/v1"
        static let googleOAuthURL = "https://oauth2.googleapis.com/token"
    }

    enum Storage {
        static let anthropicKeyKey = "anthropic_api_key"
        static let slackTokenKey = "slack_bot_token"
        static let gmailAccessTokenKey = "gmail_access_token"
        static let gmailRefreshTokenKey = "gmail_refresh_token"
        static let tasksKey = "saved_tasks"
        static let dayPlanKey = "day_plan"
        static let onboardingCompleteKey = "onboarding_complete"
        static let lastSyncKey = "last_sync_timestamp"
    }

    enum UI {
        static let cornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let iconSize: CGFloat = 22
        static let backgroundRefreshInterval: TimeInterval = 900 // 15 minutes
    }

    enum Notifications {
        static let slackAppBundleID = "com.tinyspeck.slack"
        static let whatsAppBundleID = "net.whatsapp.WhatsApp"
        static let gmailBundleID = "com.google.Gmail"
        static let mailBundleID = "com.apple.mobilemail"
    }
}
