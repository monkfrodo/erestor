# Roadmap: Erestor

## Overview

Erestor rebuilds the interface layer of Kevin's personal intelligence assistant. The proven backend intelligence (briefing, synthesis, memory, auto-sync) stays; the Telegram bottleneck goes. The roadmap moves from API foundation through the primary macOS experience, then to iOS and finally web -- each phase delivering a complete, usable capability on its platform. macOS comes first because it is the primary daily-driver device and the most complex platform (floating bubble, Carbon hotkey, native notifications).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: API Foundation** - FastAPI gateway wrapping existing Python services with REST + SSE endpoints (completed 2026-03-10)
- [x] **Phase 2: macOS Experience** - Full contextual panel with chat, data collection, synthesis, and native notifications on macOS (completed 2026-03-10)
- [x] **Phase 3: iOS + Data Migration** - iOS app with context panel, push notifications, and historical data migration (completed 2026-03-10)
- [x] **Phase 4: Web PWA** - Progressive web app as browser fallback with same core functionality (completed 2026-03-10)
- [x] **Phase 5: API Gaps + Swift Path Migration** - Missing /v1/ endpoints + migrate all legacy /api/ paths in Swift clients (completed 2026-03-10)
- [x] **Phase 6: Insights + Web Integration Fixes** - Fix insights display on iOS/Web + web push actions + SSE completeness (completed 2026-03-10)

## Phase Details

### Phase 1: API Foundation
**Goal**: Kevin's existing Erestor intelligence is accessible via a clean HTTP + SSE API, decoupled from Telegram
**Depends on**: Nothing (first phase)
**Requirements**: API-01, API-02, API-03, API-04, API-05, API-06
**Success Criteria** (what must be TRUE):
  1. A REST endpoint returns the current context (active event, timer, tasks, next event) as JSON
  2. A chat endpoint streams Claude responses via SSE in real-time
  3. Calendar events can be read (day agenda) and created (natural language parsed by Claude) through API calls
  4. Core logic functions are callable without any Telegram dependency
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md -- FastAPI app setup with auth, schemas, status and context endpoints
- [x] 01-02-PLAN.md -- Chat streaming SSE and calendar read/write endpoints

### Phase 2: macOS Experience
**Goal**: Kevin has a fully functional macOS contextual panel that replaces Telegram as his primary Erestor interface
**Depends on**: Phase 1
**Requirements**: PANEL-01, PANEL-02, PANEL-03, PANEL-04, PANEL-05, PANEL-06, PANEL-07, CHAT-01, CHAT-02, CHAT-03, CHAT-04, DATA-01, DATA-02, DATA-03, DATA-04, NOTF-01, SYNT-01, SYNT-02
**Success Criteria** (what must be TRUE):
  1. A floating panel shows current event with progress, active timer, next event, and day tasks -- updating in real-time via SSE without polling
  2. Kevin can chat with Erestor in natural language (create events, set reminders, ask questions) and see streaming responses
  3. Energy check-in polls appear at intelligent moments, block quality polls appear when calendar blocks end, and gate alerts fire when blocks are ending with tasks open
  4. Daily synthesis crosses polls, timers, blocks, and energy data into a richer analysis than the current Telegram version
  5. Native macOS notifications with inline actions deliver proactive alerts without requiring the panel to be open
**Plans**: 6 plans

Plans:
- [x] 02-01-PLAN.md -- Backend SSE event stream + Anthropic SDK chat migration
- [x] 02-02-PLAN.md -- Backend poll storage, CRUD API, and synthesis endpoints
- [x] 02-03-PLAN.md -- Swift SSE client, MarkdownUI chat, and token streaming
- [x] 02-04-PLAN.md -- Panel layout restructure, collapsible tasks, poll/gate card updates
- [x] 02-05-PLAN.md -- macOS notifications for polls/gates + backend poll scheduling
- [x] 02-06-PLAN.md -- Full macOS experience verification checkpoint

### Phase 3: iOS + Data Migration
**Goal**: Kevin has mobile access to Erestor on iPhone and all historical data from the Telegram era is preserved in the new system
**Depends on**: Phase 2
**Requirements**: IOS-01, IOS-02, IOS-03, IOS-04, NOTF-02, MIGR-01, MIGR-02, MIGR-03
**Success Criteria** (what must be TRUE):
  1. An iOS app shows the contextual panel (event, timer, tasks, chat) adapted for iPhone
  2. A full day agenda view displays all scheduled blocks on mobile
  3. Energy and block quality polls work inline on iOS, and push notifications with actions arrive via APNs
  4. Historical mood/energy data, memory system data, and log history from the Telegram system are accessible in the new system
**Plans**: 5 plans

Plans:
- [x] 03-01-PLAN.md -- Data migration (memory system tables, idempotent script) + insights API endpoint
- [x] 03-02-PLAN.md -- iOS app foundation (TabView + Painel tab + Chat + scenePhase SSE lifecycle)
- [x] 03-03-PLAN.md -- iOS Agenda tab (vertical timeline, swipe, detail sheet) + Insights tab (Swift Charts)
- [x] 03-04-PLAN.md -- iOS poll/gate modal sheets + notification categories + backend APNs integration
- [x] 03-05-PLAN.md -- Gap closure: verify iOS build + confirm APNs commit state

### Phase 4: Web PWA
**Goal**: Kevin can access Erestor from any browser as a fallback when not on an Apple device
**Depends on**: Phase 1
**Requirements**: WEB-01, WEB-02, WEB-03, NOTF-03
**Success Criteria** (what must be TRUE):
  1. A PWA-installable web app provides the same panel functionality (event, timer, tasks) as native clients
  2. Chat with streaming responses works in the browser
  3. Web push notifications deliver alerts when the browser is open
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md -- Next.js PWA scaffold, design system, stores, SSE service, and Panel tab
- [x] 04-02-PLAN.md -- Chat tab with streaming markdown + Agenda and Insights tabs
- [x] 04-03-PLAN.md -- Poll/gate modals + web push notifications (frontend + backend)

### Phase 5: API Gaps + Swift Path Migration
**Goal**: All Swift client paths use correct /v1/ endpoints, with missing backend endpoints created
**Depends on**: Phase 1, Phase 2, Phase 3
**Requirements**: PANEL-03, CHAT-03, NOTF-02
**Gap Closure:** Closes gaps from v1.0 audit — legacy /api/ paths, missing endpoints
**Success Criteria** (what must be TRUE):
  1. POST /v1/timer/stop exists and stops the active timer
  2. GET /v1/history returns recent conversation history
  3. POST /v1/device/register accepts iOS device tokens for APNs
  4. All Swift /api/ path references are replaced with /v1/ equivalents (zero legacy paths remain)
  5. Timer stop button, chat history load, and iOS push registration work end-to-end
**Plans**: 1 plan

Plans:
- [x] 05-01-PLAN.md -- Backend endpoints (timer/stop, history, device/register) + Swift /api/ to /v1/ migration

### Phase 6: Insights + Web Integration Fixes
**Goal**: Insights charts render correctly on iOS and Web, web push actions work, web SSE handles all event types
**Depends on**: Phase 1, Phase 3, Phase 4
**Requirements**: IOS-03, WEB-02, NOTF-03
**Gap Closure:** Closes gaps from v1.0 audit — decode mismatches, missing handlers
**Success Criteria** (what must be TRUE):
  1. iOS InsightsView correctly unwraps ApiResponse.data and displays energy/quality/timer charts
  2. Web InsightsTab field names and shapes match backend response — charts render real data
  3. Web service worker poll response action reaches backend successfully
  4. Web SSE client handles poll_expired (removes stale polls) and poll_reminder events
**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md -- iOS InsightsView decode fix + Web InsightsTab transform + sw.js poll-respond route + SSE handlers

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. API Foundation | 2/2 | Complete | 2026-03-10 |
| 2. macOS Experience | 6/6 | Complete | 2026-03-10 |
| 3. iOS + Data Migration | 5/5 | Complete | 2026-03-10 |
| 4. Web PWA | 3/3 | Complete | 2026-03-10 |
| 5. API Gaps + Swift Migration | 1/1 | Complete | 2026-03-10 |
| 6. Insights + Web Fixes | 1/1 | Complete | 2026-03-10 |
