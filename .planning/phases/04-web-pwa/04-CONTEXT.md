# Phase 4: Web PWA - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Progressive Web App as browser fallback with same core functionality as iOS app. Four tabs (Painel, Chat, Agenda, Insights), chat with SSE streaming, inline polls/gates as modals, web push notifications with action buttons, and daily synthesis. Kevin can access Erestor from any browser when not on an Apple device.

</domain>

<decisions>
## Implementation Decisions

### Tech stack
- Next.js 15 + TypeScript + Tailwind CSS (Kevin's standard stack)
- PWA with manifest.json — installable on home screen/desktop with custom icon and splash screen
- Always-online — no offline cache, no service worker for data caching (consistent with PROJECT.md: offline-first is out of scope)
- Service worker used only for web push notifications
- Deploy on DigitalOcean — same server as backend, PM2 + Nginx

### Code location
- Claude's Discretion: decide between `~/projetos/erestor/web/` (monorepo) or separate repo based on what works best with the existing structure and deploy setup

### Feature parity
- Full parity with iOS app: 4 tabs — Painel, Chat, Agenda, Insights
- Polls (energy + block quality) appear as modals (iOS pattern, not inline cards)
- Gate alerts: web push notification + modal when PWA is open
- Daily synthesis (22h) appears as chat message from Erestor — same as macOS/iOS
- On-demand insights via chat ("como foi minha semana?") — same SYNT-02 pattern
- Timer visible in panel with project/task label
- Day agenda with timeline view

### Visual design
- Port exact Vesper Dark theme — CSS variables mapping 1:1 with Swift DS enum
- Fonts: IBM Plex Mono + Inter (loaded via Google Fonts or self-hosted)
- Colors: DS.surface, DS.bright, DS.green, DS.amber, DS.border, etc. as CSS custom properties
- Mobile-first layout with desktop breakpoint — mobile uses tabs/cards, desktop gets sidebar with painel + chat side by side
- Chat with full markdown rendering + syntax highlighting (react-markdown + highlight.js or similar)

### Web push notifications
- Permission requested after first interaction (not on page load)
- Events that trigger push: energy polls, block quality polls, gate alerts, daily synthesis
- Notifications include action buttons: energy 1-5, quality perdi/meh/ok/flow, gate "Ver"
- No deduplication between platforms — always send web push regardless of macOS/iOS activity (consistent with Phase 3 APNs decision)

### Claude's Discretion
- Web Push API implementation details (VAPID keys, subscription management)
- Service worker architecture for push handling
- SSE reconnection strategy for web (adapt from Swift's exponential backoff pattern)
- Exact responsive breakpoints and sidebar layout for desktop
- Library choices for markdown rendering and syntax highlighting
- State management approach (React Context, Zustand, or similar)
- Agenda timeline component implementation

</decisions>

<specifics>
## Specific Ideas

- PWA should feel like a native app when installed — standalone mode, no browser chrome, dark splash screen
- Polls as modals: same quick UX as iOS — modal slides up, tap a number, slides away. Non-blocking
- The HTML prototype (`prototipo-painel.html`) in the repo root is a visual reference for the panel design
- Desktop breakpoint should show painel context on the left, chat on the right — efficient use of screen space
- Existing API contract from Phase 1 (REST + SSE) is the same — no backend changes needed for web client

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `prototipo-painel.html`: HTML prototype defining target UI/UX — use as visual reference for web implementation
- Backend API (`~/claude-sync/produtividade/api/`): All endpoints already built (context, chat/stream, polls, calendar, synthesis, insights)
- `DesignSystem.swift` (DS enum): Color/font definitions to port as CSS custom properties
- API contract (REST + SSE): Same endpoints iOS/macOS use — no backend work needed

### Established Patterns
- SSE streaming for chat: `POST /api/chat/stream` returns SSE events with token-by-token text
- SSE event stream: `GET /api/events/stream` for real-time context updates (polls, gates, context changes)
- Poll response: `POST /api/polls/{poll_id}/respond` with choice value
- Auth: Bearer token via `Authorization` header on all requests
- Context: `GET /api/context` returns current event, timer, tasks, next event
- Calendar: `GET /api/calendar/today` for day agenda

### Integration Points
- Backend already serves all needed endpoints — web is a new thin client
- Web push requires new backend endpoint for subscription registration + push sending (Web Push API / VAPID)
- Nginx needs new server block or location for the PWA static files / Next.js process
- PM2 config needs new process for Next.js dev/production server

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-web-pwa*
*Context gathered: 2026-03-10*
