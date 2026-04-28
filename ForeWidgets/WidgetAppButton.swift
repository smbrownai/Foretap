//
//  WidgetAppButton.swift
//  ForeWidgets
//
//  One tappable app icon inside a widget — Button(intent:) backed by
//  LaunchAppIntent. Tapping opens the target app (via OpenURLIntent) and
//  enqueues a usage event in the shared queue for the main app to drain.
//

import SwiftUI
import WidgetKit
import AppIntents

struct WidgetAppButton: View {
    let app: SnapshotApp
    var iconSize: CGFloat = 40
    var labelStyle: LabelStyle = .below

    enum LabelStyle {
        case below
        case none
    }

    private var category: AppCategory {
        AppCategory(rawValue: app.categoryRaw) ?? .other
    }

    var body: some View {
        Button(intent: LaunchAppIntent(urlScheme: app.urlScheme, appName: app.name)) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.tint.gradient)
                    .frame(width: iconSize, height: iconSize)
                    .overlay(
                        Image(systemName: category.sfSymbol)
                            .font(.system(size: iconSize * 0.45, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                if labelStyle == .below {
                    Text(app.name)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: iconSize + 16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
