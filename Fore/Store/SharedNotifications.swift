//
//  SharedNotifications.swift
//  Fore
//
//  Cross-process notification names + helpers built on Darwin notifications.
//  Used to ping the main app from the ForeIntents extension when the active
//  Focus changes, and (Phase 5 chunk B) from the widget when usage events are
//  enqueued.
//
//  Member of: Fore + ForeIntentsExtension + ForeWidgetsExtension targets.
//

import Foundation

enum SharedNotifications {
    nonisolated static let focusDidChange = "com.shawnbrown.Fore.focusDidChange" as CFString

    nonisolated static func postFocusDidChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(focusDidChange),
            nil, nil, true
        )
    }
}
