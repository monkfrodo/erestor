# Erestor

## What This Is

Erestor is Kevin's personal intelligence assistant — a cross-platform system (macOS, iOS, web) that passively and actively collects data about his day (calendar, energy, focus quality, tasks, habits) and returns actionable insights, proactive alerts, and rich daily syntheses. It replaces the current Telegram bot with a purpose-built interface that functions as a contextual panel always present across devices.

## Core Value

Erestor must surface the right context at the right moment — showing what's happening now, what's next, and what patterns matter — so Kevin can make better decisions about how he spends his time and energy.

## Requirements

### Validated

<!-- Capabilities already working in the current system -->

- ✓ Google Calendar integration — reads events, creates events via natural language — existing
- ✓ Daily briefing generation — morning summary with agenda, tasks, context — existing
- ✓ Daily log builder — automatic daily log from collected data — existing
- ✓ Memory system — persistent context about people, projects, sessions — existing
- ✓ Auto-sync agents — morning/periodic/night autonomous routines — existing
- ✓ Claude as LLM brain — natural language understanding and response generation — existing
- ✓ Mood/energy data collection — periodic check-ins about state — existing
- ✓ Daily synthesis — end-of-day analysis crossing data points — existing
- ✓ Reminder system — time-based notifications — existing
- ✓ Timer tracking — track time spent on projects/tasks — existing

### Active

<!-- New capabilities for the rebuilt Erestor -->

- [ ] Cross-platform contextual panel (macOS, iOS, web) with event, timer, tasks, chat
- [ ] Inline energy check-ins (1-5 scale) at intelligent moments
- [ ] Block quality assessment at end of calendar blocks (perdi/meh/ok/flow)
- [ ] Proactive gate alerts (e.g., "block ends in 15 min, task X still open")
- [ ] Native notifications with inline actions (macOS + iOS)
- [ ] Chat interface with natural language commands (create events, set reminders, ask questions)
- [ ] Timer system visible in panel with project/task labeling
- [ ] Evolved daily synthesis — crossing polls, timers, blocks, mood throughout the day
- [ ] Migration of historical data from Telegram-based system
- [ ] Day agenda view (full schedule visible on mobile)
- [ ] Real-time context awareness — panel updates as calendar progresses
- [ ] Backend API replacing Telegram as interface layer

### Out of Scope

- Telegram bot interface — being fully replaced by native platform
- Multi-user support — Erestor is Kevin's personal tool only
- Third-party app integrations beyond current set (GCal, Notion, ActivityWatch) — can expand later
- Offline-first architecture — requires connection to backend/Claude
- Voice interface — text-based interaction only for v1

## Context

Erestor has been running as a Telegram bot on DigitalOcean (Python + PM2) for months. The bot works but the Telegram interface is limiting — no contextual panel, no inline polls, no proactive UI, no timer visibility. The system's intelligence (briefing, synthesis, memory, auto-sync) is proven and valuable; the interface is the bottleneck.

The existing codebase includes:
- **Bot/backend** (`~/claude-sync/produtividade/`): Python scripts for Telegram bot, briefing, log-builder, auto-sync, memory system, hooks
- **Desktop app** (`~/projetos/erestor/ErestorApp/`): Swift/SwiftUI macOS app with floating bubble + chat panel (partially built, needs rethinking)
- **Prototypes**: HTML prototype (`prototipo-painel.html`) defining the target UI/UX for all platforms

A detailed prototype exists showing every state: work mode with timer, energy polls, block quality check, proactive gate alerts, chat conversation, mobile views, and native notifications for both macOS and iOS.

Design language: dark theme (Vesper-inspired), IBM Plex Mono + Inter fonts, green/blue/amber/red accent colors on dark surface.

## Constraints

- **Platform**: Must work on macOS, iOS, and web browsers
- **Backend**: DigitalOcean server (existing infrastructure) — keep what works, refactor what doesn't
- **LLM**: Claude API as the intelligence layer
- **Data migration**: Historical data from Telegram system must be migrated
- **Single user**: Built exclusively for Kevin — no auth complexity needed beyond basic security
- **Design**: Must follow the established prototype visual language (dark, minimal, contextual)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Kill Telegram, build own interface | Full control over UX, enable contextual panels, inline polls, native notifications | — Pending |
| Cross-platform (macOS + iOS + web) | Kevin uses all three daily | — Pending |
| Keep Claude as LLM | Already integrated, proven quality for personal assistant use case | — Pending |
| Keep backend logic, replace interface layer | Briefing, sync, memory logic works — only Telegram interface is the bottleneck | — Pending |
| Migrate historical data | Months of mood, energy, logs have pattern value | — Pending |
| Evolved synthesis | Cross more data points for richer daily analysis | — Pending |

---
*Last updated: 2026-03-09 after initialization*
