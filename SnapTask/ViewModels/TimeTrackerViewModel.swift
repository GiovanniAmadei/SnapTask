import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
class TimeTrackerViewModel: ObservableObject {
    static let shared = TimeTrackerViewModel(taskManager: TaskManager.shared)
    
    @Published var activeSessions: [TrackingSession] = []
    @Published var showingCompletion = false
    @Published var completedSession: TrackingSession?
    @Published var currentSessionId: UUID?
    
    private var timers: [UUID: Timer] = [:]
    private let taskManager: TaskManager
    
    private var backgroundTimestamps: [UUID: Date] = [:]
    
    /// Timestamp of the last tick for each running session. Used to compute
    /// the real delta between ticks so we don't lose time when the run
    /// loop is busy and a Timer fires later than scheduled.
    private var lastTickDates: [UUID: Date] = [:]
    
    init(taskManager: TaskManager) {
        self.taskManager = taskManager
        setupBackgroundHandling()
        restoreSessionStates()
    }
    
    private func setupBackgroundHandling() {
        // `didEnterBackground` fires when the app is fully backgrounded.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // `willResignActive` fires earlier — e.g. on iPad split-view focus
        // change or incoming call — so we save here too as a safety net.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
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
        // Salva timestamp per ogni sessione attiva
        let now = Date()
        for session in activeSessions where session.isRunning && !session.isPaused {
            backgroundTimestamps[session.id] = now
            saveSessionState(session)
        }
    }
    
    @objc private func appWillResignActive() {
        // Save early so a crash / force-quit from the app switcher doesn't
        // lose progress. We don't touch `backgroundTimestamps` here — the
        // timer keeps firing while the app is merely inactive.
        for session in activeSessions where session.isRunning && !session.isPaused {
            saveSessionState(session)
        }
    }
    
    @objc private func appWillEnterForeground() {
        let now = Date()
        // Calcola tempo trascorso per ogni sessione
        for i in activeSessions.indices {
            let session = activeSessions[i]
            guard session.isRunning && !session.isPaused,
                  let backgroundStart = backgroundTimestamps[session.id] else { continue }
            
            let backgroundDuration = now.timeIntervalSince(backgroundStart)
            activeSessions[i].elapsedTime += backgroundDuration
            
            // Riavvia timer per questa sessione — reset del lastTickDate
            // così il prossimo tick non conteggia di nuovo il delta background.
            lastTickDates[session.id] = now
            restartTimer(for: session.id)
        }
        
        // Pulisci timestamps
        backgroundTimestamps.removeAll()
        Task {
            await cleanupSessionStates()
        }
    }
    
    private func saveSessionState(_ session: TrackingSession) {
        let key = "timer_session_\(session.id.uuidString)"
        let sessionData: [String: Any] = [
            "id": session.id.uuidString,
            "taskId": session.taskId?.uuidString ?? "",
            "taskName": session.taskName ?? "",
            "elapsedTime": session.elapsedTime,
            "isRunning": session.isRunning,
            "isPaused": session.isPaused,
            "startTime": session.startTime.timeIntervalSince1970,
            "mode": session.mode.rawValue,
            "categoryId": session.categoryId?.uuidString ?? "",
            "categoryName": session.categoryName ?? "",
            "backgroundTimestamp": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(sessionData, forKey: key)
    }
    
    private func restoreSessionStates() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("timer_session_") }
        
        for key in keys {
            if let sessionData = userDefaults.dictionary(forKey: key),
               let sessionIdString = sessionData["id"] as? String,
               let sessionId = UUID(uuidString: sessionIdString),
               let isRunning = sessionData["isRunning"] as? Bool,
               let isPaused = sessionData["isPaused"] as? Bool,
               let elapsedTime = sessionData["elapsedTime"] as? TimeInterval,
               let startTimeInterval = sessionData["startTime"] as? TimeInterval,
               let modeRaw = sessionData["mode"] as? String,
               let mode = TrackingMode(rawValue: modeRaw),
               let backgroundTimestamp = sessionData["backgroundTimestamp"] as? TimeInterval {
                
                // Calcola tempo trascorso in background
                let now = Date().timeIntervalSince1970
                let backgroundDuration = now - backgroundTimestamp
                let updatedElapsedTime = isRunning && !isPaused ? elapsedTime + backgroundDuration : elapsedTime
                
                let taskId = sessionData["taskId"] as? String != "" ? UUID(uuidString: sessionData["taskId"] as? String ?? "") : nil
                let categoryId = sessionData["categoryId"] as? String != "" ? UUID(uuidString: sessionData["categoryId"] as? String ?? "") : nil
                
                var session = TrackingSession(
                    id: sessionId,
                    taskId: taskId,
                    taskName: sessionData["taskName"] as? String,
                    mode: mode,
                    categoryId: categoryId,
                    categoryName: sessionData["categoryName"] as? String,
                    startTime: Date(timeIntervalSince1970: startTimeInterval),
                    elapsedTime: updatedElapsedTime,
                    isRunning: isRunning,
                    isPaused: isPaused
                )
                
                activeSessions.append(session)
                
                // Riavvia timer se necessario
                if isRunning && !isPaused {
                    startTimer(for: sessionId)
                }
            }
        }
        
        // Imposta currentSessionId se non è settato
        if currentSessionId == nil {
            currentSessionId = activeSessions.first?.id
        }
        
        // FIXED: Pulisci le sessioni "fantasma" - sessioni che non hanno mai avuto tempo tracciato
        // e non sono mai state avviate
        activeSessions.removeAll { session in
            session.elapsedTime == 0 && !session.isRunning && !session.isPaused
        }
        
        // Pulisci i dati salvati dopo il ripristino per evitare accumuli
        Task {
            await cleanupSessionStates()
        }
    }
    
    private func cleanupSessionStates() async {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("timer_session_") }
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    private func restartTimer(for sessionId: UUID) {
        // Ferma timer esistente se presente
        timers[sessionId]?.invalidate()
        if lastTickDates[sessionId] == nil {
            lastTickDates[sessionId] = Date()
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let idx = self.activeSessions.firstIndex(where: { $0.id == sessionId }) else {
                    // Session removed externally — clean up.
                    self.timers[sessionId]?.invalidate()
                    self.timers.removeValue(forKey: sessionId)
                    self.lastTickDates.removeValue(forKey: sessionId)
                    return
                }
                guard self.activeSessions[idx].isRunning,
                      !self.activeSessions[idx].isPaused else { return }
                
                // Use real wall-clock delta instead of hard-coded 1s to
                // compensate for timer drift when the run loop is busy.
                let now = Date()
                let last = self.lastTickDates[sessionId] ?? now
                let delta = max(0, now.timeIntervalSince(last))
                self.lastTickDates[sessionId] = now
                self.activeSessions[idx].elapsedTime += delta
                
                // Persist every ~10 seconds of elapsed time.
                if Int(self.activeSessions[idx].elapsedTime) % 10 == 0 {
                    self.saveSessionState(self.activeSessions[idx])
                }
            }
        }
        // Use a slight tolerance so iOS can coalesce firings (lower power cost).
        timer.tolerance = 0.1
        timers[sessionId] = timer
    }
    
    var hasActiveSession: Bool {
        return activeSessions.contains { session in
            session.isRunning || session.elapsedTime > 0 || session.isPaused
        }
    }
    
    var activeTask: TodoTask? {
        // Return the most recently started session's task
        guard let latestSession = activeSessions.max(by: { $0.startTime < $1.startTime }),
              let taskId = latestSession.taskId else { return nil }
        return taskManager.tasks.first { $0.id == taskId }
    }
    
    // Backward compatibility properties for single session use
    var currentSession: TrackingSession? {
        guard let sessionId = currentSessionId else {
            return activeSessions.first
        }
        return activeSessions.first { $0.id == sessionId }
    }
    
    var isRunning: Bool {
        return currentSession?.isRunning ?? false
    }
    
    var isPaused: Bool {
        return currentSession?.isPaused ?? false
    }
    
    var formattedElapsedTime: String {
        guard let session = currentSession else { return "00:00" }
        return formattedElapsedTime(for: session.id)
    }
    
    var sessionTitle: String {
        guard let session = currentSession else { return "Focus Session" }
        return sessionTitle(for: session.id)
    }
    
    // Get session by ID
    func getSession(id: UUID) -> TrackingSession? {
        return activeSessions.first { $0.id == id }
    }
    
    // Start a new session or return existing active session
    func startSession(for task: TodoTask?, mode: TrackingMode) -> UUID {
        if let taskId = task?.id,
           let existing = activeSessions.first(where: { $0.taskId == taskId }) {
            currentSessionId = existing.id
            return existing.id
        }
        
        if mode == .simple && activeSessions.count >= 2 {
            // Return first session ID if limit reached
            return activeSessions.first?.id ?? UUID()
        }
        
        let session = TrackingSession(
            taskId: task?.id,
            taskName: task?.name,
            mode: mode,
            categoryId: task?.category?.id,
            categoryName: task?.category?.name
        )
        
        activeSessions.append(session)
        currentSessionId = session.id
        
        saveSessionState(session)
        
        return session.id
    }
    
    func startGeneralSession(mode: TrackingMode, categoryName: String? = nil) -> UUID {
        if let existing = activeSessions.first(where: { $0.taskId == nil }) {
            currentSessionId = existing.id
            return existing.id
        }
        
        if mode == .simple && activeSessions.count >= 2 {
            // Return first session ID if limit reached
            return activeSessions.first?.id ?? UUID()
        }
        
        let session = TrackingSession(
            mode: mode,
            categoryName: categoryName
        )
        
        activeSessions.append(session)
        currentSessionId = session.id
        
        saveSessionState(session)
        
        return session.id
    }
    
    // Start timer session (convenience method)
    func startTimerSession() {
        guard let sessionId = currentSessionId else { return }
        startTimer(for: sessionId)
    }
    
    // Start timer for specific session
    func startTimer(for sessionId: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        activeSessions[index].isRunning = true
        activeSessions[index].isPaused = false
        
        restartTimer(for: sessionId)
        
        // Salva stato aggiornato
        saveSessionState(activeSessions[index])
        
        // Live Activity
        let session = activeSessions[index]
        let task = session.taskId != nil ? taskManager.tasks.first(where: { $0.id == session.taskId }) : nil
        let startDate = Date().addingTimeInterval(-session.elapsedTime)
        LiveActivityManager.shared.startSimpleTimer(
            taskName: session.taskName ?? task?.name ?? "Focus Session",
            categoryColorHex: task?.category?.color,
            categoryName: task?.category?.name ?? session.categoryName,
            startDate: startDate,
            isPaused: false,
            elapsedTime: session.elapsedTime
        )
    }
    
    // Pause current session (convenience method)
    func pauseSession() {
        guard let sessionId = currentSessionId else { return }
        pauseSession(id: sessionId)
    }
    
    // Resume current session (convenience method)
    func resumeSession() {
        guard let sessionId = currentSessionId else { return }
        resumeSession(id: sessionId)
    }
    
    // Stop current session (convenience method)
    func stopSession() {
        guard let sessionId = currentSessionId else { return }
        stopSession(id: sessionId)
    }
    
    // Save current session (convenience method)
    func saveSession() {
        guard let sessionId = currentSessionId else { return }
        saveSession(id: sessionId)
    }
    
    // Discard current session (convenience method)
    func discardSession() {
        guard let sessionId = currentSessionId else { return }
        discardSession(id: sessionId)
    }
    
    // Pause specific session
    func pauseSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        activeSessions[index].isPaused = true
        
        // Pause timer
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        lastTickDates.removeValue(forKey: id)
        
        saveSessionState(activeSessions[index])
        
        let session = activeSessions[index]
        let startDate = Date().addingTimeInterval(-session.elapsedTime)
        LiveActivityManager.shared.updateSimpleTimer(
            startDate: startDate,
            isPaused: true,
            elapsedTime: session.elapsedTime
        )
    }
    
    // Resume specific session  
    func resumeSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        activeSessions[index].isPaused = false
        startTimer(for: id)
    }
    
    // Stop and complete specific session
    func stopSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        
        // Stop timer first so elapsedTime stops incrementing
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        lastTickDates.removeValue(forKey: id)
        
        // Snapshot current state, mark as complete (sets totalDuration = elapsedTime)
        var session = activeSessions[index]
        session.complete()
        activeSessions[index] = session
        
        saveSessionState(activeSessions[index])
        
        let startDate = Date().addingTimeInterval(-session.elapsedTime)
        LiveActivityManager.shared.updateSimpleTimer(
            startDate: startDate,
            isPaused: true,
            elapsedTime: session.elapsedTime
        )
        
        // Set as completed session for completion view
        completedSession = session
        showingCompletion = true
    }
    
    // Save specific session
    func saveSession(id: UUID) {
        guard var session = completedSession ?? getSession(id: id) else { return }
        
        // IMPORTANT: Always use current task data for category tracking, not captured data
        // If this is a task-specific session, get the current task data
        if let taskId = session.taskId,
           let currentTask = taskManager.tasks.first(where: { $0.id == taskId }) {
            
            print("🔄 Updating session category from captured to current task state")
            print("   Session had: categoryId=\(session.categoryId?.uuidString.prefix(8) ?? "nil"), categoryName=\(session.categoryName ?? "nil")")
            print("   Current task: categoryId=\(currentTask.category?.id.uuidString.prefix(8) ?? "nil"), categoryName=\(currentTask.category?.name ?? "nil")")
            
            // Update session with current task category (not captured category)
            session.categoryId = currentTask.category?.id
            session.categoryName = currentTask.category?.name
            
            print("   Updated session: categoryId=\(session.categoryId?.uuidString.prefix(8) ?? "nil"), categoryName=\(session.categoryName ?? "nil")")
        }
        
        // Update task's tracked time if it's task-specific
        if let taskId = session.taskId {
            taskManager.addTrackedTime(session.effectiveWorkTime, to: taskId)
        }
        
        // Stop and remove from active sessions now that it is saved
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        lastTickDates.removeValue(forKey: id)
        
        let key = "timer_session_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        
        activeSessions.removeAll { $0.id == id }
        if currentSessionId == id {
            currentSessionId = activeSessions.first?.id
        }
        
        if activeSessions.isEmpty || !hasActiveSession {
            LiveActivityManager.shared.end(dismissImmediately: true)
        }
        
        // Clear completed session
        completedSession = nil
        showingCompletion = false
    }
    
    // Discard specific session
    func discardSession(id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        lastTickDates.removeValue(forKey: id)
        
        let key = "timer_session_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        
        activeSessions.removeAll { $0.id == id }
        if currentSessionId == id {
            currentSessionId = activeSessions.first?.id
        }
        
        if activeSessions.isEmpty || !hasActiveSession {
            LiveActivityManager.shared.end(dismissImmediately: true)
        }
        
        completedSession = nil
        showingCompletion = false
    }
    
    // Remove session without completion (force stop)
    func removeSession(id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        lastTickDates.removeValue(forKey: id)
        activeSessions.removeAll { $0.id == id }
        
        let key = "timer_session_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // Clear current session if it was this one
        if currentSessionId == id {
            currentSessionId = activeSessions.first?.id
        }
        
        if activeSessions.isEmpty || !hasActiveSession {
            LiveActivityManager.shared.end(dismissImmediately: true)
        }
    }
    
    // Get formatted time for specific session
    func formattedElapsedTime(for sessionId: UUID) -> String {
        guard let session = activeSessions.first(where: { $0.id == sessionId }) else { return "00:00" }
        
        let elapsedTime = session.elapsedTime
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Get session title
    func sessionTitle(for sessionId: UUID) -> String {
        guard let session = activeSessions.first(where: { $0.id == sessionId }) else { return "Unknown Session" }
        return session.taskName ?? "Focus Session"
    }
    
    deinit {
        timers.values.forEach { $0.invalidate() }
        // `NotificationCenter` removes observers automatically on iOS 9+,
        // but explicit removal is still safer when mixing selector-based
        // observers with Combine cancellables.
        NotificationCenter.default.removeObserver(self)
        // Don't spawn a Task capturing `self` here — it's already being
        // torn down. Clean up synchronously instead.
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("timer_session_") }
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}