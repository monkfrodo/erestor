# Architecture Research

**Domain:** Cross-platform personal intelligence assistant (macOS, iOS, web)
**Researched:** 2026-03-09
**Confidence:** HIGH

## System Overview

```
                         Clients
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │  macOS App   │  │   iOS App    │  │   Web App    │
  │  (SwiftUI +  │  │  (SwiftUI)   │  │  (HTML/JS)   │
  │   AppKit)    │  │              │  │              │
  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
         │                 │                  │
         └────────────┬────┴──────────────────┘
                      │  HTTPS (REST + SSE)
                      ▼
         ┌────────────────────────────┐
         │       API Gateway          │
         │   (FastAPI on DO server)   │
         ├────────────────────────────┤
         │  /api/chat/stream   (SSE)  │
         │  /api/context       (GET)  │
         │  /api/push/pending  (GET)  │
         │  /api/poll/respond  (POST) │
         │  /api/timer/*       (CRUD) │
         │  /api/events/*      (CRUD) │
         │  /api/notify        (POST) │
         └────────────┬───────────────┘
                      │
         ┌────────────┴───────────────┐
         │      Core Services         │
         ├────────────────────────────┤
         │  ┌──────────┐ ┌─────────┐ │
         │  │ Chat /   │ │ Context │ │
         │  │ LLM      │ │ Engine  │ │
         │  └──────────┘ └─────────┘ │
         │  ┌──────────┐ ┌─────────┐ │
         │  │ Auto-    │ │ Poll /  │ │
         │  │ Sync     │ │ Gate    │ │
         │  └──────────┘ └─────────┘ │
         │  ┌──────────┐ ┌─────────┐ │
         │  │ Memory   │ │ Push /  │ │
         │  │ System   │ │ Notify  │ │
         │  └──────────┘ └─────────┘ │
         └────────────┬───────────────┘
                      │
    ┌─────────────────┼──────────────────┐
    ▼                 ▼                  ▼
┌────────┐    ┌────────────┐    ┌──────────────┐
│ SQLite │    │ Claude API │    │ Google Cal   │
│ / JSON │    │            │    │ + Notion     │
│ Files  │    │            │    │ + AW         │
└────────┘    └────────────┘    └──────────────┘
```

## Component Responsibilities

| Component | Responsibility | Talks To |
|-----------|----------------|----------|
| **macOS App** | Floating bubble, context panel, chat, native notifications, system actions (AppleScript, hotkeys) | API Gateway via REST + SSE |
| **iOS App** | Context panel, chat, push notifications, mobile agenda view | API Gateway via REST + SSE |
| **Web App** | Fallback interface, same panel/chat UX in browser | API Gateway via REST + SSE |
| **API Gateway** | HTTP routing, auth (bearer token), SSE stream management, request validation | Core Services |
| **Chat / LLM Service** | Natural language processing, Claude API calls, action extraction, streaming responses | Claude API, Memory System |
| **Context Engine** | Aggregates current state (calendar event, timer, next event, tasks, active poll) into a single snapshot | Google Calendar, Timer data, Task data |
| **Auto-Sync Agents** | Autonomous routines (morning briefing, periodic checks, nightly synthesis) on cron schedules | All other services, Claude API |
| **Poll / Gate Service** | Creates energy/quality polls at intelligent moments, gate alerts before block transitions | Context Engine, Push/Notify |
| **Memory System** | Persistent context about people, projects, sessions, patterns | SQLite / JSON files |
| **Push / Notify Service** | Queues server-initiated events, delivers via polling endpoint + APNs/macOS notifications | All services that generate events |

## Recommended Architecture: Unified API + Thin Clients

### Why This Pattern

The existing system already follows this pattern correctly: intelligence lives server-side, clients are thin UI shells. This is the right call for a single-user personal assistant because:

1. **One source of truth** -- all data and logic on one server, no sync conflicts
2. **Backend already exists** -- proven Python services for briefing, synthesis, memory, auto-sync
3. **LLM costs are server-side anyway** -- Claude API calls must happen server-side
4. **Simpler clients** -- native apps only handle rendering and local system actions

### What Changes from Current Architecture

The current system uses the Telegram API as the interface layer. The new architecture replaces Telegram with a proper REST + SSE API that the native apps consume directly.

| Current | New |
|---------|-----|
| Telegram bot receives messages | FastAPI REST endpoint receives messages |
| Telegram sends responses | SSE stream delivers responses |
| Telegram notifications | APNs (iOS) + UNUserNotification (macOS) + Push polling |
| No context panel | `/api/context` endpoint polled by clients |
| No inline polls | `/api/push/pending` delivers poll/gate events |

## Architectural Patterns

### Pattern 1: SSE for Chat Streaming, REST for Everything Else

**What:** Chat responses stream via Server-Sent Events. All other interactions (polls, timers, events, context) use standard REST endpoints.

**Why:** SSE is simpler than WebSockets for unidirectional server-to-client streaming (which is exactly what LLM token streaming is). REST is simpler for CRUD operations. No need for WebSocket complexity when the client only sends via POST and receives streams via SSE.

**Trade-offs:** SSE has a browser connection limit (~6 per domain in HTTP/1.1). Not an issue for a single-user system. If bidirectional real-time becomes needed later, WebSocket can be added for that specific use case.

**Current system already does this** -- `ChatService.sendMessageStreaming()` POSTs to `/api/chat/stream` and reads SSE response. Keep this pattern.

### Pattern 2: Context Polling with Smart Intervals

**What:** Clients poll `/api/context` at regular intervals (5s active, 30s background) to get current state. The server aggregates all context into a single JSON snapshot.

**Why:** Simpler than maintaining persistent connections for context updates. A single-user system generates minimal load from polling. The context snapshot is cheap to compute.

**Trade-offs:** 5-second latency on context updates. Acceptable for calendar events and timers. Could upgrade to SSE push for context if latency becomes annoying, but polling is simpler to implement and debug.

**Optimization:** Server can return `304 Not Modified` with ETag when context hasn't changed, reducing bandwidth.

### Pattern 3: Push Event Queue (Server-Initiated Actions)

**What:** Server queues events (polls, gate alerts, reminders) in a pending queue. Clients poll `/api/push/pending` every 3s. Events are consumed (marked delivered) on read.

**Why:** Decouples event generation from delivery. Auto-sync agents, cron jobs, and calendar watchers can all enqueue events without knowing which client is active. The active client picks them up.

**Current system already does this** -- `ChatService.startPushPolling()` polls `/api/push/pending`. Keep this pattern but add APNs delivery as a parallel channel for when no client is actively polling.

### Pattern 4: Multiplatform SwiftUI with Platform Adapters

**What:** Share models, services, and view models across macOS and iOS. Use platform-specific view files only for UI that fundamentally differs (floating bubble is macOS-only, full-screen layout is iOS-only).

**Why:** Apple's multiplatform SwiftUI target enables ~80% code sharing between macOS and iOS. The shared code includes `ChatService`, all models, `ContextPanelView`, `ChatInputView`, and the design system. Platform-specific code is limited to window management (AppKit bubble on macOS) and notification registration (APNs on iOS).

**Structure:**
```
ErestorApp/
├── Shared/              # 80% of code lives here
│   ├── Services/        # ChatService, ActionHandler, ErestorConfig
│   ├── Models/          # ChatMessage, ContextSummary, PushEvent, etc.
│   ├── Views/           # ContextPanelView, ChatView, PollCard, etc.
│   └── DesignSystem.swift
├── macOS/               # macOS-only code
│   ├── ErestorApp.swift         # AppDelegate, MenuBarExtra
│   ├── BubbleWindowController.swift  # Floating bubble (AppKit)
│   ├── GlobalHotkey.swift       # Carbon hotkey
│   └── MacActions.swift         # AppleScript actions
└── iOS/
    ├── ErestorApp_iOS.swift     # APNs, UIApplicationDelegate
    └── MobileLayout.swift       # Full-screen container
```

### Pattern 5: Web Client as Progressive Enhancement

**What:** A standalone HTML/JS web app (no framework) that consumes the same API. Not a priority -- built last as a fallback for when native apps aren't available.

**Why:** The API is already HTTP-based. A lightweight web client is trivial to build on top of it. No need for React/Next.js -- a single HTML file with vanilla JS (like the existing `chat.html` in WKWebView) is sufficient for a single-user tool.

**Trade-offs:** No native notifications on web (Web Push API exists but is flaky). No system actions. Reduced functionality is acceptable for a fallback interface.

## Data Flow

### Chat Message Flow

```
User types message
    ↓
Client POSTs to /api/chat/stream {text, context}
    ↓
API Gateway validates, forwards to Chat/LLM Service
    ↓
Chat/LLM Service:
  1. Loads memory context (recent messages, session, people/projects)
  2. Builds Claude API prompt with system context + user message
  3. Calls Claude API with streaming enabled
    ↓
Claude API streams tokens back
    ↓
API Gateway converts to SSE: data: {"type":"delta","text":"..."}
    ↓
Client receives chunks, renders incrementally
    ↓
On stream end: data: {"type":"done","actions":[...]}
    ↓
Client executes local actions (open URL, set timer, etc.)
```

### Context Update Flow

```
Every 5 seconds:
    Client GETs /api/context
        ↓
    Context Engine aggregates:
      - Current calendar event (from GCal cache)
      - Active timer (from timer store)
      - Next event (from GCal cache)
      - Pending tasks (from task store)
      - Active poll (from poll queue)
        ↓
    Returns ContextSummary JSON
        ↓
    Client updates SwiftUI @Published properties
        ↓
    Views reactively re-render
```

### Proactive Event Flow (Server-Initiated)

```
Auto-sync agent or cron job detects:
  "Calendar block ends in 15 min, task X still open"
    ↓
Creates PushEvent {type: "gate_inform", ...}
    ↓
Enqueues in push_pending store
    ↓
Parallel delivery:
  A) Client polls /api/push/pending → receives event → shows inline card
  B) APNs push → iOS notification with action buttons
  C) macOS UNUserNotification → notification banner with actions
    ↓
User responds (taps button or answers inline)
    ↓
Client POSTs /api/poll/respond {event_id, response}
    ↓
Backend logs response, updates context, feeds into synthesis
```

### Daily Synthesis Flow

```
Night auto-sync agent (cron, ~23:00):
    ↓
Collects day's data:
  - All poll responses (energy 1-5, block quality)
  - Timer sessions (project, duration)
  - Calendar events (planned vs actual)
  - Chat interactions (topics, actions taken)
  - Task completions
    ↓
Builds synthesis prompt for Claude
    ↓
Claude generates daily analysis
    ↓
Stored as daily log (logs/YYYY-MM-DD.md)
    ↓
Patterns fed into memory system for future briefings
```

## State Management

**Server is the source of truth.** Clients are stateless renderers with local caches.

| State | Where It Lives | How Clients Access |
|-------|----------------|-------------------|
| Chat history | Server (memory system) | Loaded on app launch, appended per message |
| Current context | Server (context engine) | Polled every 5s |
| Pending events | Server (push queue) | Polled every 3s |
| User preferences | Server (config store) | Loaded on app launch |
| Timer state | Server (timer store) | Part of context response |
| Historical data | Server (SQLite/JSON) | Not accessed directly by clients |

**Client-side state** is limited to:
- UI state (panel open/closed, scroll position)
- Streaming buffer (current SSE chunks)
- Notification permissions status
- Offline detection (consecutive failures counter)

## Build Order (Dependencies)

This is the critical section for roadmap planning. Components must be built in dependency order.

### Phase 1: API Layer (Foundation)

**Build first** because everything depends on it.

| Component | Why First |
|-----------|-----------|
| FastAPI app scaffold | All clients need endpoints to hit |
| `/api/chat/stream` | Core interaction loop |
| `/api/context` | Panel needs data to display |
| Auth middleware | Security before exposing endpoints |

**Depends on:** Existing Python services (briefing, memory, etc.) -- wrap them, don't rewrite.

### Phase 2: macOS Client (Primary Platform)

**Build second** because Kevin uses macOS as primary device.

| Component | Why This Order |
|-----------|----------------|
| Shared models + ChatService | Foundation for all UI |
| Context panel (SwiftUI) | Core value prop -- always-visible context |
| Chat interface (SwiftUI, replacing WKWebView) | Primary interaction surface |
| Floating bubble (AppKit) | macOS-specific chrome |
| Native notifications | Proactive alerts |

**Depends on:** API Layer (Phase 1).

### Phase 3: Data Collection Pipeline

**Build third** because polls, timers, and gate alerts need the API and a client to display in.

| Component | Why This Order |
|-----------|----------------|
| Poll system (energy, block quality) | Core data collection |
| Gate alert system | Proactive intelligence |
| Timer enhancements | Visible in context panel |
| Evolved synthesis | Crosses all new data points |

**Depends on:** API Layer (Phase 1) + macOS Client (Phase 2).

### Phase 4: iOS Client

**Build fourth** because it shares ~80% code with macOS client.

| Component | Why This Order |
|-----------|----------------|
| iOS target in Xcode project | Platform setup |
| Mobile layout adaptations | Screen size differences |
| APNs integration | Push notifications |
| Mobile-specific views (day agenda) | iOS value adds |

**Depends on:** Shared code from Phase 2.

### Phase 5: Web Client + Polish

**Build last** as a fallback interface.

| Component | Why This Order |
|-----------|----------------|
| Standalone HTML/JS client | Uses same API |
| Data migration (Telegram history) | Can happen anytime but not blocking |
| Historical patterns dashboard | Nice-to-have visualization |

**Depends on:** Stable API (Phase 1).

## Anti-Patterns

### Anti-Pattern 1: WebSocket for Everything

**What people do:** Use WebSocket for all real-time communication including chat, context, and notifications.
**Why it's wrong:** WebSocket adds complexity (connection management, reconnection logic, state synchronization) without benefit for a single-user system. SSE + REST is simpler, more debuggable, and sufficient.
**Do this instead:** SSE for streaming responses, REST for everything else, polling for context/push.

### Anti-Pattern 2: Thick Client with Local Database

**What people do:** Store data locally on each device and sync to server.
**Why it's wrong:** Creates sync conflicts, duplicates logic, and adds massive complexity for a single-user system that always has network access.
**Do this instead:** Server is source of truth. Clients cache nothing except UI state. If offline, show "offline" -- don't try to work offline (explicitly out of scope per PROJECT.md).

### Anti-Pattern 3: Rewriting Backend Services

**What people do:** Rewrite the entire backend when changing the interface layer.
**Why it's wrong:** The existing Python services (briefing, synthesis, memory, auto-sync) are proven and working. Rewriting them risks regressions and delays.
**Do this instead:** Wrap existing services with a FastAPI API layer. Import and call existing Python functions. Refactor incrementally over time.

### Anti-Pattern 4: Framework-Heavy Web Client

**What people do:** Use React/Next.js for the web client of a single-user tool.
**Why it's wrong:** Massive dependency overhead for what is essentially a chat panel + context display. The existing `chat.html` WKWebView approach proves vanilla JS is sufficient.
**Do this instead:** Single HTML file with vanilla JS consuming the REST + SSE API. No build step, no dependencies, trivial to maintain.

### Anti-Pattern 5: Replacing WKWebView Chat with SwiftUI Too Early

**What people do:** Rebuild the entire chat UI in SwiftUI before the API layer is stable.
**Why it's wrong:** The chat rendering (markdown, streaming, code blocks) is complex. WKWebView with HTML/JS handles this well. Premature migration creates UI regressions.
**Do this instead:** Keep WKWebView for chat rendering initially. Migrate to SwiftUI views for chat only after the API layer and context panel are stable and working.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Claude API | Server-side only, streaming via httpx/aiohttp | Never expose API key to clients |
| Google Calendar | OAuth2 refresh token, server-side polling + cache | Existing integration, keep as-is |
| APNs (Apple Push) | Server sends via `apns2` or HTTP/2 to Apple servers | Requires Apple Developer cert, device token registration |
| Notion API | Server-side, used by briefing/log-builder | Existing integration, keep as-is |
| ActivityWatch | Server-side, local API on Kevin's machine | Only works when macOS is active |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Client <-> API Gateway | HTTPS REST + SSE | Bearer token auth, JSON payloads |
| API Gateway <-> Core Services | Python function calls | Same process, no network overhead |
| Core Services <-> Claude API | HTTPS streaming | Server-side only, async |
| Core Services <-> Data Store | File I/O / SQLite | Same server, local disk |
| Auto-Sync <-> Core Services | Python imports + cron | Runs as separate process on same server |
| Push/Notify <-> APNs | HTTPS/2 | Async, fire-and-forget with retry |

## Sources

- [Apple: Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [Clean Architecture for SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
- [Modern MVVM in SwiftUI 2025](https://medium.com/@minalkewat/modern-mvvm-in-swiftui-2025-the-clean-architecture-youve-been-waiting-for-72a7d576648e)
- [FastAPI SSE for real-time notifications](https://medium.com/@inandelibas/real-time-notifications-in-python-using-sse-with-fastapi-1c8c54746eb7)
- [WebSocket/SSE with FastAPI at scale](https://blog.greeden.me/en/2025/10/28/weaponizing-real-time-websocket-sse-notifications-with-fastapi-connection-management-rooms-reconnection-scale-out-and-observability/)
- [SwiftUI multiplatform architecture patterns](https://dev.to/sebastienlato/swiftui-multi-platform-architecture-ios-ipados-macos-visionos-1961)
- [Building a unified multiplatform architecture with SwiftUI](https://medium.com/@mrhotfix/building-a-unified-multiplatform-architecture-with-swiftui-ios-macos-and-visionos-6214b307466a)
- [Cross-platform SwiftUI patterns](https://www.bekk.christmas/post/2023/20/cross-platform-swiftui)
- [Structuring platform-specific code in SwiftUI](https://augmentedcode.io/2021/09/27/structuring-platform-specific-code-in-swiftui/)

---
*Architecture research for: Erestor cross-platform personal intelligence assistant*
*Researched: 2026-03-09*
