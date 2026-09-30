# WAVE Telegram ingest

Zero-cost Telegram → WAVE movie ingestion. Uses Telegram’s official client API (gram.js) and a local caption parser. No paid AI, no Kurdlogs Core, no scraping of Telegram Desktop.

## Setup

```bash
cd telegram_ingest
cp .env.example .env
# fill TELEGRAM_API_ID / HASH from https://my.telegram.org
# set TELEGRAM_CHANNEL to the allowed channel (@username or -100id)
# set ADMIN_TOKEN to a long random secret
npm install
npm run login
# paste TELEGRAM_SESSION into .env
npm start
```

On a VPS, `better-sqlite3` needs a working C++ toolchain (`build-essential` / Windows Build Tools).

## Historical import

```bash
curl -X POST http://127.0.0.1:8787/api/admin/telegram/import \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"limit\":176}"
```

Last 10 / 50 / 100: send `"limit": 10` (or 50 / 100).

## Live monitoring

```bash
curl -X POST http://127.0.0.1:8787/api/admin/telegram/monitor/start \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

Or set `TELEGRAM_MONITOR_ON_START=true`.

## Tests

```bash
npm test
```

Videos stay on Telegram. The Flutter app only talks to this backend (`GET /api/movies/:id/play`).
