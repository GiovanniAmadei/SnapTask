import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var statisticsViewModel = StatisticsViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "clock")
                }
                .tag(0)
            
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar")
                }
                .tag(1)
                .onChange(of: selectedTab) { oldValue, newValue in
                    if newValue == 1 {
                        statisticsViewModel.refreshStats()
                    }
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
} 