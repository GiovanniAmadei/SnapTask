import Foundation
import os.log

enum LogLevel: Int {
    case debug = 0
    case info
    case warning
    case error
    
    var description: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARNING"
        case .error: return "🔴 ERROR"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

class Logger {
    // Shared instance
    static let shared = Logger()
    
    // Categories for logs
    private var subsystems: [String: OSLog] = [:]
    
    // Minimum log level to display
    #if DEBUG
    private var minimumLogLevel: LogLevel = .debug
    #else
    private var minimumLogLevel: LogLevel = .info
    #endif
    
    private init() {
        // Default subsystems
        registerSubsystem(name: "app", description: "General application logs")
        registerSubsystem(name: "network", description: "Network operations")
        registerSubsystem(name: "data", description: "Data operations")
        registerSubsystem(name: "ui", description: "User Interface")
        registerSubsystem(name: "watch", description: "Watch connectivity")
    }
    
    // Register a new subsystem
    func registerSubsystem(name: String, description: String) {
        subsystems[name] = OSLog(subsystem: "com.example.snaptask.\(name)", category: description)
    }
    
    // Set minimum log level
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }
    
    // Main logging function
    func log(_ message: String, level: LogLevel = .debug, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
        // Check if we should log this level
        guard level.rawValue >= minimumLogLevel.rawValue else { return }
        
        // Get the subsystem or use default
        let logSystem = subsystems[subsystem] ?? subsystems["app"]!
        
        // Format the message with file and line info for debug builds
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        #else
        let formattedMessage = message
        #endif
        
        // Log using os_log
        os_log("%{public}@", log: logSystem, type: level.osLogType, formattedMessage)
        
        // Also print to console for easier debugging
        #if DEBUG
        print("\(level.description) [\(subsystem)] - \(formattedMessage)")
        #endif
    }
    
    // Convenience methods
    func debug(_ message: String, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, subsystem: subsystem, file: file, function: function, line: line)
    }
    
    func info(_ message: String, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, subsystem: subsystem, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, subsystem: subsystem, file: file, function: function, line: line)
    }
    
    func error(_ message: String, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, subsystem: subsystem, file: file, function: function, line: line)
    }
}

// Global shorthand function
func Log(_ message: String, level: LogLevel = .debug, subsystem: String = "app", file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: level, subsystem: subsystem, file: file, function: function, line: line)
} 