# Erestor v1.0 — Guia de Deploy

**Data:** 2026-03-10
**Status:** Código pronto, falta deploy nas 3 plataformas

---

## O que foi feito

- 6 fases, 18 planos, 175 arquivos, ~29k linhas
- Backend: FastAPI com 12 routers (REST + SSE)
- macOS: Swift/SwiftUI app com floating bubble, chat streaming, polls, notifications
- iOS: Swift/SwiftUI app com 4 tabs (Painel, Chat, Agenda, Insights)
- Web: Next.js 15 PWA com streaming chat, polls, web push
- Migração de dados históricos do Telegram → SQLite
- Audit passed: 36/36 requisitos, 9/9 flows E2E

---

## Passo a passo de deploy

### 1. Backend — DigitalOcean

```bash
# No Mac — push do código
cd ~/claude-sync
git push

# No servidor DO (via SSH)
ssh do
cd ~/claude-sync/produtividade
git pull
pip install pywebpush   # dependência nova
pm2 restart erestor-api # ou o nome do processo da API
```

**Verificar:** `curl https://erestor-api.kevineger.com.br/v1/status -H "Authorization: Bearer TOKEN"` deve retornar JSON com `{status: "running"}`.

**Routers novos que precisam funcionar:**
- POST /v1/timer/stop
- GET /v1/history
- POST /v1/device/register
- POST /v1/webpush/subscribe
- GET /v1/insights/chart-data

### 2. macOS app — rebuild local

```bash
cd ~/projetos/erestor/ErestorApp
xcodegen generate
xcodebuild -scheme ErestorApp build
```

Ou: Xcode → Open `~/projetos/erestor/ErestorApp` → Cmd+B (Build) → Cmd+R (Run)

O app já tem LaunchAgent configurado (`com.erestor.app`) que inicia automaticamente.

### 3. iOS app — instalar no iPhone

**Pré-requisitos (só na primeira vez):**
1. iPhone: Ajustes → Privacidade e Segurança → Modo Desenvolvedor → ativar (reinicia o iPhone)
2. Xcode: Settings → Accounts → adicionar Apple ID pessoal
3. Cabo USB conectando iPhone ao Mac

**Instalar:**
1. Abrir projeto no Xcode
2. Selecionar scheme `ErestorApp-iOS`
3. Selecionar teu iPhone como destino (não Simulator)
4. Cmd+R (Run)
5. No iPhone: Ajustes → Geral → Gerenciamento de VPN e Dispositivo → confiar no certificado

**Notas:**
- App roda 100% nativo no iPhone (não precisa do Mac depois de instalar)
- Expira a cada 7 dias — plugar cabo + Cmd+R no Xcode pra renovar (30 segundos)
- Push notifications (APNs) NÃO funcionam sem Apple Developer Program ($99/ano)
- Não pretendemos pagar isso, então sem push — app funciona pra tudo menos notificações

### 4. Web PWA — deploy

```bash
cd ~/projetos/erestor/web
npm install
npm run build
```

**Env vars necessárias:**
- `NEXT_PUBLIC_API_BASE=https://erestor-api.kevineger.com.br`
- `API_BASE=https://erestor-api.kevineger.com.br` (server-side, pro proxy /api/poll-respond)
- `NEXT_PUBLIC_API_TOKEN=<bearer token>` (se o frontend precisa mandar auth)

**Deploy options:**
- Vercel (mais simples): push pro GitHub e conectar
- DigitalOcean: `npm run build && pm2 start npm --name erestor-web -- start`

### 5. Migração de dados (uma vez só)

```bash
# No servidor DO (ou local se DB é local)
cd ~/claude-sync/produtividade
python3 migrate-history.py
```

Popula o SQLite com dados históricos do Telegram (mood, energy, memory, logs).

### 6. Web Push — VAPID keys (opcional)

Só se quiser web push funcionando:

```bash
# Gerar keys
pip install pywebpush py_vapid
python3 -c "from py_vapid import Vapid; v = Vapid(); v.generate_keys(); print('Public:', v.public_key.urlsafe_b64encode()); print('Private:', v.private_key)"
```

Configurar como env vars no backend e no frontend web.

---

## Verificação pós-deploy

### Backend
- [ ] `GET /v1/status` retorna 200
- [ ] `GET /v1/context` retorna evento atual
- [ ] `POST /v1/chat/stream` retorna SSE com resposta do Claude
- [ ] `GET /v1/events/stream` mantém conexão SSE aberta

### macOS
- [ ] Cmd+Shift+E abre/fecha o painel
- [ ] Evento atual aparece com barra de progresso
- [ ] Chat funciona com streaming
- [ ] Polls aparecem inline quando triggered

### iOS
- [ ] App abre com 4 tabs
- [ ] Painel mostra evento, timer, tasks
- [ ] Chat funciona com streaming
- [ ] Agenda mostra timeline do dia
- [ ] Insights mostra charts

### Web
- [ ] PWA abre no browser
- [ ] Layout responsivo (mobile bottom tabs, desktop sidebar)
- [ ] Chat streaming funciona
- [ ] Polls aparecem como modais

---

## Decisões tomadas

- **iOS sem Apple Developer Program**: app nativo via free provisioning, renova a cada 7 dias
- **Sem push em nenhuma plataforma mobile**: APNs requer Developer Program
- **PWA como backup no iPhone**: funciona mas app nativo é preferido
- **Backend no DO existente**: mesma infra do Telegram bot, PM2 + Nginx

---

## Arquivos importantes

| O que | Onde |
|-------|------|
| Backend (código) | `~/claude-sync/produtividade/` |
| Backend (API entry) | `~/claude-sync/produtividade/run_api.py` |
| macOS app | `~/projetos/erestor/ErestorApp/` |
| iOS app | mesmo projeto, scheme `ErestorApp-iOS` |
| Web PWA | `~/projetos/erestor/web/` |
| Planning/docs | `~/projetos/erestor/.planning/` |
| Milestone archive | `~/projetos/erestor/.planning/milestones/` |
| Migration script | `~/claude-sync/produtividade/migrate-history.py` |
| SQLite DB | `~/claude-sync/produtividade/erestor_events.db` |
