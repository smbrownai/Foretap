# Fore — Build Error Log

## Purpose
Log every significant build error encountered and how it was resolved.
This file is read at the start of each Claude Code session to avoid repeating mistakes.

## Format
```
### [Date] — [Error Summary]
**Phase:** 
**File:** 
**Error message:** 
**Root cause:** 
**Fix:** 
```

---

### 2026-04-27 — Darwin notification outraces cross-process UserDefaults read (cfprefsd race)
**Phase:** 5 (Chunk A)
**File:** `Fore/Engine/FocusBridge.swift`
**Symptom:** Extension writes `SharedDefaults.activeFocusName = "Work"` and posts Darwin notification. Main-app callback fires; reads `SharedDefaults.activeFocusName` → still `(nil)`. Extension's own readback shows `"Work"` (local cache hit).
**Root cause:** App-group `UserDefaults` writes flow through `cfprefsd`, the system preferences daemon. The writing process sees its own change immediately (local cache); other processes read through cfprefsd and get the new value only after it has finished propagating — typically tens of ms later. Darwin notifications, by contrast, are delivered nearly synchronously to all subscribers. Result: the notification arrives before cfprefsd has caught up.
**Fix:** Tried 250 ms retry first — still stale on a real iPhone 16 Pro Max, so cfprefsd was lagging well over a quarter second. Switched the active-focus value to a file written into the App Group container (`containerURL(forSecurityApplicationGroupIdentifier:)` + a small text file). File reads are immediately consistent across processes since both processes read straight off disk; cfprefsd is bypassed entirely.
**Watch out for:** any Darwin-notification-driven cross-process value propagation through UserDefaults. cfprefsd lag between writer and reader is real and can exceed several hundred ms on device. For values that must be visible immediately on receipt of a Darwin ping, use a small file under the App Group container.

---

### 2026-04-27 — `FetchDescriptor` parameter name confusion: `Extra argument 'sort' in call` + `Cannot infer key path type from context`
**Phase:** 5 (Chunk A)
**File:** `Fore/Engine/WidgetPublisher.swift`
**Error message:** `Extra argument 'sort' in call`, `Cannot infer key path type from context; consider explicitly specifying a root type`
**Root cause:** I used `FetchDescriptor(sort: [SortDescriptor(\.x)])` — that parameter label only exists on the SwiftUI `@Query` convenience. The actual `FetchDescriptor` initializer takes `sortBy:`, not `sort:`. With the wrong label the compiler stops type-checking the closure and fails to resolve the `\.x` key path's root type, hence the secondary error.
**Fix:** Switched to `FetchDescriptor(sortBy: [SortDescriptor(\Type.property, order: ...)])` with an explicit root type on the key path.
**Watch out for:** the `@Query` macro and `FetchDescriptor` look interchangeable but accept different labels (`sort:` vs `sortBy:`). When the secondary error blames a key path, double-check the initializer label first.

---

### 2026-04-27 — `SetFocusFilterIntent` conformance failure: `does not conform to protocol 'InstanceDisplayRepresentable'`
**Phase:** 4
**File:** `Fore/Intents/ForeFocusFilter.swift`
**Error message:** `Type 'ForeFocusFilter' does not conform to protocol 'InstanceDisplayRepresentable'`
**Root cause:** `SetFocusFilterIntent` extends `InstanceDisplayRepresentable`, which requires a non-static `var displayRepresentation: DisplayRepresentation` so iOS can render the configured filter in Settings → Focus → Filters. The static `title` / `description` aren't enough.
**Fix:** Added an instance `var displayRepresentation: DisplayRepresentation` that returns "Promote \"<sectionTitle>\"" when configured, "No section selected" otherwise.
**Watch out for:** other AppIntents protocols that mix static (`title`) and instance (`displayRepresentation`) requirements — the compiler error will name the *parent* protocol (`InstanceDisplayRepresentable`), not the one you adopted.

---

### 2026-04-27 — SwiftData crash on container init: `Unexpected property within Persisted Struct/Enum: _CalendarProtocol`
**Phase:** 1
**File:** `Fore/Model/LauncherSection.swift`, surfaces in `Fore/Store/ForeStore.swift` at `ModelContainer(for:)`
**Error message:** `SwiftData/SchemaProperty.swift:472: Fatal error: Unexpected property within Persisted Struct/Enum: _CalendarProtocol`
**Root cause:** `DateComponents` (used for `timeWindowStart` / `timeWindowEnd` per SPEC §3) holds a `Calendar?`. SwiftData reflects nested property graphs and cannot persist `Calendar` (a `_CalendarProtocol` existential). `DateComponents` is `Codable` in plain Foundation but unsupported by SwiftData's schema generator.
**Fix:** Replaced `DateComponents?` storage with four scalar `Int?` properties (`timeWindowStartHour/Minute`, `timeWindowEndHour/Minute`). Added a `DateComponents?` computed accessor extension so the rest of the app can keep using the spec's interface. Logged deviation in PROGRESS.md.
**Watch out for:** any future SwiftData `@Model` field whose type transitively contains `Calendar`, `Locale`, `TimeZone`, or other Foundation types backed by `_*Protocol` existentials. Prefer scalar storage + computed accessors.

---

