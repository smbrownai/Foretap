# Fore Backend (Phase B + C)

A single Cloudflare Worker that:

- **`POST /v1/schemes`** — accepts client submissions of
  `(bundleId, scheme, name)` pairs that the client just verified by
  successfully launching. Stores each submission with an anonymous
  per-install device hash; once ≥3 distinct devices report the same
  pair, it's considered community-verified.
- **`GET /v1/apps.json.gz`** — serves the latest gzipped
  `AppDatabase.json` for the iOS client to refresh from. Bundled
  database is the always-available fallback if this 404s.
- **`POST /admin/promote`** (auth-gated) — folds every
  community-verified pair into the base database, gzips, and uploads
  to R2 for clients to fetch. Runs on a daily cron and can be
  invoked manually after each crawler run.

Free tier covers an absurd amount of traffic:

| service          | free tier (per month)         |
| ---------------- | ----------------------------- |
| Workers requests | 100k requests/day             |
| D1 storage       | 5 GB                          |
| D1 reads         | 5M rows/day                   |
| R2 storage       | 10 GB                         |
| R2 egress        | 1 GB free → unlimited at $0   |

## One-time setup

```sh
# From repo root
cd tools/backend
npm install                 # installs wrangler + workers-types

# Sign in to Cloudflare (opens a browser).
npx wrangler login
```

### Create resources

```sh
# 1. D1 database
npx wrangler d1 create fore-db
# Copy the printed `database_id = "..."` into wrangler.toml.

# 2. Run schema migration
npm run migrate

# 3. R2 bucket
npx wrangler r2 bucket create fore-db

# 4. Set admin secret (for /admin/promote)
# Pick a random 32+ char token. Store it somewhere too.
npx wrangler secret put ADMIN_TOKEN
```

### Upload the base database

The promote job merges client submissions into a base database that
the crawler produces. Upload (or re-upload) it whenever you re-run
the crawler:

```sh
npm run upload-base
```

### Deploy

```sh
npm run deploy
# Worker URL is printed: https://fore-db.<account>.workers.dev
```

Set the iOS client's `databaseRefreshURL` to
`https://<your-domain>/v1/apps.json.gz` and `submissionURL` to
`https://<your-domain>/v1/schemes`.

### First promote

Trigger one manually so `apps.json.gz` exists for the client to fetch:

```sh
WORKER_URL=https://fore-db.<account>.workers.dev \
ADMIN_TOKEN=<your-token> \
npm run promote
```

After that, the daily 04:17 UTC cron handles it.

## How submissions become verified schemes

1. iOS user adds a custom app, supplies a URL scheme.
2. They later tap the icon. iOS opens the app, `UIApplication.open`
   returns `true`. That's the verification signal.
3. Client `POST`s `(bundleId, scheme, name, deviceHash)` to
   `/v1/schemes`. Worker upserts into `submissions`.
4. Once 3+ distinct devices have reported the same `(bundleId, scheme)`
   pair, the SQL view `verified_schemes` includes it.
5. The next `/admin/promote` cron tick merges new verified pairs into
   `apps.json.gz` on R2.
6. iOS clients on app launch / once a week pull the new `apps.json.gz`,
   cache it, and prefer it over the bundled database. Custom App rows
   that newly have community schemes light up.

## Privacy

We don't store user identities, IPs, or any PII. The "anonymous device
ID" is a SHA-256 of a per-install UUID stored in the iOS Keychain
locally; the server only ever sees the hash. Its only purpose is the
"≥3 distinct devices" verification gate. Clients can be opted out
entirely via Settings → Help build the catalog.

## Local development

```sh
npm run migrate:local       # local D1 migration
npm run dev                 # wrangler dev with local D1 + R2 bindings
```
