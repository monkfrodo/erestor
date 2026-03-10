# Phase 2: macOS Experience - Research

**Researched:** 2026-03-09
**Domain:** macOS SwiftUI native app + Python FastAPI backend (polls, SSE, Anthropic SDK, synthesis)
**Confidence:** HIGH

## Summary

Phase 2 transforms the existing Erestor macOS app from a WKWebView-based chat with polling into a fully native SwiftUI experience with real-time SSE updates, token-by-token streaming via the Anthropic Python SDK, inline polls/gate alerts, and an evolved daily synthesis. The existing codebase provides strong foundations: ChatService already handles SSE streaming, ContextPanelView already renders context cards with polls and gates, and the backend already has SSE infrastructure via sse-starlette. The main work areas are: (1) replacing the WKWebView chat with native SwiftUI chat including markdown rendering, (2) migrating the backend from CLI subprocess to Anthropic SDK for true token streaming, (3) adding a persistent SSE event stream for context/polls/gates replacing the 5s polling, (4) creating poll storage in SQLite, and (5) evolving daily synthesis to cross-reference all collected data.

The codebase is well-structured with clear patterns: `@MainActor ObservableObject` services, `DS.*` design system, `ErestorConfig.authorize(&request)` for auth, and snake_case `CodingKeys` for API models. The backend uses FastAPI with sse-starlette, router-level auth via `Depends(verify_token)`, and lazy imports for Python 3.9 compatibility. The existing poll system in the Telegram bot is rich (energy, block quality, mentoria, etc.) but uses Telegram API polls -- Phase 2 needs equivalent functionality via native macOS UI and notifications.

**Primary recommendation:** Work in layers -- backend SSE event stream first (enabling real-time push), then native SwiftUI chat with markdown, then polls/gates backend + frontend, then synthesis evolution. Each layer builds on the previous.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Migrate from WKWebView (chat.html) to native SwiftUI chat
- Remove chat.html and ChatWebViewVC -- all chat in SwiftUI using DS (DesignSystem) colors/fonts
- Full markdown rendering (bold, lists, code blocks with syntax highlighting) -- use swift-markdown or similar parser
- Token-by-token streaming (each word appears in real-time like ChatGPT)
- Backend migrates from CLI subprocess (`claude --print`) to Anthropic Python SDK for true token streaming
- Conversation history persists within session (CHAT-03)
- Chat input always visible at bottom of panel (CHAT-04)
- Polls appear both inline in panel (PollCardView) AND as macOS notifications when panel is closed
- Gate alerts appear as macOS notification (with sound/banner) + amber/red card inline in panel
- Block quality polls (perdi/meh/ok/flow) trigger automatically when calendar event ends
- Energy polls triggered at intelligent moments by backend
- If Kevin doesn't respond to a poll: ONE reminder notification after 10 min, then expires silently
- Expired polls registered as "not answered" in the data
- Poll responses stored in SQLite for synthesis queries
- Visual hierarchy top-to-bottom: Context > Alerts (polls/gates, temporary) > Chat (always visible)
- Tasks as collapsible section between context and alerts
- Synthesis appears as chat message from Erestor (no dedicated UI section)
- Panel is resizable via drag (ResizeHandleView already exists) -- persists size between sessions
- Real-time panel updates via SSE (PANEL-07) -- replace current 5s polling for context
- Poll response data stored in SQLite (same erestor_events.db)
- Daily synthesis runs automatically at 22h + available on-demand via chat
- Synthesis crosses polls, timers, blocks, and energy data (SYNT-01)
- On-demand insights from collected data via chat (SYNT-02)

### Claude's Discretion
- Push mechanism for polls/gates/context updates (SSE channel vs polling vs hybrid)
- How to inject CLAUDE.md context into Anthropic SDK calls (system prompt construction)
- Markdown parser library choice for Swift
- Notification categories and action button design
- Exact poll timing intelligence (when to trigger energy polls)
- Gate alert timing (how many minutes before block ends)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PANEL-01 | Floating bubble (NSPanel) that does not steal focus, always visible | Already implemented in BubbleWindowController.swift -- no changes needed |
| PANEL-02 | Global hotkey (Cmd+Shift+E) to toggle panel via Carbon | Already implemented in GlobalHotkey.swift -- no changes needed |
| PANEL-03 | Current calendar event displayed with progress bar | EventCardView exists, needs SSE-driven updates instead of polling |
| PANEL-04 | Active timer with project/task label and stop button | TimerChipView exists, needs SSE-driven updates |
| PANEL-05 | Next event preview with time until | NextEventView exists, needs SSE-driven updates |
| PANEL-06 | Task list for the day with priority indicators | TaskListView exists, needs collapsible behavior + SSE updates |
| PANEL-07 | Real-time panel updates via SSE (no polling) | New persistent SSE endpoint on backend, new SSE client in ChatService |
| CHAT-01 | Natural language commands to create events, set reminders, ask questions | Anthropic SDK migration enables richer responses; ActionHandler already handles 19+ action types |
| CHAT-02 | Streaming responses from Claude displayed in real-time | Anthropic SDK `client.messages.stream()` + SSE relay to Swift client |
| CHAT-03 | Conversation history persists within session | ChatService.messages array already persists in session; extend with backend history API |
| CHAT-04 | Chat input always visible at bottom of panel | ChatInputView exists; embed in new native SwiftUI chat layout |
| DATA-01 | Energy check-in polls (1-5 scale) triggered at intelligent moments | Backend poll scheduling + PollCardView (exists) + macOS notifications (categories exist) |
| DATA-02 | Block quality assessment poll at end of calendar blocks | Backend event ending detection (exists in polls.py) + push via SSE |
| DATA-03 | Proactive gate alerts when block is ending and tasks remain open | Gate system exists in gate.py; push via SSE to app |
| DATA-04 | Poll responses stored and available for synthesis | New SQLite tables in erestor_events.db for poll responses |
| NOTF-01 | Native macOS notifications with inline actions (polls, quick responses) | UNUserNotificationCenter already set up with POLL_ENERGY, POLL_QUALITY, GATE_INFORM, REMINDER categories |
| SYNT-01 | Evolved daily synthesis crossing polls, timers, blocks, and energy data | Extend synthesis.py to query SQLite poll data; deliver as chat message |
| SYNT-02 | On-demand insights from collected data via chat | Backend endpoint or system prompt enrichment for data-driven answers |
</phase_requirements>

## Standard Stack

### Core (Swift/macOS)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MarkdownUI | 2.4.0 | Markdown rendering in SwiftUI | GFM-compatible, supports code blocks, lists, tables. In maintenance mode but stable and widely used. Successor (Textual) is v0.1.0, too early for production |
| HighlightSwift | 1.1.0 | Code syntax highlighting | 50+ languages, 30 themes, provides `CodeText` SwiftUI view. Dark theme compatible |
| SwiftUI (native) | macOS 26 | UI framework | Already in use, deployment target macOS 26.0 |
| UserNotifications | native | macOS notifications with actions | Already integrated, notification categories already registered |

### Core (Python/Backend)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| anthropic | latest (>=0.40) | Claude API with streaming | Official SDK, replaces CLI subprocess. Provides `client.messages.stream()` for token-by-token |
| sse-starlette | (existing) | SSE for FastAPI | Already in use for chat streaming. Extend for persistent event stream |
| FastAPI | 0.128.8 | API framework | Already in use, Python 3.9 compatible |
| sqlite3 | stdlib | Poll data storage | Already used via erestor_events.db. Add poll_responses table |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MarkdownUI | Textual (v0.1.0) | Too new (Dec 2025, 16 commits). Not production-ready |
| MarkdownUI | Native SwiftUI Text markdown | Only supports inline styles (bold/italic/links). No code blocks, tables, lists |
| HighlightSwift | Manual NSAttributedString | Massive effort, 50+ languages to support |
| SSE persistent stream | WebSocket | SSE is simpler, unidirectional (server-to-client) which fits the use case. Already using sse-starlette |

**Installation (Swift):**
Add to `project.yml` or `Package.swift`:
```yaml
# project.yml dependencies
packages:
  MarkdownUI:
    url: https://github.com/gonzalezreal/swift-markdown-ui
    from: "2.4.0"
  HighlightSwift:
    url: https://github.com/appstefan/HighlightSwift
    from: "1.1.0"
```

**Installation (Python):**
```bash
pip install anthropic
```

## Architecture Patterns

### Recommended Project Structure Changes
```
ErestorApp/
├── Services/
│   ├── ChatService.swift        # MODIFY: add SSE event stream, remove polling
│   ├── BubbleWindowController.swift  # MODIFY: remove WKWebView, embed SwiftUI chat
│   ├── ErestorConfig.swift      # MODIFY: add /v1/ endpoint paths
│   ├── ActionHandler.swift      # NO CHANGE
│   └── GlobalHotkey.swift       # NO CHANGE
├── Views/
│   ├── ContextPanelView.swift   # MODIFY: restructure layout hierarchy
│   ├── ChatHistoryView.swift    # REWRITE: native markdown rendering with streaming
│   ├── ChatInputView.swift      # MINOR: disable during streaming
│   ├── ChatMessageView.swift    # NEW: single message bubble with markdown
│   ├── CollapsibleTasksView.swift  # NEW: collapsible task section
│   ├── ChatWebViewVC.swift      # DELETE
│   ├── DesignSystem.swift       # NO CHANGE
│   ├── EventCardView.swift      # NO CHANGE
│   ├── PollCardView.swift       # MINOR: add poll ID tracking, expiry timer
│   ├── GateAlertView.swift      # NO CHANGE
│   ├── TimerChipView.swift      # NO CHANGE
│   └── NextEventView.swift      # NO CHANGE
├── Models/
│   ├── Message.swift            # MODIFY: add PollEvent, GateEvent models
│   └── SSEEvent.swift           # NEW: typed SSE event models
├── Resources/
│   ├── chat.html                # DELETE (replaced by native SwiftUI)
│   └── chat.css                 # DELETE
└── Extensions/
    └── Color+Hex.swift          # NO CHANGE

~/claude-sync/produtividade/
├── api/
│   ├── routers/
│   │   ├── chat.py              # REWRITE: Anthropic SDK streaming
│   │   ├── context.py           # NO CHANGE (data endpoint)
│   │   ├── events.py            # NEW: persistent SSE event stream
│   │   ├── polls.py             # NEW: poll CRUD + response storage
│   │   └── synthesis.py         # NEW: synthesis trigger + data query
│   ├── main.py                  # MODIFY: register new routers
│   └── schemas.py               # MODIFY: add poll/event schemas
├── erestor/
│   ├── event_store.py           # MODIFY: add poll_responses table
│   ├── synthesis.py             # MODIFY: query SQLite poll data, remove Telegram deps
│   ├── polls.py                 # MODIFY: add desktop poll dispatch (via event bus)
│   └── claude.py                # MODIFY: add Anthropic SDK wrapper alongside CLI
```

### Pattern 1: Persistent SSE Event Stream
**What:** Single SSE connection from app to backend that carries all real-time events (context updates, polls, gates, chat tokens)
**When to use:** Replaces multiple polling loops (status 5s, context 5s, push 3s)
**Recommendation:** Use a dedicated `/v1/events/stream` endpoint that yields events as they occur. The backend uses an asyncio.Queue per client.

```python
# Backend: api/routers/events.py
from asyncio import Queue
from fastapi import APIRouter, Depends
from sse_starlette.sse import EventSourceResponse, ServerSentEvent

router = APIRouter(dependencies=[Depends(verify_token)])

# In-process event queue (single-user app, no need for Redis)
_event_queue: Queue = Queue()

async def push_event(event_type: str, data: dict):
    """Called by other modules to push events to the connected client."""
    await _event_queue.put({"type": event_type, "data": data})

@router.get("/events/stream")
async def event_stream():
    async def generate():
        # Send initial context snapshot
        yield ServerSentEvent(data=json.dumps({"type": "context", ...}))
        # Then stream events as they arrive
        while True:
            event = await _event_queue.get()
            yield ServerSentEvent(data=json.dumps(event))
    return EventSourceResponse(generate())
```

```swift
// Swift: ChatService — SSE event listener
private func startEventStream() {
    eventStreamTask = Task { [weak self] in
        guard let url = ErestorConfig.url(for: "/v1/events/stream") else { return }
        var request = URLRequest(url: url)
        ErestorConfig.authorize(&request)
        request.timeoutInterval = .infinity

        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let json = String(line.dropFirst(6))
                await self?.handleSSEEvent(json)
            }
        } catch {
            // Reconnect after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.startEventStream()
        }
    }
}
```

### Pattern 2: Anthropic SDK Token Streaming via SSE Relay
**What:** Backend uses Anthropic Python SDK for true token-by-token streaming, relays each token as SSE event to the Swift client
**When to use:** Chat endpoint (CHAT-02)

```python
# Backend: api/routers/chat.py (rewritten)
import anthropic
from sse_starlette.sse import EventSourceResponse, ServerSentEvent

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env

@router.post("/chat/stream")
async def chat_stream(req: ChatRequest):
    async def generate():
        try:
            with client.messages.stream(
                model="claude-sonnet-4-20250514",
                max_tokens=4096,
                system=_build_system_prompt(),
                messages=_build_messages(req.message),
            ) as stream:
                for text in stream.text_stream:
                    yield ServerSentEvent(
                        data=json.dumps({"text": text}),
                        event="message"
                    )
            # Final event with actions
            response = stream.get_final_message()
            full_text = response.content[0].text
            actions = _parse_actions(full_text)
            yield ServerSentEvent(
                data=json.dumps({
                    "done": True,
                    "full_response": full_text,
                    "actions": actions
                }),
                event="done"
            )
        except Exception as exc:
            yield ServerSentEvent(
                data=json.dumps({"error": str(exc)}),
                event="error"
            )
    return EventSourceResponse(generate())
```

**Note:** The Anthropic SDK's `client.messages.stream()` is synchronous by default. For async FastAPI, use `anthropic.AsyncAnthropic()` with `async with client.messages.stream(...) as stream: async for text in stream.text_stream:`.

### Pattern 3: Native SwiftUI Chat with Streaming Markdown
**What:** Replace WKWebView with SwiftUI ScrollView + MarkdownUI for message rendering
**When to use:** Chat display (CHAT-02, CHAT-03, CHAT-04)

```swift
// ChatMessageView.swift — single message with markdown
import MarkdownUI

struct ChatMessageView: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(message.role == .user ? "kevin" : "erestor")
                .font(DS.mono(9))
                .foregroundColor(DS.muted)

            if message.role == .assistant {
                Markdown(message.text)
                    .markdownTheme(.erestor)  // custom theme using DS colors
                    .font(DS.body(11.5))
                if isStreaming {
                    // Blinking cursor
                    Text("|")
                        .font(DS.mono(11.5))
                        .foregroundColor(DS.green)
                        .opacity(cursorOpacity)
                }
            } else {
                Text(message.text)
                    .font(DS.body(11.5))
                    .foregroundColor(DS.subtle)
            }
        }
    }
}
```

### Pattern 4: Poll Data Storage in SQLite
**What:** Store poll responses in structured tables for synthesis queries
**When to use:** DATA-04, SYNT-01, SYNT-02

```sql
-- Add to event_store.py init_db()
CREATE TABLE IF NOT EXISTS poll_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts REAL NOT NULL,
    date TEXT NOT NULL,
    poll_type TEXT NOT NULL,       -- energy, block_quality, day, mentoria
    value TEXT NOT NULL,           -- the selected option
    context TEXT DEFAULT '{}',    -- JSON: event title, timer info, etc.
    source TEXT DEFAULT 'desktop', -- desktop or telegram
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_poll_responses_date ON poll_responses(date);
CREATE INDEX IF NOT EXISTS idx_poll_responses_type ON poll_responses(poll_type);
```

### Anti-Patterns to Avoid
- **Multiple polling loops:** Current code has 3s push polling + 5s context polling + 5s status polling. Replace ALL with single SSE stream + reconnect logic
- **WKWebView for chat:** Adds complexity (JS escaping, bridge coordination, DOM manipulation). Native SwiftUI is simpler and more maintainable
- **Synchronous Anthropic SDK in async handler:** The `client.messages.stream()` is sync. Must use `AsyncAnthropic()` or wrap in `asyncio.to_thread` to avoid blocking the FastAPI event loop
- **Storing poll data in JSON files:** Current Telegram bot uses individual JSON files per poll type. Phase 2 must use SQLite for queryable synthesis data

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown rendering | Custom AttributedString parser | MarkdownUI 2.4.0 | GFM spec compliance, code blocks, tables, lists -- hundreds of edge cases |
| Code syntax highlighting | Manual regex highlighting | HighlightSwift 1.1.0 | 50+ languages, theme system, dark mode sync |
| SSE client reconnection | Manual retry logic | URLSession.bytes with reconnect wrapper | Built-in HTTP keep-alive, proper error handling |
| Token streaming from Claude | CLI subprocess parsing | Anthropic Python SDK | Official API, proper streaming, error handling, rate limiting |
| Poll expiry management | Custom timer tracking | Backend-driven expiry via SSE events | Single source of truth for poll lifecycle |

**Key insight:** The existing codebase already has most of the UI components (PollCardView, GateAlertView, EventCardView, etc.). The main work is plumbing -- connecting backend events to frontend views via SSE rather than polling, and replacing WKWebView with native SwiftUI.

## Common Pitfalls

### Pitfall 1: SSE Connection Drops Without Reconnection
**What goes wrong:** The SSE stream silently disconnects (network change, sleep/wake, server restart) and the app shows stale data
**Why it happens:** URLSession doesn't auto-reconnect SSE streams; the connection just dies
**How to avoid:** Implement reconnection with exponential backoff in the SSE client. Send periodic heartbeat events from backend (every 30s). Detect connection loss via heartbeat timeout.
**Warning signs:** Panel shows stale context, polls don't appear, chat stops streaming

### Pitfall 2: Anthropic SDK Blocking the Event Loop
**What goes wrong:** Chat requests hang because the sync Anthropic SDK blocks FastAPI's async event loop
**Why it happens:** `anthropic.Anthropic()` is synchronous. Using it in an `async def` handler blocks everything
**How to avoid:** Use `anthropic.AsyncAnthropic()` with `async with client.messages.stream(...)`. Or use `asyncio.to_thread()` to run sync SDK in a thread pool (pattern already used in context.py)
**Warning signs:** All SSE connections freeze during chat requests

### Pitfall 3: SwiftUI ScrollView Performance with Streaming Updates
**What goes wrong:** Chat scrolls jaggily or drops frames during token-by-token streaming
**Why it happens:** Re-rendering the entire message list on each token update
**How to avoid:** Only update the streaming message's text binding. Use `@State` for the streaming buffer, not `@Published` on ChatService. Batch token updates (e.g., every 50ms)
**Warning signs:** Visible lag when assistant responses stream in

### Pitfall 4: MarkdownUI Re-parsing on Every Token
**What goes wrong:** Each streamed token triggers a full markdown re-parse of the entire message
**Why it happens:** MarkdownUI's `Markdown(text)` view re-parses whenever text changes
**How to avoid:** During streaming, render as plain `Text`. Only switch to `Markdown` view after streaming completes (on `.finished` event). This is the pattern used by ChatGPT's iOS app.
**Warning signs:** CPU spikes during streaming, dropped frames

### Pitfall 5: Notification Actions Not Reaching the App
**What goes wrong:** Kevin responds to a poll notification but the response is lost
**Why it happens:** `UNUserNotificationCenter` action handlers must be registered before the notification fires, and the delegate must be set
**How to avoid:** The delegate and categories are already set up in ErestorApp.swift. Just ensure the `sendPushResponse` method posts to the correct backend endpoint for poll storage
**Warning signs:** Poll responses from notifications don't appear in synthesis data

### Pitfall 6: Python 3.9 Compatibility
**What goes wrong:** Type hints like `dict[str, Any]` or `list[str]` cause runtime crashes
**Why it happens:** Backend runs Python 3.9 which doesn't support PEP 604 union types or lowercase generics
**How to avoid:** Use `from typing import Dict, List, Optional` or `from __future__ import annotations`. Pattern already established in calendar.py
**Warning signs:** `TypeError: 'type' object is not subscriptable` at import time

## Code Examples

### MarkdownUI Custom Theme for Vesper Dark
```swift
// Source: MarkdownUI docs + DS color system
import MarkdownUI

extension MarkdownUI.Theme {
    static let erestor = Theme()
        .text {
            ForegroundColor(DS.text)
            FontSize(11.5)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(10.5)
            ForegroundColor(DS.bright)
            BackgroundColor(DS.bg)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14)
                    ForegroundColor(DS.bright)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(13)
                    ForegroundColor(DS.bright)
                }
        }
        .link {
            ForegroundColor(DS.blue)
        }
        .codeBlock { configuration in
            // Use HighlightSwift for syntax highlighting
            configuration.label
                .padding(8)
                .background(DS.bg)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DS.border, lineWidth: 1)
                )
        }
        .listItem {
            ForegroundColor(DS.text)
        }
}
```

### Anthropic AsyncAnthropic Streaming (Python)
```python
# Source: Anthropic SDK docs
import anthropic

client = anthropic.AsyncAnthropic()  # reads ANTHROPIC_API_KEY env

async def stream_chat(message: str, history: list, system_prompt: str):
    """Yield text tokens from Claude."""
    messages = history + [{"role": "user", "content": message}]
    async with client.messages.stream(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=system_prompt,
        messages=messages,
    ) as stream:
        async for text in stream.text_stream:
            yield text
    # After stream completes, get final message for metadata
    final = await stream.get_final_message()
    return final
```

### SSE Event Types (Backend to Frontend Contract)
```python
# Event types for /v1/events/stream
EVENT_TYPES = {
    "context_update": {  # replaces context polling
        "current_event": {...},
        "timer": {...},
        "next_event": {...},
        "tasks": [...]
    },
    "poll_energy": {
        "poll_id": "uuid",
        "question": "Como ta a energia?",
        "options": ["1-morto", "2-baixa", "3-ok", "4-boa", "5-pico"],
        "expires_at": 1234567890  # Unix timestamp
    },
    "poll_quality": {
        "poll_id": "uuid",
        "question": "Como foi esse bloco?",
        "options": ["perdi", "meh", "ok", "flow"],
        "context": {"event_title": "VENDER | prospecção"}
    },
    "gate_alert": {
        "text": "Bloco acabando em 5min, 2 tarefas abertas",
        "severity": "amber",  # or "red"
        "tasks": ["tarefa 1", "tarefa 2"]
    },
    "poll_expired": {
        "poll_id": "uuid",
        "poll_type": "energy"
    },
    "poll_reminder": {
        "poll_id": "uuid",
        "poll_type": "energy",
        "text": "Ainda nao respondeu o check-in de energia"
    },
    "heartbeat": {
        "ts": 1234567890
    }
}
```

### Collapsible Task Section
```swift
struct CollapsibleTasksView: View {
    let tasks: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("tarefas")
                        .font(DS.mono(9))
                        .foregroundColor(DS.dim)
                    Spacer()
                    Text("\(tasks.count)")
                        .font(DS.mono(9))
                        .foregroundColor(DS.muted)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(DS.muted)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if isExpanded {
                TaskListView(tasks: tasks)
                    .transition(.opacity)
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WKWebView + chat.html for chat | Native SwiftUI chat with MarkdownUI | Phase 2 | Eliminates JS bridge complexity, better streaming UX |
| CLI subprocess `claude --print` | Anthropic Python SDK `client.messages.stream()` | Phase 2 | True token-by-token streaming, proper error handling |
| 5s context polling + 3s push polling | Single persistent SSE event stream | Phase 2 | Real-time updates, lower resource usage |
| JSON file poll storage | SQLite poll_responses table | Phase 2 | Queryable data for synthesis, no file I/O race conditions |
| Telegram-only polls | Native macOS UI + notifications | Phase 2 | Replaces Telegram as primary interface |

**Deprecated/outdated:**
- `chat.html` + `chat.css`: Removed, replaced by native SwiftUI
- `ChatWebViewVC.swift`: Removed, no longer needed
- `ChatWebViewController`: Removed
- `startPushPolling()` in ChatService: Replaced by SSE event stream
- `startContextPolling()` in BubbleWindowController: Replaced by SSE event stream

## Open Questions

1. **MarkdownUI streaming performance**
   - What we know: MarkdownUI re-parses on every text change. During streaming, this could cause lag.
   - What's unclear: Exact performance characteristics at 11.5pt font in a 288px wide panel
   - Recommendation: Render streaming text as plain `Text`, switch to `Markdown` on stream completion. Test and adjust.

2. **Anthropic SDK async compatibility with Python 3.9**
   - What we know: AsyncAnthropic exists and works. Python 3.9 is the runtime.
   - What's unclear: Whether `anthropic` package latest version still supports Python 3.9
   - Recommendation: Pin `anthropic` version, test import on Python 3.9 before deploying

3. **SSE reconnection during sleep/wake**
   - What we know: macOS puts URLSession connections to sleep. On wake, the SSE stream may be dead.
   - What's unclear: Exact behavior of URLSession.bytes during sleep/wake cycles
   - Recommendation: Implement heartbeat-based liveness detection. On wake notification (`NSWorkspace.didWakeNotification`), force reconnect.

4. **System prompt construction for Anthropic SDK**
   - What we know: Current CLI approach reads CLAUDE.md as context. SDK needs explicit system prompt.
   - What's unclear: Exact prompt construction -- how much context to include, how to inject WorldState
   - Recommendation: Build system prompt from soul.md + relevant CLAUDE.md sections + current WorldState snapshot. Keep under 8K tokens.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (Python backend) |
| Config file | ~/claude-sync/produtividade/pytest.ini or pyproject.toml |
| Quick run command | `cd ~/claude-sync/produtividade && python -m pytest tests/ -x --timeout=10` |
| Full suite command | `cd ~/claude-sync/produtividade && python -m pytest tests/ --timeout=30` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PANEL-07 | SSE event stream delivers context updates | integration | `pytest tests/test_events_stream.py -x` | -- Wave 0 |
| CHAT-02 | Anthropic SDK streaming yields tokens via SSE | unit | `pytest tests/test_chat_anthropic.py -x` | -- Wave 0 |
| DATA-01 | Energy poll created and delivered via SSE | unit | `pytest tests/test_polls_api.py::test_energy_poll -x` | -- Wave 0 |
| DATA-02 | Block quality poll triggered on event end | unit | `pytest tests/test_polls_api.py::test_block_quality -x` | -- Wave 0 |
| DATA-04 | Poll response stored in SQLite | unit | `pytest tests/test_polls_api.py::test_store_response -x` | -- Wave 0 |
| SYNT-01 | Synthesis queries poll data from SQLite | unit | `pytest tests/test_synthesis_api.py::test_synthesis_query -x` | -- Wave 0 |
| SYNT-02 | On-demand insights endpoint returns data | integration | `pytest tests/test_synthesis_api.py::test_on_demand -x` | -- Wave 0 |
| PANEL-01 | Floating bubble NSPanel | manual-only | N/A (visual, AppKit) | N/A |
| PANEL-02 | Global hotkey toggle | manual-only | N/A (Carbon, requires UI) | N/A |
| PANEL-03-06 | Context cards render correctly | manual-only | N/A (SwiftUI views) | N/A |
| CHAT-01 | NL commands create events/reminders | integration | `pytest tests/test_chat_anthropic.py::test_action_parsing -x` | -- Wave 0 |
| CHAT-03 | Conversation history within session | manual-only | N/A (Swift state) | N/A |
| CHAT-04 | Chat input always visible | manual-only | N/A (SwiftUI layout) | N/A |
| DATA-03 | Gate alerts push via SSE | unit | `pytest tests/test_events_stream.py::test_gate_push -x` | -- Wave 0 |
| NOTF-01 | macOS notifications with inline actions | manual-only | N/A (UNUserNotificationCenter) | N/A |

### Sampling Rate
- **Per task commit:** `cd ~/claude-sync/produtividade && python -m pytest tests/ -x --timeout=10`
- **Per wave merge:** `cd ~/claude-sync/produtividade && python -m pytest tests/ --timeout=30`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_events_stream.py` -- covers PANEL-07, DATA-03 (SSE event stream)
- [ ] `tests/test_chat_anthropic.py` -- covers CHAT-02, CHAT-01 (Anthropic SDK streaming)
- [ ] `tests/test_polls_api.py` -- covers DATA-01, DATA-02, DATA-04 (poll CRUD)
- [ ] `tests/test_synthesis_api.py` -- covers SYNT-01, SYNT-02 (synthesis queries)

## Sources

### Primary (HIGH confidence)
- Existing codebase: `~/projetos/erestor/ErestorApp/` -- all Swift source files read and analyzed
- Existing codebase: `~/claude-sync/produtividade/api/` -- all backend API files read and analyzed
- Existing codebase: `~/claude-sync/produtividade/erestor/` -- synthesis.py, polls.py, event_store.py analyzed
- [Anthropic SDK streaming docs](https://platform.claude.com/docs/en/api/messages-streaming) -- official API docs for `client.messages.stream()` with `text_stream` iteration

### Secondary (MEDIUM confidence)
- [MarkdownUI GitHub](https://github.com/gonzalezreal/swift-markdown-ui) -- v2.4.0, maintenance mode, GFM-compatible
- [HighlightSwift GitHub](https://github.com/appstefan/HighlightSwift) -- v1.1.0, 50+ languages, SwiftUI `CodeText` view
- [Textual GitHub](https://github.com/gonzalezreal/textual) -- v0.1.0, too early for production
- [FastAPI SSE docs](https://fastapi.tiangolo.com/tutorial/server-sent-events/) -- sse-starlette integration pattern

### Tertiary (LOW confidence)
- MarkdownUI streaming performance characteristics -- not verified with benchmarks, based on general SwiftUI rendering knowledge

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- libraries verified via GitHub, versions confirmed, patterns match existing codebase
- Architecture: HIGH -- patterns derived from existing codebase analysis, SSE/streaming well-documented
- Pitfalls: HIGH -- derived from actual code analysis (Python 3.9 compat issues already encountered in Phase 1, SSE patterns understood from existing ChatService implementation)

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable libraries, no fast-moving dependencies)
