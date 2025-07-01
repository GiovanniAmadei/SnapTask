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
    
    init(taskManager: TaskManager) {
        self.taskManager = taskManager
        setupBackgroundHandling()
        restoreSessionStates()
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
        // Salva timestamp per ogni sessione attiva
        for session in activeSessions {
            if session.isRunning && !session.isPaused {
                backgroundTimestamps[session.id] = Date()
                saveSessionState(session)
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Calcola tempo trascorso per ogni sessione
        for i in activeSessions.indices {
            let session = activeSessions[i]
            if session.isRunning && !session.isPaused,
               let backgroundStart = backgroundTimestamps[session.id] {
                
                let backgroundDuration = Date().timeIntervalSince(backgroundStart)
                activeSessions[i].elapsedTime += backgroundDuration
                
                // Riavvia timer per questa sessione
                restartTimer(for: session.id)
            }
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
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let sessionIndex = self.activeSessions.firstIndex(where: { $0.id == sessionId }),
                   self.activeSessions[sessionIndex].isRunning && !self.activeSessions[sessionIndex].isPaused {
                    self.activeSessions[sessionIndex].elapsedTime += 1
                    
                    // Aggiorna stato salvato ogni 10 secondi
                    if Int(self.activeSessions[sessionIndex].elapsedTime) % 10 == 0 {
                        self.saveSessionState(self.activeSessions[sessionIndex])
                    }
                }
            }
        }
        
        timers[sessionId] = timer
    }
    
    var hasActiveSession: Bool {
        return !activeSessions.isEmpty
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
    
    // Start a new session
    func startSession(for task: TodoTask?, mode: TrackingMode) -> UUID {
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
        
        saveSessionState(activeSessions[index])
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
        
        var session = activeSessions[index]
        session.complete()
        
        // Stop timer
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        
        let key = "timer_session_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // Remove from active sessions
        activeSessions.remove(at: index)
        
        // Clear current session if it was this one
        if currentSessionId == id {
            currentSessionId = activeSessions.first?.id
        }
        
        // Set as completed session for completion view
        completedSession = session
        showingCompletion = true
    }
    
    // Save specific session
    func saveSession(id: UUID) {
        guard var session = completedSession else { return }
        
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
        
        // Let TimeTrackingCompletionView handle the actual saving based on user selection
        
        // Update task's tracked time if it's task-specific
        if let taskId = session.taskId {
            taskManager.addTrackedTime(session.effectiveWorkTime, to: taskId)
        }
        
        // Clear completed session
        completedSession = nil
        showingCompletion = false
    }
    
    // Discard specific session
    func discardSession(id: UUID) {
        completedSession = nil
        showingCompletion = false
    }
    
    // Remove session without completion (force stop)
    func removeSession(id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        activeSessions.removeAll { $0.id == id }
        
        let key = "timer_session_\(id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        
        // Clear current session if it was this one
        if currentSessionId == id {
            currentSessionId = activeSessions.first?.id
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
        NotificationCenter.default.removeObserver(self)
        Task {
            await cleanupSessionStates()
        }
    }
}
