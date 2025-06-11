import Foundation

struct TrackingSession: Identifiable, Codable {
    let id: UUID
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
        self.id = UUID()
        self.taskId = taskId
        self.taskName = taskName
        self.mode = mode
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.startTime = Date()
    }
    
    init(id: UUID, taskId: UUID?, taskName: String?, mode: TrackingMode, categoryId: UUID?, categoryName: String?, startTime: Date, elapsedTime: TimeInterval, isRunning: Bool, isPaused: Bool) {
        self.id = id
        self.taskId = taskId
        self.taskName = taskName
        self.mode = mode
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.startTime = startTime
        self.elapsedTime = elapsedTime
        self.isRunning = isRunning
        self.isPaused = isPaused
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
