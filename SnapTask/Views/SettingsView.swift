import SwiftUI
import StoreKit
import UserNotifications
import MessageUI
import WidgetKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel.shared
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var donationService = DonationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("dailyQuoteNotificationsEnabled") private var dailyQuoteNotificationsEnabled = false
    @AppStorage("dailyQuoteNotificationTime") private var dailyQuoteNotificationTime = "09:00"
    @AppStorage("diaryNotificationsEnabled") private var diaryNotificationsEnabled = false
    @AppStorage("diaryNotificationTime") private var diaryNotificationTime = "20:00"
    @State private var showingDonationSheet = false
    @State private var showingTimePicker = false
    @State private var selectedNotificationTime = Date()
    @State private var notificationPermissionStatus = UNAuthorizationStatus.notDetermined
    private enum SettingsAlertItem: Identifiable {
        case deleteConfirmation
        case resetAndSeedConfirmation
        case deleteSuccess
        case seedSuccess
        case permission
        case taskPermission
        case emailNotAvailable
        case themeWarning

        var id: String {
            switch self {
            case .deleteConfirmation: return "deleteConfirmation"
            case .resetAndSeedConfirmation: return "resetAndSeedConfirmation"
            case .deleteSuccess: return "deleteSuccess"
            case .seedSuccess: return "seedSuccess"
            case .permission: return "permission"
            case .taskPermission: return "taskPermission"
            case .emailNotAvailable: return "emailNotAvailable"
            case .themeWarning: return "themeWarning"
            }
        }

        var title: String {
            switch self {
            case .deleteConfirmation: return "delete_all_data_confirmation_title".localized
            case .resetAndSeedConfirmation: return "Ripristina e Popola?"
            case .deleteSuccess: return "Dati Eliminati"
            case .seedSuccess: return "Dati di Esempio Caricati!"
            case .permission: return "enable_notifications".localized
            case .taskPermission: return "notification_permission_required".localized
            case .emailNotAvailable: return "email_client_not_available".localized
            case .themeWarning: return "dark_mode_theme_warning_title".localized
            }
        }

        var message: String {
            switch self {
            case .deleteConfirmation: return "delete_all_data_confirmation_message".localized
            case .resetAndSeedConfirmation: return "Verranno eliminati tutti i dati attuali e sostituiti con un set completo di dati di esempio."
            case .deleteSuccess: return "Tutti i dati dell'applicazione sono stati cancellati con successo."
            case .seedSuccess: return "Task con orari distribuiti, ricorrenze, premi, categorie, finanze e statistiche sono pronti!"
            case .permission: return "notification_permission_message".localized
            case .taskPermission: return "notification_permission_denied_message".localized
            case .emailNotAvailable: return "email_client_not_available_message".localized
            case .themeWarning: return "dark_mode_theme_warning_message".localized
            }
        }
    }

    @State private var activeAlert: SettingsAlertItem? = nil
    @State private var showingCalendarIntegrationView = false
    @State private var showingWelcome = false
    @State private var isDeleting = false
    @State private var isSeeding = false
    @State private var isSeedingReplace = false
    @State private var showingPremiumPaywall = false

    @State private var didInitialLoad = false

    private enum NotificationTimeTarget {
        case dailyQuote
        case diary
    }

    @State private var timePickerTarget: NotificationTimeTarget = .dailyQuote


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

                    // Redeem Offer Code
                    Button {
                        presentOfferCodeRedemption()
                    } label: {
                        HStack {
                            Image(systemName: "ticket")
                                .foregroundColor(.purple)
                                .frame(width: 24)

                            Text("redeem_offer_code".localized)
                                .themedPrimaryText()
                                .font(.body)

                            Spacer()

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
                            timePickerTarget = .dailyQuote
                            selectedNotificationTime = dateFromTimeString(dailyQuoteNotificationTime)
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
                                activeAlert = .permission
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

                    // Diary Notifications
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("diary_reminder".localized)
                            .themedPrimaryText()

                        Spacer()

                        Toggle("", isOn: $diaryNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                            .onChange(of: diaryNotificationsEnabled) { _, newValue in
                                handleDiaryNotificationToggle(newValue)
                            }
                    }
                    .listRowBackground(theme.surfaceColor)

                    if diaryNotificationsEnabled {
                        Button {
                            timePickerTarget = .diary
                            selectedNotificationTime = dateFromTimeString(diaryNotificationTime)
                            showingTimePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                Text("notification_time".localized)
                                    .themedPrimaryText()

                                Spacer()

                                Text(diaryNotificationTime)
                                    .themedSecondaryText()

                                Image(systemName: "chevron.right")
                                    .themedSecondaryText()
                                    .font(.caption)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .listRowBackground(theme.surfaceColor)

                        if notificationPermissionStatus == .denied {
                            Button {
                                activeAlert = .permission
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

                    // Task Notifications - Master Mute
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("task_notifications_master".localized)
                                .themedPrimaryText()
                                .font(.body)
                            Text("task_notifications_master_description".localized)
                                .font(.caption)
                                .themedSecondaryText()
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $taskNotificationManager.areTaskNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                            .onChange(of: taskNotificationManager.areTaskNotificationsEnabled) { _, newValue in
                                handleMasterMuteToggle(newValue)
                            }
                    }
                    .listRowBackground(theme.surfaceColor)

                    // Show iOS permission status only if master mute is ON and permissions denied
                    if taskNotificationManager.areTaskNotificationsEnabled && taskNotificationManager.authorizationStatus == .denied {
                        Button {
                            activeAlert = .taskPermission
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                Text("ios_permission_required".localized)
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
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.indigo)
                            .frame(width: 24)
                        
                        Text("appearance".localized)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        Picker("", selection: $appearanceMode) {
                            Text("system".localized).tag("system")
                            Text("light".localized).tag("light")
                            Text("dark".localized).tag("dark")
                        }
                        .pickerStyle(.menu)
                        .tint(theme.accentColor)
                        .onChange(of: appearanceMode) { _, newValue in
                            handleAppearanceModeChange(newValue)
                        }
                    }
                    .contentShape(Rectangle())
                    .listRowBackground(theme.surfaceColor)
                    
                    NavigationLink {
                        LanguageSelectionView()
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
                
                // Finance Section
                Section {
                    NavigationLink(destination: FinanceSettingsView()) {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("finance_dashboard".localized)
                                .themedPrimaryText()
                            Spacer()
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } header: {
                    Text("finance".localized)
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

                    Button {
                        openAppStoreReviewPage()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("rate_app".localized)
                                    .themedPrimaryText()
                                    .font(.body)
                                Text("rate_app_subtitle".localized)
                                    .font(.caption)
                                    .themedSecondaryText()
                            }

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

                // MARK: - DEBUG_PRE_RELEASE_REMOVE: Developer / Testing Section
                Section {
                    Button {
                        seedData(replace: false)
                    } label: {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Popola Dati di Esempio (Aggiungi)")
                                    .themedPrimaryText()
                                    .font(.body)
                                
                                Text("Aggiunge task con orari, ricorrenze, premi, finanze e statistiche senza cancellare i dati attuali")
                                    .font(.caption)
                                    .themedSecondaryText()
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if isSeeding && !isSeedingReplace {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.indigo)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSeeding || isDeleting)
                    
                    Button {
                        activeAlert = .resetAndSeedConfirmation
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ripristina & Popola da Zero")
                                    .themedPrimaryText()
                                    .font(.body)
                                
                                Text("Cancella tutto e ricrea un set completo e pulito di dati di test")
                                    .font(.caption)
                                    .themedSecondaryText()
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if isSeeding && isSeedingReplace {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSeeding || isDeleting)
                } header: {
                    Text("Sviluppatore")
                        .themedSecondaryText()
                } footer: {
                    Text("Permette di riempire rapidamente l'app con task distribuiti nella giornata, premi, categorie e finanze per testare ogni schermata.")
                        .font(.caption)
                        .themedSecondaryText()
                }
                .listRowBackground(theme.surfaceColor)

                // Data Management Section
                Section {
                    Button {
                        activeAlert = .deleteConfirmation
                    } label: {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting || isSeeding)
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
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor.ignoresSafeArea())
            .onAppear {
                if !didInitialLoad {
                    didInitialLoad = true
                    Task {
                        await quoteManager.checkAndUpdateQuote()
                        await subscriptionManager.loadProducts()
                    }
                }
                loadNotificationTime()
                checkNotificationPermissionStatus()
                taskNotificationManager.checkAuthorizationStatus()
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
                    switch timePickerTarget {
                    case .dailyQuote:
                        scheduleDailyQuoteNotification()
                    case .diary:
                        scheduleDiaryNotification()
                    }
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
            .alert(
                activeAlert?.title ?? "",
                isPresented: Binding(
                    get: { activeAlert != nil },
                    set: { if !$0 { activeAlert = nil } }
                ),
                presenting: activeAlert
            ) { item in
                switch item {
                case .deleteConfirmation:
                    Button("delete_all_data_button".localized, role: .destructive) {
                        performDeleteAllData()
                    }
                    Button("cancel".localized, role: .cancel) { }
                case .resetAndSeedConfirmation:
                    Button("Ripristina e Popola", role: .destructive) {
                        seedData(replace: true)
                    }
                    Button("Annulla", role: .cancel) { }
                case .permission:
                    Button("settings".localized) {
                        openAppSettings()
                    }
                    Button("cancel".localized, role: .cancel) { }
                case .taskPermission:
                    Button("open_settings".localized) {
                        openAppSettings()
                    }
                    Button("cancel".localized, role: .cancel) { }
                case .emailNotAvailable:
                    Button("ok".localized, role: .cancel) { }
                case .themeWarning:
                    Button("switch_to_simple_theme".localized) {
                        themeManager.setTheme(ThemeManager.defaultTheme)
                    }
                    Button("keep_current_theme".localized, role: .cancel) {
                        appearanceMode = "system"
                    }
                case .seedSuccess, .deleteSuccess:
                    Button("OK", role: .cancel) { }
                }
            } message: { item in
                Text(item.message)
            }
            .fullScreenCover(isPresented: $showingWelcome) {
                WelcomeView()
            }
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.inline)
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

    private func handleDiaryNotificationToggle(_ newValue: Bool) {
        print(" Toggle diary notification: \(newValue)")
        if newValue {
            Task {
                await requestDiaryNotificationPermission()
            }
        } else {
            cancelDiaryNotification()
        }
    }
    
    private func handleAppearanceModeChange(_ newValue: String) {
        // Se l'utente sta provando ad attivare light/dark mode con un tema che sovrascrive i colori
        if newValue != "system" && themeManager.currentTheme.overridesSystemColors {
            activeAlert = .themeWarning
        }
    }
    
    private func handleMasterMuteToggle(_ newValue: Bool) {
        if newValue && taskNotificationManager.authorizationStatus == .denied {
            // Se l'utente abilita il master mute ma iOS nega i permessi, chiedi i permessi
            Task {
                let granted = await taskNotificationManager.requestNotificationPermission()
                await MainActor.run {
                    if granted {
                        taskNotificationManager.setTaskNotificationsEnabled(true)
                    } else {
                        // Se i permessi vengono negati, torna su OFF e mostra l'alert
                        taskNotificationManager.setTaskNotificationsEnabled(false)
                        activeAlert = .taskPermission
                    }
                }
            }
        } else {
            // Caso normale: imposta semplicemente il master mute
            taskNotificationManager.setTaskNotificationsEnabled(newValue)
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
                activeAlert = .permission
            }
            
            checkNotificationPermissionStatus()
        } catch {
            print(" Notification permission error: \(error)")
            dailyQuoteNotificationsEnabled = false
        }
    }

    @MainActor
    private func requestDiaryNotificationPermission() async {
        print(" Requesting diary notification permission...")

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            print(" Diary notification permission result: \(granted)")

            if granted {
                scheduleDiaryNotification()
            } else {
                diaryNotificationsEnabled = false
                activeAlert = .permission
            }

            checkNotificationPermissionStatus()
        } catch {
            print(" Diary notification permission error: \(error)")
            diaryNotificationsEnabled = false
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

                if settings.authorizationStatus == .denied && self.diaryNotificationsEnabled {
                    self.diaryNotificationsEnabled = false
                }
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func presentOfferCodeRedemption() {
        // Simulator: presentCodeRedemptionSheet does nothing. Open App Store redeem webpage instead.
        #if targetEnvironment(simulator)
        let webFallbacksSim = [
            "https://apps.apple.com/redeem?ctx=offercodes",
            "https://apps.apple.com/redeem"
        ]
        openURLs(webFallbacksSim)
        return
        #else
        // Prefer in-app redemption sheet when available (iOS 14+)
        if #available(iOS 14.0, *) {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
            return
        }

        // Device fallback: open App Store redeem page for offer codes for this app
        let appId = "6746721766"
        let urlStrings = [
            "itms-apps://apps.apple.com/redeem?ctx=offercodes&id=\(appId)",
            "itms-apps://apps.apple.com/redeem",
            "https://apps.apple.com/redeem?ctx=offercodes&id=\(appId)",
            "https://apps.apple.com/redeem"
        ]
        openURLs(urlStrings)
        #endif
    }

    // Try opening a sequence of URLs; if one fails, attempt the next.
    private func openURLs(_ urlStrings: [String], index: Int = 0) {
        guard index < urlStrings.count else { return }
        guard let url = URL(string: urlStrings[index]) else {
            openURLs(urlStrings, index: index + 1)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                openURLs(urlStrings, index: index + 1)
            }
        }
    }
    
    private func scheduleDailyQuoteNotification() {
        // Remove existing daily quote notifications (legacy id and new prefix-based ids)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyQuote"]) // legacy

        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix("dailyQuote_") }
                .map { $0.identifier }

            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                print(" Removed \(idsToRemove.count) existing daily quote notifications")
            }

            guard dailyQuoteNotificationsEnabled else { return }

            // Parse the time from dailyQuoteNotificationTime
            let timeComponents = self.dailyQuoteNotificationTime.split(separator: ":")
            guard timeComponents.count == 2,
                  let hour = Int(timeComponents[0]),
                  let minute = Int(timeComponents[1]) else { return }

            let calendar = Calendar.current
            let quoteService = QuoteService.shared

            // Start from today
            let today = Date()
            var scheduledCount = 0

            for offset in 0..<30 {
                guard let baseDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
                components.hour = hour
                components.minute = minute

                guard let fireDate = calendar.date(from: components) else { continue }

                // Only schedule future notifications
                if fireDate <= Date() { continue }

                // Build identifier and content for that day
                let idDateFormatter = DateFormatter()
                idDateFormatter.dateFormat = "yyyy-MM-dd"
                let idDateString = idDateFormatter.string(from: baseDate)
                let identifier = "dailyQuote_\(idDateString)"

                let dailyQuote = quoteService.quoteFor(date: baseDate)

                let content = UNMutableNotificationContent()
                content.title = "your_daily_motivation".localized
                content.body = String(format: "daily_quote_notification_body".localized, dailyQuote.text, dailyQuote.author)
                content.sound = .default
                content.badge = nil

                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request) { error in
                    if let error = error {
                        print(" Error scheduling daily quote (\(identifier)): \(error)")
                    }
                }
                scheduledCount += 1
            }

            print(" Scheduled \(scheduledCount) daily quote notifications starting at \(self.dailyQuoteNotificationTime)")
        }
    }

    private func scheduleDiaryNotification() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix("diary_") }
                .map { $0.identifier }

            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                print(" Removed \(idsToRemove.count) existing diary notifications")
            }

            guard diaryNotificationsEnabled else { return }

            let timeComponents = self.diaryNotificationTime.split(separator: ":")
            guard timeComponents.count == 2,
                  let hour = Int(timeComponents[0]),
                  let minute = Int(timeComponents[1]) else { return }

            let calendar = Calendar.current
            let today = Date()
            var scheduledCount = 0

            for offset in 0..<30 {
                guard let baseDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
                components.hour = hour
                components.minute = minute

                guard let fireDate = calendar.date(from: components) else { continue }

                if fireDate <= Date() { continue }

                let idDateFormatter = DateFormatter()
                idDateFormatter.dateFormat = "yyyy-MM-dd"
                let idDateString = idDateFormatter.string(from: baseDate)
                let identifier = "diary_\(idDateString)"

                let content = UNMutableNotificationContent()
                content.title = "diary_reminder_title".localized
                content.body = "diary_reminder_body".localized
                content.sound = .default
                content.badge = nil

                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request) { error in
                    if let error = error {
                        print(" Error scheduling diary reminder (\(identifier)): \(error)")
                    }
                }

                scheduledCount += 1
            }

            print(" Scheduled \(scheduledCount) diary reminders starting at \(self.diaryNotificationTime)")
        }
    }
    
    private func cancelDailyQuoteNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyQuote"]) // legacy
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix("dailyQuote_") }
                .map { $0.identifier }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                print(" Daily quote notifications cancelled: removed \(idsToRemove.count) items")
            } else {
                print(" Daily quote notification cancelled (legacy only)")
            }
        }
    }

    private func cancelDiaryNotification() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix("diary_") }
                .map { $0.identifier }

            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                print(" Diary reminders cancelled: removed \(idsToRemove.count) items")
            } else {
                print(" Diary reminder cancelled")
            }
        }
    }
    
    private func loadNotificationTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        selectedNotificationTime = formatter.date(from: dailyQuoteNotificationTime) ?? Date()
    }

    private func dateFromTimeString(_ time: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: time) ?? Date()
    }
    
    private func saveNotificationTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let formatted = formatter.string(from: selectedNotificationTime)
        switch timePickerTarget {
        case .dailyQuote:
            dailyQuoteNotificationTime = formatted
        case .diary:
            diaryNotificationTime = formatted
        }
    }
    
    private func performDeleteAllData() {
        isDeleting = true
        HapticManager.shared.impact(.heavy)
        
        Task {
            // 1. Reset TaskManager (wipes standard UserDefaults and App Group shared UserDefaults, clears in-memory tasks and trackingSessions, cancels notifications)
            TaskManager.shared.resetUserDefaults()
            
            // 2. Reset Rewards and Points
            await RewardManager.shared.performCompleteReset()
            
            // 3. Reset Categories
            CategoryManager.shared.performCompleteReset()
            
            // 4. Reset Journal & Mandala
            JournalManager.shared.resetAll()
            MandalaManager.shared.resetAll()
            
            // 5. Reset Finances
            FinanceManager.shared.resetAll()
            
            // 6. Stop active timers and Pomodoro
            TimeTrackerViewModel.shared.activeSessions.forEach { TimeTrackerViewModel.shared.removeSession(id: $0.id) }
            PomodoroViewModel.shared.stop()
            
            // 7. Clear all remaining statistics, metadata and timer keys from UserDefaults
            let ud = UserDefaults.standard
            ud.removeObject(forKey: "timeTracking")
            ud.removeObject(forKey: "taskMetadata")
            ud.removeObject(forKey: "pomodoro_background_timestamp")
            ud.removeObject(forKey: "pomodoro_time_remaining")
            ud.removeObject(forKey: "pomodoro_state")
            ud.removeObject(forKey: "pomodoro_current_session")
            ud.removeObject(forKey: "pomodoro_total_paused_time")
            
            for key in ud.dictionaryRepresentation().keys where key.hasPrefix("timer_session_") {
                ud.removeObject(forKey: key)
            }
            ud.synchronize()
            
            // 8. Cancel all notifications
            TaskNotificationManager.shared.cancelAllNotifications()
            
            // 9. Reload widgets
            WidgetCenter.shared.reloadAllTimelines()
            
            // 10. Notify all UI observers
            NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
            NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)
            NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
            
            await MainActor.run {
                self.isDeleting = false
                HapticManager.shared.notification(.success)
                
                // Present success confirmation after previous modal finishes dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.activeAlert = .deleteSuccess
                }
            }
        }
    }

    // MARK: - DEBUG_PRE_RELEASE_REMOVE
    private func seedData(replace: Bool) {
        guard !isSeeding else { return }
        isSeeding = true
        isSeedingReplace = replace
        HapticManager.shared.impact(.light)
        Task {
            await DemoDataSeeder.shared.seedDemoContent(replace: replace)
            await MainActor.run {
                isSeeding = false
                isSeedingReplace = false
                HapticManager.shared.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.activeAlert = .seedSuccess
                }
            }
        }
    }
    
    private func openEmailClient() {
        let email = "giovannisebastianoamadei@gmail.com"
        let subject = "SnapTask - " + "contact_support".localized
        let body = ""
        
        // Create mailto URL
        let mailtoString = "mailto:\(email)?subject=\(subject)&body=\(body)"
        
        // Encode the string for URL
        guard let mailtoURL = URL(string: mailtoString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            activeAlert = .emailNotAvailable
            return
        }
        
        // Check if device can open mail
        if UIApplication.shared.canOpenURL(mailtoURL) {
            UIApplication.shared.open(mailtoURL)
        } else {
            activeAlert = .emailNotAvailable
        }
    }

    private func openAppStoreReviewPage() {
        let appId = "6746721766"
        #if targetEnvironment(simulator)
        let urls = [
            "https://apps.apple.com/app/id\(appId)?action=write-review"
        ]
        #else
        let urls = [
            "itms-apps://itunes.apple.com/app/id\(appId)?action=write-review",
            "itms-apps://apps.apple.com/app/id\(appId)?action=write-review",
            "https://apps.apple.com/app/id\(appId)?action=write-review"
        ]
        #endif
        openURLs(urls)
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