import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @State private var showingColorPicker = false
    @State private var editingCategory: Category?
    @State private var newCategoryName = ""
    @State private var selectedColor = "#FF69B4" // Default pink color
    
    private let presetColors: [[Color]] = [
        [.red, .orange, .yellow, .green],
        [.mint, .teal, .cyan, .blue],
        [.indigo, .purple, .pink, .brown],
        [.gray, .black, .white, .clear]
    ]
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New Category", text: $newCategoryName)
                    Button("Add") {
                        if !newCategoryName.isEmpty {
                            let category = Category(
                                id: UUID(),
                                name: newCategoryName,
                                color: selectedColor
                            )
                            settingsViewModel.addCategory(category)
                            newCategoryName = ""
                        }
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
            
            Section("Color") {
                ColorPickerGrid(selectedColor: $selectedColor)
            }
            
            Section {
                ForEach(settingsViewModel.categories) { category in
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: category.color))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                        Text(category.name)
                            .padding(.leading, 8)
                        Spacer()
                        Button {
                            editingCategory = category
                            selectedColor = category.color
                            showingColorPicker = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    settingsViewModel.removeCategory(at: indexSet)
                }
            }
        }
        .navigationTitle("Edit Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            NavigationStack {
                ColorPickerView(selectedColor: $selectedColor) { color in
                    if let category = editingCategory {
                        var updatedCategory = category
                        updatedCategory.color = color
                        settingsViewModel.updateCategory(updatedCategory)
                        editingCategory = nil
                    }
                    selectedColor = color
                    showingColorPicker = false
                }
            }
            .presentationDetents([.medium])
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
        .navigationTitle("Select Color")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    } 
    } 
