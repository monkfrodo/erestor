---
phase: 02-macos-experience
plan: 02
subsystem: api
tags: [fastapi, sqlite, polls, synthesis, insights, tdd]

# Dependency graph
requires:
  - phase: 01-api-foundation
    provides: FastAPI app, event_store, auth deps, schemas
provides:
  - poll_responses SQLite table with indexes
  - Poll CRUD API (create, respond, list, gate alerts)
  - Synthesis trigger endpoint (crosses polls + timers + events)
  - On-demand insights endpoint (natural language query)
  - Poll helper functions in event_store.py
affects: [02-macos-experience/04, 03-ios-experience]

# Tech tracking
tech-stack:
  added: []
  patterns: [lazy-import-for-erestor-modules, mockable-claude-functions, tdd-red-green]

key-files:
  created:
    - ~/claude-sync/produtividade/api/routers/polls.py
    - ~/claude-sync/produtividade/api/routers/synthesis.py
    - ~/claude-sync/produtividade/tests/test_polls_api.py
    - ~/claude-sync/produtividade/tests/test_synthesis_api.py
  modified:
    - ~/claude-sync/produtividade/erestor/event_store.py
    - ~/claude-sync/produtividade/api/schemas.py
    - ~/claude-sync/produtividade/api/main.py

key-decisions:
  - "Default options per poll type (energy: 5-level, block_quality: 4-level) set in router, not schema"
  - "Claude calls separated into mockable _call_claude_for_synthesis and _call_claude_for_query functions"
  - "Simple keyword matching for date range parsing (semana, mes, ontem) instead of NLP library"
  - "Gate alerts stored as poll_type='gate' in same table for unified querying"

patterns-established:
  - "TDD flow: RED failing tests -> GREEN implementation -> commit each phase"
  - "Mockable Claude helpers: separate function for each Claude call pattern"
  - "Poll data gathering helper _gather_synthesis_data for reuse across endpoints"

requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04, SYNT-01, SYNT-02]

# Metrics
duration: 6min
completed: 2026-03-10
---

# Phase 2 Plan 2: Poll Storage, CRUD API, and Synthesis Endpoints Summary

**Poll CRUD API with energy/block_quality/gate types in SQLite, plus synthesis trigger and natural-language insights endpoints crossing polls + timers + events**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-10T10:38:07Z
- **Completed:** 2026-03-10T10:44:29Z
- **Tasks:** 2 (TDD, 4 commits total)
- **Files modified:** 7

## Accomplishments
- poll_responses table in SQLite with date/type/status indexes
- Full poll lifecycle: create with defaults, respond, expire, query by date/type/status
- Gate alerts stored as poll_type="gate" for unified querying
- Synthesis endpoint crosses polls + timers + events for daily analysis
- On-demand insights accepts natural language ("como foi minha semana?") and returns data-driven answer
- 26 new tests (17 polls + 9 synthesis), all passing

## Task Commits

Each task was committed atomically (TDD RED + GREEN):

1. **Task 1: Poll storage + CRUD API** (TDD)
   - RED: `cd7e580` (test: add failing tests for poll CRUD API endpoints)
   - GREEN: `2f9fdf9` (feat: implement poll storage, CRUD API, and gate alerts)

2. **Task 2: Synthesis and on-demand insights** (TDD)
   - RED: `5dd13d5` (test: add failing tests for synthesis and insights endpoints)
   - GREEN: `ba68272` (feat: implement synthesis trigger and on-demand insights endpoints)

## Files Created/Modified
- `api/routers/polls.py` - Poll CRUD + gate alert endpoints (POST /polls, POST /polls/{id}/respond, GET /polls, POST /polls/gate)
- `api/routers/synthesis.py` - Synthesis trigger and on-demand insights (POST /synthesis/trigger, POST /synthesis/query)
- `erestor/event_store.py` - poll_responses table, create_poll, respond_to_poll, expire_poll, get_polls_by_date, get_poll_data
- `api/schemas.py` - PollCreateRequest, PollRespondRequest, GateAlertRequest, PollResponse, SynthesisTriggerRequest, SynthesisQueryRequest
- `api/main.py` - Registered polls and synthesis routers
- `tests/test_polls_api.py` - 17 tests for poll API
- `tests/test_synthesis_api.py` - 9 tests for synthesis API

## Decisions Made
- Default options per poll type set in router (energy: 5-level morto-to-pico, block_quality: 4-level perdi-to-flow), not in schema -- keeps schema flexible
- Claude calls separated into mockable functions (_call_claude_for_synthesis, _call_claude_for_query) for clean testing
- Simple keyword matching for date range parsing (semana, mes, ontem, hoje) -- avoids NLP dependency, sufficient for Kevin's Portuguese queries
- Gate alerts stored as poll_type="gate" in the same poll_responses table for unified querying

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Pre-existing test failures in test_chat_anthropic.py and test_gate.py (unrelated to this plan's changes, not fixed)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Poll and synthesis APIs ready for frontend consumption (Plan 04)
- Event store helpers available for any module that needs poll data
- Synthesis data gathering is reusable across different analysis contexts

## Self-Check: PASSED

All 4 created files verified on disk. All 4 commit hashes verified in git log.

---
*Phase: 02-macos-experience*
*Completed: 2026-03-10*
