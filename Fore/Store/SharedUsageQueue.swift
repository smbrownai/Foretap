//
//  SharedUsageQueue.swift
//  Fore
//
//  Cross-process append-only queue of usage events the widget cannot write
//  directly to SwiftData. The widget's LaunchAppIntent calls `append(...)`
//  in its own process; the main app drains the queue (via UsageQueueDrain)
//  on next foreground.
//
//  Member of: Fore + ForeWidgetsExtension targets. (ForeIntentsExtension does
//  not need this — focus filter doesn't generate launch events.)
//

import Foundation

struct PendingUsageEvent: Codable, Equatable, Sendable {
    var appScheme: String
    var launchedAt: Date
    var hourOfDay: Int
    var dayOfWeek: Int
}

enum SharedUsageQueue {
    nonisolated static func append(scheme: String, at date: Date = .now) {
        let cal = Calendar.current
        let event = PendingUsageEvent(
            appScheme: scheme,
            launchedAt: date,
            hourOfDay: cal.component(.hour, from: date),
            dayOfWeek: cal.component(.weekday, from: date)
        )

        var existing: [PendingUsageEvent] = {
            guard let data = SharedDefaults.pendingUsageData else { return [] }
            return (try? JSONDecoder().decode([PendingUsageEvent].self, from: data)) ?? []
        }()
        existing.append(event)

        SharedDefaults.pendingUsageData = try? JSONEncoder().encode(existing)
    }

    nonisolated static func drainAll() -> [PendingUsageEvent] {
        guard let data = SharedDefaults.pendingUsageData else { return [] }
        let events = (try? JSONDecoder().decode([PendingUsageEvent].self, from: data)) ?? []
        SharedDefaults.pendingUsageData = nil
        return events
    }
}
