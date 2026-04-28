//
//  ForeFocusFilter.swift
//  ForeIntents (extension target)
//
//  iOS calls perform() in this extension process when the user activates a
//  Focus that has Fore configured as a filter (Settings → Focus → Filters →
//  Fore). We write the chosen section title to SharedDefaults; the main app
//  picks it up via FocusMonitor.reload() on next foreground.
//

import AppIntents
import Foundation
import OSLog

private let log = Logger(subsystem: "com.shawnbrown.Fore.ForeIntents", category: "FocusFilter")

struct ForeFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Configure Fore for Focus"
    static var description = IntentDescription(
        "Choose which Fore section is promoted while this Focus is active."
    )

    @Parameter(title: "Section to Promote")
    var sectionTitle: String?

    var displayRepresentation: DisplayRepresentation {
        if let title = sectionTitle, !title.isEmpty {
            return DisplayRepresentation(title: "Promote “\(title)”")
        } else {
            return DisplayRepresentation(title: "No section selected")
        }
    }

    func perform() async throws -> some IntentResult {
        log.notice("ForeFocusFilter.perform called with sectionTitle=\(sectionTitle ?? "(nil)", privacy: .public)")

        let suite = UserDefaults(suiteName: "group.com.shawnbrown.Fore")
        log.notice("App Group suite is \(suite == nil ? "NIL — entitlement missing" : "OK", privacy: .public)")

        log.notice("Active focus file path: \(SharedDefaults.activeFocusFilePath, privacy: .public)")

        SharedDefaults.activeFocusName = sectionTitle

        let readback = SharedDefaults.activeFocusName ?? "(nil)"
        log.notice("Readback after write: \(readback, privacy: .public)")

        SharedNotifications.postFocusDidChange()

        return .result()
    }
}
