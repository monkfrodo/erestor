# Phase 1: API Foundation - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

FastAPI gateway wrapping existing Python services with REST + SSE endpoints, replacing Telegram as the interface layer. Core logic extracted from bot handlers into clean reusable functions. Calendar read/write, chat streaming, and context endpoints all accessible via HTTP.

</domain>

<decisions>
## Implementation Decisions

### Code location and structure
- Backend lives inside `~/claude-sync/produtividade/` (existing repo)
- Refactor entire directory structure: separate into `core/`, `api/`, `bot/` (or similar clean separation)
- Core logic extracted from `erestor_bot.py` into importable modules that both API and bot can call
- Runs on same DigitalOcean server alongside existing services

### Telegram transition
- Kill Telegram bot immediately once API is operational — no parallel running
- All autonomous routines (briefing.py, auto-sync.py, log-builder.py) redirect output to API instead of Telegram
- During Phase 1 (before macOS app is ready), interaction happens via test interface (Claude decides: curl, mini web UI, or similar)

### API contract
- Redesign endpoints from scratch — do not carry over legacy `/api/chat/stream`, `/api/context`, `/api/push/pending` contracts
- Clean contract designed for the new multi-platform architecture
- Swift app will be updated in Phase 2 to use new endpoints

### Claude's Discretion
- SSE vs polling for real-time updates (research suggested SSE for single-user)
- API response format (envelope pattern vs direct responses)
- Authentication approach (improve from hardcoded bearer token — Keychain on Swift side, env var on server)
- Database choice (SQLite vs PostgreSQL vs files — for polls, timers, energy data, logs)
- Memory system storage (structured DB, markdown, or hybrid)
- Poll/energy data storage format (structured for querying patterns)
- Deploy method (PM2, Docker, or other)
- Exact directory structure for the refactored codebase

</decisions>

<specifics>
## Specific Ideas

- The existing `erestor_bot.py` has handlers that contain the core logic — these need to be extracted into standalone functions before wrapping with FastAPI
- `briefing.py`, `auto-sync.py`, and `log-builder.py` currently use `send_telegram.sh` or direct Telegram API calls — these are the integration points to redirect
- `ErestorConfig.swift` has the hardcoded API URL (`erestor-api.kevineger.com.br`) and bearer token — the new API should use the same domain/subdomain
- The existing API already serves some endpoints (chat/stream, context, push/pending) — the redesign replaces ALL of these

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ChatService.swift`: Already implements SSE streaming client — can be adapted for new API contract
- `ActionHandler.swift`: 19+ local action types (reminder, open_project, shell, timer, gcal, music) — these stay client-side
- `ErestorConfig.swift`: Centralized API config — needs updating with new endpoints but pattern is sound
- `DesignSystem.swift` (`DS` enum): Vesper Dark theme colors/fonts — reusable across all phases

### Established Patterns
- Server is source of truth, clients are thin — this pattern continues
- `@MainActor ObservableObject` (ChatService) as single state hub — continues
- SSE for chat streaming already implemented in Swift — pattern carries forward
- `os.Logger` with subsystem/category pattern — continues

### Integration Points
- Backend: `~/claude-sync/produtividade/` is the code to refactor
- Server: DigitalOcean, managed by PM2, Nginx reverse proxy to `erestor-api.kevineger.com.br`
- Credentials: `~/.erestor_telegram` (will become deprecated), `~/.gcal_credentials` (stays)
- LaunchAgents: `com.erestor.telegram-bot` needs updating/replacing

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-api-foundation*
*Context gathered: 2026-03-09*
