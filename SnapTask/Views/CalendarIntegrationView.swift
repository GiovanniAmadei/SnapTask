import SwiftUI
import EventKit

struct CalendarIntegrationView: View {
    @StateObject private var integrationManager = CalendarIntegrationManager.shared
    @StateObject private var appleService = AppleCalendarService.shared
    @StateObject private var googleService = GoogleCalendarService.shared
    
    @State private var showingCalendarPicker = false
    @State private var showingGoogleAuth = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPermissionAlert = false
    @State private var showingSettingsAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                enabledSection
                
                if integrationManager.settings.isEnabled {
                    providerSection
                    calendarSelectionSection
                    syncOptionsSection
                    statusSection
                }
            }
            .navigationTitle("calendar_integration".localized)
            .navigationBarTitleDisplayMode(.large)
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
        } header: {
            Text("integration".localized)
        } footer: {
            Text("sync_tasks_calendar_automatically".localized)
        }
    }
    
    private var providerSection: some View {
        Section("calendar_provider".localized) {
            ForEach(CalendarProvider.allCases, id: \.self) { provider in
                HStack {
                    Image(systemName: provider.iconName)
                        .foregroundColor(provider == .apple ? .blue : .red)
                        .frame(width: 20)
                    
                    Text(provider.displayName)
                    
                    Spacer()
                    
                    if integrationManager.settings.provider == provider {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectProvider(provider)
                }
            }
        }
    }
    
    private var calendarSelectionSection: some View {
        Section("calendar_selection".localized) {
            Button(action: {
                showingCalendarPicker = true
            }) {
                HStack {
                    Text("selected_calendar".localized)
                    Spacer()
                    Text(integrationManager.settings.selectedCalendarName ?? "none".localized)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    private var syncOptionsSection: some View {
        Section("sync_options".localized) {
            Toggle("auto_sync_task_creation".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskCreate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskCreate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("auto_sync_task_updates".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskUpdate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskUpdate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("sync_completed_tasks".localized, isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskComplete },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskComplete = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("sync_recurring_tasks".localized, isOn: Binding(
                get: { integrationManager.settings.syncRecurringTasks },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.syncRecurringTasks = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
        }
    }
    
    private var statusSection: some View {
        Section("status".localized) {
            HStack {
                Text("provider_status".localized)
                Spacer()
                statusIndicator
            }
            
            HStack {
                Text("sync_status".localized)
                Spacer()
                Text(integrationManager.syncStatus.displayText)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("synced_events".localized)
                Spacer()
                Text("\(integrationManager.getSyncedTasksCount())")
                    .foregroundColor(.secondary)
            }
            
            Button("sync_all_tasks_now".localized) {
                syncAllTasks()
            }
            .disabled(isLoading || integrationManager.settings.selectedCalendarId == nil)
            
            if integrationManager.getSyncedTasksCount() > 0 {
                Button("delete_all_synced_tasks".localized) {
                    deleteAllSyncedTasks()
                }
                .disabled(isLoading)
                .foregroundColor(.red)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("syncing".localized)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var statusIndicator: some View {
        Group {
            switch integrationManager.settings.provider {
            case .apple:
                HStack {
                    Circle()
                        .fill(appleService.authorizationStatus == .authorized ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(appleService.authorizationStatus == .authorized ? "connected".localized : "not_connected".localized)
                        .foregroundColor(.secondary)
                }
            case .google:
                HStack {
                    Circle()
                        .fill(googleService.isAuthenticated ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(googleService.isAuthenticated ? "connected".localized : "not_connected".localized)
                        .foregroundColor(.secondary)
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
            .navigationTitle("select_calendar".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
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
                        Text(calendar.source.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if integrationManager.settings.selectedCalendarId == calendar.calendarIdentifier {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectAppleCalendar(calendar)
                }
            }
        }
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
                        if let description = calendar.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if integrationManager.settings.selectedCalendarId == calendar.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectGoogleCalendar(calendar)
                }
            }
        }
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