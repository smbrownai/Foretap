//
//  GetTopAppsIntent.swift
//  Fore
//
//  "Get my top apps from Fore" — returns the top N app names by current
//  priority score. Reads from the App Group widget snapshot (which already
//  has the resolved Frequently Used app list) so the intent works without
//  hitting SwiftData and without bringing Fore forward.
//

import AppIntents
import Foundation

struct GetTopAppsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Top Apps from Fore"
    static var description = IntentDescription("Returns the top N apps by current priority score.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Count", default: 5)
    var count: Int

    init() {}
    init(count: Int = 5) { self.count = count }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let snapshot = WidgetSnapshot.decode(from: SharedDefaults.widgetSnapshotData)
        let frequent = snapshot.sections.first { $0.typeRaw == "frequentlyUsed" }
        let names = (frequent?.apps ?? snapshot.sections.flatMap(\.apps))
            .prefix(max(count, 0))
            .map(\.name)
        return .result(value: Array(names))
    }
}
