import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @State private var showingCategoryEditor = false
    @State private var editingCategory: Category? = nil
    
    var body: some View {
        List {
            ForEach(settingsViewModel.categories) { category in
                HStack {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 20, height: 20)
                    Text(category.name)
                    Spacer()
                    if selectedCategory?.id == category.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedCategory?.id == category.id {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                    }
                    dismiss()
                }
            }
            
            Button {
                editingCategory = Category(id: UUID(), name: "", color: "#FF0000")
            } label: {
                Label("Add New Category", systemImage: "plus")
                    .foregroundColor(.accentColor)
            }
        }
        .navigationTitle("Select Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingCategoryEditor = true
                }
            }
        }
        .sheet(isPresented: $showingCategoryEditor) {
            NavigationStack {
                CategoryEditorView()
            }
        }
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                CategoryFormView(editingCategory: category) { updatedCategory in
                    if let _ = settingsViewModel.categories.firstIndex(where: { $0.id == updatedCategory.id }) {
                        settingsViewModel.updateCategory(updatedCategory)
                    } else {
                        settingsViewModel.addCategory(updatedCategory)
                        selectedCategory = updatedCategory
                    }
                }
            }
        }
    }
} 