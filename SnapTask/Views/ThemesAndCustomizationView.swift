import SwiftUI

struct ThemesAndCustomizationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.theme) private var theme
    @StateObject private var appIconManager = AppIconManager.shared
    
    var body: some View {
        List {
            // Personalizzazione Section (grouped)
            Section {
                // Temi
                NavigationLink {
                    ThemeSelectionView()
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text("themes".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)

                // Icona app (with preview)
                NavigationLink {
                    AppIconSelectionView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "app.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        Text("Icona app")
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        Group {
                            if let img = appIconManager.previewImageForCurrent() {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "square.app.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(theme.primaryColor)
                            }
                        }
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(theme.borderColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .listRowBackground(theme.surfaceColor)

                // Colori timer (Pomodoro)
                NavigationLink(destination: PomodoroColorsView()) {
                    HStack {
                        Image(systemName: "timer.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("timer_colors".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)

                // Gradienti categorie
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    
                    Text("category_gradients".localized)
                        .themedPrimaryText()
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.showCategoryGradients)
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("Personalizzazione")
                    .themedSecondaryText()
            }
            
            // Categories Section (without gradients toggle)
            Section {
                NavigationLink {
                    CategoriesView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("manage_categories".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("categories".localized)
                    .themedSecondaryText()
            }
            
            // Priorities Section
            Section {
                NavigationLink {
                    PrioritiesView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("manage_priorities".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("priorities".localized)
                    .themedSecondaryText()
            } footer: {
                Text("customize_task_priorities".localized)
                    .themedSecondaryText()
            }
            
            

            
            
            // Task Completion Section
            Section {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading) {
                        Text("auto_complete_tasks".localized)
                            .themedPrimaryText()
                        Text("auto_complete_tasks_description".localized)
                            .themedSecondaryText()
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.autoCompleteTaskWithSubtasks)
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("task_completion".localized)
                    .themedSecondaryText()
            } footer: {
                Text("auto_complete_tasks_footer".localized)
                    .themedSecondaryText()
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .onAppear { appIconManager.refresh() }
        .navigationTitle("themes_and_customization".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrioritiesView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingNewPrioritySheet = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        List {
            ForEach(viewModel.priorities, id: \.self) { priority in
                HStack {
                    Image(systemName: priority.icon)
                        .foregroundColor(Color(hex: priority.color))
                        .frame(width: 24)
                    
                    Text(priority.displayName)
                        .themedPrimaryText()
                    
                    Spacer()
                }
                .listRowBackground(theme.surfaceColor)
            }
            .onDelete { indexSet in
                viewModel.removePriority(at: indexSet)
            }
            
            Button(action: { showingNewPrioritySheet = true }) {
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(theme.accentColor)
                        .frame(width: 24)
                    
                    Text("add_priority".localized)
                        .themedPrimary()
                    
                    Spacer()
                }
            }
            .listRowBackground(theme.surfaceColor)
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("priorities".localized)
        .navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.theme) private var theme
    @State private var name = ""
    var onSave: (Priority) -> Void
    
    var body: some View {
        Form {
            Section {
                TextField("priority_name".localized, text: $name)
                    .themedPrimaryText()
            } header: {
                Text("priority_details".localized)
                    .themedSecondaryText()
            }
            
            if let priority = Priority(rawValue: name.lowercased()) {
                Section {
                    HStack {
                        Image(systemName: priority.icon)
                            .foregroundColor(Color(hex: priority.color))
                            .frame(width: 24)
                        
                        Text(priority.displayName)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        Text("preview".localized)
                            .themedSecondaryText()
                            .font(.caption)
                    }
                } header: {
                    Text("preview".localized)
                        .themedSecondaryText()
                }
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("new_priority".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) { 
                    dismiss() 
                }
                .themedSecondaryText()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("save".localized) {
                    if let priority = Priority(rawValue: name.lowercased()) {
                        onSave(priority)
                    }
                    dismiss()
                }
                .disabled(Priority(rawValue: name.lowercased()) == nil)
                .themedPrimary()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ThemesAndCustomizationView(viewModel: SettingsViewModel())
    }
}