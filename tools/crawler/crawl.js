#!/usr/bin/env node
//
// Fore App Database Crawler
//
// Generates Fore/Database/AppDatabase.json by pulling top-N apps from
// every App Store genre via Apple's legacy iTunes RSS feed, then
// enriching each via the iTunes Lookup API to get bundle IDs, primary
// genres, and high-resolution artwork URLs. Known URL schemes from
// the existing AppDatabase.json (matched by app name) are preserved
// and stamped onto matching iTunes results.
//
// Usage:
//   node tools/crawler/crawl.js                     # full crawl (~5000 apps)
//   node tools/crawler/crawl.js --apps-count 1000   # smaller bundle
//   node tools/crawler/crawl.js --offline           # just migrate schema, no network
//   node tools/crawler/crawl.js --output path.json  # custom output
//
// No external dependencies; uses Node's built-in fetch.
//

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { GENRES, GENRE_TO_CATEGORY } from './genres.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_OUTPUT = path.join(REPO_ROOT, 'Fore', 'Database', 'AppDatabase.json');

// ---- CLI parsing ---------------------------------------------------------

const args = process.argv.slice(2);
const flags = {
  offline: args.includes('--offline'),
  output: arg('--output') || DEFAULT_OUTPUT,
  appsCount: parseInt(arg('--apps-count') || '5000', 10),
  country: arg('--country') || 'us',
  perGenreLimit: parseInt(arg('--per-genre') || '200', 10),
};

function arg(name) {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
}

// ---- HTTP helpers --------------------------------------------------------

async function fetchJson(url, attempt = 1) {
  try {
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'Fore-Crawler/1.0' },
    });
    if (resp.status === 429 && attempt < 4) {
      await sleep(1000 * attempt);
      return fetchJson(url, attempt + 1);
    }
    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status} for ${url}`);
    }
    return await resp.json();
  } catch (err) {
    if (attempt < 3) {
      await sleep(500 * attempt);
      return fetchJson(url, attempt + 1);
    }
    throw err;
  }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

// Apple ships artwork at multiple sizes. The /lookup response gives us
// 100x100; rewrite to a higher resolution for retina displays.
function bumpArtworkSize(url, size = 256) {
  if (!url) return null;
  return url.replace(/\d+x\d+bb\.(jpg|png)/, `${size}x${size}bb.$1`);
}

// ---- iTunes endpoints ----------------------------------------------------

// Apple's legacy RSS feed silently caps results at 100/genre regardless
// of `limit`, so we pull from three different chart types per genre and
// merge to broaden coverage.
const CHARTS = [
  'topfreeapplications',
  'toppaidapplications',
  'topgrossingapplications',
];

async function fetchTopApps(chart, genreId, country, limit) {
  const url = `https://itunes.apple.com/${country}/rss/${chart}/limit=${limit}/genre=${genreId}/json`;
  const data = await fetchJson(url);
  return data.feed?.entry ?? [];
}

async function lookupApps(trackIds, country) {
  if (trackIds.length === 0) return [];
  const ids = trackIds.join(',');
  const url = `https://itunes.apple.com/lookup?id=${ids}&country=${country}&limit=${trackIds.length}`;
  const data = await fetchJson(url);
  return data.results ?? [];
}

// ---- Existing database (for known-scheme merge) -------------------------

async function loadExisting(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const data = JSON.parse(content);
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
}

function normalizeName(name) {
  return (name || '')
    .toLowerCase()
    .replace(/[‘’']/g, '')         // smart quotes / apostrophes
    .replace(/[^a-z0-9]+/g, ' ')             // punctuation -> space
    .trim()
    .replace(/\s+/g, ' ');
}

const VENDOR_PREFIXES = [
  'microsoft', 'google', 'apple', 'amazon', 'meta', 'samsung',
];

function buildSchemeMap(existing) {
  // Map from a set of normalized name variants -> scheme. Multiple keys
  // can point at the same scheme so we can match permissively without
  // having to scan a list at lookup time.
  const map = new Map();
  for (const entry of existing) {
    const scheme = entry.urlScheme;
    if (!scheme) continue;
    const norm = normalizeName(entry.name);
    if (!norm) continue;
    map.set(norm, scheme);
    // Also register vendor-prefixed variants so an iTunes "Microsoft
    // Outlook" matches a curated "Outlook" entry.
    for (const v of VENDOR_PREFIXES) {
      map.set(`${v} ${norm}`, scheme);
    }
  }
  return map;
}

/// Try a few normalization strategies against the known-scheme map.
function findScheme(itunesName, knownSchemes) {
  const norm = normalizeName(itunesName);
  if (!norm) return null;
  if (knownSchemes.has(norm)) return knownSchemes.get(norm);
  // Strip a leading vendor prefix from the iTunes name and retry —
  // catches "Microsoft Outlook" / "Google Sheets" / etc. against curated
  // entries that omit the prefix.
  const tokens = norm.split(' ');
  if (tokens.length > 1 && VENDOR_PREFIXES.includes(tokens[0])) {
    const stripped = tokens.slice(1).join(' ');
    if (knownSchemes.has(stripped)) return knownSchemes.get(stripped);
  }
  return null;
}

// ---- Output construction -------------------------------------------------

function buildEntry(lookup, knownSchemes, today) {
  const name = lookup.trackName || lookup.collectionName || '';
  const scheme = findScheme(name, knownSchemes);
  const genre = lookup.primaryGenreName || null;
  return {
    id: lookup.bundleId || `track:${lookup.trackId}`,
    trackId: lookup.trackId ?? null,
    name,
    developer: lookup.artistName || null,
    primaryGenre: genre,
    category: GENRE_TO_CATEGORY[genre] || 'other',
    iconURL: bumpArtworkSize(lookup.artworkUrl100, 256),
    urlScheme: scheme,
    schemeSource: scheme ? 'official' : null,
    verifiedAt: scheme ? today : null,
  };
}

function migrateLegacyEntry(entry, today) {
  // Already in new schema (has `id`)? Pass through unchanged.
  if (entry.id && (entry.iconURL !== undefined || entry.developer !== undefined)) {
    return entry;
  }
  const scheme = entry.urlScheme || null;
  return {
    id: entry.id || (scheme ? `legacy:${scheme}` : `legacy:${entry.name}`),
    trackId: null,
    name: entry.name,
    developer: null,
    primaryGenre: null,
    category: entry.category || 'other',
    iconURL: null,
    urlScheme: scheme,
    schemeSource: scheme ? 'official' : null,
    verifiedAt: scheme ? today : null,
  };
}

// ---- Main ----------------------------------------------------------------

async function main() {
  const today = new Date().toISOString().slice(0, 10);
  const existing = await loadExisting(flags.output);
  const knownSchemes = buildSchemeMap(existing);
  console.log(`Loaded ${existing.length} existing entries (${knownSchemes.size} with schemes)`);

  if (flags.offline) {
    const migrated = existing.map(e => migrateLegacyEntry(e, today));
    await fs.writeFile(flags.output, JSON.stringify(migrated, null, 2));
    console.log(`Wrote ${migrated.length} migrated entries → ${flags.output}`);
    return;
  }

  // Phase 1: pull top apps per (chart, genre), dedupe by trackId,
  // keep best rank seen across charts.
  console.log(`\nFetching ${CHARTS.length} charts × ${GENRES.length} genres (limit ${flags.perGenreLimit} each)...`);
  const seen = new Map(); // trackId -> { firstRank, genres, charts }

  for (const genre of GENRES) {
    let added = 0;
    for (const chart of CHARTS) {
      let entries;
      try {
        entries = await fetchTopApps(chart, genre.id, flags.country, flags.perGenreLimit);
      } catch (err) {
        console.warn(`  ! ${genre.name} ${chart} failed: ${err.message}`);
        continue;
      }
      for (let rank = 0; rank < entries.length; rank++) {
        const trackId = parseInt(entries[rank].id?.attributes?.['im:id'] || '0', 10);
        if (!trackId) continue;
        if (!seen.has(trackId)) {
          seen.set(trackId, { firstRank: rank, genres: [genre.name], charts: [chart] });
          added++;
        } else {
          const cur = seen.get(trackId);
          if (rank < cur.firstRank) cur.firstRank = rank;
          if (!cur.genres.includes(genre.name)) cur.genres.push(genre.name);
          if (!cur.charts.includes(chart)) cur.charts.push(chart);
        }
      }
      await sleep(120);
    }
    console.log(`  ${genre.name.padEnd(24)} +${String(added).padStart(3)} (cumulative: ${seen.size})`);
  }

  // Phase 2: order by best chart rank, take top N, look up details.
  const sorted = [...seen.entries()]
    .sort((a, b) => a[1].firstRank - b[1].firstRank)
    .slice(0, flags.appsCount);

  console.log(`\nLooking up ${sorted.length} apps via /lookup (batches of 200)...`);
  const lookups = [];
  for (let i = 0; i < sorted.length; i += 200) {
    const batch = sorted.slice(i, i + 200).map(([id]) => id);
    try {
      const results = await lookupApps(batch, flags.country);
      lookups.push(...results);
    } catch (err) {
      console.warn(`  ! batch ${i}-${i + 200} failed: ${err.message}`);
    }
    process.stdout.write(`  ${lookups.length}/${sorted.length}\r`);
    await sleep(250);
  }
  console.log(`  ${lookups.length}/${sorted.length} done.\n`);

  // Phase 3: build output entries from iTunes lookups.
  const output = lookups
    .filter(r => r.kind === 'software' || r.wrapperType === 'software')
    .map(r => buildEntry(r, knownSchemes, today));

  // Phase 4: append legacy entries that didn't surface in iTunes results.
  // Skip a legacy entry if either (a) its scheme is already attached to
  // an iTunes row (the matcher succeeded — adding it again would be a
  // duplicate) or (b) its normalized name already exists in the output.
  const seenNames = new Set(output.map(e => normalizeName(e.name)));
  const seenSchemes = new Set(output.map(e => e.urlScheme).filter(Boolean));
  let legacyAdded = 0;
  for (const entry of existing) {
    const nameKey = normalizeName(entry.name);
    if (seenNames.has(nameKey)) continue;
    if (entry.urlScheme && seenSchemes.has(entry.urlScheme)) continue;
    output.push(migrateLegacyEntry(entry, today));
    legacyAdded++;
  }
  if (legacyAdded > 0) {
    console.log(`Preserved ${legacyAdded} curated entries not in iTunes top charts.`);
  }

  // Stats
  const withScheme = output.filter(e => e.urlScheme).length;
  const withIcon = output.filter(e => e.iconURL).length;
  console.log(`\nFinal: ${output.length} entries`);
  console.log(`  with URL scheme: ${withScheme} (${pct(withScheme, output.length)})`);
  console.log(`  with icon URL:   ${withIcon} (${pct(withIcon, output.length)})`);

  await fs.writeFile(flags.output, JSON.stringify(output, null, 2));
  const bytes = (await fs.stat(flags.output)).size;
  console.log(`Wrote ${output.length} entries (${(bytes / 1024 / 1024).toFixed(2)} MB) → ${flags.output}`);
}

function pct(n, total) {
  return total === 0 ? '0%' : `${((n / total) * 100).toFixed(1)}%`;
}

main().catch(err => {
  console.error('Crawl failed:', err);
  process.exit(1);
});
