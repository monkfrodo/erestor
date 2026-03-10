---
phase: 2
slug: macos-experience
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest (Python backend) |
| **Config file** | ~/claude-sync/produtividade/pytest.ini or pyproject.toml |
| **Quick run command** | `cd ~/claude-sync/produtividade && python -m pytest tests/ -x --timeout=10` |
| **Full suite command** | `cd ~/claude-sync/produtividade && python -m pytest tests/ --timeout=30` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd ~/claude-sync/produtividade && python -m pytest tests/ -x --timeout=10`
- **After every plan wave:** Run `cd ~/claude-sync/produtividade && python -m pytest tests/ --timeout=30`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | PANEL-07 | integration | `pytest tests/test_events_stream.py -x` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | DATA-03 | unit | `pytest tests/test_events_stream.py::test_gate_push -x` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | CHAT-02 | unit | `pytest tests/test_chat_anthropic.py -x` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | CHAT-01 | integration | `pytest tests/test_chat_anthropic.py::test_action_parsing -x` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 2 | DATA-01 | unit | `pytest tests/test_polls_api.py::test_energy_poll -x` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 2 | DATA-02 | unit | `pytest tests/test_polls_api.py::test_block_quality -x` | ❌ W0 | ⬜ pending |
| 02-03-03 | 03 | 2 | DATA-04 | unit | `pytest tests/test_polls_api.py::test_store_response -x` | ❌ W0 | ⬜ pending |
| 02-04-01 | 04 | 3 | SYNT-01 | unit | `pytest tests/test_synthesis_api.py::test_synthesis_query -x` | ❌ W0 | ⬜ pending |
| 02-04-02 | 04 | 3 | SYNT-02 | integration | `pytest tests/test_synthesis_api.py::test_on_demand -x` | ❌ W0 | ⬜ pending |
| 02-05-01 | 05 | 3 | PANEL-01 | manual | N/A (NSPanel visual) | N/A | ⬜ pending |
| 02-05-02 | 05 | 3 | PANEL-02 | manual | N/A (Carbon hotkey) | N/A | ⬜ pending |
| 02-05-03 | 05 | 3 | PANEL-03-06 | manual | N/A (SwiftUI views) | N/A | ⬜ pending |
| 02-05-04 | 05 | 3 | CHAT-03 | manual | N/A (Swift state) | N/A | ⬜ pending |
| 02-05-05 | 05 | 3 | CHAT-04 | manual | N/A (SwiftUI layout) | N/A | ⬜ pending |
| 02-05-06 | 05 | 3 | NOTF-01 | manual | N/A (UNNotifications) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_events_stream.py` — SSE event stream tests (PANEL-07, DATA-03)
- [ ] `tests/test_chat_anthropic.py` — Anthropic SDK streaming tests (CHAT-02, CHAT-01)
- [ ] `tests/test_polls_api.py` — Poll CRUD tests (DATA-01, DATA-02, DATA-04)
- [ ] `tests/test_synthesis_api.py` — Synthesis query tests (SYNT-01, SYNT-02)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Floating bubble NSPanel doesn't steal focus | PANEL-01 | AppKit visual behavior | Launch app, verify bubble appears, click other apps, verify no focus steal |
| Cmd+Shift+E toggles panel | PANEL-02 | Carbon hotkey requires running app | Press Cmd+Shift+E, verify panel toggles |
| Context cards show event/timer/tasks | PANEL-03-06 | SwiftUI rendering | Open panel, verify event card, timer chip, next event, task list render |
| Chat history persists in session | CHAT-03 | Swift state management | Send messages, scroll up, verify history |
| Chat input always visible | CHAT-04 | SwiftUI layout | Open panel, verify input at bottom regardless of content |
| macOS notifications with inline actions | NOTF-01 | UNUserNotificationCenter | Trigger poll, check notification appears with action buttons |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
