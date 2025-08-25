import Foundation
import SwiftUI
import Combine
import UIKit
import UserNotifications
import os.log

@MainActor
class PomodoroViewModel: ObservableObject {
    enum PomodoroState: String {
        case notStarted = "notStarted"
        case working = "working"
        case onBreak = "onBreak"
        case paused = "paused"
        case completed = "completed"
    }
    
    // Shared instance for the active Pomodoro session
    static let shared = PomodoroViewModel()
    
    // Current context and settings manager
    @Published var context: PomodoroContext = .general
    private let settingsManager = PomodoroSettingsManager.shared
    
    // Current active task being tracked
    @Published var activeTask: TodoTask?
    
    @Published var state: PomodoroState = .notStarted
    @Published var timeRemaining: TimeInterval
    @Published var currentSession: Int = 1
    
    private var sessionStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    
    // Dynamic settings based on context
    var settings: PomodoroSettings {
        get {
            return settingsManager.getSettings(for: context)
        }
        set {
            settingsManager.updateSettings(newValue, for: context)
            applySettingsToCurrentSession()
        }
    }
    
    // Use settings.totalSessions instead of sessionsUntilLongBreak
    var totalSessions: Int {
        return settings.totalSessions
    }
    
    private var timer: AnyCancellable? {
        didSet { Logger.pomodoro("Timer state updated: \(self.timer != nil)", level: .debug) }
    }
    private var startDate: Date?
    private var pausedTimeRemaining: TimeInterval?
    
    @Published private var completedWorkSessions: Set<Int> = []
    @Published private var completedBreakSessions: Set<Int> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.timeRemaining = PomodoroSettings.defaultSettings.workDuration
        setupBackgroundHandling()
        
        NotificationCenter.default.publisher(for: .pomodoroSettingsUpdated)
            .sink { [weak self] notification in
                if let context = notification.object as? PomodoroContext,
                   context == self?.context {
                    self?.applySettingsToCurrentSession()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        guard state == .working || state == .onBreak else { return }
        
        // Salva lo stato attuale per calcolare il tempo al ritorno
        saveBackgroundState()
        
        // Programma notifica per la fine della sessione corrente
        Task {
            await scheduleSessionEndNotification()
        }
    }
    
    @objc private func appWillEnterForeground() {
        guard state == .working || state == .onBreak else { return }
        
        // Calcola il tempo trascorso in background
        calculateBackgroundProgress()
        
        // Riavvia il timer se necessario
        if state == .working || state == .onBreak {
            restartTimerAfterBackground()
        }
        
        // Rimuovi notifiche esistenti se la sessione è ancora attiva
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func saveBackgroundState() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pomodoro_background_timestamp")
        UserDefaults.standard.set(timeRemaining, forKey: "pomodoro_time_remaining")
        UserDefaults.standard.set(state.rawValue, forKey: "pomodoro_state")
        UserDefaults.standard.set(currentSession, forKey: "pomodoro_current_session")
        UserDefaults.standard.set(totalPausedTime, forKey: "pomodoro_total_paused_time")
    }
    
    private func calculateBackgroundProgress() {
        let backgroundTimestamp = UserDefaults.standard.double(forKey: "pomodoro_background_timestamp")
        let savedTimeRemaining = UserDefaults.standard.double(forKey: "pomodoro_time_remaining")
        let savedStateRaw = UserDefaults.standard.string(forKey: "pomodoro_state") ?? ""
        
        guard backgroundTimestamp > 0, savedTimeRemaining > 0 else { return }
        
        let now = Date().timeIntervalSince1970
        let backgroundDuration = now - backgroundTimestamp
        
        // Calcola il nuovo tempo rimanente
        let newTimeRemaining = max(0, savedTimeRemaining - backgroundDuration)
        timeRemaining = newTimeRemaining
        
        // Controlla se la sessione dovrebbe essere completata
        if newTimeRemaining <= 0 {
            handleSessionCompletion()
        }
        
        // Pulisci i valori salvati
        UserDefaults.standard.removeObject(forKey: "pomodoro_background_timestamp")
        UserDefaults.standard.removeObject(forKey: "pomodoro_time_remaining")
        UserDefaults.standard.removeObject(forKey: "pomodoro_state")
        UserDefaults.standard.removeObject(forKey: "pomodoro_current_session")
    }
    
    private func handleSessionCompletion() {
        if state == .working {
            completeWorkSession()
        } else if state == .onBreak {
            completeBreakSession()
        }
    }
    
    private func restartTimerAfterBackground() {
        // Riavvia il timer con il tempo rimanente aggiornato
        timer?.cancel()
        startTimer()
    }
    
    private var stateRawValue: String {
        switch state {
        case .notStarted: return "notStarted"
        case .working: return "working"
        case .onBreak: return "onBreak"
        case .paused: return "paused"
        case .completed: return "completed"
        }
    }
    
    private func scheduleSessionEndNotification() async {
        // Remove existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard state == .working || state == .onBreak, timeRemaining > 0 else { return }
        
        let sessionType = state == .working ? "Work" : "Break"
        let taskName = activeTask?.name ?? "Focus Session"
        
        // Schedule notification for when current session ends
        let content = UNMutableNotificationContent()
        content.title = "\(sessionType) session completed!"
        content.body = state == .working ? 
            "Great job! Time for a break." : 
            "Break time is over. Ready to focus?"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pomodoro-complete-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        try? await UNUserNotificationCenter.current().add(request)
        
        if state == .working && currentSession < settings.totalSessions {
            let breakDuration = currentSession % settings.sessionsUntilLongBreak == 0 ? 
                settings.longBreakDuration : settings.breakDuration
            
            let nextWorkContent = UNMutableNotificationContent()
            nextWorkContent.title = "Break time over!"
            nextWorkContent.body = "Ready to start your next work session?"
            nextWorkContent.sound = .default
            
            let nextWorkTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeRemaining + breakDuration, 
                repeats: false
            )
            let nextWorkRequest = UNNotificationRequest(
                identifier: "pomodoro-next-work-\(UUID().uuidString)",
                content: nextWorkContent,
                trigger: nextWorkTrigger
            )
            
            try? await UNUserNotificationCenter.current().add(nextWorkRequest)
        }
    }
    
    var progress: Double {
        guard state != .notStarted && state != .completed else { return 0.0 }
        
        let total = state == .working ? settings.workDuration : 
                   (currentSession % settings.sessionsUntilLongBreak == 0 ? 
                    settings.longBreakDuration : settings.breakDuration)
        guard total > 0 else {
            Logger.pomodoro("Invalid timer duration configuration", level: .error)
            return 0
        }
        
        let currentSessionProgress = 1 - (timeRemaining / total)
        return max(0.0, min(1.0, currentSessionProgress))
    }
    
    var overallProgress: Double {
        guard state != .notStarted else { return 0.0 }
        
        let totalWorkTime = Double(settings.totalSessions) * settings.workDuration
        let completedWorkTime = Double(completedWorkSessions.count) * settings.workDuration
        
        // Add current session progress if working
        let currentProgress = state == .working ? progress * settings.workDuration : 0
        
        return min(1.0, (completedWorkTime + currentProgress) / totalWorkTime)
    }
    
    // Set active task and configure settings for task context
    func setActiveTask(_ task: TodoTask) {
        if activeTask?.id != task.id || state == .notStarted {
            // Stop current timer if running
            timer?.cancel()
            timer = nil
            
            self.activeTask = task
            self.context = .task
            
            // Use task-specific settings or default task settings
            let taskSettings = task.pomodoroSettings ?? settingsManager.taskSettings
            settingsManager.updateSettings(taskSettings, for: .task)
            
            self.timeRemaining = taskSettings.workDuration
            self.currentSession = 1
            self.completedWorkSessions = []
            self.completedBreakSessions = []
            self.state = .notStarted
            self.startDate = nil
            self.pausedTimeRemaining = nil
            self.pausedState = nil
            
            self.sessionStartTime = nil
            self.pauseStartTime = nil
            self.totalPausedTime = 0
        }
    }
    
    func initializeGeneralSession() {
        stop()
        self.activeTask = nil
        self.context = .general
        
        let generalSettings = settingsManager.generalSettings
        self.timeRemaining = generalSettings.workDuration
        self.currentSession = 1
        self.completedWorkSessions = []
        self.completedBreakSessions = []
        self.state = .notStarted
        self.startDate = nil
        self.pausedTimeRemaining = nil
        self.pausedState = nil
        
        self.sessionStartTime = nil
        self.pauseStartTime = nil
        self.totalPausedTime = 0
    }
    
    // Check if a specific task is the active one
    func isActiveTask(_ task: TodoTask) -> Bool {
        return activeTask?.id == task.id && (state != .notStarted || hasActiveTask)
    }
    
    // Check if a task is currently active
    var hasActiveTask: Bool {
        // Consider any running/paused Pomodoro session as active, even in general focus mode
        // This keeps the UI widgets and sheets visible when running without a specific task
        return (state == .working || state == .onBreak || state == .paused)
    }
    
    func start() {
        guard timer == nil else { return }
        
        if state == .paused {
            state = pausedState ?? .working
            if let pauseStart = pauseStartTime {
                totalPausedTime += Date().timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
        } else {
            state = .working
            sessionStartTime = Date()
            totalPausedTime = 0
        }
        
        startDate = Date()
        startTimer()
        
        Task {
            await scheduleSessionEndNotification()
        }
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateTimer()
                }
            }
    }
    
    func pause() {
        timer?.cancel()
        timer = nil
        pausedTimeRemaining = timeRemaining
        pausedState = state
        state = .paused
        
        pauseStartTime = Date()
        
        // Remove notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func resume() {
        guard state == .paused else { return }
        start()
    }
    
    func skip() {
        if state == .working {
            completedWorkSessions.insert(currentSession - 1)
            state = .onBreak
            timeRemaining = currentSession % settings.sessionsUntilLongBreak == 0 ?
                settings.longBreakDuration : settings.breakDuration
            
            sessionStartTime = Date()
            totalPausedTime = 0
            
            start()
        } else {
            completedBreakSessions.insert(currentSession - 1)
            completeBreakSession()
        }
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
        state = .notStarted
        timeRemaining = settings.workDuration
        currentSession = 1
        completedWorkSessions = []
        completedBreakSessions = []
        pausedState = nil
        pausedTimeRemaining = nil
        startDate = nil
        
        sessionStartTime = nil
        pauseStartTime = nil
        totalPausedTime = 0
        
        // Remove notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "pomodoro_background_timestamp")
        UserDefaults.standard.removeObject(forKey: "pomodoro_time_remaining")
        UserDefaults.standard.removeObject(forKey: "pomodoro_state")
        UserDefaults.standard.removeObject(forKey: "pomodoro_current_session")
    }
    
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
    
    private func completeWorkSession() {
        timer?.cancel()
        timer = nil
        
        completedWorkSessions.insert(currentSession - 1)
        
        // Use settings.totalSessions instead of hardcoded totalSessions
        if currentSession >= settings.totalSessions {
            state = .completed
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        state = .onBreak
        timeRemaining = currentSession % settings.sessionsUntilLongBreak == 0 ?
            settings.longBreakDuration : settings.breakDuration
        
        sessionStartTime = Date()
        totalPausedTime = 0
        
        startDate = Date()
        startTimer()
        
        Task {
            await scheduleSessionEndNotification()
        }
    }
    
    private func completeBreakSession() {
        timer?.cancel()
        timer = nil
        
        completedBreakSessions.insert(currentSession - 1)
        currentSession += 1
        
        // Use settings.totalSessions instead of hardcoded totalSessions
        if currentSession > settings.totalSessions {
            state = .completed
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        state = .working
        timeRemaining = settings.workDuration
        
        sessionStartTime = Date()
        totalPausedTime = 0
        
        startDate = Date()
        startTimer()
        
        Task {
            await scheduleSessionEndNotification()
        }
    }
    
    private func applySettingsToCurrentSession() {
        // If session hasn't started or is completed, update time remaining
        if state == .notStarted {
            timeRemaining = settings.workDuration
        } 
        // If currently working and progress is 0 (just started), update duration
        else if state == .working && progress < 0.01 {
            timeRemaining = settings.workDuration
        }
        // If on break and progress is 0 (just started break), update break duration
        else if state == .onBreak && progress < 0.01 {
            let isLongBreak = currentSession % settings.sessionsUntilLongBreak == 0
            timeRemaining = isLongBreak ? settings.longBreakDuration : settings.breakDuration
        }
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
        NotificationCenter.default.removeObserver(self)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Logger.pomodoro("PomodoroViewModel deinitialized", level: .info)
    }
}

// Extension to add Pomodoro-specific logging
extension Logger {
    static func pomodoro(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: level, subsystem: "pomodoro", file: file, function: function, line: line)
    }
}
