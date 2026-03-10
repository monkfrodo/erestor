# Stack Research

**Domain:** Cross-platform personal intelligence assistant (macOS, iOS, web)
**Researched:** 2026-03-09
**Confidence:** MEDIUM-HIGH

## Recommended Stack

**Strategy: Native Apple + Web PWA (two codebases, shared API contract)**

SwiftUI native app for macOS and iOS (where native integration is critical), plus a Next.js PWA for web browser access. Both talk to the existing Python backend via the same REST + SSE API.

This is NOT a "write once run everywhere" approach. It is a "right tool for each platform" approach, chosen because the macOS experience requires deep system integration (menu bar, floating panel, global hotkey, Carbon framework) that no cross-platform framework handles well.

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|------------|---------|---------|-----------------|------------|
| Swift 6 | 6.0+ | macOS + iOS native app | Already in use, full access to AppKit/UIKit/Carbon. No cross-platform framework can replicate the floating bubble + global hotkey + NSPanel pattern. Swift 6 adds complete concurrency checking. | HIGH |
| SwiftUI | iOS 17+ / macOS 14+ | Shared UI components (context panel, polls, cards) | Already the UI layer for iOS and context panel. Mature enough in 2025-2026 for the panel UI. Keep AppKit for the bubble window controller. | HIGH |
| Next.js | 15.x | Web PWA for browser access | Kevin's standard stack. App Router + Route Handlers for SSE proxy. PWA mode for installability and push notifications on macOS Safari and iOS Safari. | HIGH |
| TypeScript | 5.x | Web app language | Type safety, Kevin's standard | HIGH |
| Tailwind CSS | 4.x | Web app styling | Kevin's standard, dark theme implementation is straightforward | HIGH |

### macOS-Specific Technologies

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| AppKit (NSPanel) | Floating bubble + chat panel windows | Required for the non-activating floating panel pattern. SwiftUI cannot create NSPanel-based windows that avoid focus stealing. Already proven in current codebase. | HIGH |
| Carbon (RegisterEventHotKey) | Global hotkey (Cmd+Shift+E) | Only reliable way to register system-wide hotkeys without Accessibility permissions on macOS. No cross-platform alternative exists. | HIGH |
| WKWebView + SwiftUI hybrid | Chat interface rendering | Current approach works. Chat HTML can be shared between web PWA and native WKWebView. Consider migrating to pure SwiftUI chat if complexity allows. | MEDIUM |
| UserNotifications | Native notifications with actions | Full support for notification categories, inline actions (poll responses, gate acknowledgments). Already implemented. | HIGH |
| Combine | Reactive state management | Already in use for stream observation. Works well with ObservableObject pattern. | HIGH |

### iOS-Specific Technologies

| Technology | Purpose | Why | Confidence |
|------------|---------|-----|------------|
| SwiftUI | Full app UI | iOS app is simpler (no bubble, no hotkey). Pure SwiftUI is the right choice. | HIGH |
| APNs (Apple Push Notification service) | Push notifications | Required for background notifications on iOS. Already set up with device token registration. | HIGH |
| WidgetKit | Lock screen / home screen widgets | Show current event, timer, next task without opening the app. High value for a contextual assistant. | MEDIUM |

### Web PWA Technologies

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| next-pwa-pack | latest | PWA wrapper for Next.js 15 | Service worker registration, caching, offline support. Built for Next.js 15 App Router. | MEDIUM |
| Web Push API | - | Browser push notifications | Works on macOS Safari 16+ (no install needed) and iOS Safari 16.4+ (requires Add to Home Screen). Covers the "web" notification gap. | HIGH |
| EventSource | native | SSE streaming for chat | Native browser API, no library needed. Matches the existing `/api/chat/stream` SSE endpoint. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-markdown-ui | 2.x | Markdown rendering in SwiftUI | Rendering Claude's markdown responses in native chat views (if migrating away from WKWebView chat) |
| Observation framework | iOS 17+ | Modern state management | Replace @Published/@ObservableObject with @Observable macro for cleaner code. iOS 17+ only. |
| KeychainAccess (SPM) | 4.x | Secure token storage | Replace hardcoded bearer token in ErestorConfig with Keychain storage |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| XcodeGen | Project file generation | Already in use. Keep it -- avoids xcodeproj merge conflicts. |
| Xcode 16+ | Build system | Required for Swift 6, SwiftUI latest |
| pnpm | Web package manager | Faster than npm, Kevin can adopt for the Next.js project |

## Installation

```bash
# macOS/iOS native app (no external dependencies currently)
cd ~/projetos/erestor/ErestorApp
xcodegen generate
xcodebuild -project ErestorApp.xcodeproj -scheme ErestorApp -configuration Debug build

# Web PWA (new project)
npx create-next-app@latest erestor-web --typescript --tailwind --app --src-dir
cd erestor-web
pnpm add next-pwa-pack
pnpm add -D @types/node
```

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| SwiftUI native (macOS + iOS) | **Tauri 2** (web frontend + Rust shell) | Tauri 2 iOS support is immature (developers report alpha-quality, not beta). Notification actions are mobile-only. Transparent floating windows on macOS have known bugs. Would require learning Rust for system integration. The floating bubble + Carbon hotkey pattern cannot be replicated. |
| SwiftUI native (macOS + iOS) | **React Native** (macOS + iOS + Web) | RN macOS is out-of-tree (Microsoft maintained), menu bar apps require hacky workarounds via `react-native-menubar-extra`. No Carbon hotkey support. No NSPanel floating window. Massive framework overhead for a single-user personal tool. |
| SwiftUI native (macOS + iOS) | **Electron** | 200MB+ binary for a menu bar utility. Absurd resource usage. No iOS support. |
| SwiftUI native (macOS + iOS) | **Flutter** | No macOS menu bar support. Dart ecosystem is smaller. No Carbon/AppKit interop without FFI complexity. |
| Next.js PWA (web) | **Standalone web app (no PWA)** | Loses push notifications on iOS (requires Add to Home Screen + PWA manifest). PWA is strictly better. |
| Next.js PWA (web) | **React SPA deployed on Vercel** | Could work, but PWA adds installability, offline caching, and push notifications for free. No reason not to use PWA. |
| Shared chat.html in WKWebView | **Pure SwiftUI chat** | The WKWebView approach allows sharing the chat UI between web and native. However, pure SwiftUI chat would be more maintainable long-term. Consider migrating in a later phase. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Tauri 2 for iOS | iOS support is immature -- developers report alpha quality despite "stable" label. Notification actions not supported on macOS. Apple App Store guidelines push back on web-wrapper apps. | Swift native for iOS |
| React Native for macOS | Out-of-tree platform, menu bar app support is community-maintained with sparse examples. Cannot replicate NSPanel, Carbon hotkey, or activation policy patterns. | Swift/AppKit native for macOS |
| Electron | 200MB+ binary, excessive RAM for a menu bar utility. No iOS. | Tauri 2 if you must go web-wrapper (but don't) |
| Firebase Cloud Messaging for push | Unnecessary dependency for a single-user app. APNs direct + Web Push API cover all needs. | APNs (native) + Web Push API (PWA) |
| WebSocket for real-time | Overkill for single-user. SSE is simpler, unidirectional (server-to-client), already implemented in the backend. | SSE (EventSource) |
| SwiftData / Core Data | No local database needed. All state lives on the server. The client is a thin UI layer. | Server-side state via REST API |

## Architecture Decision: Shared vs Separate Chat UI

The current codebase renders chat in WKWebView (`chat.html`) on macOS. Two options:

**Option 1: Shared HTML chat (current approach)**
- Same `chat.html` renders in WKWebView (macOS) and in the browser (web PWA)
- Pro: Single chat UI implementation, consistent rendering
- Con: JS bridge complexity, harder to debug, two rendering contexts

**Option 2: Native SwiftUI chat + Web chat (recommended for v2)**
- SwiftUI `ChatView` for macOS/iOS, React component for web
- Pro: Native feel, no WKWebView overhead, better accessibility
- Con: Two implementations to maintain

**Recommendation:** Start with shared HTML chat (faster to ship), migrate to native SwiftUI chat in a later phase when the API contract is stable.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| Swift 6 | Xcode 16+, macOS 14+ | Complete concurrency checking. Can still target macOS 14 deployment. |
| SwiftUI (iOS 17+) | Observation framework, WidgetKit | iOS 17 is the sweet spot -- @Observable macro, improved navigation |
| Next.js 15 | Tailwind CSS 4, next-pwa-pack | App Router is stable. Route Handlers for SSE. |
| Web Push API | Safari 16+ (macOS), Safari 16.4+ (iOS) | iOS requires PWA installed to Home Screen |

## Key Architectural Principle

The Python backend is the single source of truth. All clients (macOS, iOS, web) are thin UI layers that:
1. Poll `/api/context` for current state
2. Stream `/api/chat/stream` for chat via SSE
3. Poll `/api/push/pending` for server-initiated events
4. POST to action endpoints (`/api/timer`, `/api/gcal`, `/api/tasks`)

This means the three clients share zero code directly -- they share the API contract. This is intentional: each platform gets native UX without cross-platform compromise.

## Sources

- [Tauri 2 iOS feedback (GitHub Discussion #10197)](https://github.com/tauri-apps/tauri/discussions/10197) -- developers report alpha-quality iOS support
- [Tauri 2 Notification Plugin](https://v2.tauri.app/plugin/notification/) -- notification actions mobile-only
- [Tauri 2 System Tray](https://v2.tauri.app/learn/system-tray/) -- menu bar app support
- [React Native macOS (Microsoft)](https://github.com/microsoft/react-native-macos) -- out-of-tree platform status
- [react-native-menubar-extra](https://github.com/okwasniewski/react-native-menubar-extra) -- community menu bar support
- [Next.js PWA Guide](https://nextjs.org/docs/app/guides/progressive-web-apps) -- official PWA documentation
- [PWA Push Notifications on iOS](https://brainhub.eu/library/pwa-on-ios) -- iOS PWA limitations and requirements
- [WebKit for SwiftUI (WWDC 2025)](https://dev.to/arshtechpro/wwdc-2025-webkit-for-swiftui-2igc) -- new native WebView in iOS 26
- [SwiftUI Multiplatform (Apple)](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target) -- official multiplatform guidance

---
*Stack research for: Erestor cross-platform personal intelligence assistant*
*Researched: 2026-03-09*
