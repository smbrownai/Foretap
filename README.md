# Fore (Foretap)

A smart, section-based iOS app launcher that surfaces the right apps at the
right time — configured in seconds, not minutes.

## What it is

Fore replaces Apple's App Library as the primary app discovery and launching
surface on iPhone. Apps are organized into named sections (Pinned, Work,
Travel, etc.) that stack vertically. Each section type has its own sourcing
and ordering logic — manual lists, recently used, frequently used, time-based
windows, and Focus-mode-bound. Sections rise to the top automatically when
their context kicks in.

## Status

All required spec phases (1–5, 7, 8) shipped. Project is TestFlight-ready.

| Phase | Scope | Status |
|---|---|---|
| 1 | Data model + bundled app database (194 entries) | Done |
| 2 | iPhone UI: section stack, editor, add-apps flow | Done |
| 3 | Intelligence engine: priority score, auto sections | Done |
| 4 | Focus mode integration | Done |
| 5 | Three home-screen widgets + App Group plumbing | Done |
| 6 | iPadOS adaptation (NavigationSplitView, drag/drop) | Deferred |
| 7 | App Intents + Shortcuts + Siri | Done |
| 8 | Settings, onboarding, polish | Done |

## Stack

- **iOS 17+** (Swift 5.9+, Xcode 16+)
- **SwiftUI** for all UI
- **SwiftData** for persistence (no Core Data, no third-party DB)
- **WidgetKit** for the three home-screen widget sizes
- **AppIntents** for Shortcuts, Siri, and the `SetFocusFilterIntent`
- No external Swift Package dependencies

## Targets

| Target | Purpose |
|---|---|
| `Fore` | Main app, owns the SwiftData store and most intents |
| `ForeWidgetsExtension` | Three widget sizes + interactive `LaunchAppIntent` |
| `ForeIntentsExtension` | `SetFocusFilterIntent` host (out-of-process) |

All three share the App Group `group.com.shawnbrown.Fore` for cross-process
state: active focus name (file-backed in the App Group container), widget
snapshot (UserDefaults), and a pending-usage queue drained on app foreground.

## Project layout

```
Fore/
├── Model/        SwiftData @Model classes + enums
├── Database/     Bundled AppDatabase.json + loader
├── Engine/       UsageTracker, SectionSorter, FocusMonitor,
│                 FocusBridge, WidgetPublisher, UsageQueueDrain,
│                 DataExporter, DataReset
├── Store/        ForeStore (ModelContainer), SharedDefaults,
│                 SharedNotifications, SharedUsageQueue,
│                 WidgetSnapshot, AppPreferences
├── Intents/      LaunchAppIntent, OpenSectionIntent,
│                 AddAppToSectionIntent, LaunchSectionKitIntent,
│                 GetTopAppsIntent, ForeShortcutsProvider,
│                 IntentOptionsProviders
├── Views/        Home/, AddApps/, SectionEditor/, Settings/,
│                 Onboarding/, AppCategory+Style.swift
└── ForeApp.swift

ForeWidgets/      Widget bundle: ForeWidgetEntry, WidgetAppButton,
                  Small/Medium/LargeWidget

ForeIntents/      ForeFocusFilter (SetFocusFilterIntent)
```

## Building

1. Clone the repo.
2. Open `Fore.xcodeproj` in Xcode 16+.
3. Configure signing: each of the three targets needs **Automatic Signing**
   on, with your Apple Developer team selected.
4. App Group capability `group.com.shawnbrown.Fore` must be registered for
   the three App IDs in your developer account, and ticked on each target's
   **Signing & Capabilities** tab. (See `ERRORS.md` for the entitlement
   gotchas hit during initial setup.)
5. Build and run on a real device — widgets render fully only on hardware.

## Companion documents

These files at the repo root are working documents updated alongside the
code:

- [`SPEC.md`](SPEC.md) — authoritative product spec. Section, intent, and
  widget contracts. Read this before making non-trivial changes.
- [`PROGRESS.md`](PROGRESS.md) — current phase, what's done, decisions made,
  open items. Updated each session.
- [`ERRORS.md`](ERRORS.md) — log of every significant build / runtime error
  hit and how it was resolved. Useful before touching SwiftData schema,
  AppIntents conformance, or App Group plumbing — past pain is documented.

## Notable design decisions

- **`LauncherSection` time-window storage** uses scalar `Int?` hour/minute
  fields, not `DateComponents`. SwiftData can't reflect Calendar-bearing
  types. See ERRORS.md (2026-04-27).
- **Active focus value lives in a file** in the App Group container, not
  UserDefaults. cfprefsd cross-process propagation lags Darwin notifications
  by 100s of ms; file reads are immediately consistent. See ERRORS.md.
- **`AppEntry` records are created lazily** via `AddAppsView.commit()`, not
  pre-seeded from the bundled database. Keeps SwiftData lean.
- **Widgets render category SF Symbols + tints** in lieu of real app icons —
  iOS provides no public API to fetch installed-app icons.
- **Three intents (`OpenSection`, `AddAppToSection`, `LaunchSectionKit`,
  `GetTopApps`) live in the main app target**, not the intents extension —
  they need direct SwiftData access. The extension only hosts
  `ForeFocusFilter` so that iOS can invoke it during Focus state changes.

## License

Private project. Not open source.
