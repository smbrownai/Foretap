//
//  AppRowView.swift
//  Fore
//

import SwiftUI

struct AppRowView: View {
    let entry: AppDatabaseEntry
    let status: AppDatabaseLoader.InstallStatus
    let isSelected: Bool
    let onToggle: () -> Void

    private var statusLabel: String? {
        switch status {
        case .installed:    return nil
        case .notInstalled: return "Not installed"
        case .unverified:   return "Status unknown"
        case .noScheme:     return "Tap to add scheme"
        }
    }

    private var iconOpacity: Double {
        switch status {
        case .installed:    return 1.0
        case .unverified:   return 0.85
        case .notInstalled: return 0.4
        case .noScheme:     return 0.55
        }
    }

    private var trailingIcon: some View {
        Group {
            if status == .noScheme {
                Image(systemName: "plus.circle.dashed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                miniIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let dev = entry.developer, !dev.isEmpty {
                            Text(dev)
                                .lineLimit(1)
                        } else {
                            Text(entry.category.displayName)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let statusLabel {
                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                trailingIcon
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Real App Store artwork when we have a URL; otherwise the
    /// category-tinted SF symbol fallback so the row never looks empty.
    private var miniIcon: some View {
        Group {
            if let urlString = entry.iconURL, let url = URL(string: urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.15))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.medium)
                    case .empty, .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(iconOpacity)
    }

    private var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(entry.category.tint.gradient)
            .overlay(
                Image(systemName: entry.category.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
