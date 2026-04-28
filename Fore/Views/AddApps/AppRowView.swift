//
//  AppRowView.swift
//  Fore
//

import SwiftUI

struct AppRowView: View {
    let entry: AppDatabaseEntry
    let isInstalled: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                miniIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(entry.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isInstalled {
                    Text("Not installed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var miniIcon: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(entry.category.tint.gradient)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: entry.category.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .opacity(isInstalled ? 1.0 : 0.4)
    }
}
