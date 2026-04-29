# Fore App Database Crawler

Generates `Fore/Database/AppDatabase.json` by pulling top apps from every
App Store genre via Apple's iTunes RSS feed and enriching each entry
through the iTunes Lookup API.

The output JSON is bundled with the iOS app and powers the **Add Apps**
picker. Each entry carries:

| field          | source                              | notes                               |
| -------------- | ----------------------------------- | ----------------------------------- |
| `id`           | iTunes `bundleId` (or `legacy:…`)   | stable primary key                  |
| `trackId`      | iTunes RSS / Lookup                 | numeric App Store ID                |
| `name`         | iTunes `trackName`                  |                                     |
| `developer`    | iTunes `artistName`                 |                                     |
| `primaryGenre` | iTunes `primaryGenreName`           | App Store top-level genre           |
| `category`     | mapped via `genres.js`              | internal `AppCategory`              |
| `iconURL`      | iTunes artwork @ 256×256            |                                     |
| `urlScheme`    | merged from prior `AppDatabase.json`| nullable; users supply via Custom App |
| `schemeSource` | `official` / `community` / `null`   | provenance for future moderation    |
| `verifiedAt`   | ISO date                            | when scheme was last seen           |

## Usage

```
# From repo root
node tools/crawler/crawl.js                 # full crawl, ~5000 apps
node tools/crawler/crawl.js --apps-count 1000
node tools/crawler/crawl.js --offline       # just migrate schema, no network
node tools/crawler/crawl.js --country gb    # different App Store storefront
```

No npm install needed — uses Node 18+ built-in `fetch`.

A full run takes ~3 minutes and writes ~2–4 MB to
`Fore/Database/AppDatabase.json`.

## How URL schemes get filled in

The crawler reads the existing `AppDatabase.json` before overwriting it
and builds a name-keyed map of every previously known `urlScheme`. When
an iTunes result's `trackName` matches a known name (case-insensitive),
the scheme is carried over. Everything else gets `urlScheme: null` —
the iOS app shows those entries as "Tap to add a URL scheme" and routes
the user into Add Custom App with the name pre-filled.

This means the curated 194 schemes we already have are preserved, and
the database grows over time as you re-run the crawler with newer
known-scheme inputs (e.g. from community submissions in Phase C).

## Re-running

Re-run quarterly, or whenever you add new schemes manually to the JSON.
The crawler is idempotent: legacy entries that don't appear in iTunes
top charts are preserved so curated rows never get dropped.
