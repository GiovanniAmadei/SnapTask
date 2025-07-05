import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel.shared
    @State private var newCategoryName = ""
    @State private var selectedColor = "#FF0000"
    @State private var showingColorPicker = false
    @State private var editingCategory: Category? = nil
    
    var body: some View {
        List {
            Section("add_new_category".localized) {
                HStack {
                    TextField("category_name".localized, text: $newCategoryName)
                    Button("add".localized) {
                        let newCategory = Category(
                            id: UUID(),
                            name: newCategoryName,
                            color: selectedColor
                        )
                        viewModel.addCategory(newCategory)
                        newCategoryName = ""
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
            
            Section("color".localized) {
                ColorPicker("select_color".localized, selection: Binding(
                    get: { Color(hex: selectedColor) },
                    set: { selectedColor = $0.toHex() ?? "#FF0000" }
                ))
                .padding(.vertical, 8)
            }
            
            Section {
                ForEach(viewModel.categories) { category in
                    HStack {
                        Button {
                            editingCategory = category
                        } label: {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        Text(category.name)
                        Spacer()
                        Button(action: {
                            editingCategory = category
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.removeCategory(at: indexSet)
                }
            }
        }
        .navigationTitle("categories".localized)
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                CategoryFormView(
                    editingCategory: category
                ) { updatedCategory in
                    viewModel.updateCategory(updatedCategory)
                }
            }
        }
    }
}

struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    let onColorSelected: (String) -> Void
    
    private let colors = [
        "#FF69B4", "#FF0000", "#FFA500", "#FFFF00", 
        "#00FF00", "#0000FF", "#800080", "#A52A2A",
        "#808080", "#000000"
    ]
    
    var body: some View {
        List {
            ForEach(colors, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 24, height: 24)
                        Spacer()
                        if color == selectedColor {
                            Image(systemName: "checkmark")
                                .foregroundColor(.pink)
                        }
                    }
                }
            }
        }
        .navigationTitle("select_color".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) {
                    dismiss()
                }
            }
        }
    } 
}