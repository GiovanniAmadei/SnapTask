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
            
            

            
            
            // Behavior Section (includes Eisenhower settings link + Task Completion)
            Section {
                // Eisenhower Matrix link
                NavigationLink {
                    EisenhowerSettingsView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("eisenhower_settings_title".localized)
                                .themedPrimaryText()
                            Text("eisenhower_threshold_desc".localized)
                                .font(.caption)
                                .themedSecondaryText()
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)

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
                Text("app_behavior".localized)
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
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("new_priority".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EisenhowerSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.theme) private var theme

    private let todayHours = Array(0...24)
    private let weekHours = Array(0...168)
    private let monthDays = Array(0...31)
    private let yearDays = Array(0...60)

    var body: some View {
        List {
            Section {
                HStack(alignment: .top) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("eisenhower_today_require_specific_time_title".localized)
                                .themedPrimaryText()
                            Spacer()
                            Toggle("", isOn: $viewModel.eisenhowerTodayRequireSpecificTime)
                                .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                        }
                        Text("eisenhower_today_require_specific_time_desc".localized)
                            .font(.caption)
                            .themedSecondaryText()
                    }
                }
            }
            .listRowBackground(theme.surfaceColor)

            Section {
                // Today (hours)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        Text("eisenhower_today_urgent_hours_title".localized)
                            .themedPrimaryText()
                    }
                    Spacer()
                    Picker("", selection: $viewModel.eisenhowerTodayUrgentHours) {
                        ForEach(todayHours, id: \.self) { h in
                            Text("\(h)h").tag(h)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 90, height: 100)
                    .clipped()
                }
                .listRowBackground(theme.surfaceColor)

                // Week (hours)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("eisenhower_week_urgent_hours_title".localized)
                            .themedPrimaryText()
                    }
                    Spacer()
                    Picker("", selection: $viewModel.eisenhowerWeekUrgentHours) {
                        ForEach(weekHours, id: \.self) { h in
                            Text("\(h)h").tag(h)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 90, height: 100)
                    .clipped()
                }
                .listRowBackground(theme.surfaceColor)

                // Month (days)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("eisenhower_month_urgent_days_title".localized)
                            .themedPrimaryText()
                    }
                    Spacer()
                    Picker("", selection: $viewModel.eisenhowerMonthUrgentDays) {
                        ForEach(monthDays, id: \.self) { d in
                            Text("\(d)d").tag(d)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 90, height: 100)
                    .clipped()
                }
                .listRowBackground(theme.surfaceColor)

                // Year (days)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("eisenhower_year_urgent_days_title".localized)
                            .themedPrimaryText()
                    }
                    Spacer()
                    Picker("", selection: $viewModel.eisenhowerYearUrgentDays) {
                        ForEach(yearDays, id: \.self) { d in
                            Text("\(d)d").tag(d)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 90, height: 100)
                    .clipped()
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("eisenhower_settings_title".localized)
                    .themedSecondaryText()
            }

            Section {
                Button {
                    viewModel.resetEisenhowerUrgencyDefaults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(theme.accentColor)
                            .frame(width: 24)
                        Text("reset_to_defaults".localized)
                            .themedPrimary()
                        Spacer()
                    }
                }
            } footer: {
                Text("eisenhower_threshold_desc".localized)
                    .themedSecondaryText()
            }
            .listRowBackground(theme.surfaceColor)
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("eisenhower_settings_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemesAndCustomizationView(viewModel: SettingsViewModel())
    }
}