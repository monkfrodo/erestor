---
phase: 3
slug: ios-data-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest (Python backend) + XCTest (Swift, not yet configured) |
| **Config file** | pytest discovered from produtividade/ |
| **Quick run command** | `python3 -m pytest tests/ -x --timeout=30` |
| **Full suite command** | `python3 -m pytest tests/ --timeout=60` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `python3 -m pytest tests/ -x --timeout=30`
- **After every plan wave:** Run `python3 -m pytest tests/ --timeout=60`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 0 | MIGR-01, MIGR-02, MIGR-03 | unit | `pytest tests/test_migration.py -x` | ❌ W0 | ⬜ pending |
| TBD | 01 | 0 | NOTF-02 | unit | `pytest tests/test_apns_integration.py -x` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | IOS-01 | manual-only | Xcode simulator visual check | N/A | ⬜ pending |
| TBD | TBD | TBD | IOS-02 | manual-only | Xcode simulator visual check | N/A | ⬜ pending |
| TBD | TBD | TBD | IOS-03 | manual-only | Xcode simulator interaction test | N/A | ⬜ pending |
| TBD | TBD | TBD | IOS-04 | manual-only | Requires physical device + APNs config | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/test_migration.py` — covers MIGR-01, MIGR-02, MIGR-03 (migration idempotency, data integrity)
- [ ] `tests/test_apns_integration.py` — covers NOTF-02 (APNs send with mocked httpx)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Painel tab shows context cards | IOS-01 | SwiftUI visual layout, single-user app | Build for iOS simulator, verify ContextPanelView with cards |
| Agenda view displays day events | IOS-02 | Visual timeline layout | Build, navigate to Agenda tab, verify DayTimelineView |
| Polls appear as modal sheets | IOS-03 | Interactive UI behavior | Trigger poll via backend, verify sheet appears |
| Push notifications with actions | IOS-04 | Requires APNs + physical device | Test on device: send push, verify buttons work |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
