//
//  UsageEvent.swift
//  Fore
//

import Foundation
import SwiftData

@Model
final class UsageEvent {
    var id: UUID
    var appScheme: String
    var launchedAt: Date
    var activeFocusName: String?
    var hourOfDay: Int
    var dayOfWeek: Int

    init(
        id: UUID = UUID(),
        appScheme: String,
        launchedAt: Date = .now,
        activeFocusName: String? = nil,
        hourOfDay: Int,
        dayOfWeek: Int
    ) {
        self.id = id
        self.appScheme = appScheme
        self.launchedAt = launchedAt
        self.activeFocusName = activeFocusName
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
    }
}
