//
//  ForeWidgetEntry.swift
//  ForeWidgets
//
//  Configuration intent + TimelineEntry + AppIntentTimelineProvider, all
//  consumed by the three widget definitions.
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - Configuration

struct ForeWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Fore Widget"
    static var description = IntentDescription("Pick which Fore section this widget shows.")

    /// User picks which section to display by long-pressing the widget. If
    /// empty, the widget falls back to the first section in the snapshot
    /// (which honors any active Focus promotion since WidgetPublisher already
    /// applied SectionSorter.sortedSections).
    @Parameter(title: "Section title")
    var sectionTitle: String?

    init() {}
    init(sectionTitle: String?) { self.sectionTitle = sectionTitle }
}

// MARK: - Entry

struct ForeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let configuration: ForeWidgetConfiguration

    /// Returns the section the widget should render given its configuration.
    /// Falls back to the first section in the snapshot if no match.
    func resolvedSection() -> SnapshotSection? {
        if let title = configuration.sectionTitle, !title.isEmpty,
           let match = snapshot.sections.first(where: { $0.title == title }) {
            return match
        }
        return snapshot.sections.first
    }

    /// For the Large widget — the next non-equal section after the first one.
    func resolvedSecondarySection() -> SnapshotSection? {
        let primary = resolvedSection()
        return snapshot.sections.first { $0.id != primary?.id }
    }
}

// MARK: - Provider

struct ForeTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = ForeWidgetConfiguration
    typealias Entry = ForeWidgetEntry

    func placeholder(in context: Context) -> ForeWidgetEntry {
        ForeWidgetEntry(date: .now, snapshot: .empty, configuration: ForeWidgetConfiguration())
    }

    func snapshot(for configuration: ForeWidgetConfiguration, in context: Context) async -> ForeWidgetEntry {
        ForeWidgetEntry(
            date: .now,
            snapshot: WidgetSnapshot.decode(from: SharedDefaults.widgetSnapshotData),
            configuration: configuration
        )
    }

    func timeline(for configuration: ForeWidgetConfiguration, in context: Context) async -> Timeline<ForeWidgetEntry> {
        let snapshot = WidgetSnapshot.decode(from: SharedDefaults.widgetSnapshotData)
        let entry = ForeWidgetEntry(date: .now, snapshot: snapshot, configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }
}
