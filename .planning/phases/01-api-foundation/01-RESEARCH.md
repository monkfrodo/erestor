# Phase 1: API Foundation - Research

**Researched:** 2026-03-09
**Domain:** Python HTTP API (FastAPI + SSE), refactoring existing bot architecture
**Confidence:** HIGH

## Summary

Phase 1 replaces the Telegram bot interface with a clean FastAPI HTTP + SSE API, decoupling Erestor's core intelligence from any specific client. The existing codebase in `~/claude-sync/produtividade/` is already partially modularized into an `erestor/` package (~40 modules) with a `world_state.py`, `calendar.py`, `claude.py`, `handlers.py`, `commands.py`, etc. There is also an existing HTTP API layer (`erestor_api.py`) using raw `http.server` that wraps bot handlers via thread-local send capture -- this is the layer to be replaced by FastAPI.

The key challenge is not greenfield API design but surgical extraction: the core logic (calendar operations, Claude calls, context building, timer management) is already well-separated in `erestor/` modules, but the entry points (`erestor_bot.py`, `erestor_api.py`, `erestor_local.py`) still route through Telegram-oriented `handle_text()` and use a monkey-patching capture pattern to intercept `send()` calls. The new API should call core functions directly, bypassing the Telegram handler layer entirely.

**Primary recommendation:** Use FastAPI 0.135+ with native SSE support (`fastapi.sse.EventSourceResponse`), keep the existing `erestor/` package structure and add an `api/` router layer on top. Core logic extraction is mostly done -- focus on creating clean FastAPI endpoints that call `erestor/` modules directly instead of routing through `handle_text()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Backend lives inside `~/claude-sync/produtividade/` (existing repo)
- Refactor entire directory structure: separate into `core/`, `api/`, `bot/` (or similar clean separation)
- Core logic extracted from `erestor_bot.py` into importable modules that both API and bot can call
- Runs on same DigitalOcean server alongside existing services
- Kill Telegram bot immediately once API is operational -- no parallel running
- All autonomous routines (briefing.py, auto-sync.py, log-builder.py) redirect output to API instead of Telegram
- Redesign endpoints from scratch -- do not carry over legacy contracts
- Clean contract designed for the new multi-platform architecture
- Swift app will be updated in Phase 2 to use new endpoints

### Claude's Discretion
- SSE vs polling for real-time updates (research suggested SSE for single-user)
- API response format (envelope pattern vs direct responses)
- Authentication approach (improve from hardcoded bearer token -- Keychain on Swift side, env var on server)
- Database choice (SQLite vs PostgreSQL vs files -- for polls, timers, energy data, logs)
- Memory system storage (structured DB, markdown, or hybrid)
- Poll/energy data storage format (structured for querying patterns)
- Deploy method (PM2, Docker, or other)
- Exact directory structure for the refactored codebase

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| API-01 | FastAPI gateway wrapping existing Python services with REST + SSE endpoints | FastAPI 0.135+ with native SSE; replace raw http.server with proper async framework |
| API-02 | Chat streaming endpoint using Claude API via SSE | Use `EventSourceResponse` with async generator wrapping `call_claude_streaming()` or direct Anthropic API |
| API-03 | Context endpoint returning current event, active timer, tasks, and next event in real-time | Wrap existing `build_world_state()` from `erestor/world_state.py` -- already returns frozen dataclass |
| API-04 | Calendar read endpoint returning day agenda from Google Calendar | Wrap existing `gcal_today_events()` from `erestor/calendar.py` |
| API-05 | Calendar write endpoint creating events via natural language parsed by Claude | Wrap existing `gcal_create_event()` plus Claude for NL parsing |
| API-06 | Core logic extracted from Telegram bot handlers into clean reusable functions | Most logic already in `erestor/` modules; extract remaining handler-embedded logic |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | 0.135+ | HTTP framework with native SSE | Native SSE support added in 0.135.0, async-first, auto-docs, Pydantic integration |
| uvicorn | 0.34+ | ASGI server | Standard production server for FastAPI, supports workers |
| pydantic | 2.x | Request/response validation | Ships with FastAPI, type-safe schemas |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| python-multipart | latest | Form data parsing | If file upload endpoints needed later |
| httpx | 0.28+ | Async HTTP client | For GCal/Notion API calls if migrating from urllib |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FastAPI native SSE | sse-starlette | sse-starlette was the standard before 0.135; FastAPI native is now preferred |
| httpx | urllib.request (current) | urllib works fine, is stdlib, already proven in codebase; httpx adds async but also a dependency |
| Anthropic SDK | claude CLI subprocess | SDK gives streaming control; CLI gives CLAUDE.md context for free. Decision depends on streaming needs |

**Installation:**
```bash
pip install "fastapi>=0.135" uvicorn pydantic
```

## Architecture Patterns

### Recommended Directory Structure (Claude's Discretion)
```
~/claude-sync/produtividade/
├── core/                    # Pure business logic (no I/O framework deps)
│   ├── __init__.py
│   ├── calendar.py          # GCal operations (from erestor/calendar.py)
│   ├── claude.py            # Claude API calls (from erestor/claude.py)
│   ├── context.py           # World state building (from erestor/world_state.py)
│   ├── memory.py            # Memory system (from erestor/memory.py)
│   ├── notion.py            # Notion operations (from erestor/notion.py)
│   ├── timers.py            # Timer management (from erestor/timers.py)
│   ├── config.py            # Shared config (from erestor/config.py)
│   ├── state.py             # Shared state (from erestor/state.py)
│   └── utils.py             # Shared utilities (from erestor/utils.py)
├── api/                     # FastAPI layer
│   ├── __init__.py
│   ├── main.py              # FastAPI app creation, middleware, startup/shutdown
│   ├── deps.py              # Dependencies (auth, etc.)
│   ├── routers/
│   │   ├── chat.py          # POST /chat/stream (SSE)
│   │   ├── context.py       # GET /context (real-time state)
│   │   ├── calendar.py      # GET /calendar/today, POST /calendar/create
│   │   └── status.py        # GET /status (health check)
│   └── schemas.py           # Pydantic models for request/response
├── bot/                     # Telegram bot (to be killed after API works)
│   ├── __init__.py
│   ├── erestor_bot.py       # Moved from root
│   └── ...                  # Other bot-specific modules
├── agents/                  # Autonomous routines
│   ├── briefing.py          # From root briefing.py
│   ├── auto_sync.py         # From root auto-sync.py
│   ├── log_builder.py       # From root log-builder.py
│   └── synthesis.py         # From erestor/synthesis.py
├── erestor/                 # EXISTING package (keep during migration)
│   ├── ... (40+ modules)
│   └── ...
├── memory/                  # Memory files (unchanged)
├── logs/                    # Log files (unchanged)
└── run_api.py               # Entry point: uvicorn launcher
```

**Note on migration strategy:** Rather than a big-bang refactor, the pragmatic approach is:
1. Create `api/` layer that imports from existing `erestor/` modules directly
2. Get endpoints working against existing module structure
3. Only then refactor `erestor/` into `core/` if the separation provides real value

This avoids breaking the working system while the API is being built.

### Pattern 1: FastAPI SSE for Chat Streaming
**What:** Native SSE endpoint using async generator
**When to use:** Chat streaming (API-02)
**Example:**
```python
# Source: https://fastapi.tiangolo.com/tutorial/server-sent-events/
from fastapi import FastAPI
from fastapi.sse import EventSourceResponse, ServerSentEvent
from collections.abc import AsyncIterable

@app.post("/v1/chat/stream", response_class=EventSourceResponse)
async def chat_stream(request: ChatRequest) -> AsyncIterable[ServerSentEvent]:
    async for chunk in stream_claude_response(request.message):
        yield ServerSentEvent(data=chunk, event="message")
    yield ServerSentEvent(data={"done": True}, event="done")
```

### Pattern 2: Pydantic Response Envelope
**What:** Consistent response format across all endpoints
**When to use:** All REST endpoints
**Example:**
```python
from pydantic import BaseModel
from typing import Optional, Any

class ApiResponse(BaseModel):
    ok: bool = True
    data: Optional[Any] = None
    error: Optional[str] = None

# Usage in endpoint
@app.get("/v1/context")
async def get_context() -> ApiResponse:
    ws = build_world_state()
    return ApiResponse(data=ws.to_dict())
```

### Pattern 3: Bearer Token Auth via Dependency
**What:** Simple bearer token auth for single-user API
**When to use:** All endpoints
**Example:**
```python
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
import secrets

security = HTTPBearer()
API_TOKEN = os.environ["ERESTOR_API_TOKEN"]

async def verify_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
):
    if not secrets.compare_digest(credentials.credentials, API_TOKEN):
        raise HTTPException(status_code=401, detail="Invalid token")
    return credentials

# Apply to all routes via router dependency
router = APIRouter(dependencies=[Depends(verify_token)])
```

### Anti-Patterns to Avoid
- **Routing through handle_text():** The existing `erestor_api.py` routes everything through the Telegram `handle_text()` and captures responses via monkey-patching. The new API must call core functions directly.
- **Monkey-patching send functions:** The current `_captured_send` / `_patch_modules_once` pattern is fragile and thread-unsafe at scale. Replace with proper function calls.
- **Subprocess Claude calls for streaming:** `direct_chat.py` calls `claude --print` via subprocess and streams the entire output as a single chunk. This is not true streaming. Consider using the Anthropic Python SDK for token-by-token streaming, OR keep subprocess but with line-by-line reading.
- **Mixing sync and async:** FastAPI runs on asyncio. The existing codebase is sync-heavy (urllib, subprocess). Use `run_in_executor` for blocking calls rather than mixing paradigms.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSE streaming | Custom `text/event-stream` with raw wfile.write | FastAPI's native `EventSourceResponse` | Handles keep-alive pings, proper headers, connection cleanup, proxy buffering |
| Request validation | Manual JSON parsing and field checking | Pydantic models | Type safety, auto-docs, error messages for free |
| API documentation | Manual swagger/OpenAPI | FastAPI auto-generated docs | `/docs` and `/redoc` out of the box |
| Auth middleware | Per-endpoint if/else checks | FastAPI dependency injection | Consistent, testable, applies to router groups |
| CORS handling | Manual header setting | FastAPI CORSMiddleware | Handles preflight, credentials, origin patterns |
| Process management | Custom daemon threading | PM2 or systemd with uvicorn | Restart on crash, log management, zero-downtime reload |

**Key insight:** The existing codebase hand-rolls HTTP serving (raw `http.server`), SSE (manual `wfile.write`), auth (manual header check), and CORS (manual headers). FastAPI provides all of these with better correctness and less code.

## Common Pitfalls

### Pitfall 1: Blocking the Event Loop
**What goes wrong:** Calling sync functions (urllib.request, subprocess, file I/O) directly in async FastAPI endpoints blocks the entire event loop.
**Why it happens:** The existing codebase is entirely synchronous. Dropping it into async endpoints without adaptation causes hangs.
**How to avoid:** Wrap all blocking calls with `asyncio.to_thread()` or `loop.run_in_executor()`. Alternatively, use `def` (sync) endpoints for blocking operations -- FastAPI automatically runs them in a thread pool.
**Warning signs:** Endpoint latency spikes, SSE streams freezing during long operations.

### Pitfall 2: State Shared Between Requests
**What goes wrong:** The existing bot uses module-level globals for state (timers, conversation history, caches). Multiple concurrent API requests can corrupt shared state.
**Why it happens:** The Telegram bot processes one message at a time. An HTTP API handles concurrent requests.
**How to avoid:** Use locks (already present for some state in `erestor/state.py`), or move to request-scoped state. For this single-user system, the risk is low but real for timer start/stop races.
**Warning signs:** Timer states becoming inconsistent, duplicate calendar events.

### Pitfall 3: Claude CLI Subprocess Overhead
**What goes wrong:** Each chat request spawns a `claude --print` subprocess (cold start ~2-5s), making chat feel sluggish.
**Why it happens:** The existing architecture uses Claude CLI for its CLAUDE.md context injection.
**How to avoid:** Two options: (1) Switch to Anthropic Python SDK for direct API calls with manual context injection, or (2) Keep CLI but accept the latency. For Phase 1, option 2 is pragmatic -- optimization can come later.
**Warning signs:** Chat responses consistently taking 5+ seconds before first token.

### Pitfall 4: Killing Telegram Too Early
**What goes wrong:** Killing the Telegram bot before all autonomous routines are redirected leaves Kevin without briefings, proactive alerts, etc.
**Why it happens:** CONTEXT.md says "kill immediately once API is operational" but "operational" needs careful definition.
**How to avoid:** Define "operational" as: all 6 API requirements verified AND autonomous routines redirected. During Phase 1 development, keep Telegram running as safety net. Kill only at the very end.
**Warning signs:** Morning briefings not arriving, proactive checks not running.

### Pitfall 5: Breaking GCal Token Refresh
**What goes wrong:** The GCal token refresh uses `~/.gcal_credentials` and caches to `~/.gcal_token_cache`. If the new API process runs as a different user or in a container, credentials are not found.
**Why it happens:** Credentials are stored relative to `$HOME`.
**How to avoid:** Ensure the API process runs as the same user that has credentials configured. If using PM2, this is automatic. If Docker, mount the credentials.
**Warning signs:** 401 errors on GCal API calls, empty agenda responses.

## Code Examples

### Existing Core Functions Already Extractable

```python
# From erestor/world_state.py -- already a clean dataclass
ws = build_world_state()
# Returns: WorldState(now, day_phase, timer_type, timer_desc,
#          current_event, next_event, p1_tasks, energy, ...)

# From erestor/calendar.py -- already clean functions
token = gcal_token()
events = gcal_today_events(token, cal_id)
success = gcal_create_event(title, start_iso, end_iso, cal_id)

# From erestor/memory.py -- already clean functions
history = load_history()
memory = load_memory()
snapshot = read_snapshot()
```

### FastAPI App Setup
```python
# api/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Erestor API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Single user, all origins OK
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
from api.routers import chat, context, calendar, status
app.include_router(status.router, prefix="/v1")
app.include_router(context.router, prefix="/v1")
app.include_router(chat.router, prefix="/v1")
app.include_router(calendar.router, prefix="/v1")
```

### Context Endpoint Wrapping WorldState
```python
# api/routers/context.py
from fastapi import APIRouter, Depends
from api.deps import verify_token
import asyncio

router = APIRouter(dependencies=[Depends(verify_token)])

@router.get("/context")
async def get_context():
    from erestor.world_state import build_world_state
    ws = await asyncio.to_thread(build_world_state)
    # WorldState is a frozen dataclass -- serialize it
    import dataclasses
    return {"ok": True, "data": dataclasses.asdict(ws)}
```

### Chat Streaming with Native FastAPI SSE
```python
# api/routers/chat.py
from fastapi import APIRouter, Depends
from fastapi.sse import EventSourceResponse, ServerSentEvent
from pydantic import BaseModel
from collections.abc import AsyncIterable
from api.deps import verify_token

router = APIRouter(dependencies=[Depends(verify_token)])

class ChatRequest(BaseModel):
    message: str

@router.post("/chat/stream", response_class=EventSourceResponse)
async def chat_stream(req: ChatRequest) -> AsyncIterable[ServerSentEvent]:
    # Option A: subprocess streaming (pragmatic, preserves CLAUDE.md context)
    import asyncio
    from erestor.direct_chat import call_claude_blocking

    response = await asyncio.to_thread(call_claude_blocking, req.message)
    yield ServerSentEvent(data={"text": response}, event="message")
    yield ServerSentEvent(data={"done": True}, event="done")
```

## Discretion Recommendations

### SSE vs Polling: Use SSE
SSE is the right choice for single-user real-time updates. Already proven in the existing Swift app (`ChatService.swift` implements SSE client). FastAPI 0.135+ has native SSE with keep-alive pings and proxy-safe headers built in.

### Response Format: Envelope Pattern
Use `{"ok": true, "data": {...}}` / `{"ok": false, "error": "..."}`. Simple, consistent, easy to parse in Swift. The existing API already uses a similar pattern with `{"success": true, ...}`.

### Authentication: Bearer Token from Environment
Keep the current pattern (env var `ERESTOR_API_TOKEN`) but improve: use `secrets.compare_digest()` for timing-safe comparison, return proper 401 with WWW-Authenticate header. For a single-user personal tool, this is sufficient. No need for OAuth2/JWT complexity.

### Database: Keep SQLite + Files (Hybrid)
The existing system uses SQLite (`erestor_events.db`) for event logs, signals, patterns, gate buffer, and markdown files for memory/logs. This works well for a single-user system. No reason to introduce PostgreSQL complexity. Keep SQLite for structured queryable data, markdown for human-readable memory.

### Deploy Method: PM2
PM2 is already managing the Telegram bot on DigitalOcean. Use `pm2 start "uvicorn api.main:app --host 0.0.0.0 --port 8767" --name erestor-api`. Docker adds overhead for a single-user deployment with no benefit.

### Directory Structure: Pragmatic Migration
Start by adding `api/` alongside existing `erestor/` package. The `erestor/` package IS the core -- it is already extracted from the monolithic bot. Only create `core/` if/when `erestor/` needs further decomposition. Moving 40+ files risks breaking everything for organizational purity.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| sse-starlette for SSE | FastAPI native SSE | FastAPI 0.135.0 (2025) | No external dependency needed |
| http.server raw | FastAPI/Starlette ASGI | Long-standing | Proper async, middleware, validation |
| claude CLI subprocess | Anthropic Python SDK | Available now | True token streaming, but loses CLAUDE.md auto-context |
| Python 3.8 support | Python 3.9+ minimum | FastAPI 0.112+ | Can use modern syntax |

**Deprecated/outdated:**
- `sse-starlette` library: Still works but FastAPI native SSE is now preferred for new projects
- Raw `http.server` for APIs: No validation, no async, no auto-docs
- `erestor_local.py` (localhost:8766): Will be replaced by the new FastAPI API

## Open Questions

1. **Claude CLI vs Anthropic SDK for chat streaming**
   - What we know: CLI gives CLAUDE.md context automatically; SDK gives true token streaming
   - What is unclear: Whether the CLAUDE.md context is critical for chat quality, or if it can be injected manually
   - Recommendation: Start with CLI subprocess (proven, low risk), migrate to SDK if streaming latency is unacceptable

2. **Autonomous routine output redirection**
   - What we know: `briefing.py`, `auto-sync.py`, `log-builder.py` currently send output via `send_telegram.sh` or Telegram API
   - What is unclear: What "redirect to API" means concretely -- SSE push? Store-and-poll? macOS native notifications?
   - Recommendation: For Phase 1, store output in a queue/DB; delivery to clients is Phase 2's concern

3. **Existing erestor_api.py and erestor_local.py removal**
   - What we know: Both provide HTTP APIs with different approaches (remote vs local)
   - What is unclear: Which features from `erestor_local.py` (desktop presence, push polling, API proxying) need to be preserved
   - Recommendation: Catalog all `erestor_local.py` endpoints and mark which are Phase 1 vs Phase 2

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (standard Python testing) |
| Config file | none -- Wave 0 |
| Quick run command | `pytest tests/ -x -q` |
| Full suite command | `pytest tests/ -v` |

### Phase Requirements - Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | FastAPI app starts, returns 200 on /v1/status | smoke | `pytest tests/test_api_status.py -x` | Wave 0 |
| API-02 | Chat endpoint streams SSE events with Claude response | integration | `pytest tests/test_chat_stream.py -x` | Wave 0 |
| API-03 | Context endpoint returns WorldState as JSON | unit | `pytest tests/test_context.py -x` | Wave 0 |
| API-04 | Calendar read returns day events | integration | `pytest tests/test_calendar_read.py -x` | Wave 0 |
| API-05 | Calendar write creates event from natural language | integration | `pytest tests/test_calendar_write.py -x` | Wave 0 |
| API-06 | Core functions callable without Telegram imports | unit | `pytest tests/test_core_extraction.py -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `pytest tests/ -x -q`
- **Per wave merge:** `pytest tests/ -v`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/` directory -- does not exist yet
- [ ] `tests/conftest.py` -- shared fixtures (mock GCal token, mock Claude response, test client)
- [ ] `pytest.ini` or `pyproject.toml` [tool.pytest] -- test configuration
- [ ] Framework install: `pip install pytest httpx` (httpx needed for FastAPI TestClient)

## Sources

### Primary (HIGH confidence)
- [FastAPI SSE docs](https://fastapi.tiangolo.com/tutorial/server-sent-events/) -- native SSE support in 0.135+, code examples, best practices
- [FastAPI official docs](https://fastapi.tiangolo.com/tutorial/bigger-applications/) -- project structure, routers, dependencies
- Existing codebase analysis: `erestor/` package (40+ modules), `erestor_api.py`, `erestor_local.py`, `erestor_bot.py`

### Secondary (MEDIUM confidence)
- [FastAPI releases](https://github.com/fastapi/fastapi/releases) -- version 0.135.1 confirmed current
- [zhanymkanov/fastapi-best-practices](https://github.com/zhanymkanov/fastapi-best-practices) -- project structure patterns
- [sse-starlette PyPI](https://pypi.org/project/sse-starlette/) -- SSE library (confirmed superseded by native support)

### Tertiary (LOW confidence)
- Python version on DO server not confirmed (local is 3.9.6; server likely 3.11+ in venv)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- FastAPI 0.135+ with native SSE is well-documented and proven
- Architecture: HIGH -- existing codebase is already modularized; extraction path is clear
- Pitfalls: HIGH -- identified from direct analysis of existing code patterns
- Discretion items: MEDIUM -- recommendations based on single-user context and existing patterns

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable domain, 30-day validity)
