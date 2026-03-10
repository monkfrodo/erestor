---
phase: 02-macos-experience
verified: 2026-03-10T15:04:08Z
status: human_needed
score: 5/5 success criteria verified
must_haves:
  truths:
    - "A floating panel shows current event with progress, active timer, next event, and day tasks -- updating in real-time via SSE without polling"
    - "Kevin can chat with Erestor in natural language (create events, set reminders, ask questions) and see streaming responses"
    - "Energy check-in polls appear at intelligent moments, block quality polls appear when calendar blocks end, and gate alerts fire when blocks are ending with tasks open"
    - "Daily synthesis crosses polls, timers, blocks, and energy data into a richer analysis than the current Telegram version"
    - "Native macOS notifications with inline actions deliver proactive alerts without requiring the panel to be open"
  artifacts:
    - path: "~/claude-sync/produtividade/api/routers/events.py"
      provides: "Persistent SSE event stream with asyncio.Queue + poll scheduler"
    - path: "~/claude-sync/produtividade/api/routers/chat.py"
      provides: "Anthropic SDK token-by-token streaming via SSE"
    - path: "~/claude-sync/produtividade/api/routers/polls.py"
      provides: "Poll CRUD + gate alert + manual trigger endpoints"
    - path: "~/claude-sync/produtividade/api/routers/synthesis.py"
      provides: "Synthesis trigger and on-demand insights endpoints"
    - path: "~/claude-sync/produtividade/erestor/event_store.py"
      provides: "poll_responses SQLite table with helpers"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Models/SSEEvent.swift"
      provides: "Typed SSE event models"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/ChatMessageView.swift"
      provides: "Markdown rendering with MarkdownUI + streaming plain text"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/ChatHistoryView.swift"
      provides: "Native SwiftUI chat with LazyVStack + auto-scroll"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/ContextPanelView.swift"
      provides: "Panel layout: Context > Tasks > Alerts > Chat"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/CollapsibleTasksView.swift"
      provides: "Collapsible task section with count badge"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/PollCardView.swift"
      provides: "Poll card with expiry countdown + backend POST"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Views/GateAlertView.swift"
      provides: "Gate alert with severity colors + task list"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Services/ChatService.swift"
      provides: "SSE event stream client + notification posting + streaming"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/Services/BubbleWindowController.swift"
      provides: "NSHostingView embedding (no WKWebView)"
    - path: "~/projetos/erestor/ErestorApp/ErestorApp/ErestorApp.swift"
      provides: "Notification categories with poll response actions"
  key_links:
    - from: "events.py"
      to: "main.py"
      via: "router registration"
    - from: "polls.py"
      to: "event_store.py"
      via: "create_poll/respond_to_poll"
    - from: "synthesis.py"
      to: "event_store.py"
      via: "get_poll_data"
    - from: "ChatService.swift"
      to: "/v1/events/stream"
      via: "URLSession.bytes SSE"
    - from: "ChatService.swift"
      to: "/v1/chat/stream"
      via: "POST + SSE token streaming"
    - from: "ChatMessageView.swift"
      to: "MarkdownUI"
      via: "Markdown() view"
    - from: "PollCardView -> ContextPanelView"
      to: "/v1/polls/{poll_id}/respond"
      via: "POST on tap"
    - from: "BubbleWindowController.swift"
      to: "ContextPanelView.swift"
      via: "NSHostingView"
    - from: "ErestorApp.swift"
      to: "UNNotificationCenter"
      via: "categories + action handler"
human_verification:
  - test: "Launch app and toggle panel with Cmd+Shift+E"
    expected: "Panel shows current event, timer, next event, collapsible tasks, and chat input at bottom"
    why_human: "Visual layout, floating window behavior, and hotkey cannot be verified programmatically"
  - test: "Type a message in chat and observe streaming"
    expected: "Words appear one-by-one with blinking cursor, then switch to markdown rendering when complete"
    why_human: "Real-time streaming UX and markdown rendering quality need visual confirmation"
  - test: "Trigger a poll via curl and observe inline card + notification"
    expected: "Poll card appears in panel; if panel is closed, macOS notification appears with action buttons"
    why_human: "Notification delivery and inline card appearance need visual confirmation"
  - test: "Ask 'como foi meu dia?' in chat"
    expected: "Response includes poll data, timer sessions, and energy readings if available"
    why_human: "Claude response quality and data integration need human judgment"
---

# Phase 2: macOS Experience Verification Report

**Phase Goal:** Kevin has a fully functional macOS contextual panel that replaces Telegram as his primary Erestor interface
**Verified:** 2026-03-10T15:04:08Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Floating panel shows current event with progress, timer, next event, tasks -- updating via SSE without polling | VERIFIED | ContextPanelView.swift renders EventCardView, TimerChipView, NextEventView, CollapsibleTasksView in correct hierarchy. ChatService.swift connects to /v1/events/stream via URLSession.bytes, no polling methods remain. SSE routes context_update events to @Published context. |
| 2 | Kevin can chat in natural language and see streaming responses | VERIFIED | ChatService.sendMessageStreaming() POSTs to /v1/chat/stream with message + last 20 messages as history. Backend chat.py uses AsyncAnthropic with stream.text_stream for token-by-token SSE. ChatMessageView renders plain Text during streaming, switches to Markdown() on completion. Action parsing via regex [ACTION:type:params]. |
| 3 | Energy polls at intelligent moments, block quality polls on event end, gate alerts when blocks end with open tasks | VERIFIED | events.py _poll_scheduler runs every 60s: _check_energy_polls (2h+ gap, 8-21h, active presence), _check_block_quality_polls (event ended within 2min), _check_gate_alerts (5min amber, 2min red with P1 tasks). polls.py stores in poll_responses SQLite table. PollCardView shows tappable options, POSTs to /v1/polls/{id}/respond. GateAlertView shows severity-colored cards. |
| 4 | Daily synthesis crosses polls, timers, blocks, and energy data | VERIFIED | synthesis.py _gather_synthesis_data queries poll_responses, daily_signals, event_log for date range. POST /v1/synthesis/trigger calls Claude with gathered data. POST /v1/synthesis/query accepts natural language. events.py _check_daily_synthesis auto-triggers at 22h. |
| 5 | Native macOS notifications with inline actions deliver proactive alerts | VERIFIED | ErestorApp.swift registers POLL_ENERGY (5 actions), POLL_QUALITY (4 actions), GATE_INFORM, POLL_REMINDER categories. Action handler parses ENERGY_N/QUALITY_opt identifiers and POSTs to /v1/polls/{id}/respond. ChatService posts notifications when panel is hidden; 10-min reminder via UNTimeIntervalNotificationTrigger(600). poll_expired cleans pending notifications. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `api/routers/events.py` | VERIFIED | 444 lines. SSE generator, push_event(), poll scheduler with 6 check functions, heartbeat. |
| `api/routers/chat.py` | VERIFIED | 156 lines. AsyncAnthropic streaming, system prompt from soul.md + WorldState, action parsing, conversation history. |
| `api/routers/polls.py` | VERIFIED | 141 lines. CRUD endpoints, gate alerts, manual trigger. |
| `api/routers/synthesis.py` | VERIFIED | 156 lines. Synthesis trigger, on-demand insights, date range parsing. |
| `erestor/event_store.py` | VERIFIED | poll_responses table with indexes, create_poll, respond_to_poll, expire_poll, get_polls_by_date, get_poll_data. |
| `api/schemas.py` | VERIFIED | SSE event type constants, PollCreateRequest, PollRespondRequest, GateAlertRequest, PollResponse, SynthesisTriggerRequest, SynthesisQueryRequest. |
| `api/main.py` | VERIFIED | All 7 routers registered (status, context, chat, calendar, events, polls, synthesis). Lifespan handler calls init_db(). |
| `Models/SSEEvent.swift` | VERIFIED | 67 lines. SSEEventType enum (7 types), SSEEvent with JSONSerialization parser, PollSSEEvent, GateSSEEvent with CodingKeys. |
| `Views/ChatMessageView.swift` | VERIFIED | 127 lines. Role labels, plain Text for user/streaming, Markdown() for completed assistant, blinking cursor, custom .erestor theme with DS colors. |
| `Views/ChatHistoryView.swift` | VERIFIED | 41 lines. ScrollViewReader + LazyVStack + ForEach + ChatMessageView. Auto-scroll on message count and streaming text changes. |
| `Views/ContextPanelView.swift` | VERIFIED | 270+ lines. Hierarchy: EventCardView > TimerChipView > NextEventView > CollapsibleTasksView > ForEach activePolls > ForEach activeGates > ChatHistoryView + input. respondToPoll POSTs to backend. |
| `Views/CollapsibleTasksView.swift` | VERIFIED | 39 lines. Toggle with animation, count badge, DS.mono/DS.dim/DS.muted styling, wraps TaskListView. |
| `Views/PollCardView.swift` | VERIFIED | 178 lines. Energy (5 circles) and quality (4 buttons) options. Expiry countdown timer. Auto-dismiss on expiry. onResponse callback. |
| `Views/GateAlertView.swift` | VERIFIED | 121 lines. Amber/red severity colors. Task list. Dismiss button via onDismiss. |
| `Services/ChatService.swift` | VERIFIED | 600+ lines. SSE event stream (startEventStream), no polling methods, exponential backoff reconnect, wake notification, activePolls/activeGates, sendMessageStreaming with token batching, notification posting (postPollNotification, postGateNotification, scheduleReminderNotification). |
| `Services/BubbleWindowController.swift` | VERIFIED | NSHostingView(rootView: ContextPanelView) at line 167. No WKWebView imports or references. |
| `Services/ErestorConfig.swift` | VERIFIED | v1 path constants (eventsStreamPath, chatStreamPath, pollsPath, synthesisPath). |
| `ErestorApp.swift` | VERIFIED | Notification categories (POLL_ENERGY, POLL_QUALITY, GATE_INFORM, POLL_REMINDER) with action buttons. respondToPollBackend POSTs to backend. |
| `project.yml` | VERIFIED | MarkdownUI 2.4.0 and HighlightSwift 1.1.0 SPM packages. Both listed as target dependencies. |
| `ChatWebViewVC.swift` | DELETED (correct) | File does not exist. |
| `Resources/chat.html` | DELETED (correct) | File does not exist. |
| `tests/test_events_stream.py` | VERIFIED | 6267 bytes. Tests for SSE stream. |
| `tests/test_chat_anthropic.py` | VERIFIED | 7612 bytes. Tests for Anthropic streaming. |
| `tests/test_polls_api.py` | VERIFIED | 9675 bytes. Tests for poll CRUD. |
| `tests/test_synthesis_api.py` | VERIFIED | 6523 bytes. Tests for synthesis. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| events.py | main.py | router registration | WIRED | `app.include_router(events.router, prefix="/v1")` at line 33 |
| polls.py | main.py | router registration | WIRED | `app.include_router(polls.router, prefix="/v1")` at line 34 |
| synthesis.py | main.py | router registration | WIRED | `app.include_router(synthesis.router, prefix="/v1")` at line 35 |
| chat.py | anthropic.AsyncAnthropic | SDK client | WIRED | Lazy init via _get_client(), `client.messages.stream()` |
| polls.py | event_store.py | create_poll/respond_to_poll | WIRED | Lazy imports of create_poll, respond_to_poll |
| events.py | event_store.py | poll scheduling | WIRED | Lazy imports of create_poll, expire_poll, get_polls_by_date |
| synthesis.py | event_store.py | get_poll_data | WIRED | Import of get_poll_data and _get_conn |
| ChatService.swift | /v1/events/stream | URLSession.bytes SSE | WIRED | ErestorConfig.eventsStreamPath used in startEventStream() |
| ChatService.swift | /v1/chat/stream | POST + SSE | WIRED | ErestorConfig.chatStreamPath used in sendMessageStreaming() |
| ChatMessageView.swift | MarkdownUI | Markdown() view | WIRED | `import MarkdownUI` + `Markdown(message.text).markdownTheme(.erestor)` |
| ChatHistoryView.swift | ChatMessageView | ForEach messages | WIRED | `ChatMessageView(message: msg)` in ForEach loop |
| ContextPanelView.swift | ChatHistoryView | embedded in bottom | WIRED | `ChatHistoryView(messages:isStreaming:)` in VStack |
| PollCardView -> ContextPanelView | /v1/polls/{id}/respond | POST on tap | WIRED | respondToPoll() builds URL from ErestorConfig.pollsPath + pollId, POSTs value |
| BubbleWindowController.swift | ContextPanelView | NSHostingView | WIRED | `NSHostingView(rootView: panelView)` at line 167 |
| ErestorApp.swift | UNNotificationCenter | categories + handler | WIRED | Categories registered, userNotificationCenter didReceive calls respondToPollBackend |
| ChatService.swift | UNNotificationCenter | posting notifications | WIRED | postPollNotification, postGateNotification, scheduleReminderNotification |
| events.py | polls.py (trigger) | push_event for scheduling | WIRED | events.py imports push_event and calls it in _check_* functions |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PANEL-01 | 02-04 | Floating bubble (NSPanel) | SATISFIED | NSPanel config preserved in BubbleWindowController, no WKWebView |
| PANEL-02 | 02-04 | Global hotkey (Cmd+Shift+E) | SATISFIED | GlobalHotkey.swift exists (not modified, kept from Phase 1), Carbon framework in project.yml |
| PANEL-03 | 02-04 | Current event with progress bar | SATISFIED | EventCardView in ContextPanelView with eventProgress() |
| PANEL-04 | 02-04 | Active timer with label and stop | SATISFIED | TimerChipView in ContextPanelView with onStop handler |
| PANEL-05 | 02-04 | Next event preview | SATISFIED | NextEventView in ContextPanelView with minsToNext |
| PANEL-06 | 02-04 | Task list with priorities | SATISFIED | CollapsibleTasksView wrapping TaskListView with p1+p2 tasks |
| PANEL-07 | 02-01, 02-03 | Real-time SSE updates | SATISFIED | events.py SSE stream + ChatService.startEventStream(), all polling removed |
| CHAT-01 | 02-01 | Natural language commands | SATISFIED | Chat endpoint parses [ACTION:type:params], system prompt includes WorldState |
| CHAT-02 | 02-01, 02-03 | Streaming responses | SATISFIED | AsyncAnthropic stream.text_stream + per-token SSE + ChatMessageView streaming |
| CHAT-03 | 02-03 | Conversation history | SATISFIED | ChatService sends last 20 messages as history with each request |
| CHAT-04 | 02-03 | Chat input always visible | SATISFIED | ChatInputView at bottom of ContextPanelView VStack, disabled during streaming |
| DATA-01 | 02-02, 02-05 | Energy check-in polls | SATISFIED | _check_energy_polls in scheduler, poll_responses table, PollCardView energy type |
| DATA-02 | 02-02, 02-05 | Block quality polls | SATISFIED | _check_block_quality_polls on event end, PollCardView quality type |
| DATA-03 | 02-02, 02-05 | Gate alerts | SATISFIED | _check_gate_alerts at 5min/2min, GateAlertView with severity colors |
| DATA-04 | 02-02 | Poll responses stored for synthesis | SATISFIED | poll_responses table, get_poll_data used by synthesis |
| NOTF-01 | 02-05 | macOS notifications with inline actions | SATISFIED | UNNotificationCategory with ENERGY_/QUALITY_ actions, respondToPollBackend |
| SYNT-01 | 02-02, 02-05 | Evolved daily synthesis | SATISFIED | synthesis.py crosses polls+timers+events, auto-trigger at 22h |
| SYNT-02 | 02-02 | On-demand insights via chat | SATISFIED | POST /v1/synthesis/query accepts natural language, date range parsing |

**Orphaned requirements:** None. All 18 requirement IDs from the phase are accounted for across plans and verified in code.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| ChatService.swift | 323, 344 | "placeholder" in comments | Info | Refers to streaming placeholder message pattern, not a TODO -- acceptable |

No blockers or warnings found. No TODO/FIXME/HACK comments in any modified files.

### Human Verification Required

### 1. Panel Layout and Floating Behavior

**Test:** Launch app, toggle panel with Cmd+Shift+E
**Expected:** Panel shows current event with progress bar at top, timer below it, next event preview, collapsible tasks section (starts collapsed with count), then chat area at bottom. Panel floats without stealing focus from other apps. Resize persists.
**Why human:** Visual layout hierarchy, floating window behavior, and focus management cannot be verified programmatically.

### 2. Chat Streaming and Markdown Rendering

**Test:** Type a message in chat (e.g., "explica o que e markdown com exemplos de codigo")
**Expected:** Response streams word-by-word with blinking green cursor. After completion, text switches to formatted markdown with bold text, code blocks with syntax highlighting (dark theme), and properly styled headings.
**Why human:** Real-time streaming UX quality, markdown rendering fidelity, and Vesper Dark theme appearance need visual confirmation.

### 3. Poll Cards and Notifications

**Test:** Run `curl -X POST https://erestor-api.kevineger.com.br/v1/polls/trigger -H "Authorization: Bearer gzC3a3cvg15-IgU3lAu0YuJeHCxc87EOTZJ4sikSuMU" -H "Content-Type: application/json" -d '{"poll_type": "energy"}'`
**Expected:** With panel open: energy poll card appears inline with 5 tappable number buttons and expiry countdown. With panel closed: macOS notification appears with 5 action buttons (1-5). Tapping a response dismisses and POSTs to backend.
**Why human:** Notification delivery timing, action button rendering, and inline/notification coordination need runtime testing.

### 4. Synthesis via Chat

**Test:** In chat, type "como foi meu dia?"
**Expected:** Response includes available poll data, timer sessions, and energy readings for today. If no data exists, says "sem dados suficientes."
**Why human:** Claude response quality and data integration completeness need human judgment.

### Gaps Summary

No gaps found. All 18 requirements are satisfied in code. All artifacts exist, are substantive (not stubs), and are properly wired. All key links verified. WKWebView completely removed. The only remaining step is Plan 02-06 (human verification checkpoint), which is the correct final gate for this phase.

The codebase fully implements the phase goal. Human verification is needed to confirm the visual and interactive experience works as designed at runtime.

---

_Verified: 2026-03-10T15:04:08Z_
_Verifier: Claude (gsd-verifier)_
