//
//  DataReset.swift
//  Fore
//
//  Destructive operations exposed in SettingsView. Each is wrapped in a
//  confirmation alert at the call site.
//

import Foundation
import SwiftData

@MainActor
struct DataReset {
    /// Wipes every UsageEvent. AppEntry.launchCount / lastLaunched cache
    /// fields are also cleared so Recently/Frequently sections start empty.
    static func resetUsageData(in context: ModelContext) {
        let events = (try? context.fetch(FetchDescriptor<UsageEvent>())) ?? []
        for e in events { context.delete(e) }

        let apps = (try? context.fetch(FetchDescriptor<AppEntry>())) ?? []
        for app in apps {
            app.launchCount = 0
            app.lastLaunched = nil
        }

        try? context.save()
    }

    /// Deletes every section AND every AppEntry. The bootstrap will recreate
    /// the three default sections on next foreground.
    static func resetAllSections(in context: ModelContext) {
        let sections = (try? context.fetch(FetchDescriptor<LauncherSection>())) ?? []
        for s in sections { context.delete(s) }

        let apps = (try? context.fetch(FetchDescriptor<AppEntry>())) ?? []
        for a in apps { context.delete(a) }

        try? context.save()
    }
}
