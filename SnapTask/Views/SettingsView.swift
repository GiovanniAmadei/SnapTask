import SwiftUI
import StoreKit
import UserNotifications
import MessageUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel.shared
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var donationService = DonationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
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
    @State private var showingPremiumPaywall = false
    @State private var showingThemeWarning = false
    @State private var showingTaskNotificationPermissionAlert = false
    @State private var showingEmailNotAvailableAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                Section {
                    Button {
                        showingPremiumPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: subscriptionManager.isSubscribed ? "crown.fill" : "crown")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subscriptionManager.isSubscribed ? "premium_plan_active".localized : "upgrade_to_pro".localized)
                                    .themedPrimaryText()
                                    .font(.body)
                                
                                if subscriptionManager.isSubscribed {
                                    if let expirationDate = subscriptionManager.subscriptionExpirationDate {
                                        Text(expirationDate == .distantFuture
                                             ? "lifetime_access".localized
                                             : ("subscription_expires".localized + " " + expirationDate.formatted(date: .abbreviated, time: .omitted)))
                                            .font(.caption)
                                            .themedSecondaryText()
                                    }
                                } else {
                                    Text("premium_features".localized)
                                        .font(.caption)
                                        .themedSecondaryText()
                                }
                            }
                            
                            Spacer()
                            
                            // if !subscriptionManager.isSubscribed {
                            //     PremiumBadge(size: .small)
                            // }
                            
                            if subscriptionManager.isSubscribed {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 24, height: 24)
                            } else {
                                PremiumBadge(size: .small)
                            }
                            
                            Image(systemName: "chevron.right")
                                .themedSecondaryText()
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("premium_plan".localized)
                        .themedSecondaryText()
                }
                
                // Quote Section - iOS style
                Section {
                    IOSQuoteCard()
                        .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("quote_of_the_day".localized)
                        .themedSecondaryText()
                }
                
                // Notifications Section
                Section {
                    // Daily Quote Notifications
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("daily_quote_reminder".localized)
                            .themedPrimaryText()
                        
                        Spacer()

                        
                        Toggle("", isOn: $dailyQuoteNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                            .onChange(of: dailyQuoteNotificationsEnabled) { _, newValue in
                                handleNotificationToggle(newValue)
                            }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    if dailyQuoteNotificationsEnabled {
                        Button {
                            showingTimePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                Text("notification_time".localized)
                                    .themedPrimaryText()
                                
                                Spacer()
                                
                                Text(dailyQuoteNotificationTime)
                                    .themedSecondaryText()
                                
                                Image(systemName: "chevron.right")
                                    .themedSecondaryText()
                                    .font(.caption)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .listRowBackground(theme.surfaceColor)
                        
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
                            .listRowBackground(theme.surfaceColor)
                        }
                    }

                    // Task Notifications
                    HStack {
                        Image(systemName: "alarm.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("task_notifications".localized)
                                .themedPrimaryText()
                                .font(.body)
                            Text("task_notifications_description".localized)
                                .font(.caption)
                                .themedSecondaryText()
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $taskNotificationManager.areNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                            .onChange(of: taskNotificationManager.areNotificationsEnabled) { _, newValue in
                                handleTaskNotificationToggle(newValue)
                            }
                    }
                    .listRowBackground(theme.surfaceColor)

                    // Show task notification permission status
                    if taskNotificationManager.authorizationStatus == .denied && taskNotificationManager.areNotificationsEnabled {
                        Button {
                            showingTaskNotificationPermissionAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                Text("notification_permission_denied_message".localized)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .listRowBackground(theme.surfaceColor)
                    }
                } header: {
                    Text("notifications".localized)
                        .themedSecondaryText()
                }
                
                // Appearance Section
                Section {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        Text("dark_mode".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        Toggle("", isOn: $isDarkMode)
                            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                            .onChange(of: isDarkMode) { _, newValue in
                                handleDarkModeToggle(newValue)
                            }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("language".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            Text(languageManager.currentLanguage.name)
                                .themedSecondaryText()
                            
                            Image(systemName: "chevron.right")
                                .themedSecondaryText()
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    NavigationLink {
                        ThemesAndCustomizationView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            Text("themes_and_customization".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                } header: {
                    Text("appearance".localized)
                        .themedSecondaryText()
                }
                
                // Synchronization Section
                Section {
                    NavigationLink(destination: CloudKitSyncSettingsView()) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("icloud_sync".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    NavigationLink(destination: CalendarIntegrationView()) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("calendar_integration".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                } header: {
                    Text("synchronization".localized)
                        .themedSecondaryText()
                } footer: {
                    Text("manage_data_sync".localized)
                        .themedSecondaryText()
                }

                // Community Section
                Section {
                    NavigationLink(destination: FeedbackView()) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("feedback_suggestions".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    NavigationLink(destination: WhatsNewView()) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            Text("whats_cooking".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            // Show badge only if there are unread highlighted updates
                            if UpdateNewsService.shared.hasUnreadHighlightedItems() {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("community".localized)
                        .themedSecondaryText()
                }

                // Support Section
                Section {
                    Button {
                        openEmailClient()
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("contact_support".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .themedSecondaryText()
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                    
                    Button {
                        showingWelcome = true
                    } label: {
                        HStack {
                            Image(systemName: "heart")
                                .foregroundColor(.pink)
                                .frame(width: 24)
                            
                            Text("review_welcome_message".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .themedSecondaryText()
                                .font(.caption)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("terms_of_service".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            // Image(systemName: "chevron.right")
                            //     .themedSecondaryText()
                            //     .font(.caption)
                            //     .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            
                            Text("privacy_policy".localized)
                                .themedPrimaryText()
                            
                            Spacer()
                            
                            // Image(systemName: "chevron.right")
                            //     .themedSecondaryText()
                            //     .font(.caption)
                            //     .frame(width: 12, height: 12)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("support".localized)
                        .themedSecondaryText()
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
                                    .themedSecondaryText()
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
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("data_management".localized)
                        .themedSecondaryText()
                } footer: {
                    Text("delete_all_data_footer".localized)
                        .font(.caption)
                        .themedSecondaryText()
                }
            }
            .themedBackground()
            .scrollContentBackground(.hidden)
            .onAppear {
                Task {
                    await quoteManager.checkAndUpdateQuote()
                    await subscriptionManager.loadProducts()
                }
                loadNotificationTime()
                checkNotificationPermissionStatus()
                taskNotificationManager.checkAuthorizationStatus()
            }
            .actionSheet(isPresented: $showingLanguagePicker) {
                ActionSheet(
                    title: Text("language".localized),
                    message: Text("choose_language".localized),
                    buttons: languageManager.localizedLanguages.map { language in
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

            .sheet(isPresented: $showingPremiumPaywall) {
                Group {
                    if subscriptionManager.isSubscribed {
                        PremiumStatusView()
                    } else {
                        PremiumPaywallView()
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("enable_notifications".localized, isPresented: $showingPermissionAlert) {
                Button("settings".localized) {
                    openAppSettings()
                }
                Button("cancel".localized, role: .cancel) { }
            } message: {
                Text("notification_permission_message".localized)
            }
            .alert("notification_permission_required".localized, isPresented: $showingTaskNotificationPermissionAlert) {
                Button("open_settings".localized) {
                    openAppSettings()
                }
                Button("cancel".localized, role: .cancel) { }
            } message: {
                Text("notification_permission_denied_message".localized)
            }
            .alert("email_client_not_available".localized, isPresented: $showingEmailNotAvailableAlert) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text("email_client_not_available_message".localized)
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
            .alert("dark_mode_theme_warning_title".localized, isPresented: $showingThemeWarning) {
                Button("switch_to_simple_theme".localized) {
                    // Switch to default theme and enable dark mode
                    themeManager.setTheme(ThemeManager.defaultTheme)
                    isDarkMode = true
                }
                Button("keep_current_theme".localized, role: .cancel) {
                    // Keep current theme and disable dark mode
                    isDarkMode = false
                }
            } message: {
                Text("dark_mode_theme_warning_message".localized)
            }
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView()
            }
            .navigationBarTitle("settings".localized)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(false)
        }
    }
    
    private var settingsRowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderColor.opacity(0.3), lineWidth: 0.5)
            )
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
    
    private func handleDarkModeToggle(_ newValue: Bool) {
        // Se l'utente sta provando ad attivare la modalità scura con un tema che sovrascrive i colori
        if newValue && themeManager.currentTheme.overridesSystemColors {
            showingThemeWarning = true
        }
    }
    
    private func handleTaskNotificationToggle(_ newValue: Bool) {
        if newValue && taskNotificationManager.authorizationStatus != .authorized {
            Task {
                let granted = await taskNotificationManager.requestNotificationPermission()
                if !granted {
                    showingTaskNotificationPermissionAlert = true
                }
            }
        } else if !newValue {
            taskNotificationManager.toggleNotifications()
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
                print(" Daily quote notification scheduled for \(self.dailyQuoteNotificationTime)")
            }
        }
    }
    
    private func cancelDailyQuoteNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyQuote"])
        print(" Daily quote notification cancelled")
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
                await taskManager.removeTask(task)
            }
            
            // Clear any remaining data
            taskManager.resetUserDefaults()
            
            // Reset rewards and points
            let rewardManager = RewardManager.shared
            await rewardManager.performCompleteReset()
            
            // Reset categories to defaults
            let categoryManager = CategoryManager.shared
            categoryManager.performCompleteReset()
            
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
    
    private func openEmailClient() {
        let email = "giovannisebastianoamadei@gmail.com"
        let subject = "SnapTask - " + "contact_support".localized
        let body = ""
        
        // Create mailto URL
        let mailtoString = "mailto:\(email)?subject=\(subject)&body=\(body)"
        
        // Encode the string for URL
        guard let mailtoURL = URL(string: mailtoString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            showingEmailNotAvailableAlert = true
            return
        }
        
        // Check if device can open mail
        if UIApplication.shared.canOpenURL(mailtoURL) {
            UIApplication.shared.open(mailtoURL)
        } else {
            showingEmailNotAvailableAlert = true
        }
    }
}

struct IOSQuoteCard: View {
    @StateObject private var quoteManager = QuoteManager.shared
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if quoteManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("loading_inspiration".localized)
                        .font(.subheadline)
                        .themedSecondaryText()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(quoteManager.currentQuote.text)
                        .font(.body)
                        .italic()
                        .themedPrimaryText()
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text("— \(quoteManager.currentQuote.author)")
                            .font(.caption)
                            .themedSecondaryText()
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await quoteManager.forceUpdateQuote()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .themedPrimary()
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
    @Environment(\.theme) private var theme
    
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
            .themedBackground()
            .navigationTitle("notification_time".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                    .themedSecondaryText()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        onSave()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .themedPrimary()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}