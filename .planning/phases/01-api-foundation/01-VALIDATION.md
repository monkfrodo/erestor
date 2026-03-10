---
phase: 1
slug: api-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `pytest tests/ -x -q` |
| **Full suite command** | `pytest tests/ -v` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pytest tests/ -x -q`
- **After every plan wave:** Run `pytest tests/ -v`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | API-01 | smoke | `pytest tests/test_api_status.py -x` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | API-02 | integration | `pytest tests/test_chat_stream.py -x` | ❌ W0 | ⬜ pending |
| 01-03-01 | 01 | 1 | API-03 | unit | `pytest tests/test_context.py -x` | ❌ W0 | ⬜ pending |
| 01-04-01 | 01 | 1 | API-04 | integration | `pytest tests/test_calendar_read.py -x` | ❌ W0 | ⬜ pending |
| 01-05-01 | 02 | 2 | API-05 | integration | `pytest tests/test_calendar_write.py -x` | ❌ W0 | ⬜ pending |
| 01-06-01 | 01 | 1 | API-06 | unit | `pytest tests/test_core_extraction.py -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/` directory — does not exist yet
- [ ] `tests/conftest.py` — shared fixtures (mock GCal token, mock Claude response, test client)
- [ ] `pytest.ini` or `pyproject.toml` [tool.pytest] — test configuration
- [ ] Framework install: `pip install pytest httpx` (httpx needed for FastAPI TestClient)
- [ ] `tests/test_api_status.py` — stubs for API-01
- [ ] `tests/test_chat_stream.py` — stubs for API-02
- [ ] `tests/test_context.py` — stubs for API-03
- [ ] `tests/test_calendar_read.py` — stubs for API-04
- [ ] `tests/test_calendar_write.py` — stubs for API-05
- [ ] `tests/test_core_extraction.py` — stubs for API-06

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSE stream renders in Swift app | API-02 | Requires macOS app client | Start API, open Swift app, send chat message, verify streaming |
| GCal creates real event | API-05 | Requires live GCal token | Call POST /v1/calendar/create with natural language, check Google Calendar |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
