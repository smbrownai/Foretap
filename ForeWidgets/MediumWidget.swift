//
//  MediumWidget.swift
//  ForeWidgets
//
//  4×2: section header + up to 8 apps.
//

import SwiftUI
import WidgetKit

struct ForeMediumWidget: Widget {
    let kind: String = "ForeMediumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ForeWidgetConfiguration.self,
            provider: ForeTimelineProvider()
        ) { entry in
            ForeMediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fore — Medium")
        .description("Show one Fore section, up to 8 apps.")
        .supportedFamilies([.systemMedium])
    }
}

private struct ForeMediumWidgetView: View {
    let entry: ForeWidgetEntry

    var body: some View {
        if let section = entry.resolvedSection(), !section.apps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(section.emoji).font(.caption)
                    Text(section.title)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Spacer()
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                    alignment: .center,
                    spacing: 6
                ) {
                    ForEach(Array(section.apps.prefix(8))) { app in
                        WidgetAppButton(app: app, iconSize: 36, labelStyle: .below)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.grid.3x2")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Open Fore to add apps to a section")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
