import SwiftUI

struct CategoriesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingNewCategorySheet = false
    @State private var editingCategory: Category? = nil
    
    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                HStack {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 12, height: 12)
                    Text(category.name)
                    Spacer()
                    Button(action: { editingCategory = category }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete { indexSet in
                viewModel.removeCategory(at: indexSet)
            }
            
            Button(action: { showingNewCategorySheet = true }) {
                Label("add_category".localized, systemImage: "plus")
            }
        }
        .navigationTitle("categories".localized)
        .sheet(isPresented: $showingNewCategorySheet) {
            NavigationStack {
                CategoryFormView { category in
                    viewModel.addCategory(category)
                }
            }
        }
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