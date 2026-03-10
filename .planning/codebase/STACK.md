# Technology Stack

**Analysis Date:** 2026-03-09

## Languages

**Primary:**
- Swift 5.9 - All app logic (macOS + iOS targets)
- HTML/CSS/JavaScript - Chat UI rendered in WKWebView (`ErestorApp/ErestorApp/Resources/chat.html`)

**Secondary:**
- Python 3 - Backend bot/agents (lives in `~/claude-sync/produtividade/`, NOT in this repo)

## Runtime

**Environment:**
- macOS 26.0+ (primary target)
- iOS 17.0+ (secondary target)

**Build Tool:**
- XcodeGen (`ErestorApp/project.yml`) generates `ErestorApp.xcodeproj`
- Xcode 16.0+

**Package Manager:**
- No SPM dependencies (zero external Swift packages)
- All dependencies are Apple system frameworks

## Frameworks

**Core:**
- SwiftUI - App lifecycle, MenuBarExtra, iOS UI (`ContextPanelView`, `PollCardView`, etc.)
- AppKit (macOS) - NSPanel floating windows, drag handling, NSPasteboard, NSWorkspace
- UIKit (iOS) - UIApplicationDelegate, APNs registration
- WebKit/WKWebView - Chat interface renders `chat.html` with JS bridge via `WKScriptMessageHandler`
- Carbon - Global hotkey registration (Cmd+Shift+E) via `RegisterEventHotKey`

**Networking:**
- Foundation/URLSession - All HTTP calls (REST + SSE streaming)
- No third-party HTTP libraries

**Notifications:**
- UserNotifications - Local notifications, notification categories (POLL_ENERGY, POLL_QUALITY, GATE_INFORM, REMINDER)

**Logging:**
- `os.Logger` (unified logging) - Subsystem: `org.integros.erestor`, categories: ChatService, ActionHandler, BubbleWindow, GlobalHotkey, ChatWebViewVC

## Key Dependencies

**System Frameworks (no external deps):**
- `Carbon.framework` - Global hotkey (Cmd+Shift+E) without Accessibility permissions
- `WebKit.framework` - WKWebView for chat UI
- `UserNotifications.framework` - Push/local notifications
- `AppKit.framework` - Window management, AppleScript execution
- `Combine` - Reactive bindings (`@Published`, `AnyCancellable`, `$streamDelta.sink`)

**Web Fonts (loaded in chat.html via Google Fonts CDN):**
- IBM Plex Mono (light, regular, medium, italic)
- Inter (light, regular, medium)

## Configuration

**API Configuration:**
- Hardcoded in `ErestorApp/ErestorApp/Services/ErestorConfig.swift`
- Base URL: `https://erestor-api.kevineger.com.br`
- Auth: Bearer token (hardcoded)
- All API calls use `ErestorConfig.authorize(&request)` to add auth header
- All URL construction uses `ErestorConfig.url(for: "/api/...")`

**Build Configuration:**
- `ErestorApp/project.yml` - XcodeGen project spec
- `ErestorApp/ErestorApp/Info.plist` - macOS Info.plist
- `ErestorApp/ErestorApp/iOS/Info.plist` - iOS Info.plist
- `ErestorApp/ErestorApp/ErestorApp.entitlements` - macOS entitlements (empty)
- `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.entitlements` - iOS entitlements (APNs)

**App Settings:**
- `LSUIElement: true` - Menu bar only app (no Dock icon)
- `NSAllowsLocalNetworking: true` - Allows localhost connections
- `NSAppleEventsUsageDescription` - AppleScript permission for iTerm/Music control
- Bundle ID: `org.integros.erestor` (macOS), `org.integros.erestor.ios` (iOS)

## Platform Requirements

**Development:**
- macOS 26.0+ (Tahoe)
- Xcode 16.0+
- XcodeGen (`brew install xcodegen`)
- No external package dependencies to install

**Build Commands:**
```bash
cd ErestorApp
xcodegen generate
xcodebuild -project ErestorApp.xcodeproj -scheme ErestorApp -configuration Debug build
```

**Production:**
- Self-hosted macOS app (code-signed with ad-hoc identity `-`)
- Managed by LaunchAgent `com.erestor.app` (RunAtLoad)
- Backend server: `com.erestor.local-server` LaunchAgent runs `erestor_local.py` on localhost:8766

## Two-Target Architecture

**macOS target (`ErestorApp`):**
- Floating bubble window + chat panel (NSPanel)
- Global hotkey (Carbon)
- AppleScript actions (iTerm, Music, Spotify)
- MenuBarExtra system tray icon
- Sources: all files except `iOS/` directory

**iOS target (`ErestorApp-iOS`):**
- SwiftUI-only interface (ContextPanelView)
- APNs device token registration
- No bubble/hotkey/AppleScript/WebView
- Sources: excludes `ErestorApp.swift`, `BubbleWindowController.swift`, `GlobalHotkey.swift`, `ActionHandler.swift`, `ChatWebViewVC.swift`

---

*Stack analysis: 2026-03-09*
