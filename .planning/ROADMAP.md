# Roadmap: Erestor

## Overview

Erestor rebuilds the interface layer of Kevin's personal intelligence assistant. The proven backend intelligence (briefing, synthesis, memory, auto-sync) stays; the Telegram bottleneck goes. The roadmap moves from API foundation through the primary macOS experience, then to iOS and finally web -- each phase delivering a complete, usable capability on its platform. macOS comes first because it is the primary daily-driver device and the most complex platform (floating bubble, Carbon hotkey, native notifications).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: API Foundation** - FastAPI gateway wrapping existing Python services with REST + SSE endpoints
- [ ] **Phase 2: macOS Experience** - Full contextual panel with chat, data collection, synthesis, and native notifications on macOS
- [ ] **Phase 3: iOS + Data Migration** - iOS app with context panel, push notifications, and historical data migration
- [ ] **Phase 4: Web PWA** - Progressive web app as browser fallback with same core functionality

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
- [ ] 02-02-PLAN.md -- Backend poll storage, CRUD API, and synthesis endpoints
- [ ] 02-03-PLAN.md -- Swift SSE client, MarkdownUI chat, and token streaming
- [ ] 02-04-PLAN.md -- Panel layout restructure, collapsible tasks, poll/gate card updates
- [ ] 02-05-PLAN.md -- macOS notifications for polls/gates + backend poll scheduling
- [ ] 02-06-PLAN.md -- Full macOS experience verification checkpoint

### Phase 3: iOS + Data Migration
**Goal**: Kevin has mobile access to Erestor on iPhone and all historical data from the Telegram era is preserved in the new system
**Depends on**: Phase 2
**Requirements**: IOS-01, IOS-02, IOS-03, IOS-04, NOTF-02, MIGR-01, MIGR-02, MIGR-03
**Success Criteria** (what must be TRUE):
  1. An iOS app shows the contextual panel (event, timer, tasks, chat) adapted for iPhone
  2. A full day agenda view displays all scheduled blocks on mobile
  3. Energy and block quality polls work inline on iOS, and push notifications with actions arrive via APNs
  4. Historical mood/energy data, memory system data, and log history from the Telegram system are accessible in the new system
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: Web PWA
**Goal**: Kevin can access Erestor from any browser as a fallback when not on an Apple device
**Depends on**: Phase 1
**Requirements**: WEB-01, WEB-02, WEB-03, NOTF-03
**Success Criteria** (what must be TRUE):
  1. A PWA-installable web app provides the same panel functionality (event, timer, tasks) as native clients
  2. Chat with streaming responses works in the browser
  3. Web push notifications deliver alerts when the browser is open
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. API Foundation | 2/2 | Complete | 2026-03-10 |
| 2. macOS Experience | 2/6 | In Progress|  |
| 3. iOS + Data Migration | 0/2 | Not started | - |
| 4. Web PWA | 0/1 | Not started | - |
