import SwiftUI
import EventKit

struct CalendarIntegrationView: View {
    @StateObject private var integrationManager = CalendarIntegrationManager.shared
    @StateObject private var appleService = AppleCalendarService.shared
    @StateObject private var googleService = GoogleCalendarService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    @State private var showingCalendarPicker = false
    @State private var showingGoogleAuth = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPermissionAlert = false
    @State private var showingSettingsAlert = false
    
    var body: some View {
        Form {
            enabledSection
            
            if integrationManager.settings.isEnabled {
                providerSection
                calendarSelectionSection
                syncOptionsSection
                statusSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.currentTheme.backgroundColor)
        .navigationTitle("calendar_integration".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("error".localized, isPresented: .constant(errorMessage != nil)) {
            Button("ok".localized) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert("enable_calendar_access".localized, isPresented: $showingPermissionAlert) {
            Button("allow".localized) {
                Task {
                    await selectProvider(.apple)
                }
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("calendar_access_message".localized)
        }
        .alert("calendar_access_required".localized, isPresented: $showingSettingsAlert) {
            Button("open_settings".localized) {
                appleService.openCalendarSettings()
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("calendar_access_required_message".localized)
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarSelectionView()
        }
        .onAppear {
            appleService.checkAuthorizationStatus()
            googleService.checkAuthenticationStatus()
        }
    }
    
    private var enabledSection: some View {
        Section {
            Toggle("enable_calendar_integration".localized, isOn: Binding(
                get: { integrationManager.settings.isEnabled },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.isEnabled = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            .tint(themeManager.currentTheme.accentColor)
            .listRowBackground(themeManager.currentTheme.surfaceColor)
        } header: {
            Text("integration".localized)
                .themedPrimaryText()
        } footer: {
            Text("sync_tasks_calendar_automatically".localized)
                .themedSecondaryText()
        }
    }
    
    private var providerSection: some View {
        Section(header: Text("calendar_provider".localized).themedPrimaryText()) {
            ForEach(CalendarProvider.allCases, id: \.self) { provider in
                HStack {
                    Image(systemName: provider.iconName)
                        .foregroundColor(provider == .apple ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.secondaryColor)
                        .frame(width: 20)
                    
                    Text(provider.displayName)
                        .themedPrimaryText()
                    
                    Spacer()
                    
                    if integrationManager.settings.provider == provider {
                        Image(systemName: "checkmark")
                            .themedAccent()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectProvider(provider)
                }
                .listRowBackground(themeManager.currentTheme.surfaceColor)
            }
        }
    }
    
    private var calendarSelectionSection: some View {
        Section(header: Text("calendar_selection".localized).themedPrimaryText()) {
            Button(action: {
                showingCalendarPicker = true
            }) {
                HStack {
                    Text("selected_calendar".localized)
                        .themedPrimaryText()
                    Spacer()
                    Text(integrationManager.settings.selectedCalendarName ?? "none".localized)
                        .themedSecondaryText()
                    Image(systemName: "chevron.right")
                        .themedSecondaryText()
                        .font(.caption)
                }
            }
            .listRowBackground(themeManager.currentTheme.surfaceColor)
        }
    }
    
    private var syncOptionsSection: some View {
        Section(header: Text("sync_options".localized).themedPrimaryText()) {
            Toggle("auto_sync_task_creation".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskCreate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskCreate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            .tint(themeManager.currentTheme.accentColor)
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            Toggle("auto_sync_task_updates".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskUpdate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskUpdate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            .tint(themeManager.currentTheme.accentColor)
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            Toggle("sync_completed_tasks".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskComplete },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskComplete = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            .tint(themeManager.currentTheme.accentColor)
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            Toggle("sync_recurring_tasks".localized, isOn: Binding(
                get: { integrationManager.settings.syncRecurringTasks },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.syncRecurringTasks = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            .tint(themeManager.currentTheme.accentColor)
            .listRowBackground(themeManager.currentTheme.surfaceColor)
        }
    }
    
    private var statusSection: some View {
        Section(header: Text("status".localized).themedPrimaryText()) {
            HStack {
                Text("provider_status".localized)
                    .themedPrimaryText()
                Spacer()
                statusIndicator
            }
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            HStack {
                Text("sync_status".localized)
                    .themedPrimaryText()
                Spacer()
                Text(integrationManager.syncStatus.displayText)
                    .themedSecondaryText()
            }
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            HStack {
                Text("synced_events".localized)
                    .themedPrimaryText()
                Spacer()
                Text("\(integrationManager.getSyncedTasksCount())")
                    .themedSecondaryText()
            }
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            Button("sync_all_tasks_now".localized) {
                syncAllTasks()
            }
            .disabled(isLoading || integrationManager.settings.selectedCalendarId == nil)
            .themedAccent()
            .listRowBackground(themeManager.currentTheme.surfaceColor)
            
            if integrationManager.getSyncedTasksCount() > 0 {
                Button("delete_all_synced_tasks".localized) {
                    deleteAllSyncedTasks()
                }
                .disabled(isLoading)
                .foregroundColor(.red)
                .listRowBackground(themeManager.currentTheme.surfaceColor)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(themeManager.currentTheme.accentColor)
                    Text("syncing".localized)
                        .themedSecondaryText()
                }
                .listRowBackground(themeManager.currentTheme.surfaceColor)
            }
        }
    }
    
    private var statusIndicator: some View {
        Group {
            switch integrationManager.settings.provider {
            case .apple:
                HStack {
                    Circle()
                        .fill(appleService.authorizationStatus == .authorized ? themeManager.currentTheme.accentColor : .red)
                        .frame(width: 8, height: 8)
                    Text(appleService.authorizationStatus == .authorized ? "connected".localized : "not_connected".localized)
                        .themedSecondaryText()
                }
            case .google:
                HStack {
                    Circle()
                        .fill(googleService.isAuthenticated ? themeManager.currentTheme.accentColor : .red)
                        .frame(width: 8, height: 8)
                    Text(googleService.isAuthenticated ? "connected".localized : "not_connected".localized)
                        .themedSecondaryText()
                }
            }
        }
    }
    
    private func selectProvider(_ provider: CalendarProvider) {
        Task {
            isLoading = true
            
            do {
                var settings = integrationManager.settings
                settings.provider = provider
                settings.selectedCalendarId = nil
                settings.selectedCalendarName = nil
                integrationManager.updateSettings(settings)
                
                switch provider {
                case .apple:
                    print("📅 Selected Apple Calendar, current status: \(appleService.authorizationStatus.rawValue)")
                    
                    let granted = await appleService.requestAccess()
                    print("📅 Request result: \(granted), final status: \(appleService.authorizationStatus.rawValue)")
                    
                    if !granted {
                        errorMessage = "calendar_access_denied_message".localized
                    }
                case .google:
                    if !googleService.isAuthenticated {
                        try await googleService.authenticate()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
    
    private func syncAllTasks() {
        Task {
            isLoading = true
            
            let tasks = await MainActor.run {
                TaskManager.shared.tasks
            }
            
            print("📅 Starting sync of \(tasks.count) tasks")
            await integrationManager.syncAllTasksToCalendar(tasks)
            
            isLoading = false
        }
    }
    
    private func deleteAllSyncedTasks() {
        Task {
            isLoading = true
            
            print("📅 Starting deletion of all synced tasks from calendar")
            await integrationManager.deleteAllSyncedTasksFromCalendar()
            
            isLoading = false
        }
    }
}

struct CalendarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var integrationManager = CalendarIntegrationManager.shared
    @StateObject private var appleService = AppleCalendarService.shared
    @StateObject private var googleService = GoogleCalendarService.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                switch integrationManager.settings.provider {
                case .apple:
                    appleCalendarList
                case .google:
                    googleCalendarList
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.currentTheme.backgroundColor)
            .navigationTitle("select_calendar".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .themedAccent()
                }
            }
        }
    }
    
    private var appleCalendarList: some View {
        List {
            ForEach(appleService.availableCalendars, id: \.calendarIdentifier) { calendar in
                HStack {
                    Circle()
                        .fill(Color(cgColor: calendar.cgColor))
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(calendar.title)
                            .font(.body)
                            .themedPrimaryText()
                        Text(calendar.source.title)
                            .font(.caption)
                            .themedSecondaryText()
                    }
                    
                    Spacer()
                    
                    if integrationManager.settings.selectedCalendarId == calendar.calendarIdentifier {
                        Image(systemName: "checkmark")
                            .themedAccent()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectAppleCalendar(calendar)
                }
                .listRowBackground(themeManager.currentTheme.surfaceColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private var googleCalendarList: some View {
        List {
            ForEach(googleService.availableCalendars) { calendar in
                HStack {
                    Circle()
                        .fill(Color(hex: calendar.backgroundColor ?? "#4285F4"))
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(calendar.summary)
                            .font(.body)
                            .themedPrimaryText()
                        if let description = calendar.description {
                            Text(description)
                                .font(.caption)
                                .themedSecondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    if integrationManager.settings.selectedCalendarId == calendar.id {
                        Image(systemName: "checkmark")
                            .themedAccent()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectGoogleCalendar(calendar)
                }
                .listRowBackground(themeManager.currentTheme.surfaceColor)
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.currentTheme.backgroundColor)
    }
    
    private func selectAppleCalendar(_ calendar: EKCalendar) {
        var settings = integrationManager.settings
        settings.selectedCalendarId = calendar.calendarIdentifier
        settings.selectedCalendarName = calendar.title
        integrationManager.updateSettings(settings)
    }
    
    private func selectGoogleCalendar(_ calendar: GoogleCalendar) {
        var settings = integrationManager.settings
        settings.selectedCalendarId = calendar.id
        settings.selectedCalendarName = calendar.summary
        integrationManager.updateSettings(settings)
    }
}

#Preview {
    CalendarIntegrationView()
}