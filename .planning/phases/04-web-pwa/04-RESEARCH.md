# Phase 4: Web PWA - Research

**Researched:** 2026-03-10
**Domain:** Next.js PWA with SSE streaming, Web Push, Vesper Dark theme
**Confidence:** HIGH

## Summary

Phase 4 builds a Progressive Web App using Next.js 15 + TypeScript + Tailwind CSS that connects to the existing FastAPI backend (already CORS-enabled, all endpoints built). The PWA is a thin client -- no database, no server-side logic beyond optional VAPID proxy. All data flows through the existing REST + SSE API at `/v1/`.

Next.js has built-in PWA support via `app/manifest.ts` -- no third-party PWA library needed since offline caching is explicitly out of scope. Service worker is only needed for Web Push notifications. The backend needs two new additions: a `/v1/webpush/subscribe` endpoint and a `pywebpush` integration to send push messages alongside the existing APNs sends.

**Primary recommendation:** Use Next.js 15 native manifest support + a hand-written `public/sw.js` for push only. Deploy on DigitalOcean alongside the backend (PM2 + Nginx). Port the DesignSystem.swift colors/fonts exactly as CSS custom properties.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Next.js 15 + TypeScript + Tailwind CSS (Kevin's standard stack)
- PWA with manifest.json -- installable on home screen/desktop with custom icon and splash screen
- Always-online -- no offline cache, no service worker for data caching (consistent with PROJECT.md: offline-first is out of scope)
- Service worker used only for web push notifications
- Deploy on DigitalOcean -- same server as backend, PM2 + Nginx
- Full parity with iOS app: 4 tabs -- Painel, Chat, Agenda, Insights
- Polls (energy + block quality) appear as modals (iOS pattern, not inline cards)
- Gate alerts: web push notification + modal when PWA is open
- Daily synthesis (22h) appears as chat message from Erestor -- same as macOS/iOS
- On-demand insights via chat ("como foi minha semana?") -- same SYNT-02 pattern
- Timer visible in panel with project/task label
- Day agenda with timeline view
- Port exact Vesper Dark theme -- CSS variables mapping 1:1 with Swift DS enum
- Fonts: IBM Plex Mono + Inter (loaded via Google Fonts or self-hosted)
- Colors: DS.surface, DS.bright, DS.green, DS.amber, DS.border, etc. as CSS custom properties
- Mobile-first layout with desktop breakpoint -- mobile uses tabs/cards, desktop gets sidebar with painel + chat side by side
- Chat with full markdown rendering + syntax highlighting (react-markdown + highlight.js or similar)
- Permission requested after first interaction (not on page load)
- Events that trigger push: energy polls, block quality polls, gate alerts, daily synthesis
- Notifications include action buttons: energy 1-5, quality perdi/meh/ok/flow, gate "Ver"
- No deduplication between platforms -- always send web push regardless of macOS/iOS activity

### Claude's Discretion
- Web Push API implementation details (VAPID keys, subscription management)
- Service worker architecture for push handling
- SSE reconnection strategy for web (adapt from Swift's exponential backoff pattern)
- Exact responsive breakpoints and sidebar layout for desktop
- Library choices for markdown rendering and syntax highlighting
- State management approach (React Context, Zustand, or similar)
- Agenda timeline component implementation
- Code location: monorepo (`~/projetos/erestor/web/`) vs separate repo

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WEB-01 | Progressive Web App with same panel functionality as native | Next.js 15 native manifest + Vesper Dark CSS variables + 4-tab layout + SSE for real-time updates |
| WEB-02 | Chat interface with streaming | EventSource API connecting to existing `/v1/chat/stream` + react-markdown for rendering |
| WEB-03 | Web push notifications | Service worker + Web Push API + VAPID keys + pywebpush on backend |
| NOTF-03 | Web push notifications via Web Push API | New backend router for subscription CRUD + pywebpush sending + notification action buttons |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| next | 15.x | App Router framework | Kevin's standard stack, built-in manifest support |
| react | 19.x | UI library | Bundled with Next.js 15 |
| typescript | 5.x | Type safety | Kevin's standard |
| tailwindcss | 4.x | Utility CSS | Kevin's standard, configured via @theme in globals.css |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| react-markdown | ^9.0 | Markdown rendering in chat | Chat message display |
| remark-gfm | ^4.0 | GitHub Flavored Markdown (tables, strikethrough) | Extends react-markdown |
| rehype-highlight | ^7.0 | Syntax highlighting in code blocks | Code in chat responses |
| zustand | ^5.0 | Lightweight state management | Global state (context, chat, polls) |
| pywebpush | ^2.0 | Python Web Push sending (backend) | Sending push notifications from FastAPI |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| zustand | React Context | Context causes unnecessary re-renders with frequent SSE updates; zustand has fine-grained subscriptions |
| rehype-highlight | react-syntax-highlighter | rehype-highlight is lighter, integrates directly with react-markdown pipeline |
| serwist/@ducanh2912/next-pwa | Hand-written sw.js | No offline caching needed -- serwist adds unnecessary complexity for push-only SW |

**Installation (web app):**
```bash
npx create-next-app@15 web --typescript --tailwind --app --src-dir
cd web
npm install react-markdown remark-gfm rehype-highlight zustand
npm install -D @types/node
```

**Installation (backend addition):**
```bash
pip install pywebpush
```

## Architecture Patterns

### Recommended Project Structure (monorepo: `~/projetos/erestor/web/`)
```
web/
├── public/
│   ├── sw.js                    # Service worker (push only)
│   ├── icon-192x192.png         # PWA icon
│   ├── icon-512x512.png         # PWA icon
│   └── badge.png                # Notification badge
├── src/
│   ├── app/
│   │   ├── layout.tsx           # Root layout (fonts, theme, SW registration)
│   │   ├── manifest.ts          # PWA manifest (dynamic)
│   │   ├── page.tsx             # Main app (redirects or renders)
│   │   └── globals.css          # DS CSS variables + Tailwind @theme
│   ├── components/
│   │   ├── tabs/
│   │   │   ├── PainelTab.tsx    # Event card, timer, tasks, next event
│   │   │   ├── ChatTab.tsx      # Chat messages + input
│   │   │   ├── AgendaTab.tsx    # Day timeline view
│   │   │   └── InsightsTab.tsx  # Insights/synthesis display
│   │   ├── modals/
│   │   │   ├── PollModal.tsx    # Energy/quality poll modal
│   │   │   └── GateModal.tsx    # Gate alert modal
│   │   ├── chat/
│   │   │   ├── ChatMessage.tsx  # Single message with markdown
│   │   │   └── ChatInput.tsx    # Input field
│   │   ├── panel/
│   │   │   ├── EventCard.tsx    # Current event with progress
│   │   │   ├── TimerChip.tsx    # Active timer display
│   │   │   ├── TaskList.tsx     # Day tasks
│   │   │   └── NextEvent.tsx    # Next event preview
│   │   └── layout/
│   │       ├── MobileLayout.tsx # Bottom tab navigation
│   │       └── DesktopLayout.tsx # Sidebar + content
│   ├── stores/
│   │   ├── contextStore.ts     # WorldState from SSE
│   │   ├── chatStore.ts        # Chat messages + streaming state
│   │   └── pollStore.ts        # Active polls queue
│   ├── services/
│   │   ├── api.ts              # REST API client (fetch wrapper)
│   │   ├── sse.ts              # SSE connection manager
│   │   └── push.ts             # Push subscription management
│   └── lib/
│       ├── ds.ts               # Design system constants
│       └── utils.ts            # Helpers
├── next.config.ts
├── .env.example
└── package.json
```

**Code location recommendation (Claude's Discretion):** Use `~/projetos/erestor/web/` (monorepo). Reasons: (1) the `prototipo-painel.html` is already in the repo root as visual reference, (2) the DesignSystem.swift is in the same repo for color/font mapping, (3) deploy is on DigitalOcean via PM2 not Vercel so no branch-deploy concern, (4) keeps all Erestor client code together.

### Pattern 1: SSE Connection with Reconnection
**What:** Browser EventSource with exponential backoff reconnection
**When to use:** Connecting to `/v1/events/stream` for real-time context, polls, gates
**Example:**
```typescript
// Source: MDN EventSource docs + Swift pattern from Phase 2 (02-03)
class SSEManager {
  private es: EventSource | null = null;
  private retryDelay = 3000;
  private maxDelay = 30000;
  private token: string;

  connect() {
    // EventSource doesn't support custom headers natively
    // Use URL param for auth since backend is single-user
    this.es = new EventSource(`${API_BASE}/v1/events/stream?token=${this.token}`);

    this.es.addEventListener('context_update', (e) => {
      const data = JSON.parse(e.data);
      useContextStore.getState().update(data);
    });

    this.es.addEventListener('poll_energy', (e) => {
      const data = JSON.parse(e.data);
      usePollStore.getState().addPoll(data);
    });

    this.es.addEventListener('poll_quality', (e) => {
      const data = JSON.parse(e.data);
      usePollStore.getState().addPoll(data);
    });

    this.es.addEventListener('gate_alert', (e) => {
      const data = JSON.parse(e.data);
      usePollStore.getState().addGate(data);
    });

    this.es.addEventListener('heartbeat', () => {
      this.retryDelay = 3000; // Reset on successful heartbeat
    });

    this.es.onerror = () => {
      this.es?.close();
      setTimeout(() => this.connect(), this.retryDelay);
      this.retryDelay = Math.min(this.retryDelay * 2, this.maxDelay);
    };
  }

  disconnect() {
    this.es?.close();
    this.es = null;
  }
}
```

### Pattern 2: Chat Streaming with fetch + ReadableStream
**What:** POST to `/v1/chat/stream` and consume SSE response via fetch (not EventSource, since EventSource only supports GET)
**When to use:** Sending chat messages and streaming responses
**Example:**
```typescript
// Source: Backend chat.py uses POST /chat/stream with SSE response
async function streamChat(message: string, history: ChatMessage[]) {
  const res = await fetch(`${API_BASE}/v1/chat/stream`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({ message, history }),
  });

  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop()!;

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = JSON.parse(line.slice(6));
        if (data.text) {
          // Append token to streaming message
          useChatStore.getState().appendToken(data.text);
        }
        if (data.done) {
          useChatStore.getState().finishStreaming(data.full_response, data.actions);
        }
      }
    }
  }
}
```

### Pattern 3: Design System CSS Variables
**What:** Port DesignSystem.swift colors as CSS custom properties
**When to use:** All styling across the PWA
**Example:**
```css
/* Source: ErestorApp/Views/DesignSystem.swift */
:root {
  --ds-surface: #1e1c1a;
  --ds-border: #2a2725;
  --ds-muted: #3d3733;
  --ds-dim: #4a4540;
  --ds-subtle: #6b5b50;
  --ds-text: #b8a99d;
  --ds-bright: #e0d5ca;

  --ds-green: #4a9e69;
  --ds-blue: #5b6d99;
  --ds-red: #c25a4a;
  --ds-amber: #c9a84c;

  --ds-green-dim: rgba(74, 158, 105, 0.08);
  --ds-blue-dim: rgba(91, 109, 153, 0.08);
  --ds-red-dim: rgba(194, 90, 74, 0.08);
  --ds-amber-dim: rgba(201, 168, 76, 0.08);

  --ds-s2: #242120;
  --ds-bg: #1a1816;

  --font-mono: 'IBM Plex Mono', ui-monospace, monospace;
  --font-body: 'Inter', system-ui, sans-serif;
}
```

### Pattern 4: Zustand Store for SSE State
**What:** Zustand stores with fine-grained selectors for SSE-updated state
**When to use:** Avoid re-rendering entire app on every SSE event
**Example:**
```typescript
import { create } from 'zustand';

interface ContextState {
  currentEvent: any | null;
  timer: any | null;
  tasks: any[];
  nextEvent: any | null;
  update: (data: any) => void;
}

export const useContextStore = create<ContextState>((set) => ({
  currentEvent: null,
  timer: null,
  tasks: [],
  nextEvent: null,
  update: (data) => set({
    currentEvent: data.current_event ?? null,
    timer: data.active_timer ?? null,
    tasks: data.tasks ?? [],
    nextEvent: data.next_event ?? null,
  }),
}));
```

### Anti-Patterns to Avoid
- **Using EventSource for POST requests:** EventSource only supports GET. Chat streaming requires fetch + ReadableStream for POST body support.
- **EventSource with Authorization header:** The native EventSource API does not support custom headers. For the event stream, pass the token as a URL query parameter (single-user app, acceptable security tradeoff) or use a polyfill like `sse.js`.
- **React Context for high-frequency SSE updates:** Context re-renders all consumers on every change. Zustand with selectors avoids this.
- **Using next-pwa/serwist for push-only SW:** These packages add offline caching complexity that is explicitly out of scope. A hand-written `public/sw.js` is simpler and sufficient.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown rendering | Custom parser | react-markdown + remark-gfm + rehype-highlight | Edge cases in markdown spec are endless |
| State management with SSE | Custom pub/sub | zustand | Built-in devtools, selectors, persistence |
| Web Push encryption | Custom crypto | pywebpush (Python) | RFC 8188 aes128gcm encoding is complex |
| SSE parsing for chat POST | Custom parser | fetch + ReadableStream standard API | Browser-native, handles chunked transfer |
| PWA manifest | JSON file | Next.js app/manifest.ts | Type-safe, dynamic if needed |

**Key insight:** The PWA is a thin client. All intelligence lives in the backend. The web app's job is display + interaction -- keep it as simple as possible.

## Common Pitfalls

### Pitfall 1: EventSource Auth Header Limitation
**What goes wrong:** EventSource API does not support custom HTTP headers. Bearer token cannot be sent.
**Why it happens:** EventSource is a simple API designed for GET-only streams.
**How to avoid:** For the `/v1/events/stream` endpoint, either: (a) pass token as query parameter `?token=xxx` (acceptable for single-user), or (b) use a polyfill like `sse.js` that supports headers, or (c) add cookie-based auth as fallback. Recommendation: query parameter -- simplest, single-user app.
**Warning signs:** SSE connection returns 401/403.

### Pitfall 2: SSE Connection Limit (6 per domain on HTTP/1.1)
**What goes wrong:** Opening multiple tabs exhausts the browser's 6-connection limit per domain.
**Why it happens:** HTTP/1.1 spec limits concurrent connections. Each SSE stream holds one open.
**How to avoid:** Use HTTP/2 on Nginx (already likely configured with SSL). HTTP/2 multiplexes connections. Also consider SharedWorker or BroadcastChannel for multi-tab coordination.
**Warning signs:** SSE connections fail in additional tabs.

### Pitfall 3: Web Push on iOS Safari Requires Installed PWA
**What goes wrong:** Push notifications don't work in Safari mobile browser, only in installed PWA.
**Why it happens:** iOS 16.4+ supports Web Push, but only for PWAs added to home screen (standalone mode).
**How to avoid:** Show install prompt for iOS users before requesting push permission. The `InstallPrompt` component pattern from Next.js docs handles this.
**Warning signs:** `PushManager` returns undefined on iOS Safari (not installed).

### Pitfall 4: Notification Action Buttons Browser Support
**What goes wrong:** Action buttons work on Chrome/Android but not on Safari/iOS PWA.
**Why it happens:** Safari does not support the `actions` property in `showNotification()` options.
**How to avoid:** Design notifications to work without actions (clicking the notification itself opens the PWA). Actions are progressive enhancement -- energy/quality buttons work on Chrome, on Safari the user clicks the notification and sees the poll modal in-app.
**Warning signs:** Actions array is silently ignored on Safari.

### Pitfall 5: Chat POST Streaming SSE Parsing
**What goes wrong:** Using EventSource for chat fails because it's a POST request.
**Why it happens:** Backend's `/v1/chat/stream` is POST (sends message body). EventSource only supports GET.
**How to avoid:** Use `fetch()` with `ReadableStream` to consume the SSE response from the POST endpoint. Parse SSE format manually (split on `\n`, extract `data:` lines).
**Warning signs:** Trying to instantiate `new EventSource()` with a POST body.

### Pitfall 6: Backend Python Version Compatibility
**What goes wrong:** pywebpush requires Python >= 3.10.
**Why it happens:** The DigitalOcean server runs Python 3.9 (from STATE.md: FastAPI 0.128.8 chosen for Python 3.9 compat).
**How to avoid:** Check Python version on server. If 3.9, use `py_vapid` + `http_ece` directly (pywebpush's dependencies) or upgrade Python. Alternative: use the `webpush` package (different from pywebpush) which may have broader compatibility. **This needs validation before planning.**
**Warning signs:** Import errors on `pywebpush` on the server.

## Code Examples

### PWA Manifest (Next.js 15 native)
```typescript
// Source: https://nextjs.org/docs/app/guides/progressive-web-apps
// app/manifest.ts
import type { MetadataRoute } from 'next'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Erestor',
    short_name: 'Erestor',
    description: 'Personal intelligence assistant',
    start_url: '/',
    display: 'standalone',
    background_color: '#1a1816',  // DS.bg
    theme_color: '#1e1c1a',      // DS.surface
    icons: [
      { src: '/icon-192x192.png', sizes: '192x192', type: 'image/png' },
      { src: '/icon-512x512.png', sizes: '512x512', type: 'image/png' },
    ],
  }
}
```

### Service Worker for Push Only
```javascript
// Source: https://nextjs.org/docs/app/guides/progressive-web-apps + MDN
// public/sw.js
self.addEventListener('push', function (event) {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.body,
    icon: '/icon-192x192.png',
    badge: '/badge.png',
    tag: data.tag || 'erestor',
    data: data.payload || {},
    vibrate: [100, 50, 100],
  };

  // Add action buttons if supported (Chrome/Android)
  if (data.actions) {
    options.actions = data.actions;
  }

  event.waitUntil(
    self.registration.showNotification(data.title || 'Erestor', options)
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  const action = event.action;
  const payload = event.notification.data;

  if (action && payload.poll_id) {
    // Action button clicked -- respond to poll via API
    event.waitUntil(
      fetch(`${self.location.origin}/api/poll-respond`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          poll_id: payload.poll_id,
          value: action,
        }),
      }).then(() => {
        return clients.openWindow('/');
      })
    );
  } else {
    // Notification body clicked -- open/focus the PWA
    event.waitUntil(
      clients.matchAll({ type: 'window' }).then((windowClients) => {
        for (const client of windowClients) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            return client.focus();
          }
        }
        return clients.openWindow('/');
      })
    );
  }
});
```

### Backend Web Push Router (new)
```python
# Source: pywebpush docs + existing events.py APNs pattern
# api/routers/webpush.py
import json
import logging
from pathlib import Path
from typing import Dict, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from api.deps import verify_token
from api.schemas import ApiResponse

router = APIRouter(dependencies=[Depends(verify_token)])
_logger = logging.getLogger("erestor.webpush")

_DEVICES_PATH = Path.home() / "claude-sync" / "produtividade" / "erestor" / "data" / "devices.json"


class WebPushSubscription(BaseModel):
    endpoint: str
    keys: Dict[str, str]  # auth + p256dh


@router.post("/webpush/subscribe", response_model=ApiResponse)
async def subscribe(sub: WebPushSubscription):
    """Register a web push subscription."""
    data = _load_devices()
    web_subs = data.setdefault("web", [])
    # Deduplicate by endpoint
    web_subs = [s for s in web_subs if s["endpoint"] != sub.endpoint]
    web_subs.append(sub.dict())
    data["web"] = web_subs
    _save_devices(data)
    return ApiResponse(data={"subscribed": True})


@router.delete("/webpush/subscribe", response_model=ApiResponse)
async def unsubscribe(sub: WebPushSubscription):
    """Remove a web push subscription."""
    data = _load_devices()
    web_subs = data.get("web", [])
    data["web"] = [s for s in web_subs if s["endpoint"] != sub.endpoint]
    _save_devices(data)
    return ApiResponse(data={"unsubscribed": True})
```

### Responsive Layout Pattern
```typescript
// Mobile-first with desktop breakpoint
// Use Tailwind's md: breakpoint (768px)

// MobileLayout: bottom tab bar, single content area
// DesktopLayout: sidebar (painel) + main content (chat) side by side

function AppShell() {
  return (
    <>
      {/* Mobile: bottom tabs */}
      <div className="md:hidden h-screen flex flex-col">
        <main className="flex-1 overflow-auto">{activeTab}</main>
        <nav className="flex border-t border-[var(--ds-border)]">
          {tabs.map(tab => <TabButton key={tab.id} />)}
        </nav>
      </div>

      {/* Desktop: sidebar layout */}
      <div className="hidden md:flex h-screen">
        <aside className="w-[360px] border-r border-[var(--ds-border)] overflow-auto">
          <PainelTab />
        </aside>
        <main className="flex-1 flex flex-col">
          <ChatTab />
        </main>
      </div>
    </>
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| next-pwa package | Next.js native manifest.ts | Fall 2024 | No third-party dependency needed for basic PWA |
| aesgcm Web Push encoding | aes128gcm (RFC 8188) | 2018+ | pywebpush defaults to aes128gcm, correct choice |
| web-push npm for Node.js | pywebpush for Python | N/A | Backend is Python/FastAPI, use pywebpush directly |
| Polling for real-time | SSE via EventSource | Already implemented | Backend already has SSE -- just connect from browser |

**Deprecated/outdated:**
- `next-pwa` (original by @nicedayfor): unmaintained, do not use
- `aesgcm` content encoding: deprecated in favor of `aes128gcm`
- Firebase Cloud Messaging for Web Push: not needed with VAPID self-hosted

## Open Questions

1. **Python version on DigitalOcean server**
   - What we know: Phase 1 chose FastAPI 0.128.8 for Python 3.9 compatibility
   - What's unclear: Has Python been upgraded since? pywebpush requires >= 3.10
   - Recommendation: Check `python3 --version` on DO server before planning. If 3.9, either upgrade Python or use lower-level `py_vapid` + `http_ece` libraries. This is a LOW confidence item that must be validated.

2. **EventSource auth strategy**
   - What we know: Native EventSource does not support custom headers. Backend uses `verify_token` dependency.
   - What's unclear: Whether to use query param, cookie, or polyfill
   - Recommendation: Query parameter `?token=xxx` is simplest for single-user app. Backend already allows all origins via CORS. May need to add query param support to `verify_token` dependency.

3. **Nginx configuration for Next.js**
   - What we know: Backend runs on DO with PM2 + Nginx. Next.js needs its own process.
   - What's unclear: Exact Nginx config (subdomain vs path prefix)
   - Recommendation: Use subdomain `web.erestor.domain` or path prefix `/web/`. Subdomain is cleaner for PWA (manifest scope).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Vitest + React Testing Library |
| Config file | `web/vitest.config.ts` (Wave 0) |
| Quick run command | `cd web && npx vitest run --reporter=verbose` |
| Full suite command | `cd web && npx vitest run` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WEB-01 | Panel shows event, timer, tasks, next event | unit | `npx vitest run src/__tests__/panel.test.tsx -t "panel"` | Wave 0 |
| WEB-01 | SSE connects and updates context store | unit | `npx vitest run src/__tests__/sse.test.ts -t "sse"` | Wave 0 |
| WEB-01 | Manifest is valid and installable | unit | `npx vitest run src/__tests__/manifest.test.ts` | Wave 0 |
| WEB-02 | Chat sends message and streams response | unit | `npx vitest run src/__tests__/chat.test.tsx -t "chat"` | Wave 0 |
| WEB-03 | Push subscription registers with backend | unit | `npx vitest run src/__tests__/push.test.ts -t "push"` | Wave 0 |
| NOTF-03 | Backend sends web push to subscriptions | unit (pytest) | `pytest tests/test_webpush.py -x` | Wave 0 |

### Sampling Rate
- **Per task commit:** `cd web && npx vitest run --reporter=verbose`
- **Per wave merge:** Full suite (web + backend tests)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `web/vitest.config.ts` -- Vitest configuration for Next.js
- [ ] `web/src/__tests__/` -- Test directory structure
- [ ] `tests/test_webpush.py` -- Backend web push router tests
- [ ] Framework install: `npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom`

## Sources

### Primary (HIGH confidence)
- [Next.js PWA Guide](https://nextjs.org/docs/app/guides/progressive-web-apps) - Full PWA setup including manifest, service worker, web push, VAPID keys
- [MDN EventSource](https://developer.mozilla.org/en-US/docs/Web/API/EventSource) - SSE API, auto-reconnection, limitations
- [MDN ServiceWorkerRegistration.showNotification](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification) - Notification options including actions
- [MDN NotificationEvent.action](https://developer.mozilla.org/en-US/docs/Web/API/NotificationEvent/action) - Action button handling in service worker
- DesignSystem.swift (local) - Exact color hex values and font names

### Secondary (MEDIUM confidence)
- [pywebpush GitHub](https://github.com/web-push-libs/pywebpush) - Python Web Push library docs, VAPID usage
- [react-markdown GitHub](https://github.com/remarkjs/react-markdown) - Markdown component for React
- [web.dev Push Notifications](https://web.dev/articles/push-notifications-web-push-protocol) - Web Push protocol details

### Tertiary (LOW confidence)
- Python 3.9 compatibility with pywebpush -- needs server validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Next.js 15 PWA is officially documented by Vercel, all libraries are well-established
- Architecture: HIGH - Pattern matches existing iOS/macOS clients, API contract is stable and documented
- Pitfalls: HIGH - EventSource limitations and iOS push restrictions are well-documented
- Web Push backend: MEDIUM - pywebpush Python version requirement needs server validation

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (stable technologies, 30-day validity)
