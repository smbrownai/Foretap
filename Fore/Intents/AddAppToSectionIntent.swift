//
//  AddAppToSectionIntent.swift
//  Fore
//
//  "Add Notion to my Pinned section in Fore" — looks up the app in the
//  bundled database by name, finds the section by title, and assigns
//  (or creates and assigns) the AppEntry. Runs in-process in the main app
//  so we have direct SwiftData access; not bringing the app forward.
//

import AppIntents
import Foundation
import SwiftData

struct AddAppToSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add App to Section in Fore"
    static var description = IntentDescription("Add an app from the Fore database to one of your sections.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App", optionsProvider: AppNameOptionsProvider())
    var appName: String

    @Parameter(title: "Section", optionsProvider: SectionTitleOptionsProvider())
    var sectionTitle: String

    init() {}
    init(appName: String, sectionTitle: String) {
        self.appName = appName
        self.sectionTitle = sectionTitle
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dbEntries = (try? AppDatabaseLoader.loadBundledEntries()) ?? []
        guard let dbEntry = dbEntries.first(where: {
            $0.name.localizedCaseInsensitiveCompare(appName) == .orderedSame
        }) else {
            return .result(dialog: "Couldn't find an app named \(appName) in Fore's database.")
        }

        let context = ForeStore.shared.context
        let title = sectionTitle
        let sectionDescriptor = FetchDescriptor<LauncherSection>(
            predicate: #Predicate { $0.title == title }
        )
        guard let section = try? context.fetch(sectionDescriptor).first else {
            return .result(dialog: "Couldn't find a section named \(sectionTitle).")
        }

        let scheme = dbEntry.urlScheme
        let appDescriptor = FetchDescriptor<AppEntry>(
            predicate: #Predicate { $0.urlScheme == scheme }
        )
        let existing = try? context.fetch(appDescriptor).first

        let app: AppEntry
        if let existing {
            app = existing
        } else {
            app = AppEntry(
                name: dbEntry.name,
                urlScheme: dbEntry.urlScheme,
                category: dbEntry.category
            )
            context.insert(app)
        }

        app.section = section
        app.customSortIndex = (section.apps.map(\.customSortIndex).max() ?? -1) + 1

        try? context.save()

        return .result(dialog: "Added \(dbEntry.name) to \(section.title).")
    }
}
