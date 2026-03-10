# External Integrations

**Analysis Date:** 2026-03-09

## APIs & External Services

**Erestor Backend API (primary integration):**
- Base URL: `https://erestor-api.kevineger.com.br`
- Auth: Bearer token via `ErestorConfig.authorize(&request)`
- Config: `ErestorApp/ErestorApp/Services/ErestorConfig.swift`
- Transport: HTTPS with URLSession
- All endpoints return JSON

**API Endpoints consumed by the app:**

| Endpoint | Method | Purpose | File |
|----------|--------|---------|------|
| `/api/status` | GET | Server health check (progressive polling 5s/10s/60s) | `Services/ChatService.swift` |
| `/api/chat/stream` | POST | SSE streaming chat (primary) | `Services/ChatService.swift` |
| `/api/chat` | POST | Non-streaming chat (legacy fallback) | `Services/ChatService.swift` |
| `/api/context` | GET | Calendar events, timer, tasks, energy level | `Services/ChatService.swift` |
| `/api/history` | GET | Load last 10 messages (`?source=desktop&limit=10`) | `Services/ChatService.swift` |
| `/api/push/pending` | GET | Poll for proactive push events (3s interval) | `Services/ChatService.swift` |
| `/api/push/respond` | POST | Send poll/notification responses | `ErestorApp.swift` |
| `/api/timer/start` | POST | Start work/rest timer | `Services/ActionHandler.swift` |
| `/api/timer/stop` | POST | Stop timer | `Services/ActionHandler.swift`, `Views/ChatWebViewVC.swift` |
| `/api/gcal/create` | POST | Create Google Calendar event | `Services/ActionHandler.swift` |
| `/api/gcal/update` | POST | Update Google Calendar event | `Services/ActionHandler.swift` |
| `/api/task/create` | POST | Create Notion task | `Services/ActionHandler.swift` |
| `/api/task/complete` | POST | Complete Notion task | `Services/ActionHandler.swift` |
| `/api/device/register` | POST | Register iOS APNs device token | `iOS/ErestorApp_iOS.swift` |

**SSE Streaming Protocol:**
- POST to `/api/chat/stream` with `{"message": "text"}`
- Response: Server-Sent Events with `data: {JSON}` lines
- Chunk types: `{text: "..."}` (token), `{done: true, full_response: "...", actions: [...]}` (end)
- Error: `{error: "message"}`
- Timeout: 300s (5 min)

**Google Fonts CDN:**
- Used in `ErestorApp/ErestorApp/Resources/chat.html`
- Loads IBM Plex Mono + Inter from `fonts.googleapis.com`
- Fallback to system fonts if CDN unavailable

## Data Storage

**Databases:**
- None in the app itself
- Backend manages all persistent data (calendar, tasks, timer state, history)

**Local State:**
- No local database or file-based persistence
- All state is in-memory (`@Published` properties on `ChatService`)
- History loaded from backend on app launch
- Context refreshed via polling (5s interval)

**Caching:**
- `cachedCtx` in `chat.html` JavaScript holds last context response
- No disk caching

## Authentication & Identity

**Auth Approach:**
- Static Bearer token hardcoded in `ErestorConfig.swift`
- Same token duplicated in `chat.html` JavaScript for direct fetch calls
- No user login, no OAuth, no session management
- Single-user system (Kevin only)

**iOS APNs:**
- Device token registered with backend via `/api/device/register`
- Entitlement: `aps-environment: development`

## Push Events System

**Push Polling (replaces SSE push):**
- Polls `/api/push/pending` every 3 seconds when server is online
- File: `Services/ChatService.swift` (`startPushPolling()`)

**Push Event Types:**
| Type | Purpose | UI Response |
|------|---------|-------------|
| `message` | Proactive message from backend | Chat bubble + macOS notification |
| `poll_energy` | Energy check-in (1-5 scale) | Poll card in chat + notification (POLL_ENERGY category) |
| `poll_quality` | Quality check-in (perdi/meh/ok/flow) | Poll card + notification (POLL_QUALITY category) |
| `gate_inform` | Gate alert (amber/red severity) | Gate alert card + notification (GATE_INFORM category) |
| `reminder` | Scheduled reminder | Notification (REMINDER category) |
| `action` | Remote action execution | Executes via ActionHandler |
| `context_update` | Context data refresh | Updates ContextSummary |

**Notification Categories & Actions:**
- `POLL_ENERGY`: 4 action buttons (1-morto, 2-baixa, 3-ok, 4-boa)
- `POLL_QUALITY`: 4 action buttons (perdi, meh, ok, flow)
- `GATE_INFORM`: 2 action buttons (Ver, Dispensar)
- `REMINDER`: 2 action buttons (Ver, Dispensar)
- Configured in `ErestorApp.swift` (`registerNotificationCategories()`)

## Local System Integrations (macOS only)

**AppleScript (via NSAppleScript):**
- iTerm: Open terminal window with `cd <path> && claude`
  - File: `Services/ActionHandler.swift` (`openTerminalAt()`)
- Music/Spotify: Play/pause, next track, previous track
  - Auto-detects running app (Spotify preferred over Music)
  - File: `Services/ActionHandler.swift` (`musicControl()`)

**NSWorkspace:**
- Open URLs in default browser (`openURL()`)
- Launch apps by name (`openApp()`)
- Open Finder at path (`openFinder()`)
- Desktop action opens iTerm + Arc (`openDesktop()`)

**System Tools:**
- `/bin/bash` - Execute shell commands (`runShell()`)
- `/usr/sbin/screencapture -i` - Interactive screenshot to Desktop (`captureScreenshot()`)
- `NSPasteboard` - Copy to clipboard (`copyToClipboard()`)

**13+ Action Types (via ActionHandler):**
- `reminder`, `open_project`, `open_url`, `open_app`, `open_finder`
- `clipboard`, `shell`, `timer_start`, `timer_stop`
- `gcal_create`, `gcal_update`, `create_task`, `complete_task`
- `web_search`, `music_toggle`, `music_next`, `music_prev`
- `screenshot`, `open_desktop`

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry, no crash reporting)

**Logs:**
- `os.Logger` unified logging (viewable via Console.app)
- `NSLog` for critical state changes
- Categories: ChatService, ActionHandler, BubbleWindow, GlobalHotkey, ChatWebViewVC

## CI/CD & Deployment

**Hosting:**
- Local macOS app (not App Store)
- Built and installed manually via xcodebuild

**CI Pipeline:**
- None

**LaunchAgents (managed externally):**
- `com.erestor.local-server` - Backend Python server (localhost:8766)
- `com.erestor.app` - App GUI (RunAtLoad)
- Installed via `~/claude-sync/produtividade/setup-agents.sh`

## Backend System (out-of-repo context)

The app is a client for a backend system that lives at `~/claude-sync/produtividade/`. Key backend components (NOT in this repo):

- `erestor_bot.py` - Telegram bot interface
- `erestor_local.py` - Local HTTP server (localhost:8766, SSE streaming)
- `briefing.py` - Daily briefing (GCal + Notion + ActivityWatch)
- `auto-sync.py` - Autonomous agents (morning/periodic/night sync)
- `log-builder.py` - Daily log generation

**Backend integrates with:**
- Google Calendar API (OAuth2, 9 calendars)
- Notion API (REST, tasks/inbox)
- ActivityWatch (localhost:5600)
- Telegram Bot API
- Claude CLI (`claude --print`)

## Environment Configuration

**Required for app to function:**
- Backend server running at `https://erestor-api.kevineger.com.br`
- Valid Bearer token in `ErestorConfig.swift`
- macOS 26.0+ with Accessibility for AppleScript (iTerm/Music control)

**No .env files:**
- All config is hardcoded in Swift source (`ErestorConfig.swift`)
- API token is also duplicated in `chat.html` JavaScript

## Webhooks & Callbacks

**Incoming:**
- None (app polls for push events, no inbound webhooks)

**Outgoing:**
- iOS APNs device token registration (`/api/device/register`)
- Poll responses sent to `/api/push/respond`

---

*Integration audit: 2026-03-09*
