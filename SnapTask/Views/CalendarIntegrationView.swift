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
            .navigationTitle("Calendar Integration")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("Enable Calendar Access", isPresented: $showingPermissionAlert) {
                Button("Allow") {
                    Task {
                        await selectProvider(.apple)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("SnapTask needs access to your calendar to sync your tasks and create calendar events automatically.")
            }
            .alert("Calendar Access Required", isPresented: $showingSettingsAlert) {
                Button("Open Settings") {
                    appleService.openCalendarSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Calendar access is required to sync your tasks. Please enable calendar access for SnapTask in Settings.")
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
            Toggle("Enable Calendar Integration", isOn: Binding(
                get: { integrationManager.settings.isEnabled },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.isEnabled = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
        } header: {
            Text("Integration")
        } footer: {
            Text("Sync your tasks with your calendar app automatically")
        }
    }
    
    private var providerSection: some View {
        Section("Calendar Provider") {
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
        Section("Calendar Selection") {
            Button(action: {
                showingCalendarPicker = true
            }) {
                HStack {
                    Text("Selected Calendar")
                    Spacer()
                    Text(integrationManager.settings.selectedCalendarName ?? "None")
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
        Section("Sync Options") {
            Toggle("Auto-sync on task creation", isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskCreate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskCreate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("Auto-sync on task updates", isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskUpdate },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskUpdate = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("Sync completed tasks", isOn: Binding(
                get: { integrationManager.settings.autoSyncOnTaskComplete },
                set: { newValue in
                    var settings = integrationManager.settings
                    settings.autoSyncOnTaskComplete = newValue
                    integrationManager.updateSettings(settings)
                }
            ))
            
            Toggle("Sync recurring tasks", isOn: Binding(
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
        Section("Status") {
            HStack {
                Text("Provider Status")
                Spacer()
                statusIndicator
            }
            
            HStack {
                Text("Sync Status")
                Spacer()
                Text(integrationManager.syncStatus.displayText)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Synced Events")
                Spacer()
                Text("\(integrationManager.getSyncedTasksCount())")
                    .foregroundColor(.secondary)
            }
            
            Button("Sync All Tasks Now") {
                syncAllTasks()
            }
            .disabled(isLoading || integrationManager.settings.selectedCalendarId == nil)
            
            if integrationManager.getSyncedTasksCount() > 0 {
                Button("Delete All Synced Tasks") {
                    deleteAllSyncedTasks()
                }
                .disabled(isLoading)
                .foregroundColor(.red)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
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
                    Text(appleService.authorizationStatus == .authorized ? "Connected" : "Not Connected")
                        .foregroundColor(.secondary)
                }
            case .google:
                HStack {
                    Circle()
                        .fill(googleService.isAuthenticated ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(googleService.isAuthenticated ? "Connected" : "Not Connected")
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
                        errorMessage = "Calendar access was denied. Please enable calendar access in iOS Settings > Privacy & Security > Calendars > SnapTask."
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
            .navigationTitle("Select Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
