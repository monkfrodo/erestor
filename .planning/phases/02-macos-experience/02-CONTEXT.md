# Phase 2: macOS Experience - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Fully functional macOS contextual panel replacing Telegram as Kevin's primary Erestor interface. Covers: floating panel with context/alerts/chat, native SwiftUI chat with token-by-token streaming, energy and block quality polls, gate alerts, macOS notifications with inline actions, and evolved daily synthesis. Backend extensions for new data endpoints, poll storage, and Anthropic SDK migration.

</domain>

<decisions>
## Implementation Decisions

### Chat rendering
- Migrate from WKWebView (chat.html) to native SwiftUI chat
- Remove chat.html and ChatWebViewVC — all chat in SwiftUI using DS (DesignSystem) colors/fonts
- Full markdown rendering (bold, lists, code blocks with syntax highlighting) — use swift-markdown or similar parser
- Token-by-token streaming (each word appears in real-time like ChatGPT)
- Backend migrates from CLI subprocess (`claude --print`) to Anthropic Python SDK for true token streaming
- Conversation history persists within session (CHAT-03)
- Chat input always visible at bottom of panel (CHAT-04)

### Poll and gate interaction
- Polls appear both inline in panel (PollCardView) AND as macOS notifications when panel is closed
- Gate alerts appear as macOS notification (with sound/banner) + amber/red card inline in panel — gates are urgent
- Block quality polls (perdi/meh/ok/flow) trigger automatically when calendar event ends
- Energy polls triggered at intelligent moments by backend
- If Kevin doesn't respond to a poll: ONE reminder notification after 10 min, then expires silently
- Expired polls registered as "not answered" in the data
- Poll responses stored in SQLite for synthesis queries

### Panel layout
- Visual hierarchy top-to-bottom: Context (current event + timer + next event) > Alerts (polls/gates, temporary) > Chat (always visible)
- Tasks as collapsible section between context and alerts — shows count when collapsed ("3 tasks"), expands to full list
- Synthesis appears as chat message from Erestor (no dedicated UI section)
- Panel is resizable via drag (ResizeHandleView already exists) — persists size between sessions
- Real-time panel updates via SSE (PANEL-07) — replace current 5s polling for context

### Backend data endpoints
- Poll response data stored in SQLite (same erestor_events.db) — structured tables for energy, block quality
- Daily synthesis runs automatically at 22h + available on-demand via chat ("como foi meu dia?", "como foi minha semana?")
- Synthesis crosses polls, timers, blocks, and energy data (SYNT-01)
- On-demand insights from collected data via chat (SYNT-02)

### Claude's Discretion
- Push mechanism for polls/gates/context updates (SSE channel vs polling vs hybrid)
- How to inject CLAUDE.md context into Anthropic SDK calls (system prompt construction)
- Markdown parser library choice for Swift
- Notification categories and action button design
- Exact poll timing intelligence (when to trigger energy polls)
- Gate alert timing (how many minutes before block ends)

</decisions>

<specifics>
## Specific Ideas

- Token-by-token streaming should feel like ChatGPT — each word appearing smoothly
- Polls should feel non-intrusive: appear, easy to tap a number, disappear. Not modal, not blocking
- Gate alerts should feel urgent but not annoying — one notification, one inline card, that's it
- The panel layout preview Kevin approved: Context at top with progress bar, alerts in middle (temporary), chat at bottom with input always visible
- Synthesis in chat lets Kevin scroll back and read it anytime, and ask follow-up questions about the data

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ChatService.swift`: SSE streaming client already implemented — adapt for new API contract and token-by-token events
- `ActionHandler.swift`: 19+ local action types — stays client-side, no changes needed
- `ErestorConfig.swift`: Centralized API config — update with new `/v1/` endpoints
- `DesignSystem.swift` (`DS` enum): Vesper Dark theme colors/fonts — use for all new SwiftUI views
- `ContextPanelView.swift`: Main panel layout — restructure for new hierarchy
- `PollCardView.swift`: Poll UI card — already exists, may need updates
- `GateAlertView.swift`: Gate alert UI — already exists, may need updates
- `EventCardView.swift`, `TimerChipView.swift`, `NextEventView.swift`, `TaskListView.swift`: All exist and are reusable
- `ResizeHandleView.swift`: Drag resize handle — already exists in BubbleWindowController
- `Color+Hex.swift`: Hex color extension — reusable

### Established Patterns
- `@MainActor ObservableObject` (ChatService) as single state hub — continue this pattern
- `os.Logger` with subsystem/category — continue for all new services
- Singleton pattern (`static let shared`) for services — continue
- `DS.*` for all colors/fonts — never hardcode values
- `ErestorConfig.authorize(&request)` for auth — continue
- `CodingKeys` with snake_case mapping for API models — continue

### Integration Points
- `ChatService.swift` needs new methods for event stream, poll responses
- `BubbleWindowController.swift` needs update: remove WKWebView setup, embed SwiftUI chat
- `ErestorApp.swift` notification categories need expansion for polls and gates
- `Models/Message.swift` needs new models for poll events, gate events, synthesis
- Backend `~/claude-sync/produtividade/api/` needs new routers: polls, events, synthesis
- Backend needs Anthropic SDK integration replacing CLI subprocess in chat router

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-macos-experience*
*Context gathered: 2026-03-09*
