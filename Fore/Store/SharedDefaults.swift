//
//  SharedDefaults.swift
//  Fore
//
//  Typed accessors over the App Group UserDefaults suite shared by:
//    - Fore (main app)
//    - ForeWidgetsExtension (widget process)
//    - ForeIntentsExtension (Focus filter intent process)
//
//  This file MUST be a member of all three targets in Xcode so each process
//  links its own copy of the symbols. The App Group entitlement
//  `group.com.shawnbrown.Fore` must be enabled on each target's
//  Signing & Capabilities tab.
//

import Foundation

enum SharedDefaults {
    nonisolated static let appGroupID = "group.com.shawnbrown.Fore"

    nonisolated static var suite: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            // If this fires, the App Group capability is missing on the
            // calling target. UserDefaults(suiteName:) returns nil only when
            // the suite is not entitled.
            assertionFailure("App Group \(appGroupID) is not configured on this target.")
            return .standard
        }
        return defaults
    }

    // MARK: - Active Focus
    //
    // Stored as a small file in the App Group container rather than in
    // UserDefaults. cfprefsd propagation between processes can lag the
    // Darwin notification by hundreds of ms; file reads are immediately
    // consistent across processes since both read straight off disk.

    private nonisolated static let kActiveFocus = "fore.activeFocusName"

    private nonisolated static var activeFocusFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("activeFocus.txt", isDirectory: false)
    }

    /// Diagnostic — exposes the resolved file URL so each process can log it.
    nonisolated static var activeFocusFilePath: String {
        activeFocusFileURL?.path ?? "(no container URL — App Group missing)"
    }

    nonisolated static var activeFocusName: String? {
        get {
            guard let url = activeFocusFileURL else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url),
                  let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        set {
            guard let url = activeFocusFileURL else { return }
            if let value = newValue, !value.isEmpty {
                try? value.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Widget Snapshot

    private nonisolated static let kWidgetSnapshot = "fore.widgetSnapshot"

    nonisolated static var widgetSnapshotData: Data? {
        get { suite.data(forKey: kWidgetSnapshot) }
        set {
            if let data = newValue {
                suite.set(data, forKey: kWidgetSnapshot)
            } else {
                suite.removeObject(forKey: kWidgetSnapshot)
            }
        }
    }

    // MARK: - Deep Link (intent → app)
    //
    // Set by OpenSectionIntent (and possibly other future intents) before
    // bringing the app to the foreground; consumed and cleared by HomeView
    // on next scenePhase → .active.

    private nonisolated static var pendingOpenSectionFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("pendingOpenSection.txt", isDirectory: false)
    }

    nonisolated static var pendingOpenSectionTitle: String? {
        get {
            guard let url = pendingOpenSectionFileURL,
                  FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        set {
            guard let url = pendingOpenSectionFileURL else { return }
            if let value = newValue, !value.isEmpty {
                try? value.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Pending Usage Queue (widget → app)

    private nonisolated static let kPendingUsage = "fore.pendingUsageQueue"

    /// Append-style queue of `PendingUsageEvent` rows the widget cannot write
    /// directly to SwiftData. Drained on app foreground by UsageQueueDrain.
    nonisolated static var pendingUsageData: Data? {
        get { suite.data(forKey: kPendingUsage) }
        set {
            if let data = newValue {
                suite.set(data, forKey: kPendingUsage)
            } else {
                suite.removeObject(forKey: kPendingUsage)
            }
        }
    }
}
