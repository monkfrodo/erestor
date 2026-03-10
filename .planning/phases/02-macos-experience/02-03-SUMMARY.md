---
phase: 02-macos-experience
plan: 03
subsystem: swift-app
tags: [sse, markdownui, highlightswift, swiftui, streaming, chat, markdown]

# Dependency graph
requires:
  - phase: 02-macos-experience
    provides: SSE event stream endpoint (/v1/events/stream), Anthropic SDK chat streaming (/v1/chat/stream)
provides:
  - "SSE event stream client in ChatService replacing all polling loops"
  - "Native SwiftUI chat with MarkdownUI rendering and Vesper Dark theme"
  - "Token-by-token streaming with plain Text during stream, Markdown after completion"
  - "Typed SSE event models (context_update, poll, gate, heartbeat)"
  - "ChatMessageView with custom .erestor MarkdownUI theme"
  - "Rewritten ChatHistoryView with LazyVStack and auto-scroll"
affects: [02-macos-experience, polls-ui, gate-alerts, synthesis-display]

# Tech tracking
tech-stack:
  added: [MarkdownUI-2.4.0, HighlightSwift-1.1.0]
  patterns: [sse-event-stream-client, streaming-then-markdown, heartbeat-liveness, exponential-backoff-reconnect]

key-files:
  created:
    - "~/projetos/erestor/ErestorApp/ErestorApp/Models/SSEEvent.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/ChatMessageView.swift"
  modified:
    - "~/projetos/erestor/ErestorApp/project.yml"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Models/Message.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Services/ErestorConfig.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Services/ChatService.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/ChatHistoryView.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/ContextPanelView.swift"

key-decisions:
  - "Render streaming text as plain Text, switch to Markdown on completion (avoids MarkdownUI re-parsing per token)"
  - "URLSession.bytes SSE client with exponential backoff (3s -> 6s -> 12s -> 24s -> 30s cap)"
  - "Heartbeat-based liveness detection (offline after 60s without heartbeat, checked every 15s)"
  - "In-place message mutation for streaming (updateStreamingMessage modifies array element directly)"
  - "Conversation history (last 20 messages) sent with each chat request for context"
  - "Chat input disabled during streaming via .disabled() modifier"
  - "Force SSE reconnect on macOS wake via NSWorkspace.didWakeNotification"

patterns-established:
  - "Streaming-then-Markdown pattern: plain Text during stream, MarkdownUI after completion (Pitfall 4)"
  - "SSE event routing via SSEEvent.parse() with JSONSerialization for flexible typing"
  - "Custom MarkdownUI theme extension (.erestor) using DS design system colors"
  - "ChatMessage.isStreaming flag for distinguishing rendering modes"

requirements-completed: [PANEL-07, CHAT-02, CHAT-03, CHAT-04]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 2 Plan 03: SSE Event Stream Client + Native SwiftUI Chat with MarkdownUI Summary

**SSE event stream replacing all polling, native SwiftUI chat with MarkdownUI markdown rendering and token-by-token streaming using Vesper Dark theme**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T10:48:21Z
- **Completed:** 2026-03-10T10:53:49Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- ChatService connects to /v1/events/stream SSE and receives real-time context updates, polls, gates, and heartbeats
- All polling loops (status 5s, push 3s, context 5s) replaced by single persistent SSE stream with auto-reconnect
- Chat messages render with full markdown (bold, lists, code blocks) via MarkdownUI with custom Vesper Dark theme
- Token-by-token streaming shows plain text during stream, switches to Markdown view on completion
- Conversation history persists within session and is sent to backend with each message
- Chat input always visible at bottom, disabled during streaming

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SPM dependencies and create SSE event models + config updates** - `aae4419` (feat)
2. **Task 2: Rewrite ChatService SSE + ChatMessageView + ChatHistoryView** - `e73dfe8` (feat)

_All commits in ~/projetos/erestor/ repository_

## Files Created/Modified
- `ErestorApp/project.yml` - Added MarkdownUI 2.4.0 and HighlightSwift 1.1.0 SPM packages
- `ErestorApp/ErestorApp/Models/SSEEvent.swift` - Typed SSE event models (SSEEventType, SSEEvent, PollSSEEvent, GateSSEEvent)
- `ErestorApp/ErestorApp/Models/Message.swift` - ChatMessage.text now var for streaming, added isStreaming flag and streaming() factory
- `ErestorApp/ErestorApp/Services/ErestorConfig.swift` - Added /v1/ endpoint path constants
- `ErestorApp/ErestorApp/Services/ChatService.swift` - Major rewrite: SSE event stream, removed polling, in-place streaming updates, conversation history
- `ErestorApp/ErestorApp/Views/ChatMessageView.swift` - New: single message bubble with MarkdownUI and streaming cursor
- `ErestorApp/ErestorApp/Views/ChatHistoryView.swift` - Rewrite: LazyVStack with auto-scroll and streaming text tracking
- `ErestorApp/ErestorApp/Views/ContextPanelView.swift` - Pass isStreaming to ChatHistoryView, disable input during streaming

## Decisions Made
- Render streaming messages as plain Text to avoid MarkdownUI re-parsing on every token (matches ChatGPT iOS pattern)
- Exponential backoff for SSE reconnection: 3s doubling to 30s cap (balances responsiveness with server load)
- Heartbeat liveness: 60s timeout checked every 15s (matches backend 30s heartbeat interval with 2x margin)
- In-place array mutation for streaming updates (avoids array recreation per token)
- Last 20 messages sent as history for context (keeps payload reasonable)
- MarkdownUI .listItem requires configuration closure (not just text style) -- fixed during build

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MarkdownUI .listItem API mismatch**
- **Found during:** Task 2 (build verification)
- **Issue:** MarkdownUI .listItem block directive requires a configuration closure parameter, not a bare text style block
- **Fix:** Changed `.listItem { ForegroundColor(...) }` to `.listItem { configuration in configuration.label.markdownTextStyle { ... } }`
- **Files modified:** ChatMessageView.swift
- **Verification:** Build succeeds
- **Committed in:** e73dfe8 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor API usage fix. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviation above.

## User Setup Required
None - MarkdownUI and HighlightSwift are resolved via SPM automatically.

## Next Phase Readiness
- SSE event stream client ready for polls and gates to appear in panel
- Chat markdown rendering ready for synthesis output display
- ContextPanelView ready for poll/gate cards driven by SSE events (activePolls/activeGates on ChatService)
- WKWebView chat.html still exists but is no longer the primary chat interface -- removal deferred to cleanup plan

---
*Phase: 02-macos-experience*
*Completed: 2026-03-10*
