import SwiftUI

struct ContentView: View {
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @State private var showingWelcome = false
    @State private var selectedTab = 0
    @StateObject private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
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
        .onAppear {
            if !hasShownWelcome {
                showingWelcome = true
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
        .fullScreenCover(isPresented: $showingWelcome) {
            WelcomeView()
        }
    }
}
