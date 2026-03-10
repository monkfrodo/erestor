---
phase: 4
slug: web-pwa
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Vitest + React Testing Library (web) / pytest (backend) |
| **Config file** | `web/vitest.config.ts` (Wave 0 installs) |
| **Quick run command** | `cd web && npx vitest run --reporter=verbose` |
| **Full suite command** | `cd web && npx vitest run && pytest tests/test_webpush.py -x` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd web && npx vitest run --reporter=verbose`
- **After every plan wave:** Run `cd web && npx vitest run && pytest tests/test_webpush.py -x`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | WEB-01 | unit | `npx vitest run src/__tests__/manifest.test.ts` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | WEB-01 | unit | `npx vitest run src/__tests__/panel.test.tsx -t "panel"` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | WEB-01 | unit | `npx vitest run src/__tests__/sse.test.ts -t "sse"` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | WEB-02 | unit | `npx vitest run src/__tests__/chat.test.tsx -t "chat"` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | WEB-03 | unit | `npx vitest run src/__tests__/push.test.ts -t "push"` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | NOTF-03 | unit (pytest) | `pytest tests/test_webpush.py -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `web/vitest.config.ts` — Vitest configuration for Next.js
- [ ] `web/src/__tests__/` — Test directory structure with stubs
- [ ] `tests/test_webpush.py` — Backend web push router tests
- [ ] Framework install: `npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PWA installable (standalone mode) | WEB-01 | Browser install prompt requires real browser | Open in Chrome/Edge → check "Install app" option in address bar |
| Push notification delivery | NOTF-03 | Requires real browser permission + push service | 1. Grant notification permission 2. Trigger poll from backend 3. Verify notification appears |
| Notification action buttons | NOTF-03 | Chrome-only feature, requires user interaction | Click notification action button → verify PWA opens to correct modal |
| SSE reconnection | WEB-01/WEB-02 | Network interruption simulation | Kill backend → wait → restart → verify streams reconnect |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
