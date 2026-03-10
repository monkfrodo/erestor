---
phase: 04-web-pwa
plan: 01
subsystem: ui
tags: [nextjs, pwa, typescript, tailwind, zustand, sse, vitest]

requires:
  - phase: 01-api-foundation
    provides: REST + SSE API endpoints (context, events/stream, chat, calendar)
provides:
  - Next.js 15 PWA project scaffolding at web/
  - Vesper Dark design system as CSS custom properties + TypeScript constants
  - SSE connection manager with exponential backoff reconnection
  - Zustand stores for context, chat, and poll state
  - Panel tab with EventCard, TimerChip, TaskList, NextEvent components
  - Responsive layout shell (mobile bottom tabs, desktop sidebar)
  - PWA manifest (standalone, installable)
  - Push-only service worker
affects: [04-02, 04-03]

tech-stack:
  added: [next@15.5, react@19.1, zustand@5, react-markdown@10, rehype-highlight@7, vitest@4, tailwindcss@4]
  patterns: [zustand-selectors, sse-exponential-backoff, css-custom-properties-ds, mobile-first-responsive]

key-files:
  created:
    - web/src/app/globals.css
    - web/src/app/manifest.ts
    - web/src/app/layout.tsx
    - web/src/app/page.tsx
    - web/src/lib/ds.ts
    - web/src/services/api.ts
    - web/src/services/sse.ts
    - web/src/stores/contextStore.ts
    - web/src/stores/chatStore.ts
    - web/src/stores/pollStore.ts
    - web/src/components/panel/EventCard.tsx
    - web/src/components/panel/TimerChip.tsx
    - web/src/components/panel/TaskList.tsx
    - web/src/components/panel/NextEvent.tsx
    - web/src/components/tabs/PainelTab.tsx
    - web/src/components/layout/MobileLayout.tsx
    - web/src/components/layout/DesktopLayout.tsx
    - web/public/sw.js
  modified: []

key-decisions:
  - "Tailwind v4 @theme block + :root CSS vars for DS (dual access: Tailwind classes + var() inline)"
  - "Push-only service worker (no offline caching per PROJECT.md scope)"
  - "Query param auth for SSE (EventSource lacks header support, single-user acceptable)"
  - "Turbopack enabled by default from create-next-app"
  - "Modified web/.gitignore to allow .env.example commit"

patterns-established:
  - "DS CSS vars: --ds-surface, --ds-border, etc. mapping 1:1 with DesignSystem.swift"
  - "Zustand selectors: useContextStore((s) => s.currentEvent) for fine-grained re-renders"
  - "SSE reconnection: 3s initial, exponential backoff to 30s cap, reset on heartbeat"
  - "Responsive layout: MobileLayout (md:hidden) + DesktopLayout (hidden md:flex)"

requirements-completed: [WEB-01]

duration: 7min
completed: 2026-03-10
---

# Phase 4 Plan 1: PWA Foundation Summary

**Next.js 15 PWA with Vesper Dark design system, Zustand stores, SSE real-time connection, panel tab components, and responsive mobile/desktop layout shell**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-10T17:59:05Z
- **Completed:** 2026-03-10T18:06:16Z
- **Tasks:** 2
- **Files modified:** 30+

## Accomplishments
- Full Next.js 15 PWA project with installable manifest, dark splash screen, and placeholder icons
- Vesper Dark design system ported 1:1 from DesignSystem.swift as CSS custom properties
- SSE connection manager connecting to backend event stream with exponential backoff reconnection
- Three Zustand stores (context, chat, poll) for real-time state management
- Panel tab showing current event with progress bar, live timer, tasks with priority colors, and next event
- Responsive layout: mobile bottom tab bar (4 tabs) and desktop sidebar (360px panel) + content
- 19 Vitest tests all passing (manifest validation, SSE behavior, panel component rendering)

## Task Commits

1. **Task 1: Scaffold Next.js project with DS, manifest, stores, and services** - `fb57a00` (feat)
2. **Task 2: Panel tab components and responsive layout shell** - `33a040a` (feat)

## Files Created/Modified
- `web/src/app/globals.css` - Tailwind v4 + DS CSS custom properties
- `web/src/app/manifest.ts` - PWA manifest (standalone, DS colors)
- `web/src/app/layout.tsx` - Root layout with SW registration
- `web/src/app/page.tsx` - Main app with SSE init and responsive layouts
- `web/src/lib/ds.ts` - DS constants as TypeScript object
- `web/src/services/api.ts` - API fetch wrapper with auth
- `web/src/services/sse.ts` - SSE connection manager with reconnection
- `web/src/stores/contextStore.ts` - WorldState from SSE events
- `web/src/stores/chatStore.ts` - Chat messages and streaming state
- `web/src/stores/pollStore.ts` - Active polls and gate alerts
- `web/src/components/panel/EventCard.tsx` - Current event with progress bar
- `web/src/components/panel/TimerChip.tsx` - Live timer with project label
- `web/src/components/panel/TaskList.tsx` - Day tasks with priority indicators
- `web/src/components/panel/NextEvent.tsx` - Next event with time-until
- `web/src/components/tabs/PainelTab.tsx` - Panel composition
- `web/src/components/layout/MobileLayout.tsx` - Bottom tab bar layout
- `web/src/components/layout/DesktopLayout.tsx` - Sidebar + content layout
- `web/public/sw.js` - Push-only service worker

## Decisions Made
- Tailwind v4 @theme block for DS colors alongside :root CSS vars for dual access
- Push-only service worker -- no offline caching per explicit PROJECT.md scope
- Query parameter auth for SSE since EventSource API lacks custom header support
- Modified web/.gitignore to unignore .env.example (was caught by .env* pattern)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Modified .gitignore for .env.example**
- **Found during:** Task 1 (committing files)
- **Issue:** web/.gitignore had `.env*` pattern that blocked `.env.example` from being committed
- **Fix:** Added `!.env.example` exception to .gitignore
- **Files modified:** web/.gitignore
- **Verification:** git add succeeded after fix
- **Committed in:** fb57a00 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Trivial gitignore fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PWA foundation complete with all stores, services, and layout components
- Ready for Plan 04-02 (Chat tab with streaming) and 04-03 (Agenda, Insights, Web Push)
- Backend API endpoints already built in Phase 1 -- no backend changes needed

## Self-Check: PASSED

All 21 key files verified present. Both task commits (fb57a00, 33a040a) confirmed in git log.

---
*Phase: 04-web-pwa*
*Completed: 2026-03-10*
