import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingCategoryEditor = false
    @State private var editingCategory: Category? = nil
    @State private var showingPremiumPaywall = false
    
    private var canAddMoreCategories: Bool {
        if subscriptionManager.hasAccess(to: .unlimitedCategories) {
            return true
        }
        return settingsViewModel.categories.count < SubscriptionManager.maxCategoriesForFree
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(settingsViewModel.categories) { category in
                        Button(action: {
                            if selectedCategory?.id == category.id {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                            }
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 20, height: 20)
                                Text(category.name)
                                    .themedPrimaryText()
                                Spacer()
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(theme.primaryColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedCategory?.id == category.id ? theme.primaryColor.opacity(0.1) : theme.surfaceColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                selectedCategory?.id == category.id ? theme.primaryColor : theme.borderColor,
                                                lineWidth: selectedCategory?.id == category.id ? 2 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Button {
                        handleAddCategory()
                    } label: {
                        HStack {
                            Label("add_new_category".localized, systemImage: "plus")
                                .foregroundColor(canAddMoreCategories ? theme.primaryColor : theme.secondaryTextColor)
                            
                            Spacer()
                            
                            if !canAddMoreCategories {
                                PremiumBadge(size: .small)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.surfaceColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(theme.borderColor, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("select_category".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("edit".localized) {
                        showingCategoryEditor = true
                    }
                    .themedPrimary()
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
            .sheet(isPresented: $showingPremiumPaywall) {
                PremiumPaywallView()
            }
        }
    }
    
    private func handleAddCategory() {
        if canAddMoreCategories {
            editingCategory = Category(id: UUID(), name: "", color: "#FF0000")
        } else {
            showingPremiumPaywall = true
        }
    }
}