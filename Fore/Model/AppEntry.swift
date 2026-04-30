//
//  AppEntry.swift
//  Fore
//

import Foundation
import SwiftData

@Model
final class AppEntry {
    var id: UUID
    var name: String
    var urlScheme: String
    var category: AppCategory
    var isInstalled: Bool
    var dateAdded: Date
    var customSortIndex: Int

    /// Bundle identifier from the App Store database, when known.
    /// Set when the AppEntry came from a database row that we matched
    /// to an iTunes result; nil for purely-custom apps the user typed
    /// in. When non-nil and the scheme launches successfully, we
    /// submit the (bundleId, scheme) pair to the community backend.
    var bundleId: String?

    var section: LauncherSection?

    var launchCount: Int
    var lastLaunched: Date?

    init(
        id: UUID = UUID(),
        name: String,
        urlScheme: String,
        category: AppCategory,
        isInstalled: Bool = false,
        dateAdded: Date = .now,
        customSortIndex: Int = 0,
        bundleId: String? = nil,
        section: LauncherSection? = nil,
        launchCount: Int = 0,
        lastLaunched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.urlScheme = urlScheme
        self.category = category
        self.isInstalled = isInstalled
        self.dateAdded = dateAdded
        self.customSortIndex = customSortIndex
        self.bundleId = bundleId
        self.section = section
        self.launchCount = launchCount
        self.lastLaunched = lastLaunched
    }
}
