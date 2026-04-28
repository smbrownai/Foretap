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
        self.section = section
        self.launchCount = launchCount
        self.lastLaunched = lastLaunched
    }
}
