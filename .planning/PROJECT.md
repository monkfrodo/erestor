# Erestor

## What This Is

Erestor is Kevin's personal intelligence assistant — a cross-platform system (macOS, iOS, web) that passively and actively collects data about his day (calendar, energy, focus quality, tasks, habits) and returns actionable insights, proactive alerts, and rich daily syntheses. It replaced the Telegram bot with purpose-built native interfaces on all three platforms.

## Core Value

Surface the right context at the right moment — showing what's happening now, what's next, and what patterns matter — so Kevin can make better decisions about how he spends his time and energy.

## Requirements

### Validated

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
- ✓ FastAPI backend with 12 REST + SSE endpoints (auth, context, chat, calendar, events, polls, synthesis, insights, timer, history, device, webpush) — v1.0
- ✓ macOS floating panel with real-time SSE context, streaming chat, polls, gates, native notifications — v1.0
- ✓ iOS app with TabView (Painel, Chat, Agenda, Insights), poll/gate sheets, APNs push — v1.0
- ✓ Next.js PWA with responsive layout, streaming chat, web push, offline manifest — v1.0
- ✓ Historical data migration (mood/energy, memory, logs) from Telegram to SQLite — v1.0
- ✓ Cross-platform notifications (macOS native, iOS APNs, Web Push) — v1.0

### Active

(None — next milestone requirements TBD via `/gsd:new-milestone`)

### Out of Scope

- Telegram bot interface — fully replaced by native platforms
- Multi-user support — Erestor is Kevin's personal tool only
- Voice interface — text-based interaction only
- Offline-first architecture — requires connection to backend/Claude
- Android app — Kevin uses Apple ecosystem only
- Gamification (streaks, points) — anti-pattern for wellbeing tools
- Full task management — shows tasks, doesn't manage them

## Context

**Current State (post v1.0):**
- Backend: FastAPI on DigitalOcean (12 routers, Python + PM2)
- macOS: Swift/SwiftUI app with floating bubble, Carbon hotkey, MarkdownUI chat
- iOS: Swift/SwiftUI app with 4-tab layout, Swift Charts, APNs
- Web: Next.js 15 PWA with Zustand, SSE, react-markdown
- Data: SQLite (erestor_events.db) with poll_responses, daily_signals, memory_people, memory_context, event_log
- Design: Vesper Dark theme, IBM Plex Mono + Inter fonts

**Known Tech Debt:**
- Human visual verification pending (15 items across macOS/iOS/Web)
- SYNT-02 and API-05 have no client UI (backend-only endpoints)
- iOS agenda only shows today's events (no date-parameterized endpoint)
- ErestorApp.swift has dead code `/v1/push/respond` path
- Nyquist validation not completed for any phase

## Constraints

- **Platform**: macOS, iOS, web browsers
- **Backend**: DigitalOcean server (Python + PM2 + Nginx + SSL)
- **LLM**: Claude API (Anthropic SDK for streaming)
- **Single user**: Built exclusively for Kevin
- **Design**: Vesper Dark theme (dark, minimal, contextual)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Kill Telegram, build own interface | Full control over UX, contextual panels, inline polls, native notifications | ✓ Good — all 3 platforms shipped |
| Cross-platform (macOS + iOS + web) | Kevin uses all three daily | ✓ Good — consistent experience |
| FastAPI + SSE for real-time | Lightweight, Python ecosystem, token streaming | ✓ Good — 12 routers, sub-second updates |
| Anthropic SDK for streaming chat | Direct token-by-token SSE, no polling | ✓ Good — smooth UX on all platforms |
| Lazy imports in Python handlers | Avoid Python 3.9 PEP 604 issues at module level | ✓ Good — workaround for legacy codebase |
| NSHostingView over WKWebView | Native SwiftUI rendering, no web bridge complexity | ✓ Good — eliminated WKWebView entirely |
| MarkdownUI for chat rendering | Native Swift markdown, syntax highlighting | ✓ Good — streaming + formatted output |
| Zustand for web state | Lightweight, no boilerplate, works with SSE | ✓ Good — clean store pattern |
| SQLite for poll/signal data | Simple, no external DB needed, collocated with backend | ✓ Good — migration script works cleanly |
| ErestorConfig path constants | Centralize all /v1/ paths, prevent legacy /api/ drift | ✓ Good — zero legacy paths after Phase 5 |

---
*Last updated: 2026-03-10 after v1.0 milestone*
