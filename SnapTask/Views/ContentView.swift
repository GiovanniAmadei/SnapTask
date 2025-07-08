import SwiftUI

struct ContentView: View {
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @State private var showingWelcome = false
    @State private var showingUpdateBanner = false
    @State private var selectedTab = 0
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshID = UUID()
    
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
            .id(refreshID) // Force complete refresh on language change
            .environment(\.theme, themeManager.currentTheme)
            .themedBackground()
            
            // Update Banner Overlay
            if showingUpdateBanner {
                UpdateBannerView(isPresented: $showingUpdateBanner)
                    .onAppear {
                        // Trigger the animation when the banner appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.children.last?.view.subviews.last?.layer.removeAllAnimations()
                        }
                    }
            }
        }
        .onAppear {
            print("📱 ContentView onAppear - hasShownWelcome: \(hasShownWelcome)")
            if !hasShownWelcome {
                showingWelcome = true
            } else {
                // Check if we should show update banner
                checkForUpdateBanner()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActiveTimer)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActivePomodoro)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
            // Force UI refresh when language changes
            print("🌍 ContentView received language change notification")
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeChanged)) { _ in
            // Force UI refresh when theme changes
            print("🎨 ContentView received theme change notification")
            refreshID = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceShowUpdateBanner"))) { _ in
            print("🎉 Force showing update banner...")
            showingUpdateBanner = true
        }
        .fullScreenCover(isPresented: $showingWelcome) {
            WelcomeView()
                .onDisappear {
                    // Check for update banner after welcome is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkForUpdateBanner()
                    }
                }
        }
    }
    
    private func checkForUpdateBanner() {
        print("🔍 Checking for update banner...")
        let shouldShow = UpdateBannerManager.shouldShowUpdateBanner()
        print("🎯 Should show banner: \(shouldShow)")
        
        if shouldShow {
            print("🎉 Showing update banner...")
            showingUpdateBanner = true
        } else {
            print("📱 Update banner already shown for this version, skipping")
        }
    }
}

// MARK: - Debug Helper (for testing)
extension ContentView {
    func resetUpdateBannerForTesting() {
        UpdateBannerManager.resetBannerForTesting()
    }
}