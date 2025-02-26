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
                    VStack(alignment: .leading, spacing: 8) {
                        if quoteManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            Text(quoteManager.currentQuote.text)
                                .font(.body)
                                .italic()
                            
                            Text("- \(quoteManager.currentQuote.author)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            Task {
                                await quoteManager.checkAndUpdateQuote()
                            }
                        } label: {
                            Label("New Quote", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
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