import SwiftUI

struct WatchCategoriesView: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingAddCategory = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryManager.categories) { category in
                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 12, height: 12)
                        
                        Text(category.name)
                            .font(.system(size: 12))
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            WatchCategoryFormView()
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            let category = categoryManager.categories[index]
            categoryManager.removeCategory(category)
        }
    }
}

struct WatchCategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryManager = CategoryManager.shared
    
    @State private var name = ""
    @State private var selectedColor = "#3B82F6"
    
    private let colors = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#F97316", "#06B6D4", "#84CC16"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Name Field
                TextField("Category name", text: $name)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                    )
                
                // Color Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let category = Category(name: name, color: selectedColor)
                        categoryManager.addCategory(category)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}