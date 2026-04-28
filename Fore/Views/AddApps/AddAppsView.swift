//
//  AddAppsView.swift
//  Fore
//

import SwiftUI
import SwiftData

struct AddAppsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var section: LauncherSection

    @State private var search: String = ""
    @State private var selected: Set<String> = []          // urlSchemes
    @State private var allEntries: [AppDatabaseEntry] = []
    @State private var installed: Set<String> = []         // urlSchemes flagged installed
    @State private var isLoading: Bool = true
    @State private var hideUninstalled: Bool = true

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add (\(selected.count))") { commit() }
                            .disabled(selected.isEmpty)
                    }
                }
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().controlSize(.large)
        } else {
            List {
                Section {
                    Toggle("Hide uninstalled", isOn: $hideUninstalled)
                        .font(.caption)
                }

                Section {
                    ForEach(filtered, id: \.urlScheme) { entry in
                        AppRowView(
                            entry: entry,
                            isInstalled: installed.contains(entry.urlScheme),
                            isSelected: selected.contains(entry.urlScheme),
                            onToggle: { toggle(entry) }
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var filtered: [AppDatabaseEntry] {
        let alreadyInSection = Set(section.apps.map(\.urlScheme))

        return allEntries.filter { entry in
            if alreadyInSection.contains(entry.urlScheme) { return false }
            if hideUninstalled && !installed.contains(entry.urlScheme) { return false }
            if search.isEmpty { return true }

            let needle = search.lowercased()
            if entry.name.lowercased().contains(needle) { return true }
            if entry.keywords.contains(where: { $0.lowercased().contains(needle) }) { return true }
            return false
        }
    }

    private func toggle(_ entry: AppDatabaseEntry) {
        if selected.contains(entry.urlScheme) {
            selected.remove(entry.urlScheme)
        } else {
            selected.insert(entry.urlScheme)
        }
    }

    private func load() async {
        do {
            let entries = try AppDatabaseLoader.loadBundledEntries()
            allEntries = entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            installed = Set(
                AppDatabaseLoader.resolveInstalled(entries)
                    .filter { $0.isInstalled }
                    .map { $0.entry.urlScheme }
            )
        } catch {
            allEntries = []
        }
        isLoading = false
    }

    private func commit() {
        guard !selected.isEmpty else { return }

        let entriesByScheme = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.urlScheme, $0) })
        let baseIndex = (section.apps.map(\.customSortIndex).max() ?? -1) + 1

        for (offset, scheme) in selected.enumerated() {
            guard let dbEntry = entriesByScheme[scheme] else { continue }

            // Reuse existing AppEntry for this scheme if we have one (e.g., user
            // added the app to a different section previously). Otherwise create.
            let existing: AppEntry? = {
                let descriptor = FetchDescriptor<AppEntry>(
                    predicate: #Predicate { $0.urlScheme == scheme }
                )
                return try? modelContext.fetch(descriptor).first
            }()

            let app: AppEntry
            if let existing {
                app = existing
            } else {
                app = AppEntry(
                    name: dbEntry.name,
                    urlScheme: dbEntry.urlScheme,
                    category: dbEntry.category,
                    isInstalled: installed.contains(scheme)
                )
                modelContext.insert(app)
            }

            app.section = section
            app.customSortIndex = baseIndex + offset
        }

        try? modelContext.save()
        dismiss()
    }
}
