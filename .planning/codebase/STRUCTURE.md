# Codebase Structure

**Analysis Date:** 2026-03-09

## Directory Layout

```
erestor/
├── .planning/              # GSD planning documents
│   └── codebase/           # Architecture analysis (this file)
├── docs/                   # Project documentation
│   ├── architecture.md     # System architecture diagrams
│   ├── native-app-plan.md  # Native app planning
│   ├── technical-decisions.md  # Decision log
│   └── update-protocol.md  # Doc update guidelines
├── ErestorApp/             # Swift app source (macOS + iOS)
│   ├── project.yml         # XcodeGen project spec
│   ├── build/              # Build output (gitignored)
│   ├── ErestorApp.xcodeproj/  # Generated Xcode project
│   └── ErestorApp/         # App source code
│       ├── ErestorApp.swift       # macOS app entry point
│       ├── Info.plist             # macOS app config
│       ├── ErestorApp.entitlements # macOS entitlements
│       ├── Assets.xcassets/       # macOS assets (AppIcon, MenuBarIcon)
│       ├── Extensions/           # Swift extensions
│       │   └── Color+Hex.swift
│       ├── Helpers/              # Utility helpers (empty)
│       ├── Models/               # Data models
│       │   └── Message.swift
│       ├── Resources/            # Runtime resources
│       │   ├── chat.html         # WKWebView chat UI
│       │   └── icon.png          # Floating bubble icon
│       ├── Services/             # Business logic + networking
│       │   ├── ActionHandler.swift
│       │   ├── BubbleWindowController.swift
│       │   ├── ChatService.swift
│       │   ├── ErestorConfig.swift
│       │   └── GlobalHotkey.swift
│       ├── Views/                # UI components
│       │   ├── ChatHistoryView.swift
│       │   ├── ChatInputView.swift
│       │   ├── ChatWebViewVC.swift
│       │   ├── ContextPanelView.swift
│       │   ├── DayTimelineView.swift
│       │   ├── DesignSystem.swift
│       │   ├── EventCardView.swift
│       │   ├── GateAlertView.swift
│       │   ├── NextEventView.swift
│       │   ├── PollCardView.swift
│       │   ├── TaskListView.swift
│       │   └── TimerChipView.swift
│       └── iOS/                  # iOS-specific files
│           ├── ErestorApp_iOS.swift    # iOS app entry point
│           ├── Info.plist              # iOS app config
│           ├── ErestorApp_iOS.entitlements
│           └── Assets.xcassets/       # iOS assets
├── CLAUDE.md               # Claude Code project context
├── README.md               # Project overview
├── prototipo-painel.html   # HTML prototype of the panel UI
└── .gitignore
```

## Directory Purposes

**`docs/`:**
- Purpose: Human-readable project documentation
- Contains: Architecture docs, technical decisions, planning documents
- Key files: `docs/architecture.md` (system diagram), `docs/technical-decisions.md` (rationale log)

**`ErestorApp/`:**
- Purpose: Root of the Swift native app project
- Contains: XcodeGen spec, Xcode project, app source code
- Key files: `ErestorApp/project.yml` (XcodeGen project definition)

**`ErestorApp/ErestorApp/Services/`:**
- Purpose: Core business logic, API communication, system integration
- Contains: 5 service files totaling ~1,746 lines
- Key files: `ChatService.swift` (API client + state), `BubbleWindowController.swift` (window system), `ActionHandler.swift` (local actions)

**`ErestorApp/ErestorApp/Views/`:**
- Purpose: All UI components (SwiftUI + AppKit hybrid)
- Contains: 12 view files totaling ~978 lines
- Key files: `ContextPanelView.swift` (main panel layout), `ChatWebViewVC.swift` (WebView bridge), `DesignSystem.swift` (DS enum)

**`ErestorApp/ErestorApp/Models/`:**
- Purpose: Data structures for API communication and internal state
- Contains: Single file with all models (156 lines)
- Key files: `Message.swift` (ChatMessage, ContextSummary, ChatAction, PushEvent, GCalEvent, TaskItem)

**`ErestorApp/ErestorApp/Resources/`:**
- Purpose: Static assets bundled with the app
- Contains: `chat.html` (self-contained chat UI loaded in WKWebView), `icon.png` (bubble image)

**`ErestorApp/ErestorApp/iOS/`:**
- Purpose: iOS-specific entry point and configuration
- Contains: iOS app delegate, Info.plist, entitlements, asset catalog
- Note: Shares most code with macOS via `#if os(macOS)` / `#if os(iOS)` conditionals

**`ErestorApp/ErestorApp/Extensions/`:**
- Purpose: Swift type extensions
- Contains: `Color+Hex.swift` (Color init from hex string)

**`ErestorApp/ErestorApp/Helpers/`:**
- Purpose: Utility helpers (currently empty)

## Key File Locations

**Entry Points:**
- `ErestorApp/ErestorApp/ErestorApp.swift`: macOS app entry (`@main`, AppDelegate, MenuBarExtra)
- `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift`: iOS app entry (`@main`, AppDelegate_iOS)

**Configuration:**
- `ErestorApp/project.yml`: XcodeGen project spec (targets, settings, deployment targets)
- `ErestorApp/ErestorApp/Services/ErestorConfig.swift`: API base URL + auth token
- `ErestorApp/ErestorApp/Info.plist`: macOS app settings (LSUIElement, ATS, AppleEvents)
- `ErestorApp/ErestorApp/iOS/Info.plist`: iOS app settings

**Core Logic:**
- `ErestorApp/ErestorApp/Services/ChatService.swift`: All API communication (chat, streaming, context, push polling, status)
- `ErestorApp/ErestorApp/Services/BubbleWindowController.swift`: Window management (bubble, chat panel, drag, notification dot)
- `ErestorApp/ErestorApp/Services/ActionHandler.swift`: 19+ local action types (AppleScript, shell, clipboard, etc.)
- `ErestorApp/ErestorApp/Services/GlobalHotkey.swift`: Cmd+Shift+E Carbon hotkey
- `ErestorApp/ErestorApp/Models/Message.swift`: All data models in one file

**UI:**
- `ErestorApp/ErestorApp/Views/ContextPanelView.swift`: Main panel layout (header, events, tasks, chat)
- `ErestorApp/ErestorApp/Views/ChatWebViewVC.swift`: WKWebView bridge (JS <-> Swift)
- `ErestorApp/ErestorApp/Views/DesignSystem.swift`: Vesper Dark color palette + font helpers
- `ErestorApp/ErestorApp/Resources/chat.html`: Self-contained HTML/CSS/JS chat interface

**Prototype:**
- `prototipo-painel.html`: HTML prototype of the panel design (reference for SwiftUI views)

## Naming Conventions

**Files:**
- PascalCase for Swift files matching the primary type: `ChatService.swift`, `ActionHandler.swift`
- Compound names with category suffix: `ChatInputView.swift`, `EventCardView.swift`, `ChatWebViewVC.swift`
- Extension files use `Type+Extension.swift` pattern: `Color+Hex.swift`
- iOS-specific files use `_iOS` suffix: `ErestorApp_iOS.swift`, `ErestorApp_iOS.entitlements`

**Directories:**
- PascalCase for source directories: `Services/`, `Views/`, `Models/`, `Extensions/`, `Helpers/`, `Resources/`
- Lowercase for non-source directories: `docs/`, `build/`

**Types:**
- PascalCase for types: `ChatService`, `BubbleWindowController`, `ContextPanelView`
- Views use `View` suffix: `ChatInputView`, `EventCardView`, `PollCardView`
- Controllers use `Controller` or `VC` suffix: `BubbleWindowController`, `ChatWebViewController`

**Design System:**
- Single `DS` enum as namespace for all design tokens
- Color constants: lowercase names (`surface`, `border`, `muted`, `green`, `amber`)
- Font helpers: `DS.mono(_:weight:)`, `DS.body(_:weight:)`

## Where to Add New Code

**New Service (API integration, system feature):**
- Implementation: `ErestorApp/ErestorApp/Services/NewService.swift`
- Follow pattern: `@MainActor class`, singleton via `static let shared`, use `os.Logger`
- Wire up in `ErestorApp.swift` AppDelegate

**New View (UI component):**
- Implementation: `ErestorApp/ErestorApp/Views/NewComponentView.swift`
- Follow pattern: `struct NewComponentView: View`, use `DS` colors/fonts
- Compose into `ContextPanelView` or `BubbleWindowController`

**New Model (API response type):**
- Implementation: `ErestorApp/ErestorApp/Models/Message.swift` (add to existing file)
- Follow pattern: `struct NewModel: Codable` with `CodingKeys` for snake_case mapping

**New Action Type:**
- Add case to `ActionHandler.execute()` switch in `ErestorApp/ErestorApp/Services/ActionHandler.swift`
- Add label to `ActionHandler.actionLabels` dictionary
- Add backend actions to `ActionHandler.backendActions` set if they call the API
- Add fields to `ChatAction` struct in `ErestorApp/ErestorApp/Models/Message.swift`

**New Extension:**
- Implementation: `ErestorApp/ErestorApp/Extensions/Type+Extension.swift`

**New Push Event Type:**
- Add case to `ChatService.handlePushEvent()` in `ErestorApp/ErestorApp/Services/ChatService.swift`
- Add notification category in `ErestorApp.swift` `registerNotificationCategories()` if actionable
- Add UI handling in `ContextPanelView.handlePush()` if inline display needed

**iOS-specific code:**
- Place in `ErestorApp/ErestorApp/iOS/` directory
- Use `#if os(iOS)` guards in shared files
- Check `project.yml` excludes for macOS-only files

## Special Directories

**`ErestorApp/build/`:**
- Purpose: Xcode build output
- Generated: Yes
- Committed: No (gitignored)

**`ErestorApp/ErestorApp.xcodeproj/`:**
- Purpose: Xcode project file (generated by XcodeGen from `project.yml`)
- Generated: Yes (via `xcodegen generate`)
- Committed: Yes (for direct Xcode use)

**`ErestorApp/.claude-flow/`:**
- Purpose: Claude Flow agent session data
- Generated: Yes
- Committed: No (development tool state)

**`ErestorApp/ErestorApp/Helpers/`:**
- Purpose: Reserved for utility helpers
- Currently empty
- Committed: Yes (placeholder)

## Platform-Specific Build Rules

The `project.yml` defines two targets with shared source and platform-specific excludes:

**macOS target (`ErestorApp`):**
- Excludes: `iOS/` directory
- Includes all Services, Views, Models, Extensions, Resources
- Dependencies: `Carbon.framework` (for global hotkey)

**iOS target (`ErestorApp-iOS`):**
- Excludes: `ErestorApp.swift`, `Info.plist`, `ErestorApp.entitlements`, both `Assets.xcassets`, and macOS-only services:
  - `Services/BubbleWindowController.swift`
  - `Services/GlobalHotkey.swift`
  - `Services/ActionHandler.swift`
  - `Views/ChatWebViewVC.swift`
- Shared code uses `#if os(macOS)` / `#if os(iOS)` conditionals

---

*Structure analysis: 2026-03-09*
