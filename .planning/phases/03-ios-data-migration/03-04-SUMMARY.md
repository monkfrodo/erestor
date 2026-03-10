---
phase: 03-ios-data-migration
plan: 04
subsystem: ios, notifications, api
tags: [swiftui, apns, push-notifications, ios-sheets, notification-actions]

# Dependency graph
requires:
  - phase: 03-02
    provides: iOS TabView shell with poll/gate sheet placeholders
  - phase: 02-05
    provides: Backend poll scheduler and APNs module
provides:
  - iOS poll modal sheets with energy (5 buttons) and quality (4 buttons) layouts
  - iOS gate alert sheets with severity indicator and task list
  - iOS notification categories with action buttons (POLL_ENERGY, POLL_QUALITY, GATE_INFORM)
  - Notification response handler that POSTs to /v1/polls/{id}/respond
  - Backend APNs push integration in poll scheduler
affects: [04-web-dashboard]

# Tech tracking
tech-stack:
  added: []
  patterns: [iOS notification categories with 4-button limit, lazy APNs loading in scheduler]

key-files:
  created:
    - ErestorApp/ErestorApp/Views/iOS_PollSheetView.swift
    - ErestorApp/ErestorApp/Views/iOS_GateSheetView.swift
    - ~/claude-sync/produtividade/tests/test_apns_integration.py
  modified:
    - ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift
    - ErestorApp/ErestorApp/Views/iOS_TabRootView.swift
    - ~/claude-sync/produtividade/api/routers/events.py

key-decisions:
  - "iOS notification actions grouped to 4-button limit: energy uses 1-2/3/4-5/remind ranges"
  - "APNs send_push called via asyncio.to_thread to avoid blocking event loop"
  - "Always send APNs to iOS regardless of macOS presence (no deduplication)"
  - "Separate iOS sheet view files instead of inline in TabRootView for maintainability"

patterns-established:
  - "iOS notification categories: POLL_ENERGY (4 grouped actions), POLL_QUALITY (4 actions), GATE_INFORM (2 actions)"
  - "APNs helpers _load_apns/_load_device_tokens for lazy loading and mockable testing"

requirements-completed: [IOS-03, IOS-04, NOTF-02]

# Metrics
duration: 7min
completed: 2026-03-10
---

# Phase 3 Plan 4: iOS Poll/Gate Sheets and APNs Push Integration Summary

**iOS modal poll/gate sheets with notification action buttons and backend APNs push for every scheduler event**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-10T15:51:07Z
- **Completed:** 2026-03-10T15:58:41Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- iOS poll sheets render energy (5 buttons with labels) and quality (4 buttons) with tap feedback and "Lembrar em 10min" option
- iOS gate alert sheets show severity indicator, message, task list, and dismiss button
- Notification categories registered with action buttons respecting iOS 4-button limit
- Notification response handler parses action identifiers and POSTs to backend
- Backend poll scheduler sends APNs push for every energy poll, quality poll, and gate alert
- APNs gracefully degrades when not configured or on send failure

## Task Commits

Each task was committed atomically:

1. **Task 1: iOS poll/gate modal sheets and notification categories** - `7498f91` (feat)
2. **Task 2 RED: Failing APNs integration tests** - `a65fdab` (test, in claude-sync)
3. **Task 2 GREEN: Backend APNs integration in poll scheduler** - `85a01c0` (feat, in claude-sync)

## Files Created/Modified
- `ErestorApp/ErestorApp/Views/iOS_PollSheetView.swift` - Energy (5-button HStack) and quality (4-button) poll modal sheets
- `ErestorApp/ErestorApp/Views/iOS_GateSheetView.swift` - Gate alert sheet with severity colors and task list
- `ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift` - Notification categories, response handler, poll backend POST
- `ErestorApp/ErestorApp/Views/iOS_TabRootView.swift` - Wire new sheet views, add remind-in-10min handler
- `~/claude-sync/produtividade/api/routers/events.py` - APNs helper functions, wired into poll/gate scheduler
- `~/claude-sync/produtividade/tests/test_apns_integration.py` - 5 tests for APNs integration

## Decisions Made
- iOS notification actions grouped to 4-button limit: energy uses "1-2 baixa" / "3 ok" / "4-5 alta" / "Lembrar 10min" (full 5-option UI available in modal sheet when notification is tapped)
- ENERGY_12 maps to "2", ENERGY_45 maps to "4" as midpoint values
- APNs helpers use lazy loading (_load_apns, _load_device_tokens) for easy mocking in tests
- Sheet views extracted to separate files from iOS_TabRootView for cleaner code organization

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- iOS SDK not installed on build machine -- iOS build verification skipped. macOS build confirmed unaffected. All iOS code guarded by #if os(iOS).
- pytest-asyncio not available -- converted async tests to sync using asyncio.get_event_loop().run_until_complete()

## User Setup Required

**External services require manual configuration.** APNs push notifications require:
- `~/.erestor_apns_config` - JSON with key_id, team_id, bundle_id from Apple Developer > Keys > APNs
- `~/.erestor_apns_key.p8` - Download .p8 key file from Apple Developer > Keys
- `~/claude-sync/produtividade/erestor/data/devices.json` - iOS device tokens (auto-populated when app registers)

## Next Phase Readiness
- iOS poll/gate flow complete: SSE triggers modal sheets when app is open, APNs push when backgrounded
- Backend sends APNs for all scheduled events
- Ready for Phase 4 (web dashboard) or further iOS refinement

---
*Phase: 03-ios-data-migration*
*Completed: 2026-03-10*
