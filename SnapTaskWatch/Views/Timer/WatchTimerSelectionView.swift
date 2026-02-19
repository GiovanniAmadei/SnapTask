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
        List {
            if let task = preselectedTask {
                Section {
                    taskHeader(task)
                }
            }

            Section {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    NavigationLink {
                        destinationView(for: mode)
                    } label: {
                        modeRow(mode)
                    }
                }
            }
        }
        .navigationTitle("Timer")
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
    }

    private func modeRow(_ mode: TimerMode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: mode.icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
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
        .padding(.vertical, 4)
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
