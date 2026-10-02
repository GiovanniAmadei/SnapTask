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
        didSet {
            // Only log real transitions (nil ↔ non-nil). Assigning `nil`
            // to an already-nil timer is a common idempotent code path
            // (e.g. `stop()` called on an already-stopped session) and
            // logging every one of those flooded the console.
            let wasNil = oldValue == nil
            let isNil = timer == nil
            guard wasNil != isNil else { return }
            Logger.pomodoro("Timer state updated: \(!isNil)", level: .debug)
        }
    }
    private var startDate: Date?
    private var pausedTimeRemaining: TimeInterval?
    
    @Published private var completedWorkSessions: Set<Int> = []
    @Published private var completedBreakSessions: Set<Int> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // Persistence keys
    private let persistedKey = "pomodoro_persisted_state"
    private struct PersistedState: Codable {
        let timestamp: TimeInterval
        let state: String
        let timeRemaining: TimeInterval
        let currentSession: Int
        let context: String
        let activeTaskId: String?
        let sessionStartTime: TimeInterval?
        let pauseStartTime: TimeInterval?
        let totalPausedTime: TimeInterval
    }
    
    // Helpers to encode/decode PomodoroContext since it has no rawValue
    private func encodeContext(_ ctx: PomodoroContext) -> String {
        switch ctx {
        case .general: return "general"
        case .task: return "task"
        }
    }
    private func decodeContext(_ string: String) -> PomodoroContext {
        return string == "task" ? .task : .general
    }
    
    private init() {
        self.timeRemaining = PomodoroSettings.defaultSettings.workDuration
        setupBackgroundHandling()
        restorePersistedStateIfNeeded()
        
        NotificationCenter.default.publisher(for: .pomodoroSettingsUpdated)
            // Defer to the next run-loop tick so we never re-enter a SwiftUI
            // update cycle (which was causing a feedback loop between
            // setActiveTask → updateSettings → sink → objectWillChange → body).
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                // Compare contexts explicitly: PomodoroContext is a Swift enum
                // bridged as `Any?` through NotificationCenter; the cast below
                // returns nil on older iOS versions in rare cases, so we also
                // accept a nil object as "any context" to stay permissive.
                guard let self else { return }
                let notifContext = notification.object as? PomodoroContext
                if notifContext == nil || notifContext == self.context {
                    self.applySettingsToCurrentSession()
                }
            }
            .store(in: &cancellables)
        
        // Forward settings-manager changes into this VM so any view that
        // observes the VM (e.g. session counter "2/6") re-renders as soon
        // as the user saves new settings — without this, the counter would
        // still say "2/4" until another @Published value changes.
        //
        // `receive(on: RunLoop.main)` is critical: forwarding
        // `objectWillChange` synchronously while SwiftUI is already updating
        // the body triggers "Publishing changes from within view updates" and,
        // combined with an `onAppear`-driven re-entry in `setActiveTask`,
        // produced an infinite loop of `timer = nil` assignments.
        settingsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
        persistState()
        
        // Programma notifica per la fine della sessione corrente
        Task {
            await scheduleSessionEndNotification()
        }
    }
    
    @objc private func appWillEnterForeground() {
        guard state == .working || state == .onBreak else { return }
        
        // Calcola il tempo trascorso in background
        calculateBackgroundProgress()
        persistState()
        
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

    private func persistState() {
        // Persist also when paused so we can resume later
        let payload = PersistedState(
            timestamp: Date().timeIntervalSince1970,
            state: stateRawValue,
            timeRemaining: timeRemaining,
            currentSession: currentSession,
            context: encodeContext(context),
            activeTaskId: activeTask?.id.uuidString,
            sessionStartTime: sessionStartTime?.timeIntervalSince1970,
            pauseStartTime: pauseStartTime?.timeIntervalSince1970,
            totalPausedTime: totalPausedTime
        )
        do {
            let data = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(data, forKey: persistedKey)
        } catch {
            Logger.pomodoro("Failed encoding persisted state: \(error)", level: .error)
        }
    }

    private func restorePersistedStateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: persistedKey) else { return }
        do {
            let saved = try JSONDecoder().decode(PersistedState.self, from: data)
            // Restore context
            if saved.context == "task",
               let idStr = saved.activeTaskId,
               let uuid = UUID(uuidString: idStr) {
                // Try to attach existing task
                if let task = TaskManager.shared.tasks.first(where: { $0.id == uuid }) {
                    self.activeTask = task
                    self.context = .task
                } else {
                    // Fallback to general if task not found
                    self.activeTask = nil
                    self.context = .general
                }
            } else {
                self.activeTask = nil
                self.context = decodeContext(saved.context)
            }
            
            self.currentSession = saved.currentSession
            self.totalPausedTime = saved.totalPausedTime
            self.sessionStartTime = saved.sessionStartTime != nil ? Date(timeIntervalSince1970: saved.sessionStartTime!) : nil
            self.pauseStartTime = saved.pauseStartTime != nil ? Date(timeIntervalSince1970: saved.pauseStartTime!) : nil
            
            // Map state
            self.state = PomodoroState(rawValue: saved.state) ?? .notStarted
            
            // If working/onBreak, compute elapsed time since saved timestamp
            let now = Date().timeIntervalSince1970
            let delta = max(0, now - saved.timestamp)
            if self.state == .working || self.state == .onBreak {
                let newRemaining = max(0, saved.timeRemaining - delta)
                self.timeRemaining = newRemaining
                if newRemaining <= 0 {
                    handleSessionCompletion()
                } else {
                    startDate = Date()
                    startTimer()
                    // Re-align Live Activity on app relaunch. The manager
                    // reattaches to an existing activity in its init, so
                    // calling start() here simply refreshes the endDate
                    // (or creates one if it was lost).
                    LiveActivityManager.shared.start(
                        taskName: activeTask?.name ?? "Focus Session",
                        categoryColorHex: activeTask?.category?.color,
                        categoryName: activeTask?.category?.name,
                        phase: liveActivityPhase,
                        timeRemaining: newRemaining,
                        phaseTotalDuration: currentLiveActivityPhaseDuration,
                        currentSession: currentSession,
                        totalSessions: settings.totalSessions
                    )
                }
            } else {
                // paused/notStarted/completed
                self.timeRemaining = saved.timeRemaining
                if self.state == .paused {
                    LiveActivityManager.shared.update(
                        phase: .paused,
                        timeRemaining: self.timeRemaining,
                        phaseTotalDuration: currentLiveActivityPhaseDuration,
                        currentSession: currentSession,
                        totalSessions: settings.totalSessions
                    )
                } else if self.state == .completed {
                    LiveActivityManager.shared.end(dismissImmediately: false)
                }
            }
        } catch {
            Logger.pomodoro("Failed decoding persisted state: \(error)", level: .error)
        }
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
    
    /// Current effective phase (working or onBreak), correctly resolved even when paused.
    var effectivePhase: PomodoroState {
        if state == .paused {
            return pausedState ?? .working
        }
        if state == .notStarted {
            return .working
        }
        return state
    }
    
    var isWorkingPhase: Bool {
        return effectivePhase == .working
    }
    
    /// Total focus time accumulated so far across full completed sessions plus the current in-flight work session.
    var totalTrackedFocusTime: TimeInterval {
        let fullCompletedTime = Double(completedWorkSessions.count) * settings.workDuration
        let currentSessionWorkTime: TimeInterval
        if effectivePhase == .working {
            currentSessionWorkTime = max(0, settings.workDuration - timeRemaining)
        } else {
            // If on break, the work portion of this session is already accounted for in completedWorkSessions
            currentSessionWorkTime = 0
        }
        return fullCompletedTime + currentSessionWorkTime
    }
    
    var progress: Double {
        guard state != .notStarted && state != .completed else { return 0.0 }
        
        let isWork = effectivePhase == .working
        let divisor = max(1, settings.sessionsUntilLongBreak)
        let total = isWork ? settings.workDuration : 
                   (currentSession % divisor == 0 ? 
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
        guard totalWorkTime > 0 else { return 0.0 }
        let completedWorkTime = Double(completedWorkSessions.count) * settings.workDuration
        
        // Add current session progress if in working phase (even if paused)
        let currentProgress = effectivePhase == .working ? progress * settings.workDuration : 0
        
        return min(1.0, (completedWorkTime + currentProgress) / totalWorkTime)
    }
    
    // Set active task and configure settings for task context
    func setActiveTask(_ task: TodoTask) {
        // Bail out when the task is already the active one.
        //
        // Important: we do NOT also reset on `state == .notStarted` here.
        // That condition caused an infinite loop because
        // `PomodoroView.onAppear` uses `isActiveTask(task)` which in turn
        // requires `state != .notStarted` — so right after `setActiveTask`
        // (which leaves state == .notStarted) any re-evaluation of
        // `onAppear` would call `setActiveTask` again, firing all the
        // @Published setters and re-entering the update cycle.
        guard activeTask?.id != task.id else { return }
        
        // Stop current timer and tear down any in-flight Live Activity:
        // it was referring to the previous task so the user-visible name
        // and color are now stale.
        timer?.cancel()
        timer = nil
        LiveActivityManager.shared.end(dismissImmediately: true)
        
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
        persistState()
    }
    
    func initializeGeneralSession() {
        // Idempotent: once we're already in a fresh general-context
        // session there's nothing to do. Re-running this would reset
        // every @Published value and trigger another round of SwiftUI
        // updates — which, combined with `PomodoroTabView.onAppear` that
        // calls this method, produced the `timer = nil` freeze loop.
        if context == .general
            && state == .notStarted
            && activeTask == nil
            && currentSession == 1
            && completedWorkSessions.isEmpty
            && completedBreakSessions.isEmpty {
            return
        }
        
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
        persistState()
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
        
        let wasPaused = (state == .paused)
        
        if wasPaused {
            state = pausedState ?? .working
            if let pauseStart = pauseStartTime {
                totalPausedTime += Date().timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
        } else {
            state = .working
            sessionStartTime = Date()
            totalPausedTime = 0
            if let taskId = activeTask?.id {
                TaskManager.shared.markStartedIfNeeded(taskId)
            }
        }
        
        startDate = Date()
        startTimer()
        
        Task {
            await scheduleSessionEndNotification()
        }
        
        // Live Activity: start fresh or resume from paused
        if wasPaused {
            LiveActivityManager.shared.update(
                phase: liveActivityPhase,
                timeRemaining: timeRemaining,
                phaseTotalDuration: currentLiveActivityPhaseDuration,
                currentSession: currentSession,
                totalSessions: settings.totalSessions
            )
        } else {
            LiveActivityManager.shared.start(
                taskName: activeTask?.name ?? "Focus Session",
                categoryColorHex: activeTask?.category?.color,
                categoryName: activeTask?.category?.name,
                phase: liveActivityPhase,
                timeRemaining: timeRemaining,
                phaseTotalDuration: currentLiveActivityPhaseDuration,
                currentSession: currentSession,
                totalSessions: settings.totalSessions
            )
        }
        
        persistState()
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
        
        LiveActivityManager.shared.update(
            phase: .paused,
            timeRemaining: timeRemaining,
            phaseTotalDuration: currentLiveActivityPhaseDuration,
            currentSession: currentSession,
            totalSessions: settings.totalSessions
        )
        
        persistState()
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
            
            // start() bails out early because the timer is already running;
            // update the Live Activity explicitly so the phase/endDate
            // reflect the new break window.
            LiveActivityManager.shared.update(
                phase: .onBreak,
                timeRemaining: timeRemaining,
                phaseTotalDuration: currentLiveActivityPhaseDuration,
                currentSession: currentSession,
                totalSessions: settings.totalSessions
            )
            
            start()
        } else {
            completedBreakSessions.insert(currentSession - 1)
            completeBreakSession()
        }
        persistState()
    }
    
    func stop() {
        // Idempotent: if we're already fully stopped, don't re-publish a
        // bunch of @Published values (which would kick off another SwiftUI
        // update cycle and, combined with certain `onAppear` hooks, cause
        // a feedback loop).
        if state == .notStarted
            && timer == nil
            && currentSession == 1
            && completedWorkSessions.isEmpty
            && completedBreakSessions.isEmpty
            && pausedState == nil {
            return
        }
        
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
        
        // End Live Activity
        LiveActivityManager.shared.end(dismissImmediately: true)
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "pomodoro_background_timestamp")
        UserDefaults.standard.removeObject(forKey: "pomodoro_time_remaining")
        UserDefaults.standard.removeObject(forKey: "pomodoro_state")
        UserDefaults.standard.removeObject(forKey: "pomodoro_current_session")
        UserDefaults.standard.removeObject(forKey: persistedKey)
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
            LiveActivityManager.shared.end(dismissImmediately: false)
            // Clear persisted state when cycle is completed
            UserDefaults.standard.removeObject(forKey: persistedKey)
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
        
        // Transition Live Activity to break phase
        LiveActivityManager.shared.update(
            phase: .onBreak,
            timeRemaining: timeRemaining,
            phaseTotalDuration: currentLiveActivityPhaseDuration,
            currentSession: currentSession,
            totalSessions: settings.totalSessions
        )
        
        // Persist after transitioning to break
        persistState()
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
            LiveActivityManager.shared.end(dismissImmediately: false)
            // Clear persisted state when cycle is completed
            UserDefaults.standard.removeObject(forKey: persistedKey)
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
        
        // Transition Live Activity back to working phase
        LiveActivityManager.shared.update(
            phase: .working,
            timeRemaining: timeRemaining,
            phaseTotalDuration: currentLiveActivityPhaseDuration,
            currentSession: currentSession,
            totalSessions: settings.totalSessions
        )
        
        // Persist after transitioning back to work
        persistState()
    }
    
    private func applySettingsToCurrentSession() {
        // Keep currentSession inside the new valid range. If the user
        // lowered totalSessions below the in-flight session, clamp it so
        // the UI and Live Activity stay consistent.
        let newTotal = max(1, settings.totalSessions)
        if currentSession > newTotal {
            currentSession = newTotal
        }
        
        // If session hasn't started or is completed, update time remaining
        switch state {
        case .notStarted:
            timeRemaining = settings.workDuration
        case .working where progress < 0.01:
            // Just started working — safe to apply new work duration.
            timeRemaining = settings.workDuration
        case .onBreak where progress < 0.01:
            // Just started the break — safe to apply new break duration.
            let divisor = max(1, settings.sessionsUntilLongBreak)
            let isLongBreak = currentSession % divisor == 0
            timeRemaining = isLongBreak ? settings.longBreakDuration : settings.breakDuration
        default:
            // Mid-session: do NOT reset timeRemaining (it would be jarring
            // to the user). Just let the new totals propagate to the UI.
            break
        }
        
        // Keep the Live Activity session totals in sync so the Dynamic
        // Island progress bar matches the new configuration.
        if state == .working || state == .onBreak || state == .paused {
            LiveActivityManager.shared.update(
                phase: liveActivityPhase,
                timeRemaining: timeRemaining,
                phaseTotalDuration: currentLiveActivityPhaseDuration,
                currentSession: currentSession,
                totalSessions: newTotal
            )
        }
        
        persistState()
    }
    
    private var pausedState: PomodoroState?
    
    /// Map internal Pomodoro state to the Live Activity phase.
    private var liveActivityPhase: PomodoroActivityAttributes.ContentState.Phase {
        switch state {
        case .working:
            return .working
        case .onBreak:
            return .onBreak
        case .paused:
            return .paused
        case .notStarted, .completed:
            return .working
        }
    }
    
    private var currentLiveActivityPhaseDuration: TimeInterval {
        let divisor = max(1, settings.sessionsUntilLongBreak)

        switch state {
        case .working:
            return settings.workDuration
        case .onBreak:
            return currentSession % divisor == 0 ? settings.longBreakDuration : settings.breakDuration
        case .paused:
            switch pausedState {
            case .onBreak:
                return currentSession % divisor == 0 ? settings.longBreakDuration : settings.breakDuration
            case .working, .paused, .notStarted, .completed, .none:
                return settings.workDuration
            }
        case .notStarted, .completed:
            return settings.workDuration
        }
    }

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
