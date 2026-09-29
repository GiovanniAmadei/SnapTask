import SwiftUI

struct WatchCategoriesListView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var deletingCategory: Category?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                Button {
                    showingAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }

            Section("Your Categories") {
                if syncManager.categories.isEmpty {
                    Text("No categories yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(syncManager.categories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .lineLimit(1)
                                    Text(category.color.uppercased())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                deletingCategory = category
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                WatchCategoryFormView(mode: .create)
            }
        }
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                WatchCategoryFormView(mode: .edit(category))
            }
        }
        .confirmationDialog(
            "Delete Category?",
            isPresented: $showingDeleteConfirmation,
            presenting: deletingCategory
        ) { category in
            Button("Delete", role: .destructive) {
                syncManager.deleteCategory(category)
                deletingCategory = nil
            }
            Button("Cancel", role: .cancel) {
                deletingCategory = nil
            }
        } message: { category in
            Text("Delete \(category.name)? Tasks using it will keep the category removed.")
        }
    }
}

#Preview {
    NavigationStack {
        WatchCategoriesListView()
            .environmentObject(WatchSyncManager.shared)
    }
}
