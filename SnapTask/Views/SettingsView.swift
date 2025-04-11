import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingLanguagePicker = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("quote_of_the_day".localized) {
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
                                await quoteManager.forceUpdateQuote()
                            }
                        } label: {
                            Label("new_quote".localized, systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("customization".localized) {
                    NavigationLink {
                        CategoriesView(viewModel: viewModel)
                    } label: {
                        Label("categories".localized, systemImage: "folder.fill")
                    }
                    
                    NavigationLink {
                        PrioritiesView(viewModel: viewModel)
                    } label: {
                        Label("priorities".localized, systemImage: "flag.fill")
                    }
                }
                
                Section("appearance".localized) {
                    Toggle("dark_mode".localized, isOn: $isDarkMode)
                    
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            Label("language".localized, systemImage: "globe")
                            Spacer()
                            Text(languageManager.currentLanguage.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("performance".localized) {
                    NavigationLink {
                        BiohackingView()
                    } label: {
                        Label("biohacking".localized, systemImage: "bolt.heart")
                    }
                }
            }
            .navigationTitle("settings".localized)
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                }
            }
            .actionSheet(isPresented: $showingLanguagePicker) {
                ActionSheet(
                    title: Text("language".localized),
                    message: Text("Choose a language"),
                    buttons: languageManager.availableLanguages.map { language in
                        .default(Text(language.name)) {
                            languageManager.setLanguage(language.code)
                        }
                    } + [.cancel()]
                )
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