import SwiftUI
import Combine

struct PomodoroView: View {
    let task: TodoTask
    let presentationStyle: PresentationStyle
    @StateObject private var viewModel = PomodoroViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showingCompletionSheet = false
    @State private var showingSettings = false
    @State private var completedFocusTime: TimeInterval = 0
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    enum PresentationStyle {
        case fullscreen
        case sheet
    }
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    private var isCompactMode: Bool {
        presentationStyle == .sheet
    }
    
    init(task: TodoTask, presentationStyle: PresentationStyle = .sheet) {
        self.task = task
        self.presentationStyle = presentationStyle
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isCompactMode {
                compactLayout
            } else {
                fullscreenLayout
            }
        }
        .themedBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { 
                    dismiss() 
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .themedPrimaryText()
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(theme.surfaceColor)
                        )
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if isCompactMode {
                        Button(action: {
                            expandToFullscreen()
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.accentColor)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(theme.accentColor.opacity(0.1))
                                )
                        }
                    }
                    
                    Button(action: { 
                        viewModel.stop()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
        .onAppear {
            if !viewModel.isActiveTask(task) {
                viewModel.setActiveTask(task)
            }
        }
        .onChange(of: viewModel.state) { oldState, newState in
            if newState == .completed {
                completedFocusTime = Double(viewModel.currentSession) * viewModel.settings.workDuration
                showingCompletionSheet = true
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            PomodoroCompletionView(
                task: task,
                focusTimeCompleted: completedFocusTime
            )
        }
        .sheet(isPresented: $showingSettings) {
            ContextualPomodoroSettingsView(context: .task)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { _ in
            dismiss()
        }
    }
    
    private var compactLayout: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if let category = task.category {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 8, height: 8)
                }
                
                Text(task.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .themedPrimaryText()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("session".localized)
                        .font(.system(.footnote, design: .rounded).weight(.regular))
                        .themedSecondaryText()
                    Text("\(viewModel.currentSession)/\(viewModel.totalSessions)")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .themedPrimaryText()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(theme.surfaceColor)
                )
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.caption.weight(.medium))
                        .foregroundColor(theme.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(theme.accentColor.opacity(0.1))
                        )
                }
                
                Button("completed".localized) {
                    handleDone()
                }
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundColor(theme.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(theme.accentColor.opacity(0.1))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            ZStack {
                Circle()
                    .stroke(
                        (viewModel.state == .working ? focusColor : breakColor).opacity(0.1),
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0.0, to: viewModel.progress)
                    .stroke(
                        LinearGradient(
                            colors: viewModel.state == .working ? 
                                [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.state == .working ? "brain.head.profile" : "cup.and.saucer.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.state == .working ? focusColor : breakColor)
                        
                        Text(viewModel.state == .working ? "focus_time".localized : "break_time".localized)
                            .font(.system(.footnote, design: .rounded))
                            .themedSecondaryText()
                    }
                    
                    Text(timeString(from: viewModel.timeRemaining))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: viewModel.state == .working ? 
                                    [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                    
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .themedSecondaryText()
                }
            }
            .padding(.vertical, 8)
            
            GeometryReader { geometry in
                ZStack {
                    HStack(spacing: 3) {
                        ForEach(1...viewModel.totalSessions, id: \.self) { session in
                            ZStack {
                                sessionBackgroundBar(width: (geometry.size.width - CGFloat(viewModel.totalSessions - 1) * 3) / CGFloat(viewModel.totalSessions), session: session)
                                if session == viewModel.currentSession {
                                    currentSessionProgressBar(width: (geometry.size.width - CGFloat(viewModel.totalSessions - 1) * 3) / CGFloat(viewModel.totalSessions))
                                } else if session < viewModel.currentSession {
                                    completedSessionProgressBar(width: (geometry.size.width - CGFloat(viewModel.totalSessions - 1) * 3) / CGFloat(viewModel.totalSessions), session: session)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 4)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: { handleStop() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(viewModel.state == .notStarted || viewModel.state == .completed)
                .opacity((viewModel.state == .notStarted || viewModel.state == .completed) ? 0.5 : 1.0)
                
                Button(action: {
                    if viewModel.state == .notStarted || viewModel.state == .paused {
                        viewModel.start()
                    } else {
                        viewModel.pause()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: viewModel.state == .working ? 
                                        [focusColor, focusColor.opacity(0.8)] : 
                                        viewModel.state == .onBreak ? 
                                        [breakColor, breakColor.opacity(0.8)] :
                                        [theme.accentColor, theme.accentColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: viewModel.state == .working || viewModel.state == .onBreak ? 
                            "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(
                        color: (viewModel.state == .working ? focusColor : 
                               viewModel.state == .onBreak ? breakColor : theme.accentColor).opacity(0.3), 
                        radius: 6, x: 0, y: 3
                    )
                }
                
                Button(action: { viewModel.skip() }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.state == .working ? focusColor : 
                                 viewModel.state == .onBreak ? breakColor : theme.borderColor)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: (viewModel.state == .working ? focusColor : 
                                   viewModel.state == .onBreak ? breakColor : theme.borderColor).opacity(0.3), 
                           radius: 4, x: 0, y: 2)
                }
                .disabled(viewModel.state == .notStarted || viewModel.state == .completed)
                .opacity((viewModel.state == .notStarted || viewModel.state == .completed) ? 0.5 : 1.0)
                
                if isCompactMode {
                    Button(action: {
                        let sessionProgress = viewModel.state == .working ? viewModel.progress : 1.0
                        let completedFullSessions = max(0, viewModel.currentSession - 1)
                        let currentSessionTime = sessionProgress * viewModel.settings.workDuration
                        completedFocusTime = Double(completedFullSessions) * viewModel.settings.workDuration + currentSessionTime
                        showingCompletionSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    private var fullscreenLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        if let category = task.category {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 12, height: 12)
                        }
                        
                        Text(task.name)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("session".localized)
                                .font(.system(.footnote, design: .rounded))
                                .themedSecondaryText()
                            Text("\(viewModel.currentSession)/\(viewModel.totalSessions)")
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .themedPrimaryText()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.surfaceColor)
                        )
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                                .font(.body.weight(.medium))
                                .foregroundColor(theme.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(theme.accentColor.opacity(0.1))
                                )
                        }
                        
                        Button("completed".localized) {
                            handleDone()
                        }
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundColor(theme.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(theme.accentColor.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (viewModel.state == .working ? focusColor : breakColor).opacity(0.1),
                                        (viewModel.state == .working ? focusColor : breakColor).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 6
                            )
                            .frame(width: 220, height: 220)
                        
                        Circle()
                            .trim(from: 0.0, to: viewModel.progress)
                            .stroke(
                                LinearGradient(
                                    colors: viewModel.state == .working ? 
                                        [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: 6,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(Angle(degrees: -90))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.state == .working ? "brain.head.profile" : "cup.and.saucer.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.state == .working ? focusColor : breakColor)
                                
                                Text(viewModel.state == .working ? "focus_time".localized : "break_time".localized)
                                    .font(.system(.subheadline, design: .rounded))
                                    .themedSecondaryText()
                            }
                            
                            Text(timeString(from: viewModel.timeRemaining))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: viewModel.state == .working ? 
                                            [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .contentTransition(.numericText())
                            
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .themedSecondaryText()
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(
                    LinearGradient(
                        colors: [
                            theme.backgroundColor,
                            theme.surfaceColor.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("session_overview".localized)
                        .font(.headline.weight(.semibold))
                        .themedPrimaryText()
                    Spacer()
                    Text("\(formatTime(viewModel.timeRemaining)) " + "left".localized)
                        .font(.system(.footnote, design: .rounded))
                        .themedSecondaryText()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                ModernSessionTimeline(viewModel: viewModel)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ControlButton(
                        icon: "stop.fill",
                        size: .medium,
                        color: .red,
                        isDisabled: viewModel.state == .notStarted || viewModel.state == .completed
                    ) {
                        handleStop()
                    }
                    
                    ControlButton(
                        icon: viewModel.state == .working || viewModel.state == .onBreak ? 
                            "pause.fill" : "play.fill",
                        size: .large,
                        color: viewModel.state == .working ? focusColor : 
                               viewModel.state == .onBreak ? breakColor : 
                               viewModel.state == .notStarted ? theme.accentColor : focusColor,  
                        isPulsing: viewModel.state == .working || viewModel.state == .onBreak
                    ) {
                        if viewModel.state == .notStarted || viewModel.state == .paused {
                            viewModel.start()
                        } else {
                            viewModel.pause()
                        }
                    }
                    
                    ControlButton(
                        icon: "forward.fill",
                        size: .medium,
                        color: viewModel.state == .working ? focusColor : 
                               viewModel.state == .onBreak ? breakColor : theme.textColor,
                        isDisabled: viewModel.state == .notStarted || viewModel.state == .completed
                    ) {
                        viewModel.skip()
                    }
                }
                
                if viewModel.state != .notStarted {
                    let completionTime = Date().addingTimeInterval(viewModel.timeRemaining)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(.footnote, design: .rounded))
                            .themedSecondaryText()
                        Text("finishes_at".localized + " \(formatTimeOnly(completionTime))")
                            .font(.system(.footnote, design: .rounded))
                            .themedSecondaryText()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    private func currentSessionProgressBar(width: CGFloat) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (viewModel.currentSession % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        
        var elapsedTime: TimeInterval = 0
        
        if viewModel.state == .working {
            elapsedTime = viewModel.settings.workDuration - viewModel.timeRemaining
        } else if viewModel.state == .onBreak {
            let breakDuration = viewModel.currentSession % viewModel.settings.sessionsUntilLongBreak == 0 ? 
                viewModel.settings.longBreakDuration : viewModel.settings.breakDuration
            elapsedTime = viewModel.settings.workDuration + (breakDuration - viewModel.timeRemaining)
        }
        
        let workProgress = min(1.0, elapsedTime / viewModel.settings.workDuration)
        let totalProgress = min(1.0, elapsedTime / totalSessionTime)
        
        return HStack(spacing: 0) {
            // Work portion (always green when completed/in progress)
            Rectangle()
                .fill(focusColor)
                .frame(width: width * workPortion * workProgress)
            
            // Break portion (only visible during break)
            if viewModel.state == .onBreak {
                let breakProgress = (elapsedTime - viewModel.settings.workDuration) / (totalSessionTime - viewModel.settings.workDuration)
                let breakPortion = 1.0 - workPortion
                
                Rectangle()
                    .fill(breakColor)
                    .frame(width: width * breakPortion * breakProgress)
            }
            
            Spacer()
        }
    }
    
    private func completedSessionProgressBar(width: CGFloat, session: Int) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (session % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion - green
            Rectangle()
                .fill(focusColor)
                .frame(width: width * workPortion, height: 4)
            
            // Break portion - break color
            Rectangle()
                .fill(breakColor)
                .frame(width: width * breakPortion, height: 4)
        }
    }
    
    private func sessionBackgroundBar(width: CGFloat, session: Int) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (session % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion background
            Rectangle()
                .fill(theme.borderColor.opacity(0.3))
                .frame(width: width * workPortion, height: 4)
            
            // Break portion background (slightly different opacity)
            Rectangle()
                .fill(theme.borderColor.opacity(0.2))
                .frame(width: width * breakPortion, height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
    
    private func expandToFullscreen() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .expandActivePomodoro, object: task)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openFocusTabPomodoro, object: task)
        }
    }
    
    private func handleStop() {
        viewModel.stop()
    }
    
    private func handleDone() {
        // Solo apri completion sheet se la sessione è effettivamente completa o fermata
        if viewModel.state == .completed {
            showingCompletionSheet = true
        } else if viewModel.state == .working || viewModel.state == .onBreak || viewModel.state == .paused {
            // Se la sessione è attiva, fermala prima e poi apri completion sheet
            let sessionProgress = viewModel.state == .working ? viewModel.progress : 1.0
            let completedFullSessions = max(0, viewModel.currentSession - 1)
            let currentSessionTime = sessionProgress * viewModel.settings.workDuration
            completedFocusTime = Double(completedFullSessions) * viewModel.settings.workDuration + currentSessionTime
            
            // Ferma il timer
            viewModel.stop()
            
            // Ora apri completion sheet
            showingCompletionSheet = true
        } else {
            // Se non è iniziata, semplicemente chiudi
            dismiss()
        }
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes) min"
    }
}

struct MiniPomodoroWidget: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.state == .working ? focusColor : breakColor)
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.state == .paused ? 0.5 : 1.0)
                        .symbolEffect(.pulse, options: .repeating, isActive: viewModel.state == .working || viewModel.state == .onBreak)
                    
                    Text(viewModel.state == .working ? "focus".localized : "break".localized)
                        .font(.system(size: 12, weight: .medium))
                        .themedSecondaryText()
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Text(timeString(from: viewModel.timeRemaining))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .themedPrimaryText()
                
                Capsule()
                    .fill(theme.borderColor.opacity(0.2))
                    .frame(height: 4)
                    .overlay(
                        GeometryReader { geo in
                            ZStack {
                                HStack(spacing: 1) {
                                    ForEach(1...viewModel.totalSessions, id: \.self) { _ in
                                        let segmentWidth = geo.size.width / CGFloat(viewModel.totalSessions)
                                        Capsule()
                                            .fill(theme.borderColor.opacity(0.3))
                                            .frame(width: segmentWidth)
                                    }
                                }
                                
                                HStack(spacing: 0) {
                                    ForEach(1...viewModel.totalSessions, id: \.self) { session in
                                        let sessionWidth = geo.size.width / CGFloat(viewModel.totalSessions)
                                        
                                        miniWidgetSessionBackground(width: sessionWidth, session: session)
                                            .overlay(
                                                GeometryReader { segmentGeo in
                                                    if session == viewModel.currentSession {
                                                        miniWidgetCurrentSessionBar(width: segmentGeo.size.width)
                                                    } else if session < viewModel.currentSession {
                                                        miniWidgetCompletedSessionBar(width: segmentGeo.size.width, session: session)
                                                    }
                                                    // Future sessions show nothing - just divided gray background
                                                }
                                            )
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    )
                    .frame(width: 36)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.surfaceColor)
                    .shadow(color: theme.shadowColor, radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 32)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func miniWidgetCurrentSessionBar(width: CGFloat) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (viewModel.currentSession % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        
        var elapsedTime: TimeInterval = 0
        
        if viewModel.state == .working {
            elapsedTime = viewModel.settings.workDuration - viewModel.timeRemaining
        } else if viewModel.state == .onBreak {
            let breakDuration = viewModel.currentSession % viewModel.settings.sessionsUntilLongBreak == 0 ? 
                viewModel.settings.longBreakDuration : viewModel.settings.breakDuration
            elapsedTime = viewModel.settings.workDuration + (breakDuration - viewModel.timeRemaining)
        }
        
        let workProgress = min(1.0, elapsedTime / viewModel.settings.workDuration)
        
        return HStack(spacing: 0) {
            // Work portion
            Capsule()
                .fill(focusColor)
                .frame(width: width * workPortion * workProgress)
            
            // Break portion (only during break)
            if viewModel.state == .onBreak {
                let breakProgress = (elapsedTime - viewModel.settings.workDuration) / (totalSessionTime - viewModel.settings.workDuration)
                let breakPortion = 1.0 - workPortion
                
                Capsule()
                    .fill(breakColor)
                    .frame(width: width * breakPortion * breakProgress)
            }
            
            Spacer()
        }
    }
    
    private func miniWidgetSessionBackground(width: CGFloat, session: Int) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (session % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion background
            Capsule()
                .fill(theme.borderColor.opacity(0.3))
                .frame(width: width * workPortion, height: 4)
            
            // Break portion background (slightly different opacity)
            Capsule()
                .fill(theme.borderColor.opacity(0.2))
                .frame(width: width * breakPortion, height: 4)
        }
    }
    
    private func miniWidgetCompletedSessionBar(width: CGFloat, session: Int) -> some View {
        let totalSessionTime = viewModel.settings.workDuration + 
            (session % viewModel.settings.sessionsUntilLongBreak == 0 ? 
             viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        let workPortion = viewModel.settings.workDuration / totalSessionTime
        let breakPortion = 1.0 - workPortion
        
        return HStack(spacing: 0) {
            // Work portion - green
            Capsule()
                .fill(focusColor)
                .frame(width: width * workPortion, height: 4)
            
            // Break portion - break color
            Capsule()
                .fill(breakColor)
                .frame(width: width * breakPortion, height: 4)
        }
    }
}