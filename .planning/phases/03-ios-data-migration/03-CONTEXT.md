# Phase 3: iOS + Data Migration - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

iOS app with contextual panel, full day agenda, inline polls, push notifications with actions (APNs), and migration of all historical Telegram-era data (mood/energy, memory system, logs) into the new SQLite-based system. Kevin gets mobile access to Erestor on iPhone and all historical data becomes queryable.

</domain>

<decisions>
## Implementation Decisions

### App structure
- Tab bar with 4 tabs: Painel (contexto+alerts), Chat, Agenda, Insights
- Painel uses stacked cards for each section (current event, timer, next event, tasks)
- Polls and gate alerts appear as modal sheets (bottom sheet pattern) — not inline cards like macOS
- Gate alerts: push notification + modal sheet when app is open
- iOS target already exists in project.yml with correct excludes (BubbleWindowController, GlobalHotkey, ActionHandler)

### Day agenda view
- Timeline vertical with hours on the side and blocks positioned by time (reuse/adapt DayTimelineView.swift)
- Current event gets expanded card showing progress and associated tasks; other events stay compact
- Swipe lateral to navigate between days (yesterday/tomorrow), date displayed at top
- Tapping an event opens a half-sheet with full details (description, tasks, notes)

### Push notification flow
- Poll notifications include response buttons + "Remind in 10min" button — same pattern as macOS notifications
- Energy polls: buttons 1-5 inline in notification
- Block quality polls: buttons perdi/meh/ok/flow inline in notification
- Gate alerts: urgent push notification with sound
- Device token registration already implemented in ErestorApp_iOS.swift

### Data migration
- All historical data imported into SQLite (erestor_events.db) in structured tables
- One-shot migration script (idempotent — can re-run safely if errors occur)
- After migration: historical data queryable via chat ("como foi minha energia em janeiro?") using same SYNT-02 pattern
- After migration: historical data also visible in Insights tab (visualizations, patterns)

### Claude's Discretion
- APNs delivery method: backend Python direct (aioapns) vs Firebase Cloud Messaging — research and decide
- Push deduplication: always send to iPhone, or only when macOS inactive (presence system) — research and decide
- Memory system migration schema: analyze people/, context/, behavior-model.json structures and decide best SQLite schema (tables vs JSON columns)
- Insights tab visualizations: charts, patterns, data presentation approach
- Exact modal sheet design for polls and gates
- Tab bar icons and styling (should follow DS/Vesper Dark theme)

</decisions>

<specifics>
## Specific Ideas

- Polls should feel quick: modal sheet slides up, tap a number, it slides away. Not blocking workflow
- Gate alerts are urgent — push notification should use critical alert style if possible
- Agenda timeline should feel like a calendar day view — familiar to anyone who's used Google Calendar
- Current event expanded in timeline gives Kevin immediate context of "where am I right now"
- Insights tab is where Kevin goes to reflect — "como foi minha semana?" should work both in chat and in Insights with visual data

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ErestorApp_iOS.swift`: iOS entry point with APNs setup, device token registration, and ContextPanelView as root — already functional skeleton
- `ContextPanelView.swift`: Main panel layout — needs iOS-specific adaptation (tab bar wrapper, card-based layout)
- `ChatService.swift`: SSE streaming, API communication — fully shared with iOS target
- `ErestorConfig.swift`: API config + auth — shared with iOS
- `DayTimelineView.swift`: Day timeline view — exists, needs mobile adaptation
- `EventCardView.swift`, `TimerChipView.swift`, `NextEventView.swift`, `TaskListView.swift`: All shared views, reusable on iOS
- `PollCardView.swift`, `GateAlertView.swift`: Poll/gate UI — adapt to modal sheet pattern for iOS
- `ChatHistoryView.swift`, `ChatInputView.swift`, `ChatMessageView.swift`: Chat views — shared, may need iOS keyboard handling
- `DesignSystem.swift` (DS enum): Vesper Dark theme — fully reusable
- `Color+Hex.swift`: Hex color extension — shared
- `Message.swift`: All models (ChatMessage, ContextSummary, GCalEvent, TaskItem, PushEvent) — shared

### Established Patterns
- `@MainActor ObservableObject` (ChatService) as single state hub — continues
- `DS.*` for all colors/fonts — continues on iOS
- `ErestorConfig.authorize(&request)` for auth — continues
- `CodingKeys` with snake_case mapping — continues
- `os.Logger` with subsystem/category — continues
- MarkdownUI + HighlightSwift packages — already in project.yml, shared with iOS

### Integration Points
- `project.yml`: iOS target already configured, excludes macOS-only files
- `ErestorApp_iOS.swift`: Root scene needs TabView wrapper instead of direct ContextPanelView
- New iOS-specific views needed: TabView wrapper, AgendaView (timeline adaptation), InsightsView, PollSheetView, GateSheetView
- Backend: new APNs router needed, device registration endpoint exists but APNs sending doesn't
- Backend: migration script as standalone Python file in produtividade/
- Backend: Insights data endpoints (historical queries, aggregations)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-ios-data-migration*
*Context gathered: 2026-03-10*
