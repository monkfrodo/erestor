# Coding Conventions

**Analysis Date:** 2026-03-09

## Naming Patterns

**Files:**
- Swift files use PascalCase: `ChatService.swift`, `ActionHandler.swift`, `ContextPanelView.swift`
- Views suffixed with `View`: `EventCardView.swift`, `PollCardView.swift`, `ChatInputView.swift`
- Services have no suffix, just descriptive PascalCase: `ChatService.swift`, `GlobalHotkey.swift`
- Extensions use `Type+Feature` pattern: `Color+Hex.swift`

**Types (structs, classes, enums):**
- PascalCase: `ChatMessage`, `ContextSummary`, `BubbleWindowController`
- Enums use short names when scoped: `DS` (design system), `EventType`, `PollType`
- Nested types are common for API response models: `ContextSummary.TimerInfo`, `GCalEvent.GCalDateTime`

**Functions:**
- camelCase: `sendMessageStreaming(_:)`, `loadHistory()`, `openProject(path:)`
- Verbs for actions: `execute(_:)`, `toggleChat()`, `showChat()`, `hideChat()`
- Prefixed `private` helpers with descriptive names: `appendErrorMessage()`, `parseRelativeTime(_:)`

**Variables/Properties:**
- camelCase: `serverOnline`, `isChatVisible`, `isStreaming`
- Boolean properties prefixed with `is`/`has`: `isLoading`, `isStreaming`, `isChatVisible`, `isDragging`
- Private properties without underscore prefix: `lastSuccessfulRequest`, `consecutiveFailures`

**Constants:**
- Static let in enums: `DS.surface`, `DS.green`, `ErestorConfig.apiBaseURL`
- Layout constants as private let: `bubbleSize`, `chatWidth`, `chatHeight`, `margin`

## Code Style

**Formatting:**
- No automated formatter detected (no SwiftFormat/SwiftLint config files)
- 4-space indentation throughout
- Opening brace on same line as declaration
- Single blank line between methods
- Trailing commas in array literals

**Line Length:**
- No enforced limit, but lines generally stay under 120 characters
- Long lines broken at logical points (function arguments, chained calls)

## Import Organization

**Order:**
1. Foundation / system frameworks (`Foundation`, `AppKit`, `SwiftUI`, `WebKit`)
2. System-specific frameworks (`Carbon`, `UserNotifications`, `Combine`)
3. OS logging (`os`)

**Pattern:**
- No third-party dependencies -- all imports are Apple frameworks
- Platform-conditional imports used: `#if os(macOS) / import AppKit / #else / import UIKit / #endif`

## Architecture Patterns

**Singletons:**
- Services use `static let shared`: `ActionHandler.shared`, `GlobalHotkey.shared`, `BubbleWindowController.shared`
- Private `init()` to enforce singleton pattern

**MainActor Isolation:**
- All `ObservableObject` classes annotated with `@MainActor`: `ChatService`, `BubbleWindowController`, `ActionHandler`
- Network calls explicitly marked `nonisolated` when they run off main thread: `ChatService.pollStatus()`

**Combine Observation:**
- `@Published` properties for reactive state: `messages`, `isLoading`, `serverOnline`, `streamDelta`
- `AnyCancellable` stored as instance properties for Combine subscriptions
- `.receive(on: DispatchQueue.main).sink` pattern for UI updates from publishers

**SwiftUI Views:**
- Struct-based views with `let` parameters (no `@Binding` used)
- Callbacks passed as closures: `onSend: (String) -> Void`, `onResponse: (String) -> Void`, `onClose: (() -> Void)?`
- `DS` enum referenced for all colors and fonts -- never use raw Color/Font values in views

**AppKit Integration:**
- `NSPanel` used for floating windows (bubble + chat panel)
- Custom `NSView` subclasses for drag handling: `BubbleDragView`, `DraggableHeaderView`, `ResizeHandleView`
- `NSViewControllerRepresentable` bridges WKWebView into SwiftUI: `ChatWebViewVC`

## Error Handling

**Network Errors:**
- `do/catch` blocks around `URLSession` calls
- Errors logged via `os.Logger`, user-facing error messages appended as assistant messages in Portuguese
- Silent failure pattern for non-critical endpoints (context polling, push polling): catch block is empty or logs warning only
- `appendErrorMessage()` centralizes error message creation with connection failure text

**Guard-Early-Return:**
- Extensively used: `guard let url = ErestorConfig.url(for: ...) else { return }`
- Guards validate inputs before proceeding: `guard !name.isEmpty`, `guard !cmd.isEmpty`

**No Throwing Functions:**
- The codebase does not use `throws` in its own functions
- All error handling is done via `try?` (silent) or `do/catch` (logged)
- `try?` used for JSON encoding: `request.httpBody = try? JSONEncoder().encode(body)`

## Logging

**Framework:** Apple `os.Logger`

**Pattern:**
- One private logger per file at top level: `private let logger = Logger(subsystem: "org.integros.erestor", category: "CategoryName")`
- Categories match the class/purpose: `"ChatService"`, `"ActionHandler"`, `"BubbleWindow"`, `"GlobalHotkey"`
- Log levels used:
  - `logger.info()` for successful operations
  - `logger.warning()` for recoverable issues
  - `logger.error()` for failures
- `NSLog()` used occasionally for critical debug points: `NSLog("[Erestor] ...")`
- Prefix `[Erestor]` in NSLog messages for easy filtering

## Comments

**MARK Comments:**
- Extensively used to section code: `// MARK: - Setup`, `// MARK: - Streaming send (SSE)`, `// MARK: - Helpers`
- Every major section within a class has a MARK comment

**Inline Comments:**
- Explain "why" not "what": `// Singleton guard -- kill stale instances instead of exiting`
- Document workarounds: `// NSAppleScript must run on main thread for thread safety`
- Document protocol: `// ALWAYS publish .finished BEFORE actions -- this ensures finalizeStream() runs`

**Doc Comments:**
- `///` used for important types and functions: `/// Registers Cmd+Shift+E as a global hotkey`
- Not comprehensive -- many functions lack doc comments

## Function Design

**Size:**
- Most functions under 30 lines
- `sendMessageStreaming()` is the largest at ~120 lines (SSE parsing loop)
- `execute()` in `ActionHandler` is a large switch statement (~80 lines) but each case is concise

**Parameters:**
- Named parameters with descriptive labels: `scheduleReminder(text:at:)`, `openProject(path:)`
- Default parameter values used sparingly: `actionType: String? = nil`

**Return Values:**
- Async functions return `Void` -- state is mutated via `@Published` properties
- Helper functions return optionals: `parseTime(_:) -> (Int, Int)?`, `parseRelativeTime(_:) -> Int?`

## Module Design

**File Organization:**
- One primary type per file
- Supporting types (enums, small structs) co-located with their consumer: `EventType` in `EventCardView.swift`, `SSEChunk` in `ChatService.swift`
- Private types marked `private`: `private struct SSEChunk`, `private struct ChatResponse`

**Exports:**
- No barrel files -- each file is self-contained
- Internal access control (default) for most types
- `private` used extensively for implementation details

## Design System Usage

**Colors:**
- Always use `DS.*` constants: `DS.surface`, `DS.bright`, `DS.green`, `DS.border`
- Never hardcode hex values in views -- all defined in `ErestorApp/ErestorApp/Views/DesignSystem.swift`
- Exception: AppKit views in `BubbleWindowController.swift` use `NSColor(red:green:blue:alpha:)` directly (no SwiftUI Color)

**Fonts:**
- Use `DS.mono(_:weight:)` for monospaced text (IBM Plex Mono with SF Mono fallback)
- Use `DS.body(_:weight:)` for body text (Inter with SF Pro fallback)
- Never use `.font(.system(...))` directly in views

**Spacing:**
- Manual padding values (no spacing constants): `.padding(.horizontal, 14)`, `.padding(.vertical, 8)`
- Consistent values across views: 14pt horizontal padding, 12pt vertical padding, 10pt corner radius

## API Communication

**Request Pattern:**
```swift
guard let url = ErestorConfig.url(for: "/api/endpoint") else { return }
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.timeoutInterval = 10
ErestorConfig.authorize(&request)
request.httpBody = try? JSONEncoder().encode(body)
let (data, response) = try await URLSession.shared.data(for: request)
```

**All networking goes through `ErestorConfig`:**
- `ErestorConfig.url(for:)` builds URLs
- `ErestorConfig.authorize(&request)` adds Bearer token
- Centralized in `ErestorApp/ErestorApp/Services/ErestorConfig.swift`

## Codable Models

**CodingKeys Pattern:**
- Custom `CodingKeys` used to map `snake_case` API fields to `camelCase` Swift properties
- Example in `ContextSummary`: `case dayPhase = "day_phase"`, `case timerType = "timer_type"`
- `Identifiable` conformance uses `let id = UUID()` (excluded from Codable via CodingKeys)

## Async/Concurrency

**Task Usage:**
- `Task { await ... }` for fire-and-forget async operations from synchronous contexts
- `Task { @MainActor in ... }` for ensuring UI updates from callbacks
- Long-running polling uses `Task` stored as instance property with cancellation support

**Polling Pattern:**
```swift
private func startPolling() {
    pollTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: N * 1_000_000_000)
            guard let self else { break }
            await self.doWork()
        }
    }
}
```

---

*Convention analysis: 2026-03-09*
