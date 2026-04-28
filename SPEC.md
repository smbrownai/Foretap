# Fore — Product Specification
## Working Document for Claude Code
### Version 1.0 — April 2026

---

## How to Use This Document

This is the authoritative spec for the Fore iOS/iPadOS app. Read it fully before writing any code. When resuming a session, read this file plus `PROGRESS.md` to orient yourself. When you encounter ambiguity not covered here, make a reasonable decision, implement it, and note the decision in `PROGRESS.md` under "Decisions Made."

Do not invent features not described here. Do not add dependencies not listed in the Frameworks section. Ask before deviating from the architecture described below.

---

## 1. Product Overview

### What Fore Is
Fore is an iOS and iPadOS app launcher that replaces the native App Library as the user's primary app discovery and launching surface. It presents apps in user-defined, named sections — each with its own sorting logic — accessible via a home screen widget and a full in-app interface.

### The Core Problem Being Solved
Apple's App Library has three failures:
1. **Passive discovery** — it doesn't surface what the user needs right now
2. **Painful organization** — drag-and-drop on a small screen, no bulk operations, no intelligence
3. **One flat model** — no concept of context, recency, frequency, or intent running simultaneously

Fore solves all three with a section-based model, checkbox-driven app selection, and a scoring engine that learns from real usage.

### The Value Proposition (One Sentence)
> A smart, section-based app launcher that surfaces the right apps at the right time — configured in seconds, not minutes.

### Target Users
Power users who manage many apps and want more control than iOS provides. Specifically: professionals, developers, and productivity enthusiasts who use an iPhone and/or iPad daily.

### Platform
- **iOS 17+** (primary)
- **iPadOS 17+** (adaptive layout from same codebase)
- **Swift 5.9+**, **SwiftUI**, **SwiftData**
- Xcode 15+

---

## 2. Core Concepts

### 2.1 AppEntry
A single launchable app known to Fore. Has a URL scheme used to open it. May or may not be installed on the current device. Installed status is determined at runtime via `canOpenURL`.

### 2.2 LauncherSection
A named, ordered container of AppEntries. The atomic unit of the Fore UI. Sections stack vertically. Each section has a type that determines how its apps are sourced and sorted.

### 2.3 Section Types

| Type | Behavior |
|---|---|
| `pinned` | User manually adds apps. User controls order. Always visible at top unless user reorders. |
| `recentlyUsed` | Auto-populated from UsageEvents. Last N unique apps launched, ordered by recency. User does not manually add apps. |
| `frequentlyUsed` | Auto-populated from UsageEvents. Top N apps by priority score over rolling 30 days. |
| `timeBased` | Auto-activates during a time window (e.g., 7–9am). Apps are manually added but section only appears during its window. |
| `focusBased` | Auto-promotes to top of stack when a named iOS Focus mode is active. Apps manually added by user. |
| `manual` | User-curated, user-named (e.g., "Work", "Travel"). User controls order. |

### 2.4 UsageEvent
A log entry written every time the user launches an app through Fore. Used to compute scores for recentlyUsed and frequentlyUsed sections. Stored locally, never transmitted.

### 2.5 Priority Score
A computed double assigned to each AppEntry that drives automatic section ordering. Computed from: launch frequency (logarithmic), recency (exponential decay, 3-day half-life), and time-of-day affinity. Higher is better.

---

## 3. Data Models

All models use **SwiftData** (`@Model`). No Core Data. No external database.

```swift
// AppEntry.swift
@Model class AppEntry {
    var id: UUID
    var name: String
    var urlScheme: String          // e.g. "spotify://"
    var category: AppCategory
    var isInstalled: Bool          // updated at runtime via canOpenURL
    var dateAdded: Date
    var customSortIndex: Int       // for manual ordering within a section
    var section: LauncherSection?

    // Derived — computed from UsageEvents, cached here for performance
    var launchCount: Int
    var lastLaunched: Date?
}

// LauncherSection.swift
@Model class LauncherSection {
    var id: UUID
    var title: String
    var emoji: String              // e.g. "📌"
    var type: SectionType          // see Section Types above
    var displayOrder: Int          // user-controlled stack position (0 = top)
    var maxVisible: Int            // show this many before "Show more"
    var isEnabled: Bool
    var apps: [AppEntry]

    // Focus section only
    var focusName: String?

    // Time-based section only
    var timeWindowStart: DateComponents?
    var timeWindowEnd: DateComponents?
}

// UsageEvent.swift
@Model class UsageEvent {
    var id: UUID
    var appScheme: String
    var launchedAt: Date
    var activeFocusName: String?   // Focus mode active at time of launch, if any
    var hourOfDay: Int             // 0–23
    var dayOfWeek: Int             // 1–7, Calendar.current component
}

// AppCategory enum
enum AppCategory: String, Codable, CaseIterable {
    case productivity
    case social
    case entertainment
    case health
    case finance
    case travel
    case utilities
    case news
    case music
    case developer
    case shopping
    case food
    case education
    case other
}

// SectionType enum — must be Codable for SwiftData persistence
enum SectionType: Codable {
    case pinned
    case recentlyUsed
    case frequentlyUsed
    case timeBased
    case focusBased
    case manual
}
```

---

## 4. App Database

### Format
Bundled file: `Fore/Database/AppDatabase.json`

Each entry:
```json
{
  "name": "Fantastical",
  "urlScheme": "fantastical3://",
  "category": "productivity",
  "keywords": ["calendar", "tasks", "reminders", "scheduling"]
}
```

### Required Entries (build with at least 150 apps)
Include well-known apps across all categories. Prioritize apps with confirmed, documented URL schemes. Cover at minimum:

**Productivity:** Fantastical, Things 3, Notion, Craft, Bear, Obsidian, Drafts, GoodNotes, Notability, OmniFocus, Todoist, TickTick, Linear, Jira, Asana, Slack, Microsoft Teams, Zoom, Loom, 1Password, Bitwarden

**Communication:** Mail, Messages (sms://), WhatsApp, Telegram, Signal, Discord, Spark Mail, Mimestream, Gmail, Outlook

**Developer:** Xcode (xcode://), Working Copy, Blink Shell, Prompt, Textastic, GitHub, GitLab, Jira

**Finance:** Robinhood, Coinbase, Chase, Bank of America, Venmo, Cash App, Mint, YNAB, Copilot

**Health & Fitness:** Gentler Streak, Strong, MyFitnessPal, Strava, Headspace, Calm, Sleep Cycle, Zero

**Entertainment:** Spotify, Apple Music (music://), Pocket Casts, Overcast, Castro, Netflix, YouTube, Plex, Infuse, Reeder, Instapaper, Pocket

**Travel & Maps:** Google Maps, Apple Maps (maps://), Waze, Airbnb, Booking.com, TripIt, Flighty, Yelp

**News:** Reeder 5, NetNewsWire, Flipboard, The New York Times, The Athletic, ESPN

**Social:** Twitter/X, Instagram, Threads, LinkedIn, Reddit, Mastodon, TikTok

**Utilities:** Toolbox, PastePal, CleanMaster, Scriptable, Shortery, Jayson, Keka, Command X

**Shopping:** Amazon, eBay, Etsy, ASOS, Nike, Instacart, DoorDash, Uber Eats

**Food & Drink:** Yelp, OpenTable, Starbucks, Toast, Nespresso

### Scheme Validation
At app launch and on foreground, `SchemeValidator` runs `canOpenURL` for each database entry and updates the `isInstalled` flag. The Info.plist `LSApplicationQueriesSchemes` array must contain all schemes from the database (Apple caps at 50 — see Known Constraints section).

---

## 5. Folder Structure

```
Fore/
├── ForeApp.swift
├── App/
│   └── ContentView.swift
├── Model/
│   ├── AppEntry.swift
│   ├── LauncherSection.swift
│   ├── UsageEvent.swift
│   ├── AppCategory.swift
│   └── SectionType.swift
├── Database/
│   ├── AppDatabase.json
│   └── AppDatabaseLoader.swift      // loads JSON, checks canOpenURL
├── Engine/
│   ├── SchemeValidator.swift        // canOpenURL checks + caching
│   ├── UsageTracker.swift           // writes UsageEvents on each launch
│   ├── SectionSorter.swift          // computes ordered app list per section type
│   └── FocusMonitor.swift           // observes active Focus mode
├── Store/
│   └── ForeStore.swift              // SwiftData container, shared environment object
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift           // root view, section stack
│   │   ├── SectionRowView.swift     // one section in the stack
│   │   └── AppIconView.swift        // one tappable app icon
│   ├── AddApps/
│   │   ├── AddAppsView.swift        // searchable list, checkbox selection
│   │   └── AppRowView.swift         // one row in the add apps list
│   ├── SectionEditor/
│   │   ├── SectionEditorView.swift  // rename, type, maxVisible, delete
│   │   └── NewSectionView.swift     // create new section flow
│   └── Settings/
│       └── SettingsView.swift
├── Widgets/                         // ForeWidgets target
│   ├── ForeWidgets.swift
│   ├── SmallWidget.swift
│   ├── MediumWidget.swift
│   ├── LargeWidget.swift
│   └── WidgetEntry.swift
└── Intents/                         // ForeIntents target (also used inline)
    ├── LaunchAppIntent.swift
    ├── OpenSectionIntent.swift
    ├── AddAppToSectionIntent.swift
    ├── LaunchSectionKitIntent.swift
    ├── GetTopAppsIntent.swift
    └── ForeFocusFilter.swift
```

---

## 6. UI Specification

### 6.1 iPhone Layout

#### HomeView
- `NavigationStack` with title "Fore" and settings gear in toolbar
- Body: `List` of `LauncherSection` rows, reorderable via `.onMove`
- Each section row (`SectionRowView`) contains:
  - Header: emoji + title + "Edit" button + app count badge
  - For active Focus sections: colored indicator dot + "ACTIVE" label
  - Body: horizontal `ScrollView` of `AppIconView` items
  - Footer: "Show more" link if app count exceeds `maxVisible`
- FAB or toolbar button: "+ Add Section"

#### AppIconView
- App icon (from URL scheme lookup or category SF Symbol fallback)
- App name below icon, truncated to 1 line
- Tap: launch app via URL scheme, log UsageEvent
- Long press: contextual menu (Move to section, Pin, Remove)

#### AddAppsView
- Full-screen sheet triggered by section "Edit" → "Add Apps"
- `searchField` at top, reactive filtering (no search button)
- `List` of all installed apps from database not already in this section
- Each row: app icon + name + category tag + checkbox
- Multi-select: tap checkbox to toggle
- Bottom bar: "Add (N)" button, disabled when N = 0
- Tapping "Add (N)" appends selected apps to the section and dismisses

#### SectionEditorView
- Sheet or pushed view from section "Edit" button
- Fields: title (text field), emoji (emoji picker), type (picker), maxVisible (stepper)
- For timeBased: start time picker, end time picker
- For focusBased: Focus mode name picker (list of common Focus names + custom text field)
- Danger zone: "Delete Section" button (confirmation required)

#### NewSectionView
- Modal sheet
- Step 1: choose section type (visual card selection)
- Step 2: name + emoji
- Step 3 (conditional): configure type-specific settings
- Creates section and dismisses, section appears at bottom of stack

### 6.2 iPadOS Layout

Replace `NavigationStack` with `NavigationSplitView`:
- **Sidebar (left column):** list of sections, reorderable, "+ Add Section" at bottom
- **Detail (right column):** selected section's apps in a grid (6 columns), section editor toolbar at top
- Drag apps from detail pane to sidebar sections (drop target highlighting)
- Hardware keyboard shortcuts:
  - `⌘K` — focus search in AddAppsView
  - `⌘N` — new section
  - `⌘,` — settings
  - `⌘E` — edit selected section

### 6.3 Visual Design Principles
- **No decorative chrome.** Fore is a tool, not a showcase.
- System background colors throughout (adapts to light/dark automatically)
- SF Symbols for all icons where app icon is unavailable
- App icons: 44×44pt, rounded corners matching iOS standard (10pt radius)
- Section headers: SF Pro Rounded, semibold
- Haptic feedback: `UIImpactFeedbackGenerator(.medium)` on every app launch tap
- Animation: section reorder uses default SwiftUI list animation. App launch is instant — no transition animation that could add perceived latency.

---

## 7. Intelligence Engine

### 7.1 Priority Score Formula

```swift
func priorityScore(for scheme: String, events: [UsageEvent]) -> Double {
    let now = Date()
    let appEvents = events.filter { $0.appScheme == scheme }
    guard !appEvents.isEmpty else { return 0 }

    // Frequency: logarithmic scaling
    let frequency = log(Double(appEvents.count) + 1) * 10.0

    // Recency: exponential decay, half-life = 3 days (259200 seconds)
    let recency = appEvents
        .map { exp(-now.timeIntervalSince($0.launchedAt) / 259200) }
        .reduce(0, +) * 20.0

    // Time-of-day affinity: bonus for apps used at similar hours
    let currentHour = Calendar.current.component(.hour, from: now)
    let timeAffinity = Double(appEvents
        .filter { abs($0.hourOfDay - currentHour) <= 2 }
        .count) * 5.0

    return frequency + recency + timeAffinity
}
```

### 7.2 Auto-Section Refresh Rules

- **recentlyUsed:** Query last 20 UsageEvents, deduplicate by scheme, take top N (where N = section.maxVisible). Refresh on: app foreground, after any launch.
- **frequentlyUsed:** Compute priority score for all tracked schemes over last 30 days. Sort descending. Take top N. Refresh on: app foreground, after any launch.
- **timeBased:** Check current time against window on app foreground and every 15 minutes via background task if available.
- **focusBased:** Refresh triggered by FocusMonitor when Focus state changes.

### 7.3 UsageTracker

```swift
class UsageTracker {
    static let shared = UsageTracker()

    func record(scheme: String, context: ModelContext) {
        let now = Date()
        let cal = Calendar.current
        let event = UsageEvent(
            id: UUID(),
            appScheme: scheme,
            launchedAt: now,
            activeFocusName: FocusMonitor.shared.currentFocusName,
            hourOfDay: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now)
        )
        context.insert(event)
        try? context.save()
    }

    func pruneOldEvents(olderThan days: Int = 90, context: ModelContext) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<UsageEvent>(
            predicate: #Predicate { $0.launchedAt < cutoff }
        )
        let old = (try? context.fetch(descriptor)) ?? []
        old.forEach { context.delete($0) }
        try? context.save()
    }
}
```

---

## 8. Focus Mode Integration

### 8.1 FocusMonitor

Observes the current Focus mode name using `NEHotspotNetwork` is NOT used here. Instead use `UserNotifications` / `FocusFilterIntent` architecture:

```swift
class FocusMonitor: ObservableObject {
    static let shared = FocusMonitor()
    @Published var currentFocusName: String? = nil

    // Updated via ForeFocusFilter.perform() when Focus changes
    func update(focusName: String?) {
        DispatchQueue.main.async {
            self.currentFocusName = focusName
        }
    }
}
```

### 8.2 ForeFocusFilter (App Intent)

```swift
struct ForeFocusFilter: FocusFilterIntent {
    static let title: LocalizedStringResource = "Configure Fore for Focus"
    static let description = IntentDescription("Choose which section Fore promotes during this Focus mode.")

    @Parameter(title: "Section to Promote")
    var sectionTitle: String?

    func perform() async throws -> some IntentResult {
        FocusMonitor.shared.update(focusName: sectionTitle)
        return .result()
    }
}
```

### 8.3 Section Promotion Logic

In `SectionSorter`, when computing `displayOrder` for rendering:

```swift
func sortedSections(_ sections: [LauncherSection]) -> [LauncherSection] {
    let activeFocus = FocusMonitor.shared.currentFocusName
    return sections
        .filter { $0.isEnabled }
        .sorted { a, b in
            // Focus-active sections always rise above non-pinned
            if let focus = activeFocus {
                let aActive = a.type == .focusBased && a.focusName == focus
                let bActive = b.type == .focusBased && b.focusName == focus
                if aActive != bActive { return aActive }
            }
            // Pinned sections stay at top
            let aPinned = a.type == .pinned
            let bPinned = b.type == .pinned
            if aPinned != bPinned { return aPinned }
            // Otherwise respect user-defined displayOrder
            return a.displayOrder < b.displayOrder
        }
}
```

---

## 9. WidgetKit Specification

### 9.1 Widget Sizes

| Size | Identifier | App rows | Columns | Available |
|---|---|---|---|---|
| Small | `foreSmall` | Top 4 apps | 2×2 | iPhone + iPad |
| Medium | `foreMedium` | One section, up to 8 apps | 4×2 | iPhone + iPad |
| Large | `foreLarge` | Two sections, up to 16 apps | 4×4 | iPhone + iPad |
| Extra Large | `foreXLarge` | Three sections | 8×4 | iPad only |

### 9.2 Interactive Widgets (iOS 17+)

Each app icon in the widget is a `Button` backed by `LaunchAppIntent`. Tapping it launches the target app without opening Fore.

```swift
struct LaunchAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Launch App via Fore"

    @Parameter(title: "App URL Scheme")
    var urlScheme: String

    @Parameter(title: "App Name")
    var appName: String

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: urlScheme) else { return .result() }
        await UIApplication.shared.open(url)
        // Note: usage tracking in widget context is limited;
        // write to shared UserDefaults and sync to SwiftData on next app open
        SharedUsageQueue.append(scheme: urlScheme)
        return .result()
    }
}
```

### 9.3 Shared Data Between App and Widget

Use App Groups (`group.com.yourname.fore`) for shared `UserDefaults`:
- Widget reads current section data serialized to shared UserDefaults
- Widget writes pending usage events to a queue in shared UserDefaults
- Main app reads and processes queue on foreground

### 9.4 Timeline Provider

```swift
struct ForeTimelineProvider: AppIntentTimelineProvider {
    func timeline(for configuration: ForeWidgetConfiguration, in context: Context) async -> Timeline<ForeWidgetEntry> {
        let sections = SharedDataStore.loadSections()
        let entry = ForeWidgetEntry(date: .now, sections: sections)

        // Refresh every 15 minutes to catch time-based section changes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
```

### 9.5 Widget Configuration
Each widget is configurable via `AppIntentConfiguration`:
- Which section to display (or "Smart" — auto-selects by context)
- Whether to follow active Focus mode
- App icon size: compact / standard

---

## 10. App Intents (Shortcuts)

Implement all five intents in the `ForeIntents` target, also available as `AppIntent` in-app.

### Intent 1: LaunchAppIntent
Parameters: `urlScheme: String`, `appName: String`
Action: Opens the app. Logs a usage event.
Siri phrase example: "Launch Fantastical via Fore"

### Intent 2: OpenSectionIntent
Parameters: `sectionTitle: String`
Action: Opens Fore and scrolls to/highlights the named section.
Siri phrase example: "Open my Work section in Fore"

### Intent 3: AddAppToSectionIntent
Parameters: `appName: String`, `sectionTitle: String`
Action: Looks up app in database, adds to named section.
Siri phrase example: "Add Notion to my Pinned section in Fore"

### Intent 4: LaunchSectionKitIntent
Parameters: `sectionTitle: String`, `delaySeconds: Int` (default: 1)
Action: Sequentially opens all apps in the named section with a delay between each.
Siri phrase example: "Start my morning kit in Fore"

```swift
func perform() async throws -> some IntentResult {
    let apps = ForeStore.shared.apps(inSectionNamed: sectionTitle)
    for app in apps {
        guard let url = URL(string: app.urlScheme) else { continue }
        await UIApplication.shared.open(url)
        try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
    }
    return .result()
}
```

### Intent 5: GetTopAppsIntent
Parameters: `count: Int` (default: 5)
Returns: Array of app names (for use in other Shortcuts)
Action: Returns the top N apps by current priority score.

---

## 11. Known Constraints & Mitigations

| Constraint | Detail | Mitigation |
|---|---|---|
| `LSApplicationQueriesSchemes` cap | Apple limits Info.plist to 50 declared schemes for `canOpenURL` | Prioritize top 50 most common apps for verified detection; for others, show as "unverified" and attempt open, failing gracefully |
| Cannot enumerate installed apps | No public API to list all apps on device | Maintain curated AppDatabase.json; user manually adds apps not in database via custom scheme entry |
| Widget usage tracking | Widget extension cannot directly write to SwiftData | Use App Groups shared UserDefaults as an event queue; drain queue into SwiftData on main app foreground |
| Focus mode name | No API to programmatically read the current Focus mode name | FocusFilterIntent is configured by user per Focus; user explicitly links a section to a Focus |
| No background launch of other apps | `UIApplication.shared.open` requires foreground | All app launches must happen while Fore is active or via widget tap (which is handled by `AppIntent.perform`) |

---

## 12. Build Phases

Complete these phases in order. Do not begin a phase until the previous one compiles and runs correctly.

### Phase 0 — Project Foundation
- Xcode project and target structure set up (done manually in Xcode)
- All Swift files created with correct target membership
- App Groups entitlement configured
- Info.plist `LSApplicationQueriesSchemes` array populated
- **Done when:** project builds with zero errors on a device or simulator

### Phase 1 — Data Model & App Database
- All SwiftData models written and compiling
- `AppDatabase.json` created with 150+ entries
- `AppDatabaseLoader` reads JSON and runs scheme validation
- `ForeStore` provides a shared SwiftData `ModelContainer`
- **Done when:** database loads, installed apps filter correctly, models persist across launches

### Phase 2 — Core iPhone UI
- `HomeView` renders sections from SwiftData
- `SectionRowView` shows horizontal app scroll
- `AppIconView` launches apps and logs UsageEvents
- `AddAppsView` with search and checkbox multi-select
- `SectionEditorView` and `NewSectionView` functional
- Section reordering works
- **Done when:** user can add sections, add apps, reorder, launch apps, and see usage events logged

### Phase 3 — Intelligence Engine
- `UsageTracker` writes events correctly
- `SectionSorter` computes priority scores
- recentlyUsed and frequentlyUsed sections auto-populate and update
- **Done when:** after 10+ launches through Fore, Recent and Frequent sections reflect real behavior

### Phase 4 — Focus Mode Integration
- `FocusMonitor` observes and publishes Focus state
- `ForeFocusFilter` intent registered and triggering
- Focus sections auto-promote in HomeView
- **Done when:** activating a Focus mode causes its linked section to rise to the top of Fore

### Phase 5 — WidgetKit
- All widget sizes render correctly
- Interactive widget taps launch apps
- App Groups shared data passes section info to widget
- Usage event queue drains correctly on app foreground
- Widget timeline refreshes on schedule
- **Done when:** all widget sizes work on device, taps launch correct apps, no stale data

### Phase 6 — iPadOS Adaptation
- `NavigationSplitView` layout for regular horizontal size class
- 6-column app grid in detail pane
- Drag and drop between sidebar and detail
- Keyboard shortcuts registered and functional
- **Done when:** app looks and behaves natively on iPad, not like stretched iPhone app

### Phase 7 — App Intents & Shortcuts
- All 5 intents implemented and appear in Shortcuts app
- `ForeFocusFilter` configurable per Focus in Settings → Focus
- `LaunchSectionKitIntent` opens apps sequentially
- **Done when:** all intents work from Shortcuts and via Siri

### Phase 8 — Polish & Settings
- `SettingsView` complete
- Haptic feedback on all launch taps
- Empty states for new users
- Onboarding flow (3 screens max)
- `PROGRESS.md` reflects everything complete
- **Done when:** app is ready for TestFlight

---

## 13. Settings Screen Contents

- **Default section for new apps:** picker
- **App icon size:** Compact / Standard / Large (segment control)
- **Widget:** link to widget configuration instructions
- **Data:**
  - Export usage data (JSON)
  - Reset all usage data (confirmation required)
  - Reset all sections (confirmation required)
- **About:** version number, build number, link to feedback

---

## 14. Default Sections on First Launch

Create these sections automatically when the user first opens Fore:

1. **📌 Pinned** — type: `pinned`, displayOrder: 0, maxVisible: 8
2. **🕐 Recently Used** — type: `recentlyUsed`, displayOrder: 1, maxVisible: 8
3. **🔥 Frequently Used** — type: `frequentlyUsed`, displayOrder: 2, maxVisible: 8

Do not pre-populate with apps. User adds their own.

---

## 15. Frameworks — Approved List

Use only these frameworks. Do not add Swift Package dependencies without noting the decision in `PROGRESS.md` and justifying it.

- `SwiftUI` — all UI
- `SwiftData` — persistence
- `WidgetKit` — home screen widgets
- `AppIntents` — Shortcuts + Focus integration
- `UserNotifications` — Focus filter registration
- `UIKit` — `UIApplication.shared.open`, `UIImpactFeedbackGenerator` only
- `Foundation` — standard library use
- No third-party packages unless absolutely necessary

---

## 16. Companion Files

Maintain these files at the project root throughout development:

- **`SPEC.md`** — this file. Do not modify unless spec changes.
- **`PROGRESS.md`** — current phase, what's done, what's next, open questions, decisions made.
- **`ERRORS.md`** — log of build errors encountered and how they were resolved. Useful for avoiding repeat mistakes across sessions.

---

*End of SPEC.md*
