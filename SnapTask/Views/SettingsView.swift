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
    
    var body: some View {
        NavigationStack {
            List {
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
                
                // Behavior Section
                Section("behavior".localized) {
                    NavigationLink(destination: BehaviorSettingsView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            Text("app_behavior".localized)
                            
                            Spacer()
                            
                            // Show current auto-complete status as preview
                            Text(viewModel.autoCompleteTaskWithSubtasks ? "auto_complete_on".localized : "manual".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Sync Section
                Section("sync".localized) {
                    NavigationLink(destination: CloudKitSyncSettingsView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("icloud_sync".localized)
                            
                            Spacer()
                            
                            // Show sync status indicator
                            SyncStatusIndicator()
                        }
                    }
                    
                    Button {
                        showingCalendarIntegrationView = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
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
            }
            .navigationTitle("settings".localized)
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
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView()
            }
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

struct SyncStatusIndicator: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            if cloudKitService.isCloudKitEnabled {
                switch cloudKitService.syncStatus {
                case .syncing:
                    ProgressView()
                        .scaleEffect(0.7)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                case .error:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                default:
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } else {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
        }
    }
}

struct CompactSettingsCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let destination: AnyView
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    iconColor.opacity(0.3),
                                    iconColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Material.ultraThinMaterial)
                    .shadow(
                        color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppearanceCompactCard: View {
    @StateObject private var languageManager = LanguageManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showingLanguagePicker = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.3),
                                Color.indigo.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "paintpalette.fill")
                    .font(.title3)
                    .foregroundColor(.indigo)
            }
            
            Text("appearance".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Toggle("dark_mode".localized, isOn: $isDarkMode)
                    .toggleStyle(SwitchToggleStyle(tint: .indigo))
                    .scaleEffect(0.8)
                
                Button {
                    showingLanguagePicker = true
                } label: {
                    Text(languageManager.currentLanguage.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Material.ultraThinMaterial))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
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
    }
}

struct SyncCompactCard: View {
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "icloud.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            Text("icloud_sync".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            VStack(spacing: 4) {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(cloudKitService.syncStatus.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
    }
    
    private var syncStatusColor: Color {
        switch cloudKitService.syncStatus {
        case .success:
            return .green
        case .syncing:
            return .orange
        case .error(_):
            return .red
        case .idle:
            return .gray
        case .disabled:
            return .secondary
        }
    }
}

struct SupportCard: View {
    @StateObject private var donationService = DonationService.shared
    @State private var showingDonationSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(.pink)
                
                Text("support_snaptask".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("help_continue_improving".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button {
                showingDonationSheet = true
            } label: {
                HStack {
                    Text("support_development".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if donationService.hasEverDonated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(
                        colors: [.pink.opacity(0.15), .purple.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.08),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
        .sheet(isPresented: $showingDonationSheet) {
            DonationView()
        }
    }
}

#Preview {
    SettingsView()
}
