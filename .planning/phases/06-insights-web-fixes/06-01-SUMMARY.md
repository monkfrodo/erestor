---
phase: 06-insights-web-fixes
plan: 01
subsystem: ios-views, web-components, web-sse
tags: [bugfix, data-transform, api-proxy, sse-events]
requirements_completed: [IOS-03, WEB-02, NOTF-03]
dependency_graph:
  requires: []
  provides: [insights-rendering, poll-respond-proxy, sse-poll-events]
  affects: [iOS_InsightsView, InsightsTab, sse, sw]
tech_stack:
  added: []
  patterns: [api-response-wrapper, data-transform-layer, api-proxy-route, sse-event-handler]
key_files:
  created:
    - web/src/app/api/poll-respond/route.ts
  modified:
    - ErestorApp/ErestorApp/Views/iOS_InsightsView.swift
    - web/src/components/tabs/InsightsTab.tsx
    - web/src/services/sse.ts
decisions:
  - "EnergyPoint.level kept as String with numericLevel computed property (no lossy conversion)"
  - "transformInsights() as standalone function, not hook (pure data transform)"
  - "poll_reminder uses browser Notification API (matches iOS native notification pattern)"
  - "Timer chart renamed to Horas por Dia since backend data is per-date not per-project"
metrics:
  duration: 4 min
  completed: "2026-03-10"
  tasks: 3
  files: 4
---

# Phase 6 Plan 01: Insights and Web Fixes Summary

Fix data shape mismatches between backend ApiResponse envelope and client expectations across iOS InsightsView, Web InsightsTab, service worker poll actions, and Web SSE event handling.

## One-liner

ApiResponse envelope unwrapping for iOS/Web insights, backend field name transforms, poll-respond proxy route, and poll_expired/poll_reminder SSE handlers.

## Tasks Completed

### Task 1: Fix iOS InsightsView ApiResponse unwrapping and energy level parsing
**Commit:** `f4d1489`
**Files:** `ErestorApp/ErestorApp/Views/iOS_InsightsView.swift`

- Added `InsightsApiResponse` wrapper struct to decode `{ok, data}` envelope
- Changed `EnergyPoint.level` from `Int` to `String` to match backend format ("4-boa", "3-ok")
- Added `numericLevel` computed property extracting leading digits for chart rendering
- Updated `fetchChartData()` to decode through wrapper, then extract `.data`
- Updated all chart marks and summary card to use `numericLevel` instead of `level`

### Task 2: Fix Web InsightsTab data transformation and poll-respond API route
**Commit:** `f756ae8`
**Files:** `web/src/components/tabs/InsightsTab.tsx`, `web/src/app/api/poll-respond/route.ts`

- Added `BackendInsights` interface matching backend snake_case field names
- Added `transformInsights()` to map `energy_trend` -> `energy`, `quality_distribution` -> `quality` array, `timer_hours` -> `timers`
- Energy level string parsing: `parseInt("4-boa")` -> `4`
- Renamed timer chart header from "Tempo por Projeto" to "Horas por Dia"
- Created Next.js API route at `/api/poll-respond` proxying POST to backend `/v1/polls/{id}/respond`
- Service worker `notificationclick` handler already calls this route -- now it exists

### Task 3: Add poll_expired and poll_reminder SSE handlers
**Commit:** `e7ae76b`
**Files:** `web/src/services/sse.ts`

- Added `poll_expired` event listener that calls `usePollStore.getState().removePoll()`
- Added `poll_reminder` event listener that shows browser `Notification` if poll is still active
- Web SSE now handles all 7 backend event types: context_update, poll_energy, poll_quality, gate_alert, poll_expired, poll_reminder, heartbeat

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

1. iOS: `xcodebuild build` with ErestorApp-iOS scheme targeting iPhone 17 Pro simulator -- BUILD SUCCEEDED
2. Web: `npx tsc --noEmit` passes with zero new errors (pre-existing push.test.ts type errors are out of scope)
3. `/api/poll-respond/route.ts` exists and exports POST
4. All 7 SSE event types have corresponding addEventListener calls in sse.ts
