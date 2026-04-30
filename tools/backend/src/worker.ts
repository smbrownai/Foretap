// Fore backend — single Cloudflare Worker handling:
//
//   POST /v1/schemes        client reports (bundleId, scheme) it just launched
//   GET  /v1/apps.json.gz   latest gzipped database for clients to refresh
//   POST /admin/promote     (auth-gated) merge verified submissions into R2
//
// Storage bindings:
//   DB        D1 database   submissions + verified-schemes view
//   APPS_R2   R2 bucket     stores apps.json.gz for client downloads
//
// Secrets:
//   ADMIN_TOKEN   shared secret required to call /admin/promote
//
// All client traffic is rate-limited per anonymous_device_id; abuse
// detection is intentionally simple — promote() requires ≥3 distinct
// devices, so a single bad actor can't single-handedly poison entries.

export interface Env {
  DB: D1Database;
  APPS_R2: R2Bucket;
  ADMIN_TOKEN: string;
}

interface SubmissionBody {
  bundleId: string;
  scheme: string;
  name?: string;
  anonymousDeviceID: string;
  clientVersion?: string;
}

interface DBEntry {
  id: string;
  trackId: number | null;
  name: string;
  developer: string | null;
  primaryGenre: string | null;
  category: string;
  iconURL: string | null;
  urlScheme: string | null;
  schemeSource: string | null;
  verifiedAt: string | null;
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization',
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    try {
      if (request.method === 'POST' && url.pathname === '/v1/schemes') {
        return await handleSubmit(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/v1/apps.json.gz') {
        return await handleGetDatabase(env);
      }
      if (request.method === 'POST' && url.pathname === '/admin/promote') {
        return await handlePromote(request, env);
      }
      if (request.method === 'GET' && url.pathname === '/healthz') {
        return json({ ok: true }, 200);
      }
    } catch (err) {
      return json({ error: 'internal', detail: String(err) }, 500);
    }

    return json({ error: 'not_found' }, 404);
  },
};

// ---- POST /v1/schemes ---------------------------------------------------

async function handleSubmit(request: Request, env: Env): Promise<Response> {
  let body: SubmissionBody;
  try {
    body = (await request.json()) as SubmissionBody;
  } catch {
    return json({ error: 'invalid_body' }, 400);
  }

  // Basic input validation. Every field has a tight cap so a single
  // submission can't waste much storage.
  const bundleId = sanitize(body.bundleId, 200);
  const scheme = sanitize(body.scheme, 100);
  const name = sanitize(body.name, 200, true);
  const deviceID = sanitize(body.anonymousDeviceID, 128);
  const clientVersion = sanitize(body.clientVersion, 32, true);

  if (!bundleId || !scheme || !deviceID) {
    return json({ error: 'missing_fields' }, 400);
  }
  if (!/^[a-zA-Z][a-zA-Z0-9+\-.]*:\/\//.test(scheme)) {
    return json({ error: 'invalid_scheme' }, 400);
  }
  if (!/^[a-zA-Z0-9.\-_]+$/.test(bundleId)) {
    return json({ error: 'invalid_bundle_id' }, 400);
  }
  if (deviceID.length < 32) {
    return json({ error: 'invalid_device_id' }, 400);
  }

  const now = Math.floor(Date.now() / 1000);

  // Cheap rate gate: if this device is on a tear, bounce.
  const stats = await env.DB.prepare(
    'SELECT total_submissions, last_seen FROM device_stats WHERE anonymous_device_id = ?'
  )
    .bind(deviceID)
    .first<{ total_submissions: number; last_seen: number }>();

  if (stats && stats.total_submissions > 200 && now - stats.last_seen < 60) {
    return json({ error: 'rate_limited' }, 429);
  }

  // Upsert the submission. UNIQUE(bundle_id, scheme, device) means a
  // device re-submitting the same pair is a no-op insert.
  await env.DB.batch([
    env.DB
      .prepare(
        `INSERT OR IGNORE INTO submissions
           (bundle_id, scheme, app_name, anonymous_device_id, client_version, submitted_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(bundleId, scheme, name, deviceID, clientVersion, now),
    env.DB
      .prepare(
        `INSERT INTO device_stats (anonymous_device_id, total_submissions, first_seen, last_seen)
         VALUES (?, 1, ?, ?)
         ON CONFLICT(anonymous_device_id) DO UPDATE SET
           total_submissions = total_submissions + 1,
           last_seen = excluded.last_seen`
      )
      .bind(deviceID, now, now),
  ]);

  // Tell the client whether this pair is now verified — useful for
  // future client-side UX ("thanks, this scheme is now confirmed").
  const row = await env.DB.prepare(
    `SELECT COUNT(DISTINCT anonymous_device_id) AS device_count
       FROM submissions
      WHERE bundle_id = ? AND scheme = ?`
  )
    .bind(bundleId, scheme)
    .first<{ device_count: number }>();

  return json({ ok: true, deviceCount: row?.device_count ?? 1 }, 200);
}

// ---- GET /v1/apps.json.gz ----------------------------------------------

async function handleGetDatabase(env: Env): Promise<Response> {
  const obj = await env.APPS_R2.get('apps.json.gz');
  if (!obj) {
    // R2 has nothing yet; clients fall back to bundled.
    return new Response('not_found', { status: 404, headers: CORS });
  }

  return new Response(obj.body, {
    status: 200,
    headers: {
      ...CORS,
      'content-type': 'application/json',
      'content-encoding': 'gzip',
      'cache-control': 'public, max-age=86400, s-maxage=3600',
      'etag': obj.httpEtag,
    },
  });
}

// ---- POST /admin/promote -----------------------------------------------
// Reads the bundled AppDatabase.json from R2 (uploaded out-of-band
// after each crawler run), folds in any community-verified schemes
// the bundled JSON doesn't already have, gzips, and writes it back
// to apps.json.gz for clients to fetch.
//
// Trigger this whenever the curated DB has been updated, or on a
// cron tick (Workers Cron Triggers, free).

async function handlePromote(request: Request, env: Env): Promise<Response> {
  const auth = request.headers.get('authorization');
  if (auth !== `Bearer ${env.ADMIN_TOKEN}`) {
    return json({ error: 'unauthorized' }, 401);
  }

  const baseObj = await env.APPS_R2.get('base/AppDatabase.json');
  if (!baseObj) {
    return json({ error: 'no_base_db' }, 500);
  }

  const baseText = await baseObj.text();
  let entries: DBEntry[];
  try {
    entries = JSON.parse(baseText);
  } catch {
    return json({ error: 'base_db_parse_failed' }, 500);
  }

  // Pull every verified (bundle_id, scheme) pair.
  const verified = await env.DB.prepare(
    'SELECT bundle_id, scheme, app_name, device_count FROM verified_schemes'
  ).all<{
    bundle_id: string;
    scheme: string;
    app_name: string | null;
    device_count: number;
  }>();

  // Index existing entries by id (bundleId) for fast merge.
  const byID = new Map(entries.map(e => [e.id, e]));
  const today = new Date().toISOString().slice(0, 10);

  let added = 0;
  let updated = 0;
  for (const v of verified.results ?? []) {
    const existing = byID.get(v.bundle_id);
    if (existing) {
      if (!existing.urlScheme) {
        existing.urlScheme = v.scheme;
        existing.schemeSource = 'community';
        existing.verifiedAt = today;
        updated++;
      }
    } else {
      // Bundle ID not in our crawled set — append a minimal entry.
      // Future enhancement: enrich via iTunes Lookup. For now, the
      // client can render with the fallback icon and the typed name.
      entries.push({
        id: v.bundle_id,
        trackId: null,
        name: v.app_name ?? v.bundle_id,
        developer: null,
        primaryGenre: null,
        category: 'other',
        iconURL: null,
        urlScheme: v.scheme,
        schemeSource: 'community',
        verifiedAt: today,
      });
      added++;
    }
  }

  // Gzip and upload.
  const json = JSON.stringify(entries);
  const gz = await gzipString(json);
  await env.APPS_R2.put('apps.json.gz', gz, {
    httpMetadata: { contentType: 'application/json', contentEncoding: 'gzip' },
  });

  return jsonResp({
    ok: true,
    totalEntries: entries.length,
    added,
    updated,
    verifiedPairs: verified.results?.length ?? 0,
  }, 200);
}

// ---- helpers ------------------------------------------------------------

function sanitize(value: unknown, maxLen: number, allowEmpty = false): string {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim().slice(0, maxLen);
  return allowEmpty ? trimmed : trimmed;
}

function json(obj: unknown, status: number): Response {
  return jsonResp(obj, status);
}

function jsonResp(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'content-type': 'application/json' },
  });
}

async function gzipString(s: string): Promise<ArrayBuffer> {
  const cs = new CompressionStream('gzip');
  const writer = cs.writable.getWriter();
  void writer.write(new TextEncoder().encode(s));
  void writer.close();
  return await new Response(cs.readable).arrayBuffer();
}
