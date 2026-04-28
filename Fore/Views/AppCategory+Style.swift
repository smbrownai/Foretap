//
//  AppCategory+Style.swift
//  Fore
//
//  Presentation-only mapping: per-category SF Symbol + tint. Lives in Views/
//  so the Model layer stays free of SwiftUI imports.
//

import SwiftUI

extension AppCategory {
    var sfSymbol: String {
        switch self {
        case .productivity: return "briefcase.fill"
        case .social:       return "person.2.fill"
        case .entertainment:return "tv.fill"
        case .health:       return "heart.fill"
        case .finance:      return "dollarsign.circle.fill"
        case .travel:       return "airplane"
        case .utilities:    return "wrench.and.screwdriver.fill"
        case .news:         return "newspaper.fill"
        case .music:        return "music.note"
        case .developer:    return "chevron.left.forwardslash.chevron.right"
        case .shopping:     return "bag.fill"
        case .food:         return "fork.knife"
        case .education:    return "book.fill"
        case .other:        return "app.fill"
        }
    }

    var tint: Color {
        switch self {
        case .productivity: return .blue
        case .social:       return .pink
        case .entertainment:return .red
        case .health:       return .green
        case .finance:      return .mint
        case .travel:       return .cyan
        case .utilities:    return .gray
        case .news:         return .orange
        case .music:        return .purple
        case .developer:    return .indigo
        case .shopping:     return .yellow
        case .food:         return Color(.systemOrange)
        case .education:    return .teal
        case .other:        return .secondary
        }
    }

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}
