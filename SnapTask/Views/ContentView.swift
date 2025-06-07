import SwiftUI

struct ContentView: View {
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @State private var showingWelcome = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView(viewModel: TimelineViewModel())
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(0)
            
            FocusTabView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(1)
            
            RewardsView()
                .tabItem {
                    Label("Rewards", systemImage: "star")
                }
                .tag(2)
            
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
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
        .fullScreenCover(isPresented: $showingWelcome) {
            WelcomeView()
        }
    }
}
