# Feature Research

**Domain:** Personal intelligence assistant / life-tracking system
**Researched:** 2026-03-09
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any personal tracking/assistant system must have to feel complete. Since Erestor is a single-user personal tool, "users" means Kevin -- but the bar is set by commercial products he has used and could switch to.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Mood/energy check-ins | Every tracker (Daylio, Bearable, Exist) has this. Without subjective data there is nothing to correlate. | LOW | Already exists in current system. Rebuild as inline UI polls (1-5 scale) rather than chat commands. Bearable uses 1-10; 1-5 is sufficient for personal use and reduces decision fatigue. |
| Calendar integration | Gyroscope, Apple Health, Notion Life OS all connect to calendar. The schedule is the skeleton of the day. | MEDIUM | Already exists (GCal). Rebuild needs read + write + real-time event awareness in the panel. |
| Daily briefing / morning summary | Standard in AI assistants (Lindy, Motion, Clockwise). Sets context for the day. | MEDIUM | Already exists. Needs richer formatting in new UI (agenda blocks, task counts, weather). |
| Daily synthesis / end-of-day review | Exist generates weekly reports, Reflection.app does AI-guided reviews, Notion Life OS templates have daily review sections. This is the core value loop. | HIGH | Already exists but is the primary differentiator to evolve. Must cross-reference polls, timers, block quality, calendar adherence. |
| Task visibility | Every productivity tool shows pending tasks. The panel must surface what needs doing today. | LOW | Pull from existing task system. Show count + next action, not full task management. |
| Timer / time tracking | Toggl, RescueTime, Clockwise all track where time goes. Without this, "how did I spend my day?" has no answer. | MEDIUM | Already exists. Needs visible timer in panel with project/task labels. |
| Chat / natural language interface | Every AI assistant has conversational input. Users expect to type commands and questions. | MEDIUM | Already exists via Telegram. Rebuild as native chat in panel with streaming responses. |
| Notification / reminder system | Basic expectation of any assistant. "Remind me at 3pm" must work. | MEDIUM | Already exists. Rebuild with native OS notifications (macOS + iOS) with inline actions. |
| Data persistence & history | Exist, Bearable, Daylio all let you look back months/years. Historical data is the foundation of pattern detection. | MEDIUM | Migration of Telegram-era data is critical. New system must store everything durably. |
| Cross-platform access | Gyroscope (iOS + web), Exist (iOS + Android + web), Daylio (mobile). Must work where Kevin is. | HIGH | macOS + iOS + web. This is the biggest infrastructure challenge. |

### Differentiators (Competitive Advantage)

Features that make Erestor uniquely valuable compared to using Daylio + Toggl + Notion + calendar separately.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Contextual panel (always-present, real-time) | No competitor shows current event + timer + next task + energy state in a single persistent view. Gyroscope has dashboards but they are retrospective. Erestor's panel is **live** -- it knows what is happening now. | HIGH | This is THE differentiator. The panel updates as the calendar progresses, shows active timer, surfaces proactive alerts. Not a dashboard you visit; a companion that is always there. |
| Block quality assessment | No mainstream tracker asks "how was that calendar block?" after it ends. Exist correlates activities with mood but at day-level granularity. Block-level quality (perdi/meh/ok/flow) gives hour-level insight. | MEDIUM | Trigger poll when calendar event ends. Simple 4-point scale. Correlate with energy polls before/after. This is novel and high-signal. |
| Proactive gate alerts | "Block ends in 15 min, task X still open" -- no passive tracker does this. Clockwise rearranges calendar but does not coach you through blocks. This is the AI coach aspect Apple is building toward with Health+ but applied to productivity. | MEDIUM | Requires real-time calendar awareness + task state. Push notification with inline action (extend block, mark task done, snooze). |
| Intelligent poll timing | Bearable and Daylio use fixed schedules or manual entry. Erestor can trigger check-ins at contextually smart moments: after a meeting, before a deep work block, when energy is likely to dip (based on historical patterns). | MEDIUM | Start with event-boundary triggers (between calendar blocks). Later add pattern-based timing. |
| Cross-data synthesis with LLM | Exist finds statistical correlations. Erestor uses Claude to generate narrative insights: "Your flow states this week happened on mornings after 7h+ sleep and no meetings before 10am." Natural language > statistical tables. | HIGH | This is the evolved daily synthesis. Claude processes the day's data points and writes a human-readable analysis. Existing system does basic version; new system crosses more data. |
| Unified data model (single-user, all signals) | Commercial tools silo data (mood in Daylio, time in Toggl, calendar in GCal, tasks in Todoist). Erestor owns all signals in one system. Correlations that require crossing tools become trivial. | MEDIUM | Design data model to store mood, energy, timers, block quality, tasks, calendar events in one schema. This unlocks all correlation features. |
| Memory system (persistent context) | No consumer tracker remembers "Kevin mentioned he slept badly because of neighbor noise" and factors that into analysis. Erestor's memory about people, projects, and sessions gives the LLM context that statistical tools cannot have. | MEDIUM | Already exists. Carry forward and integrate into synthesis prompts. |
| Natural language event/task creation | "Schedule dentist Thursday 2pm" or "Remind me to call Maria tomorrow morning" -- conversational creation without switching to GCal or a task app. | LOW | Already exists. Low complexity because the LLM handles parsing. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem valuable but would hurt the product if built.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Multi-user / social features | "Let my partner see my mood" or "compare with friends" | Adds auth complexity, privacy concerns, UI for sharing. Erestor is a personal tool -- multi-user destroys the simplicity. | Keep single-user. If sharing is ever needed, export a weekly summary as text. |
| Gamification (streaks, badges, XP) | Daylio and Notion templates use streaks. Feels motivating. | Streaks punish missed days and create anxiety. Kevin's goal is insight, not compliance. Gamification incentivizes logging for the sake of logging rather than meaningful data. | Show consistency stats without streak pressure. "You logged energy 18 of 21 days this month" is informative without being coercive. |
| Detailed food / nutrition tracking | Gyroscope and Apple Health+ are adding meal logging. Comprehensive health picture. | Extremely high friction. Photo-based food tracking requires training data and is unreliable. Manually logging meals is tedious and abandonment rates are high. Not in Erestor's core value prop. | If diet matters, integrate with a dedicated food app later. Do not build food tracking. |
| Wearable device integration (v1) | Apple Watch, Oura, Fitbit data would enrich correlations. | Significant integration complexity. Each device has its own API, auth flow, data format. Premature before the core loop (poll -> track -> synthesize) is solid. | Defer to v2+. Design data model to accept external health data later, but do not build integrations now. |
| Full task management | "Why not replace Todoist/Things too?" | Task management is a deep product. Building CRUD for tasks, projects, subtasks, priorities is months of work and already solved by dedicated tools. | Show tasks from existing system. Allow creating tasks via chat. Do not build a task management UI. |
| Voice interface | Speaking is faster than typing for check-ins. | Requires speech-to-text, adds latency, accessibility concerns, noisy environments. Text is reliable and searchable. | Defer entirely. Text-first for v1. If voice is ever added, it is a v3 feature. |
| Offline-first architecture | Use Erestor without internet. | The LLM (Claude) requires internet. Without LLM, Erestor loses its core intelligence. Building offline sync adds massive complexity for a single-user tool that always has connectivity. | Accept online requirement. Cache recent data for display, but do not architect for offline operation. |
| Automated habit tracking ("set and forget") | Exist and Gyroscope auto-track steps, screen time, etc. via integrations. | Auto-tracked data has low signal-to-noise. Steps counted but not contextualized. The deliberate act of reporting energy/mood creates self-awareness -- automation removes that reflective moment. | Keep active polls for subjective data. Auto-track only calendar and timer (which are already system-generated). |
| Complex data visualizations / charts | Gyroscope has beautiful health dashboards. Seem essential for a tracking tool. | Charts require significant frontend work. For a single user, narrative synthesis from the LLM is more actionable than interactive charts. "Your energy peaks at 10am" is better than a line graph. | Start with LLM-generated text insights. Add simple sparklines or trend indicators (up/down arrows) if needed. Defer interactive charts. |

## Feature Dependencies

```
[Calendar Integration]
    |--- enables ---> [Block Quality Assessment] (needs to know when blocks end)
    |--- enables ---> [Proactive Gate Alerts] (needs real-time event awareness)
    |--- enables ---> [Daily Briefing] (needs today's agenda)
    |--- enables ---> [Daily Synthesis] (needs calendar adherence data)

[Mood/Energy Check-ins]
    |--- feeds ---> [Daily Synthesis] (subjective data for correlation)
    |--- feeds ---> [Intelligent Poll Timing] (historical patterns)

[Timer System]
    |--- feeds ---> [Daily Synthesis] (time allocation data)
    |--- feeds ---> [Contextual Panel] (live timer display)

[Chat Interface]
    |--- enables ---> [Natural Language Event/Task Creation]
    |--- enables ---> [Reminder System] (conversational reminders)

[Data Persistence]
    |--- required by ---> [ALL features] (nothing works without storage)
    |--- enables ---> [Cross-Data Synthesis] (historical patterns)
    |--- enables ---> [Memory System] (persistent context)

[Backend API]
    |--- required by ---> [Cross-Platform Access] (shared backend)
    |--- required by ---> [Contextual Panel] (real-time data)
    |--- required by ---> [Notifications] (push triggers)

[Contextual Panel]
    |--- enhanced by ---> [Block Quality Assessment] (inline polls)
    |--- enhanced by ---> [Proactive Gate Alerts] (alert display)
    |--- enhanced by ---> [Intelligent Poll Timing] (smart check-ins)

[Cross-Data Synthesis with LLM]
    |--- requires ---> [Mood/Energy Check-ins] (subjective data)
    |--- requires ---> [Timer System] (time data)
    |--- requires ---> [Calendar Integration] (schedule data)
    |--- requires ---> [Block Quality Assessment] (block-level data)
    |--- requires ---> [Memory System] (context)
```

### Dependency Notes

- **Block Quality Assessment requires Calendar Integration:** Cannot ask "how was that block?" without knowing when calendar events end.
- **Proactive Gate Alerts require Calendar Integration + Task visibility:** Must know current event timing AND pending task state to generate meaningful alerts.
- **Cross-Data Synthesis requires all data sources:** The synthesis is only as rich as the data feeding it. More active data points = richer daily analysis.
- **Intelligent Poll Timing requires historical data:** Pattern-based timing needs weeks of poll data to detect energy rhythms. Start with event-boundary triggers.
- **Cross-Platform Access requires Backend API:** All clients must talk to the same backend. Backend API is the foundation for everything.

## MVP Definition

### Launch With (v1)

The minimum to replace Telegram and prove the new interface is better.

- [ ] Backend API (HTTP + SSE) -- replaces Telegram as interface layer
- [ ] Contextual panel (macOS first) -- current event, timer, next task, chat
- [ ] Chat interface with streaming -- natural language commands, same capabilities as Telegram bot
- [ ] Calendar integration (read + write) -- agenda view, event creation
- [ ] Timer system visible in panel -- start/stop/label from panel
- [ ] Inline energy check-ins (1-5 scale) -- triggered between calendar blocks
- [ ] Daily briefing generation -- morning summary pushed to panel
- [ ] Daily synthesis (basic) -- end-of-day analysis with available data
- [ ] Reminder system with native notifications -- macOS notifications with actions
- [ ] Data migration from Telegram system -- carry forward historical data

### Add After Validation (v1.x)

Features to add once the core panel is working daily.

- [ ] Block quality assessment -- trigger after calendar events end, collect perdi/meh/ok/flow
- [ ] Proactive gate alerts -- "block ends in 15min" notifications
- [ ] Intelligent poll timing -- event-boundary triggers first, then pattern-based
- [ ] iOS app -- extend panel to mobile
- [ ] Web interface -- browser access when not on Apple devices
- [ ] Evolved daily synthesis -- cross all data points with richer LLM prompts

### Future Consideration (v2+)

Features to defer until the core loop is solid.

- [ ] Wearable integration (Apple Watch, Oura) -- design data model to accept it, build later
- [ ] Weekly/monthly trend reports -- LLM-generated periodic summaries
- [ ] Pattern detection alerts ("you tend to crash after back-to-back meetings") -- requires substantial historical data
- [ ] Simple trend visualizations (sparklines, arrows) -- once there is enough data to visualize
- [ ] Auto-sync with external tools (ActivityWatch, Notion) -- expand integrations

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Backend API | HIGH | HIGH | P1 |
| Contextual panel (macOS) | HIGH | HIGH | P1 |
| Chat interface | HIGH | MEDIUM | P1 |
| Calendar integration | HIGH | MEDIUM | P1 |
| Timer in panel | HIGH | LOW | P1 |
| Energy check-ins | HIGH | LOW | P1 |
| Daily briefing | HIGH | LOW | P1 |
| Daily synthesis (basic) | HIGH | MEDIUM | P1 |
| Native notifications | HIGH | MEDIUM | P1 |
| Data migration | HIGH | MEDIUM | P1 |
| Block quality assessment | HIGH | LOW | P2 |
| Proactive gate alerts | HIGH | MEDIUM | P2 |
| iOS app | HIGH | HIGH | P2 |
| Web interface | MEDIUM | MEDIUM | P2 |
| Intelligent poll timing | MEDIUM | MEDIUM | P2 |
| Evolved synthesis | HIGH | MEDIUM | P2 |
| Wearable integration | LOW | HIGH | P3 |
| Weekly/monthly reports | MEDIUM | MEDIUM | P3 |
| Pattern detection alerts | MEDIUM | HIGH | P3 |
| Trend visualizations | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (replace Telegram with something strictly better)
- P2: Should have, add within first month of daily use
- P3: Nice to have, build when core loop is proven

## Competitor Feature Analysis

| Feature | Exist.io | Gyroscope | Daylio | Bearable | Erestor Approach |
|---------|----------|-----------|--------|----------|-----------------|
| Mood tracking | Day-level rating + notes | Not core focus | 1-5 with custom moods | 1-10 with granular emotions | 1-5 energy scale, inline polls at smart moments |
| Data correlation | Statistical correlation engine | AI coach + Health Score | Basic monthly stats | Factor analysis reports | LLM narrative synthesis (Claude) |
| Calendar awareness | Imports calendar events | No | No | No | **Real-time** -- knows current block, time remaining, what is next |
| Time tracking | Via RescueTime/Toggl integration | Activity tracking | No | No | Built-in timer with project/task labels |
| Proactive alerts | No | AI coach suggestions | Reminder to log | Reminder to log | Context-aware gate alerts ("block ends in 15min, task X open") |
| Daily review | No (weekly insights) | Daily Health Score | View daily mood history | Daily insights | LLM-generated narrative crossing all data points |
| Chat interface | No | No | No | No | Full conversational interface with Claude |
| Cross-platform | iOS + Android + Web | iOS + Web | iOS + Android | iOS + Android | macOS + iOS + Web |
| Pricing | $6.99/mo | $39/mo (G1) | $5.99/mo | $6.99/mo | Self-hosted (API costs only) |

## Sources

- [Exist.io](https://exist.io/) -- personal analytics platform, correlation engine
- [Gyroscope](https://gyrosco.pe/) -- health tracking with AI coach, Health Score
- [Daylio](https://daylio.net/) -- mood journal with activity tracking
- [Bearable](https://bearable.app/bearable-vs-daylio-which-one-should-you-choose/) -- symptom and mood tracking with health correlations
- [Apple Health+ (2026)](https://www.macrumors.com/2025/11/10/ai-apple-health-service-still-coming/) -- upcoming AI-powered health coaching service
- [Clockwise](https://www.morgen.so/blog-posts/best-ai-planning-assistants) -- AI calendar management
- [Reflection.app](https://www.reflection.app/) -- AI-guided journaling and daily review
- [Notion Life OS templates](https://www.notion4management.com/blog/best-notion-life-templates) -- comprehensive life management in Notion
- [Quantified Self practices](https://rize.io/blog/quantified-self) -- data correlation and self-tracking patterns
- [AI Personal Assistants 2026](https://kairntech.com/blog/articles/ai-personal-assistants/) -- proactive AI assistant trends

---
*Feature research for: personal intelligence assistant / life-tracking system*
*Researched: 2026-03-09*
