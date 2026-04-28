//
//  AppIconView.swift
//  Fore
//

import SwiftUI
import SwiftData
import UIKit

struct AppIconView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppPreferenceKey.iconSize) private var iconSizeRaw: String = AppIconSize.standard.rawValue

    let app: AppEntry
    var onRemove: (() -> Void)? = nil

    private var iconSize: CGFloat {
        (AppIconSize(rawValue: iconSizeRaw) ?? .standard).iconDimension
    }

    var body: some View {
        VStack(spacing: 6) {
            iconTile
                .frame(width: iconSize, height: iconSize)

            Text(app.name)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: iconSize + 12)
        }
        .contentShape(Rectangle())
        .onTapGesture { launch() }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove from Section", systemImage: "minus.circle")
                }
            }
        }
        .accessibilityLabel(Text(app.name))
        .accessibilityHint(Text("Launches \(app.name)"))
    }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(app.category.tint.gradient)
            .overlay(
                Image(systemName: app.category.sfSymbol)
                    .font(.system(size: iconSize * 0.43, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .opacity(app.isInstalled ? 1.0 : 0.4)
    }

    private func launch() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard let url = URL(string: app.urlScheme) else { return }
        let scheme = app.urlScheme

        Task { @MainActor in
            let opened = await UIApplication.shared.open(url)
            if opened {
                UsageTracker.record(scheme: scheme, app: app, in: modelContext)
            }
        }
    }
}
