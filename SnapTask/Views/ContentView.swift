import SwiftUI

struct ContentView: View {
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @State private var showingWelcome = false
    // Version 1.0 banner removed - no longer needed
    @State private var selectedTab = 0
    @State private var showingTaskDetail = false
    @State private var selectedTaskId: UUID?
    @State private var showingJournal = false
    @State private var selectedJournalDate: Date?
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshID = UUID()
    @State private var tabBarThemeID = UUID()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TimelineView(viewModel: TimelineViewModel())
                    .tabItem {
                        Label("timeline".localized, systemImage: "calendar")
                    }
                    .tag(0)
                
                FocusTabView()
                    .tabItem {
                        Label("focus".localized, systemImage: "timer")
                    }
                    .tag(1)
                
                RewardsView()
                    .tabItem {
                        Label("rewards".localized, systemImage: "star")
                    }
                    .tag(2)
                
                StatisticsView()
                    .tabItem {
                        Label("statistics".localized, systemImage: "chart.bar")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Label("settings".localized, systemImage: "gearshape")
                    }
                    .tag(4)
            }
            .id(refreshID) // Only for language changes
            .environment(\.theme, themeManager.currentTheme)
            .themedBackground()
            
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let taskId = selectedTaskId {
                NavigationStack {
                    TaskDetailView(taskId: taskId)
                }
            }
        }
        .sheet(isPresented: $showingJournal) {
            if let date = selectedJournalDate {
                NavigationStack {
                    JournalView(date: date)
                }
            }
        }
        .onAppear {
            print("ContentView onAppear - hasShownWelcome: \(hasShownWelcome)")
            if !hasShownWelcome {
                showingWelcome = true
            }

            if let dateString = UserDefaults.standard.string(forKey: "pendingJournalDateFromNotification") {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dateString) {
                    selectedJournalDate = date
                    showingJournal = true
                }
                UserDefaults.standard.removeObject(forKey: "pendingJournalDateFromNotification")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActiveTimer)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActivePomodoro)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTaskDetail)) { notification in
            if let taskId = notification.object as? UUID {
                selectedTaskId = taskId
                selectedTab = 0 // Switch to timeline tab
                showingTaskDetail = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openJournalFromNotification)) { notification in
            if let date = notification.object as? Date {
                selectedJournalDate = date
                showingJournal = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
            // Force UI refresh when language changes
            print("ContentView received language change notification")
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
            // Force immediate tab bar and navigation bar update without refreshing the entire view
            print("ContentView received theme change notification - updating bars directly")
            forceUpdateExistingBars()
        }
        .fullScreenCover(isPresented: $showingWelcome) {
            WelcomeView()
        }
    }
    
    private func forceUpdateExistingBars() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("Could not find window for bars update")
            return
        }
        
        let theme = themeManager.currentTheme
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(theme.backgroundColor)
        
        // Configure normal (unselected) tab items
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(theme.secondaryTextColor)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(theme.secondaryTextColor)
        ]
        
        // Configure selected tab items
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(theme.primaryColor)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(theme.primaryColor)
        ]
        
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(theme.backgroundColor)
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(theme.textColor)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(theme.textColor)
        ]
        
        // Apply to global appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Find and update the actual bars
        func updateBars(in view: UIView) {
            if let tabBar = view as? UITabBar {
                print("Found tab bar, applying new theme...")
                tabBar.standardAppearance = tabBarAppearance
                tabBar.scrollEdgeAppearance = tabBarAppearance
                tabBar.setNeedsLayout()
                tabBar.layoutIfNeeded()
            }
            
            if let navBar = view as? UINavigationBar {
                print("Found navigation bar, applying new theme...")
                navBar.standardAppearance = navBarAppearance
                navBar.compactAppearance = navBarAppearance
                navBar.scrollEdgeAppearance = navBarAppearance
                navBar.setNeedsLayout()
                navBar.layoutIfNeeded()
            }
            
            for subview in view.subviews {
                updateBars(in: subview)
            }
        }
        
        updateBars(in: window)
        
        // Also update tint color
        window.tintColor = UIColor(theme.accentColor)
        
        print("Tab bar and navigation bar theme updated successfully")
    }
    
}