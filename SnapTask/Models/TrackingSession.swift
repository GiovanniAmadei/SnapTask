import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

enum DeviceType: String, Codable, CaseIterable {
    case iPhone = "iPhone"
    case iPad = "iPad"
    case mac = "Mac"
    case appleWatch = "Apple Watch"
    case unknown = "Unknown"
    
    var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .mac: return "Mac"
        case .appleWatch: return "Apple Watch"
        case .unknown: return "Unknown Device"
        }
    }
    
    var icon: String {
        switch self {
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .mac: return "desktopcomputer"
        case .appleWatch: return "applewatch"
        case .unknown: return "questionmark.circle"
        }
    }
    
    static var current: DeviceType {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #elseif os(macOS)
        return .mac
        #elseif os(watchOS)
        return .appleWatch
        #else
        return .unknown
        #endif
    }
}

struct TrackingSession: Identifiable, Codable {
    let id: UUID
    let taskId: UUID?
    let taskName: String?
    let mode: TrackingMode
    var categoryId: UUID?
    var categoryName: String?
    let startTime: Date
    let deviceType: DeviceType
    let deviceName: String
    let creationDate: Date
    var lastModifiedDate: Date
    
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
        self.deviceType = DeviceType.current
        self.deviceName = Self.getCurrentDeviceName()
        self.creationDate = Date()
        self.lastModifiedDate = Date()
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
        self.deviceType = DeviceType.current
        self.deviceName = Self.getCurrentDeviceName()
        self.creationDate = Date()
        self.lastModifiedDate = Date()
    }
    
    var effectiveWorkTime: TimeInterval {
        return totalDuration - pausedDuration
    }
    
    var isForSpecificTask: Bool {
        return taskId != nil
    }
    
    var deviceDisplayInfo: String {
        return "\(deviceType.displayName) · \(deviceName)"
    }
    
    mutating func complete() {
        isCompleted = true
        isRunning = false
        isPaused = false
        endTime = Date()
        totalDuration = elapsedTime
        lastModifiedDate = Date()
    }
    
    mutating func updateCategory(from task: TodoTask) {
        categoryId = task.category?.id
        categoryName = task.category?.name
        lastModifiedDate = Date()
        
        print("Updated tracking session category: \(categoryName ?? "No Category")")
    }
    
    static func getCurrentDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #else
        return "Unknown Device"
        #endif
    }
    
    enum CodingKeys: String, CodingKey {
        case id, taskId, taskName, mode, categoryId, categoryName, startTime
        case deviceType, deviceName, creationDate, lastModifiedDate
        case isRunning, isPaused, elapsedTime, totalDuration, pausedDuration
        case isCompleted, endTime, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        taskId = try container.decodeIfPresent(UUID.self, forKey: .taskId)
        taskName = try container.decodeIfPresent(String.self, forKey: .taskName)
        mode = try container.decode(TrackingMode.self, forKey: .mode)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        startTime = try container.decode(Date.self, forKey: .startTime)
        
        deviceType = try container.decodeIfPresent(DeviceType.self, forKey: .deviceType) ?? DeviceType.current
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? Self.getCurrentDeviceName()
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate) ?? startTime
        lastModifiedDate = try container.decodeIfPresent(Date.self, forKey: .lastModifiedDate) ?? startTime
        
        isRunning = try container.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        elapsedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedTime) ?? 0
        totalDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalDuration) ?? 0
        pausedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .pausedDuration) ?? 0
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}
