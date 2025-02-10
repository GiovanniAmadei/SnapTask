import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var quoteManager = QuoteManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Quote of the Day") {
                    if quoteManager.isLoading {
                        ProgressView()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(quoteManager.currentQuote.text)
                                .font(.body)
                            
                            Text("- \(quoteManager.currentQuote.author)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Customization") {
                    NavigationLink {
                        CategoriesView(viewModel: viewModel)
                    } label: {
                        Label("Categories", systemImage: "folder.fill")
                    }
                    
                    NavigationLink {
                        PrioritiesView(viewModel: viewModel)
                    } label: {
                        Label("Priorities", systemImage: "flag.fill")
                    }
                }
                
                Section("Performance") {
                    NavigationLink {
                        BiohackingView()
                    } label: {
                        Label("Biohacking", systemImage: "bolt.heart")
                    }
                }
                
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                }
            }
        }
    }
}

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
                Label("Add Category", systemImage: "plus")
            }
        }
        .navigationTitle("Categories")
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

struct PrioritiesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingNewPrioritySheet = false
    
    var body: some View {
        List {
            ForEach(viewModel.priorities, id: \.self) { priority in
                HStack {
                    Image(systemName: priority.icon)
                        .foregroundColor(Color(hex: priority.color))
                    Text(priority.rawValue.capitalized)
                    Spacer()
                }
            }
            .onDelete { indexSet in
                viewModel.removePriority(at: indexSet)
            }
            
            Button(action: { showingNewPrioritySheet = true }) {
                Label("Add Priority", systemImage: "plus")
            }
        }
        .navigationTitle("Priorities")
        .sheet(isPresented: $showingNewPrioritySheet) {
            NavigationStack {
                PriorityFormView { priority in
                    viewModel.addPriority(priority)
                }
            }
        }
    }
}

struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: Color
    private let editingCategory: Category?
    var onSave: (Category) -> Void
    
    init(editingCategory: Category? = nil, onSave: @escaping (Category) -> Void) {
        self.editingCategory = editingCategory
        self.onSave = onSave
        _name = State(initialValue: editingCategory?.name ?? "")
        _color = State(initialValue: editingCategory.map { Color(hex: $0.color) } ?? .red)
    }
    
    var body: some View {
        Form {
            TextField("Category Name", text: $name)
            ColorPicker("Color", selection: $color)
        }
        .navigationTitle(editingCategory == nil ? "New Category" : "Edit Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let category = Category(
                        id: editingCategory?.id ?? UUID(),
                        name: name,
                        color: color.toHex() ?? "#FF0000"
                    )
                    onSave(category)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

struct PriorityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var onSave: (Priority) -> Void
    
    var body: some View {
        Form {
            TextField("Priority Name", text: $name)
            
            // Preview how the priority will look
            if let priority = Priority(rawValue: name.lowercased()) {
                HStack {
                    Image(systemName: priority.icon)
                        .foregroundColor(Color(hex: priority.color))
                    Text("Preview")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("New Priority")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let priority = Priority(rawValue: name.lowercased()) {
                        onSave(priority)
                    }
                    dismiss()
                }
                .disabled(Priority(rawValue: name.lowercased()) == nil)
            }
        }
    }
} 