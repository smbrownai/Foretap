#!/usr/bin/env node
//
// Fore URL Scheme Extractor
//
// For every entry in Fore/Database/AppDatabase.json that has a real
// bundle ID and no urlScheme, this script:
//
//   1. Downloads the IPA via `ipatool` (single-app at a time).
//   2. Streams Info.plist out of Payload/*.app/Info.plist.
//   3. Parses the (binary) plist with `plutil` and walks
//      CFBundleURLTypes -> CFBundleURLSchemes.
//   4. Picks the most-likely-launch scheme using simple heuristics.
//   5. Writes the result back into AppDatabase.json (and a state
//      file so the run resumes after Ctrl-C / crash / overnight stop).
//   6. Deletes the IPA from disk immediately — we only retain the
//      derived fact (name -> scheme).
//
// Throttling defaults to 10 downloads/minute with ±20% jitter.
// Tweak with --rate. Splitting across nights via --max is recommended
// for run sizes > ~2000.
//
// Setup is in tools/scheme-extractor/README.md. The TL;DR is:
//   brew tap majd/repo && brew install ipatool
//   ipatool auth login --email <personal Apple ID>
//
// Usage:
//   node tools/scheme-extractor/extract.js
//   node tools/scheme-extractor/extract.js --max 1500
//   node tools/scheme-extractor/extract.js --rate 6     # 6/min, slower
//   node tools/scheme-extractor/extract.js --resume     # continue from state
//   node tools/scheme-extractor/extract.js --dry-run    # show what would run
//

import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DB_PATH = path.join(REPO_ROOT, 'Fore', 'Database', 'AppDatabase.json');
const STATE_PATH = path.join(__dirname, 'extract.state.json');

// ---- CLI -----------------------------------------------------------------

const args = process.argv.slice(2);
const flags = {
  max: parseInt(arg('--max') || '0', 10) || Infinity,
  rate: parseFloat(arg('--rate') || '10'), // downloads per minute
  resume: args.includes('--resume'),
  dryRun: args.includes('--dry-run'),
  verbose: args.includes('--verbose'),
};

function arg(name) {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
}

// ---- Throttling ----------------------------------------------------------

const baseGap = 60_000 / flags.rate;          // ms between downloads
const jitterRange = baseGap * 0.4;            // ±20%
function nextGap() {
  const jitter = (Math.random() - 0.5) * jitterRange;
  return Math.max(2000, Math.round(baseGap + jitter));
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

// ---- Shell helper --------------------------------------------------------

function exec(cmd, args, opts = {}) {
  return new Promise(resolve => {
    const child = spawn(cmd, args, { ...opts });
    let stdout = '';
    let stderr = '';
    child.stdout?.on('data', d => (stdout += d));
    child.stderr?.on('data', d => (stderr += d));
    child.on('error', err => resolve({ code: -1, stdout, stderr: stderr + '\n' + err.message }));
    child.on('close', code => resolve({ code, stdout, stderr }));
  });
}

// ---- IPA -> scheme pipeline ---------------------------------------------

async function downloadIPA(bundleId, dir) {
  // ipatool writes <bundleId>_<version>.ipa to --output
  const result = await exec('ipatool', [
    'download',
    '--bundle-identifier', bundleId,
    '--output', dir,
    '--non-interactive',
    '--format', 'json',
  ]);
  if (result.code !== 0) {
    return { ok: false, error: result.stderr.trim().split('\n').slice(-1)[0] };
  }
  const files = await fs.readdir(dir);
  const ipa = files.find(f => f.endsWith('.ipa'));
  return ipa ? { ok: true, path: path.join(dir, ipa) } : { ok: false, error: 'No .ipa file produced' };
}

async function findInfoPlistEntry(ipaPath) {
  // List archive contents, find Payload/*.app/Info.plist (top-level only).
  const result = await exec('unzip', ['-Z', '-1', ipaPath]);
  if (result.code !== 0) return null;
  const lines = result.stdout.split('\n');
  return lines.find(l => /^Payload\/[^/]+\.app\/Info\.plist$/.test(l)) || null;
}

async function extractInfoPlist(ipaPath, entry, outPath) {
  // Stream the single Info.plist out of the zip.
  const child = spawn('unzip', ['-p', ipaPath, entry], { stdio: ['ignore', 'pipe', 'pipe'] });
  const out = await fs.open(outPath, 'w');
  await new Promise((resolve, reject) => {
    child.stdout.on('data', chunk => out.write(chunk));
    child.on('error', reject);
    child.on('close', code => (code === 0 ? resolve() : reject(new Error(`unzip exited ${code}`))));
  });
  await out.close();
}

async function readSchemes(infoPlistPath) {
  // plutil ships with macOS; converts binary plist to JSON we can parse.
  const result = await exec('plutil', ['-convert', 'json', '-o', '-', infoPlistPath]);
  if (result.code !== 0) return null;
  let plist;
  try {
    plist = JSON.parse(result.stdout);
  } catch {
    return null;
  }
  const types = Array.isArray(plist.CFBundleURLTypes) ? plist.CFBundleURLTypes : [];
  const all = [];
  for (const t of types) {
    if (Array.isArray(t.CFBundleURLSchemes)) {
      for (const s of t.CFBundleURLSchemes) {
        if (typeof s === 'string' && s.length > 0) all.push(s);
      }
    }
  }
  return all;
}

// Heuristics: the "real" launch scheme is usually short, alphanumeric,
// and not an SDK/OAuth callback. We rank schemes and take the best.
function pickBestScheme(schemes, name) {
  if (!schemes || !schemes.length) return null;

  const isObviousJunk = s => {
    if (s.includes('.') && /^[a-z0-9.-]+$/i.test(s)) return true;     // bundle-id-style
    if (/^fb\d+$/i.test(s)) return true;                               // Facebook SDK
    if (/^fb-messenger/i.test(s)) return true;
    if (/^twitterkit-/i.test(s)) return true;
    if (/^pin\d+$/i.test(s)) return true;                              // Pinterest SDK
    if (/^com\.googleusercontent/i.test(s)) return true;
    if (/^msauth/i.test(s)) return true;                               // MSAL OAuth
    if (/^msal/i.test(s)) return true;
    if (/oauth|callback|signin/i.test(s)) return true;
    if (/^x-msauth/i.test(s)) return true;
    if (/^auth0$/i.test(s)) return true;
    if (s.length > 30) return true;                                    // probably internal
    return false;
  };

  const candidates = schemes.filter(s => !isObviousJunk(s));
  const pool = candidates.length > 0 ? candidates : schemes;

  // Prefer name-prefix matches first (e.g. "spotify" for Spotify).
  const nameKey = (name || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
  pool.sort((a, b) => {
    const aMatch = nameKey && a.toLowerCase().replace(/[^a-z0-9]+/g, '').startsWith(nameKey) ? -1 : 0;
    const bMatch = nameKey && b.toLowerCase().replace(/[^a-z0-9]+/g, '').startsWith(nameKey) ? -1 : 0;
    if (aMatch !== bMatch) return aMatch - bMatch;
    return a.length - b.length;
  });
  return pool[0];
}

async function extractSchemeForBundle(bundleId, name) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'fore-extract-'));
  try {
    const dl = await downloadIPA(bundleId, dir);
    if (!dl.ok) return { ok: false, reason: dl.error || 'download failed' };

    const entry = await findInfoPlistEntry(dl.path);
    if (!entry) return { ok: false, reason: 'no Info.plist in IPA' };

    const plistPath = path.join(dir, 'Info.plist');
    try {
      await extractInfoPlist(dl.path, entry, plistPath);
    } catch (err) {
      return { ok: false, reason: `unzip: ${err.message}` };
    }

    const schemes = await readSchemes(plistPath);
    if (!schemes) return { ok: false, reason: 'plist parse failed' };
    if (schemes.length === 0) return { ok: true, scheme: null, schemes: [] };

    const picked = pickBestScheme(schemes, name);
    return { ok: true, scheme: picked ? `${picked}://` : null, schemes };
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

// ---- State persistence ---------------------------------------------------

async function loadState() {
  try {
    const raw = await fs.readFile(STATE_PATH, 'utf8');
    return JSON.parse(raw);
  } catch {
    return { processed: {}, stats: { ok: 0, noScheme: 0, failed: 0 } };
  }
}

async function saveState(state) {
  await fs.writeFile(STATE_PATH, JSON.stringify(state, null, 2));
}

async function loadDB() {
  const raw = await fs.readFile(DB_PATH, 'utf8');
  return JSON.parse(raw);
}

async function saveDB(db) {
  await fs.writeFile(DB_PATH, JSON.stringify(db, null, 2));
}

// ---- Main ----------------------------------------------------------------

async function main() {
  // Pre-flight: confirm ipatool + plutil + unzip are present.
  for (const tool of ['ipatool', 'plutil', 'unzip']) {
    const probe = await exec('which', [tool]);
    if (probe.code !== 0) {
      console.error(`ERROR: '${tool}' not found in PATH. See tools/scheme-extractor/README.md.`);
      process.exit(1);
    }
  }

  // Sanity-check that ipatool is signed in.
  const auth = await exec('ipatool', ['auth', 'info', '--format', 'json']);
  if (auth.code !== 0) {
    console.error("ERROR: ipatool not signed in. Run 'ipatool auth login --email <apple-id>'.");
    process.exit(1);
  }

  const db = await loadDB();
  const state = flags.resume ? await loadState() : { processed: {}, stats: { ok: 0, noScheme: 0, failed: 0 } };

  // Build the work queue: real bundle IDs, no scheme yet, not already processed.
  const queue = db.filter(e =>
    typeof e.id === 'string'
    && !e.id.startsWith('legacy:')
    && !e.id.startsWith('track:')
    && (!e.urlScheme || e.urlScheme.length === 0)
    && !state.processed[e.id]
  );
  const target = queue.slice(0, flags.max);

  console.log(`Database has ${db.length} entries.`);
  console.log(`Queue: ${queue.length} unresolved bundle IDs (processing ${target.length}).`);
  console.log(`Rate: ${flags.rate}/min (~${(baseGap / 1000).toFixed(1)}s ± jitter between downloads).`);
  console.log(`State file: ${STATE_PATH}`);

  if (flags.dryRun) {
    for (const entry of target.slice(0, 20)) {
      console.log(`  ${entry.id.padEnd(40)} ${entry.name}`);
    }
    if (target.length > 20) console.log(`  …and ${target.length - 20} more`);
    return;
  }
  if (target.length === 0) {
    console.log('Nothing to do.');
    return;
  }

  const today = new Date().toISOString().slice(0, 10);
  const dbById = new Map(db.map(e => [e.id, e]));

  // Persist DB + state every N successes so a crash doesn't lose work.
  const SAVE_EVERY = 25;
  let sinceSave = 0;
  const startedAt = Date.now();

  for (let i = 0; i < target.length; i++) {
    const entry = target[i];
    const elapsed = ((Date.now() - startedAt) / 1000 / 60).toFixed(1);
    const prefix = `[${i + 1}/${target.length}  ${elapsed}m  ok=${state.stats.ok}  none=${state.stats.noScheme}  fail=${state.stats.failed}]`;

    let line = `${prefix} ${entry.name.padEnd(40).slice(0, 40)}  ${entry.id}`;

    let result;
    try {
      result = await extractSchemeForBundle(entry.id, entry.name);
    } catch (err) {
      result = { ok: false, reason: err.message };
    }

    if (result.ok && result.scheme) {
      const dbEntry = dbById.get(entry.id);
      if (dbEntry) {
        dbEntry.urlScheme = result.scheme;
        dbEntry.schemeSource = 'extracted';
        dbEntry.verifiedAt = today;
      }
      state.stats.ok++;
      console.log(`${line}  →  ${result.scheme}`);
    } else if (result.ok && !result.scheme) {
      state.stats.noScheme++;
      console.log(`${line}  →  (no usable scheme)`);
    } else {
      state.stats.failed++;
      console.log(`${line}  ✗  ${result.reason}`);
    }
    state.processed[entry.id] = result.scheme || (result.ok ? 'NONE' : 'FAILED');

    sinceSave++;
    if (sinceSave >= SAVE_EVERY) {
      await saveDB(db);
      await saveState(state);
      sinceSave = 0;
    }

    if (i < target.length - 1) {
      await sleep(nextGap());
    }
  }

  // Final write
  await saveDB(db);
  await saveState(state);

  console.log('\nDone.');
  console.log(`  schemes added: ${state.stats.ok}`);
  console.log(`  no scheme:     ${state.stats.noScheme}`);
  console.log(`  failed:        ${state.stats.failed}`);
  console.log(`  database:      ${DB_PATH}`);
}

main().catch(err => {
  console.error('extract failed:', err);
  process.exit(1);
});
