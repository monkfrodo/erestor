# Erestor Native macOS App — Plano

## Conceito

App nativo macOS como segunda interface do Erestor (Telegram = mobile, App = desktop).
Mesmo cérebro, mesma memória, mesma inteligência. Duas portas de entrada.

## Arquitetura

```
Servidor DO (PM2)              iMac/MacBook (local)
┌─────────────────┐           ┌──────────────────┐
│ erestor_bot.py  │           │ erestor_local.py  │  ← backend local (NOVO)
│ Telegram ↔ Bot  │           │ localhost:8766    │
└────────┬────────┘           └────────┬─────────┘
         │                             │
         │   ┌─────────────────┐       │
         └──▶│ mesmos arquivos  │◀──────┘
             │ (synced via git) │
             │ • memory/       │       ┌──────────┐
             │ • snapshot      │       │ App Swift │
             └─────────────────┘       │ (SwiftUI) │
                                       └──────────┘
```

### Zero conflito com o bot do Telegram:
- `erestor_local.py` é um servidor HTTP separado (não modifica erestor_bot.py)
- Lê os mesmos arquivos de contexto (memory/, snapshot, etc.)
- Chama `claude --print` localmente (mesma lógica do bot)
- Histórico de conversa separado (não bagunça o do Telegram)

## Backend Local — `erestor_local.py`

Servidor HTTP em `localhost:8766` com endpoints:

### `POST /chat`
- Recebe: `{"message": "texto"}`
- Carrega contexto (snapshot, memory, GCal events)
- Monta prompt com `prompt_resposta()` (adaptado: "app do Kevin" em vez de "bot do Telegram")
- Chama `claude --print` (timeout 90s)
- Salva histórico local
- Retorna: `{"response": "texto", "actions": [...]}`

### `GET /context`
- Retorna briefing resumido: tarefas ativas, próximo evento, timer ativo, etc.
- Lê de `/tmp/erestor_context.txt` + snapshot + GCal

### `GET /status`
- Uptime, wallpaper ativo, timer, último briefing

### Actions (retornadas pelo Claude junto com a resposta):
- `{"type": "reminder", "text": "...", "at": "HH:MM"}` → cria notificação nativa macOS
- `{"type": "open_project", "path": "~/projetos/blackout"}` → abre terminal + Claude Code
- `{"type": "open_url", "url": "..."}` → abre no browser
- `{"type": "create_event", ...}` → cria evento no GCal

## App Swift

### Interface
- Menu bar icon (acesso rápido)
- Janela dedicada com:
  - Chat (input + histórico)
  - Painel lateral: briefing do dia, próximo evento, tarefas P1
  - Notificações nativas do macOS para proatividade
  - Botões de ação rápida: work/endwork, status, briefing

### Funcionalidades que o Telegram NÃO pode fazer:
- Criar lembretes/notificações nativas do macOS
- Abrir Claude Code no projeto certo com 1 clique
- Atalho de teclado global pra abrir o chat
- Mostrar briefing como widget
- Arrastar arquivo pra contexto

## Implementação — Ordem

### Fase 1 — Chat funcional
1. `erestor_local.py` com endpoint `/chat` (reutiliza módulos erestor/)
2. App Swift com chat UI básico
3. LaunchAgent pro servidor local

### Fase 2 — Contexto visual
4. Endpoint `/context` com briefing
5. Painel lateral no app com agenda + tarefas
6. Notificações nativas

### Fase 3 — Ações e integração
7. Sistema de actions (reminder, open project, etc.)
8. Atalho de teclado global
9. Integração com Claude Code (abrir no projeto certo)

## Referências técnicas

- `prompt_resposta()` está em `erestor/claude.py:369-414`
- `call_claude()` está em `erestor/claude.py:227-262`
- `load_history()` / `save_history()` estão em `erestor/memory.py:118-149`
- `read_snapshot()` está em `erestor/memory.py`
- Webhook server pattern em `erestor_bot.py:210-332` (port 8765)
- O servidor local deve usar porta 8766 (não conflitar com webhook)
- Soul/personality: `erestor/soul.md`
- O prompt precisa ser adaptado: trocar "bot do Telegram" por "app nativo do Kevin"
