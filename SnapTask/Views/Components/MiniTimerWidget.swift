import SwiftUI

struct MiniTimerWidget: View {
    let sessionId: UUID
    @ObservedObject var viewModel: TimeTrackerViewModel
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var session: TrackingSession? {
        viewModel.getSession(id: sessionId)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status indicator - CHANGE: Make it yellow
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .opacity(session?.isPaused == true ? 0.5 : 1.0)
                        .symbolEffect(.pulse, options: .repeating, isActive: session?.isRunning == true)
                    
                    // Session type
                    Text(session?.isPaused == true ? "Paused" : "Timer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                // Elapsed time
                Text(viewModel.formattedElapsedTime(for: sessionId))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                
                // Task name if available
                if let taskName = session?.taskName {
                    Text(taskName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Focus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 32)
    }
}
