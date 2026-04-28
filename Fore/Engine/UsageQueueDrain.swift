//
//  UsageQueueDrain.swift
//  Fore
//
//  Drains the shared widget-launch queue into SwiftData on app foreground.
//  Member of: Fore target only (uses SwiftData @Model types).
//

import Foundation
import SwiftData

@MainActor
struct UsageQueueDrain {
    static func drain(in context: ModelContext) {
        let pending = SharedUsageQueue.drainAll()
        guard !pending.isEmpty else { return }

        let allApps = (try? context.fetch(FetchDescriptor<AppEntry>())) ?? []
        let appsByScheme = Dictionary(grouping: allApps, by: \.urlScheme)
            .compactMapValues(\.first)

        for entry in pending {
            let event = UsageEvent(
                appScheme: entry.appScheme,
                launchedAt: entry.launchedAt,
                activeFocusName: SharedDefaults.activeFocusName,
                hourOfDay: entry.hourOfDay,
                dayOfWeek: entry.dayOfWeek
            )
            context.insert(event)

            if let app = appsByScheme[entry.appScheme] {
                app.launchCount += 1
                app.lastLaunched = max(app.lastLaunched ?? .distantPast, entry.launchedAt)
            }
        }

        try? context.save()
    }
}
