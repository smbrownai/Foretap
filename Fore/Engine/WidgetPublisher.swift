//
//  WidgetPublisher.swift
//  Fore
//
//  Builds a WidgetSnapshot from the live SwiftData store + active focus and
//  writes it to SharedDefaults, then tells WidgetKit to refresh timelines.
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
struct WidgetPublisher {
    /// Resolves each section's app list (using SectionSorter so auto sections
    /// are populated correctly) and writes the snapshot. Cheap enough to run
    /// on every relevant state change.
    static func publish(in context: ModelContext) {
        let sectionDescriptor = FetchDescriptor<LauncherSection>(
            sortBy: [SortDescriptor(\LauncherSection.displayOrder)]
        )
        let sections = (try? context.fetch(sectionDescriptor)) ?? []

        let allApps = (try? context.fetch(FetchDescriptor<AppEntry>())) ?? []

        let eventsDescriptor = FetchDescriptor<UsageEvent>(
            sortBy: [SortDescriptor(\UsageEvent.launchedAt, order: .reverse)]
        )
        let usageEvents = (try? context.fetch(eventsDescriptor)) ?? []

        let activeFocus = SharedDefaults.activeFocusName
        let ordered = SectionSorter.sortedSections(sections, activeFocus: activeFocus)

        let snapshotSections: [SnapshotSection] = ordered.map { section in
            let apps = SectionSorter.resolvedApps(
                for: section,
                usageEvents: usageEvents,
                allApps: allApps
            )
            return SnapshotSection(
                id: section.id,
                title: section.title,
                emoji: section.emoji,
                typeRaw: section.type.rawValue,
                displayOrder: section.displayOrder,
                maxVisible: section.maxVisible,
                focusName: section.focusName,
                apps: apps.map {
                    SnapshotApp(
                        id: $0.id,
                        name: $0.name,
                        urlScheme: $0.urlScheme,
                        categoryRaw: $0.category.rawValue
                    )
                }
            )
        }

        let snapshot = WidgetSnapshot(
            generatedAt: .now,
            activeFocusName: activeFocus,
            sections: snapshotSections
        )

        SharedDefaults.widgetSnapshotData = snapshot.encoded()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
