# Pitfalls Research

**Domain:** Cross-platform personal intelligence assistant (macOS + iOS + web)
**Researched:** 2026-03-09
**Confidence:** HIGH (based on existing codebase analysis + domain research)

## Critical Pitfalls

### Pitfall 1: Platform Abstraction Sprawl — Three UIs for One Developer

**What goes wrong:**
A solo developer tries to build and maintain native macOS (SwiftUI), native iOS (SwiftUI), and web (HTML/CSS/JS) interfaces simultaneously. Each platform accumulates its own rendering path, event handling, and state management. The codebase becomes three separate apps sharing a name but diverging in behavior. This is already happening in Erestor: macOS uses WKWebView with `chat.html` for chat rendering, while iOS has separate SwiftUI views (`ChatHistoryView`, `ChatInputView`) that have diverged from the WebView implementation. The CONCERNS.md explicitly flags the iOS target as "untested and likely incomplete."

**Why it happens:**
The desire to be everywhere from day one. SwiftUI promises cross-platform code sharing, but macOS and iOS have fundamentally different interaction models (menu bar app vs. full-screen app), different notification systems, and different lifecycle management. Adding web as a third target triples the surface area.

**How to avoid:**
1. Build ONE platform first (web) as the universal baseline that works everywhere including macOS/iOS via a lightweight native wrapper.
2. Only add native-specific features (menu bar bubble, native notifications, global hotkey) as thin platform shells around the shared web core.
3. Never duplicate rendering logic across platforms. The chat UI should render in exactly one place (web view or native — pick one, not both).
4. Define a strict "shared core" (API client, data models, state) vs. "platform shell" (window management, notifications, hotkey) boundary.

**Warning signs:**
- Two or more implementations of the same UI component across platforms
- iOS target that compiles but nobody has tested in weeks
- `#if os(macOS)` / `#if os(iOS)` blocks appearing in view code (not just platform services)
- Different bugs reported on different platforms for the same feature

**Phase to address:**
Phase 1 (Foundation) — Decide the rendering strategy before writing any UI code. This is the single most consequential architectural decision for the project.

---

### Pitfall 2: Polling Proliferation — Death by a Thousand Timers

**What goes wrong:**
Every feature that needs "live" data adds its own polling loop. The app ends up with 5-6 concurrent timers hitting the backend independently, doubling or tripling network traffic, draining battery on mobile, and creating race conditions where stale data from one poll overwrites fresh data from another. This is the current state of the Erestor codebase: status polling (5-60s), push polling (3s), context polling from Swift (5s), context polling from JS (5s), window cleanup (1s), bubble watchdog (5s).

**Why it happens:**
Polling is the path of least resistance. Each feature is developed in isolation, and "just add a timer" is the fastest way to get real-time-ish behavior. Nobody consolidates because the individual timers "work fine" during development.

**How to avoid:**
1. Use Server-Sent Events (SSE) as the single real-time channel from backend to all clients. The backend already supports SSE for chat streaming — extend it to push context updates, notifications, and state changes through one connection.
2. Client sends commands via regular HTTP POST (chat messages, poll responses, timer actions).
3. One SSE connection replaces all polling loops. The backend multiplexes event types over this single stream.
4. Implement reconnection with exponential backoff for mobile network instability.

**Warning signs:**
- More than 2 `setInterval` or `Timer.scheduledTimer` calls in the codebase
- Backend access logs showing repeated identical requests from the same client within seconds
- Mobile battery drain during background operation
- "Context flicker" where the UI briefly shows stale then fresh data

**Phase to address:**
Phase 1 (Foundation) — The real-time communication pattern must be established before any feature builds on top of it. Retrofitting SSE after multiple polling loops exist is significantly harder.

---

### Pitfall 3: WKWebView as Chat Renderer — Two Worlds, Constant Friction

**What goes wrong:**
Using WKWebView to render chat (HTML/CSS/JS) inside a SwiftUI app creates a permanent bridge-maintenance burden. Every interaction between the native app and the web view requires JavaScript injection, message handlers, and careful coordination of two separate state models. The current codebase has fragile stream rendering coordination with multiple tracking variables (`streamFinishedMessageCount`, `renderedCount`, `wasStreaming`, `lastStreamDeltaID`) and a "Safety cleanup block" — a code smell indicating the coordination logic has edge cases nobody fully understands.

**Why it happens:**
HTML/CSS is easier for rich text rendering (markdown, code blocks, links) than SwiftUI's limited text formatting. The developer starts with a web prototype that looks great, wraps it in WKWebView, and commits to maintaining two runtime environments forever.

**How to avoid:**
Two viable paths (pick one, not both):
- **Path A (Web-first):** Embrace the web view fully. Make the entire panel a web app. The native shell only provides: window management, global hotkey, native notifications, and a JS bridge for platform actions. All UI lives in HTML/CSS/JS. This is simpler and means the same UI works on web browsers too.
- **Path B (Native-first):** Use SwiftUI for everything including chat. Use `AttributedString` or a markdown renderer library for rich text. Harder upfront but eliminates the bridge entirely.
- **Never:** Use WKWebView for some parts and native SwiftUI for other parts of the same feature (current situation).

**Warning signs:**
- `evaluateJavaScript()` calls scattered across multiple Swift files
- JavaScript-to-Swift message handler list growing beyond 5 handlers
- Bugs that only reproduce in specific sequences of native + web view interactions
- "Safety" or "fallback" code handling edge cases in the bridge layer

**Phase to address:**
Phase 1 (Foundation) — This decision is coupled with Pitfall 1 (platform strategy). If going web-first, WKWebView becomes a thin container. If going native-first, WKWebView is removed entirely.

---

### Pitfall 4: LLM Streaming Over Unreliable Mobile Networks

**What goes wrong:**
Claude API streaming (SSE) works well on stable desktop connections but breaks on mobile networks that drop idle connections, switch between Wi-Fi and cellular, or go through proxies that buffer SSE responses. The user sees a message that starts streaming, then freezes mid-sentence with no error indication, or the connection silently drops and the app appears "thinking" forever.

**Why it happens:**
Desktop development masks mobile network realities. The developer tests on a fast, stable connection and assumes the happy path is the only path. Claude API responses for complex queries can take 30-60+ seconds of streaming, which is an eternity for a mobile connection that might change networks.

**How to avoid:**
1. Never stream directly from the client to Claude API. The backend should be the single point of contact with Claude, streaming the response to the client via SSE.
2. Implement heartbeat pings in the SSE stream (every 5 seconds) so the client can detect dead connections vs. slow responses.
3. Add client-side timeout detection: if no SSE event received for 10 seconds, show a "reconnecting" indicator.
4. Make streaming resumable: the backend should buffer the complete response so the client can request the full message if the stream was interrupted.
5. Set TCP keep-alive on all connections per Anthropic's own recommendation.

**Warning signs:**
- No heartbeat/ping mechanism in SSE streams
- No timeout handling on the client side
- No way to retrieve a complete message after a partial stream
- Testing only on Wi-Fi, never on cellular or throttled connections

**Phase to address:**
Phase 2 (API Layer) — When building the API endpoints that proxy Claude, build resilience in from the start.

---

### Pitfall 5: Data Migration Treated as a One-Shot Script

**What goes wrong:**
The developer writes a migration script to move historical Telegram data (mood logs, energy check-ins, daily syntheses, chat history) into the new system, runs it once, declares victory, and moves on. Later, they discover missing data, wrong timestamps, broken references, or data that was in Telegram's format but doesn't map cleanly to the new schema. The migration script no longer works because the new schema evolved.

**Why it happens:**
Migration feels like a boring chore, not a feature. The developer wants to build new things, not carefully map old data. Telegram exports use specific formats (JSON with Telegram-specific structures) that don't map 1:1 to a purpose-built schema.

**How to avoid:**
1. Design the new schema first, then map old data to it — never design the schema around the old data format.
2. Make migration idempotent and repeatable. It should be safe to run multiple times without duplicating data.
3. Validate migrated data: count records, verify date ranges, spot-check specific entries.
4. Keep a "raw import" table with the original Telegram data alongside the normalized data, so nothing is lost even if the mapping is wrong.
5. Run the migration against production data early in development, not at the end. This surfaces mapping problems while there's time to fix them.

**Warning signs:**
- Migration script has no validation step
- Script can only be run once (not idempotent)
- No comparison between source record count and destination record count
- Schema designed to match Telegram's data shape rather than the new system's needs

**Phase to address:**
Phase 3 or dedicated milestone — After the new schema is stable but before the system goes live. Migration needs a stable target to migrate into.

---

### Pitfall 6: Notification Sprawl — Annoying the User Into Disabling Everything

**What goes wrong:**
A "proactive" assistant sends too many notifications. Gate alerts, energy check-ins, block quality assessments, reminders, daily briefings — each feature adds notifications independently. The user gets overwhelmed, disables notifications for the app entirely, and loses all proactive value. On iOS, there's a single permission toggle per app — one "no" kills everything.

**Why it happens:**
Each notification type is designed in isolation and seems reasonable on its own. "Just one check-in per calendar block" sounds fine until you have 8 blocks in a day, plus 3 reminders, plus a briefing, plus gate alerts. The developer doesn't experience the cumulative effect because they test features individually.

**How to avoid:**
1. Implement a notification budget: maximum N notifications per hour (start with 2-3), enforced server-side.
2. Use priority levels: only "urgent" notifications (gate alerts, time-sensitive reminders) use native push. Everything else waits for the user to open the panel.
3. Build a "quiet hours" system from day one.
4. Use inline panel updates (energy polls, block quality) instead of push notifications — show them in the UI when the user is already looking, don't interrupt.
5. Track notification dismissal rates. If a notification type is consistently dismissed, reduce its frequency automatically.

**Warning signs:**
- More than 3 notification types shipping without a centralized notification manager
- No server-side throttling of outbound notifications
- No "Do Not Disturb" or quiet hours configuration
- Testing individual notification types without simulating a full day's volume

**Phase to address:**
Phase 3 (Notifications) — Must be designed as a system, not added per-feature.

---

### Pitfall 7: Backend API Bolted Onto a Bot — Wrong Abstraction Layer

**What goes wrong:**
The existing Python backend was designed as a Telegram bot — its "API" is Telegram message handlers. When adding HTTP endpoints for the new clients, the developer wraps existing bot functions with Flask/FastAPI routes. But bot handlers assume a request-response model with Telegram's specific message types, not a general API contract. The result is an API that leaks Telegram abstractions (message IDs, chat IDs, callback queries) and doesn't support features the new UI needs (partial updates, typed responses, batch operations).

**Why it happens:**
The "keep what works" instinct is strong. The bot logic IS working — briefings generate correctly, synthesis runs, memory persists. Wrapping it seems faster than refactoring. But the interface assumptions are baked deeply into the code.

**How to avoid:**
1. Separate the API layer completely from bot interface code. Extract core logic (briefing generation, synthesis, memory operations) into pure functions that take typed inputs and return typed outputs.
2. Build the API layer as a new service that calls core logic functions — not as a wrapper around bot handlers.
3. Define API contracts (request/response schemas) before implementing endpoints. The new UI's needs should drive the API design, not the old bot's message format.
4. Run the new API alongside the Telegram bot during transition, both calling the same core logic.

**Warning signs:**
- API response format includes Telegram-specific fields
- Endpoints that accept or return plain text strings instead of structured JSON
- Core logic functions that import `telegram` or reference `update.message`
- API endpoints that can only do what the Telegram bot could do (no new capabilities)

**Phase to address:**
Phase 1-2 (Foundation/API Layer) — The refactoring of core logic into clean functions should happen before building API endpoints on top.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcoded API credentials in source | Quick setup, no config complexity | Credential rotation requires rebuild; exposed in git | Never — use Keychain or plist excluded from git |
| Polling instead of SSE | Simple to implement, no connection management | Battery drain, redundant traffic, race conditions | Prototype only; replace before any mobile testing |
| Shared WKWebView + native SwiftUI rendering | Leverage existing HTML prototype quickly | Two rendering paths to maintain, fragile bridge coordination | Never — pick one rendering strategy |
| No test coverage | Ship faster initially | Any refactor can silently break features; current 0% test coverage across 3,315 lines | Acceptable for prototype; unacceptable once API layer is stable |
| Dead code kept "just in case" | No effort to remove | Confusion about canonical code paths (e.g., legacy sendMessage) | Never — remove and rely on git history |
| Carbon framework for global hotkey | Works today on macOS | Apple deprecated Carbon; will break in future macOS | Acceptable short-term; migrate to CGEvent or KeyboardShortcuts package before shipping |

## Integration Gotchas

Common mistakes when connecting to external services relevant to Erestor.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Claude API | Streaming directly from mobile client to Claude | Proxy through backend; backend handles auth, rate limits, and response buffering |
| Claude API | No timeout on streaming responses | Set 60s inactivity timeout with heartbeat detection; show "reconnecting" state |
| Claude API | Ignoring rate limits (429 errors) | Implement exponential backoff; cache responses where possible; ramp traffic gradually |
| Google Calendar | Polling GCal API from each client | Backend polls GCal on a schedule and pushes events to clients via SSE |
| macOS Notifications | Using UNUserNotificationCenter without checking authorization status | Always check and handle denied/provisional states; degrade gracefully |
| iOS Notifications | Assuming push notification permission is granted | Request permission at a meaningful moment (not app launch); explain value first |
| SSE connections | No reconnection logic | Auto-reconnect with exponential backoff (1s, 2s, 4s, max 30s); send last-event-ID |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded chat history in memory | Memory grows with session length; app slows after long sessions | Cap at 100-200 messages in memory; paginate history from API | After ~500+ messages in a session |
| DateFormatter created per call | Micro-stutters in UI updates | Use static/cached DateFormatter instances | Noticeable with 1-second timer updates |
| Multiple concurrent polling loops | CPU/battery drain; duplicate API calls | Single SSE connection for all real-time data | Immediately on mobile; subtle on desktop |
| Storing all daily logs/syntheses as flat files | Slow search, no querying capability | Use SQLite or structured storage with indexes | After ~6 months of daily data |
| WKWebView memory leaks | App memory grows over time; potential crash | Reuse single WKWebView instance; never allocate new ones for each chat session | After extended usage sessions |

## Security Mistakes

Domain-specific security issues for a personal assistant with shell access.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Shell command execution without allowlist | Compromised backend = full machine access | Maintain explicit allowlist of permitted commands; log all executions |
| AppleScript injection via unsanitized input | Arbitrary AppleScript execution if backend sends malicious action parameter | Validate action parameters against enum of known values before interpolation |
| API token in source code committed to git | Token exposed to anyone with repo access; rotation requires code change | Store in Keychain (macOS/iOS) or environment variable; inject at runtime |
| Bearer token over HTTP (if URL misconfigured) | Token transmitted in cleartext | Enforce HTTPS-only in API client; reject HTTP URLs programmatically |
| No request signing or replay protection | Intercepted requests could be replayed | Add timestamp + nonce to API requests; reject stale requests |

## UX Pitfalls

Common user experience mistakes for personal assistant apps.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Too many notification types at launch | User disables all notifications, losing proactive value | Start with 1-2 notification types; earn trust before adding more |
| Energy check-in at wrong moments (during deep work) | Interrupts flow state; user starts ignoring check-ins | Only prompt during natural transitions (between calendar blocks, after timer stops) |
| Chat that feels like talking to a blank wall | No personality, generic responses | Maintain Erestor's personality in system prompts; reference specific context |
| Panel that requires interaction to be useful | User stops opening the app | Panel should be glanceable: current event + next event + timer status visible without interaction |
| Synthesis that's too long to read | User skips daily synthesis | Keep synthesis to 3-5 key insights with expandable details |
| Migration that changes familiar patterns | User feels lost in new system | Preserve existing command patterns (natural language) while adding new UI affordances |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **SSE streaming:** Often missing reconnection logic — verify the client auto-reconnects after network drops, WiFi-to-cellular transitions, and server restarts
- [ ] **Native notifications:** Often missing permission request flow — verify the app handles denied permissions gracefully and re-prompts at appropriate times
- [ ] **Chat interface:** Often missing error states — verify behavior when backend is down, Claude returns an error, network times out mid-stream, or rate limit is hit
- [ ] **Energy check-ins:** Often missing persistence of partial data — verify that a check-in started but not completed (app backgrounded) is either saved or cleanly discarded
- [ ] **Data migration:** Often missing validation step — verify record counts match, date ranges are preserved, and edge cases (empty entries, special characters, very long messages) survive
- [ ] **Timer system:** Often missing timezone handling — verify timers display correctly when user travels or system clock changes
- [ ] **iOS app:** Often missing background/foreground lifecycle — verify SSE reconnects on foreground, notifications work in background, and state is preserved across app switches
- [ ] **Web app:** Often missing session expiry — verify the web panel handles token expiry gracefully (auto-refresh or re-auth prompt)

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Platform UI divergence (3 separate implementations) | HIGH | Choose one rendering strategy; rebuild the other platforms using it; accept 2-4 weeks of rework |
| Polling proliferation | MEDIUM | Implement SSE endpoint; migrate one polling loop at a time; remove old timers as each migrates |
| WKWebView bridge fragility | HIGH | Either go full web-first (remove native rendering) or full native (remove WebView); partial migration is impossible |
| LLM stream failures on mobile | LOW | Add heartbeat + timeout detection; can be done incrementally without architecture change |
| Bad data migration | MEDIUM | Keep raw import data; write new mapping; re-run migration (if idempotent) |
| Notification fatigue | LOW | Add server-side throttling; can be tuned without client update |
| Bot-shaped API | HIGH | Extract core logic into clean functions; rebuild API layer; most expensive if deferred past Phase 2 |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Platform abstraction sprawl | Phase 1 (Foundation) | Single rendering strategy documented and enforced; no duplicate UI components |
| Polling proliferation | Phase 1 (Foundation) | SSE endpoint exists; zero `setInterval` polling loops in client code |
| WKWebView bridge fragility | Phase 1 (Foundation) | Chat renders through exactly one path (web or native, not both) |
| LLM streaming on mobile | Phase 2 (API Layer) | Chat works on throttled cellular connection; stream interruption shows recovery UI |
| Data migration failures | Phase 3 (Migration) | Migration script is idempotent; validation report shows record count match |
| Notification sprawl | Phase 3 (Notifications) | Notification budget enforced server-side; quiet hours configurable |
| Bot-shaped API | Phase 1-2 (Foundation/API) | Core logic callable without Telegram imports; API responses are typed JSON |

## Sources

- Erestor codebase analysis: `.planning/codebase/CONCERNS.md` (2026-03-09 audit)
- [Building Adaptable SwiftUI Applications for Multiple Platforms](https://fatbobman.medium.com/building-adaptable-swiftui-applications-for-multiple-platforms-964624fa7b2)
- [Sharing cross-platform code in SwiftUI apps - Jesse Squires](https://www.jessesquires.com/blog/2022/08/19/sharing-code-in-swiftui-apps/)
- [WebSocket vs Polling vs SSE - DEV Community](https://dev.to/abirk/websocket-vs-polling-vs-sse-17ii)
- [Why Is WKWebView So Heavy and Why Is Leaking It So Bad?](https://embrace.io/blog/wkwebview-memory-leaks/)
- [Claude API Rate Limits](https://platform.claude.com/docs/en/api/rate-limits)
- [Claude API Errors](https://platform.claude.com/docs/en/api/errors)
- [WebKit Is Now Native in SwiftUI - WWDC 2025](https://medium.com/@shubhamsanghavi100/webkit-is-now-native-in-swiftui-finally-a-first-class-webview-wwdc-2025-9f4a3a3e222f)
- [Scope Creep in Indie Games: How to Avoid Development Hell](https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell)

---
*Pitfalls research for: Erestor cross-platform personal intelligence assistant*
*Researched: 2026-03-09*
