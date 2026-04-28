//
//  DataExporter.swift
//  Fore
//
//  Encodes all UsageEvents to JSON for export via the iOS share sheet.
//

import Foundation
import SwiftData

@MainActor
struct DataExporter {
    struct ExportedEvent: Codable {
        var appScheme: String
        var launchedAt: Date
        var activeFocusName: String?
        var hourOfDay: Int
        var dayOfWeek: Int
    }

    /// Returns a URL to a temporary `.json` file containing all usage events.
    /// Caller passes the URL to a share sheet; the file is in the temp
    /// directory and will be cleaned up by iOS.
    static func exportUsageEvents(in context: ModelContext) throws -> URL {
        let events = (try? context.fetch(
            FetchDescriptor<UsageEvent>(sortBy: [SortDescriptor(\UsageEvent.launchedAt, order: .reverse)])
        )) ?? []

        let payload = events.map {
            ExportedEvent(
                appScheme: $0.appScheme,
                launchedAt: $0.launchedAt,
                activeFocusName: $0.activeFocusName,
                hourOfDay: $0.hourOfDay,
                dayOfWeek: $0.dayOfWeek
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fore-usage-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
