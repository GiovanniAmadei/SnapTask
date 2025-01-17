import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsViewModel = SettingsViewModel.shared
    @State private var showingCategoryEditor = false
    
    var body: some View {
        List {
            Button {
                selectedCategory = nil
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedCategory == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(.pink)
                    }
                }
            }
            .foregroundColor(.primary)
            
            ForEach(settingsViewModel.categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 20, height: 20)
                        Text(category.name)
                        Spacer()
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.pink)
                        }
                    }
                }
                .foregroundColor(.primary)
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
    }
} 