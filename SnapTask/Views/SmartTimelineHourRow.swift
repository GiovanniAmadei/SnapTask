import SwiftUI

struct SmartTimelineHourRow: View {
    let hour: Int
    let tasks: [TodoTask]
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    let isCurrentHour: Bool
    let currentMinute: Int?
    let nextTaskHour: Int?
    let isLastHour: Bool
    
    // Use EnhancedTimelineTaskView instead of the basic one
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Time column with enhanced current time indicator
                VStack(spacing: 4) {
                    Text(hourString)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(isCurrentHour ? .bold : .medium)
                        .foregroundColor(isCurrentHour ? .pink : .secondary)
                    
                    if isCurrentHour {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 10, height: 10)
                                .shadow(color: .pink.opacity(0.4), radius: 3)
                            
                            if let minute = currentMinute {
                                Text(String(format: "%02d", minute))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.pink)
                                    .fontWeight(.bold)
                            }
                            
                            Text("now".localized)
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.pink)
                        }
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isCurrentHour)
                    }
                }
                .frame(width: 60)
                
                // Task content area
                VStack(alignment: .leading, spacing: 8) {
                    if !tasks.isEmpty {
                        ForEach(tasks, id: \.id) { task in
                            EnhancedTimelineTaskView(task: task, viewModel: viewModel)
                        }
                    } else {
                        // Empty state with next task info
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCurrentHour ? Color.pink.opacity(0.08) : Color.gray.opacity(0.03))
                            .frame(height: 50)
                            .overlay(
                                VStack(spacing: 4) {
                                    if isCurrentHour && currentMinute != nil {
                                        HStack {
                                            Circle()
                                                .fill(Color.pink)
                                                .frame(width: 6, height: 6)
                                            Rectangle()
                                                .fill(Color.pink.opacity(0.6))
                                                .frame(height: 2)
                                            Spacer()
                                        }
                                    } else if let nextTaskInfo = timeToNextTask {
                                        Text(nextTaskInfo)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(.horizontal, 12)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isCurrentHour ?
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.pink.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1.5)
                        )
                        .shadow(color: .pink.opacity(0.1), radius: 4)
                    : nil
                )
            }
            .padding(.vertical, 6)
            
            // Connection line
            if !isLastHour {
                HStack {
                    Spacer()
                        .frame(width: 30)
                    
                    VStack(spacing: 0) {
                        if !tasks.isEmpty || nextTaskHour != nil {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isCurrentHour ? Color.pink.opacity(0.6) : Color.gray.opacity(0.3),
                                            Color.gray.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 2, height: 20)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2, height: 2)
                                }
                            }
                        }
                        
                        Divider()
                            .background(
                                isCurrentHour ? 
                                Color.pink.opacity(0.4) : 
                                Color.gray.opacity(0.2)
                            )
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var timeToNextTask: String? {
        guard let nextHour = nextTaskHour, tasks.isEmpty else { return nil }
        let hoursDiff = nextHour - hour
        
        if hoursDiff == 1 {
            return "Next task in 1 hour"
        } else if hoursDiff > 1 {
            return "Next task in \(hoursDiff) hours"
        }
        return nil
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
