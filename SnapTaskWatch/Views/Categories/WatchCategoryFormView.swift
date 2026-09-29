import SwiftUI

struct WatchCategoryFormView: View {
    enum Mode {
        case create
        case edit(Category)
    }

    let mode: Mode
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: String = WatchCategoryPalette.defaultColor

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit Category" : "New Category"
    }

    init(mode: Mode) {
        self.mode = mode
        if case .edit(let category) = mode {
            _name = State(initialValue: category.name)
            _selectedColor = State(initialValue: category.color)
        }
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                NavigationLink {
                    WatchCategoryColorPickerView(selectedColor: $selectedColor)
                } label: {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(Color(hex: selectedColor))
                            .frame(width: 12, height: 12)
                    }
                }
            }

            Section {
                Button(isEditing ? "Save Changes" : "Create Category") {
                    saveCategory()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(title)
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        switch mode {
        case .create:
            let category = Category(id: UUID(), name: trimmedName, color: selectedColor)
            syncManager.createCategory(category)
        case .edit(let existing):
            let updated = Category(id: existing.id, name: trimmedName, color: selectedColor)
            syncManager.updateCategory(updated)
        }

        dismiss()
    }
}

private enum WatchCategoryPalette {
    static let defaultColor = "4F46E5"
    static let colors: [String] = [
        "4F46E5", "7C3AED", "DB2777", "EF4444",
        "F97316", "EAB308", "22C55E", "14B8A6",
        "0EA5E9", "6366F1", "8B5CF6", "6B7280"
    ]
}

private struct WatchCategoryColorPickerView: View {
    @Binding var selectedColor: String

    var body: some View {
        List {
            ForEach(Array(WatchCategoryPalette.colors.enumerated()), id: \.offset) { _, color in
                Button {
                    selectedColor = color
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 14, height: 14)
                        Text(color.uppercased())
                        Spacer()
                        if selectedColor == color {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Color")
    }
}

#Preview {
    NavigationStack {
        WatchCategoryFormView(mode: .create)
            .environmentObject(WatchSyncManager.shared)
    }
}
