import SwiftUI

struct CategoriesView: View {
    @Environment(\.theme) private var theme
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
    
    private func taskCount(for category: Category) -> Int {
        TaskManager.shared.tasks.filter { $0.category?.id == category.id }.count
    }
    
    var body: some View {
        List {
            if viewModel.categories.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                        Text("no_categories_yet".localized)
                            .font(.headline)
                            .themedPrimaryText()
                        Text("no_categories_hint".localized)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .themedSecondaryText()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(theme.surfaceColor)
            } else {
                Section {
                    ForEach(viewModel.categories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                CategoryIconTile(icon: category.displayIcon, color: Color(hex: category.color), size: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.body.weight(.medium))
                                        .themedPrimaryText()
                                    let count = taskCount(for: category)
                                    Text((count == 1 ? "category_tasks_count_one" : "category_tasks_count").localized.replacingOccurrences(of: "%d", with: "\(count)"))
                                        .font(.caption)
                                        .themedSecondaryText()
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showingDeleteAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                editingCategory = category
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showingDeleteAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
            
            Section {
                addCategoryButton
            }
            .listRowBackground(theme.surfaceColor)
            
            // Premium limit info
            if !subscriptionManager.hasAccess(to: .unlimitedCategories) {
                limitInfoSection
                    .listRowBackground(theme.surfaceColor)
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
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
                    Task {
                        await viewModel.forceDeleteCategory(category)
                    }
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
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(canAddMoreCategories ? theme.primaryColor : theme.secondaryTextColor)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundColor(canAddMoreCategories ? theme.primaryColor.opacity(0.6) : theme.secondaryTextColor.opacity(0.5))
                    )
                Text("add_category".localized)
                    .font(.body.weight(.medium))
                    .foregroundColor(canAddMoreCategories ? theme.primaryColor : theme.secondaryTextColor)
                
                Spacer()
                
                if !canAddMoreCategories {
                    PremiumBadge(size: .small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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