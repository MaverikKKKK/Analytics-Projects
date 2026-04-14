# Butler.AI

Your AI-powered personal command center — an iPhone app that monitors your Slack, Email, WhatsApp, and SMS notifications, extracts actionable tasks using Claude AI, and plans your day automatically.

## Features

- **Smart Inbox** — Aggregates Slack, Gmail, WhatsApp & SMS notifications in one place
- **AI Task Extraction** — Claude AI reads your messages and creates tasks automatically
- **Day Planner** — AI builds a structured day plan based on your priorities and deadlines
- **Butler Chat** — Chat naturally with your AI assistant to add, modify, or query tasks
- **Background Monitoring** — Syncs every 15 minutes in the background, even when app is closed
- **Priority Dashboard** — Separate work and personal task views with urgency indicators

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI (iOS 16+) |
| Architecture | MVVM + @MainActor |
| AI | Claude claude-opus-4-6 (Anthropic API) |
| Slack Integration | Slack Web API (OAuth + Polling) |
| Email Integration | Gmail REST API (OAuth2) |
| Notifications | UNUserNotificationCenter |
| Background Sync | BGTaskScheduler |
| Storage | UserDefaults + JSON |

## Setup

### Prerequisites

- macOS 13+ with Xcode 15+
- iPhone running iOS 16+
- [Homebrew](https://brew.sh) (for XcodeGen)

### Quick Start

```bash
cd butler.ai
./setup.sh
```

This will install XcodeGen and generate the Xcode project.

### Manual Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate --spec project.yml
   ```

3. Open `ButlerAI.xcodeproj` in Xcode

4. Set your Development Team in **Project Settings → Signing & Capabilities**

5. Build and run on your iPhone

## API Keys Required

### Anthropic (Claude AI) — Required
- Get your API key at [console.anthropic.com](https://console.anthropic.com)
- Add it in the app: **Settings → AI Assistant → Claude API Key**

### Slack Bot Token — Optional (for Slack monitoring)
1. Go to [api.slack.com/apps](https://api.slack.com/apps) → Create New App
2. Add Bot Token Scopes:
   - `channels:history` — Read messages from public channels
   - `channels:read` — View channel list
   - `groups:history` — Read private channel messages
   - `im:history` — Read direct messages
   - `users:read` — Resolve usernames
3. Install the app to your workspace
4. Copy the **Bot User OAuth Token** (starts with `xoxb-`)
5. Add in app: **Settings → Slack Integration → Token**

### Gmail OAuth — Optional (for email monitoring)
1. Create a project at [Google Cloud Console](https://console.cloud.google.com)
2. Enable Gmail API
3. Create OAuth 2.0 credentials (iOS app type)
4. Add the reverse client ID URL scheme to your Info.plist
5. Connect via **Settings → Gmail Integration → Connect Gmail**

## iOS Notification Monitoring

Butler monitors iOS notifications from:

| Source | Capability | Notes |
|--------|-----------|-------|
| Slack | Full via API | Real-time with background refresh |
| Gmail | Full via API | Polls every 15 minutes |
| WhatsApp | Preview only | ~100 char notification preview |
| SMS/iMessage | Preview only | Notification preview when app in foreground |

> **Note:** iOS restricts reading full WhatsApp and SMS content. Butler captures notification previews (~100 characters). For full content, users must forward messages or share via the share sheet.

## Project Structure

```
butler.ai/
├── setup.sh                    # Project setup script
├── project.yml                 # XcodeGen configuration
├── ButlerAI/
│   ├── App/
│   │   ├── ButlerAIApp.swift   # App entry point
│   │   ├── ContentView.swift   # Tab navigation
│   │   └── AppState.swift      # Root state + DI
│   ├── Models/
│   │   ├── TaskModel.swift     # Task, Priority, Category, Source enums
│   │   ├── NotificationItem.swift
│   │   ├── DayPlan.swift       # TimeBlock, DayPlan, DayPlanBuilder
│   │   └── ChatMessage.swift   # Claude API message types
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   └── NotificationViewModel.swift
│   ├── Views/
│   │   ├── Dashboard/          # Dashboard, TaskCard, DayPlanner, Stats
│   │   ├── Chat/               # ChatView, MessageBubble
│   │   ├── Notifications/      # NotificationsView, NotificationRow
│   │   ├── Settings/           # Settings, API key config
│   │   └── Shared/             # OnboardingView
│   ├── Services/
│   │   ├── ClaudeService.swift     # Anthropic Claude API (streaming)
│   │   ├── SlackService.swift      # Slack Web API
│   │   ├── EmailService.swift      # Gmail REST API
│   │   ├── NotificationMonitor.swift # iOS UNUserNotificationCenter
│   │   ├── TaskPlannerService.swift  # Orchestrates all sources
│   │   └── PersistenceService.swift  # UserDefaults storage
│   ├── Utilities/
│   │   ├── AppTheme.swift      # Colors, gradients, modifiers
│   │   ├── Constants.swift     # API URLs, storage keys
│   │   └── DateUtils.swift     # Date formatting extensions
│   └── Resources/
│       ├── Info.plist
│       └── ButlerAI.entitlements
```

## How It Works

### Task Extraction Flow

```
Message arrives (Slack/Email/iOS notification)
    ↓
TaskPlannerService.syncAndProcess()
    ↓
Keyword filter (cost optimization — only actionable messages hit Claude API)
    ↓
ClaudeService.extractTasks() → Anthropic API
    ↓
ButlerTask created with source, priority, category
    ↓
DashboardViewModel publishes update → UI refreshes
```

### AI Day Planning

```
User taps "Plan My Day" or background refresh triggers
    ↓
Pending tasks sorted by priority
    ↓
ClaudeService.planDay() → Anthropic API
    ↓
DayPlanBuilder creates TimeBlocks from response
    ↓
Timeline view renders the schedule
```

### Background Monitoring

Butler registers `BGAppRefreshTask` with iOS, which wakes the app every ~15 minutes to:
1. Fetch new Slack messages from monitored channels
2. Fetch unread Gmail messages
3. Process any captured iOS notifications (WhatsApp/SMS)
4. Run AI task extraction on actionable messages
5. Reschedule notifications for upcoming tasks

## Configuration

### Changing Sync Frequency

Edit `Constants.UI.backgroundRefreshInterval` (default: 900 seconds = 15 min):

```swift
// ButlerAI/Utilities/Constants.swift
enum UI {
    static let backgroundRefreshInterval: TimeInterval = 900 // 15 min
}
```

### Adding Custom Keywords for Task Detection

Edit the keyword filter in `TaskPlannerService.isActionable()`:

```swift
let actionKeywords = [
    "please", "can you", "deadline", "urgent", ...
    "your_custom_keyword"  // Add here
]
```

### Changing Claude Model

```swift
// ButlerAI/Utilities/Constants.swift
enum API {
    static let claudeModel = "claude-opus-4-6"  // Change here
}
```

## Privacy & Security

- All API keys stored in UserDefaults (upgrade to Keychain for production)
- No data sent to any server except Anthropic API, Slack API, and Google API
- WhatsApp and SMS monitoring is read-only (preview only)
- Claude API calls include only message content (no metadata)

## Known Limitations

1. **WhatsApp/SMS**: iOS only provides ~100 char notification previews. Full content is not accessible without special carrier/enterprise entitlements.
2. **Background execution**: iOS limits background refresh frequency. In practice, syncs may happen every 15-60 minutes depending on device usage patterns.
3. **Keychain**: Current build uses UserDefaults for API key storage. For production, migrate to iOS Keychain for security.
4. **Gmail OAuth**: Requires a Google Cloud project. The OAuth flow currently shows instructions — the full web-based OAuth flow needs to be wired up with `ASWebAuthenticationSession`.

## Contributing

Built with SwiftUI + Claude claude-opus-4-6. PRs welcome for:
- CoreData migration (replacing UserDefaults)
- Keychain integration for API keys
- Full Gmail OAuth flow implementation
- WhatsApp Business API integration
- Apple Watch companion app
