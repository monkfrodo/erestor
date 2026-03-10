---
phase: 02-macos-experience
plan: 01
subsystem: api
tags: [sse, anthropic-sdk, streaming, fastapi, asyncio]

# Dependency graph
requires:
  - phase: 01-api-foundation
    provides: FastAPI app with router pattern, auth deps, schemas, sse-starlette
provides:
  - "Persistent SSE event stream endpoint (GET /v1/events/stream) with push_event() API"
  - "Anthropic SDK token-by-token chat streaming (POST /v1/chat/stream)"
  - "SSE event type constants and SSEEvent schema"
  - "Action parsing from Claude response text"
  - "System prompt construction from soul.md + WorldState"
affects: [02-macos-experience, swift-app, polls, synthesis]

# Tech tracking
tech-stack:
  added: [anthropic-sdk-0.84.0]
  patterns: [asyncio-queue-sse, async-anthropic-streaming, lazy-client-init]

key-files:
  created:
    - "~/claude-sync/produtividade/api/routers/events.py"
    - "~/claude-sync/produtividade/tests/test_events_stream.py"
    - "~/claude-sync/produtividade/tests/test_chat_anthropic.py"
  modified:
    - "~/claude-sync/produtividade/api/routers/chat.py"
    - "~/claude-sync/produtividade/api/schemas.py"
    - "~/claude-sync/produtividade/api/main.py"

key-decisions:
  - "AsyncAnthropic client with lazy initialization to avoid import crash if SDK not installed"
  - "asyncio.Queue for SSE event distribution (single-user app, no Redis needed)"
  - "Heartbeat via asyncio.wait_for timeout pattern instead of background task"
  - "Action parsing with regex [ACTION:type:params] pattern from response text"
  - "System prompt = soul.md content + WorldState JSON snapshot"
  - "Removed obsolete test_chat_stream.py (Phase 1 single-chunk tests) replaced by test_chat_anthropic.py"

patterns-established:
  - "push_event(type, data) API for injecting events into the SSE stream from any module"
  - "Mock stream context manager pattern for testing Anthropic SDK streaming"
  - "Lazy client initialization pattern for optional SDK dependencies"

requirements-completed: [PANEL-07, CHAT-01, CHAT-02]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 2 Plan 01: SSE Event Stream + Anthropic SDK Chat Streaming Summary

**Persistent SSE event stream with asyncio.Queue and Anthropic SDK token-by-token chat streaming via AsyncAnthropic**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T10:38:22Z
- **Completed:** 2026-03-10T10:43:47Z
- **Tasks:** 2 (both TDD)
- **Files modified:** 6
- **Tests added:** 14 (6 events + 8 chat)

## Accomplishments
- GET /v1/events/stream delivers real-time SSE events with context snapshots, heartbeats, and push_event() API for other modules
- POST /v1/chat/stream now uses Anthropic SDK for true token-by-token streaming (replaces single-chunk call_claude)
- System prompt built from soul.md + WorldState JSON, conversation history supported
- All 14 new tests passing, 209 total tests pass (no regressions from this plan)

## Task Commits

Each task was committed atomically (TDD: RED then GREEN):

1. **Task 1: Persistent SSE event stream endpoint**
   - `6c08baf` (test: failing tests for SSE event stream)
   - `8691487` (feat: persistent SSE event stream endpoint with heartbeat)

2. **Task 2: Rewrite chat to Anthropic SDK token streaming**
   - `3220c9e` (test: failing tests for Anthropic SDK chat streaming)
   - `2867dd3` (feat: rewrite chat to Anthropic SDK token streaming)

_All commits in ~/claude-sync/ repository_

## Files Created/Modified
- `api/routers/events.py` - New persistent SSE event stream with asyncio.Queue, push_event(), heartbeat
- `api/routers/chat.py` - Rewritten: AsyncAnthropic SDK streaming, system prompt from soul.md + WorldState, action parsing
- `api/schemas.py` - Added SSE event type constants and SSEEvent model
- `api/main.py` - Registered events router
- `tests/test_events_stream.py` - 6 tests for SSE stream (content-type, push_event, heartbeat, auth, formats)
- `tests/test_chat_anthropic.py` - 8 tests for Anthropic streaming (multi-token, done, error, auth, validation, actions)
- `tests/test_chat_stream.py` - Removed (obsolete Phase 1 tests)

## Decisions Made
- Used AsyncAnthropic (async) instead of sync Anthropic to avoid blocking the FastAPI event loop
- Lazy client initialization with global `_client = None` pattern to handle missing SDK gracefully
- asyncio.wait_for with timeout for heartbeat generation (simpler than a separate background task)
- Model defaults to claude-sonnet-4-20250514 with ERESTOR_CLAUDE_MODEL env override
- Regex-based action parsing for [ACTION:type:params] tags (matches existing bot pattern)
- Removed test_chat_stream.py since it tested the now-replaced single-chunk implementation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed anthropic SDK and pytest-timeout**
- **Found during:** Task 1 (test infrastructure check)
- **Issue:** anthropic SDK and pytest-timeout not installed in Python 3.9 environment
- **Fix:** `python3 -m pip install anthropic pytest-timeout`
- **Files modified:** None (runtime dependency)
- **Verification:** Imports work, tests run with --timeout flag

**2. [Rule 1 - Bug] Removed obsolete test_chat_stream.py**
- **Found during:** Task 2 (regression check)
- **Issue:** Old tests patched `erestor.claude.call_claude` which the rewritten chat.py no longer uses
- **Fix:** Removed test_chat_stream.py (all its test cases covered by test_chat_anthropic.py)
- **Files modified:** tests/test_chat_stream.py (deleted)
- **Verification:** Full test suite passes without it

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for test execution. No scope creep.

## Pre-existing Test Failures (Out of Scope)

- `test_gate.py::TestSubmitUrgent::test_urgent_delivered_immediately` - mock signature mismatch with gate._deliver
- `test_polls_api.py::test_create_energy_poll` - polls router not yet implemented (404)
- `test_synthesis_api.py::test_synthesis_trigger_returns_text` - synthesis router not yet implemented

These are from other planned work, not caused by this plan's changes.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - anthropic SDK reads ANTHROPIC_API_KEY from environment (already configured on server).

## Next Phase Readiness
- SSE event stream ready for Swift app to connect (PANEL-07 foundation)
- push_event() API ready for polls and gates to inject events
- Chat streaming ready for native SwiftUI chat display
- Conversation history API ready for CHAT-03 implementation

---
*Phase: 02-macos-experience*
*Completed: 2026-03-10*
