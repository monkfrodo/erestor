# Codebase Concerns

**Analysis Date:** 2026-03-09

## Tech Debt

**Hardcoded API credentials in source code:**
- Issue: API base URL and bearer token are hardcoded as string literals in two separate places, committed to git
- Files: `ErestorApp/ErestorApp/Services/ErestorConfig.swift` (lines 6-7), `ErestorApp/ErestorApp/Resources/chat.html` (lines 965-966)
- Impact: Credentials are exposed in version control. Rotating the token requires changing code in two places and rebuilding
- Fix approach: Move credentials to a plist file excluded from git, or read from Keychain at runtime. The chat.html should receive the token via a JS bridge call from Swift instead of embedding it

**Duplicate context polling (Swift + JavaScript):**
- Issue: Both `BubbleWindowController.startContextPolling()` and the `chat.html` JavaScript `setInterval(fetchContext, 5000)` independently poll `/api/context` every 5 seconds, doubling API calls
- Files: `ErestorApp/ErestorApp/Services/BubbleWindowController.swift` (line 344-350), `ErestorApp/ErestorApp/Resources/chat.html` (lines 968-984)
- Impact: Double the network traffic for context. The Swift polling result (`chatService.context`) is used by `ContextPanelView` (SwiftUI) which is only used on iOS. On macOS the chat.html handles its own context rendering. This means the Swift polling is wasted on macOS
- Fix approach: On macOS, remove the Swift-side context polling since chat.html is self-contained. Alternatively, have Swift poll once and inject context into the WebView via `updateContext()` JS call, removing the JS-side fetch

**Legacy non-streaming send method:**
- Issue: `ChatService.sendMessage()` (non-streaming) is still present as a "legacy fallback" but nothing in the codebase calls it. It also has two fallback decode paths (APIResponse and ChatResponse)
- Files: `ErestorApp/ErestorApp/Services/ChatService.swift` (lines 183-236)
- Impact: Dead code that adds maintenance burden and confusion about which API format is canonical
- Fix approach: Remove `sendMessage()` and the `ChatResponse` struct if the streaming endpoint is the sole path

**Aggressive window cleanup timer:**
- Issue: A `Timer` fires every 1 second to close "stale windows" that macOS might create. This is a workaround for SwiftUI `MenuBarExtra` creating unwanted windows
- Files: `ErestorApp/ErestorApp/ErestorApp.swift` (lines 66-70), `closeStaleWindows()` (lines 185-203)
- Impact: Constant timer polling on the main thread. The per-second cadence is excessive for what should be a rare occurrence
- Fix approach: Increase interval to 10-30 seconds, or use `NSApp.windows` observation via KVO instead of polling

**Empty Helpers directory:**
- Issue: `ErestorApp/ErestorApp/Helpers/` directory exists but contains no files
- Files: `ErestorApp/ErestorApp/Helpers/`
- Impact: Dead directory pollutes project structure
- Fix approach: Remove the empty directory or populate it with actual helpers extracted from service files

**Singleton guard uses Thread.sleep on main thread:**
- Issue: When killing stale app instances at launch, the code calls `Thread.sleep(forTimeInterval: 0.5)` which blocks the main thread
- Files: `ErestorApp/ErestorApp/ErestorApp.swift` (line 21)
- Impact: 500ms main thread freeze on every app launch. Usually harmless for a background app but is an anti-pattern
- Fix approach: Use async/await or DispatchQueue.main.asyncAfter for the delay, or use a notification-based approach to detect process termination

## Security Considerations

**Shell command execution without sanitization:**
- Risk: `ActionHandler.runShell(cmd:)` executes arbitrary shell commands received from the backend API via `Process("/bin/bash", ["-c", cmd])`. If the backend is compromised, arbitrary code execution is possible on the user's machine
- Files: `ErestorApp/ErestorApp/Services/ActionHandler.swift` (lines 279-293)
- Current mitigation: Backend is authenticated with a bearer token. Commands originate from the AI assistant
- Recommendations: Add an allowlist of permitted commands or command prefixes. Log all executed commands persistently. Consider sandboxing via an XPC service

**AppleScript injection in openProject and musicControl:**
- Risk: User-controlled input (project path, music app name) is interpolated into AppleScript strings. While the path has single-quote escaping, the musicControl `action` parameter is directly interpolated without any escaping
- Files: `ErestorApp/ErestorApp/Services/ActionHandler.swift` (lines 218-236 for openTerminalAt, lines 313-345 for musicControl)
- Current mitigation: The `action` parameter comes from hardcoded strings in the `execute()` switch ("playpause", "next track", "previous track"), not from user input
- Recommendations: Add explicit validation that the action parameter is one of the expected values before interpolating into AppleScript

**API token transmitted over HTTPS only:**
- Risk: Bearer token is sent in every request. If the API endpoint ever downgrades to HTTP, the token leaks
- Files: `ErestorApp/ErestorApp/Services/ErestorConfig.swift` (line 6)
- Current mitigation: URL uses `https://`. App Transport Security is configured to allow local networking only (`NSAllowsLocalNetworking`)
- Recommendations: The current setup is acceptable. Ensure the API URL remains HTTPS

## Performance Bottlenecks

**DateFormatter created on every call:**
- Problem: `ChatService.currentTime()` and `ContextPanelView.currentTimeString()` create a new `DateFormatter` on every invocation. DateFormatter initialization is expensive
- Files: `ErestorApp/ErestorApp/Services/ChatService.swift` (lines 457-462), `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (lines 207-213)
- Cause: DateFormatter allocation and locale/timezone setup is repeated per call
- Improvement path: Create static or cached DateFormatter instances. Use `ISO8601DateFormatter` where applicable

**Push polling at 3-second intervals:**
- Problem: `ChatService.startPushPolling()` polls `/api/push/pending` every 3 seconds regardless of app state (chat visible or not)
- Files: `ErestorApp/ErestorApp/Services/ChatService.swift` (lines 280-288)
- Cause: Polling is the simplest approach but generates constant network traffic
- Improvement path: Consider WebSocket or Server-Sent Events for push delivery. At minimum, increase the interval when the app is idle or the chat is hidden

**Multiple concurrent polling loops:**
- Problem: The app runs 4+ concurrent polling/timer loops simultaneously: status polling (5-60s), push polling (3s), context polling from Swift (5s), context polling from JS (5s), window cleanup (1s), bubble watchdog (5s)
- Files: Multiple across `ChatService.swift`, `BubbleWindowController.swift`, `ErestorApp.swift`, `chat.html`
- Cause: Each feature was added independently without consolidating polling
- Improvement path: Consolidate into a single polling coordinator that batches requests or uses a single WebSocket connection for all real-time data

## Fragile Areas

**Stream rendering coordination between Swift and WebView:**
- Files: `ErestorApp/ErestorApp/Views/ChatWebViewVC.swift` (entire file), `ErestorApp/ErestorApp/Services/BubbleWindowController.swift` (lines 227-283)
- Why fragile: Message rendering is split between two paths -- `ChatWebViewVC.updateNSViewController` (SwiftUI representable) and `BubbleWindowController.observeStreaming` (Combine sink). Both push JavaScript calls to the same WebView. The `streamFinishedMessageCount`, `renderedCount`, `wasStreaming`, and `lastStreamDeltaID` variables coordinate deduplication but the logic is complex and has edge cases (evidenced by the "Safety" cleanup block at line 74)
- Safe modification: When changing streaming behavior, test: (1) normal stream, (2) error during stream, (3) rapid consecutive messages, (4) clear history during stream
- Test coverage: Zero automated tests

**ChatWebViewVC used in two incompatible ways:**
- Files: `ErestorApp/ErestorApp/Views/ChatWebViewVC.swift`
- Why fragile: `ChatWebViewVC` is an `NSViewControllerRepresentable` (SwiftUI bridge) but `BubbleWindowController` instantiates `ChatWebViewController` directly (bypassing SwiftUI). The `Coordinator` class is shared between both paths but `updateNSViewController` is only called in the SwiftUI path. On macOS, the direct instantiation path is used, meaning most of the `updateNSViewController` logic is dead code on macOS -- streaming is handled entirely by `BubbleWindowController.observeStreaming()`
- Safe modification: Understand which code path is active for each platform before making changes. macOS uses Combine observation, iOS would use the SwiftUI representable
- Test coverage: None

**Notification-driven push event handling:**
- Files: `ErestorApp/ErestorApp/Services/ChatService.swift` (lines 318-391), `ErestorApp/ErestorApp/Services/BubbleWindowController.swift` (lines 288-337), `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (lines 138-202)
- Why fragile: Push events flow through `ChatService.handlePushEvent()` which posts `NotificationCenter` notifications. Both `BubbleWindowController.observePushMessages()` and `ContextPanelView.onReceive(pushObserver)` listen to the same notification. The notification userInfo uses string keys ("text", "eventType", "severity", "options") without type safety
- Safe modification: Any change to push event structure requires updating all three files in sync
- Test coverage: None

## Scaling Limits

**Chat message history grows unbounded:**
- Current capacity: All messages stored in `ChatService.messages` array in memory
- Limit: No upper bound on message count; long sessions accumulate messages without pruning
- Scaling path: Add a maximum message count (e.g., 100) with FIFO removal, or paginate history loading

## Dependencies at Risk

**Carbon framework (deprecated by Apple):**
- Risk: `GlobalHotkey.swift` uses Carbon's `RegisterEventHotKey` API which Apple has deprecated. Future macOS versions may remove it
- Impact: Global hotkey (Cmd+Shift+E) would stop working
- Migration plan: Use `CGEvent.tapCreate` with accessibility permissions, or `NSEvent.addGlobalMonitorForEvents` (requires accessibility access), or the newer `KeyboardShortcuts` Swift package

**macOS 26.0 deployment target:**
- Risk: The project targets macOS 26.0 which is an unreleased/cutting-edge version. This limits the app to only the latest macOS
- Impact: Cannot run on any currently stable macOS release
- Migration plan: If backward compatibility is needed, lower the deployment target and guard newer APIs with `@available` checks

## Missing Critical Features

**No error recovery for backend downtime:**
- Problem: When the backend goes offline, the app shows "Erro de conexao" but has no retry mechanism for failed messages. The user must manually resend
- Blocks: Reliable message delivery during intermittent connectivity

**No local message persistence:**
- Problem: Chat history is loaded from the backend on launch but not cached locally. If the backend is unreachable at launch, the chat starts empty
- Blocks: Offline access to conversation history

## Test Coverage Gaps

**Zero test coverage across entire codebase:**
- What's not tested: Every single file -- ChatService networking, ActionHandler command execution, SSE parsing, message rendering coordination, time parsing, context decoding
- Files: All 21 Swift files (3,315 lines total)
- Risk: Any refactoring or feature addition can break existing functionality silently. The streaming coordination logic in `ChatWebViewVC` is particularly risky to change without tests
- Priority: High -- at minimum, unit tests for: `ActionHandler.parseRelativeTime()`, `ActionHandler.parseTime()`, `ChatAction` decoding, `ContextSummary` decoding, `SSEChunk` decoding, `ChatWebViewVC.escapeForJS()`

**iOS target is untested and likely incomplete:**
- What's not tested: The iOS target (`ErestorApp-iOS`) excludes many macOS-specific files but shares `ChatService`, `ContextPanelView`, and models. The iOS app has no WebView-based chat, relying on SwiftUI views (`ChatHistoryView`, `ChatInputView`) that are not used on macOS
- Files: `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift`, `ErestorApp/project.yml` (lines 39-72)
- Risk: iOS build may compile but behave incorrectly since the SwiftUI chat views have diverged from the WebView-based macOS implementation
- Priority: Medium -- clarify if iOS is actively maintained or should be removed

---

*Concerns audit: 2026-03-09*
