//
//  SectionSorter.swift
//  Fore
//
//  Resolves the live app list to render for each section type, plus the
//  priority score formula from SPEC §7.1.
//

import Foundation

struct SectionSorter {

    /// SPEC §8.3 — promotion order: focus-active → pinned → user displayOrder.
    /// Disabled sections are filtered out. Stable for the rest.
    static func sortedSections(
        _ sections: [LauncherSection],
        activeFocus: String?
    ) -> [LauncherSection] {
        sections
            .filter { $0.isEnabled }
            .sorted { a, b in
                if let focus = activeFocus {
                    let aActive = a.type == .focusBased && a.focusName == focus
                    let bActive = b.type == .focusBased && b.focusName == focus
                    if aActive != bActive { return aActive }
                }
                let aPinned = a.type == .pinned
                let bPinned = b.type == .pinned
                if aPinned != bPinned { return aPinned }
                return a.displayOrder < b.displayOrder
            }
    }

    /// SPEC §7.1 — frequency (log) + recency (3-day half-life) + ±2hr time affinity.
    static func priorityScore(
        for scheme: String,
        events: [UsageEvent],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let appEvents = events.filter { $0.appScheme == scheme }
        guard !appEvents.isEmpty else { return 0 }

        let frequency = log(Double(appEvents.count) + 1) * 10.0

        let recency = appEvents
            .map { exp(-now.timeIntervalSince($0.launchedAt) / 259_200) }
            .reduce(0, +) * 20.0

        let currentHour = calendar.component(.hour, from: now)
        let timeAffinity = Double(
            appEvents.filter { abs($0.hourOfDay - currentHour) <= 2 }.count
        ) * 5.0

        return frequency + recency + timeAffinity
    }

    /// The ordered apps to display for a given section. For manual/pinned/
    /// timeBased/focusBased this is just `section.apps` sorted; for the auto
    /// types it derives from UsageEvents.
    static func resolvedApps(
        for section: LauncherSection,
        usageEvents: [UsageEvent],
        allApps: [AppEntry],
        now: Date = .now
    ) -> [AppEntry] {
        let cap = max(section.maxVisible, 0)

        switch section.type {
        case .pinned, .manual, .timeBased, .focusBased:
            return section.apps.sorted { $0.customSortIndex < $1.customSortIndex }

        case .recentlyUsed:
            return resolveRecent(events: usageEvents, allApps: allApps, cap: cap)

        case .frequentlyUsed:
            return resolveFrequent(events: usageEvents, allApps: allApps, cap: cap, now: now)
        }
    }

    // MARK: -

    /// Last N unique schemes by recency. SPEC §7.2 says "query last 20 events,
    /// dedupe, take top maxVisible."
    private static func resolveRecent(
        events: [UsageEvent],
        allApps: [AppEntry],
        cap: Int
    ) -> [AppEntry] {
        let sorted = events.sorted { $0.launchedAt > $1.launchedAt }
        let window = sorted.prefix(20)

        let appsByScheme = Dictionary(grouping: allApps, by: \.urlScheme)
            .compactMapValues(\.first)

        var seen = Set<String>()
        var result: [AppEntry] = []
        for event in window {
            guard !seen.contains(event.appScheme) else { continue }
            seen.insert(event.appScheme)
            if let app = appsByScheme[event.appScheme] {
                result.append(app)
                if result.count >= cap { break }
            }
        }
        return result
    }

    /// Top N by priority score over the last 30 days.
    private static func resolveFrequent(
        events: [UsageEvent],
        allApps: [AppEntry],
        cap: Int,
        now: Date
    ) -> [AppEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86_400)
        let recentWindow = events.filter { $0.launchedAt >= cutoff }
        let schemes = Set(recentWindow.map(\.appScheme))

        let scored: [(String, Double)] = schemes.map { scheme in
            (scheme, priorityScore(for: scheme, events: recentWindow, now: now))
        }
        let ordered = scored.sorted { $0.1 > $1.1 }

        let appsByScheme = Dictionary(grouping: allApps, by: \.urlScheme)
            .compactMapValues(\.first)

        var result: [AppEntry] = []
        for (scheme, _) in ordered {
            if let app = appsByScheme[scheme] {
                result.append(app)
                if result.count >= cap { break }
            }
        }
        return result
    }
}
