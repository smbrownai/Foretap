-- Submissions of (bundle_id, scheme) pairs from clients. Each row is a
-- single device's claim that this scheme launches this app. Anonymous
-- device id is a SHA-256 of a per-install UUID stored in the iOS
-- Keychain; we use it only to dedupe — never to track.
CREATE TABLE IF NOT EXISTS submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bundle_id TEXT NOT NULL,
  scheme TEXT NOT NULL,
  app_name TEXT,
  anonymous_device_id TEXT NOT NULL,
  client_version TEXT,
  submitted_at INTEGER NOT NULL,
  UNIQUE(bundle_id, scheme, anonymous_device_id)
);

CREATE INDEX IF NOT EXISTS idx_submissions_pair ON submissions(bundle_id, scheme);
CREATE INDEX IF NOT EXISTS idx_submissions_bundle ON submissions(bundle_id);

-- Aggregate view: any (bundle_id, scheme) pair confirmed by ≥3
-- distinct devices is treated as community-verified. The promotion
-- pass that publishes apps.json.gz to R2 reads this view.
CREATE VIEW IF NOT EXISTS verified_schemes AS
  SELECT bundle_id,
         scheme,
         MAX(app_name) AS app_name,
         COUNT(DISTINCT anonymous_device_id) AS device_count,
         MIN(submitted_at) AS first_seen,
         MAX(submitted_at) AS last_seen
    FROM submissions
   GROUP BY bundle_id, scheme
  HAVING device_count >= 3;

-- Tiny abuse-tracking table: per-device submission counts so we can
-- spot a single device flooding low-quality schemes. Cheap to maintain
-- inline on each insert.
CREATE TABLE IF NOT EXISTS device_stats (
  anonymous_device_id TEXT PRIMARY KEY,
  total_submissions INTEGER NOT NULL DEFAULT 0,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);
