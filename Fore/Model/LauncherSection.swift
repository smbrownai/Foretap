//
//  LauncherSection.swift
//  Fore
//

import Foundation
import SwiftData

@Model
final class LauncherSection {
    var id: UUID
    var title: String
    var emoji: String
    var type: SectionType
    var displayOrder: Int
    var maxVisible: Int
    var isEnabled: Bool

    @Relationship(deleteRule: .nullify, inverse: \AppEntry.section)
    var apps: [AppEntry] = []

    var focusName: String?

    // Time window stored as hour/minute scalars rather than DateComponents
    // because SwiftData cannot reflect Calendar-bearing types. See
    // PROGRESS.md → Decisions Made.
    var timeWindowStartHour: Int?
    var timeWindowStartMinute: Int?
    var timeWindowEndHour: Int?
    var timeWindowEndMinute: Int?

    init(
        id: UUID = UUID(),
        title: String,
        emoji: String,
        type: SectionType,
        displayOrder: Int = 0,
        maxVisible: Int = 8,
        isEnabled: Bool = true,
        focusName: String? = nil,
        timeWindowStart: DateComponents? = nil,
        timeWindowEnd: DateComponents? = nil
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.type = type
        self.displayOrder = displayOrder
        self.maxVisible = maxVisible
        self.isEnabled = isEnabled
        self.focusName = focusName
        self.timeWindowStartHour = timeWindowStart?.hour
        self.timeWindowStartMinute = timeWindowStart?.minute
        self.timeWindowEndHour = timeWindowEnd?.hour
        self.timeWindowEndMinute = timeWindowEnd?.minute
    }
}

extension LauncherSection {
    var timeWindowStart: DateComponents? {
        get {
            guard let h = timeWindowStartHour else { return nil }
            return DateComponents(hour: h, minute: timeWindowStartMinute ?? 0)
        }
        set {
            timeWindowStartHour = newValue?.hour
            timeWindowStartMinute = newValue?.minute
        }
    }

    var timeWindowEnd: DateComponents? {
        get {
            guard let h = timeWindowEndHour else { return nil }
            return DateComponents(hour: h, minute: timeWindowEndMinute ?? 0)
        }
        set {
            timeWindowEndHour = newValue?.hour
            timeWindowEndMinute = newValue?.minute
        }
    }
}
