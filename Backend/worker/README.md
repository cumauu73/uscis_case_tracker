# My Case Updates API

Cloudflare Worker backend for the iOS app. The public app calls this API, and this API calls USCIS with server-side credentials.

## Local Setup

```bash
cd Backend/worker
npm install
npm run check
```

For local mock responses, create `Backend/worker/.dev.vars`:

```text
MOCK_USCIS_RESPONSES=true
```

Then run:

```bash
npm run dev
```

Test:

```bash
curl http://localhost:8787/health
curl http://localhost:8787/v1/cases/IOE0912345678
```

## Production Secrets

Set these in Cloudflare Worker settings or with Wrangler secrets:

```bash
npx wrangler secret put USCIS_TOKEN_URL
npx wrangler secret put USCIS_CLIENT_ID
npx wrangler secret put USCIS_CLIENT_SECRET
```

Set non-secret variables in `wrangler.jsonc` or the Cloudflare dashboard:

```text
USCIS_BASE_URL
USCIS_CASE_STATUS_PATH_TEMPLATE
USCIS_SCOPE
CACHE_TTL_SECONDS
MOCK_USCIS_RESPONSES=false
```

The current `USCIS_CASE_STATUS_PATH_TEMPLATE` is a placeholder. Replace it with the exact USCIS sandbox/production path from the USCIS Developer Portal.

## Deploy

```bash
cd Backend/worker
npx wrangler login
npm run deploy
```

In Cloudflare Dashboard:

1. Go to Workers & Pages.
2. Open `mycaseupdates-api`.
3. Go to Settings.
4. Add Custom Domain: `api.mycaseupdates.app`.
5. Add the required variables and secrets.

## API Contract

```text
GET /v1/cases/:receiptNumber
```

Response:

```json
{
  "receiptNumber": "IOE0912345678",
  "formType": "USCIS Case",
  "title": "Case Status Check Ready",
  "description": "Mock response from the My Case Updates API.",
  "updatedAt": "2026-07-29T00:00:00.000Z"
}
```
