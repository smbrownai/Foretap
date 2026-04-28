//
//  SectionEditorView.swift
//  Fore
//

import SwiftUI
import SwiftData

struct SectionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var section: LauncherSection

    @State private var showDeleteConfirm = false
    @State private var isAddingApps = false

    private var allowsManualApps: Bool {
        section.type != .recentlyUsed && section.type != .frequentlyUsed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section") {
                    TextField("Title", text: $section.title)
                    TextField("Emoji", text: $section.emoji)
                        .textInputAutocapitalization(.never)

                    Picker("Type", selection: $section.type) {
                        ForEach(SectionType.allCases, id: \.self) { type in
                            Text(label(for: type)).tag(type)
                        }
                    }

                    Stepper(
                        "Show \(section.maxVisible) apps before More",
                        value: $section.maxVisible,
                        in: 1...20
                    )

                    Toggle("Enabled", isOn: $section.isEnabled)
                }

                if section.type == .timeBased {
                    Section("Active Window") {
                        timeWindowEditor
                    }
                }

                if section.type == .focusBased {
                    Section("Focus Mode") {
                        TextField(
                            "Focus name (e.g. Work)",
                            text: Binding(
                                get: { section.focusName ?? "" },
                                set: { section.focusName = $0.isEmpty ? nil : $0 }
                            )
                        )
                    }
                }

                if allowsManualApps {
                    Section("Apps") {
                        Button {
                            isAddingApps = true
                        } label: {
                            Label("Add Apps", systemImage: "plus")
                        }
                        Text("\(section.apps.count) in this section")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Delete Section", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Button("Simulate launch (1× each app)") {
                        simulateLaunches(perApp: 1)
                    }
                    Button("Simulate launch (10× each app)") {
                        simulateLaunches(perApp: 10)
                    }
                    .disabled(section.apps.isEmpty)
                }
                #endif
            }
            .navigationTitle("Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .alert("Delete \(section.title)?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteSection() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Apps in this section won't be deleted; they'll just be unassigned.")
            }
            .sheet(isPresented: $isAddingApps) {
                AddAppsView(section: section)
            }
        }
    }

    @ViewBuilder
    private var timeWindowEditor: some View {
        let cal = Calendar.current
        let startBinding = Binding<Date>(
            get: {
                cal.date(from: section.timeWindowStart ?? DateComponents(hour: 7, minute: 0)) ?? Date()
            },
            set: {
                section.timeWindowStart = cal.dateComponents([.hour, .minute], from: $0)
            }
        )
        let endBinding = Binding<Date>(
            get: {
                cal.date(from: section.timeWindowEnd ?? DateComponents(hour: 9, minute: 0)) ?? Date()
            },
            set: {
                section.timeWindowEnd = cal.dateComponents([.hour, .minute], from: $0)
            }
        )

        DatePicker("Start", selection: startBinding, displayedComponents: .hourAndMinute)
        DatePicker("End", selection: endBinding, displayedComponents: .hourAndMinute)
    }

    private func label(for type: SectionType) -> String {
        switch type {
        case .pinned:          return "Pinned"
        case .recentlyUsed:    return "Recently Used"
        case .frequentlyUsed:  return "Frequently Used"
        case .timeBased:       return "Time-Based"
        case .focusBased:      return "Focus-Based"
        case .manual:          return "Manual"
        }
    }

    private func deleteSection() {
        modelContext.delete(section)
        try? modelContext.save()
        dismiss()
    }

    #if DEBUG
    /// Inserts synthetic UsageEvents for every app in the section without
    /// hitting `UIApplication.open`. Lets us verify Recently/Frequently Used
    /// populate when target apps aren't actually installed on the simulator.
    private func simulateLaunches(perApp: Int) {
        guard !section.apps.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()

        for app in section.apps {
            for i in 0..<perApp {
                // Spread synthetic events across the last 24 hours so the
                // recency-weighted score has something to chew on.
                let offset = TimeInterval(-i * 60 * 30)        // 30 min apart
                let stamp = now.addingTimeInterval(offset)

                let event = UsageEvent(
                    appScheme: app.urlScheme,
                    launchedAt: stamp,
                    activeFocusName: nil,
                    hourOfDay: cal.component(.hour, from: stamp),
                    dayOfWeek: cal.component(.weekday, from: stamp)
                )
                modelContext.insert(event)
            }
            app.launchCount += perApp
            app.lastLaunched = now
        }

        try? modelContext.save()
    }
    #endif
}
