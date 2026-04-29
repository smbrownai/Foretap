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
    @State private var selected: Set<String> = []                              // entry IDs
    @State private var allEntries: [AppDatabaseEntry] = []
    @State private var statusByID: [String: AppDatabaseLoader.InstallStatus] = [:]
    @State private var isLoading: Bool = true
    @State private var customPrefill: AddCustomAppPrefill? = nil

    /// Cap search results so we never render thousands of rows from one
    /// vague query. The picker is for adding a few apps at a time;
    /// anyone who needs more can refine.
    private static let searchResultsCap = 80

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
                .searchable(
                    text: $search,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search 5,500+ apps"
                )
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
                // "Add Custom App" + helper section is always available.
                Section {
                    Button {
                        customPrefill = .blank
                    } label: {
                        Label("Add Custom App…", systemImage: "plus.app")
                    }
                } footer: {
                    Text("Search the App Store catalog above, or add any app by URL scheme.")
                        .font(.caption2)
                }

                if isSearching {
                    searchResultsSection
                } else {
                    detectedSection
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var isSearching: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var detectedSection: some View {
        let detected = detectedEntries
        Section {
            if detected.isEmpty {
                Text("No apps detected — start typing above to search the catalog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detected) { entry in
                    AppRowView(
                        entry: entry,
                        status: .installed,
                        isSelected: selected.contains(entry.id),
                        onToggle: { handleTap(entry) }
                    )
                }
            }
        } header: {
            Text("On this device (\(detected.count))")
        } footer: {
            Text("iOS only lets us verify ~50 schemes, so this list is partial. Search for any other app above.")
                .font(.caption2)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        let results = searchResults
        Section {
            if results.isEmpty {
                Text("No matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { entry in
                    AppRowView(
                        entry: entry,
                        status: statusByID[entry.id] ?? .noScheme,
                        isSelected: selected.contains(entry.id),
                        onToggle: { handleTap(entry) }
                    )
                }
                if results.count == Self.searchResultsCap {
                    Text("Showing first \(Self.searchResultsCap) — refine search for more specific results.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Search results")
        }
    }

    /// Apps where canOpenURL returned true. Always sorted by name; small
    /// list (typically 5–20 items) so we don't bother capping.
    private var detectedEntries: [AppDatabaseEntry] {
        let alreadyInSection = Set(section.apps.compactMap(\.urlScheme))
        return allEntries.filter { entry in
            statusByID[entry.id] == .installed
                && !(entry.urlScheme.map { alreadyInSection.contains($0) } ?? false)
        }
    }

    private var searchResults: [AppDatabaseEntry] {
        let alreadyInSection = Set(section.apps.compactMap(\.urlScheme))
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var hits: [AppDatabaseEntry] = []
        hits.reserveCapacity(Self.searchResultsCap)

        for entry in allEntries {
            if let scheme = entry.urlScheme, alreadyInSection.contains(scheme) { continue }
            if matches(entry: entry, needle: needle) {
                hits.append(entry)
                if hits.count >= Self.searchResultsCap { break }
            }
        }
        return hits
    }

    private func matches(entry: AppDatabaseEntry, needle: String) -> Bool {
        if entry.name.lowercased().contains(needle) { return true }
        if let dev = entry.developer, dev.lowercased().contains(needle) { return true }
        if let genre = entry.primaryGenre, genre.lowercased().contains(needle) { return true }
        return false
    }

    /// Tap behavior: bulk-select if the entry has a known scheme,
    /// otherwise route into Add Custom App pre-filled with what we
    /// know so the user just supplies the missing scheme.
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
