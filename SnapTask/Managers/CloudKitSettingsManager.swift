import Foundation
import Combine
import UIKit

@MainActor
class CloudKitSettingsManager: ObservableObject {
    static let shared = CloudKitSettingsManager()
    
    // MARK: - Published Settings
    // Appearance mode: "system", "light", "dark"
    @Published var appearanceMode: String = "system" {
        didSet { saveSettings() }
    }
    
    @Published var selectedLanguage: String = "en" {
        didSet { saveSettings() }
    }
    
    @Published var notificationsEnabled: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var pomodoroDefaultDuration: Int = 25 {
        didSet { saveSettings() }
    }
    
    @Published var pomodoroShortBreak: Int = 5 {
        didSet { saveSettings() }
    }
    
    @Published var pomodoroLongBreak: Int = 15 {
        didSet { saveSettings() }
    }
    
    @Published var defaultTaskDuration: Int = 60 {
        didSet { saveSettings() }
    }
    
    @Published var enableHapticFeedback: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var autoSyncEnabled: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var showCompletedTasks: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var weekStartsOnMonday: Bool = true {
        didSet { saveSettings() }
    }
    
    // MARK: - Internal State
    @Published var isSyncing: Bool = false
    private var isLoadingFromRemote: Bool = false
    private let settingsKey = "app_settings"
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Syncable Settings Keys
    private let syncableSettings: Set<String> = [
        "appearanceMode",
        "selectedLanguage",
        "notificationsEnabled",
        "pomodoroDefaultDuration",
        "pomodoroShortBreak",
        "pomodoroLongBreak",
        "defaultTaskDuration",
        "enableHapticFeedback",
        "autoSyncEnabled",
        "showCompletedTasks",
        "weekStartsOnMonday"
    ]
    
    private init() {
        loadLocalSettings()
        setupCloudKitObservers()
        
        // Sync settings when CloudKit becomes available
        if CloudKitService.shared.isCloudKitEnabled {
            syncSettings()
        }
    }
    
    // MARK: - CloudKit Integration
    private func setupCloudKitObservers() {
        // Listen for CloudKit settings changes
        NotificationCenter.default.publisher(for: .cloudKitSettingsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let settings = notification.object as? [String: Any] {
                    Task { @MainActor in
                        await self.applyRemoteSettings(settings)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for CloudKit sync status changes
        CloudKitService.shared.$isCloudKitEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.syncSettings()
                }
            }
            .store(in: &cancellables)
    }
    
    func syncSettings() {
        guard CloudKitService.shared.isCloudKitEnabled else { return }
        guard !isSyncing else { return }
        
        isSyncing = true
        
        Task {
            let settings = getCurrentSettings()
            CloudKitService.shared.saveAppSettings(settings)
            
            await MainActor.run {
                self.isSyncing = false
            }
        }
    }
    
    private func getCurrentSettings() -> [String: Any] {
        var settings: [String: Any] = [:]
        
        for key in syncableSettings {
            switch key {
            case "appearanceMode":
                settings[key] = appearanceMode
            case "selectedLanguage":
                settings[key] = selectedLanguage
            case "notificationsEnabled":
                settings[key] = notificationsEnabled
            case "pomodoroDefaultDuration":
                settings[key] = pomodoroDefaultDuration
            case "pomodoroShortBreak":
                settings[key] = pomodoroShortBreak
            case "pomodoroLongBreak":
                settings[key] = pomodoroLongBreak
            case "defaultTaskDuration":
                settings[key] = defaultTaskDuration
            case "enableHapticFeedback":
                settings[key] = enableHapticFeedback
            case "autoSyncEnabled":
                settings[key] = autoSyncEnabled
            case "showCompletedTasks":
                settings[key] = showCompletedTasks
            case "weekStartsOnMonday":
                settings[key] = weekStartsOnMonday
            default:
                break
            }
        }
        
        settings["lastUpdated"] = Date().timeIntervalSince1970
        settings["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        return settings
    }
    
    private func applyRemoteSettings(_ remoteSettings: [String: Any]) async {
        isLoadingFromRemote = true
        
        for (key, value) in remoteSettings {
            guard syncableSettings.contains(key) else { continue }
            
            switch key {
            case "appearanceMode":
                if let stringValue = value as? String {
                    appearanceMode = stringValue
                    UserDefaults.standard.set(stringValue, forKey: "appearanceMode")
                } else if let boolValue = value as? Bool {
                    // Migration from old isDarkMode boolean
                    appearanceMode = boolValue ? "dark" : "light"
                    UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
                }
            case "selectedLanguage":
                if let stringValue = value as? String {
                    selectedLanguage = stringValue
                }
            case "notificationsEnabled":
                if let boolValue = value as? Bool {
                    notificationsEnabled = boolValue
                }
            case "pomodoroDefaultDuration":
                if let intValue = value as? Int {
                    pomodoroDefaultDuration = intValue
                }
            case "pomodoroShortBreak":
                if let intValue = value as? Int {
                    pomodoroShortBreak = intValue
                }
            case "pomodoroLongBreak":
                if let intValue = value as? Int {
                    pomodoroLongBreak = intValue
                }
            case "defaultTaskDuration":
                if let intValue = value as? Int {
                    defaultTaskDuration = intValue
                }
            case "enableHapticFeedback":
                if let boolValue = value as? Bool {
                    enableHapticFeedback = boolValue
                }
            case "autoSyncEnabled":
                if let boolValue = value as? Bool {
                    autoSyncEnabled = boolValue
                }
            case "showCompletedTasks":
                if let boolValue = value as? Bool {
                    showCompletedTasks = boolValue
                }
            case "weekStartsOnMonday":
                if let boolValue = value as? Bool {
                    weekStartsOnMonday = boolValue
                }
            default:
                break
            }
        }
        
        // Save merged settings locally without triggering CloudKit sync
        saveLocalSettings()
        
        isLoadingFromRemote = false
        
        print("📥 Applied \(remoteSettings.count) settings from CloudKit")
    }
    
    // MARK: - Local Storage
    private func saveSettings() {
        guard !isLoadingFromRemote else { return }
        
        saveLocalSettings()
        
        // Sync with CloudKit if enabled
        if CloudKitService.shared.isCloudKitEnabled && autoSyncEnabled {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // Debounce
                syncSettings()
            }
        }
    }
    
    private func saveLocalSettings() {
        let settings = getCurrentSettings()
        
        // Ensure all values are JSON-serializable
        let jsonCompatibleSettings = makeJSONCompatible(settings)
        
        // Convert to Data using JSONSerialization instead of JSONEncoder
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonCompatibleSettings, options: [])
            UserDefaults.standard.set(data, forKey: settingsKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }
    
    private func makeJSONCompatible(_ dictionary: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in dictionary {
            switch value {
            case let date as Date:
                result[key] = date.timeIntervalSince1970
            case let uuid as UUID:
                result[key] = uuid.uuidString
            case let data as Data:
                result[key] = data.base64EncodedString()
            case let string as String:
                result[key] = string
            case let number as NSNumber:
                result[key] = number
            case let bool as Bool:
                result[key] = bool
            case let int as Int:
                result[key] = int
            case let double as Double:
                result[key] = double
            case let float as Float:
                result[key] = Double(float)
            default:
                // Skip non-JSON-serializable types
                print("⚠️ Skipping non-JSON-serializable value for key \(key): \(type(of: value))")
            }
        }
        
        return result
    }
    
    private func loadLocalSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            // Load from UserDefaults for backward compatibility
            loadLegacySettings()
            return
        }
        
        do {
            if let settings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let codableSettings = settings.mapValues { AnyCodable($0) }
                applyLocalSettings(codableSettings)
            } else {
                loadLegacySettings()
            }
        } catch {
            print("❌ Failed to load settings: \(error)")
            loadLegacySettings()
        }
    }
    
    private func loadLegacySettings() {
        // Load individual settings from UserDefaults for backward compatibility
        // Migration: check for old isDarkMode and convert to appearanceMode
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") {
            appearanceMode = savedMode
        } else if UserDefaults.standard.object(forKey: "isDarkMode") != nil {
            // Migrate from old isDarkMode boolean
            let wasDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            appearanceMode = wasDarkMode ? "dark" : "light"
        } else {
            appearanceMode = "system"
        }
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        pomodoroDefaultDuration = UserDefaults.standard.object(forKey: "pomodoroDefaultDuration") as? Int ?? 25
        pomodoroShortBreak = UserDefaults.standard.object(forKey: "pomodoroShortBreak") as? Int ?? 5
        pomodoroLongBreak = UserDefaults.standard.object(forKey: "pomodoroLongBreak") as? Int ?? 15
        defaultTaskDuration = UserDefaults.standard.object(forKey: "defaultTaskDuration") as? Int ?? 60
        enableHapticFeedback = UserDefaults.standard.object(forKey: "enableHapticFeedback") as? Bool ?? true
        autoSyncEnabled = UserDefaults.standard.object(forKey: "autoSyncEnabled") as? Bool ?? true
        showCompletedTasks = UserDefaults.standard.object(forKey: "showCompletedTasks") as? Bool ?? true
        weekStartsOnMonday = UserDefaults.standard.object(forKey: "weekStartsOnMonday") as? Bool ?? true
        
        // Save in new format
        saveLocalSettings()
    }
    
    private func applyLocalSettings(_ settings: [String: AnyCodable]) {
        isLoadingFromRemote = true
        
        for (key, value) in settings {
            guard syncableSettings.contains(key) else { continue }
            
            switch key {
            case "appearanceMode":
                appearanceMode = value.stringValue ?? "system"
            case "selectedLanguage":
                selectedLanguage = value.stringValue ?? "en"
            case "notificationsEnabled":
                notificationsEnabled = value.boolValue ?? true
            case "pomodoroDefaultDuration":
                pomodoroDefaultDuration = value.intValue ?? 25
            case "pomodoroShortBreak":
                pomodoroShortBreak = value.intValue ?? 5
            case "pomodoroLongBreak":
                pomodoroLongBreak = value.intValue ?? 15
            case "defaultTaskDuration":
                defaultTaskDuration = value.intValue ?? 60
            case "enableHapticFeedback":
                enableHapticFeedback = value.boolValue ?? true
            case "autoSyncEnabled":
                autoSyncEnabled = value.boolValue ?? true
            case "showCompletedTasks":
                showCompletedTasks = value.boolValue ?? true
            case "weekStartsOnMonday":
                weekStartsOnMonday = value.boolValue ?? true
            default:
                break
            }
        }
        
        isLoadingFromRemote = false
    }
    
    // MARK: - Public Methods
    func resetToDefaults() {
        isLoadingFromRemote = true
        
        appearanceMode = "system"
        selectedLanguage = "en"
        notificationsEnabled = true
        pomodoroDefaultDuration = 25
        pomodoroShortBreak = 5
        pomodoroLongBreak = 15
        defaultTaskDuration = 60
        enableHapticFeedback = true
        autoSyncEnabled = true
        showCompletedTasks = true
        weekStartsOnMonday = true
        
        isLoadingFromRemote = false
        
        saveSettings()
    }
    
    func forceSync() {
        syncSettings()
    }
}

// MARK: - AnyCodable Helper
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    var boolValue: Bool? {
        return value as? Bool
    }
    
    var intValue: Int? {
        return value as? Int
    }
    
    var stringValue: String? {
        return value as? String
    }
}