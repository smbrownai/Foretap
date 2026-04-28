//
//  SectionRowView.swift
//  Fore
//

import SwiftUI
import SwiftData

struct SectionRowView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var section: LauncherSection

    /// Apps to render. HomeView resolves this via SectionSorter so each row
    /// stays cheap and the resolution happens once per refresh.
    let apps: [AppEntry]

    /// Phase 4 wires this up via FocusMonitor; defaults to false in Phase 2.
    var isFocusActive: Bool = false

    var onEdit: () -> Void
    var onAddApps: () -> Void

    @State private var isExpanded = false

    private var isAutoPopulated: Bool {
        section.type == .recentlyUsed || section.type == .frequentlyUsed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(section.emoji)
                .font(.title3)

            Text(section.title)
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if isFocusActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("ACTIVE")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            }

            Spacer()

            Text("\(apps.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())

            Button("Edit", action: onEdit)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var content: some View {
        let visible = isExpanded ? apps : Array(apps.prefix(section.maxVisible))

        if apps.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(visible) { app in
                        AppIconView(
                            app: app,
                            onRemove: isAutoPopulated ? nil : { remove(app) }
                        )
                    }

                    if apps.count > section.maxVisible {
                        Button {
                            withAnimation(.snappy) { isExpanded.toggle() }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: isExpanded ? "chevron.left" : "ellipsis")
                                    .font(.system(size: 22, weight: .semibold))
                                    .frame(width: 56, height: 56)
                                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(isExpanded ? "Less" : "More")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !isAutoPopulated {
                        Button(action: onAddApps) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    )
                                Text("Add")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isAutoPopulated {
            HStack {
                Image(systemName: section.type == .recentlyUsed ? "clock" : "flame")
                Text(section.type == .recentlyUsed
                     ? "Apps you launch via Fore appear here."
                     : "Frequently launched apps appear here over time.")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        } else {
            Button(action: onAddApps) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add apps")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func remove(_ app: AppEntry) {
        app.section = nil
        try? modelContext.save()
    }
}
