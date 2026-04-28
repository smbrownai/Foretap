//
//  IntentOptionsProviders.swift
//  Fore
//
//  DynamicOptionsProviders that drive Shortcuts/Siri parameter pickers — one
//  for picking a Fore section title, one for picking a known app from the
//  bundled AppDatabase.json. Both read fast, no SwiftData dependency.
//

import AppIntents
import Foundation

struct SectionTitleOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let snapshot = WidgetSnapshot.decode(from: SharedDefaults.widgetSnapshotData)
        return snapshot.sections.map(\.title)
    }
}

struct AppNameOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let entries = (try? AppDatabaseLoader.loadBundledEntries()) ?? []
        return entries
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
