import Foundation

struct TrackingSession: Identifiable, Codable {
    let id = UUID()
    let taskId: UUID?
    let taskName: String?
    let mode: TrackingMode
    let categoryId: UUID?
    let categoryName: String?
    let startTime: Date
    
    var isRunning: Bool = false
    var isPaused: Bool = false
    var elapsedTime: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    var pausedDuration: TimeInterval = 0
    var isCompleted: Bool = false
    var endTime: Date?
    var notes: String?
    
    init(taskId: UUID? = nil, taskName: String? = nil, mode: TrackingMode, categoryId: UUID? = nil, categoryName: String? = nil) {
        self.taskId = taskId
        self.taskName = taskName
        self.mode = mode
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.startTime = Date()
    }
    
    var effectiveWorkTime: TimeInterval {
        return totalDuration - pausedDuration
    }
    
    var isForSpecificTask: Bool {
        return taskId != nil
    }
    
    mutating func complete() {
        isCompleted = true
        isRunning = false
        isPaused = false
        endTime = Date()
        totalDuration = elapsedTime
    }
}
