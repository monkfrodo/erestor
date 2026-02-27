# Erestor — Assistente Pessoal

Erestor é um assistente pessoal autônomo que funciona 24/7 no Mac, sem depender de nenhuma conversa aberta. Ele tem acesso ao Google Calendar, Notion, ActivityWatch e Telegram — e usa Claude como cérebro para tudo que exige raciocínio.

O nome vem de Erestor de Valfenda, o guardião dos registros e conselheiro de Elrond. O papel aqui é o mesmo: guardar contexto, observar padrões e estar pronto quando o Kevin precisar.

---

## O que faz

- **Responde via Telegram** — texto, voz (transcrição local com Whisper) e comandos
- **Envia briefing matinal** — às 07:50, lê agenda, tarefas e inbox e manda resumo proativo
- **Notificações proativas** — a cada 30min, avalia AW + snapshot e avisa se houver algo relevante (reunião em 20min, P1 vencendo, AFK no bloco de pico)
- **Registra blocos de trabalho** — comandos `work / endwork / content / endcontent` salvam no Google Calendar automaticamente
- **Sincroniza tarefas** — Notion ↔ TASKS.md, de forma automática a cada ciclo
- **Constrói logs diários** — cruza transcripts do Claude Code, AW, GCal e Notion em um log markdown
- **Aprende com as sessões** — memória orgânica que acumula observações e evolui com o tempo
- **Se atualiza sozinho** — todo domingo, atualiza pip e Claude Code

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────────┐
│                           macOS (launchd)                           │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────┐ │
│  │  telegram-bot    │  │   morning-sync   │  │  proactive-check  │ │
│  │  (KeepAlive)     │  │   (07:50 diário) │  │  (a cada 30min)   │ │
│  │  erestor_bot.py  │  │   auto-sync.py   │  │  erestor_bot.py   │ │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬──────────┘ │
│           │                     │                      │            │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────┐ │
│  │  periodic-sync   │  │   night-sync     │  │  memory-autosave  │ │
│  │  (a cada 2h)     │  │  (22h e 00:30)   │  │  (a cada 5min)    │ │
│  │  auto-sync.py    │  │  auto-sync.py    │  │  memory-autosave  │ │
│  └──────────────────┘  └──────────────────┘  └───────────────────┘ │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Claude Code (sessão interativa)          │    │
│  │  hooks: insight-enforcer (PreToolUse)                       │    │
│  │         memory-reminder (UserPromptSubmit)                  │    │
│  │         memory-hook (Stop)                                  │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Integrações externas                        │
│                                                                   │
│   Telegram API     Google Calendar API     Notion API             │
│   ActivityWatch    Claude Code CLI         Whisper (local)        │
└──────────────────────────────────────────────────────────────────┘
```

### Fluxo de dados principal

```
Kevin manda mensagem no Telegram
        │
        ▼
erestor_bot.py recebe via long-polling
        │
        ├─► É comando (work/endwork/content/endcontent)?
        │       └─► Registra timestamp → salva no GCal ao encerrar
        │
        ├─► É feedback sobre o bot?
        │       └─► propose_change() → Claude gera diff → Kevin confirma → apply_change()
        │
        └─► É mensagem normal?
                └─► Monta prompt (AW atual + snapshot + memória + histórico)
                        │
                        ▼
                    claude --print (subprocess)
                        │
                        ▼
                    Formata markdown → HTML → envia no Telegram
```

### Fluxo de dados autônomo (sem Kevin ativo)

```
LaunchAgents disparam em horários fixos
        │
        ▼
auto-sync.py (morning/periodic/night)
        │
        ├─► git pull (pega contexto da outra máquina)
        ├─► Busca Notion (tarefas ativas + concluídas hoje)
        ├─► Busca GCal (todos os calendários em paralelo)
        ├─► Escreve /tmp/notion_snapshot.md
        ├─► Sincroniza TASKS.md
        ├─► Chama log-builder.py --today [--refresh]
        ├─► (morning) Envia briefing matinal via Telegram
        └─► (night) Appenda Telegram log em sessao-anterior.md + git push
```

---

## Componentes

### erestor_bot.py
Interface Telegram do Erestor. Roda permanentemente via LaunchAgent (KeepAlive).

**Dois modos:**
- `python3 erestor_bot.py` → bot loop principal
- `python3 erestor_bot.py --proactive` → check pontual (chamado pelo proactive-check)

**Responsabilidades:**
- Long-polling na API do Telegram
- Processamento de texto, voz (via Whisper local) e comandos
- Timer de blocos de trabalho/conteúdo com salvamento automático no GCal
- Integração com ActivityWatch (estado atual do Mac)
- Histórico de conversa por sessão (30min de timeout, últimas 5 trocas)
- Sistema de autoajuste via feedback: Kevin pode ajustar o comportamento do bot em linguagem natural
- Silêncio noturno configurável (padrão: 23h–7h)
- Snooze do proativo (automático quando Kevin pede mais tempo)

**Arquivos de estado (em /tmp ou $HOME):**
- `~/.erestor_telegram` — token e chat_id
- `/tmp/notion_snapshot.md` — snapshot Notion/GCal (lido por vários componentes)
- `conversation_history.json` — histórico de sessão
- `~/.erestor_snooze` — timestamp de silêncio do proativo
- `/tmp/erestor_last_msg` — timestamp da última mensagem (para detectar conversa ativa)
- `/tmp/erestor_pending_change.json` — proposta de mudança aguardando confirmação

---

### briefing.py
Coleta dados de múltiplas fontes em paralelo e exibe o briefing do dia no terminal.

**Fontes:**
- Google Calendar (9 calendários em paralelo com ThreadPoolExecutor)
- Notion (tarefas, cobranças, inbox)
- ActivityWatch (tempo ativo, apps, trabalho tardio)
- `/tmp/notion_snapshot.md` (cache — evita chamadas à API quando disponível)

**Saída:**
- Exibe no terminal com cores ANSI (bloco atual, agenda, tarefas P1/P2/P3, cobranças, inbox)
- Salva `/tmp/erestor_context.txt` para o Claude Code ler ao iniciar sessão
- Chama `log-builder.py` para garantir que o log de ontem existe

---

### log-builder.py
Constrói o log diário de forma automática cruzando 4 fontes.

**Fontes por ordem de riqueza:**
1. **Transcripts JSONL do Claude Code** — extrai sessões por projeto (nome, horário, duração, mensagens, arquivos tocados)
2. **ActivityWatch** — tempo ativo, AFK no pico (14h–17h), apps mais usados, trabalho após 21h
3. **Google Calendar** — blocos registrados (calendário "trabalho" = fonte principal)
4. **Notion snapshot** — tarefas ativas e concluídas no dia

**Modos:**
- `python3 log-builder.py [YYYY-MM-DD]` — cria log de uma data (default: ontem)
- `python3 log-builder.py --today` — log de hoje
- `python3 log-builder.py --refresh` — reconstrói seções automáticas, preserva manuais preenchidas
- `python3 log-builder.py --force` — reconstrói sem sessões (para datas antigas)

**Proteção de conteúdo manual:** As seções "Inbox processado" e "Observações / brain dump" são preservadas no `--refresh` se já foram preenchidas pelo Kevin.

---

### auto-sync.py
Agentes autônomos que rodam sem depender de nenhuma conversa aberta.

**Três modos:**
- `--mode morning` (07:50): git pull + Notion + GCal + snapshot + TASKS.md sync + log-builder + briefing Telegram
- `--mode periodic` (a cada 2h): Notion + GCal + snapshot + TASKS.md sync + log-builder --refresh
- `--mode night` (22h e 00:30): tudo do periodic + append Telegram log em memória + git push

**Funcionalidades chave:**
- `sync_tasks_md()` — marca done e adiciona novas tarefas do Notion no TASKS.md automaticamente
- `write_snapshot()` — escreve estado atual em `/tmp/notion_snapshot.md` (todas as fontes)
- `send_morning_brief()` — monta prompt e chama `claude --print` para gerar e enviar briefing
- `git_sync()` — commit e push apenas de `produtividade/` (não toca outros arquivos do claude-sync)
- `git_pull()` — pull antes do morning sync para pegar contexto da outra máquina

---

### insight-enforcer.py
Hook `PreToolUse` que avisa quando faz mais de 15min sem registrar insights.

**Comportamento:**
- Só monitora chamadas Bash (não interrompe Read/Edit/Grep/Glob)
- Bloqueia a ferramenta com `decision: block` se o intervalo foi ultrapassado
- Cooldown de 10min para evitar spam
- Não dispara na primeira execução da sessão
- Libera silenciosamente se `sessao-anterior.md` foi editado nos últimos 5min

**Nota:** Por enquanto tem comportamento de bloquear (não só avisar), conforme última versão. A intenção original era só avisar, mas foi alterado para garantir que o Kevin registre antes de continuar.

---

### memory-autosave.py
Autosave periódico do transcript da sessão atual.

**Rodado:** a cada 5min via LaunchAgent `com.erestor.memory-autosave`

**O que faz:**
- Encontra o transcript JSONL mais recente do projeto `produtividade` (em `~/.claude/projects/`)
- Só processa se modificado nas últimas 6h
- Extrai até 40 mensagens recentes (Kevin + Erestor)
- Salva rascunho em `/tmp/erestor_session_draft.md`

**Independe de como a sessão termina** — terminal fechado, /exit ou crash.

---

### memory-hook.py
Hook `Stop` que salva rascunho quando a sessão do Claude Code encerra.

**Complementar ao memory-autosave.py:** autosave cobre crashes e fechamentos inesperados, hook-stop cobre encerramentos normais com transcript final completo.

**Saída:** `/tmp/erestor_session_draft.md` — lido e apagado no início da próxima sessão.

---

### memory-reminder.py
Hook `UserPromptSubmit` que injeta lembrete de registro de insights a cada 10min.

**Comportamento:**
- A cada mensagem do Kevin, verifica `/tmp/erestor_last_insight.txt`
- Se faz mais de 10min: injeta `systemMessage` no prompt do Claude
- Não bloqueia, não avisa o Kevin — é interno para o Claude

---

### setup-agents.sh
Instala todos os LaunchAgents do Erestor.

**Uso:** `bash ~/claude-sync/produtividade/setup-agents.sh`

**LaunchAgents instalados:**

| Label | Quando roda | Script |
|-------|-------------|--------|
| `com.erestor.morning-sync` | 07:50 diário | `auto-sync.py --mode morning` |
| `com.erestor.periodic-sync` | A cada 2h | `auto-sync.py --mode periodic` |
| `com.erestor.night-sync` | 22:00 e 00:30 | `auto-sync.py --mode night` |
| `com.erestor.caffeinate` | Sempre (KeepAlive) | `caffeinate -s` |
| `com.erestor.update-system` | Domingo 10:00 | `update-system.sh` |
| `com.erestor.memory-autosave` | A cada 5min | `memory-autosave.py` |
| `com.erestor.briefing-refresh` | A cada 2h | `briefing.py` |
| `com.erestor.telegram-bot` | Sempre (KeepAlive) | `erestor_bot.py` |
| `com.erestor.proactive-check` | A cada 30min | `erestor_bot.py --proactive` |

**Verificação:** `launchctl list | grep erestor`

---

### update-system.sh
Atualização semanal automática (domingo 10:00).

- Atualiza `certifi` e `python-dateutil` via pip
- Atualiza Claude Code (`claude update`)
- Log em `/tmp/erestor-update-system.log`

---

## Sistema de Memória

A memória do Erestor tem dois eixos:

### 1. Memória viva (sessão)
- `memory/sessao-anterior.md` — tabela de observações acumuladas `| data | observação | N |`
- Registrado em tempo real durante as sessões Claude Code
- N = número de ocorrências (padrão se repete → peso maior)
- Compilação quinzenal: entradas com N ≥ 3 → promovidas para `memory/context/`
- Compilação mensal: revisão completa, atualização do CLAUDE.md

### 2. Memória permanente (contexto)
- `memory/context/` — arquivos temáticos: fluxo-diario, agenda-blocos-fixos, perfil-de-negocio, etc.
- `memory/people/` — perfis de pessoas que aparecem nas conversas
- `memory/projects/` — contexto de projetos específicos
- `memory/regras-tecnicas.md` — regras derivadas de bugs reais (leitura obrigatória)

### Hooks que garantem registro
| Hook | Trigger | Ação |
|------|---------|------|
| `insight-enforcer.py` | PreToolUse (Bash) | Bloqueia se >15min sem registrar |
| `memory-reminder.py` | UserPromptSubmit | Injeta lembrete a cada 10min |
| `memory-hook.py` | Stop | Salva rascunho no encerramento |
| `memory-autosave.py` | A cada 5min (LaunchAgent) | Salva rascunho periódico |

---

## Integrações

### Telegram
- Config: `~/.erestor_telegram` (JSON: `token`, `chat_id`)
- Segurança: só aceita mensagens do `chat_id` registrado
- Comandos: `work <desc>`, `endwork`, `content <desc>`, `endcontent`

### Google Calendar
- Credenciais OAuth: `~/.gcal_credentials` (JSON: `client_id`, `client_secret`, `refresh_token`)
- Token cache: `~/.gcal_token_cache` (renovado a cada 55min)
- Calendários: trabalho, conteúdo, estudos, exercícios, mentorias individuais, consultorias individuais, íntegros | agenda geral, cuidado pessoal

### Notion
- Token: definido diretamente nos scripts (não via .env)
- Database tarefas: `30a36705-8e14-8051-865c-d369af16e62e`
- Database cobranças: `8713437e-04f1-454c-92be-19e43e57d33f`
- Inbox block: `30a367058e1481d296ebc04909d1eee9`

### ActivityWatch
- Local: `http://localhost:5600`
- Buckets: `aw-watcher-afk_{hostname}`, `aw-watcher-window_{hostname}`
- Usado para: estado atual do Mac, streaks de foco, detecção de AFK durante pico

### Claude Code
- Chamado via subprocess: `claude --print --dangerously-skip-permissions`
- Timeout: 60–180s dependendo do contexto
- Working directory: `~/claude-sync/produtividade/` (tem acesso ao CLAUDE.md)

### Whisper
- `faster-whisper` (local, sem API externa)
- Modelo: `base`, CPU, `int8`
- Transcrição de mensagens de voz do Telegram (formato OGG)

---

## Setup numa máquina nova

```bash
# 1. Clonar claude-sync (se ainda não existe)
git clone git@github.com:monkfrodo/claude-sync.git ~/claude-sync

# 2. Instalar dependências Python
pip install certifi python-dateutil faster-whisper

# 3. Configurar credenciais
# ~/.erestor_telegram  → {"token": "...", "chat_id": null}
# ~/.gcal_credentials  → {"client_id":"...","client_secret":"...","refresh_token":"..."}

# 4. Instalar LaunchAgents
bash ~/claude-sync/produtividade/setup-agents.sh

# 5. Verificar
launchctl list | grep erestor
python3 ~/claude-sync/produtividade/briefing.py
```

---

## Localização do código fonte

O código-fonte vive em `~/claude-sync/produtividade/` — parte do repositório `claude-sync` que sincroniza configs entre iMac e MacBook.

**Este repositório** (`~/projetos/erestor/`) é o projeto standalone com documentação completa e contexto para trabalho com Claude Code.

Para trabalhar no código: abrir Claude Code em `~/claude-sync/produtividade/`.
Para documentar: abrir Claude Code aqui em `~/projetos/erestor/`.

---

## Convenções

- Commits: conventional commits em inglês, sem `Co-Authored-By`
- Paths: sempre `$HOME` ou `os.path.expanduser("~/")` — nunca hardcoded
- Logs: `logs/agents-YYYY-MM-DD.log` (agentes autônomos), `logs/telegram-YYYY-MM-DD.md` (conversas), `logs/YYYY-MM-DD.md` (log diário)
- Após qualquer fix: rodar `python3 ~/claude-sync/produtividade/erestor-check.py`
