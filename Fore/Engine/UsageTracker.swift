//
//  UsageTracker.swift
//  Fore
//
//  Phase 2 minimum: writes a UsageEvent and updates the AppEntry cache
//  fields (launchCount, lastLaunched). Pruning + scoring arrive in Phase 3.
//

import Foundation
import SwiftData

@MainActor
struct UsageTracker {
    static func record(
        scheme: String,
        app: AppEntry?,
        focusName: String? = nil,
        in context: ModelContext
    ) {
        let now = Date()
        let cal = Calendar.current
        let event = UsageEvent(
            appScheme: scheme,
            launchedAt: now,
            activeFocusName: focusName,
            hourOfDay: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now)
        )
        context.insert(event)

        if let app {
            app.launchCount += 1
            app.lastLaunched = now
        }

        try? context.save()
    }

    /// SPEC §7.3 — drop UsageEvents older than `days`. Called on app foreground.
    static func pruneOldEvents(olderThan days: Int = 90, in context: ModelContext) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return }
        let descriptor = FetchDescriptor<UsageEvent>(
            predicate: #Predicate { $0.launchedAt < cutoff }
        )
        let stale = (try? context.fetch(descriptor)) ?? []
        guard !stale.isEmpty else { return }
        for event in stale { context.delete(event) }
        try? context.save()
    }
}
