//
//  NewSectionView.swift
//  Fore
//
//  Spec §6.1 calls for a 3-step wizard. Phase 2 ships the same data capture
//  in a single Form for expediency; refactor to a wizard in Phase 8.
//

import SwiftUI
import SwiftData

struct NewSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LauncherSection.displayOrder) private var existingSections: [LauncherSection]

    @State private var title: String = ""
    @State private var emoji: String = "✨"
    @State private var type: SectionType = .manual
    @State private var maxVisible: Int = 8
    @State private var focusName: String = ""

    @State private var startDate: Date = Calendar.current.date(from: DateComponents(hour: 7)) ?? .now
    @State private var endDate: Date = Calendar.current.date(from: DateComponents(hour: 9)) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(SectionType.allCases, id: \.self) { t in
                            Text(label(for: t)).tag(t)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Name") {
                    TextField("Title (e.g. Work, Travel)", text: $title)
                    TextField("Emoji", text: $emoji)
                        .textInputAutocapitalization(.never)
                    Stepper(
                        "Show \(maxVisible) apps before More",
                        value: $maxVisible,
                        in: 1...20
                    )
                }

                if type == .timeBased {
                    Section("Active Window") {
                        DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                        DatePicker("End",   selection: $endDate,   displayedComponents: .hourAndMinute)
                    }
                }

                if type == .focusBased {
                    Section("Focus Mode") {
                        TextField("Focus name (e.g. Work)", text: $focusName)
                    }
                }
            }
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

    private func create() {
        let cal = Calendar.current
        let nextOrder = (existingSections.map(\.displayOrder).max() ?? -1) + 1

        let section = LauncherSection(
            title: title.trimmingCharacters(in: .whitespaces),
            emoji: emoji.isEmpty ? "✨" : emoji,
            type: type,
            displayOrder: nextOrder,
            maxVisible: maxVisible,
            focusName: type == .focusBased ? (focusName.isEmpty ? nil : focusName) : nil,
            timeWindowStart: type == .timeBased ? cal.dateComponents([.hour, .minute], from: startDate) : nil,
            timeWindowEnd:   type == .timeBased ? cal.dateComponents([.hour, .minute], from: endDate)   : nil
        )

        modelContext.insert(section)
        try? modelContext.save()
        dismiss()
    }
}
