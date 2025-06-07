import Foundation
import SwiftUI

class PomodoroSettingsManager: ObservableObject {
    static let shared = PomodoroSettingsManager()
    
    // Separate settings for different contexts
    @AppStorage("generalPomodoroSettings") private var generalSettingsData: Data = Data()
    @AppStorage("taskPomodoroSettings") private var taskSettingsData: Data = Data()
    
    @Published var generalSettings: PomodoroSettings {
        didSet {
            saveGeneralSettings()
        }
    }
    
    @Published var taskSettings: PomodoroSettings {
        didSet {
            saveTaskSettings()
        }
    }
    
    private init() {
        // Load or create default settings
        self.generalSettings = PomodoroSettingsManager.loadGeneralSettings()
        self.taskSettings = PomodoroSettingsManager.loadTaskSettings()
    }
    
    private static func loadGeneralSettings() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: "generalPomodoroSettings"),
              let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else {
            return PomodoroSettings.defaultSettings
        }
        return settings
    }
    
    private static func loadTaskSettings() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: "taskPomodoroSettings"),
              let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else {
            return PomodoroSettings.defaultSettings
        }
        return settings
    }
    
    private func saveGeneralSettings() {
        if let data = try? JSONEncoder().encode(generalSettings) {
            UserDefaults.standard.set(data, forKey: "generalPomodoroSettings")
        }
    }
    
    private func saveTaskSettings() {
        if let data = try? JSONEncoder().encode(taskSettings) {
            UserDefaults.standard.set(data, forKey: "taskPomodoroSettings")
        }
    }
    
    func getSettings(for context: PomodoroContext) -> PomodoroSettings {
        switch context {
        case .general:
            return generalSettings
        case .task:
            return taskSettings
        }
    }
    
    func updateSettings(_ settings: PomodoroSettings, for context: PomodoroContext) {
        switch context {
        case .general:
            generalSettings = settings
        case .task:
            taskSettings = settings
        }
    }
}

enum PomodoroContext {
    case general
    case task
}