# Project Research Summary

**Project:** Erestor
**Domain:** Cross-platform personal intelligence assistant (macOS, iOS, web)
**Researched:** 2026-03-09
**Confidence:** MEDIUM-HIGH

## Executive Summary

Erestor is a single-user personal intelligence assistant that currently runs as a Telegram bot with a macOS desktop app. The rebuild replaces Telegram with native clients (macOS, iOS) and a web PWA, all consuming the same Python backend via REST + SSE. The macOS experience is the most demanding platform -- it requires a non-activating floating window (NSPanel), a system-wide hotkey via Carbon, and native notification actions. No cross-platform framework (Tauri 2, React Native, Flutter, Electron) can replicate this. The correct strategy is native Swift for Apple platforms and a lightweight web client for browser access, unified by a shared API contract rather than shared UI code.

The recommended approach preserves the existing Python backend as the source of truth and wraps its proven services (briefing, synthesis, memory, auto-sync) behind a FastAPI layer. This is a rebuild of the interface layer, not a rewrite of the intelligence layer. The critical architectural decision is to avoid the anti-pattern of bolting HTTP endpoints onto Telegram bot handlers -- core logic must be extracted into clean functions that both the new API and the existing bot can call during the transition period.

The top risks are platform abstraction sprawl (trying to maintain three divergent UIs as a solo developer), polling proliferation (the current codebase already has 6+ concurrent polling loops), and the WKWebView/SwiftUI rendering split (two rendering paths for chat that have already diverged). All three must be resolved in the foundation phase before any feature work begins. The mitigation is to commit to a single rendering strategy (web-first with native shell, or pure native), establish SSE as the single real-time channel replacing all polling, and build macOS first to completion before touching iOS.

## Key Findings

### Recommended Stack

Native Swift for macOS and iOS, with a Next.js PWA for web. Two codebases, shared API contract. This is a "right tool for each platform" approach, not "write once run everywhere."

**Core technologies:**
- **Swift 6 + SwiftUI (iOS 17+ / macOS 14+):** Native app for both Apple platforms. SwiftUI for shared UI components (context panel, polls, chat), AppKit retained for macOS-specific window management (NSPanel floating bubble). No cross-platform framework can replicate the floating bubble + Carbon hotkey + non-activating window pattern.
- **AppKit (NSPanel) + Carbon (RegisterEventHotKey):** macOS-only. Required for the floating panel that does not steal focus and the system-wide Cmd+Shift+E hotkey. These are non-negotiable platform requirements.
- **Next.js 15 + TypeScript + Tailwind CSS 4:** Web PWA for browser access. Kevin's standard stack. PWA mode adds installability and push notifications on Safari (macOS 16+ and iOS 16.4+).
- **FastAPI:** New API gateway wrapping existing Python services. REST for CRUD, SSE for streaming. Replaces Telegram as the interface layer.
- **EventSource (native browser API) / URLSession SSE:** SSE streaming for chat on web and native respectively. No WebSocket needed for a single-user system.

**Critical version requirements:** Swift 6 (Xcode 16+), iOS 17+ deployment target (for @Observable macro), macOS 14+ deployment target.

**What NOT to use:** Tauri 2 (iOS support is alpha-quality), React Native macOS (out-of-tree, no NSPanel/Carbon support), Electron (200MB+ for a menu bar utility), Firebase/WebSocket (unnecessary for single-user), SwiftData/CoreData (no local database needed -- server is source of truth).

### Expected Features

**Must have (table stakes -- v1 launch):**
- Backend API (HTTP + SSE) replacing Telegram as interface layer
- Contextual panel on macOS -- current event, timer, next task, always visible
- Chat interface with streaming -- same capabilities as Telegram bot
- Calendar integration (read + write) -- agenda view, event creation via chat
- Timer system visible in panel -- start/stop/label
- Inline energy check-ins (1-5 scale) -- triggered between calendar blocks
- Daily briefing generation -- morning summary to panel
- Daily synthesis (basic) -- end-of-day analysis
- Reminder system with native macOS notifications and actions
- Data migration from Telegram-era system

**Should have (differentiators -- v1.x):**
- Block quality assessment -- "how was that block?" poll after calendar events end (novel, no competitor does this)
- Proactive gate alerts -- "block ends in 15min, task X still open" (AI coach behavior)
- Intelligent poll timing -- context-aware check-ins at natural transitions, not fixed schedules
- iOS app -- mobile context panel + push notifications
- Web interface -- browser fallback when not on Apple devices
- Evolved daily synthesis -- cross all data points with richer LLM prompts

**Defer (v2+):**
- Wearable integration (Apple Watch, Oura)
- Weekly/monthly trend reports
- Pattern detection alerts
- Simple trend visualizations (sparklines)
- Voice interface
- Full task management UI (show tasks, do not build task CRUD)
- Complex data visualizations / charts
- Offline-first architecture (Claude requires internet -- accept the dependency)

**Anti-features (do not build):**
- Multi-user / social features
- Gamification (streaks, badges, XP)
- Food / nutrition tracking
- Automated habit tracking ("set and forget" removes the reflective moment)

### Architecture Approach

Unified API with thin clients. The Python backend is the single source of truth. All clients are stateless renderers that poll `/api/context` for current state, stream `/api/chat/stream` for chat via SSE, poll `/api/push/pending` for server-initiated events, and POST to action endpoints. Client-side state is limited to UI state (panel open/closed, scroll position, streaming buffer).

**Major components:**
1. **API Gateway (FastAPI)** -- HTTP routing, bearer token auth, SSE stream management. Wraps existing Python services, does not rewrite them.
2. **macOS App (SwiftUI + AppKit)** -- Floating bubble, context panel, chat, native notifications, system actions (AppleScript, hotkeys). ~20% platform-specific code.
3. **iOS App (SwiftUI)** -- Context panel, chat, push notifications, mobile agenda. Shares ~80% code with macOS via multiplatform target.
4. **Web App (Next.js PWA or vanilla HTML/JS)** -- Fallback interface consuming the same API. Built last, lowest priority.
5. **Core Services (Python)** -- Chat/LLM, Context Engine, Auto-Sync Agents, Poll/Gate, Memory System, Push/Notify. These already exist and work.

**Key data flows:**
- Chat: Client POST -> API Gateway -> Chat/LLM Service -> Claude API (streaming) -> SSE back to client
- Context: Client polls `/api/context` every 5s -> Context Engine aggregates calendar + timer + tasks + active poll -> JSON snapshot
- Proactive events: Auto-sync agent detects condition -> enqueues PushEvent -> client polls `/api/push/pending` + parallel APNs delivery

### Critical Pitfalls

1. **Platform abstraction sprawl** -- Trying to build and maintain macOS, iOS, and web simultaneously as a solo developer. The codebase already shows divergence (WKWebView chat on macOS vs. SwiftUI chat views on iOS). Prevention: build ONE platform to completion before starting the next. Define a strict shared core (API client, models, state) vs. platform shell (windows, notifications, hotkey) boundary.

2. **Polling proliferation** -- The current codebase has 6+ concurrent polling loops (status 5-60s, push 3s, context 5s from Swift, context 5s from JS, window cleanup 1s, bubble watchdog 5s). Prevention: establish SSE as the single real-time channel. One SSE connection replaces all polling loops. The backend multiplexes event types over this single stream.

3. **WKWebView/SwiftUI rendering split** -- Using WKWebView for some UI and native SwiftUI for other parts of the same feature creates permanent bridge maintenance. The current codebase has fragile stream coordination with multiple tracking variables and "safety cleanup" code. Prevention: pick one rendering strategy. Either go web-first (entire panel is a web app, native shell only provides window management + hotkey + notifications) or go native-first (pure SwiftUI, no WKWebView).

4. **Bot-shaped API** -- Wrapping Telegram bot handlers with HTTP endpoints leaks Telegram abstractions (message IDs, chat IDs, callback queries). Prevention: extract core logic into pure functions with typed inputs/outputs. Build the API layer as a new service calling core logic, not as a wrapper around bot handlers. Run both in parallel during transition.

5. **Notification sprawl** -- Each feature adds notifications independently. 8 calendar blocks + 3 reminders + briefing + gate alerts = user disables everything. Prevention: implement a notification budget (max 2-3 per hour, server-side enforced), use inline panel updates instead of push for non-urgent items, build quiet hours from day one.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation -- API Layer + Rendering Decision
**Rationale:** Everything depends on a stable API contract and a clear rendering strategy. The three most critical pitfalls (platform sprawl, polling proliferation, WKWebView split) must be resolved before any feature work.
**Delivers:** FastAPI gateway wrapping existing Python services; documented API contract (OpenAPI spec); SSE endpoint replacing all polling; rendering strategy decision (web-first or native-first) documented and enforced.
**Addresses:** Backend API (P1), data persistence foundation, core architectural decisions.
**Avoids:** Platform abstraction sprawl (Pitfall 1), polling proliferation (Pitfall 2), WKWebView bridge fragility (Pitfall 3), bot-shaped API (Pitfall 7).

### Phase 2: macOS App -- Primary Platform
**Rationale:** Kevin uses macOS as his primary device. Building macOS first validates the API contract and establishes the shared code (models, services, view models) that iOS will reuse. macOS is also the most complex platform (floating bubble, hotkey, system actions).
**Delivers:** Functional macOS app with context panel, chat with streaming, calendar integration, timer display, inline energy check-ins, daily briefing display, native notifications with actions.
**Addresses:** Contextual panel (P1), chat interface (P1), calendar integration (P1), timer in panel (P1), energy check-ins (P1), daily briefing (P1), daily synthesis basic (P1), native notifications (P1).
**Avoids:** LLM streaming failures (Pitfall 4, build resilience from start), scope creep from trying to share UI with iOS too early.

### Phase 3: Data Collection Pipeline + Migration
**Rationale:** With the macOS app working, add the features that make Erestor uniquely valuable -- block quality assessment, gate alerts, evolved synthesis. Also migrate historical data now that the schema is stable.
**Delivers:** Block quality polls after calendar events, proactive gate alerts, intelligent poll timing (event-boundary triggers), evolved daily synthesis crossing all data points, historical data migrated from Telegram era.
**Addresses:** Block quality assessment (P2), proactive gate alerts (P2), intelligent poll timing (P2), evolved synthesis (P2), data migration (P1).
**Avoids:** Data migration failures (Pitfall 5, schema is stable by now), notification sprawl (Pitfall 6, build notification budget before adding more notification types).

### Phase 4: iOS App
**Rationale:** Shares ~80% code with macOS (models, services, shared views). Simpler platform (no bubble, no hotkey). By this point, shared code is battle-tested on macOS.
**Delivers:** iOS app with context panel, chat, push notifications (APNs), mobile agenda view.
**Addresses:** iOS app (P2), cross-platform access (P1).
**Avoids:** Platform divergence (shared code is proven before iOS uses it).

### Phase 5: Web PWA + Polish
**Rationale:** Built last as fallback interface. The API is stable, features are proven. Web is the lowest-value platform for a personal tool used primarily on Apple devices.
**Delivers:** Browser-accessible context panel and chat, Web Push notifications, WidgetKit widgets for iOS (lock screen / home screen context).
**Addresses:** Web interface (P2), WidgetKit (future), refined synthesis.
**Avoids:** Over-investing in web before native platforms are solid.

### Phase Ordering Rationale

- **API first** because all three clients depend on a stable contract. Building clients against an evolving API wastes effort.
- **macOS before iOS** because it is the primary platform, has the most complexity (AppKit, Carbon, floating windows), and establishes the shared Swift code that iOS will inherit.
- **Data pipeline after macOS** because polls, gate alerts, and block quality need both a working API and a client to display in. Also, migration needs a stable schema target.
- **iOS after data pipeline** because the shared code is proven and the API is feature-complete by then. iOS is a simpler SwiftUI app.
- **Web last** because it is a fallback interface with lower daily-use value. The API it consumes is already stable.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Foundation):** Needs research on FastAPI SSE patterns for multiplexed event streams, and the web-first vs. native-first rendering decision requires prototyping both approaches.
- **Phase 3 (Data Pipeline):** Calendar event-boundary detection for intelligent poll timing needs research on GCal push notifications vs. polling cadence.
- **Phase 4 (iOS):** APNs server-side integration from Python backend needs research on available libraries (apns2, aioapns).
- **Phase 5 (Web):** PWA push notification reliability on iOS Safari 16.4+ needs validation. Web Push API VAPID key setup with Python backend needs research.

Phases with standard patterns (skip research-phase):
- **Phase 2 (macOS):** Well-documented patterns. Current codebase provides the blueprint. SwiftUI + AppKit hybrid is a known pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Current codebase validates Swift native. Tauri 2 and React Native definitively ruled out with evidence. Next.js PWA is proven. |
| Features | HIGH | Clear competitor analysis (Exist, Gyroscope, Daylio, Bearable). Feature dependencies well-mapped. MVP vs. v2 boundaries are crisp. |
| Architecture | HIGH | Thin client + server pattern already proven in production. Component responsibilities clear. Data flows documented. |
| Pitfalls | HIGH | Grounded in actual codebase analysis (6+ polling loops, WKWebView bridge fragility, iOS target divergence). Not theoretical. |

**Overall confidence:** MEDIUM-HIGH (HIGH for what to build, MEDIUM for some implementation details in later phases)

### Gaps to Address

- **Rendering strategy decision:** The research identifies web-first vs. native-first as the most consequential architectural decision, but does not make the final call. STACK.md leans native-first (SwiftUI chat recommended for v2), PITFALLS.md leans web-first (single rendering path). This must be resolved in Phase 1 with prototyping.
- **APNs from Python:** Need to verify Python APNs libraries (apns2, aioapns) and certificate setup for server-side push to iOS.
- **Web Push VAPID setup:** Need to research VAPID key generation and Web Push API integration with the Python backend.
- **Swift 6 concurrency migration:** Whether to adopt complete concurrency checking or stay on Swift 5 mode for the rebuild.
- **@Observable vs. Combine:** Whether to use the Observation framework (@Observable macro, iOS 17+) or stay with Combine (@Published/@ObservableObject). Impacts shared code structure.
- **Web client framework:** STACK.md recommends Next.js PWA; ARCHITECTURE.md recommends vanilla HTML/JS (no framework). Need to decide based on whether the web client needs PWA installability and push notifications (favoring Next.js) or is a minimal fallback (favoring vanilla).

## Sources

### Primary (HIGH confidence)
- Erestor codebase analysis (`.planning/codebase/CONCERNS.md`, 2026-03-09 audit)
- [Apple: Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [Next.js PWA Guide](https://nextjs.org/docs/app/guides/progressive-web-apps)
- [Claude API documentation](https://platform.claude.com/docs/en/api/)

### Secondary (MEDIUM confidence)
- [Tauri 2 iOS feedback (GitHub Discussion #10197)](https://github.com/tauri-apps/tauri/discussions/10197) -- alpha-quality iOS
- [React Native macOS (Microsoft)](https://github.com/microsoft/react-native-macos) -- out-of-tree status
- [FastAPI SSE patterns](https://medium.com/@inandelibas/real-time-notifications-in-python-using-sse-with-fastapi-1c8c54746eb7)
- [Clean Architecture for SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
- [Exist.io](https://exist.io/), [Gyroscope](https://gyrosco.pe/), [Daylio](https://daylio.net/), [Bearable](https://bearable.app/) -- competitor analysis
- [WKWebView memory leaks](https://embrace.io/blog/wkwebview-memory-leaks/)

### Tertiary (LOW confidence)
- [WebKit for SwiftUI (WWDC 2025)](https://dev.to/arshtechpro/wwdc-2025-webkit-for-swiftui-2igc) -- new native WebView in iOS 26, may change rendering strategy calculus
- [PWA Push on iOS](https://brainhub.eu/library/pwa-on-ios) -- iOS PWA limitations, needs real-device validation

---
*Research completed: 2026-03-09*
*Ready for roadmap: yes*
