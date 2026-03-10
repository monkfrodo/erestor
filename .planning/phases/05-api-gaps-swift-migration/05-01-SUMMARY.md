---
phase: 05-api-gaps-swift-migration
plan: 01
subsystem: api + swift-clients
tags: [api, swift, migration, endpoints]
dependency_graph:
  requires: []
  provides: ["/v1/timer/stop", "/v1/history", "/v1/device/register", "swift-v1-paths"]
  affects: ["erestor-api", "ErestorApp-macOS", "ErestorApp-iOS"]
tech_stack:
  added: []
  patterns: ["lazy-import-in-handlers", "asyncio.to_thread", "ErestorConfig-path-constants"]
key_files:
  created:
    - ~/claude-sync/produtividade/api/routers/timer.py
    - ~/claude-sync/produtividade/api/routers/history.py
    - ~/claude-sync/produtividade/api/routers/device.py
  modified:
    - ~/claude-sync/produtividade/api/main.py
    - ~/projetos/erestor/ErestorApp/ErestorApp/Services/ErestorConfig.swift
    - ~/projetos/erestor/ErestorApp/ErestorApp/Services/ChatService.swift
    - ~/projetos/erestor/ErestorApp/ErestorApp/Views/ContextPanelView.swift
    - ~/projetos/erestor/ErestorApp/ErestorApp/Views/iOS_PainelView.swift
    - ~/projetos/erestor/ErestorApp/ErestorApp/iOS/ErestorApp_iOS.swift
    - ~/projetos/erestor/ErestorApp/ErestorApp/ErestorApp.swift
decisions:
  - "Used `pattern` instead of deprecated `regex` param in FastAPI Query for history endpoint"
  - "Legacy push/respond path updated to /v1/ for consistency (dead code, no backend endpoint)"
metrics:
  duration: 4 min
  completed: "2026-03-10"
requirements_completed: [PANEL-03, CHAT-03, NOTF-02]
---

# Phase 5 Plan 1: API Gaps + Swift /v1/ Migration Summary

Three missing backend endpoints created and all 8 legacy /api/ paths in Swift migrated to /v1/ via centralized ErestorConfig constants.

## What Was Done

### Task 1: Backend Endpoints (~/claude-sync/ repo)

Created three new FastAPI router files following existing patterns (verify_token dependency, ApiResponse envelope, asyncio.to_thread for sync calls):

**POST /v1/timer/stop** (`api/routers/timer.py`)
- Checks all 4 timer files (work, content, ocio, study) in order
- Reads start timestamp, computes duration, deletes timer + desc files
- Saves to GCal via `gcal_extend_or_create` with correct calendar ID per type
- Emits `timer.stopped` event via event_bus
- Returns stopped type, duration_mins, and description

**GET /v1/history** (`api/routers/history.py`)
- Query params: `source` (optional: desktop|telegram), `limit` (default 10, max 50)
- Loads from `erestor.memory.load_history()` via asyncio.to_thread
- Filters by source, slices to limit, returns stripped entries

**POST /v1/device/register** (`api/routers/device.py`)
- Accepts `{token, platform}` body via Pydantic model
- Reads/creates `erestor/data/devices.json` with atomic write
- Deduplicates tokens, appends with ISO timestamp
- Returns `{registered: true}`

All three routers registered in `api/main.py` with `/v1` prefix.

**Commit:** `4818b13` in `~/claude-sync/` repo

### Task 2: Swift Path Migration (~/projetos/erestor/ repo)

**ErestorConfig.swift** -- 6 new path constants added:
- `statusPath`, `contextPath`, `chatPath`, `historyPath`, `timerStopPath`, `deviceRegisterPath`

**ChatService.swift** -- 4 legacy paths fixed:
- `sendMessage()`: `/api/chat` -> `ErestorConfig.chatPath`
- `loadContext()`: `/api/context` -> `ErestorConfig.contextPath`
- `pollStatus()`: `/api/status` -> `ErestorConfig.statusPath`
- `loadHistory()`: `/api/history?...` -> `ErestorConfig.historyPath?...`

**ContextPanelView.swift** -- `stopTimer()`: `/api/timer/stop` -> `ErestorConfig.timerStopPath`

**iOS_PainelView.swift** -- `stopTimer()`: `/api/timer/stop` -> `ErestorConfig.timerStopPath`

**ErestorApp_iOS.swift** -- `registerDeviceToken()`: `/api/device/register` -> `ErestorConfig.deviceRegisterPath`

**ErestorApp.swift** -- `sendPushResponse()`: `/api/push/respond` -> `/v1/push/respond` (dead code, no backend endpoint exists)

**Verification:** `grep -rc '"/api/' ... = 0` -- zero legacy paths remain.

**Commit:** `1423b79` in `~/projetos/erestor/` repo

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed deprecated `regex` param in FastAPI Query**
- **Found during:** Task 1
- **Issue:** FastAPI 0.128.8 deprecates `regex` parameter in `Query()`, warns to use `pattern`
- **Fix:** Changed to `pattern="^(desktop|telegram)$"` in history.py
- **Files modified:** api/routers/history.py

## Verification Results

1. All 3 endpoints registered: `python3 -c "from api.main import app; ..."` confirms /v1/timer/stop, /v1/history, /v1/device/register
2. Zero /api/ paths in Swift: `grep -rc '"/api/' ... = 0`
3. ErestorConfig.swift has all path constants used across the app

## Self-Check: PASSED

- All 3 new router files exist on disk
- Commit 4818b13 exists in ~/claude-sync/ repo
- Commit 1423b79 exists in ~/projetos/erestor/ repo
- Backend verification: all 3 routes importable and registered
- Swift verification: zero /api/ string literals in .swift files
