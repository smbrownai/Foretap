//
//  AppPreferences.swift
//  Fore
//
//  Centralized @AppStorage keys + value types so views share the same
//  preference contract. Backed by standard UserDefaults (per-process); not
//  shared with widget/extension targets — those read from SharedDefaults.
//

import Foundation
import SwiftUI

enum AppIconSize: String, CaseIterable, Identifiable {
    case compact
    case standard
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact:  return "Compact"
        case .standard: return "Standard"
        case .large:    return "Large"
        }
    }

    /// Tile width/height in points used by AppIconView.
    var iconDimension: CGFloat {
        switch self {
        case .compact:  return 44
        case .standard: return 56
        case .large:    return 68
        }
    }
}

enum AppPreferenceKey {
    static let iconSize              = "fore.pref.iconSize"
    static let defaultSectionTitle   = "fore.pref.defaultSectionTitle"
    static let didCompleteOnboarding = "fore.pref.didCompleteOnboarding"

    /// When true, after the user successfully launches an app whose
    /// scheme they typed in via Add Custom App, Fore submits the
    /// (bundleId, scheme) pair to the backend so future users see
    /// it auto-filled. Default ON; user can flip it in Settings.
    /// See SchemeContribution + tools/backend.
    static let contributeSchemes     = "fore.pref.contributeSchemes"
}
