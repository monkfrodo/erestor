# Erestor Desktop App -- Documentacao

## Visao geral

App nativo macOS como segunda interface do Erestor. Telegram = mobile, App = desktop. Mesmo cerebro, mesma memoria, mesma personalidade. Duas portas de entrada.

O app roda na menu bar (LSUIElement = true no Info.plist), sem icone no Dock. Atalho global Cmd+Shift+E traz a janela de qualquer app. A UI principal e uma WebView com visual terminal-style (monospace, fundo escuro, prompt `~$`).

## Proxima evolucao — Floating Bubble

Refatorar a UI para um icone flutuante arrastavel pela tela:

1. **Bubble (estado colapsado):** NSPanel .floating, always on top, arrastavel, icone do Erestor ~48x48px
2. **Chat (estado expandido):** Clica na bubble → expande pra janela de chat compacta (~400x500) ancorada na posicao da bubble
3. **Colapsar:** Clica fora, Escape, ou botao de minimizar → volta pra bubble
4. **Cmd+Shift+E:** Se colapsado, expande. Se expandido, foca.
5. **Drag:** Arrastar a bubble move ela pela tela. Posicao persiste entre sessoes (@AppStorage).
6. **Menu bar:** Manter como fallback/status, mas a interacao principal e pela bubble.

Implementacao:
- `FloatingBubblePanel.swift` — NSPanel subclass com .floating level, draggable
- `BubbleViewController.swift` — gerencia estados colapsado/expandido
- Reutilizar ChatWebViewVC existente dentro do painel expandido
- Animacao de expansao/colapsamento (spring animation)

## Arquitetura

```
Backend (localhost:8766)              App Swift (SwiftUI + WebView)
erestor_local.py                      ErestorApp
  POST /chat                            ChatWebViewVC (WKWebView + chat.html)
  POST /chat/stream (SSE)               ChatService (URLSession + SSE streaming)
  GET  /context                          ActionHandler (notificacoes, terminal, URLs)
  GET  /status                           GlobalHotkey (Carbon, Cmd+Shift+E)
  GET  /briefing                         MenuBarView (quick input + status)
  POST /reset
```

O backend e o app sao processos independentes. O backend roda como LaunchAgent (Python), o app tambem. Comunicacao exclusivamente via HTTP em localhost.

## Backend -- erestor_local.py

**Caminho:** `~/claude-sync/produtividade/erestor_local.py`

Servidor HTTP em `localhost:8766` usando `http.server` com `ThreadingMixIn`. Reutiliza os modulos do `erestor/` (memoria, snapshot, GCal, soul.md). Nao modifica nem conflita com o bot Telegram (porta 8765, historico separado, locks separados).

### Dados separados

- Historico de conversa: `conversation_history_local.json` (max 10 pares, auto-reset apos 2h sem atividade)
- Logs diarios: `logs/app-YYYY-MM-DD.md`
- Cache de contexto (snapshot + GCal): 2 minutos de TTL

### Endpoints

#### POST /chat

Request:
```json
{"message": "texto", "quick": false}
```

Response:
```json
{
  "response": "texto limpo (sem action markers)",
  "timestamp": "HH:MM",
  "actions": [{"type": "reminder", "text": "...", "at": "HH:MM"}]
}
```

Fluxo:
1. Carrega contexto (snapshot + GCal, cached 2min)
2. Carrega historico local (conversation_history_local.json)
3. Monta prompt com `prompt_resposta_app()` (soul.md + memoria + snapshot + GCal + historico)
4. Chama `claude --print` (timeout 90s normal, 30s quick; effort normal/low)
5. Faz parse de actions no formato `[ACTION:tipo|param=valor]`
6. Salva historico (texto limpo, sem action markers)
7. Retorna response + actions

Se `quick=true`, usa prompt compacto (sem soul, snapshot truncado, effort low).

#### POST /chat/stream

Request: mesmo formato do `/chat`.

Response: SSE (Server-Sent Events). Cada linha:
```
data: {"text": "token chunk"}
```

Evento final:
```
data: {"done": true, "full_response": "texto completo limpo", "actions": [...]}
```

Evento de erro:
```
data: {"error": "mensagem"}
```

O streaming usa `subprocess.Popen` com `claude --print --no-session-persistence --effort <level>`, lendo stdout linha a linha. Cada linha e enviada como chunk SSE. ANSI escape codes sao removidos antes do envio.

#### GET /context

Response:
```json
{
  "snapshot": "texto do snapshot (max 2000 chars)",
  "gcal": "AGENDA REAL DO DIA (Google Calendar):\n- 09:00-10:00: Evento",
  "timer": {"type": "work", "desc": "descricao", "minutes": 45},
  "timestamp": "07/03/2026 14:30 BRT",
  "p1_tasks": ["Tarefa 1", "Tarefa 2"],
  "next_event": {"title": "Mentoria", "start": "2026-03-07T15:00:00-03:00", "end": "..."},
  "briefing": "texto do /tmp/erestor_context.txt"
}
```

Timer ativo e detectado via arquivos `~/.work_timer`, `~/.content_timer`, `~/.ocio_timer`. Tarefas P1 sao extraidas do `TASKS.md` (secao Active). Proximo evento vem do GCal (primeiro evento futuro do dia).

#### GET /status

Response:
```json
{
  "status": "running",
  "uptime_minutes": 120,
  "port": 8766
}
```

#### GET /briefing

Response:
```json
{
  "briefing": "texto do briefing",
  "source": "cached" | "live",
  "timestamp": "07/03/2026 14:30 BRT"
}
```

Se `/tmp/erestor_context.txt` existe e e de hoje, retorna o cached. Caso contrario, constroi um briefing live com GCal + P1s + timer ativo.

#### POST /reset

Apaga `conversation_history_local.json`. Response:
```json
{"status": "history cleared"}
```

### Actions

O Claude retorna actions inline no formato `[ACTION:tipo|param=valor|param2=valor2]`. O backend faz parse via regex e retorna como JSON estruturado. O app Swift executa:

| Tipo | Parametros | Efeito |
|------|-----------|--------|
| `reminder` | `text`, `at` (HH:MM, opcional) | Notificacao nativa macOS via UNUserNotificationCenter. Se `at` definido, agenda para o horario. Se nao, entrega em 5 segundos. |
| `open_project` | `path` (ex: `~/projetos/blackout`) | Abre Terminal.app via AppleScript, executa `cd <path> && claude`. |
| `open_url` | `url` | Abre no browser padrao via `NSWorkspace.shared.open()`. |

## App Swift -- estrutura

```
ErestorApp/
  project.yml               -- config XcodeGen (gera o .xcodeproj)
  ErestorApp/
    ErestorApp.swift         -- entry point (@main), Window + MenuBarExtra
    Info.plist               -- ATS localhost, LSUIElement
    ErestorApp.entitlements  -- entitlements (vazio, ad-hoc signing)
    Services/
      ChatService.swift      -- HTTP + SSE streaming (URLSession)
      ActionHandler.swift    -- executa actions (notificacoes, terminal, URLs)
      GlobalHotkey.swift     -- Cmd+Shift+E via Carbon RegisterEventHotKey
    Views/
      ChatWebViewVC.swift    -- WKWebView bridge (NSViewControllerRepresentable)
      ChatView.swift         -- SwiftUI chat nativo (backup, nao usado)
      MenuBarView.swift      -- menu bar popover (quick input + status)
      ContentView.swift      -- layout com sidebar (backup, nao usado)
      SidebarView.swift      -- sidebar terminal-style (backup, nao usado)
    Models/
      Message.swift          -- ChatMessage, ContextSummary, ChatAction
    Helpers/
      TransparentWindow.swift -- modifier para janela transparente sem titlebar
    Extensions/
      Color+Hex.swift        -- Color(hex:) initializer
    Resources/
      chat.html              -- UI do chat (HTML/CSS/JS, terminal-style)
      icon.png               -- icone do app
```

### ErestorApp.swift (entry point)

Define duas scenes:
1. **Window("Erestor", id: "main")** -- janela principal com `ChatWebViewVC`, tamanho 480x680, `hiddenTitleBar`, fundo transparente
2. **MenuBarExtra** -- icone na menu bar (`brain.head.profile`), estilo `.window`, mostra `MenuBarView`

No `.task`:
- Carrega contexto (`chatService.loadContext()`)
- Registra global hotkey (Cmd+Shift+E) que ativa a janela principal

No `.onReceive(chatService.$actions)`:
- Quando o ChatService recebe actions do backend, repassa para o `ActionHandler.execute()`

### ChatService.swift

`ObservableObject` com propriedades publicadas:
- `messages: [ChatMessage]` -- historico da conversa
- `isLoading: Bool` -- indicador de carregamento
- `context: ContextSummary?` -- dados do `/context`
- `serverOnline: Bool` -- status do backend
- `actions: [ChatAction]` -- actions pendentes
- `isStreaming: Bool` + `streamDelta: StreamDelta?` -- estado de streaming

**sendMessageStreaming()** -- metodo principal. Faz POST em `/chat/stream`, le SSE via `URLSession.shared.bytes()`, publica cada chunk como `StreamDelta(.delta)`. Ao receber `done: true`, publica `StreamDelta(.finished)` com o texto completo.

**sendMessage()** -- fallback sem streaming. POST em `/chat`, recebe JSON completo.

**StreamDelta** -- struct com enum Kind (started, delta, finished) publicada para o WebView reagir a cada token.

Timestamps em BRT (America/Sao_Paulo).

### ChatWebViewVC.swift

`NSViewControllerRepresentable` que encapsula um `WKWebView` carregando `chat.html` do bundle.

Comunicacao JS -> Swift: via `webkit.messageHandlers.chat.postMessage({type: "send", text: "..."})`. O Coordinator implementa `WKScriptMessageHandler` e chama `chatService.sendMessageStreaming()`.

Comunicacao Swift -> JS: via `webView.evaluateJavaScript()`:
- `addMessage(role, text, timestamp)` -- adiciona mensagem renderizada
- `beginStream(timestamp)` -- cria container de streaming com cursor piscante
- `appendStreamChunk(text)` -- adiciona token ao streaming (re-renderiza markdown completo)
- `finalizeStream(fullText, timestamp)` -- finaliza streaming (remove cursor)
- `setLoading(bool)` -- indicador "pensando..."
- `clearMessages()` -- limpa tudo, mostra empty state

O Coordinator rastreia `renderedCount` e `streamFinishedMessageCount` para evitar duplicacao entre mensagens de streaming e mensagens finais adicionadas ao array.

### chat.html

UI terminal-style com:
- Fonte monospace (SF Mono / Menlo / Fira Code)
- Fundo transparente (o app tem fundo `#0a0a0c` com 95% opacidade)
- Prompt `~$` verde (`#4a9f68`)
- Mensagens do usuario com `>` verde, respostas com borda lateral
- Empty state com icone, nome "erestor", chips de capacidades
- Markdown basico: code blocks, inline code, bold, italic, line breaks
- Textarea auto-resize, Enter envia, Shift+Enter nova linha
- Cursor piscante durante streaming (`stream-cursor`)
- Scroll throttled com `requestAnimationFrame` durante streaming

### ActionHandler.swift

Singleton (`ActionHandler.shared`). No init, pede permissao de notificacoes.

- **scheduleReminder()** -- `UNUserNotificationCenter`, titulo "Erestor", som padrao. Se `at` fornecido (HH:MM), usa `UNCalendarNotificationTrigger` com timezone BRT. Senao, `UNTimeIntervalNotificationTrigger` de 5 segundos.
- **openProject()** -- expande `~`, executa AppleScript que abre Terminal.app com `cd <path> && claude`.
- **openURL()** -- `NSWorkspace.shared.open(url)`.

### GlobalHotkey.swift

Singleton. Usa Carbon API (`RegisterEventHotKey`):
- Key code: `kVK_ANSI_E` (14)
- Modifiers: `cmdKey | shiftKey`
- Signature: `0x45525354` ("ERST")
- Handler: `InstallEventHandler` com `kEventClassKeyboard` / `kEventHotKeyPressed`

Nao precisa de permissao de Acessibilidade. Carbon API e deprecated mas funcional em macOS 26.

### MenuBarView.swift

Popover da menu bar com:
- Indicador de status (circulo verde/vermelho + "Online"/"Offline")
- Timer ativo (se houver)
- Campo de mensagem rapida (usa `sendMessage()`, nao streaming)
- Ultima resposta do assistente (4 linhas max)
- Botao "Abrir Erestor" (abre a janela principal)

### Models/Message.swift

- **ChatMessage** -- `id: UUID`, `role: .user | .assistant`, `text: String`, `timestamp: String`
- **ContextSummary** -- `Codable`, campos: `snapshot`, `gcal`, `timer: TimerInfo?`, `timestamp`, `p1Tasks: [String]?`, `nextEvent: NextEvent?`, `briefing`
- **ChatAction** -- `Codable`, `Identifiable`, campos: `type`, `text?`, `at?`, `path?`, `url?`

### Helpers e Extensions

- **TransparentWindow.swift** -- `ViewModifier` + `NSViewRepresentable` que configura a janela como transparente (`isOpaque = false`, `backgroundColor = .clear`, titlebar escondida)
- **Color+Hex.swift** -- `Color(hex:)` que converte string hex para Color

### Views backup (nao usadas no layout atual)

- **ChatView.swift** -- chat SwiftUI nativo com bubbles (material design), AttributedString para markdown. Usa streaming. Mantido como alternativa ao WebView.
- **ContentView.swift** -- layout com HSplitView (SidebarView + ChatWebViewVC). Backup.
- **SidebarView.swift** -- sidebar terminal-style com timer ativo, proximo evento, P1 tasks, agenda, atalhos rapidos (briefing/tarefas/agenda/status), botoes clear/sync. Removida do layout ativo.

## Setup -- como rodar

### Pre-requisitos

- macOS 26+ (Tahoe)
- Xcode 16+
- xcodegen (`brew install xcodegen`)
- Claude CLI instalado e funcional (`claude --print` funciona)
- erestor_local.py rodando em localhost:8766

### Build

```bash
cd ~/projetos/erestor/ErestorApp
xcodegen generate
xcodebuild -project ErestorApp.xcodeproj -scheme ErestorApp -configuration Debug -derivedDataPath build/DerivedData build
cp -R build/DerivedData/Build/Products/Debug/ErestorApp.app build/ErestorApp.app
```

O `project.yml` define:
- Bundle ID: `org.integros.erestor`
- Deployment target: macOS 26.0
- Swift 5.9
- Dependency: Carbon.framework
- Code signing: ad-hoc (`CODE_SIGN_IDENTITY: "-"`)
- LSUIElement: true (sem Dock icon)
- ATS: NSAllowsLocalNetworking = true

### LaunchAgents

Dois LaunchAgents necessarios:

**com.erestor.local-server** -- servidor Python. Ja configurado em `~/claude-sync/produtividade/setup-agents.sh`.

**com.erestor.app** -- abre o app no login. Precisa apontar para o path correto do ErestorApp.app.

```bash
# Carregar os agents
launchctl load ~/Library/LaunchAgents/com.erestor.local-server.plist
launchctl load ~/Library/LaunchAgents/com.erestor.app.plist
```

### Setup em maquina nova

1. Clone o repo: `git clone <url> ~/projetos/erestor`
2. Garantir que `~/claude-sync/produtividade/` existe e tem o `erestor_local.py`
3. Build o app (comandos acima)
4. Gerar/ajustar LaunchAgents com paths corretos:
   - Ajustar `$HOME` em `com.erestor.app.plist`
   - Ajustar `$HOME` e caminho do Python em `com.erestor.local-server.plist`
5. `launchctl load` em ambos
6. Testar: `curl http://127.0.0.1:8766/status` deve retornar JSON

### Permissoes necessarias

- **Notificacoes:** prompt automatico na primeira execucao (UNUserNotificationCenter). Precisa aceitar.
- **Automacao Terminal:** prompt na primeira vez que "Abrir projeto" for usado (AppleScript para Terminal.app).
- **Global hotkey:** nao precisa de permissao. Carbon API funciona sem Accessibility.

## Notas tecnicas

- **ATS:** `NSAllowsLocalNetworking=true` no Info.plist permite requests HTTP para localhost sem bloqueio.
- **Non-sandboxed:** app nao e sandboxed (entitlements vazio, ad-hoc signing). Necessario para AppleScript, notificacoes e acesso ao filesystem.
- **Carbon hotkey:** API deprecated mas funcional em macOS 26. Alternativa moderna seria `CGEvent` + permissao de Accessibility, que seria pior UX.
- **WebView bridge:** JS usa `webkit.messageHandlers.chat` para enviar mensagens. Swift usa `evaluateJavaScript()` para injetar dados. Sem framework de bridge -- comunicacao manual.
- **Streaming:** SSE do backend e processado via `URLSession.shared.bytes()` (async). Cada chunk e publicado como `StreamDelta` e o WebView re-renderiza o markdown completo a cada token (com cursor piscante). Scroll e throttled via `requestAnimationFrame` para evitar layout thrashing.
- **Historico:** nao ha persistencia local no app. O array de `ChatMessage` vive em memoria. O historico persistente fica no backend (`conversation_history_local.json`, max 10 pares, reset apos 2h).
- **Developer extras:** `WKWebView` tem `developerExtrasEnabled = true`, entao Web Inspector funciona para debug do chat.html.
