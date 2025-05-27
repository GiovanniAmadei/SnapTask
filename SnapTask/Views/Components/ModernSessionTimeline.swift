import SwiftUI

struct ModernSessionTimeline: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    var body: some View {
        VStack(spacing: 12) {
            // Session progress indicators
            HStack(spacing: 8) {
                ForEach(1...viewModel.totalSessions, id: \.self) { session in
                    SessionIndicator(
                        session: session,
                        currentSession: viewModel.currentSession,
                        isWorkCompleted: viewModel.isSessionCompleted(session: session - 1, isWork: true),
                        isBreakCompleted: viewModel.isSessionCompleted(session: session - 1, isWork: false),
                        focusColor: focusColor,
                        breakColor: breakColor
                    )
                }
            }
            
            // Progress bar
            ProgressView(value: Double(viewModel.currentSession - 1), total: Double(viewModel.totalSessions))
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

struct SessionIndicator: View {
    let session: Int
    let currentSession: Int
    let isWorkCompleted: Bool
    let isBreakCompleted: Bool
    let focusColor: Color
    let breakColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            // Session number
            Text("\(session)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(session == currentSession ? .primary : .secondary)
            
            // Session status indicator
            HStack(spacing: 2) {
                // Work indicator
                Circle()
                    .fill(isWorkCompleted ? focusColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                // Break indicator (not shown for last session)
                if session < 4 { // Assuming max 4 sessions
                    Circle()
                        .fill(isBreakCompleted ? breakColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .opacity(session <= currentSession ? 1.0 : 0.5)
    }
}