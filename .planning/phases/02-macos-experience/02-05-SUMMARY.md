---
phase: 02-macos-experience
plan: 05
subsystem: notifications-scheduling
tags: [macos-notifications, unnotificationcenter, poll-scheduling, sse, gate-alerts, energy-polls, synthesis-cron]

# Dependency graph
requires:
  - phase: 02-macos-experience
    provides: SSE event stream, poll CRUD API, activePolls/activeGates on ChatService, PollSSEEvent/GateSSEEvent models, panel layout with poll/gate cards
provides:
  - "macOS notification categories with inline poll response actions (energy 1-5, quality perdi/meh/ok/flow)"
  - "Notification responses POST to /v1/polls/{poll_id}/respond from action buttons"
  - "10-min reminder notifications for unanswered polls"
  - "Poll expiry cleanup (notifications + activePolls)"
  - "Background poll scheduler: block quality polls on event end, energy polls at 2h+ intervals, gate alerts at block end with P1s"
  - "Automatic 22h daily synthesis via scheduler (SYNT-01)"
  - "POST /v1/polls/trigger endpoint for manual poll testing"
affects: [03-ios-experience, daily-synthesis, gate-alerts]

# Tech tracking
tech-stack:
  added: []
  patterns: [background-scheduler-alongside-sse, notification-action-to-api-post, 10min-reminder-trigger]

key-files:
  modified:
    - "~/projetos/erestor/ErestorApp/ErestorApp/ErestorApp.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Services/ChatService.swift"
    - "~/claude-sync/produtividade/api/routers/events.py"
    - "~/claude-sync/produtividade/api/routers/polls.py"

key-decisions:
  - "Notification categories use ENERGY_N and QUALITY_opt identifiers for reliable parsing"
  - "POLL_REMINDER category reuses energy actions (most common poll type)"
  - "Gate alerts always post notifications regardless of panel visibility (urgent)"
  - "Poll scheduler runs as asyncio.create_task alongside SSE generator, cancelled on disconnect"
  - "Energy polls only trigger when Kevin has ACTIVE presence and during work hours (8-21h)"
  - "Block quality polls use 2-min window after event end to avoid duplicates"
  - "22h synthesis stores result in daily_signals and pushes as context_update SSE event"

patterns-established:
  - "Notification action parsing: ENERGY_3 -> value '3', QUALITY_flow -> value 'flow'"
  - "Background scheduler lifecycle: starts on SSE connect, cancels on disconnect"
  - "Gate alert timing: amber at 5min, red at 2min before block end"

requirements-completed: [NOTF-01, DATA-01, DATA-02, DATA-03]

# Metrics
duration: 4min
completed: 2026-03-10
---

# Phase 2 Plan 05: macOS Notifications for Polls/Gates + Backend Poll Scheduling Summary

**Full notification flow from backend triggers through SSE to macOS notification actions that POST poll responses back to the API, with intelligent poll scheduling for energy/block quality/gates**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T11:08:43Z
- **Completed:** 2026-03-10T11:13:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- macOS notification categories with inline action buttons: 5 energy levels (1-5), 4 quality options (perdi/meh/ok/flow), gate Ver/Dispensar
- Notification responses POST directly to /v1/polls/{poll_id}/respond via action handler in AppDelegate
- 10-min reminder notifications scheduled automatically for unanswered polls
- Background poll scheduler runs every 60s: triggers block quality polls on event end, energy polls at 2h+ intervals, gate alerts when P1 tasks open near block end
- Poll expiry management: expired polls cleaned from notifications and activePolls
- Automatic 22h daily synthesis triggered by scheduler, pushed via SSE
- Manual POST /v1/polls/trigger endpoint for testing

## Task Commits

Each task was committed atomically:

1. **Task 1: macOS notification categories and handlers** - `6c2d48f` (feat)
2. **Task 2: Backend poll scheduling via SSE** - `126c942` (feat)

_Task 1 committed in ~/projetos/erestor/, Task 2 committed in ~/claude-sync/produtividade/_

## Files Created/Modified
- `ErestorApp/ErestorApp/ErestorApp.swift` - Expanded notification categories (ENERGY_1-5, QUALITY_perdi/meh/ok/flow, POLL_REMINDER), poll response handler POSTing to backend, parsePollResponseValue helper
- `ErestorApp/ErestorApp/Services/ChatService.swift` - postPollNotification, postGateNotification, scheduleReminderNotification helpers; SSE handlers post native notifications when panel hidden; poll_expired cleans notifications
- `api/routers/events.py` - Added _poll_scheduler background task with block quality, energy, gate alert, expiry, reminder, and synthesis checks; scheduler lifecycle tied to SSE connection
- `api/routers/polls.py` - Added POST /v1/polls/trigger endpoint for manual poll testing

## Decisions Made
- ENERGY_N and QUALITY_opt identifiers chosen for reliable parsing from notification action identifiers
- POLL_REMINDER category reuses energy actions since energy is the most common poll type
- Gate alerts always fire notifications regardless of panel visibility (urgency)
- Poll scheduler uses asyncio.create_task started alongside SSE generator, cancelled in finally block on disconnect
- Energy polls require ACTIVE presence + work hours (8-21h) to avoid unnecessary notifications
- Block quality polls use a 2-minute detection window after event end with duplicate guard (no poll within 5min)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Pre-existing test failure in test_gate.py (mock signature mismatch for world_state kwarg) -- unrelated to this plan, all 235 other tests pass

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Notifications and scheduling are wired end-to-end
- Only Plan 02-06 (verification checkpoint) remains in Phase 2
- Ready for full macOS experience verification

## Self-Check: PASSED

All 4 modified files verified on disk. Both commit hashes verified in git log.

---
*Phase: 02-macos-experience*
*Completed: 2026-03-10*
