---
phase: 01-api-foundation
plan: 02
subsystem: api
tags: [sse, sse-starlette, calendar, streaming, chat, gcal, asyncio]

# Dependency graph
requires:
  - phase: 01-api-foundation/01
    provides: FastAPI app, auth dependency, ApiResponse envelope, test fixtures
provides:
  - POST /v1/chat/stream SSE endpoint for Claude conversations
  - GET /v1/calendar/today for day agenda
  - POST /v1/calendar/create for NL event creation
  - CalendarEvent and CalendarCreateRequest schemas
affects: [02-macos-app, swift-sse-client]

# Tech tracking
tech-stack:
  added: [sse-starlette-3.3.0]
  patterns: [SSE async generator with sse-starlette, lazy module import for Python 3.9 compat, sys.modules mock for untestable imports]

key-files:
  created:
    - api/routers/chat.py
    - api/routers/calendar.py
    - tests/test_chat_stream.py
    - tests/test_calendar_read.py
    - tests/test_calendar_write.py
  modified:
    - api/main.py
    - api/schemas.py

key-decisions:
  - "sse-starlette instead of FastAPI native SSE (native requires 0.135+, we have 0.128.8)"
  - "Lazy imports inside endpoint functions to avoid Python 3.9 type annotation errors in erestor/calendar.py"
  - "Single-chunk SSE for chat (full call_claude response), true streaming deferred to Phase 2"
  - "sys.modules patching in calendar tests to work around Python 3.9 dict|None syntax in erestor/calendar.py"

patterns-established:
  - "SSE endpoint pattern: async generator yielding ServerSentEvent with event types (message/done/error)"
  - "Calendar NL parsing: Claude extracts title/start/end JSON from free text, then gcal_create_event"
  - "Error in SSE: yield error event before done event, don't raise HTTP errors mid-stream"

requirements-completed: [API-02, API-04, API-05]

# Metrics
duration: 4min
completed: 2026-03-10
---

# Phase 1 Plan 2: Chat + Calendar Endpoints Summary

**Chat SSE streaming via sse-starlette, calendar day view and NL event creation endpoints with full test coverage**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T01:40:00Z
- **Completed:** 2026-03-10T01:43:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- POST /v1/chat/stream returns Claude response via SSE events (message + done + error types)
- GET /v1/calendar/today returns day agenda from all configured GCal calendars
- POST /v1/calendar/create parses natural language via Claude and creates GCal events
- All endpoints enforce bearer token auth via router-level dependency
- 15 new tests (6 chat + 4 calendar read + 5 calendar write), full suite 24 passed + 1 skipped

## Task Commits

Each task was committed atomically:

1. **Task 1: Chat streaming SSE endpoint** - `6a053ea` (feat)
2. **Task 2: Calendar read and write endpoints** - `3a465b2` (feat)

## Files Created/Modified
- `api/routers/chat.py` - SSE streaming endpoint using sse-starlette + asyncio.to_thread(call_claude)
- `api/routers/calendar.py` - Calendar today (read) and create (write) endpoints
- `api/main.py` - Added chat and calendar router includes
- `api/schemas.py` - Added CalendarEvent, CalendarCreateRequest models
- `tests/test_chat_stream.py` - 6 tests: SSE format, text content, done event, auth, validation, error
- `tests/test_calendar_read.py` - 4 tests: events, structure, auth, empty day
- `tests/test_calendar_write.py` - 5 tests: create success, auth, validation, Claude parse failure, GCal failure

## Decisions Made
- Used sse-starlette 3.3.0 because FastAPI 0.128.8 lacks native SSE (requires 0.135+)
- Lazy imports (`from erestor.calendar import ...` inside endpoint functions) to avoid Python 3.9 type error in erestor/calendar.py at module load time
- Single-chunk SSE response (full call_claude result) rather than token-by-token streaming -- true streaming is Phase 2
- sys.modules patching in calendar tests to mock erestor.calendar without triggering the `dict | None` syntax error

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] sse-starlette instead of FastAPI native SSE**
- **Found during:** Task 1 (pre-implementation check)
- **Issue:** Plan specified `from fastapi.sse import EventSourceResponse` but FastAPI 0.128.8 has no `fastapi.sse` module (native SSE added in 0.135.0)
- **Fix:** Installed sse-starlette 3.3.0, used `from sse_starlette.sse import EventSourceResponse, ServerSentEvent`
- **Files modified:** api/routers/chat.py
- **Verification:** All SSE tests pass, correct content-type and event format
- **Committed in:** 6a053ea

**2. [Rule 3 - Blocking] sys.modules mocking for Python 3.9 calendar import**
- **Found during:** Task 2 (calendar test RED phase)
- **Issue:** `erestor/calendar.py` line 287 uses `dict | None` (PEP 604), crashes on Python 3.9 at import time. Cannot mock `erestor.calendar.gcal_today_events` via normal `patch()` because the module fails to load.
- **Fix:** Used `patch.dict(sys.modules, {"erestor.calendar": mock_mod})` to inject a mock module before the lazy import inside the endpoint
- **Files modified:** tests/test_calendar_read.py, tests/test_calendar_write.py
- **Verification:** All 9 calendar tests pass
- **Committed in:** 3a465b2

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both necessary for Python 3.9 + FastAPI 0.128.8 runtime compatibility. No scope creep.

## Issues Encountered
- Python 3.9 lacks PEP 604 union type syntax support (`dict | None`). This is a pre-existing issue in `erestor/calendar.py`, not caused by this plan. Worked around with lazy imports + sys.modules mocking.

## User Setup Required
None - no external service configuration required. All tests use mocked GCal and Claude calls.

## Next Phase Readiness
- All Phase 1 API requirements (API-01 through API-06) are now complete across Plans 01 and 02
- Full API surface: /v1/status, /v1/context, /v1/chat/stream, /v1/calendar/today, /v1/calendar/create
- Phase 2 (macOS app) can consume all endpoints
- Future optimization: migrate chat from single-chunk to token-by-token streaming when Anthropic SDK is adopted

## Self-Check: PASSED

All 7 created/modified files verified present. Both task commits (6a053ea, 3a465b2) verified in git log.

---
*Phase: 01-api-foundation*
*Completed: 2026-03-10*
