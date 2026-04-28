//
//  AddCustomAppView.swift
//  Fore
//

import SwiftUI

struct AddCustomAppView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (_ name: String, _ urlScheme: String, _ category: AppCategory) -> Void

    @State private var name: String = ""
    @State private var schemeInput: String = ""
    @State private var category: AppCategory = .other

    private var normalizedScheme: String {
        let trimmed = schemeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") { return trimmed }
        return trimmed.hasSuffix(":") ? "\(trimmed)//" : "\(trimmed)://"
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard URL(string: normalizedScheme)?.scheme?.isEmpty == false else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("App") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Category", selection: $category) {
                        ForEach(AppCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section {
                    TextField("URL scheme", text: $schemeInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("URL scheme")
                } footer: {
                    Text("e.g. snapbridge:// or mygearvault://. Find it in the developer's docs. Without a scheme the app can't be launched.")
                }
            }
            .navigationTitle("Add Custom App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            normalizedScheme,
                            category
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
