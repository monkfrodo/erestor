# Arquitetura do Erestor

## Visão geral

O Erestor é construído em camadas. A camada mais externa é a interface (Telegram). A do meio são os agentes autônomos que rodam sem ninguém precisar pedir. A de baixo é o sistema de memória que acumula contexto.

```
┌──────────────────────────────────────────────────────────────────┐
│  CAMADA DE INTERFACE                                             │
│                                                                  │
│  Telegram Bot               Claude Code (sessão interativa)      │
│  (erestor_bot.py)           (CLAUDE.md de produtividade/)        │
└──────────────────┬───────────────────────────┬───────────────────┘
                   │                           │
                   ▼                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  CAMADA DE PROCESSAMENTO                                         │
│                                                                  │
│  auto-sync.py       briefing.py      log-builder.py             │
│  (agentes)          (contexto)       (logs diários)             │
└──────────────────┬───────────────────────────┬───────────────────┘
                   │                           │
                   ▼                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  CAMADA DE MEMÓRIA                                               │
│                                                                  │
│  memory/sessao-anterior.md     /tmp/notion_snapshot.md          │
│  memory/context/               conversation_history.json        │
│  logs/YYYY-MM-DD.md            /tmp/erestor_context.txt         │
└──────────────────┬───────────────────────────┬───────────────────┘
                   │                           │
                   ▼                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  INTEGRAÇÕES EXTERNAS                                            │
│                                                                  │
│  Google Calendar     Notion         ActivityWatch    Telegram    │
│  (OAuth2 local)      (REST API)     (localhost:5600) (bot API)   │
│                                                                  │
│  Claude Code CLI     Whisper (local)     Git (claude-sync)       │
└──────────────────────────────────────────────────────────────────┘
```

---

## LaunchAgents — timeline diário

```
00:30  night-sync (2ª rodada)
       └── refresh snapshot + TASKS.md + log + git push

07:50  morning-sync
       ├── git pull (pega contexto da outra máquina)
       ├── busca Notion (tarefas + concluídas hoje) [paralelo]
       ├── busca GCal (9 calendários) [paralelo]
       ├── escreve /tmp/notion_snapshot.md
       ├── sync TASKS.md (marca done, adiciona novas)
       ├── log-builder.py --today (cria se não existe)
       └── envia briefing via Telegram (claude --print)

09:50  periodic-sync (2h depois do morning)
10:xx  briefing-refresh (2h depois do início)
...
12:xx  periodic-sync
14:xx  periodic-sync
14:xx  briefing-refresh
...

[ao longo do dia, a cada 30min]
       proactive-check
       └── erestor_bot.py --proactive
           ├── silêncio noturno? (23h–7h) → abortar
           ├── snooze ativo? → abortar
           ├── conversa ativa (< 15min)? → abortar
           └── claude --print (avalia AW + snapshot)
               └── se não "NADA" → envia mensagem Telegram

[a cada 5min]
       memory-autosave
       └── salva /tmp/erestor_session_draft.md

22:00  night-sync (1ª rodada)
       ├── refresh snapshot + TASKS.md + log
       ├── appenda Telegram log em sessao-anterior.md
       └── git push

[LaunchAgents sempre ativos]
       telegram-bot   (KeepAlive — reinicia automaticamente)
       caffeinate     (KeepAlive — previne sleep)
```

---

## Fluxo de uma mensagem no Telegram

```
Kevin envia mensagem
       │
       ▼
handle_text() / handle_voice()
       │
       ├── Registra timestamp (LAST_MSG_FILE)
       │
       ├── É "mais tempo"? → snooze_proactive(30min)
       │
       ├── Tem mudança pendente? → handle confirmation (sim/não)
       │
       ├── É comando work/endwork/content/endcontent?
       │       └── handle_work_cmd() ou handle_endwork_cmd()
       │           └── endwork: gcal_create_event() → salva bloco no GCal
       │
       ├── É feedback sobre o bot? (is_feedback())
       │       └── propose_change() via claude --print
       │           └── validate_change() → PENDING_CHANGE_FILE
       │               └── Kevin confirma → apply_change() → os.kill(SIGTERM)
       │                   └── launchd reinicia o bot automaticamente
       │
       └── Mensagem normal:
               ├── aw_summary() → estado atual do Mac
               ├── /tmp/notion_snapshot.md → contexto do dia
               ├── load_history() → últimas 5 trocas
               ├── load_memory() → últimas 30 observações
               ├── prompt_resposta() → monta prompt completo
               ├── call_claude() → subprocess claude --print
               └── send() → formata HTML → Telegram API
```

---

## Sistema de autoajuste

Kevin pode ajustar o comportamento do bot em linguagem natural via Telegram:

```
Kevin: "tá muito proativo, reduz a frequência à noite"
       │
       ▼
is_feedback() → True
       │
       ▼
propose_change()
├── Extrai zona de código editável (silence ou proativo)
├── Manda para claude --print com restrições explícitas
└── Claude retorna JSON: {old, new, zona, motivo}
       │
       ▼
validate_change()
├── Verifica tamanho (< 600 chars)
├── Verifica proibições (import, subprocess, eval, etc.)
└── Verifica que "old" existe no código atual
       │
       ▼
Kevin confirma "sim" ou "não"
       │
       ▼
apply_change()
├── Backup em /tmp/erestor_bot.py.bak
├── replace() no código
└── os.kill(SIGTERM) → launchd reinicia o bot
```

**Zonas editáveis:**
- `silence`: linha com `now.hour >= X or now.hour < Y` (horários de silêncio)
- `proativo`: corpo do `prompt_proativo()` (tom e critérios de disparo)

---

## Fluxo de sincronização entre máquinas

```
iMac                              MacBook
  │                                  │
  ├── night-sync (22h)               │
  │   └── git push produtividade/    │
  │                                  │
  │                              morning-sync (07:50)
  │                              └── git pull (--ff-only)
  │                                  └── pega logs, TASKS.md,
  │                                      memória do dia anterior
```

**O que é sincronizado:**
- `produtividade/logs/` — logs diários e de agentes
- `produtividade/TASKS.md` — estado atual das tarefas
- `produtividade/memory/` — observações e contexto
- `produtividade/conversation_history.json` — histórico recente

**O que NÃO é sincronizado (local a cada máquina):**
- `/tmp/*` — arquivos de estado temporários
- `~/Library/LaunchAgents/` — os plists de LaunchAgents
- `~/.erestor_telegram`, `~/.gcal_credentials` — credenciais

---

## Diagrama de dependências entre arquivos

```
settings.json
  ├── PreToolUse  → insight-enforcer.py
  ├── UserPromptSubmit → memory-reminder.py
  └── Stop → memory-hook.py

setup-agents.sh
  ├── instala LaunchAgents que chamam:
  │   ├── auto-sync.py --mode morning/periodic/night
  │   ├── erestor_bot.py [--proactive]
  │   ├── memory-autosave.py
  │   ├── briefing.py
  │   └── update-system.sh
  └── instala caffeinate (launchd nativo)

auto-sync.py
  ├── lê: ~/.gcal_credentials
  ├── escreve: /tmp/notion_snapshot.md
  ├── modifica: produtividade/TASKS.md
  ├── chama: log-builder.py --today [--refresh]
  ├── chama: claude --print (morning brief)
  └── executa: git add produtividade/ && git commit && git push

erestor_bot.py
  ├── lê: ~/.erestor_telegram
  ├── lê: /tmp/notion_snapshot.md
  ├── lê: memory/sessao-anterior.md
  ├── lê/escreve: conversation_history.json
  ├── escreve: logs/telegram-YYYY-MM-DD.md
  ├── escreve: logs/agents-YYYY-MM-DD.log
  ├── chama: claude --print
  └── chama: gcal_create_event() (work/content)

briefing.py
  ├── lê: /tmp/notion_snapshot.md (cache)
  ├── lê: ~/.gcal_credentials
  ├── busca: GCal API (9 calendários) [paralelo]
  ├── busca: Notion API (tarefas, cobranças, inbox)
  ├── busca: ActivityWatch localhost:5600
  └── escreve: /tmp/erestor_context.txt

log-builder.py
  ├── lê: ~/.claude/projects/*/YYYY-MM-DD*.jsonl
  ├── lê: /tmp/notion_snapshot.md
  ├── busca: GCal API (4 calendários)
  ├── busca: ActivityWatch
  └── escreve: logs/YYYY-MM-DD.md
```
