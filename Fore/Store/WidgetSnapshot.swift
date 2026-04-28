//
//  WidgetSnapshot.swift
//  Fore
//
//  Pure-Codable mirror of the section/app data the widget renders. The widget
//  cannot query SwiftData (different process, different sandbox), so the main
//  app serializes a snapshot to SharedDefaults whenever relevant state changes
//  and the widget decodes it inside its TimelineProvider.
//
//  Member of: Fore + ForeWidgetsExtension targets (no SwiftData dependency on
//  purpose — keeps the widget extension lean).
//

import Foundation

struct WidgetSnapshot: Codable, Equatable, Sendable {
    var generatedAt: Date
    var activeFocusName: String?
    var sections: [SnapshotSection]

    enum CodingKeys: String, CodingKey {
        case generatedAt
        case activeFocusName
        case sections
    }

    nonisolated init(generatedAt: Date, activeFocusName: String?, sections: [SnapshotSection]) {
        self.generatedAt = generatedAt
        self.activeFocusName = activeFocusName
        self.sections = sections
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        activeFocusName = try container.decodeIfPresent(String.self, forKey: .activeFocusName)
        sections = try container.decode([SnapshotSection].self, forKey: .sections)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(activeFocusName, forKey: .activeFocusName)
        try container.encode(sections, forKey: .sections)
    }
}

struct SnapshotSection: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var emoji: String
    var typeRaw: String
    var displayOrder: Int
    var maxVisible: Int
    var focusName: String?
    var apps: [SnapshotApp]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case emoji
        case typeRaw
        case displayOrder
        case maxVisible
        case focusName
        case apps
    }

    nonisolated init(
        id: UUID,
        title: String,
        emoji: String,
        typeRaw: String,
        displayOrder: Int,
        maxVisible: Int,
        focusName: String?,
        apps: [SnapshotApp]
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.typeRaw = typeRaw
        self.displayOrder = displayOrder
        self.maxVisible = maxVisible
        self.focusName = focusName
        self.apps = apps
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        emoji = try container.decode(String.self, forKey: .emoji)
        typeRaw = try container.decode(String.self, forKey: .typeRaw)
        displayOrder = try container.decode(Int.self, forKey: .displayOrder)
        maxVisible = try container.decode(Int.self, forKey: .maxVisible)
        focusName = try container.decodeIfPresent(String.self, forKey: .focusName)
        apps = try container.decode([SnapshotApp].self, forKey: .apps)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(typeRaw, forKey: .typeRaw)
        try container.encode(displayOrder, forKey: .displayOrder)
        try container.encode(maxVisible, forKey: .maxVisible)
        try container.encode(focusName, forKey: .focusName)
        try container.encode(apps, forKey: .apps)
    }
}

struct SnapshotApp: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var urlScheme: String
    var categoryRaw: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case urlScheme
        case categoryRaw
    }

    nonisolated init(id: UUID, name: String, urlScheme: String, categoryRaw: String) {
        self.id = id
        self.name = name
        self.urlScheme = urlScheme
        self.categoryRaw = categoryRaw
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlScheme = try container.decode(String.self, forKey: .urlScheme)
        categoryRaw = try container.decode(String.self, forKey: .categoryRaw)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(urlScheme, forKey: .urlScheme)
        try container.encode(categoryRaw, forKey: .categoryRaw)
    }
}

extension WidgetSnapshot {
    nonisolated static let empty = WidgetSnapshot(
        generatedAt: .distantPast,
        activeFocusName: nil,
        sections: []
    )

    nonisolated static func decode(from data: Data?) -> WidgetSnapshot {
        guard let data else { return .empty }
        return (try? JSONDecoder().decode(WidgetSnapshot.self, from: data)) ?? .empty
    }

    nonisolated func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
