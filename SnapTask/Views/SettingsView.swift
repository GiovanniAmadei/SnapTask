import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var donationService = DonationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("dailyQuoteNotificationsEnabled") private var dailyQuoteNotificationsEnabled = false
    @AppStorage("dailyQuoteNotificationTime") private var dailyQuoteNotificationTime = "09:00"
    @State private var showingLanguagePicker = false
    @State private var showingDonationSheet = false
    @State private var showingTimePicker = false
    @State private var selectedNotificationTime = Date()
    @State private var notificationPermissionStatus = UNAuthorizationStatus.notDetermined
    @State private var showingPermissionAlert = false
    @State private var showingCalendarIntegrationView = false
    @State private var showingWelcome = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                // Header integrato nella List
                Section {
                    EmptyView()
                } header: {
                    HStack {
                        Text("settings".localized)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets())
                    .textCase(nil)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                
                // Quote Section - iOS style
                Section("quote_of_the_day".localized) {
                    IOSQuoteCard()
                }
                
                // Daily Quote Notifications Section
                Section("daily_notifications".localized) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("daily_quote_reminder".localized)
                        
                        Spacer()
                        
                        Toggle("", isOn: $dailyQuoteNotificationsEnabled)
                            .onChange(of: dailyQuoteNotificationsEnabled) { _, newValue in
                                handleNotificationToggle(newValue)
                            }
                    }
                    
                    if dailyQuoteNotificationsEnabled {
                        Button {
                            showingTimePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("notification_time".localized)
                                
                                Spacer()
                                
                                Text(dailyQuoteNotificationTime)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        // Show notification permission status
                        if notificationPermissionStatus == .denied {
                            Button {
                                showingPermissionAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    
                                    Text("enable_in_settings".localized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                // Appearance Section
                Section("appearance".localized) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        Text("dark_mode".localized)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isDarkMode)
                    }
                    
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("language".localized)
                            
                            Spacer()
                            
                            Text(languageManager.currentLanguage.name)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // Customization Section
                Section("customization".localized) {
                    NavigationLink {
                        CustomizationView(viewModel: viewModel)
                    } label: {
                        Label("customization".localized, systemImage: "paintbrush")
                            .foregroundColor(.purple)
                    }
                }
                
                // Synchronization Section
                Section {
                    NavigationLink(destination: CloudKitSyncSettingsView()) {
                        Label("icloud_sync".localized, systemImage: "icloud")
                    }
                    
                    Button {
                        showingCalendarIntegrationView = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("calendar_integration".localized)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .foregroundColor(.primary)
                    
                } header: {
                    Text("synchronization".localized)
                } footer: {
                    Text("manage_data_sync".localized)
                }
                
                // Community Section
                Section("community".localized) {
                    NavigationLink(destination: FeedbackView()) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("feedback_suggestions".localized)
                        }
                    }
                    
                    NavigationLink(destination: WhatsNewView()) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            Text("whats_cooking".localized)
                            
                            Spacer()
                            
                            // Show badge only if there are unread highlighted updates
                            if UpdateNewsService.shared.hasUnreadHighlightedItems() {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                
                // Support Section
                Section("support".localized) {
                    Button {
                        showingDonationSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .frame(width: 24)
                            
                            Text("support_snaptask".localized)
                            
                            Spacer()
                            
                            if donationService.hasEverDonated {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingWelcome = true
                    } label: {
                        Label("review_welcome_message".localized, systemImage: "heart")
                            .foregroundColor(.pink)
                    }
                }
                
                // Data Management Section
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("delete_all_data".localized)
                                    .foregroundColor(.red)
                                    .font(.body)
                                
                                Text("delete_all_data_description".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("data_management".localized)
                } footer: {
                    Text("delete_all_data_footer".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                    await donationService.loadProducts()
                }
                loadNotificationTime()
                checkNotificationPermissionStatus()
            }
            .actionSheet(isPresented: $showingLanguagePicker) {
                ActionSheet(
                    title: Text("language".localized),
                    message: Text("choose_language".localized),
                    buttons: languageManager.availableLanguages.map { language in
                        .default(Text(language.name)) {
                            languageManager.setLanguage(language.code)
                        }
                    } + [.cancel(Text("cancel".localized))]
                )
            }
            .sheet(isPresented: $showingDonationSheet) {
                DonationView()
            }
            .sheet(isPresented: $showingTimePicker) {
                TimePickerView(
                    selectedTime: $selectedNotificationTime,
                    isPresented: $showingTimePicker
                ) {
                    saveNotificationTime()
                    scheduleDailyQuoteNotification()
                }
            }
            .sheet(isPresented: $showingCalendarIntegrationView) {
                CalendarIntegrationView()
            }
            .alert("enable_notifications".localized, isPresented: $showingPermissionAlert) {
                Button("settings".localized) {
                    openAppSettings()
                }
                Button("cancel".localized, role: .cancel) { }
            } message: {
                Text("notification_permission_message".localized)
            }
            .alert("delete_all_data_confirmation_title".localized, isPresented: $showingDeleteConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("delete_all_data_button".localized, role: .destructive) {
                    Task {
                        await deleteAllData()
                    }
                }
            } message: {
                Text("delete_all_data_confirmation_message".localized)
            }
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func handleNotificationToggle(_ newValue: Bool) {
        print(" Toggle notification: \(newValue)")
        if newValue {
            Task {
                await requestNotificationPermission()
            }
        } else {
            cancelDailyQuoteNotification()
        }
    }
    
    @MainActor
    private func requestNotificationPermission() async {
        print(" Requesting notification permission...")
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print(" Notification permission result: \(granted)")
            
            if granted {
                scheduleDailyQuoteNotification()
            } else {
                dailyQuoteNotificationsEnabled = false
                showingPermissionAlert = true
            }
            
            checkNotificationPermissionStatus()
        } catch {
            print(" Notification permission error: \(error)")
            dailyQuoteNotificationsEnabled = false
        }
    }
    
    private func checkNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
                print(" Current notification status: \(settings.authorizationStatus.rawValue)")
                
                // If permissions were denied, disable the toggle
                if settings.authorizationStatus == .denied && self.dailyQuoteNotificationsEnabled {
                    self.dailyQuoteNotificationsEnabled = false
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func scheduleDailyQuoteNotification() {
        // Cancel existing notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyQuote"])
        
        guard dailyQuoteNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "your_daily_motivation".localized
        content.body = quoteManager.getCurrentQuoteText()
        content.sound = .default
        content.badge = 1
        
        // Parse the time from dailyQuoteNotificationTime
        let timeComponents = dailyQuoteNotificationTime.split(separator: ":")
        guard timeComponents.count == 2,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyQuote", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print(" Error scheduling notification: \(error)")
            } else {
                print("  Daily quote notification scheduled for \(self.dailyQuoteNotificationTime)")
            }
        }
    }
    
    private func cancelDailyQuoteNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyQuote"])
        print("  Daily quote notification cancelled")
    }
    
    private func loadNotificationTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        selectedNotificationTime = formatter.date(from: dailyQuoteNotificationTime) ?? Date()
    }
    
    private func saveNotificationTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        dailyQuoteNotificationTime = formatter.string(from: selectedNotificationTime)
    }
    
    private func deleteAllData() async {
        isDeleting = true
        
        do {
            // Wait a bit for UI feedback
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Delete all tasks first (which also clears statistics and rewards)
            let taskManager = TaskManager.shared
            let allTasks = taskManager.tasks
            
            // Remove each task individually to trigger proper cleanup
            for task in allTasks {
                taskManager.removeTask(task)
            }
            
            // Clear any remaining data
            taskManager.resetUserDefaults()
            
            // Reset rewards and points
            let rewardManager = RewardManager.shared
            await rewardManager.performCompleteReset()
            
            // Reset categories to defaults
            let categoryManager = CategoryManager.shared
            await categoryManager.performCompleteReset()
            
            // Clear time tracking statistics
            UserDefaults.standard.removeObject(forKey: "timeTracking")
            UserDefaults.standard.removeObject(forKey: "taskMetadata")
            
            // Clear all focus session data (Timer sessions)
            let userDefaults = UserDefaults.standard
            let allKeys = userDefaults.dictionaryRepresentation().keys
            let timerSessionKeys = allKeys.filter { $0.hasPrefix("timer_session_") }
            for key in timerSessionKeys {
                userDefaults.removeObject(forKey: key)
                print(" Removed timer session: \(key)")
            }
            
            // Clear Pomodoro background state
            userDefaults.removeObject(forKey: "pomodoro_background_timestamp")
            userDefaults.removeObject(forKey: "pomodoro_time_remaining")
            userDefaults.removeObject(forKey: "pomodoro_state")
            userDefaults.removeObject(forKey: "pomodoro_current_session")
            userDefaults.removeObject(forKey: "pomodoro_total_paused_time")
            
            // Stop any active focus sessions
            let timeTrackerViewModel = TimeTrackerViewModel.shared
            let pomodoroViewModel = PomodoroViewModel.shared
            
            // Remove all active timer sessions
            for session in timeTrackerViewModel.activeSessions {
                timeTrackerViewModel.removeSession(id: session.id)
            }
            
            // Stop any active Pomodoro session
            pomodoroViewModel.stop()
            
            // Synchronize UserDefaults
            UserDefaults.standard.synchronize()
            
            // Notify statistics to refresh
            NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
            
            print(" All data successfully deleted and reset to defaults")
            print(" Cleared timer sessions, Pomodoro state, and focus tracking data")
            
        } catch {
            print(" Error during data deletion: \(error)")
        }
        
        isDeleting = false
    }
}

struct IOSQuoteCard: View {
    @StateObject private var quoteManager = QuoteManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if quoteManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("loading_inspiration".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(quoteManager.currentQuote.text)
                        .font(.body)
                        .italic()
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("— \(quoteManager.currentQuote.author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await quoteManager.forceUpdateQuote()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .disabled(quoteManager.isLoading)
                        .opacity(quoteManager.isLoading ? 0.6 : 1.0)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TimePickerView: View {
    @Binding var selectedTime: Date
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "notification_time".localized,
                    selection: $selectedTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("notification_time".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        onSave()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}