import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TimelineView(viewModel: TimelineViewModel())
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            
            PomodoroTabView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
            
            RewardsView()
                .tabItem {
                    Label("Rewards", systemImage: "star")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
