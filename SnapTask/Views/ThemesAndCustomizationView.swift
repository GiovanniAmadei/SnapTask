import SwiftUI

struct ThemesAndCustomizationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.theme) private var theme
    @StateObject private var appIconManager = AppIconManager.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
    
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
                        
                        Text("app_icon".localized)
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
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    
                    Text("category_gradients".localized)
                        .themedPrimaryText()
                    
                    Spacer(minLength: 8)
                    
                    Toggle("", isOn: $viewModel.showCategoryGradients)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
                
                // Coriandoli al completamento
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("confetti_celebrations".localized)
                            .themedPrimaryText()
                        Text("confetti_celebrations_description".localized)
                            .font(.caption)
                            .themedSecondaryText()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Toggle("", isOn: $settingsManager.enableConfettiCelebration)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
                
                // Nascondi barra dei giorni
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("hide_days_bar".localized)
                            .themedPrimaryText()
                        Text("hide_days_bar_description".localized)
                            .font(.caption)
                            .themedSecondaryText()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Toggle("", isOn: $settingsManager.hideDaysBar)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("customization".localized)
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(theme.surfaceColor)

                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("auto_complete_tasks".localized)
                            .themedPrimaryText()
                        Text("auto_complete_tasks_description".localized)
                            .themedSecondaryText()
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Toggle("", isOn: $viewModel.autoCompleteTaskWithSubtasks)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                }
                .listRowBackground(theme.surfaceColor)
                
                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("auto_in_progress".localized)
                            .themedPrimaryText()
                        Text("auto_in_progress_description".localized)
                            .themedSecondaryText()
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 8)
                    
                    Toggle("", isOn: $viewModel.autoMarkInProgress)
                        .labelsHidden()
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

    var body: some View {
        List {
            Section {
                legend
            } footer: {
                Text("eisenhower_settings_intro".localized)
                    .themedSecondaryText()
            }
            .listRowBackground(theme.surfaceColor)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $viewModel.eisenhowerMediumIsImportant) {
                        Label {
                            Text("eisenhower_medium_important_title".localized)
                                .themedPrimaryText()
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: "#EF4444"))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                    Text("eisenhower_medium_important_desc".localized)
                        .font(.caption)
                        .themedSecondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("eisenhower_importance_section".localized)
                    .themedSecondaryText()
            }
            .listRowBackground(theme.surfaceColor)

            Section {
                thresholdRow(
                    title: "today".localized, icon: "sun.max.fill", color: .orange,
                    value: $viewModel.eisenhowerTodayUrgentHours, range: 0...24, step: 1, unit: .hour
                )
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $viewModel.eisenhowerTodayRequireSpecificTime) {
                        Text("eisenhower_today_require_specific_time_title".localized)
                            .themedPrimaryText()
                    }
                    .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                    Text("eisenhower_today_require_specific_time_desc".localized)
                        .font(.caption)
                        .themedSecondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 36)
                thresholdRow(
                    title: "week".localized, icon: "calendar.badge.clock", color: .blue,
                    value: $viewModel.eisenhowerWeekUrgentHours, range: 0...168, step: 6, unit: .hour
                )
                thresholdRow(
                    title: "month".localized, icon: "calendar", color: .green,
                    value: $viewModel.eisenhowerMonthUrgentDays, range: 0...31, step: 1, unit: .day
                )
                thresholdRow(
                    title: "year".localized, icon: "calendar.circle.fill", color: .purple,
                    value: $viewModel.eisenhowerYearUrgentDays, range: 0...60, step: 1, unit: .day
                )
            } header: {
                Text("eisenhower_urgency_section".localized)
                    .themedSecondaryText()
            } footer: {
                Text("eisenhower_threshold_desc".localized)
                    .themedSecondaryText()
            }
            .listRowBackground(theme.surfaceColor)

            Section {
                Button {
                    withAnimation(.smooth(duration: 0.3)) {
                        viewModel.resetEisenhowerUrgencyDefaults()
                    }
                } label: {
                    Label("reset_to_defaults".localized, systemImage: "arrow.counterclockwise")
                        .foregroundColor(theme.accentColor)
                }
            }
            .listRowBackground(theme.surfaceColor)
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("eisenhower_settings_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The four quadrants at a glance, with the axis they come from.
    private var legend: some View {
        let quadrants: [(String, String, String)] = [
            ("eisenhower_do_now", "flame.fill", "#EF4444"),
            ("eisenhower_schedule", "calendar", "#3B82F6"),
            ("eisenhower_delegate", "person.2.fill", "#F59E0B"),
            ("eisenhower_eliminate", "trash.fill", "#8E8E93")
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(quadrants, id: \.0) { key, icon, hex in
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: hex))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color(hex: hex).opacity(0.16)))
                    Text(key.localized)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: hex))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: hex).opacity(0.08))
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func thresholdRow(title: String, icon: String, color: Color, value: Binding<Int>,
                              range: ClosedRange<Int>, step: Int, unit: NSCalendar.Unit) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .themedPrimaryText()
                Text(Self.thresholdDescription(value.wrappedValue, unit: unit))
                    .font(.caption)
                    .themedSecondaryText()
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .fixedSize()
        }
        .animation(.smooth(duration: 0.2), value: value.wrappedValue)
    }

    /// "Urgent from 1 day, 12 hours before the deadline", written in the user's language.
    static func thresholdDescription(_ amount: Int, unit: NSCalendar.Unit) -> String {
        guard amount > 0 else { return "eisenhower_only_overdue".localized }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = unit == .hour ? [.day, .hour] : [.day]
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: LanguageManager.shared.actualLanguageCode)
        formatter.calendar = calendar
        let seconds = TimeInterval(amount) * (unit == .hour ? 3600 : 86400)
        let duration = formatter.string(from: seconds) ?? "\(amount)"
        return String(format: "eisenhower_urgent_within_format".localized, duration)
    }
}

#Preview {
    NavigationStack {
        ThemesAndCustomizationView(viewModel: SettingsViewModel())
    }
}