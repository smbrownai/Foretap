//
//  OpenSectionIntent.swift
//  Fore
//
//  "Open my Work section in Fore" — brings Fore to the foreground and scrolls
//  to the named section. We write the request to SharedDefaults; HomeView
//  reads and clears it on the next scenePhase → .active.
//

import AppIntents
import Foundation

struct OpenSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Section in Fore"
    static var description = IntentDescription("Open Fore and scroll to a section.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Section", optionsProvider: SectionTitleOptionsProvider())
    var sectionTitle: String

    init() {}
    init(sectionTitle: String) { self.sectionTitle = sectionTitle }

    func perform() async throws -> some IntentResult {
        SharedDefaults.pendingOpenSectionTitle = sectionTitle
        return .result()
    }
}
