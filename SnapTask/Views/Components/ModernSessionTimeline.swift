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
                        currentState: viewModel.state,
                        effectivePhase: viewModel.effectivePhase,
                        currentProgress: viewModel.progress,
                        isWorkCompleted: viewModel.isSessionCompleted(session: session - 1, isWork: true),
                        isBreakCompleted: viewModel.isSessionCompleted(session: session - 1, isWork: false),
                        focusColor: focusColor,
                        breakColor: breakColor
                    )
                }
            }
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(1...viewModel.totalSessions, id: \.self) { session in
                        let segmentWidth = (geometry.size.width - CGFloat(viewModel.totalSessions - 1) * 2) / CGFloat(viewModel.totalSessions)
                        
                        timelineSessionBackground(width: segmentWidth, session: session)
                            .overlay(
                                // Progressive fill with work + break
                                GeometryReader { segmentGeo in
                                    if session == viewModel.currentSession {
                                        timelineCurrentSessionBar(width: segmentGeo.size.width)
                                    } else if session < viewModel.currentSession {
                                        timelineCompletedSessionBar(width: segmentGeo.size.width, session: session)
                                    }
                                    // Future sessions show nothing - just divided gray background
                                }
                            )
                    }
                }
            }
            .frame(height: 6)
        }
    }
    
    private func timelineCurrentSessionBar(width: CGFloat) -> some View {
        let divisor = max(1, viewModel.settings.sessionsUntilLongBreak)
        let isLongBreak = viewModel.currentSession % divisor == 0
        let breakDuration = isLongBreak ? viewModel.settings.longBreakDuration : viewModel.settings.breakDuration
        let totalSessionTime = viewModel.settings.workDuration + breakDuration
        
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        
        var elapsedTime: TimeInterval = 0
        let phase = viewModel.effectivePhase
        
        if phase == .working {
            elapsedTime = max(0, viewModel.settings.workDuration - viewModel.timeRemaining)
        } else if phase == .onBreak {
            elapsedTime = viewModel.settings.workDuration + max(0, breakDuration - viewModel.timeRemaining)
        }
        
        let workProgress = min(1.0, elapsedTime / viewModel.settings.workDuration)
        
        return HStack(spacing: 0) {
            // Work portion
            RoundedRectangle(cornerRadius: 3)
                .fill(focusColor)
                .frame(width: width * workPortion * workProgress, height: 6)
            
            // Break portion (only during break)
            if phase == .onBreak {
                let breakProgress = max(0, min(1.0, (elapsedTime - viewModel.settings.workDuration) / max(1, totalSessionTime - viewModel.settings.workDuration)))
                let breakPortion = 1.0 - workPortion
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(breakColor)
                    .frame(width: width * breakPortion * breakProgress, height: 6)
            }
            
            Spacer()
        }
    }
    
    private func timelineSessionBackground(width: CGFloat, session: Int) -> some View {
        let divisor = max(1, viewModel.settings.sessionsUntilLongBreak)
        let isLongBreak = session % divisor == 0
        let breakDuration = isLongBreak ? viewModel.settings.longBreakDuration : viewModel.settings.breakDuration
        let totalSessionTime = viewModel.settings.workDuration + breakDuration
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion background
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.2))
                .frame(width: width * workPortion, height: 6)
            
            // Break portion background (slightly different opacity)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.15))
                .frame(width: width * breakPortion, height: 6)
        }
    }
    
    private func timelineCompletedSessionBar(width: CGFloat, session: Int) -> some View {
        let divisor = max(1, viewModel.settings.sessionsUntilLongBreak)
        let isLongBreak = session % divisor == 0
        let breakDuration = isLongBreak ? viewModel.settings.longBreakDuration : viewModel.settings.breakDuration
        let totalSessionTime = viewModel.settings.workDuration + breakDuration
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion - green
            RoundedRectangle(cornerRadius: 3)
                .fill(focusColor)
                .frame(width: width * workPortion, height: 6)
            
            // Break portion - break color
            RoundedRectangle(cornerRadius: 3)
                .fill(breakColor)
                .frame(width: width * breakPortion, height: 6)
        }
    }
}

struct SessionIndicator: View {
    let session: Int
    let currentSession: Int
    let currentState: PomodoroViewModel.PomodoroState
    let effectivePhase: PomodoroViewModel.PomodoroState
    let currentProgress: Double
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
                    .fill(workIndicatorColor)
                    .frame(width: 8, height: 8)
                
                // Break indicator (not shown for last session)
                if session < currentSession || (session == currentSession && effectivePhase == .onBreak) {
                    Circle()
                        .fill(breakIndicatorColor)
                        .frame(width: 6, height: 6)
                        .opacity(breakIndicatorOpacity)
                }
            }
        }
        .opacity(session <= currentSession ? 1.0 : 0.5)
    }
    
    private var workIndicatorColor: Color {
        if session < currentSession || (session == currentSession && (effectivePhase == .working || effectivePhase == .onBreak)) {
            return focusColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var breakIndicatorColor: Color {
        if session < currentSession || (session == currentSession && effectivePhase == .onBreak) {
            return breakColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var breakIndicatorOpacity: Double {
        if session == currentSession && effectivePhase == .onBreak {
            return 0.3 + (0.7 * currentProgress) // Fade in as break progresses
        } else if session < currentSession {
            return 1.0
        } else {
            return 1.0
        }
    }
}
