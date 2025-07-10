import SwiftUI

struct CategoriesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingNewCategorySheet = false
    @State private var editingCategory: Category? = nil
    @State private var showingPremiumPaywall = false
    
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
                    Button(action: { editingCategory = category }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
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