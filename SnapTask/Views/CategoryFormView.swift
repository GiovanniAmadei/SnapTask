import SwiftUI

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: Color
    private let editingCategory: Category?
    var onSave: (Category) -> Void
    
    init(editingCategory: Category? = nil, onSave: @escaping (Category) -> Void) {
        self.editingCategory = editingCategory
        self.onSave = onSave
        _name = State(initialValue: editingCategory?.name ?? "")
        _color = State(initialValue: editingCategory.map { Color(hex: $0.color) } ?? .red)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("category_name".localized, text: $name)
                    .autocapitalization(.words)
            }
            
            Section("color".localized) {
                ColorPicker("select_color".localized, selection: $color)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle(editingCategory == nil ? "new_category".localized : "edit_category".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save".localized) {
                    let category = Category(
                        id: editingCategory?.id ?? UUID(),
                        name: name,
                        color: color.toHex() ?? "#FF0000"
                    )
                    onSave(category)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}