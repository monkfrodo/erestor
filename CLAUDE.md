# Erestor — Contexto para Claude Code

## O que é este projeto

Erestor é o assistente pessoal do Kevin. Documentação do sistema que vive em `~/claude-sync/produtividade/`.

**Fonte da verdade:** `~/claude-sync/produtividade/`
**Este repo:** documentação, contexto de trabalho, histórico de decisões

Quando o Kevin precisar mexer no código do Erestor, abrir Claude Code em `~/claude-sync/produtividade/`. Este repo é para trabalho de documentação e planejamento.

---

## Leitura obrigatória antes de qualquer trabalho no código

```bash
cat ~/claude-sync/produtividade/memory/regras-tecnicas.md
```

São regras derivadas de bugs reais. Violar é repetir um erro já cometido.

---

## Estrutura do código-fonte

```
~/claude-sync/produtividade/
├── erestor_bot.py       # Interface Telegram (bot principal)
├── briefing.py          # Briefing diário — GCal + Notion + AW
├── log-builder.py       # Log diário automático
├── auto-sync.py         # Agentes autônomos (morning/periodic/night)
├── insight-enforcer.py  # Hook PreToolUse
├── memory-autosave.py   # Autosave periódico de sessão
├── memory-hook.py       # Hook Stop (encerramento)
├── memory-reminder.py   # Hook UserPromptSubmit
├── setup-agents.sh      # Instala LaunchAgents
├── update-system.sh     # Atualização semanal
├── erestor-check.py     # Verificação pós-fix
├── send_telegram.sh     # Helper shell para Telegram
├── CLAUDE.md            # Contexto completo do projeto (protocolos, integrações, agenda)
├── TASKS.md             # Tarefas do Kevin
├── logs/                # Logs diários e de agentes
├── memory/              # Sistema de memória viva
│   ├── sessao-anterior.md
│   ├── regras-tecnicas.md
│   ├── context/
│   ├── people/
│   └── projects/
└── .claude/
    └── settings.json    # Hooks do Claude Code
```

---

## Regras invioláveis

1. **Nunca hardcoded paths** — usar `$HOME` (bash) ou `os.path.expanduser("~/")` (Python)
2. **Nunca commitar sem autorização explícita** do Kevin
3. **Nunca incluir `Co-Authored-By`** nos commits
4. **Sempre testar localmente** antes de declarar fix pronto
5. **Sempre rodar `erestor-check.py`** após qualquer correção
6. **Nunca editar `~/.config/fish/config.fish` diretamente** — editar `~/dotfiles/config.fish`
7. **Nunca colocar `claude remote-control` na função `erestor`** — causa erros

---

## Workflow de mudanças no código

```bash
# 1. Ler regras técnicas
cat ~/claude-sync/produtividade/memory/regras-tecnicas.md

# 2. Fazer a mudança (sempre no ~/claude-sync/produtividade/)

# 3. Verificar
python3 ~/claude-sync/produtividade/erestor-check.py

# 4. Testar manualmente se aplicável
python3 ~/claude-sync/produtividade/briefing.py
# ou
launchctl list | grep erestor

# 5. Commit (no repo ~/claude-sync/, não aqui)
cd ~/claude-sync
git add produtividade/
git commit -m "fix: descrição do problema resolvido"
git push
```

---

## LaunchAgents — gerenciamento

```bash
# Ver status de todos os agentes
launchctl list | grep erestor

# Reiniciar um agente específico
launchctl unload ~/Library/LaunchAgents/com.erestor.telegram-bot.plist
launchctl load ~/Library/LaunchAgents/com.erestor.telegram-bot.plist

# Reinstalar todos os agentes (após setup-agents.sh ser atualizado)
bash ~/claude-sync/produtividade/setup-agents.sh

# Testar modo morning manualmente
python3 ~/claude-sync/produtividade/auto-sync.py --mode morning

# Ver logs em tempo real
tail -f /tmp/erestor-telegram-bot.log
tail -f ~/claude-sync/produtividade/logs/agents-$(date +%Y-%m-%d).log
```

---

## Credenciais necessárias

Não estão no repositório. Ficam em arquivos locais protegidos:

| Arquivo | Conteúdo |
|---------|----------|
| `~/.erestor_telegram` | JSON com `token` e `chat_id` |
| `~/.gcal_credentials` | JSON OAuth com `client_id`, `client_secret`, `refresh_token` |

---

## Documentação deste repo

```
docs/
├── architecture.md          # Diagrama e fluxos detalhados
├── technical-decisions.md   # Decisões técnicas e racionais
├── update-protocol.md       # Quando e como atualizar a documentação
└── components/              # Docs detalhadas por componente
    ├── erestor-bot.md
    ├── auto-sync.md
    ├── briefing.md
    ├── log-builder.md
    ├── memory-system.md
    └── hooks.md
```

---

## O que NÃO fazer

- Não mexer em `~/claude-sync/` sem entender o fluxo sync-tudo → clone-all → setup
- Não usar o sistema de memória daqui para substituir o CLAUDE.md de `produtividade/`
- Não criar código de produção aqui — este repo é documentação
- Não remover seções do README sem atualizar a referência correspondente em `docs/`
