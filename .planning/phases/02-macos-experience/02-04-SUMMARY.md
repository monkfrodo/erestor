---
phase: 02-macos-experience
plan: 04
subsystem: swift-app
tags: [swiftui, panel-layout, collapsible-tasks, poll-cards, gate-alerts, wkwebview-removal, nshostingview]

# Dependency graph
requires:
  - phase: 02-macos-experience
    provides: SSE event stream client, activePolls/activeGates on ChatService, PollSSEEvent/GateSSEEvent models
provides:
  - "Panel layout restructured: Context > Tasks (collapsible) > Alerts > Chat"
  - "CollapsibleTasksView with count badge and expand/collapse toggle"
  - "PollCardView with SSE data, expiry countdown, and backend POST on tap"
  - "GateAlertView with severity colors, task list, and dismiss button"
  - "BubbleWindowController using NSHostingView (no WKWebView)"
  - "ChatWebViewVC.swift and chat.html deleted"
affects: [03-ios-experience, notifications, synthesis-display]

# Tech tracking
tech-stack:
  added: []
  patterns: [nshostingview-panel-embedding, sse-driven-poll-alerts, expiry-countdown-timer]

key-files:
  created:
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/CollapsibleTasksView.swift"
  modified:
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/ContextPanelView.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/PollCardView.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/GateAlertView.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Services/BubbleWindowController.swift"
    - "~/projetos/erestor/ErestorApp/project.yml"
  deleted:
    - "~/projetos/erestor/ErestorApp/ErestorApp/Views/ChatWebViewVC.swift"
    - "~/projetos/erestor/ErestorApp/ErestorApp/Resources/chat.html"

key-decisions:
  - "PollCardView keeps backward-compatible signature (type+question+onResponse) with optional SSE fields (pollId, options, expiresAt)"
  - "GateAlertView uses optional tasks and onDismiss parameters for SSE-driven gates alongside legacy action-based gates"
  - "BubbleWindowController embeds ContextPanelView directly via NSHostingView, removing all WKWebView/JS bridge code"
  - "Context polling removed from BubbleWindowController (SSE handles updates via ChatService)"

patterns-established:
  - "NSHostingView embedding: SwiftUI views hosted in NSPanel via NSHostingView for floating window support"
  - "SSE-driven alerts: polls and gates arrive via SSE, displayed via ForEach on published arrays, dismissed by array removal"
  - "Expiry countdown: Timer.scheduledTimer with auto-dismiss when expired"

requirements-completed: [PANEL-01, PANEL-02, PANEL-03, PANEL-04, PANEL-05, PANEL-06]

# Metrics
duration: 5min
completed: 2026-03-10
---

# Phase 2 Plan 04: Panel Layout Restructure, Collapsible Tasks, Poll/Gate Backend Integration, WKWebView Removal Summary

**Restructured panel to Context > Tasks > Alerts > Chat hierarchy with collapsible tasks, SSE-driven poll/gate cards with backend POST, and full WKWebView removal replaced by NSHostingView**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T10:57:08Z
- **Completed:** 2026-03-10T11:02:56Z
- **Tasks:** 2
- **Files modified:** 8 (1 created, 5 modified, 2 deleted)

## Accomplishments
- Panel follows approved visual hierarchy: Context (event + timer + next event) > Tasks (collapsible with count) > Alerts (polls/gates from SSE) > Chat (always visible)
- CollapsibleTasksView shows p1+p2 tasks with count badge when collapsed, full TaskListView when expanded
- PollCardView accepts SSE poll data with expiry countdown timer and auto-dismiss on expiry
- GateAlertView shows severity-colored cards (amber/red) with task lists and dismiss button
- BubbleWindowController completely cleaned of WKWebView -- uses NSHostingView with ContextPanelView
- ChatWebViewVC.swift and chat.html deleted (1236 lines of legacy code removed)
- Context polling removed from BubbleWindowController (SSE via ChatService handles all updates)

## Task Commits

Each task was committed atomically:

1. **Task 1: Restructure ContextPanelView + CollapsibleTasksView** - `2d9b8c3` (feat)
2. **Task 2: Update PollCardView + GateAlertView + clean BubbleWindowController** - `6248962` (feat)

_All commits in ~/projetos/erestor/ repository_

## Files Created/Modified
- `ErestorApp/Views/CollapsibleTasksView.swift` - New collapsible task section wrapping TaskListView with count badge
- `ErestorApp/Views/ContextPanelView.swift` - Restructured layout hierarchy, SSE-driven polls/gates, respondToPoll helper
- `ErestorApp/Views/PollCardView.swift` - Added optional pollId, options, expiresAt params with expiry countdown
- `ErestorApp/Views/GateAlertView.swift` - Added optional tasks list and onDismiss dismiss button
- `ErestorApp/Services/BubbleWindowController.swift` - Replaced WKWebView with NSHostingView(ContextPanelView), removed context polling
- `ErestorApp/project.yml` - Removed ChatWebViewVC.swift from iOS excludes
- `ErestorApp/Views/ChatWebViewVC.swift` - DELETED (WKWebView bridge)
- `ErestorApp/Resources/chat.html` - DELETED (web-based chat UI)

## Decisions Made
- Kept PollCardView backward-compatible with old PollType enum + question signature, adding optional SSE fields as new parameters -- avoids breaking any potential non-SSE callers
- GateAlertView supports both legacy GateAlertAction-based actions and new onDismiss closure -- gradual migration
- Removed context polling from BubbleWindowController entirely since SSE event stream in ChatService handles all real-time updates
- Panel respondToPoll POSTs to /v1/polls/{id}/respond endpoint created in Plan 02-02

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 2 macOS experience is now complete: SSE streaming, native chat, polls/gates, panel layout all done
- All 4 plans in phase 02-macos-experience executed successfully
- Ready for Phase 3 (iOS experience) or verification

## Self-Check: PASSED

All 5 created/modified files verified on disk. Both deleted files confirmed absent. Both commit hashes verified in git log.

---
*Phase: 02-macos-experience*
*Completed: 2026-03-10*
