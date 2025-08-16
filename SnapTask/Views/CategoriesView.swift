import SwiftUI

struct CategoriesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingNewCategorySheet = false
    @State private var editingCategory: Category? = nil
    @State private var showingPremiumPaywall = false
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category? = nil
    @State private var showingDeletionWarningAlert = false
    @State private var categoryWithTasks: Category? = nil
    @State private var taskCount = 0
    @State private var showingDeletionBlockedAlert = false
    @State private var deletionBlockedMessage = ""
    
    private var canAddMoreCategories: Bool {
        if subscriptionManager.hasAccess(to: .unlimitedCategories) {
            return true
        }
        return viewModel.categories.count < SubscriptionManager.maxCategoriesForFree
    }
    
    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                HStack {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 12, height: 12)
                    Text(category.name)
                    Spacer()
                    
                    // Edit button
                    Button(action: { editingCategory = category }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Delete button
                    Button(action: { 
                        categoryToDelete = category
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .onDelete { indexSet in
                viewModel.removeCategory(at: indexSet)
            }
            
            // Add Category Button
            addCategoryButton
            
            // Premium limit info
            if !subscriptionManager.hasAccess(to: .unlimitedCategories) {
                limitInfoSection
            }
        }
        .navigationTitle("categories".localized)
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
        }
        .alert("delete_category".localized, isPresented: $showingDeleteAlert) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                if let category = categoryToDelete {
                    viewModel.deleteCategory(category)
                }
                categoryToDelete = nil
            }
        } message: {
            if let category = categoryToDelete {
                Text("delete_category_message".localized + " '\(category.name)'?")
            }
        }
        .alert("warning".localized, isPresented: $showingDeletionWarningAlert) {
            Button("cancel".localized, role: .cancel) { 
                categoryWithTasks = nil
            }
            Button("delete_anyway".localized, role: .destructive) {
                if let category = categoryWithTasks {
                    viewModel.forceDeleteCategory(category)
                }
                categoryWithTasks = nil
            }
        } message: {
            if let category = categoryWithTasks {
                Text("delete_category_with_tasks_warning".localized
                    .replacingOccurrences(of: "%@", with: category.name)
                    .replacingOccurrences(of: "%d", with: "\(taskCount)")
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoryDeletionWarning)) { notification in
            if let userInfo = notification.userInfo,
               let category = userInfo["category"] as? Category,
               let count = userInfo["taskCount"] as? Int {
                categoryWithTasks = category
                taskCount = count
                showingDeletionWarningAlert = true
            }
        }
        .alert("cannot_delete_category".localized, isPresented: $showingDeletionBlockedAlert) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(deletionBlockedMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoryDeletionBlocked)) { notification in
            if let userInfo = notification.userInfo,
               let categoryName = userInfo["categoryName"] as? String,
               let taskCount = userInfo["taskCount"] as? Int {
                deletionBlockedMessage = "category_used_by_tasks_message".localized
                    .replacingOccurrences(of: "%@", with: categoryName)
                    .replacingOccurrences(of: "%d", with: "\(taskCount)")
                showingDeletionBlockedAlert = true
            }
        }
    }
    
    private var addCategoryButton: some View {
        Button(action: handleAddCategory) {
            HStack {
                Label("add_category".localized, systemImage: "plus")
                
                if !canAddMoreCategories {
                    Spacer()
                    PremiumBadge(size: .small)
                }
            }
        }
        .foregroundColor(canAddMoreCategories ? .blue : .gray)
    }
    
    private var limitInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("free_plan_limits".localized)
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                Text("categories_limit_message".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(viewModel.categories.count)/\(SubscriptionManager.maxCategoriesForFree)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("upgrade_to_pro".localized) {
                        showingPremiumPaywall = true
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func handleAddCategory() {
        if canAddMoreCategories {
            showingNewCategorySheet = true
        } else {
            showingPremiumPaywall = true
        }
    }
}