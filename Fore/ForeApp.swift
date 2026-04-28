//
//  ForeApp.swift
//  Fore
//

import SwiftUI
import SwiftData

@main
struct ForeApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(ForeStore.shared.container)
    }
}
