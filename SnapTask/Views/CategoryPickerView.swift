import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingCategoryEditor = false
    @State private var showingNewCategory = false
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
                            HStack(spacing: 12) {
                                CategoryIconTile(icon: category.displayIcon, color: Color(hex: category.color), size: 32)
                                Text(category.name)
                                    .font(.body.weight(.medium))
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
            .sheet(isPresented: $showingNewCategory) {
                NavigationStack {
                    CategoryFormView { newCategory in
                        settingsViewModel.addCategory(newCategory)
                        selectedCategory = newCategory
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
            showingNewCategory = true
        } else {
            showingPremiumPaywall = true
        }
    }
}