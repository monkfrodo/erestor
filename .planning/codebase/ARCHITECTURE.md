# Architecture

**Analysis Date:** 2026-03-09

## Pattern Overview

**Overall:** Native macOS/iOS client-server app with a thin client pattern. The Swift app is a frontend that communicates with a remote Python backend (`erestor-api.kevineger.com.br`) via REST + SSE.

**Key Characteristics:**
- Menu bar accessory app (LSUIElement) with floating bubble + chat panel
- Dual-platform target: macOS (primary, full features) and iOS (secondary, simplified)
- All intelligence lives server-side; the app handles UI, notifications, and local system actions
- Pure AppKit for the bubble window (avoids focus stealing); WKWebView + `chat.html` for the chat panel
- SwiftUI used for the context panel (ContextPanelView) and iOS app entry point

## Layers

**App Entry / Lifecycle (`ErestorApp.swift`):**
- Purpose: Application bootstrap, singleton guard, window management, notification delegate
- Location: `ErestorApp/ErestorApp/ErestorApp.swift`
- Contains: `AppDelegate` (NSApplicationDelegate), `ErestorApp` (SwiftUI App with MenuBarExtra)
- Depends on: `ChatService`, `ActionHandler`, `BubbleWindowController`, `GlobalHotkey`
- Used by: macOS runtime (entry point via `@main`)

**iOS Entry (`iOS/ErestorApp_iOS.swift`):**
- Purpose: iOS app bootstrap, APNs registration, simplified UI
- Location: `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift`
- Contains: `AppDelegate_iOS` (UIApplicationDelegate), `ErestorIOSApp` (SwiftUI App)
- Depends on: `ChatService`, `ContextPanelView`, `ErestorConfig`
- Used by: iOS runtime (entry point via `@main`)

**Services Layer:**
- Purpose: Business logic, networking, system integration
- Location: `ErestorApp/ErestorApp/Services/`
- Contains: `ChatService`, `ActionHandler`, `BubbleWindowController`, `ErestorConfig`, `GlobalHotkey`
- Depends on: Models, Foundation, AppKit, Carbon
- Used by: Views, App entry points

**Models Layer:**
- Purpose: Data structures for API communication and internal state
- Location: `ErestorApp/ErestorApp/Models/`
- Contains: `ChatMessage`, `ContextSummary`, `GCalEvent`, `TaskItem`, `PushEvent`, `ChatAction`, `StreamDelta`
- Depends on: Foundation
- Used by: Services, Views

**Views Layer:**
- Purpose: UI components (SwiftUI + AppKit/WKWebView hybrid)
- Location: `ErestorApp/ErestorApp/Views/`
- Contains: Context panel, chat history, chat input, event cards, timer, polls, gate alerts
- Depends on: Services (ChatService), Models, DesignSystem
- Used by: BubbleWindowController, iOS entry point

**Design System:**
- Purpose: Centralized colors and fonts (Vesper Dark theme)
- Location: `ErestorApp/ErestorApp/Views/DesignSystem.swift`
- Contains: `DS` enum with color constants and font helpers
- Depends on: `Color+Hex` extension
- Used by: All Views

**Resources:**
- Purpose: Static assets loaded at runtime
- Location: `ErestorApp/ErestorApp/Resources/`
- Contains: `chat.html` (WKWebView chat UI), `icon.png` (bubble icon)

## Data Flow

**User Message Flow (Streaming):**

1. User types in chat input (WebView `chat.html` or SwiftUI `ChatInputView`)
2. WebView sends `{type: "send", text: "..."}` via `window.webkit.messageHandlers.chat.postMessage()`
3. `ChatWebViewVC.Coordinator.userContentController(_:didReceive:)` receives the message
4. Calls `ChatService.sendMessageStreaming(text)` which POSTs to `/api/chat/stream`
5. SSE response arrives as `data: {...}` lines; each chunk decoded as `SSEChunk`
6. `ChatService` publishes `streamDelta` (`.started` / `.delta` / `.finished`)
7. `BubbleWindowController.observeStreaming()` Combine sink pushes JS calls to WebView:
   - `beginStream()` -> `appendStreamChunk()` -> `finalizeStream()`
8. On `.finished`, if actions exist, `ActionHandler.execute()` runs them locally

**Push Event Flow (Server-Initiated):**

1. `ChatService.startPushPolling()` polls `/api/push/pending` every 3 seconds
2. Backend returns `PushEvent` array (message, poll, gate_inform, reminder, action, context_update)
3. `ChatService.handlePushEvent()` processes each event by type
4. For UI events (polls, gates, reminders): posts `Notification.Name.erestorPushMessageReceived`
5. `BubbleWindowController.observePushMessages()` shows macOS notification + notification dot
6. `ContextPanelView.onReceive(pushObserver)` shows inline poll/gate cards

**Context Flow:**

1. `BubbleWindowController.startContextPolling()` calls `ChatService.loadContext()` every 5 seconds
2. `ChatService` GETs `/api/context` and decodes into `ContextSummary`
3. SwiftUI views observe `chatService.context` and render current event, timer, next event, tasks

**State Management:**
- `ChatService` is an `@MainActor ObservableObject` — single source of truth
- Published properties: `messages`, `isLoading`, `context`, `serverOnline`, `actions`, `isStreaming`, `streamDelta`
- macOS: `BubbleWindowController` holds a reference to `ChatService` and uses Combine sinks
- iOS: `ContextPanelView` observes `ChatService` via `@ObservedObject`

## Key Abstractions

**ChatService (`Services/ChatService.swift`):**
- Purpose: Central hub for all API communication and app state
- Pattern: ObservableObject with async/await networking
- Manages: message history, SSE streaming, status polling, push polling, context loading
- 516 lines — the largest service

**BubbleWindowController (`Services/BubbleWindowController.swift`):**
- Purpose: Manages the floating bubble + chat panel window system
- Pattern: Singleton (`shared`) with pure AppKit for bubble, WKWebView for chat
- Manages: window creation, positioning, drag handling, stream observation, notification dot
- 662 lines — the largest file in the codebase

**ActionHandler (`Services/ActionHandler.swift`):**
- Purpose: Executes system-level actions from AI responses
- Pattern: Singleton (`shared`) with command pattern (switch on action.type)
- Handles 19+ action types: reminder, open_project, open_url, shell, timer, gcal, music, screenshot, etc.
- Uses AppleScript (NSAppleScript) for iTerm and Music control
- Backend actions (timer, gcal, tasks) call API endpoints asynchronously

**ChatAction (`Models/Message.swift`):**
- Purpose: Represents a command from the backend to execute locally
- Pattern: Polymorphic struct with optional fields per action type
- All 16+ optional fields decoded from a single JSON structure

**ErestorConfig (`Services/ErestorConfig.swift`):**
- Purpose: Centralized API base URL and auth token
- Pattern: Static enum with helper methods `url(for:)` and `authorize(&request)`
- Contains hardcoded API URL and bearer token

## Entry Points

**macOS App (`ErestorApp.swift`):**
- Location: `ErestorApp/ErestorApp/ErestorApp.swift`
- Triggers: App launch, LaunchAgent (`com.erestor.app`)
- Responsibilities: Singleton guard, bubble/chat setup, hotkey registration, notification handling
- Activation policy: `.accessory` (no dock icon, no main menu)

**iOS App (`iOS/ErestorApp_iOS.swift`):**
- Location: `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift`
- Triggers: App launch on iOS
- Responsibilities: APNs setup, device token registration, ContextPanelView as root

**Global Hotkey (Cmd+Shift+E):**
- Location: `ErestorApp/ErestorApp/Services/GlobalHotkey.swift`
- Triggers: Keyboard shortcut anywhere in macOS
- Uses: Carbon `RegisterEventHotKey` (no Accessibility permission needed)

**WebView Message Handler (`chat`):**
- Location: `ErestorApp/ErestorApp/Views/ChatWebViewVC.swift`
- Triggers: JavaScript `window.webkit.messageHandlers.chat.postMessage({...})`
- Handles: `send`, `close_panel`, `timer_stop`, `poll_response`

**Notification Actions:**
- Location: `ErestorApp/ErestorApp/ErestorApp.swift` (sendPushResponse)
- Triggers: User interacts with macOS notification buttons
- Categories: `POLL_ENERGY`, `POLL_QUALITY`, `GATE_INFORM`, `REMINDER`

## Error Handling

**Strategy:** Fail silently with logging. The app prioritizes staying alive and responsive over strict error propagation.

**Patterns:**
- Network errors: catch block logs via `os.Logger`, shows error message in chat ("Erro de conexao com o servidor")
- Server status: progressive degradation with `consecutiveFailures` counter and 30-second grace period
- Timeout handling: 5-minute timeout for streaming, fallback error message if recently online vs generic error
- Action failures: individual actions log errors but don't block subsequent actions in the sequence
- JSON decode failures: `try?` with fallback to legacy response formats

## Cross-Cutting Concerns

**Logging:** `os.Logger` with subsystem `org.integros.erestor` and per-file categories (`ChatService`, `ActionHandler`, `BubbleWindow`, `ChatWebViewVC`, `GlobalHotkey`). Also uses `NSLog` for critical events.

**Validation:** Minimal — trusts server responses, validates URLs and file paths before use.

**Authentication:** Bearer token in `ErestorConfig.apiToken`, applied via `ErestorConfig.authorize(&request)` to every outbound request.

**Threading:** All services are `@MainActor`. Network calls use `async/await` with `nonisolated` for status polling. AppleScript runs on `DispatchQueue.main`. Combine sinks receive on `DispatchQueue.main`.

**Window Management:** Aggressive cleanup of stale windows (1-second timer in AppDelegate), bubble watchdog (5-second periodic check + workspace change observer), singleton guard that terminates old instances.

---

*Architecture analysis: 2026-03-09*
