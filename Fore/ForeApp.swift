//
//  ForeApp.swift
//  Fore
//

import SwiftUI
import SwiftData

@main
struct ForeApp: App {
    init() {
        // Register defaults for any preference keys that aren't bound via
        // @AppStorage with an inline default. contributeSchemes defaults
        // ON so first-time users help build the catalog without an opt-in
        // tap; Settings → Help build the catalog can flip it off.
        UserDefaults.standard.register(defaults: [
            AppPreferenceKey.contributeSchemes: true,
        ])

        // Kick off a CDN refresh on cold start. Best-effort; if the
        // backend isn't configured yet (placeholder host) this no-ops.
        DatabaseRefresh.refreshIfStale()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(ForeStore.shared.container)
    }
}
