# Decisões Técnicas — Erestor

Registro das decisões de arquitetura tomadas ao longo do desenvolvimento, com o racional por trás de cada uma.

---

## Python stdlib-only para HTTP

**Decisão:** Usar `urllib.request` em vez de `requests` para todas as chamadas HTTP.

**Racional:** O Erestor roda em dois Macs como processo de sistema (LaunchAgent), sem ambiente virtual garantido. `urllib` faz parte da stdlib e nunca vai faltar. Adicionar `requests` criaria uma dependência pip que pode quebrar ao trocar de máquina ou após update do Python.

**Exceção:** `certifi` é usada para certificados SSL no macOS, mas com fallback para `ssl._create_unverified_context()` quando não está disponível. `faster-whisper` para transcrição de voz (o único pacote sem alternativa stdlib).

---

## Claude via subprocess, não API direta

**Decisão:** Chamar o Claude via `claude --print --dangerously-skip-permissions` em vez de usar a API Anthropic diretamente.

**Racional:**
1. O `claude` CLI lê o `CLAUDE.md` do diretório de trabalho (`produtividade/`) — o contexto completo está disponível automaticamente
2. Não precisa gerenciar API key — usa a sessão do Claude Code já autenticada
3. O bot tem acesso a todas as ferramentas do Claude Code (Read, Write, Bash) se precisar executar ações
4. Simplifica o código — sem SDK, sem gerenciamento de conversas multi-turn na API

**Tradeoff:** Subprocess tem overhead maior que chamada de API direta. Timeout configurado (60–180s). Para uso pessoal e volume baixo, é aceitável.

---

## Snapshot em /tmp em vez de chamadas ao vivo

**Decisão:** `auto-sync.py` escreve `/tmp/notion_snapshot.md` que é lido por `erestor_bot.py` e `briefing.py` em vez de cada componente chamar a API.

**Racional:**
- Notion e GCal têm limites de rate e latência (~500ms por chamada)
- O bot precisa responder em segundos — não dá para esperar 5 chamadas de API antes de responder
- O snapshot é atualizado a cada 2h pelo periodic-sync — suficiente para o contexto do dia
- Se o snapshot não existe ou é velho, o bot faz fallback para "snapshot indisponível" e responde assim mesmo

**Tradeoff:** Contexto pode ter até 2h de defasagem. Aceitável para tarefas e agenda — não para dados em tempo real (para isso, o Claude Code session tem acesso direto ao Notion).

---

## LaunchAgents em vez de cron

**Decisão:** Usar o sistema de LaunchAgents do macOS em vez de `crontab`.

**Racional:**
1. `KeepAlive: true` reinicia processos que morrem — crítico para o bot do Telegram
2. `caffeinate -s` via LaunchAgent previne sleep enquanto carregado, sem mexer nas preferências do sistema
3. Logs separados por processo (`/tmp/erestor-*.log`) sem configuração extra
4. Integração nativa com o macOS — menos surpreesas entre reinicializações
5. `setup-agents.sh` pode ser rodado a qualquer momento para reinstalar/atualizar sem mexer em crontab

---

## Dois processos para proativo (bot loop + proactive-check)

**Decisão:** O bot loop principal (`erestor_bot.py`) responde mensagens. O proativo (`erestor_bot.py --proactive`) roda separado a cada 30min.

**Racional:**
- Se o proativo ficasse dentro do bot loop (em thread separada), um travamento no loop afetaria o proativo e vice-versa
- O LaunchAgent `proactive-check` pode falhar silenciosamente sem afetar a capacidade de resposta do bot
- Facilita depuração: `tail -f /tmp/erestor-proactive.log` mostra só os checks proativos

---

## Autoajuste com zonas editáveis restritas

**Decisão:** Kevin pode ajustar o comportamento do bot via Telegram, mas o Claude só pode editar dois trechos específicos do código (zona `silence` e zona `proativo`).

**Racional:**
- Permitir edição livre do código seria um vetor de segurança óbvio
- Permitir zero edição deixa o bot rígido — feedback não vira mudança
- As duas zonas cobrem os principais ajustes que o Kevin vai querer: horários de silêncio e tom/critérios do proativo
- `validate_change()` verifica: tamanho, padrões proibidos (`import`, `subprocess`, `eval`, etc.), e que o `old` existe no código atual

---

## Memória orgânica em vez de CLAUDE.md estático

**Decisão:** Observações sobre o Kevin são acumuladas em `sessao-anterior.md` durante as sessões, não pré-configuradas no CLAUDE.md.

**Racional:**
- O CLAUDE.md é escrito uma vez e tende a ficar defasado
- Observações orgânicas capturam padrões que o Kevin não saberia articular antecipadamente
- O sistema de compilação (quinzenal/mensal) garante que padrões sólidos vão para memória permanente e dados velhos são descartados
- Fase inicial: volume máximo de registro (sem filtro). Padrões emergem de dados, não de seleção prévia.

---

## Git como mecanismo de sync entre máquinas

**Decisão:** `auto-sync.py` faz `git push` de `produtividade/` toda noite e `git pull` toda manhã.

**Racional:**
- Evita precisar de infraestrutura adicional (Dropbox, iCloud sync, rsync via SSH)
- Histórico de mudanças de graça
- O morning-sync do MacBook puxa o estado do dia anterior do iMac antes de começar
- Conflitos são raros porque os dois Macs raramente escrevem no mesmo arquivo na mesma janela de tempo

**Tradeoff:** Requer git configurado com SSH key autenticada em ambas as máquinas. Se não tiver internet de manhã, o pull falha silenciosamente e o dia começa sem o contexto do dia anterior.

---

## Whisper local em vez de API de transcrição

**Decisão:** Usar `faster-whisper` rodando localmente para transcrever mensagens de voz.

**Racional:**
- Voz pode conter informações sensíveis (tarefas, nomes de clientes, valores)
- Sem latência de rede para transcrição
- Sem custo por transcrição
- `faster-whisper` com modelo `base` e `int8` é rápido o suficiente para uso casual

**Tradeoff:** Qualidade menor que Whisper Large via API. Para uso pessoal e voz clara, `base` é suficiente.

---

## TASKS.md como espelho do Notion (não fonte primária)

**Decisão:** Notion é a fonte primária de tarefas. TASKS.md é um espelho local sincronizado automaticamente.

**Racional:**
- Notion tem interface visual, filtros, relações entre bases — útil para gestão complexa
- TASKS.md é legível pelo Claude Code em qualquer sessão, sem precisar de chamada de API
- `auto-sync.py` mantém os dois em sync — o Claude Code não precisa chamar o Notion para ver tarefas
- Seção `## 📥 Pendente (Notion)` no TASKS.md captura tarefas que ainda não foram triadas manualmente

**Regra importante:** Antes de apresentar qualquer tarefa no briefing, sempre checar o status no Notion. TASKS.md pode ter lag de até 2h.

---

## Logs diários em markdown estruturado

**Decisão:** Logs em `logs/YYYY-MM-DD.md` com seções fixas (agenda prevista, calendário trabalho, sessões Claude Code, ActivityWatch, tarefas, observações).

**Racional:**
- Legível pelo Claude Code sem parsing especial
- Formato consistente facilita busca retroativa ("o que eu fiz na semana de X?")
- Seções manuais (`## Inbox processado`, `## Observações`) coexistem com seções automáticas
- `--refresh` reconstrói partes automáticas sem apagar o que o Kevin preencheu manualmente
- Transcripts JSONL do Claude Code contêm a granularidade maior — o log tem só o resumo útil

---

## Correções estruturais — 27/02/2026 (wave 1 + wave 2)

14 fixes aplicados após varredura completa do código. Resumo das decisões:

**Persistência de estado fora de /tmp**
Arquivos que precisam sobreviver a restarts do LaunchAgent movidos para `HOME/` ou `PROD_DIR/logs/`:
- `PROACTIVE_LOG` → `PROD_DIR/logs/proactive_sent.json`
- `LAST_MSG_FILE` → `HOME/.erestor_last_msg`
- `PENDING_CHANGE_FILE` → `HOME/.erestor_pending_change.json`
- Backup do autoajuste → `HOME/.erestor_bot_backup.py`

**Histórico de conversa**
Aumentado de 5 para 10 trocas, timeout de 30min para 60min, truncamento de 300 para 500 chars. Kevin trabalha em múltiplos projetos em paralelo com pausas longas — contexto precisava durar mais.

**AW offline ≠ AFK**
`aw_now()` agora retorna `offline: True` quando ActivityWatch não responde. `aw_summary()` reporta "ActivityWatch offline" em vez de assumir AFK silenciosamente.

**Filtro de apps utilitários do sistema**
`AW_SYSTEM_APPS` criado. Force Quit, Spotlight, loginwindow, etc. não são reportados como sinal de trabalho real.

**Whisper model cache**
`_whisper_model` global — modelo carregado uma vez, reutilizado em todas as mensagens de voz. Elimina spike de 15-20s na primeira voz do dia.

**Timer órfão em work/endwork**
Timer com mais de 12h é detectado como órfão (bot crashou com timer ativo) — descartado com aviso em vez de criar evento fantasma no GCal.

**Proativo não vira mensagem de erro**
Timeout e erros do Claude filtrados antes de chegar no Kevin. NADA detection mais robusta.

**GCal validação real**
`gcal_create_event` valida `body.id` na resposta em vez de só `r.status`.

**FEEDBACK_SIGNALS mais restrito**
Palavras genéricas removidas ("para de", "silêncio", "cobrança") — só sinais inequívocos sobre o bot ativam o fluxo de autoajuste.
