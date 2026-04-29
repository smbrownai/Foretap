# Fore URL Scheme Extractor

Fills in `urlScheme` for the thousands of `Fore/Database/AppDatabase.json`
entries that the iTunes API can't tell us about. For each unresolved
entry it downloads the IPA via `ipatool`, reads `Info.plist`'s
`CFBundleURLTypes`, picks the most-likely launch scheme, writes it
back into the database, and discards the IPA.

URL schemes are facts; the iOS app only ships the derived
`(name, scheme)` lookup table. We don't redistribute anyone's binary.

## One-time setup

```sh
# macOS
brew tap majd/repo
brew install ipatool

# Sign in with a personal Apple ID (NOT the developer account that
# distributes Foretap — keeps any abuse-flagging away from the dev
# account):
ipatool auth login --email your.personal@example.com
# Enter password + 2FA code when prompted.
```

You also need `unzip` (built in on macOS) and `plutil` (also built in).
Node 18+ is required (uses built-in `fetch`/spawn, no npm deps).

## Running

From the repo root:

```sh
# Default: 10 downloads/min with ±20% jitter, full queue.
node tools/scheme-extractor/extract.js

# Cap the run (good for splitting across nights).
node tools/scheme-extractor/extract.js --max 1500

# Slower if you want to be extra cautious.
node tools/scheme-extractor/extract.js --rate 6

# See what would run without downloading anything.
node tools/scheme-extractor/extract.js --dry-run

# Resume after Ctrl-C / reboot / overnight stop.
node tools/scheme-extractor/extract.js --resume
```

Progress is checkpointed every 25 downloads to
`tools/scheme-extractor/extract.state.json` and to the database itself,
so an interruption costs at most a handful of redos.

## Recommended flow

For a full ~5,000-entry pass against a personal Apple ID, splitting
across three nights at 10/min keeps the per-window rate and the
per-account total looking natural:

```sh
# Night 1
node tools/scheme-extractor/extract.js --max 1800

# Night 2 (and 3)
node tools/scheme-extractor/extract.js --resume --max 1800
```

Each chunk is roughly 3 hours.

## What gets picked

`Info.plist`'s `CFBundleURLTypes` typically lists multiple schemes per
app — the launch scheme plus a pile of OAuth callbacks, SDK identifiers,
etc. The picker filters out:

- bundle-ID-style schemes (`com.foo.bar`)
- Facebook SDK app IDs (`fb1234567890`)
- `fb-messenger-*`, `twitterkit-*`, `pin*`, `com.googleusercontent.*`
- Microsoft Auth (`msauth*`, `msal*`)
- anything containing `oauth`, `callback`, `signin`
- anything longer than 30 characters

…then picks the shortest remaining scheme, preferring one that starts
with a normalized form of the app name. Failing all that, the shortest
scheme of any kind is used.

About 50–60% of apps publish a usable scheme; the rest only support
universal links and have to be added through Add Custom App with a
universal link domain (or skipped entirely).

## Risk reminders

- Use a personal Apple ID, not the dev account.
- Default 10/min with jitter is the recommended starting point — much
  slower than `ipatool` is capable of, deliberately.
- Each `ipatool download` counts as a "purchase" against your Apple ID
  even for free apps. 5,000 in a day is the kind of pattern that *can*
  trigger a velocity flag. Splitting across nights mitigates that.
- The script never retains IPAs — every download is unzipped, parsed,
  and deleted before moving on.
