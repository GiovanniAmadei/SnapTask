import SwiftUI

struct CustomizationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section("Categories") {
                NavigationLink {
                    CategoriesView(viewModel: viewModel)
                } label: {
                    Label("Manage Categories", systemImage: "folder.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Section("Priorities") {
                NavigationLink {
                    PrioritiesView(viewModel: viewModel)
                } label: {
                    Label("Manage Priorities", systemImage: "flag.fill")
                        .foregroundColor(.orange)
                }
            }
            
            Section("Pomodoro") {
                NavigationLink {
                    PomodoroColorsView()
                } label: {
                    Label("Timer Colors", systemImage: "paintbrush.fill")
                        .foregroundColor(.purple)
                }
            }
        }
        .navigationTitle("Customization")
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

#Preview {
    NavigationStack {
        CustomizationView(viewModel: SettingsViewModel())
    }
}
