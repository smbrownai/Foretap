//
//  SmallWidget.swift
//  ForeWidgets
//
//  2×2 grid: top 4 apps from the chosen section.
//

import SwiftUI
import WidgetKit

struct ForeSmallWidget: Widget {
    let kind: String = "ForeSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ForeWidgetConfiguration.self,
            provider: ForeTimelineProvider()
        ) { entry in
            ForeSmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fore — Small")
        .description("Top 4 apps from one of your Fore sections.")
        .supportedFamilies([.systemSmall])
    }
}

private struct ForeSmallWidgetView: View {
    let entry: ForeWidgetEntry

    var body: some View {
        if let section = entry.resolvedSection(), !section.apps.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(section.emoji).font(.caption)
                    Text(section.title)
                        .font(.caption2.bold())
                        .lineLimit(1)
                    Spacer()
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    alignment: .center,
                    spacing: 8
                ) {
                    ForEach(Array(section.apps.prefix(4))) { app in
                        WidgetAppButton(app: app, iconSize: 38, labelStyle: .none)
                    }
                }
            }
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Fore to set up sections")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
