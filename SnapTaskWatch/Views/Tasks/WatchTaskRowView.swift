import SwiftUI

struct WatchTaskRowView: View {
    let task: TodoTask
    let date: Date
    @EnvironmentObject var syncManager: WatchSyncManager
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return task.completions[startOfDay]?.isCompleted == true
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return .gray
    }
    
    private var priorityColor: Color {
        Color(hex: task.priority.color)
    }

    private var categoryName: String? {
        task.category?.name
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                
                HStack(spacing: 4) {
                    // Category
                    if let categoryName {
                        Text(categoryName)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.2))
                            .foregroundColor(categoryColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }

                    // Time
                    if task.hasSpecificTime {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(task.startTime, style: .time)
                        }
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                    
                    // Priority indicator (iOS style icon)
                    Image(systemName: task.priority.icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(priorityColor)
                    
                    // Points
                    if task.hasRewardPoints && task.rewardPoints > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                            Text("\(task.rewardPoints)")
                        }
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Completion toggle on the right
            Button {
                syncManager.toggleTaskCompletion(task, on: date)
            } label: {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isCompleted {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    WatchTaskRowView(
        task: TodoTask(
            name: "Test Task",
            startTime: Date(),
            hasSpecificTime: true,
            priority: .high,
            icon: "star.fill",
            hasRewardPoints: true,
            rewardPoints: 10
        ),
        date: Date()
    )
    .environmentObject(WatchSyncManager.shared)
}
