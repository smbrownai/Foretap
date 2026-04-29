//
//  AddAppsView.swift
//  Fore
//

import SwiftUI
import SwiftData
import UIKit

struct AddAppsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var section: LauncherSection

    @State private var search: String = ""
    @State private var selected: Set<String> = []                              // entry IDs (bundleId)
    @State private var allEntries: [AppDatabaseEntry] = []
    @State private var statusByID: [String: AppDatabaseLoader.InstallStatus] = [:]
    @State private var isLoading: Bool = true
    @State private var onlyShowDetected: Bool = true
    @State private var customPrefill: AddCustomAppPrefill? = nil

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
                .sheet(item: $customPrefill) { prefill in
                    AddCustomAppView(prefill: prefill) { name, scheme, category in
                        addCustom(name: name, scheme: scheme, category: category)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().controlSize(.large)
        } else {
            List {
                Section {
                    Toggle("Only show apps detected on this device", isOn: $onlyShowDetected)
                        .font(.caption)
                    Button {
                        customPrefill = .blank
                    } label: {
                        Label("Add Custom App…", systemImage: "plus.app")
                    }
                } footer: {
                    Text(onlyShowDetected
                         ? "iOS only lets us verify ~50 schemes. Apps outside that set are hidden — toggle off to browse the full list."
                         : "Apps marked “Status unknown” can't be verified by iOS. They'll still launch if installed.")
                        .font(.caption2)
                }

                Section {
                    ForEach(filtered) { entry in
                        AppRowView(
                            entry: entry,
                            status: statusByID[entry.id] ?? .noScheme,
                            isSelected: selected.contains(entry.id),
                            onToggle: { handleTap(entry) }
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var filtered: [AppDatabaseEntry] {
        let alreadyInSection: Set<String> = Set(section.apps.compactMap { app in
            // Match an existing AppEntry to a database entry primarily by
            // urlScheme; that's what we know about the AppEntry. Bundle IDs
            // for already-added apps aren't tracked separately.
            app.urlScheme
        })

        return allEntries.filter { entry in
            if let scheme = entry.urlScheme, alreadyInSection.contains(scheme) { return false }
            if onlyShowDetected && statusByID[entry.id] != .installed { return false }
            if search.isEmpty { return true }

            let needle = search.lowercased()
            if entry.name.lowercased().contains(needle) { return true }
            if let dev = entry.developer, dev.lowercased().contains(needle) { return true }
            if let genre = entry.primaryGenre, genre.lowercased().contains(needle) { return true }
            return false
        }
    }

    /// Tap behavior is dual-mode:
    ///   - If the entry has a known urlScheme, toggle bulk selection.
    ///   - If the scheme is missing, route into Add Custom App pre-filled
    ///     with the entry's name + category so the user can supply a
    ///     scheme without re-typing everything.
    private func handleTap(_ entry: AppDatabaseEntry) {
        if entry.hasScheme {
            if selected.contains(entry.id) {
                selected.remove(entry.id)
            } else {
                selected.insert(entry.id)
            }
        } else {
            customPrefill = AddCustomAppPrefill(name: entry.name, scheme: "", category: entry.category)
        }
    }

    private func load() async {
        do {
            let entries = try AppDatabaseLoader.loadBundledEntries()
            allEntries = entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            statusByID = Dictionary(
                uniqueKeysWithValues: AppDatabaseLoader.resolveInstalled(entries)
                    .map { ($0.entry.id, $0.status) }
            )
        } catch {
            allEntries = []
        }
        isLoading = false
    }

    private func addCustom(name: String, scheme: String, category: AppCategory) {
        let descriptor = FetchDescriptor<AppEntry>(
            predicate: #Predicate { $0.urlScheme == scheme }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first

        let isInstalled = AppDatabaseLoader.optimisticIsInstalled(scheme: scheme)
        let nextIndex = (section.apps.map(\.customSortIndex).max() ?? -1) + 1

        let app: AppEntry
        if let existing {
            existing.name = name
            existing.category = category
            existing.isInstalled = isInstalled
            app = existing
        } else {
            app = AppEntry(
                name: name,
                urlScheme: scheme,
                category: category,
                isInstalled: isInstalled
            )
            modelContext.insert(app)
        }
        app.section = section
        app.customSortIndex = nextIndex

        try? modelContext.save()
    }

    private func commit() {
        guard !selected.isEmpty else { return }

        let entriesByID = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.id, $0) })
        let baseIndex = (section.apps.map(\.customSortIndex).max() ?? -1) + 1

        for (offset, entryID) in selected.enumerated() {
            guard let dbEntry = entriesByID[entryID],
                  let scheme = dbEntry.urlScheme else { continue }

            // Reuse existing AppEntry for this scheme if we have one
            // (e.g. user added the app to a different section previously).
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
                let optimisticInstalled = statusByID[entryID] != .notInstalled
                app = AppEntry(
                    name: dbEntry.name,
                    urlScheme: scheme,
                    category: dbEntry.category,
                    isInstalled: optimisticInstalled
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
