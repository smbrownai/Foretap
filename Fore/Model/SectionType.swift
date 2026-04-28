//
//  SectionType.swift
//  Fore
//

import Foundation

enum SectionType: String, Codable, CaseIterable {
    case pinned
    case recentlyUsed
    case frequentlyUsed
    case timeBased
    case focusBased
    case manual
}
