//
//  SettingsView.swift
//  Fore
//
//  Per SPEC §13.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LauncherSection.displayOrder) private var sections: [LauncherSection]

    @AppStorage(AppPreferenceKey.iconSize) private var iconSizeRaw: String = AppIconSize.standard.rawValue
    @AppStorage(AppPreferenceKey.defaultSectionTitle) private var defaultSectionTitle: String = ""

    @State private var exportURL: URL? = nil
    @State private var exportError: String? = nil
    @State private var isShowingShareSheet = false

    @State private var confirmResetUsage = false
    @State private var confirmResetSections = false

    private var iconSize: AppIconSize {
        get { AppIconSize(rawValue: iconSizeRaw) ?? .standard }
    }

    var body: some View {
        NavigationStack {
            Form {
                addingSection
                appearanceSection
                hiddenSectionsSection
                widgetSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset usage data?", isPresented: $confirmResetUsage) {
                Button("Reset", role: .destructive) {
                    DataReset.resetUsageData(in: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes every recorded launch. Recently / Frequently Used sections will start empty.")
            }
            .alert("Reset all sections?", isPresented: $confirmResetSections) {
                Button("Reset", role: .destructive) {
                    DataReset.resetAllSections(in: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes every section and every app. The three default sections will be recreated.")
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let exportURL {
                    ActivityView(items: [exportURL])
                }
            }
        }
    }

    // MARK: - Sections

    private var addingSection: some View {
        Section("Adding Apps") {
            Picker("Default section", selection: $defaultSectionTitle) {
                Text("None").tag("")
                ForEach(sections, id: \.title) { section in
                    Text(section.title).tag(section.title)
                }
            }
            Text("Used by future quick-add flows. Standard Add Apps from a section header still adds to that section.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("App icon size", selection: $iconSizeRaw) {
                ForEach(AppIconSize.allCases) { size in
                    Text(size.displayName).tag(size.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var hiddenSectionsSection: some View {
        let hidden = sections.filter { !$0.isEnabled }
        if !hidden.isEmpty {
            Section {
                ForEach(hidden) { section in
                    HStack {
                        Text("\(section.emoji) \(section.title)")
                        Spacer()
                        Button("Enable") {
                            section.isEnabled = true
                            try? modelContext.save()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Hidden Sections")
            } footer: {
                Text("Sections you've disabled in Edit. Tap Enable to bring them back to the home screen.")
            }
        }
    }

    private var widgetSection: some View {
        Section("Widget") {
            VStack(alignment: .leading, spacing: 6) {
                Text("To add a Fore widget:")
                    .font(.subheadline)
                Text("1. Long-press the home screen.\n2. Tap +, search “Fore”.\n3. Pick a size and add.\n4. Long-press the widget → Edit Widget → choose which section to display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                runExport()
            } label: {
                Label("Export usage data (JSON)", systemImage: "square.and.arrow.up")
            }

            if let exportError {
                Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                confirmResetUsage = true
            } label: {
                Label("Reset usage data", systemImage: "clock.arrow.circlepath")
            }

            Button(role: .destructive) {
                confirmResetSections = true
            } label: {
                Label("Reset all sections", systemImage: "rectangle.stack.badge.minus")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
            Link(destination: URL(string: "mailto:shawn@smbrown.org?subject=Fore%20Feedback")!) {
                Label("Send Feedback", systemImage: "envelope")
            }
        }
    }

    // MARK: -

    private func runExport() {
        do {
            let url = try DataExporter.exportUsageEvents(in: modelContext)
            exportURL = url
            exportError = nil
            isShowingShareSheet = true
        } catch {
            exportError = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}

// MARK: - UIActivityViewController bridge

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
