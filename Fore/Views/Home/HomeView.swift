//
//  HomeView.swift
//  Fore
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \LauncherSection.displayOrder) private var sections: [LauncherSection]
    @Query private var allApps: [AppEntry]
    @Query(sort: \UsageEvent.launchedAt, order: .reverse) private var usageEvents: [UsageEvent]

    @State private var focusMonitor = FocusMonitor.shared

    @State private var editingSection: LauncherSection? = nil
    @State private var addingAppsTo: LauncherSection? = nil
    @State private var isCreatingSection = false
    @State private var isShowingSettings = false
    @State private var highlightedSectionID: UUID? = nil

    @AppStorage(AppPreferenceKey.didCompleteOnboarding)
    private var didCompleteOnboarding: Bool = false

    private var visibleSections: [LauncherSection] {
        SectionSorter.sortedSections(sections, activeFocus: focusMonitor.currentFocusName)
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleSections.isEmpty {
                    emptyState
                } else {
                    sectionList
                }
            }
            .navigationTitle("Foretap")
            .toolbar { toolbar }
            .sheet(item: $editingSection) { section in
                SectionEditorView(section: section)
            }
            .sheet(item: $addingAppsTo) { section in
                AddAppsView(section: section)
            }
            .sheet(isPresented: $isCreatingSection) {
                NewSectionView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: Binding(
                get: { !didCompleteOnboarding },
                set: { newValue in if !newValue { didCompleteOnboarding = true } }
            )) {
                OnboardingView()
            }
            .task {
                ForeStore.shared.bootstrapDefaultSectionsIfNeeded(in: modelContext)
                FocusBridge.startObserving()
                focusMonitor.reload()
                WidgetPublisher.publish(in: modelContext)
                handlePendingDeepLink()
            }
            .onChange(of: scenePhase) { _, new in
                switch new {
                case .active:
                    UsageTracker.pruneOldEvents(in: modelContext)
                    UsageQueueDrain.drain(in: modelContext)
                    focusMonitor.reload()
                    WidgetPublisher.publish(in: modelContext)
                    handlePendingDeepLink()
                case .background, .inactive:
                    // Refresh the widget snapshot when leaving the app so
                    // any edits the user just made are reflected on the
                    // home screen the next time they look.
                    WidgetPublisher.publish(in: modelContext)
                @unknown default:
                    break
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // Hide EditButton during an active Focus: reordering against a
            // promotion-shuffled list produces confusing results.
            if !visibleSections.isEmpty && focusMonitor.currentFocusName == nil {
                EditButton()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 4) {
                #if DEBUG
                debugFocusMenu
                #endif
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
                Button {
                    isCreatingSection = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Section")
            }
        }
    }

    #if DEBUG
    private var debugFocusMenu: some View {
        Menu {
            Button {
                focusMonitor.update(focusName: nil)
            } label: {
                if focusMonitor.currentFocusName == nil {
                    Label("None", systemImage: "checkmark")
                } else {
                    Text("None")
                }
            }
            Divider()
            ForEach(focusBasedSectionTitles, id: \.self) { title in
                Button {
                    focusMonitor.update(focusName: title)
                } label: {
                    if focusMonitor.currentFocusName == title {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            Image(systemName: focusMonitor.currentFocusName == nil ? "moon" : "moon.fill")
        }
    }

    private var focusBasedSectionTitles: [String] {
        sections
            .filter { $0.type == .focusBased }
            .compactMap { $0.focusName?.isEmpty == false ? $0.focusName : nil }
            .sorted()
    }
    #endif

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No sections yet")
                .font(.headline)
            Button {
                isCreatingSection = true
            } label: {
                Label("Add Section", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var sectionList: some View {
        ScrollViewReader { proxy in
            List {
                #if DEBUG
                Section {
                    debugFocusBanner
                }
                #endif
                ForEach(visibleSections) { section in
                    SectionRowView(
                        section: section,
                        apps: SectionSorter.resolvedApps(
                            for: section,
                            usageEvents: usageEvents,
                            allApps: allApps
                        ),
                        isFocusActive: isFocusActive(for: section),
                        onEdit: { editingSection = section },
                        onAddApps: { addingAppsTo = section }
                    )
                    .id(section.id)
                    .listRowBackground(
                        highlightedSectionID == section.id
                            ? Color.accentColor.opacity(0.15)
                            : nil
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if section.type != .recentlyUsed && section.type != .frequentlyUsed {
                            Button {
                                addingAppsTo = section
                            } label: {
                                Label("Add Apps", systemImage: "plus")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onMove(perform: move)
            }
            .listStyle(.insetGrouped)
            .onChange(of: highlightedSectionID) { _, new in
                guard let id = new else { return }
                withAnimation { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugFocusBanner: some View {
        let stored = SharedDefaults.activeFocusName
        let monitor = focusMonitor.currentFocusName
        let focusSections = sections.filter { $0.type == .focusBased }

        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG · Focus state")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("SharedDefaults: \(stored ?? "(nil)")")
                .font(.caption.monospaced())
            Text("FocusMonitor:   \(monitor ?? "(nil)")")
                .font(.caption.monospaced())
            if focusSections.isEmpty {
                Text("No focus-based sections exist.")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            } else {
                ForEach(focusSections) { s in
                    Text("section[\(s.title)].focusName = \(s.focusName ?? "(nil)")")
                        .font(.caption.monospaced())
                }
            }
            Button("Reload from SharedDefaults") {
                focusMonitor.reload()
            }
            .font(.caption2)
        }
    }
    #endif

    /// Called on scenePhase → .active. If `OpenSectionIntent` (or another
    /// deep-link source) wrote a section title to SharedDefaults, scroll to
    /// the matching section and pulse-highlight it briefly.
    private func handlePendingDeepLink() {
        guard let title = SharedDefaults.pendingOpenSectionTitle,
              let target = sections.first(where: { $0.title == title }) else {
            return
        }
        SharedDefaults.pendingOpenSectionTitle = nil
        highlightedSectionID = target.id

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { highlightedSectionID = nil }
        }
    }

    private func isFocusActive(for section: LauncherSection) -> Bool {
        guard let active = focusMonitor.currentFocusName, !active.isEmpty else { return false }
        return section.type == .focusBased && section.focusName == active
    }

    private func move(from source: IndexSet, to destination: Int) {
        // Reorder is gated to focus == nil (see toolbar). visibleSections in
        // that state is just sections sorted by displayOrder with pinned
        // promoted; pinned stays pinned regardless of new displayOrder, but
        // relative order of the rest reflects the drag.
        var ordered = visibleSections
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, section) in ordered.enumerated() {
            section.displayOrder = index
        }
        try? modelContext.save()
    }
}
