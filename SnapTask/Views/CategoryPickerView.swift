import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
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
                handleAddCategory()
            } label: {
                HStack {
                    Label("add_new_category".localized, systemImage: "plus")
                        .foregroundColor(canAddMoreCategories ? .accentColor : .gray)
                    
                    Spacer()
                    
                    if !canAddMoreCategories {
                        PremiumBadge(size: .small)
                    }
                }
            }
            .disabled(!canAddMoreCategories)
        }
        .navigationTitle("select_category".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("edit".localized) {
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
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
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