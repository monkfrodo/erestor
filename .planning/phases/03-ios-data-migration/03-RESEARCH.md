# Phase 3: iOS + Data Migration - Research

**Researched:** 2026-03-10
**Domain:** iOS SwiftUI app development, APNs push notifications, SQLite data migration
**Confidence:** HIGH

## Summary

Phase 3 involves two parallel workstreams: (1) building an iOS app that wraps existing shared Swift views into a tab-based mobile experience with polls as modal sheets and push notifications via APNs, and (2) migrating all historical Telegram-era data (memory system, logs, signals) into the existing SQLite database.

The iOS app has strong foundations already: the `ErestorApp-iOS` target exists in `project.yml` with correct excludes, `ErestorApp_iOS.swift` has APNs device token registration, `ChatService.swift` is fully shared, and all core views (EventCardView, TimerChipView, PollCardView, etc.) use `DS.*` design tokens that work cross-platform. The backend already has a working `erestor/apns.py` module using JWT/ES256 token-based auth via httpx HTTP/2 -- this just needs to be wired into the poll scheduler. The migration script `migrate-history.py` already handles signals and logs; it needs extension to cover the memory system (people/, context/, behavior-model.json).

**Primary recommendation:** Build the iOS app by wrapping existing shared views in a TabView, add iOS-specific views (AgendaView, InsightsView, PollSheetView, GateSheetView), wire APNs sending into the events router poll scheduler, and extend the migration script to cover all memory system data.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Tab bar with 4 tabs: Painel (contexto+alerts), Chat, Agenda, Insights
- Painel uses stacked cards for each section (current event, timer, next event, tasks)
- Polls and gate alerts appear as modal sheets (bottom sheet pattern) -- not inline cards like macOS
- Gate alerts: push notification + modal sheet when app is open
- iOS target already exists in project.yml with correct excludes (BubbleWindowController, GlobalHotkey, ActionHandler)
- Timeline vertical with hours on the side and blocks positioned by time (reuse/adapt DayTimelineView.swift)
- Current event gets expanded card showing progress and associated tasks; other events stay compact
- Swipe lateral to navigate between days (yesterday/tomorrow), date displayed at top
- Tapping an event opens a half-sheet with full details (description, tasks, notes)
- Poll notifications include response buttons + "Remind in 10min" button
- Energy polls: buttons 1-5 inline in notification
- Block quality polls: buttons perdi/meh/ok/flow inline in notification
- Gate alerts: urgent push notification with sound
- Device token registration already implemented in ErestorApp_iOS.swift
- All historical data imported into SQLite (erestor_events.db) in structured tables
- One-shot migration script (idempotent -- can re-run safely if errors occur)
- After migration: historical data queryable via chat using SYNT-02 pattern
- After migration: historical data also visible in Insights tab

### Claude's Discretion
- APNs delivery method: backend Python direct (aioapns) vs Firebase Cloud Messaging -- research and decide
- Push deduplication: always send to iPhone, or only when macOS inactive (presence system) -- research and decide
- Memory system migration schema: analyze people/, context/, behavior-model.json structures and decide best SQLite schema
- Insights tab visualizations: charts, patterns, data presentation approach
- Exact modal sheet design for polls and gates
- Tab bar icons and styling (should follow DS/Vesper Dark theme)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IOS-01 | Contextual panel adapted for iPhone (event, timer, tasks, chat) | Existing ContextPanelView + shared views, wrap in TabView Painel tab with stacked cards |
| IOS-02 | Full day agenda view with all scheduled blocks | Adapt existing DayTimelineView into vertical timeline with time-positioned blocks, swipe navigation |
| IOS-03 | Inline energy and block quality polls | PollCardView/GateAlertView adapted as modal bottom sheets via .sheet + presentationDetents |
| IOS-04 | Push notifications with inline actions (APNs) | Existing apns.py module + UNNotificationCategory with action buttons on iOS |
| NOTF-02 | iOS push notifications via APNs with inline actions | Wire apns.py into events router poll scheduler, register notification categories in AppDelegate |
| MIGR-01 | Historical mood/energy data migrated from Telegram system | Extend migrate-history.py to cover weekly-signals.json fully (already partial) |
| MIGR-02 | Memory system data (people, projects, context) migrated to new storage | New migration for people/*.md, context/*.md, behavior-model.json into SQLite tables |
| MIGR-03 | Log history preserved and accessible in new system | Already handled by migrate_logs() in migrate-history.py, verify completeness |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI framework | Native, already used in macOS app |
| Swift Charts | iOS 17+ | Data visualization for Insights | Apple-native, declarative, dark mode free |
| UserNotifications | iOS 17+ | Push notification handling + categories | System framework, already imported |
| httpx | 0.27+ | HTTP/2 APNs delivery from Python | Already used in apns.py, supports HTTP/2 |
| PyJWT | 2.x | JWT token generation for APNs auth | Already used in apns.py |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MarkdownUI | 2.4+ | Chat message rendering | Already in project.yml, shared with iOS |
| HighlightSwift | 1.1+ | Code syntax highlighting in chat | Already in project.yml, shared with iOS |
| sse-starlette | existing | SSE event stream | Already in backend, no changes needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct APNs (httpx) | Firebase Cloud Messaging | FCM adds dependency, extra config; direct APNs is simpler for single-user, already implemented |
| Swift Charts | DGCharts (danielgindi/Charts) | Third-party adds dependency; Swift Charts is native, sufficient for energy/signal viz |

**Recommendation (Claude's Discretion - APNs):** Use the existing `erestor/apns.py` direct APNs client. It already works with JWT/ES256 token auth via httpx HTTP/2. FCM would add Firebase SDK dependency and an intermediary service for zero benefit in a single-user app. The APNs module just needs to be called from the poll scheduler when events are triggered.

**Installation:**
No new packages needed. All dependencies already exist in the project.

## Architecture Patterns

### Recommended Project Structure
```
ErestorApp/
  ErestorApp/
    iOS/
      ErestorApp_iOS.swift          # Entry point (exists, needs TabView)
      ErestorApp_iOS.entitlements   # APNs entitlement (exists)
      Info.plist                     # iOS info (exists)
      Assets.xcassets               # iOS assets (exists)
    Views/
      # Shared views (already exist, used by both targets):
      EventCardView.swift
      TimerChipView.swift
      NextEventView.swift
      TaskListView.swift
      PollCardView.swift
      GateAlertView.swift
      ChatHistoryView.swift
      ChatInputView.swift
      ChatMessageView.swift
      DayTimelineView.swift
      DesignSystem.swift
      ContextPanelView.swift
      CollapsibleTasksView.swift
      # NEW iOS-specific views:
      iOS_TabRootView.swift         # TabView wrapper with 4 tabs
      iOS_PainelView.swift          # Painel tab (stacked cards)
      iOS_AgendaView.swift          # Day agenda timeline
      iOS_InsightsView.swift        # Insights tab with charts
      iOS_PollSheetView.swift       # Poll modal bottom sheet
      iOS_GateSheetView.swift       # Gate alert modal sheet
      iOS_EventDetailSheet.swift    # Event detail half-sheet
    Models/
      Message.swift                 # Shared models (exists)
      SSEEvent.swift                # SSE event types (exists)
    Services/
      ChatService.swift             # Shared service (exists)
      ErestorConfig.swift           # Shared config (exists)
    Extensions/
      Color+Hex.swift               # Shared (exists)
```

### Pattern 1: TabView with Shared State
**What:** Single ChatService instance shared across all tabs via `@StateObject` in app root, passed as `@ObservedObject` to tab views.
**When to use:** iOS app entry point.
**Example:**
```swift
// Source: existing ErestorApp_iOS.swift pattern
@main
struct ErestorIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate_iOS.self) var appDelegate
    @StateObject private var chatService = ChatService()

    var body: some Scene {
        WindowGroup {
            iOS_TabRootView(chatService: chatService)
                .preferredColorScheme(.dark)
        }
    }
}
```

### Pattern 2: Poll/Gate as Modal Bottom Sheet
**What:** When polls or gates arrive via SSE, present them as bottom sheets instead of inline cards.
**When to use:** iOS poll/gate display (different from macOS inline approach).
**Example:**
```swift
// Source: SwiftUI presentationDetents API (iOS 16+)
.sheet(item: $activePoll) { poll in
    iOS_PollSheetView(poll: poll, onResponse: { value in
        Task { await respondToPoll(pollId: poll.pollId, value: value) }
        activePoll = nil
    })
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
}
```

### Pattern 3: APNs Integration in Poll Scheduler
**What:** When the poll scheduler triggers a poll or gate event, also send APNs push to registered iOS device.
**When to use:** Backend poll/gate triggering.
**Example:**
```python
# In events router, after push_event() calls:
from erestor.apns import APNs
from erestor_api import _load_devices

apns_client = APNs()
devices = _load_devices()
ios_device = devices.get("ios", {})
if ios_device and apns_client.is_configured:
    apns_client.send_push(
        device_token=ios_device["device_token"],
        title="Erestor",
        body="Como ta a energia?",
        category="POLL_ENERGY",
        data={"poll_id": poll_id, "poll_type": "energy"},
    )
```

### Pattern 4: Notification Categories with Action Buttons
**What:** Register UNNotificationCategory instances with action buttons for polls.
**When to use:** iOS app startup (AppDelegate).
**Example:**
```swift
// Register in didFinishLaunchingWithOptions
let energy1 = UNNotificationAction(identifier: "ENERGY_1", title: "1-morto")
let energy2 = UNNotificationAction(identifier: "ENERGY_2", title: "2-baixa")
let energy3 = UNNotificationAction(identifier: "ENERGY_3", title: "3-ok")
let energy4 = UNNotificationAction(identifier: "ENERGY_4", title: "4-boa")
let energy5 = UNNotificationAction(identifier: "ENERGY_5", title: "5-pico")
let remind  = UNNotificationAction(identifier: "REMIND_10", title: "Lembrar em 10min")

let energyCategory = UNNotificationCategory(
    identifier: "POLL_ENERGY",
    actions: [energy1, energy2, energy3, energy4, energy5, remind],
    intentIdentifiers: []
)

// Similar for POLL_QUALITY and GATE_INFORM
UNUserNotificationCenter.current().setNotificationCategories([
    energyCategory, qualityCategory, gateCategory
])
```

### Pattern 5: Day Timeline with Time-Positioned Blocks
**What:** Vertical timeline where events are positioned proportionally to their time slot (like Google Calendar day view).
**When to use:** Agenda tab.
**Example:**
```swift
// Proportional positioning based on time
let hourHeight: CGFloat = 60  // px per hour
let startOffset = CGFloat(event.startHour - 8) * hourHeight  // 8am start

ZStack(alignment: .topLeading) {
    // Hour markers
    ForEach(8..<23, id: \.self) { hour in
        Text("\(hour):00")
            .offset(y: CGFloat(hour - 8) * hourHeight)
    }
    // Event blocks positioned by time
    ForEach(events) { event in
        EventBlock(event: event)
            .offset(y: startOffset)
            .frame(height: durationHeight)
    }
}
```

### Anti-Patterns to Avoid
- **Sharing BubbleWindowController code with iOS:** The `#if os(macOS)` guards exist for a reason. iOS should never reference NSPanel, Carbon, or window controller code.
- **Polling for context on iOS:** Use the SSE stream (ChatService already does this). Never add a polling timer.
- **Putting polls inline on iOS:** Context says modal sheets. Do not replicate the macOS inline-card pattern.
- **Blocking main thread for APNs:** The `apns.py` uses synchronous httpx. Call it via `asyncio.to_thread` in the FastAPI event loop.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| APNs JWT token auth | Custom JWT + HTTP/2 code | Existing `erestor/apns.py` | Already handles token caching, HTTP/2, error cases |
| Charts/visualizations | Custom drawing code | Swift Charts framework | Native, accessible, dark mode, VoiceOver support for free |
| Bottom sheets | Custom gesture-driven panels | SwiftUI `.sheet` + `presentationDetents` | Native API since iOS 16, handles all edge cases |
| Notification categories | Custom notification UI | UNNotificationCategory + UNNotificationAction | System API, handles background wake and action routing |
| Day timeline layout | Custom Core Graphics | SwiftUI ZStack with proportional offsets | Simple math, no need for custom layout engine |
| Data migration | Custom file parsers | Extend existing `migrate-history.py` | Already handles signals and logs; just add memory system |

**Key insight:** The existing codebase has 80%+ of what's needed. The iOS work is primarily wrapping existing shared views in new iOS-specific containers. The migration work extends an existing script.

## Common Pitfalls

### Pitfall 1: SSE Connection Lifecycle on iOS
**What goes wrong:** iOS aggressively suspends background apps, killing SSE connections. On resume, the app shows stale data.
**Why it happens:** iOS background execution limits. URLSession background tasks don't support SSE.
**How to avoid:** Use `scenePhase` to detect foreground/background transitions. On `.active`, restart the SSE stream (ChatService already has `startEventStream()`). On `.background`, cancel it to free resources. Add a `NotificationCenter` observer for `UIApplication.willEnterForegroundNotification`.
**Warning signs:** Context panel shows stale data after switching back to Erestor from another app.

### Pitfall 2: Notification Action Buttons Limit
**What goes wrong:** iOS limits the number of notification action buttons to 4. Energy polls have 5 options + "remind in 10min" = 6 buttons.
**Why it happens:** Apple UX guidelines and system constraints.
**How to avoid:** For energy polls, use 4 action buttons (combine 1-2 into "baixa" and 4-5 into "alta") in the notification, with full 5-option UI in the modal sheet when the notification is tapped. Or use a notification content extension for custom UI.
**Warning signs:** Not all poll options appearing in notification.

### Pitfall 3: APNs Certificate vs Token Auth
**What goes wrong:** Confusing certificate-based and token-based APNs auth setup.
**Why it happens:** Two different auth methods exist, older tutorials use certificates.
**How to avoid:** The existing `apns.py` uses token-based (JWT/ES256) auth. Requires: `.p8` key file from Apple Developer, Key ID, Team ID, and bundle ID. No certificate renewal needed. Config stored in `~/.erestor_apns_config`.
**Warning signs:** 403 errors from APNs = wrong auth method or expired token.

### Pitfall 4: Push Notification Deduplication
**What goes wrong:** Kevin gets duplicate notifications on macOS and iOS for the same poll.
**Why it happens:** The SSE stream delivers polls to macOS and APNs delivers to iOS simultaneously.
**How to avoid:** **Recommendation (Claude's Discretion):** Always send APNs to iOS regardless of macOS presence. On macOS, the SSE stream handles polls directly. On iOS, APNs is needed because the app may be backgrounded. The poll response endpoint already marks the poll as answered, preventing double-counting. The UX is acceptable: if Kevin responds on macOS, the poll disappears from both (via poll_expired SSE event and notification removal).
**Warning signs:** Kevin complaining about notification noise.

### Pitfall 5: Migration Idempotency
**What goes wrong:** Running migration twice creates duplicate records.
**Why it happens:** INSERT without proper uniqueness constraints.
**How to avoid:** Use `INSERT OR IGNORE` with unique constraints, or check for existing records before inserting. The current `migrate-history.py` already uses `INSERT OR IGNORE` for daily_signals. Apply the same pattern to new migration tables.
**Warning signs:** Inflated record counts after re-running migration.

### Pitfall 6: Memory System Migration - Markdown Parsing
**What goes wrong:** People and context markdown files have varied formats, parser breaks on unexpected structure.
**Why it happens:** Markdown is semi-structured. People files are short (3-7 lines) but formats vary.
**How to avoid:** Use simple regex or line-by-line parsing. Store the raw markdown alongside structured fields. For behavior-model.json and weekly-signals.json, they're already JSON -- just load and insert.
**Warning signs:** Missing data after migration for specific people or context files.

## Code Examples

### iOS TabView Root with Sheet Binding for Polls
```swift
// Source: SwiftUI TabView + presentationDetents pattern
struct iOS_TabRootView: View {
    @ObservedObject var chatService: ChatService
    @State private var selectedTab = 0
    @State private var activePoll: PollSSEEvent?
    @State private var activeGate: GateSSEEvent?

    var body: some View {
        TabView(selection: $selectedTab) {
            iOS_PainelView(chatService: chatService)
                .tabItem { Label("Painel", systemImage: "square.grid.2x2") }
                .tag(0)

            ChatView(chatService: chatService)
                .tabItem { Label("Chat", systemImage: "bubble.left") }
                .tag(1)

            iOS_AgendaView(chatService: chatService)
                .tabItem { Label("Agenda", systemImage: "calendar") }
                .tag(2)

            iOS_InsightsView(chatService: chatService)
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
        }
        .tint(DS.green)
        .sheet(item: $activePoll) { poll in
            iOS_PollSheetView(poll: poll, onResponse: { value in
                Task { await respondToPoll(pollId: poll.pollId, value: value) }
                activePoll = nil
            })
            .presentationDetents([.fraction(0.35)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeGate) { gate in
            iOS_GateSheetView(gate: gate, onDismiss: { activeGate = nil })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onReceive(chatService.$activePolls) { polls in
            if let poll = polls.last, activePoll == nil {
                activePoll = poll
            }
        }
        .onReceive(chatService.$activeGates) { gates in
            if let gate = gates.last, activeGate == nil {
                activeGate = gate
            }
        }
    }
}
```

### APNs Router Integration
```python
# New endpoint or integration in events router
async def _send_apns_for_poll(poll_type: str, poll_id: str, question: str) -> None:
    """Send APNs push when a poll is created."""
    try:
        from erestor.apns import APNs
        apns = APNs()
        if not apns.is_configured:
            return

        devices_file = Path.home() / "claude-sync/produtividade/erestor/data/devices.json"
        if not devices_file.exists():
            return
        devices = json.loads(devices_file.read_text())
        ios = devices.get("ios", {})
        if not ios:
            return

        category = "POLL_ENERGY" if poll_type == "energy" else "POLL_QUALITY"
        await asyncio.to_thread(
            apns.send_push,
            device_token=ios["device_token"],
            title="Erestor",
            body=question,
            category=category,
            data={"poll_id": poll_id, "poll_type": poll_type},
        )
    except Exception as exc:
        _logger.warning("APNs push failed: %s", exc)
```

### Memory System Migration Schema
```python
# Recommended schema for memory system data
def init_memory_tables(conn):
    """Create tables for migrated memory system data."""
    conn.execute("""CREATE TABLE IF NOT EXISTS memory_people (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        role TEXT DEFAULT '',
        status TEXT DEFAULT '',
        raw_markdown TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS memory_context (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL UNIQUE,
        content_type TEXT NOT NULL,  -- 'behavior_model', 'goals', 'patterns', 'signals', 'health', etc.
        data_json TEXT NOT NULL,     -- JSON for structured data
        raw_text TEXT DEFAULT '',    -- original text for .md files
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS memory_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT DEFAULT 'migration',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""")
    conn.commit()
```

### Insights View with Swift Charts
```swift
// Source: Swift Charts API (iOS 17+)
import Charts

struct EnergyChartView: View {
    let dataPoints: [(date: Date, level: Int)]

    var body: some View {
        Chart(dataPoints, id: \.date) { point in
            LineMark(
                x: .value("Data", point.date, unit: .day),
                y: .value("Energia", point.level)
            )
            .foregroundStyle(DS.green)
            PointMark(
                x: .value("Data", point.date, unit: .day),
                y: .value("Energia", point.level)
            )
            .foregroundStyle(DS.green)
        }
        .chartYScale(domain: 1...5)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day))
        }
    }
}
```

## Discretion Recommendations

### APNs Delivery: Direct (httpx) -- RECOMMENDED
The existing `erestor/apns.py` module is already implemented and tested. It uses JWT/ES256 token-based auth via httpx with HTTP/2 support. For a single-user app, there is zero benefit to adding Firebase. The direct approach has no intermediary, no SDK dependency, and no additional service to configure.

### Push Deduplication: Always Send to iOS -- RECOMMENDED
Always send APNs to iOS for every poll/gate event. Reasons:
1. iOS app may be backgrounded -- APNs is the only reliable delivery
2. SSE stream handles macOS delivery independently
3. The poll response system already prevents double-counting (responding on one platform marks the poll as answered)
4. Suppressing iOS notifications when macOS is active would require real-time presence checking, adding complexity for minimal benefit
5. Kevin is likely at one device at a time anyway

### Memory System Migration Schema: Hybrid (structured + raw) -- RECOMMENDED
Use structured SQLite tables for queryable data (people with name/role fields, behavior patterns as JSON), but also store raw markdown/JSON as a fallback column. This allows:
- Structured queries ("quem sao meus clientes?") via SQL
- Full-text access for Claude when generating insights
- Zero data loss from parsing limitations

### Insights Tab: Swift Charts + Summary Cards -- RECOMMENDED
Use Apple's Swift Charts framework for visualizations:
- Energy trend line chart (last 7/14/30 days)
- Block quality distribution bar chart
- Timer hours by type stacked bar chart
- Weekly patterns heatmap
Cards above charts show today's summary (energy level, hours worked, blocks completed). Data fetched from the same synthesis/query endpoint used by chat.

### Tab Bar: SF Symbols + DS.green tint -- RECOMMENDED
Use system SF Symbols for tab bar icons (already shown in code example above). Tint with DS.green for active state. This follows iOS conventions while maintaining Vesper Dark aesthetic.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Certificate-based APNs | Token-based JWT APNs | 2016+ | No cert renewal, simpler server setup |
| UIKit TabBarController | SwiftUI TabView | iOS 14+ | Declarative, works with existing DS |
| Custom bottom sheets | .sheet + presentationDetents | iOS 16+ | Native, handles all gestures/dismiss |
| DGCharts (third-party) | Swift Charts (Apple) | iOS 16+ (WWDC 2022) | Native, accessible, dark mode free |

## Open Questions

1. **APNs Developer Account Setup**
   - What we know: `apns.py` expects `.p8` key, Key ID, Team ID, bundle ID in `~/.erestor_apns_config`
   - What's unclear: Whether Kevin has already generated the APNs key in Apple Developer portal
   - Recommendation: First task should verify APNs config exists or guide setup

2. **Insights Tab Data Endpoints**
   - What we know: `/v1/synthesis/query` exists for natural language queries, `/v1/synthesis/trigger` for daily synthesis
   - What's unclear: Whether dedicated endpoints for chart data (aggregated energy/quality over time) are needed or if the query endpoint suffices
   - Recommendation: Add a lightweight `/v1/insights/chart-data` endpoint that returns pre-aggregated data for charts (avoids Claude API call per chart render)

3. **iOS App Distribution**
   - What we know: Personal use only (single user, Kevin)
   - What's unclear: TestFlight vs. direct Xcode install on device
   - Recommendation: Direct Xcode install for development; TestFlight if Kevin wants OTA updates

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (Python backend) + XCTest (Swift, not yet configured) |
| Config file | pytest discovered from produtividade/ |
| Quick run command | `python3 -m pytest tests/ -x --timeout=30` |
| Full suite command | `python3 -m pytest tests/ --timeout=60` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IOS-01 | Painel tab shows context cards | manual-only | Xcode simulator visual check | N/A |
| IOS-02 | Agenda view displays day events | manual-only | Xcode simulator visual check | N/A |
| IOS-03 | Polls appear as modal sheets | manual-only | Xcode simulator interaction test | N/A |
| IOS-04 | Push notifications with actions | manual-only | Requires physical device + APNs config | N/A |
| NOTF-02 | APNs push delivery | unit | `pytest tests/test_apns_integration.py -x` | Wave 0 |
| MIGR-01 | Mood/energy data migrated | unit | `pytest tests/test_migration.py::test_signals -x` | Wave 0 |
| MIGR-02 | Memory system data migrated | unit | `pytest tests/test_migration.py::test_memory -x` | Wave 0 |
| MIGR-03 | Log history preserved | unit | `pytest tests/test_migration.py::test_logs -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** Visual verification in Xcode simulator (iOS views) or `pytest tests/ -x` (backend/migration)
- **Per wave merge:** Full test suite + simulator walkthrough
- **Phase gate:** All migration tests green + full iOS app walkthrough on simulator

### Wave 0 Gaps
- [ ] `tests/test_migration.py` -- covers MIGR-01, MIGR-02, MIGR-03 (migration idempotency, data integrity)
- [ ] `tests/test_apns_integration.py` -- covers NOTF-02 (APNs send with mocked httpx)
- [ ] iOS UI tests are manual-only (single user app, simulator verification sufficient)

## Sources

### Primary (HIGH confidence)
- Codebase inspection: `ErestorApp_iOS.swift`, `ChatService.swift`, `project.yml`, `apns.py`, `migrate-history.py`, `events.py` router -- all directly read and analyzed
- [Apple Developer - Swift Charts](https://developer.apple.com/documentation/Charts) -- native charts framework
- [Apple Developer - APNs](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html) -- APNs HTTP/2 protocol

### Secondary (MEDIUM confidence)
- [SwiftUI Bottom Sheets](https://sarunw.com/posts/swiftui-bottom-sheet/) -- presentationDetents usage
- [Hacking with Swift - Bottom Sheet](https://www.hackingwithswift.com/quick-start/swiftui/how-to-display-a-bottom-sheet) -- sheet modifier patterns
- [tanaschita - Notification Actions](https://tanaschita.com/ios-notifications-custom-actions/) -- UNNotificationCategory patterns
- [aioapns PyPI](https://pypi.org/project/aioapns/) -- alternative APNs library (not recommended, existing httpx approach is simpler)

### Tertiary (LOW confidence)
- Notification action button limit (4 max) -- based on general iOS knowledge, should verify with physical device testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries are already in use or are Apple-native frameworks
- Architecture: HIGH - patterns derived from actual codebase analysis, existing code provides clear path
- Pitfalls: HIGH - derived from iOS development experience and codebase analysis
- Migration: HIGH - existing migrate-history.py provides template, data structures directly inspected

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (stable APIs, no fast-moving dependencies)
