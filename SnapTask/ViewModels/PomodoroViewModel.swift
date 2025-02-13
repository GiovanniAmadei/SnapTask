import Foundation
import SwiftUI
import Combine
import OSLog

class PomodoroViewModel: ObservableObject {
    enum PomodoroState {
        case notStarted
        case working
        case onBreak
        case paused
        case completed
    }
    
    @Published var state: PomodoroState = .notStarted
    @Published var timeRemaining: TimeInterval
    @Published var currentSession: Int = 1
    @Published var settings: PomodoroSettings
    
    let totalSessions: Int
    @MainActor private var timer: AnyCancellable? {
        didSet { Logger.pomodoro.debug("Timer state updated: \(self.timer != nil)") }
    }
    private var startDate: Date?
    private var pausedTimeRemaining: TimeInterval?
    
    @Published private var completedWorkSessions: Set<Int> = []
    @Published private var completedBreakSessions: Set<Int> = []
    
    init(settings: PomodoroSettings) {
        self.settings = settings
        self.timeRemaining = settings.workDuration
        self.totalSessions = settings.sessionsUntilLongBreak
    }
    
    var progress: Double {
        let total = state == .working ? settings.workDuration : 
                   (currentSession % settings.sessionsUntilLongBreak == 0 ? 
                    settings.longBreakDuration : settings.breakDuration)
        guard total > 0 else {
            Logger.pomodoro.error("Invalid timer duration configuration")
            return 0
        }
        return 1 - (timeRemaining / total)
    }
    
    @MainActor
    func start() {
        guard timer == nil else { return }
        
        if state == .paused {
            state = pausedState ?? .working
        } else {
            state = .working
        }
        startDate = Date()
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimer()
            }
    }
    
    @MainActor
    func pause() {
        timer?.cancel()
        timer = nil
        pausedTimeRemaining = timeRemaining
        pausedState = state
        state = .paused
    }
    
    @MainActor
    func resume() {
        guard state == .paused else { return }
        start()
    }
    
    @MainActor
    func skip() {
        if state == .working {
            completedWorkSessions.insert(currentSession - 1)
            state = .onBreak
            timeRemaining = currentSession % settings.sessionsUntilLongBreak == 0 ? 
                settings.longBreakDuration : settings.breakDuration
            start()
        } else {
            completedBreakSessions.insert(currentSession - 1)
            completeBreakSession()
        }
    }
    
    @MainActor
    func stop() {
        timer?.cancel()
        timer = nil
        state = .notStarted
        timeRemaining = settings.workDuration
        currentSession = 1
    }
    
    @MainActor
    private func updateTimer() {
        timeRemaining -= 1
        
        if timeRemaining <= 0 {
            if state == .working {
                completeWorkSession()
            } else {
                completeBreakSession()
            }
        }
    }
    
    @MainActor
    private func completeWorkSession() {
        timer?.cancel()
        timer = nil
        
        completedWorkSessions.insert(currentSession - 1)
        
        if currentSession >= totalSessions {
            state = .completed
            return
        }
        
        state = .onBreak
        timeRemaining = currentSession % settings.sessionsUntilLongBreak == 0 ? 
            settings.longBreakDuration : settings.breakDuration
        startDate = Date()
        start()
    }
    
    @MainActor
    private func completeBreakSession() {
        timer?.cancel()
        timer = nil
        
        completedBreakSessions.insert(currentSession - 1)
        currentSession += 1
        
        if currentSession > totalSessions {
            state = .completed
            return
        }
        
        state = .working
        timeRemaining = settings.workDuration
        startDate = Date()
        start()
    }
    
    private var pausedState: PomodoroState?
    
    func isSessionCompleted(session: Int, isWork: Bool) -> Bool {
        if isWork {
            return completedWorkSessions.contains(session)
        } else {
            return completedBreakSessions.contains(session)
        }
    }
    
    var totalSessionTime: TimeInterval {
        return settings.workDuration + 
            (currentSession % settings.sessionsUntilLongBreak == 0 ? 
                settings.longBreakDuration : settings.breakDuration)
    }
    
    deinit {
        timer?.cancel()
        Logger.pomodoro.info("PomodoroViewModel deinitialized")
    }
}

private extension Logger {
    static let pomodoro = Logger(subsystem: "com.yourapp.SnapTask", category: "Pomodoro")
} 