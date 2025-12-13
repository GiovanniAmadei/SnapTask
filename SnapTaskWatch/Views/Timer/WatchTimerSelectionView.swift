import SwiftUI

struct WatchTimerSelectionView: View {
    var preselectedTask: TodoTask? = nil
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var selectedMode: TimerMode = .simple
    
    enum TimerMode: String, CaseIterable {
        case simple = "Simple"
        case pomodoro = "Pomodoro"
        
        var icon: String {
            switch self {
            case .simple: return "timer"
            case .pomodoro: return "clock.fill"
            }
        }
        
        var description: String {
            switch self {
            case .simple: return "Track time freely"
            case .pomodoro: return "Focus sessions with breaks"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Task info if preselected
                if let task = preselectedTask {
                    taskHeader(task)
                }
                
                // Mode selection
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    NavigationLink {
                        destinationView(for: mode)
                    } label: {
                        modeCard(mode)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Timer")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func taskHeader(_ task: TodoTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.icon)
                .font(.caption)
                .foregroundColor(task.category != nil ? Color(hex: task.category!.color) : .gray)
            
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func modeCard(_ mode: TimerMode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: mode.icon)
                .font(.title3)
                .foregroundColor(mode == .pomodoro ? .orange : .blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.rawValue)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                
                Text(mode.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func destinationView(for mode: TimerMode) -> some View {
        switch mode {
        case .simple:
            WatchSimpleTimerView(task: preselectedTask)
        case .pomodoro:
            WatchPomodoroSetupView(task: preselectedTask)
        }
    }
}

#Preview {
    WatchTimerSelectionView()
        .environmentObject(WatchSyncManager.shared)
}
