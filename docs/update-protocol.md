# Protocolo de Atualização da Documentação

## Quando atualizar

### Atualização imediata (na mesma sessão)

| Evento | O que atualizar |
|--------|----------------|
| Novo componente adicionado | `README.md` (seção Componentes), `docs/components/` (novo arquivo), `docs/architecture.md` (dependências) |
| Comportamento de componente existente mudou | `README.md` (seção do componente), arquivo em `docs/components/` |
| Novo LaunchAgent adicionado | `README.md` (tabela de LaunchAgents), `docs/architecture.md` (timeline diário) |
| Nova integração adicionada | `README.md` (seção Integrações), `docs/architecture.md` |
| Decisão técnica relevante | `docs/technical-decisions.md` (nova entrada) |
| Bug corrigido que revela regra geral | `memory/regras-tecnicas.md` (no código-fonte) + considerar nota em `docs/technical-decisions.md` |
| Mudança em credenciais/arquivos de config | `README.md` (seção Integrações ou Setup) |

### Atualização periódica (mensal, junto com revisão da memória)

- Revisar se `README.md` reflete o estado atual do sistema
- Checar se há decisões técnicas não documentadas em `docs/technical-decisions.md`
- Verificar se `docs/architecture.md` está consistente com o código real
- Atualizar seção "Localização do código fonte" se algo mudou

---

## O que NÃO documentar aqui

- Tarefas pendentes do Kevin → TASKS.md (no código-fonte)
- Observações sobre comportamento do Kevin → `memory/sessao-anterior.md`
- Regras técnicas derivadas de bugs → `memory/regras-tecnicas.md`
- Logs diários → `logs/YYYY-MM-DD.md`

---

## Como atualizar

1. Abrir Claude Code em `~/projetos/erestor/`
2. Fazer as mudanças nos arquivos de documentação
3. Commitar:

```bash
cd ~/projetos/erestor
git add .
git commit -m "docs: descrição do que foi atualizado"
git push
```

---

## Convenção de commits para este repo

- `docs: atualiza componente X` — mudança em arquivo de doc existente
- `docs: adiciona componente X` — novo arquivo de documentação
- `docs: corrige arquitetura` — correção em diagrama ou fluxo
- `chore: atualiza README` — mudanças menores no README principal

Sempre em inglês, sem `Co-Authored-By`.

---

## Sinal de que a doc está desatualizada

Se qualquer uma destas situações for verdade, a doc precisa de update:

- O `README.md` lista um componente que não existe mais no código
- Um LaunchAgent novo está ativo mas não aparece na tabela do README
- O diagrama de arquitetura não reflete a estrutura atual de chamadas
- Uma decisão técnica foi tomada sem estar documentada
- Um bug foi corrigido e gerou uma nova regra não registrada
