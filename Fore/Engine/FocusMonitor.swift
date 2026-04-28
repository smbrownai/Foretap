//
//  FocusMonitor.swift
//  Fore
//
//  Holds the currently active iOS Focus mode name. The authoritative store
//  is the App Group SharedDefaults — ForeFocusFilter (in the extension
//  process) writes there when iOS activates a Focus, and the main app reads
//  on foreground / scenePhase change.
//

import Foundation
import Observation

@MainActor
@Observable
final class FocusMonitor {
    static let shared = FocusMonitor()

    private(set) var currentFocusName: String? = nil

    private init() {
        reload()
    }

    /// Re-read the active focus from SharedDefaults. Call on app foreground.
    func reload() {
        let stored = SharedDefaults.activeFocusName
        let normalized = stored?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentFocusName = (normalized?.isEmpty ?? true) ? nil : normalized
    }

    /// Programmatic update — used by the DEBUG focus override and (in-process)
    /// tests. Writes to SharedDefaults so any other process sees the change too.
    func update(focusName: String?) {
        SharedDefaults.activeFocusName = focusName
        reload()
    }
}
