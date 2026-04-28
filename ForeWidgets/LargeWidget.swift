//
//  LargeWidget.swift
//  ForeWidgets
//
//  4×4: two sections stacked, up to 16 apps total.
//

import SwiftUI
import WidgetKit

struct ForeLargeWidget: Widget {
    let kind: String = "ForeLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ForeWidgetConfiguration.self,
            provider: ForeTimelineProvider()
        ) { entry in
            ForeLargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fore — Large")
        .description("Two Fore sections side-by-side, up to 16 apps.")
        .supportedFamilies([.systemLarge])
    }
}

private struct ForeLargeWidgetView: View {
    let entry: ForeWidgetEntry

    var body: some View {
        let primary = entry.resolvedSection()
        let secondary = entry.resolvedSecondarySection()

        VStack(alignment: .leading, spacing: 10) {
            sectionBlock(primary, appCap: 8)
            Divider().opacity(0.3)
            sectionBlock(secondary, appCap: 8)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: SnapshotSection?, appCap: Int) -> some View {
        if let section, !section.apps.isEmpty {
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
                    ForEach(Array(section.apps.prefix(appCap))) { app in
                        WidgetAppButton(app: app, iconSize: 36, labelStyle: .below)
                    }
                }
            }
        } else {
            HStack {
                Image(systemName: "square.dashed")
                    .foregroundStyle(.secondary)
                Text("No section configured")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}
