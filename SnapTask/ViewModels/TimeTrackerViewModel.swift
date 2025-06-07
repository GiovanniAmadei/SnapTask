import Foundation
import Combine

@MainActor
class TimeTrackerViewModel: ObservableObject {
    static let shared = TimeTrackerViewModel(taskManager: TaskManager.shared)
    
    @Published var activeSessions: [TrackingSession] = []
    @Published var showingCompletion = false
    @Published var completedSession: TrackingSession?
    @Published var currentSessionId: UUID?
    
    private var timers: [UUID: Timer] = [:]
    private let taskManager: TaskManager
    
    init(taskManager: TaskManager) {
        self.taskManager = taskManager
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
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let sessionIndex = self.activeSessions.firstIndex(where: { $0.id == sessionId }),
                   self.activeSessions[sessionIndex].isRunning && !self.activeSessions[sessionIndex].isPaused {
                    self.activeSessions[sessionIndex].elapsedTime += 1
                }
            }
        }
        
        timers[sessionId] = timer
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
    }
    
    // Resume specific session
    func resumeSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        activeSessions[index].isPaused = false
    }
    
    // Stop and complete specific session
    func stopSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        
        var session = activeSessions[index]
        session.complete()
        
        // Stop timer
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        
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
        guard let session = completedSession else { return }
        
        // Save to task manager
        taskManager.saveTrackingSession(session)
        
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
    }
}
