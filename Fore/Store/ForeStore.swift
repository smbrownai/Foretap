//
//  ForeStore.swift
//  Fore
//
//  Owns the shared SwiftData ModelContainer used by the app, intents, and
//  (eventually) the widget extension via App Groups.
//

import Foundation
import SwiftData

@MainActor
final class ForeStore {
    static let shared = ForeStore()

    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([
            AppEntry.self,
            LauncherSection.self,
            UsageEvent.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            self.container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Could not create ForeStore ModelContainer: \(error)")
        }
    }

    /// Returns apps in the section with the given title (Phase 1 helper used
    /// by intents in later phases).
    func apps(inSectionNamed title: String) -> [AppEntry] {
        let descriptor = FetchDescriptor<LauncherSection>(
            predicate: #Predicate { $0.title == title }
        )
        guard let section = try? context.fetch(descriptor).first else { return [] }
        return section.apps.sorted { $0.customSortIndex < $1.customSortIndex }
    }

    /// SPEC §14: on first launch, seed the three default sections.
    /// No-op if any section already exists.
    func bootstrapDefaultSectionsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<LauncherSection>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaults: [(String, String, SectionType, Int)] = [
            ("Pinned",           "📌", .pinned,          0),
            ("Recently Used",    "🕐", .recentlyUsed,    1),
            ("Frequently Used",  "🔥", .frequentlyUsed,  2),
        ]

        for (title, emoji, type, order) in defaults {
            let section = LauncherSection(
                title: title,
                emoji: emoji,
                type: type,
                displayOrder: order,
                maxVisible: 8
            )
            context.insert(section)
        }

        try? context.save()
    }
}
