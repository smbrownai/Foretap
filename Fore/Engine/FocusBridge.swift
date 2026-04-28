//
//  FocusBridge.swift
//  Fore
//
//  Listens for the Darwin notification posted by ForeFocusFilter (in the
//  intents extension) and pokes FocusMonitor to re-read SharedDefaults.
//  Without this, the main app only refreshes its focus state on scenePhase
//  transitions — which doesn't fire when iOS activates a Focus while Fore is
//  already foregrounded (e.g., from Control Center).
//

import Foundation
import OSLog

private let log = Logger(subsystem: "com.shawnbrown.Fore", category: "FocusBridge")

@MainActor
enum FocusBridge {
    private static var started = false

    static func startObserving() {
        guard !started else { return }
        started = true

        // The "observer" pointer is required by CFNotificationCenter but we
        // don't use it inside the C callback — we just route to the main-actor
        // FocusMonitor singleton. A stable, non-nil token is enough.
        let token = Unmanaged.passUnretained(FocusMonitor.shared).toOpaque()

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            token,
            { _, _, _, _, _ in
                // Darwin callback runs on an arbitrary thread; hop to main.
                Task { @MainActor in
                    log.notice("FocusBridge callback fired")
                    log.notice("Active focus file path: \(SharedDefaults.activeFocusFilePath, privacy: .public)")
                    FocusMonitor.shared.reload()
                    log.notice("After reload: currentFocusName=\(FocusMonitor.shared.currentFocusName ?? "(nil)", privacy: .public)")
                }
            },
            SharedNotifications.focusDidChange,
            nil,
            .deliverImmediately
        )

        log.notice("FocusBridge.startObserving registered observer for \(SharedNotifications.focusDidChange as String, privacy: .public)")
    }
}
