# Erestor

## O que e

Assistente pessoal inteligente do Kevin — sistema cross-platform (macOS, iOS, web) que coleta dados do dia (calendario, energia, foco, tarefas, habitos) e retorna insights acionaveis, alertas proativos e sinteses diarias. Substituiu o bot do Telegram por interfaces nativas em todas as plataformas. O nome vem do conselheiro de Elrond em O Senhor dos Aneis.

**v1.0 entregue em 2026-03-10** — 18 planos em 6 fases, 1.33 horas de execucao total.

## Stack

### Backend (vive em `~/claude-sync/produtividade/`, NAO neste repo)
- **Framework:** FastAPI (Python 3.9+)
- **Servidor:** DigitalOcean (PM2 + Nginx + SSL)
- **LLM:** Claude API (Anthropic SDK, streaming)
- **Banco:** SQLite (`erestor_events.db`)
- **Endpoints:** 12 routers REST + SSE (auth, context, chat, calendar, events, polls, synthesis, insights, timer, history, device, webpush)

### macOS App (neste repo: `ErestorApp/`)
- **Linguagem:** Swift 5.9
- **UI:** SwiftUI + AppKit (NSPanel floating window)
- **Build:** XcodeGen (`project.yml`) + Xcode 16+
- **Hotkey:** Cmd+Shift+E (Carbon framework)
- **Chat:** MarkdownUI para rendering
- **Notificacoes:** UserNotifications (local + actionable)
- **Zero dependencias externas** — so frameworks Apple

### iOS App (neste repo: `ErestorApp/iOS/`)
- **UI:** SwiftUI (TabView: Painel, Chat, Agenda, Insights)
- **Push:** APNs (device token registration)
- **Charts:** Swift Charts para insights

### Web PWA (neste repo: `web/`)
- **Framework:** Next.js 15 + React 19
- **Estado:** Zustand
- **Estilo:** Tailwind CSS v4
- **Chat:** react-markdown + rehype-highlight
- **Push:** Web Push API + Service Worker
- **Testes:** Vitest + Testing Library

### Design
- **Tema:** Vesper Dark (escuro, minimal, contextual)
- **Fontes:** IBM Plex Mono + Inter
- **Cores:** Design system via `DS` enum (Swift) e CSS vars (web)

## Como usar

### Build macOS
```bash
cd ErestorApp
xcodegen generate
xcodebuild -project ErestorApp.xcodeproj -scheme ErestorApp -configuration Debug build
```

### Build web
```bash
cd web
npm install
npm run dev          # Dev server
npm run build        # Producao
npm test             # Testes
```

### Credenciais necessarias
| Arquivo | Conteudo |
|---------|----------|
| `~/.erestor_telegram` | JSON com `token` e `chat_id` |
| `~/.gcal_credentials` | JSON OAuth com `client_id`, `client_secret`, `refresh_token` |
| `web/.env` | `NEXT_PUBLIC_API_URL` e `NEXT_PUBLIC_API_TOKEN` (ver `.env.example`) |

### Workflow de mudancas no codigo do backend
```bash
# 1. Ler regras tecnicas
cat ~/claude-sync/produtividade/memory/regras-tecnicas.md

# 2. Fazer mudanca em ~/claude-sync/produtividade/
# 3. Verificar: python3 ~/claude-sync/produtividade/erestor-check.py
# 4. Commit no repo ~/claude-sync/ (nao aqui)
```

## Estrutura de Arquivos

```
erestor/
├── ErestorApp/                         # Swift app (macOS + iOS)
│   ├── project.yml                     # XcodeGen project spec (2 targets)
│   ├── ErestorApp.xcodeproj/           # Xcode project gerado
│   └── ErestorApp/
│       ├── ErestorApp.swift            # macOS entry: @main, AppDelegate,
│       │                               # MenuBarExtra, notification categories
│       ├── Info.plist                   # macOS: LSUIElement, ATS, AppleEvents
│       ├── ErestorApp.entitlements      # macOS entitlements
│       ├── Assets.xcassets/            # macOS: AppIcon, MenuBarIcon
│       ├── Extensions/
│       │   └── Color+Hex.swift         # Color init from hex string
│       ├── Models/
│       │   ├── Message.swift           # ChatMessage, ContextSummary, ChatAction,
│       │   │                           # PushEvent, GCalEvent, TaskItem (~156 linhas)
│       │   └── SSEEvent.swift          # Server-Sent Events model
│       ├── Services/
│       │   ├── ChatService.swift       # API client: REST, SSE streaming, context
│       │   │                           # polling, push, status (~principal service)
│       │   ├── BubbleWindowController.swift  # Floating bubble + chat panel (NSPanel)
│       │   ├── ActionHandler.swift     # 19+ action types: AppleScript, shell,
│       │   │                           # clipboard, URLs, Music, iTerm, etc.
│       │   ├── ErestorConfig.swift     # API base URL + auth token + path constants
│       │   └── GlobalHotkey.swift      # Cmd+Shift+E via Carbon RegisterEventHotKey
│       ├── Views/
│       │   ├── ContextPanelView.swift  # Main panel layout (header, events, tasks, chat)
│       │   ├── DesignSystem.swift      # DS enum: Vesper Dark colors + font helpers
│       │   ├── ChatHistoryView.swift   # Historico de mensagens
│       │   ├── ChatInputView.swift     # Input de chat com envio
│       │   ├── ChatMessageView.swift   # Renderizacao de mensagem individual
│       │   ├── CollapsibleTasksView.swift  # Lista de tarefas colapsavel
│       │   ├── DayTimelineView.swift   # Timeline visual do dia
│       │   ├── EventCardView.swift     # Card de evento do calendario
│       │   ├── GateAlertView.swift     # Alerta de "gate" (decisao importante)
│       │   ├── NextEventView.swift     # Proximo evento com timer
│       │   ├── PollCardView.swift      # Card de poll (energia, qualidade)
│       │   ├── TaskListView.swift      # Lista de tarefas
│       │   ├── TimerChipView.swift     # Chip de timer ativo
│       │   ├── iOS_AgendaView.swift    # Agenda iOS (hoje)
│       │   ├── iOS_EventDetailSheet.swift  # Detalhes de evento iOS
│       │   ├── iOS_GateSheetView.swift # Sheet de gate iOS
│       │   ├── iOS_InsightsView.swift  # Insights iOS com Swift Charts
│       │   ├── iOS_PainelView.swift    # Painel principal iOS
│       │   ├── iOS_PollSheetView.swift # Sheet de poll iOS
│       │   └── iOS_TabRootView.swift   # TabView raiz iOS (4 tabs)
│       ├── Resources/
│       │   └── icon.png               # Icone da floating bubble
│       └── iOS/
│           ├── ErestorApp_iOS.swift    # iOS entry: @main, AppDelegate_iOS, APNs
│           ├── Info.plist              # iOS config
│           ├── ErestorApp_iOS.entitlements  # APNs entitlements
│           └── Assets.xcassets/        # iOS AppIcon
├── web/                               # Next.js 15 PWA
│   ├── package.json                   # Next 15, React 19, Zustand, Tailwind v4
│   ├── next.config.ts                 # Config Next.js
│   ├── tsconfig.json                  # TypeScript config
│   ├── vitest.config.ts               # Config de testes
│   ├── postcss.config.mjs             # PostCSS para Tailwind
│   ├── .env.example                   # Variaveis necessarias
│   ├── public/
│   │   ├── sw.js                      # Service worker (push only, sem offline)
│   │   ├── icon-192x192.png           # PWA icon
│   │   └── icon-512x512.png           # PWA icon
│   └── src/
│       ├── app/
│       │   ├── layout.tsx             # Layout root + SW registrar
│       │   ├── page.tsx               # Pagina principal
│       │   ├── globals.css            # Vesper Dark theme + Tailwind v4
│       │   ├── manifest.ts            # PWA manifest
│       │   ├── sw-registrar.tsx       # Registra Service Worker
│       │   └── api/poll-respond/route.ts  # API route para resposta de poll
│       ├── components/
│       │   ├── chat/                  # ChatInput, ChatMessage
│       │   ├── layout/               # DesktopLayout, MobileLayout
│       │   ├── modals/               # GateModal, PollModal
│       │   ├── panel/                # EventCard, NextEvent, TaskList, TimerChip
│       │   └── tabs/                 # AgendaTab, ChatTab, InsightsTab, PainelTab
│       ├── lib/
│       │   └── ds.ts                 # Design system tokens (cores, fontes)
│       ├── services/
│       │   ├── api.ts                # Fetch helpers para API
│       │   ├── chat.ts               # Chat streaming via ReadableStream
│       │   ├── push.ts               # Web Push registration
│       │   └── sse.ts                # SSE connection + reconnect
│       ├── stores/
│       │   ├── chatStore.ts          # Zustand store para chat
│       │   ├── contextStore.ts       # Zustand store para contexto
│       │   └── pollStore.ts          # Zustand store para polls
│       └── __tests__/                # Testes Vitest (chat, manifest, panel, push, sse)
├── .planning/                        # Documentacao GSD (planejamento estruturado)
│   ├── PROJECT.md                    # Definicao do projeto, requisitos, decisoes
│   ├── STATE.md                      # Estado atual: v1.0 completo, 18/18 planos
│   ├── ROADMAP.md                    # Roadmap: 6 fases completas
│   ├── MILESTONES.md                 # Marcos do projeto
│   ├── config.json                   # Config GSD
│   ├── research/                     # Pesquisa inicial (arquitetura, features, stack)
│   ├── milestones/                   # v1.0 requirements, roadmap, audit
│   ├── phases/
│   │   ├── 01-api-foundation/       # FastAPI + 12 routers (2 planos)
│   │   ├── 02-macos-experience/     # SwiftUI panel + streaming chat (6 planos)
│   │   ├── 03-ios-data-migration/   # iOS app + SQLite migration (5 planos)
│   │   ├── 04-web-pwa/              # Next.js PWA + web push (3 planos)
│   │   ├── 05-api-gaps-swift-migration/ # API gaps + legacy cleanup (1 plano)
│   │   └── 06-insights-web-fixes/   # Insights data + web SSE (1 plano)
│   └── codebase/                     # Analise do codebase (stack, structure, etc.)
├── docs/
│   ├── architecture.md               # Diagrama e fluxos do sistema
│   ├── technical-decisions.md        # Log de decisoes tecnicas
│   ├── native-app-plan.md           # Planejamento do app nativo
│   └── update-protocol.md           # Quando/como atualizar docs
├── prototipo-painel.html            # Prototipo HTML do painel (referencia visual)
├── DEPLOY-GUIDE.md                  # Guia de deploy
├── README.md                        # Visao geral do projeto
├── .gitignore                       # Build, node_modules, .env
└── CLAUDE.md                        # Este arquivo
```

## Regras de Desenvolvimento

### FAZER
- Commits em portugues, conventional commits
- Ler `~/claude-sync/produtividade/memory/regras-tecnicas.md` antes de qualquer mudanca no backend
- Rodar `erestor-check.py` apos correcoes
- Usar `DS` enum para cores/fontes em Swift
- Usar CSS vars do design system no web
- Seguir padrao two-target: `#if os(macOS)` / `#if os(iOS)` para codigo compartilhado
- Novos models em `Models/Message.swift` (arquivo unico)
- Novos services em `Services/` com `@MainActor class` + `os.Logger`

### NAO FAZER
- Nunca incluir `Co-Authored-By` nos commits
- Nunca editar `~/claude-sync/produtividade/` a partir deste repo — abrir Claude Code la
- Nunca usar paths legados `/api/` — sempre `/v1/`
- Nunca hardcodar paths — usar `$HOME` (bash) ou `os.path.expanduser` (Python)
- Nunca editar `~/.config/fish/config.fish` diretamente — editar `~/dotfiles/config.fish`
- Nunca colocar `claude remote-control` na funcao `erestor`
- Nunca criar codigo de producao neste repo para o backend — o backend vive em `~/claude-sync/produtividade/`

## Contexto

Erestor e o assistente pessoal do Kevin — ferramenta single-user que cruza dados do dia (Google Calendar, energia, foco, tarefas) para gerar insights sobre como ele gasta tempo e energia. Nao e um chatbot generico — e um sistema de inteligencia pessoal com contexto profundo.

### Arquitetura
- **Backend (DigitalOcean):** FastAPI + Claude API + SQLite. 12 routers, SSE streaming para chat e contexto em tempo real. Polls de energia (5 niveis) e qualidade de bloco (4 niveis). Sintese diaria as 22h. Agentes autonomos (morning/periodic/night).
- **macOS:** Floating bubble na tela (NSPanel), hotkey global Cmd+Shift+E, menu bar icon. Chat streaming com MarkdownUI. Notificacoes nativas para polls e gates.
- **iOS:** TabView com 4 tabs (Painel, Chat, Agenda, Insights). Swift Charts para graficos. APNs push para polls. Bottom sheets para polls/gates.
- **Web:** Next.js PWA responsiva. SSE para contexto real-time. Zustand para estado. Web Push para notificacoes. CSS-based charts (sem lib).

### Fonte da verdade do backend
O codigo do backend vive em `~/claude-sync/produtividade/`. Este repo (`~/projetos/erestor`) contem:
- App nativo (Swift) — macOS + iOS
- Web PWA (Next.js)
- Documentacao e planejamento (.planning/)
- Prototipos visuais

### Tech debt conhecida
- Verificacao visual humana pendente (15 itens em macOS/iOS/Web)
- SYNT-02 e API-05 nao tem UI de cliente (endpoints backend-only)
- iOS agenda mostra apenas eventos de hoje
- `ErestorApp.swift` tem dead code `/v1/push/respond`

## Arquivos Importantes

| Arquivo | Descricao |
|---------|-----------|
| `ErestorApp/ErestorApp/Services/ChatService.swift` | API client principal |
| `ErestorApp/ErestorApp/Services/ErestorConfig.swift` | URL base + auth + paths |
| `ErestorApp/ErestorApp/Views/DesignSystem.swift` | Vesper Dark design system |
| `ErestorApp/ErestorApp/Views/ContextPanelView.swift` | Layout principal do painel |
| `ErestorApp/ErestorApp/Models/Message.swift` | Todos os data models |
| `ErestorApp/project.yml` | XcodeGen project spec (2 targets) |
| `web/src/app/page.tsx` | Pagina principal web |
| `web/src/lib/ds.ts` | Design tokens web |
| `.planning/PROJECT.md` | Definicao completa do projeto |
| `.planning/STATE.md` | Estado atual (v1.0 completo) |

## Git

- **Branch:** main
- **Commits:** conventional commits em portugues
