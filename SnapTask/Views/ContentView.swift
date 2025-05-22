import SwiftUI

struct ContentView: View {
    @StateObject private var timelineViewModel = TimelineViewModel()
    @AppStorage("selectedTab") private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView(viewModel: timelineViewModel)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(0)
            
            PomodoroTabView()
                .tabItem {
                    Label("Pomodoro", systemImage: "timer")
                }
                .tag(1)
            
            RewardsView()
                .tabItem {
                    Label("Rewards", systemImage: "gift")
                }
                .tag(2)
            
            TaskStatisticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
    }
} 
