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
    @State private var selected: Set<String> = []                                  // urlSchemes
    @State private var allEntries: [AppDatabaseEntry] = []
    @State private var statusByScheme: [String: AppDatabaseLoader.InstallStatus] = [:]
    @State private var isLoading: Bool = true
    @State private var onlyShowDetected: Bool = true
    @State private var showingCustomSheet: Bool = false

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
                .sheet(isPresented: $showingCustomSheet) {
                    AddCustomAppView { name, scheme, category in
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
                        showingCustomSheet = true
                    } label: {
                        Label("Add Custom App…", systemImage: "plus.app")
                    }
                } footer: {
                    Text(onlyShowDetected
                         ? "iOS only lets us verify ~50 schemes. Apps outside that set are hidden here — use Add Custom App for anything missing."
                         : "Apps marked “Status unknown” can't be verified by iOS. They'll still launch if installed.")
                        .font(.caption2)
                }

                Section {
                    ForEach(filtered, id: \.urlScheme) { entry in
                        AppRowView(
                            entry: entry,
                            status: statusByScheme[entry.urlScheme] ?? .unverified,
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
            if onlyShowDetected && statusByScheme[entry.urlScheme] != .installed { return false }
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
            statusByScheme = Dictionary(
                uniqueKeysWithValues: AppDatabaseLoader.resolveInstalled(entries)
                    .map { ($0.entry.urlScheme, $0.status) }
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
                let optimisticInstalled = statusByScheme[scheme] != .notInstalled
                app = AppEntry(
                    name: dbEntry.name,
                    urlScheme: dbEntry.urlScheme,
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
