# Requirements: Erestor

**Defined:** 2026-03-09
**Core Value:** Surface the right context at the right moment so Kevin can make better decisions about time and energy.

## v1 Requirements

### Backend API

- [x] **API-01**: FastAPI gateway wrapping existing Python services with REST + SSE endpoints
- [x] **API-02**: Chat streaming endpoint using Claude API via SSE
- [x] **API-03**: Context endpoint returning current event, active timer, tasks, and next event in real-time
- [x] **API-04**: Calendar read endpoint returning day agenda from Google Calendar
- [x] **API-05**: Calendar write endpoint creating events via natural language parsed by Claude
- [x] **API-06**: Core logic extracted from Telegram bot handlers into clean reusable functions

### Contextual Panel (macOS)

- [x] **PANEL-01**: Floating bubble (NSPanel) that does not steal focus, always visible
- [x] **PANEL-02**: Global hotkey (Cmd+Shift+E) to toggle panel via Carbon
- [x] **PANEL-03**: Current calendar event displayed with progress bar
- [x] **PANEL-04**: Active timer with project/task label and stop button
- [x] **PANEL-05**: Next event preview with time until
- [x] **PANEL-06**: Task list for the day with priority indicators
- [x] **PANEL-07**: Real-time panel updates via SSE (no polling)

### Chat

- [x] **CHAT-01**: Natural language commands to create events, set reminders, ask questions
- [x] **CHAT-02**: Streaming responses from Claude displayed in real-time
- [x] **CHAT-03**: Conversation history persists within session
- [x] **CHAT-04**: Chat input always visible at bottom of panel

### Data Collection

- [x] **DATA-01**: Energy check-in polls (1-5 scale) triggered at intelligent moments
- [x] **DATA-02**: Block quality assessment poll at end of calendar blocks (perdi/meh/ok/flow)
- [x] **DATA-03**: Proactive gate alerts when block is ending and tasks remain open
- [x] **DATA-04**: Poll responses stored and available for synthesis

### Synthesis & Insights

- [x] **SYNT-01**: Evolved daily synthesis crossing polls, timers, blocks, and energy data
- [x] **SYNT-02**: On-demand insights from collected data via chat ("como foi minha semana?")

### Mobile (iOS)

- [x] **IOS-01**: Contextual panel adapted for iPhone (event, timer, tasks, chat)
- [x] **IOS-02**: Full day agenda view with all scheduled blocks
- [x] **IOS-03**: Inline energy and block quality polls
- [x] **IOS-04**: Push notifications with inline actions (APNs)

### Web (PWA)

- [ ] **WEB-01**: Progressive Web App with same panel functionality as native
- [ ] **WEB-02**: Chat interface with streaming
- [ ] **WEB-03**: Web push notifications

### Data Migration

- [x] **MIGR-01**: Historical mood/energy data migrated from Telegram system
- [x] **MIGR-02**: Memory system data (people, projects, context) migrated to new storage
- [x] **MIGR-03**: Log history preserved and accessible in new system

### Notifications

- [x] **NOTF-01**: Native macOS notifications with inline actions (polls, quick responses)
- [x] **NOTF-02**: iOS push notifications via APNs with inline actions
- [ ] **NOTF-03**: Web push notifications via Web Push API

## v2 Requirements

### Advanced Analytics

- **ANLT-01**: Weekly/monthly pattern reports (energy curves, focus patterns)
- **ANLT-02**: Correlation analysis (sleep vs focus, meeting load vs energy)

### Integrations

- **INTG-01**: ActivityWatch integration for automatic activity tracking
- **INTG-02**: Notion integration for task sync
- **INTG-03**: Apple Health data import (sleep, exercise)

### UX Polish

- **UX-01**: macOS widgets (WidgetKit) for quick glance
- **UX-02**: iOS widgets for home screen context
- **UX-03**: Siri Shortcuts integration

## Out of Scope

| Feature | Reason |
|---------|--------|
| Telegram bot interface | Being fully replaced — no parallel running |
| Multi-user support | Erestor is Kevin's personal tool exclusively |
| Voice interface | Text-based only for v1, voice adds complexity |
| Offline-first architecture | Requires backend connection for Claude and data |
| Gamification (streaks, points) | Anti-pattern for wellbeing tools — creates anxiety |
| Food/exercise tracking | Apple Health handles this; Erestor is about focus and energy |
| Full task management system | Not a project manager — shows tasks, doesn't manage them |
| Android app | Kevin uses Apple ecosystem only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| API-01 | Phase 1 | Complete |
| API-02 | Phase 1 | Complete |
| API-03 | Phase 1 | Complete |
| API-04 | Phase 1 | Complete |
| API-05 | Phase 1 | Complete |
| API-06 | Phase 1 | Complete |
| PANEL-01 | Phase 2 | Complete |
| PANEL-02 | Phase 2 | Complete |
| PANEL-03 | Phase 2 | Complete |
| PANEL-04 | Phase 2 | Complete |
| PANEL-05 | Phase 2 | Complete |
| PANEL-06 | Phase 2 | Complete |
| PANEL-07 | Phase 2 | Complete |
| CHAT-01 | Phase 2 | Complete |
| CHAT-02 | Phase 2 | Complete |
| CHAT-03 | Phase 2 | Complete |
| CHAT-04 | Phase 2 | Complete |
| DATA-01 | Phase 2 | Complete |
| DATA-02 | Phase 2 | Complete |
| DATA-03 | Phase 2 | Complete |
| DATA-04 | Phase 2 | Complete |
| SYNT-01 | Phase 2 | Complete |
| SYNT-02 | Phase 2 | Complete |
| NOTF-01 | Phase 2 | Complete |
| IOS-01 | Phase 3 | Complete |
| IOS-02 | Phase 3 | Complete |
| IOS-03 | Phase 3 | Complete |
| IOS-04 | Phase 3 | Complete |
| NOTF-02 | Phase 3 | Complete |
| MIGR-01 | Phase 3 | Complete |
| MIGR-02 | Phase 3 | Complete |
| MIGR-03 | Phase 3 | Complete |
| WEB-01 | Phase 4 | Pending |
| WEB-02 | Phase 4 | Pending |
| WEB-03 | Phase 4 | Pending |
| NOTF-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 36 total
- Mapped to phases: 36
- Unmapped: 0

---
*Requirements defined: 2026-03-09*
*Last updated: 2026-03-10 after 02-04 plan execution*
