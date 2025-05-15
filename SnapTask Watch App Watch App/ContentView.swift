import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineWatchView()
                .tag(0)
            
            PomodoroListView()
                .tag(1)
                
            WatchStatisticsView()
                .tag(2)
                
            SettingsWatchView()
                .tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationTitle(tabTitle)
    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0:
            return ""
        case 1:
            return "Pomodoro"
        case 2:
            return "Statistics"
        case 3:
            return "Settings"
        default:
            return ""
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 