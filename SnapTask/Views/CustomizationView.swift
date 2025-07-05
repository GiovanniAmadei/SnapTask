import SwiftUI

struct CustomizationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                NavigationLink {
                    CategoriesView(viewModel: viewModel)
                } label: {
                    Label("manage_categories".localized, systemImage: "folder.fill")
                        .foregroundColor(.blue)
                }
                
                Toggle(isOn: $viewModel.showCategoryGradients) {
                    Label("category_gradients".localized, systemImage: "paintpalette.fill")
                        .foregroundColor(.cyan)
                }
            } header: {
                Text("categories".localized)
            } footer: {
                Text("category_gradients_description".localized)
            }
            
            Section("priorities".localized) {
                NavigationLink {
                    PrioritiesView(viewModel: viewModel)
                } label: {
                    Label("manage_priorities".localized, systemImage: "flag.fill")
                        .foregroundColor(.orange)
                }
            }
            
            Section("pomodoro".localized) {
                NavigationLink {
                    PomodoroColorsView()
                } label: {
                    Label("timer_colors".localized, systemImage: "paintbrush.fill")
                        .foregroundColor(.purple)
                }
            }
            
            Section {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("auto_complete_tasks".localized)
                            .font(.body)
                        Text("auto_complete_tasks_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.autoCompleteTaskWithSubtasks)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
            } header: {
                Text("task_completion".localized)
            } footer: {
                Text("auto_complete_tasks_footer".localized)
                    .font(.caption)
            }
        }
        .navigationTitle("customization".localized)
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
                        .frame(width: 20)
                    Text(priority.displayName)
                    Spacer()
                }
            }
            .onDelete { indexSet in
                viewModel.removePriority(at: indexSet)
            }
            
            Button(action: { showingNewPrioritySheet = true }) {
                Label("add_priority".localized, systemImage: "plus")
            }
        }
        .navigationTitle("priorities".localized)
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
            TextField("priority_name".localized, text: $name)
            
            if let priority = Priority(rawValue: name.lowercased()) {
                HStack {
                    Image(systemName: priority.icon)
                        .foregroundColor(Color(hex: priority.color))
                    Text("preview".localized)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("new_priority".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save".localized) {
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