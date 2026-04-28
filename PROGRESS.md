# Fore — Progress Tracker

## Current Status
**All required phases complete. Ready for TestFlight. Phase 6 (iPadOS) deferred.**
**Last updated:** 2026-04-28

---

## Phase Checklist

- [ ] Phase 0 — Project Foundation
- [x] Phase 1 — Data Model & App Database
- [x] Phase 2 — Core iPhone UI
- [x] Phase 3 — Intelligence Engine
- [x] Phase 4 — Focus Mode Integration
- [x] Phase 5 — WidgetKit
- [ ] Phase 6 — iPadOS Adaptation *(deferred — revisit when there is demand)*
- [x] Phase 7 — App Intents & Shortcuts
- [x] Phase 8 — Polish & Settings

---

## What's Done
- **Phase 1:**
  - 5 model files in `Fore/Model/`
  - `Fore/Database/AppDatabaseLoader.swift`
  - `Fore/Database/AppDatabase.json` (196 entries across all 13 categories)
  - `Fore/Store/ForeStore.swift`
- **Phase 2:**
  - `Fore/Engine/UsageTracker.swift` (record only — pruning/scoring deferred to Phase 3)
  - `Fore/Views/AppCategory+Style.swift` (per-category SF Symbol + tint)
  - `Fore/Views/Home/AppIconView.swift`, `SectionRowView.swift`, `HomeView.swift`
  - `Fore/Views/AddApps/AppRowView.swift`, `AddAppsView.swift`
  - `Fore/Views/SectionEditor/SectionEditorView.swift`, `NewSectionView.swift`
  - First-launch seeder added to `ForeStore` (`bootstrapDefaultSectionsIfNeeded`); seeds 📌 Pinned, 🕐 Recently Used, 🔥 Frequently Used per SPEC §14
  - `ForeApp.swift` swapped to `HomeView`, smoke-test `ContentView.swift` deleted
  - Mid-phase polish: inline "+" tile in `SectionRowView` for non-auto sections; "Add Apps" entry point in `SectionEditorView` per spec §6.1
- **Phase 3:**
  - `Fore/Engine/SectionSorter.swift` — priority score (SPEC §7.1) + `resolvedApps(for:usageEvents:allApps:)`
  - `UsageTracker.pruneOldEvents(olderThan:in:)` (SPEC §7.3)
  - `SectionRowView` refactored to take precomputed `apps: [AppEntry]`; auto-populated sections suppress the inline "+" tile and Remove context menu
  - `HomeView` performs the resolution once per refresh and pipes the list into each row; `.onChange(of: scenePhase)` triggers prune on foreground
  - DEBUG-only "Simulate launch" affordance in `SectionEditorView` (1×/10× per app) for verifying Recently/Frequently Used without launching real apps
- **Phase 4:**
  - `Fore/Engine/FocusMonitor.swift` — `@Observable @MainActor` singleton
  - `Fore/Intents/ForeFocusFilter.swift` — `SetFocusFilterIntent` per SPEC §8.2
  - `SectionSorter.sortedSections(_:activeFocus:)` per SPEC §8.3
  - `HomeView` consumes `FocusMonitor` and passes real `isFocusActive` into `SectionRowView`; `EditButton` hidden during active focus to keep reorder semantics sane
  - DEBUG-only moon-icon menu in toolbar that lets us flip the active focus name without setting up cross-process delivery

---

## What's Next
**Required spec phases are done.** What's left, in priority order:

1. **TestFlight prep**
   - Set Marketing Version + Build Number on the Fore target.
   - Confirm Privacy descriptions in `Info.plist` for any sensitive APIs (none currently used — no camera/contacts/etc).
   - Archive (`Product → Archive`), upload via Organizer.
2. **Phase 6 — iPadOS Adaptation** (deferred). Pick up if iPad demand exists.
3. **Open polish items captured during prior phases** (none are blockers):
   - "Smart" widget auto-selection (SPEC §9.5) — not implemented.
   - Per-widget icon-size option (SPEC §9.5) — not implemented; main app's setting governs.
   - 3-step `NewSectionView` wizard (SPEC §6.1) — currently single Form.
   - "Default section for new apps" preference is persisted but inert (no flow consumes it yet).
   - DEBUG focus banner / simulate-launch / focus override remain as developer affordances; they strip out at release build via `#if DEBUG`.
4. **Smoke tests still owed:** Siri phrases haven't been spoken to verify recognition.

---

## Open Questions
*(add questions that need human decisions)*

---

## Decisions Made
- **`SectionType` is `String`-backed** (spec showed bare `Codable` enum). Required for clean SwiftData persistence and predicate filtering.
- **`AppEntry` ↔ `LauncherSection` relationship** uses `@Relationship(deleteRule: .nullify, inverse: \AppEntry.section)` on the `apps` array; deleting a section nullifies child links rather than cascading away the AppEntries (entries live in the database list and can be re-added).
- **AppDatabase.json contains 196 entries** (spec called for 150+), spread across all 13 categories. URL schemes prioritized from publicly documented schemes; some entries (e.g., `Mint`, `Hey`, niche utilities) may not resolve via `canOpenURL` — `SchemeValidator` (Phase 3) will mark them `isInstalled = false` accordingly.
- **`AppDatabaseLoader` does NOT insert into SwiftData** at this stage — it only decodes and resolves install state. Hydration into `AppEntry` records happens in a later step once Phase 2 UI needs it; this keeps the loader testable and side-effect-free.
- **`ForeStore` is `@MainActor` + singleton.** Spec referenced `ForeStore.shared.apps(inSectionNamed:)`; making the whole class main-actor-isolated keeps SwiftData usage simple. App Group / shared-container wiring is deferred until Phase 5 (Widgets).
- **`LauncherSection.timeWindowStart/End` storage deviates from spec.** SPEC §3 prescribes `DateComponents?`, but SwiftData crashes at schema build with `Unexpected property within Persisted Struct/Enum: _CalendarProtocol` because `DateComponents` carries a `Calendar?`. Stored as four `Int?` scalars (`timeWindowStartHour`, `timeWindowStartMinute`, `timeWindowEndHour`, `timeWindowEndMinute`) with a computed `DateComponents?` accessor extension that preserves the spec's public interface. See ERRORS.md 2026-04-27 entry.
- **AppEntry records are created lazily.** AppDatabase.json is a catalog of 196 entries; `AppEntry` rows in SwiftData are only created when the user adds an app to a section via `AddAppsView.commit()`. Avoids polluting the store with hundreds of unused records and keeps "section.apps" semantically equal to "apps the user cares about."
- **App icons use per-category SF Symbol + tint** (no public iOS API to fetch installed-app icons). Mapping lives in `Fore/Views/AppCategory+Style.swift`.
- **`NewSectionView` is a single Form**, not the 3-step wizard SPEC §6.1 prescribes. Same data captured. Wizard refactor is a Phase 8 polish item.
- **`SectionRowView` "ACTIVE" indicator** is wired to a hardcoded `isFocusActive: Bool = false` parameter. Phase 4 will pass real state from FocusMonitor.
- **Recently/Frequently Used sections render `section.apps`** which is empty for auto-populated types. Phase 3 introduces `SectionSorter` to resolve the real app list for these section types.
- **Some bundled URL schemes are inherently broken on iOS,** not by Fore. Settings (`App-prefs://`) was sandboxed by Apple in iOS 11; Phone (`tel://`) is for dialing a specific number, not opening the Phone app. There's no public URL scheme that opens those system apps from a third-party launcher. Removed both from AppDatabase.json on 2026-04-28 (now 194 entries).
- **Phase 6 (iPadOS) is deferred** — user opted to skip until there is demand for an iPad version. The current iPhone layout still runs on iPad as a stretched iPhone app; revisiting later means swapping `NavigationStack` for `NavigationSplitView` in the regular horizontal size class, plus the drag-and-drop / keyboard shortcuts / XL widget bullets in SPEC §6.2 + §9.1.
- **Widget configuration is by section-title string only** in Phase 5. SPEC §9.5 also mentions a "Smart" auto-selection mode and a per-widget icon-size option — both deferred to Phase 8 polish. Each widget instance currently picks one section via long-press → Edit Widget → Section title.

---

## Session Log
- **2026-04-27:** Phase 1 complete. Wrote 5 model files, AppDatabaseLoader, AppDatabase.json (196 entries), ForeStore. Hit one crash mid-session — `DateComponents` in `LauncherSection` triggered SwiftData's `_CalendarProtocol` reflection error; resolved by switching to scalar Int storage + computed `DateComponents` accessor (see ERRORS.md). Smoke test view in `ContentView` confirmed 196-entry bundle load on device.
- **2026-04-27:** Phase 2 complete. Wrote 9 view/engine files + ForeStore seeder + ForeApp swap. App boots into HomeView, seeds three default sections, supports adding/editing/reordering sections and adding apps from the bundled catalog with search/install-filter/multi-select. Per-category SF Symbol icons used in lieu of real app icons (no public API). User confirmed working app on simulator.
- **2026-04-27:** Phase 3 complete. SectionSorter implements priority score + resolved-app routing for auto sections. SectionRowView refactored to consume precomputed apps; HomeView centralizes the per-frame resolution and triggers prune on foreground. DEBUG simulate-launch affordance lets us populate Recent/Frequent without real launches.
- **2026-04-27:** Phase 4 complete. FocusMonitor + SetFocusFilterIntent + sortedSections promotion + DEBUG focus override. Hit one compile error mid-phase: `SetFocusFilterIntent` requires an instance `displayRepresentation` (logged in ERRORS.md). User confirmed the focus-active section rises to top with ACTIVE indicator. Cross-process delivery from a real iOS Focus is deferred to Phase 5 along with App Group setup.
- **2026-04-27:** Phase 5 Chunk A complete. App Group `group.com.shawnbrown.Fore` configured on Fore + ForeWidgetsExtension + ForeIntentsExtension. SharedDefaults / SharedNotifications / WidgetPublisher / UsageQueueDrain / FocusBridge written. ForeFocusFilter moved into the ForeIntents extension target and writes through SharedDefaults. Hit two real bugs along the way: (1) `FetchDescriptor` API confusion (`sort` vs `sortBy`), (2) cfprefsd cross-process propagation lag — Darwin notification arrived before the new value was visible to the main app's UserDefaults read; switched the active-focus value to a small file in the App Group container, which is immediately consistent. Both logged in ERRORS.md. End-to-end iOS Focus → Fore section promotion now works on device with Fore foregrounded.
- **2026-04-28:** Phase 5 Chunk B complete. Three widget sizes (small, medium, large) shipped with `LaunchAppIntent` for interactive taps, `ForeTimelineProvider` reading the App Group snapshot, configurable section per widget instance via `AppIntentConfiguration`. SharedUsageQueue extracted as a shared cross-process helper for widget-side enqueues. Boilerplate Live Activity / Control Widget / placeholder AppIntent template files removed. User confirmed widgets render on real device, taps launch target apps, and `UsageQueueDrain` correctly processes queued events into Recently Used after the main app foregrounds. URL-scheme caveats observed: Settings (`App-prefs://`) is system-restricted, Phone (`tel://`) is a call-initiation scheme not an app launcher — both noted as iOS limitations, not Fore bugs.
- **2026-04-28:** Removed Settings and Phone from AppDatabase.json (194 entries remain, still above the 150 floor). Phase 6 (iPadOS) deferred to a future date pending iPad demand.
- **2026-04-28:** Phase 7 complete. All 5 SPEC §10 intents shipped: `LaunchAppIntent` (Phase 5), `OpenSectionIntent`, `AddAppToSectionIntent`, `LaunchSectionKitIntent`, `GetTopAppsIntent`, plus `ForeShortcutsProvider` registering canonical Siri phrases. Deep-link mailbox added to `SharedDefaults` for `OpenSectionIntent` → `HomeView` scroll-and-highlight. Hit two compile blockers: (1) `AppShortcut` phrases only allow `AppEntity`/`AppEnum` parameter slots and at most one per phrase — fixed by dropping parameter slots, Siri prompts for values; (2) Swift 6 strict concurrency was inferring `@MainActor` on shared static utilities — explicit `nonisolated` on `SharedDefaults` / `SharedUsageQueue` / `SharedNotifications` resolved both the actor-hop warnings and the cross-target inconsistency where the widget extension treated the same symbols as nonisolated. User confirmed the intents work in Shortcuts; Siri phrases not yet smoke-tested but expected to function.
- **2026-04-28:** Phase 8 complete. Shipped `AppPreferences` (icon size + default section + onboarding flag), `DataExporter` (JSON share-sheet for usage events), `DataReset` (wipe usage / wipe sections), `SettingsView` per SPEC §13, and a 3-page `OnboardingView` shown on first launch. `HomeView` now has a settings gear in the toolbar; `AppIconView` reacts to the icon-size preference (Compact 44pt / Standard 56pt / Large 68pt). User confirmed app behaves as expected. Project is TestFlight-ready.
