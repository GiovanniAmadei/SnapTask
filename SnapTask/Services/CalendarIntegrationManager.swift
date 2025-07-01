import Foundation
import Combine

@MainActor
class CalendarIntegrationManager: ObservableObject {
    static let shared = CalendarIntegrationManager()
    
    @Published var settings = CalendarIntegrationSettings()
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var syncStatus: SyncStatus = .idle
    
    private let appleService = AppleCalendarService.shared
    private let googleService = GoogleCalendarService.shared
    private let settingsKey = "calendar_integration_settings"
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
        
        var displayText: String {
            switch self {
            case .idle: return "Ready"
            case .syncing: return "Syncing..."
            case .success: return "Synced successfully"
            case .error(let message): return "Error: \(message)"
            }
        }
    }
    
    private init() {
        loadSettings()
    }
    
    func updateSettings(_ newSettings: CalendarIntegrationSettings) {
        settings = newSettings
        saveSettings()
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let loadedSettings = try? JSONDecoder().decode(CalendarIntegrationSettings.self, from: data) {
            settings = loadedSettings
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func syncTaskToCalendar(_ task: TodoTask) async {
        guard settings.isEnabled,
              let calendarId = settings.selectedCalendarId else {
            print("❌ Calendar sync disabled or no calendar selected")
            return
        }
        
        print("📅 Starting sync for task: \(task.name)")
        syncStatus = .syncing
        
        do {
            let eventId: String?
            
            switch settings.provider {
            case .apple:
                print("📅 Using Apple Calendar service")
                eventId = try await appleService.createEvent(from: task, in: calendarId)
            case .google:
                print("📅 Using Google Calendar service")
                eventId = try await googleService.createEvent(from: task, in: calendarId)
            }
            
            if let eventId = eventId {
                print("✅ Event created with ID: \(eventId)")
                await storeEventId(eventId, for: task.id)
                syncStatus = .success
            } else {
                print("❌ No event ID returned")
                syncStatus = .error("Failed to create calendar event")
            }
        } catch {
            print("❌ Calendar sync error: \(error.localizedDescription)")
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    func updateTaskInCalendar(_ task: TodoTask) async {
        guard settings.isEnabled,
              settings.autoSyncOnTaskUpdate,
              let eventId = await getEventId(for: task.id) else {
            return
        }
        
        syncStatus = .syncing
        
        do {
            switch settings.provider {
            case .apple:
                try await appleService.updateEvent(eventId: eventId, with: task)
            case .google:
                // Implement Google Calendar update
                break
            }
            
            syncStatus = .success
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    func deleteTaskFromCalendar(_ taskId: UUID) async {
        guard settings.isEnabled,
              let eventId = await getEventId(for: taskId) else {
            return
        }
        
        syncStatus = .syncing
        
        do {
            switch settings.provider {
            case .apple:
                try await appleService.deleteEvent(eventId: eventId)
            case .google:
                // Implement Google Calendar deletion
                break
            }
            
            await removeEventId(for: taskId)
            syncStatus = .success
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    func syncAllTasksToCalendar(_ tasks: [TodoTask]) async {
        guard settings.isEnabled,
              settings.selectedCalendarId != nil else {
            syncStatus = .error("Calendar integration not properly configured")
            return
        }
        
        print("📅 Starting sync for \(tasks.count) tasks")
        syncStatus = .syncing
        
        var successCount = 0
        var errorCount = 0
        
        for task in tasks {
            // Check if task already has an event ID (avoid duplicates)
            if await getEventId(for: task.id) != nil {
                print("📅 Task \(task.name) already synced, skipping")
                continue
            }
            
            do {
                let eventId: String?
                
                switch settings.provider {
                case .apple:
                    eventId = try await appleService.createEvent(from: task, in: settings.selectedCalendarId!)
                case .google:
                    eventId = try await googleService.createEvent(from: task, in: settings.selectedCalendarId!)
                }
                
                if let eventId = eventId {
                    await storeEventId(eventId, for: task.id)
                    successCount += 1
                    print("✅ Synced task: \(task.name)")
                } else {
                    errorCount += 1
                    print("❌ Failed to sync task: \(task.name)")
                }
            } catch {
                errorCount += 1
                print("❌ Error syncing task \(task.name): \(error.localizedDescription)")
            }
        }
        
        if errorCount == 0 {
            syncStatus = .success
            print("✅ All tasks synced successfully (\(successCount) tasks)")
        } else {
            syncStatus = .error("Synced \(successCount) tasks, \(errorCount) failed")
            print("⚠️ Sync completed with errors: \(successCount) success, \(errorCount) failed")
        }
    }
    
    func deleteAllSyncedTasksFromCalendar() async {
        guard settings.isEnabled else {
            syncStatus = .error("Calendar integration is disabled")
            return
        }
        
        print("📅 Starting deletion of all synced tasks from calendar")
        syncStatus = .syncing
        
        var successCount = 0
        var errorCount = 0
        var cleanedCount = 0
        
        // Get all stored event IDs
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let eventKeys = allKeys.filter { $0.hasPrefix("calendar_event_") }
        
        print("📅 Found \(eventKeys.count) synced events to delete")
        
        for eventKey in eventKeys {
            if let eventId = userDefaults.string(forKey: eventKey) {
                // Check if event exists before trying to delete
                switch settings.provider {
                case .apple:
                    if appleService.eventExists(eventId: eventId) {
                        do {
                            try await appleService.deleteEvent(eventId: eventId)
                            successCount += 1
                            print("✅ Deleted event: \(eventId)")
                        } catch {
                            print("❌ Failed to delete event \(eventId): \(error.localizedDescription)")
                            errorCount += 1
                        }
                    } else {
                        print("🧹 Event \(eventId) no longer exists, cleaning up stored ID")
                        cleanedCount += 1
                    }
                case .google:
                    // Implement Google Calendar deletion when available
                    break
                }
                
                // Always remove the stored event ID
                userDefaults.removeObject(forKey: eventKey)
            }
        }
        
        // Provide meaningful status based on results
        if errorCount == 0 {
            syncStatus = .success
            let totalProcessed = successCount + cleanedCount
            if cleanedCount > 0 {
                print("✅ All synced events processed: \(successCount) deleted, \(cleanedCount) cleaned up (already removed)")
            } else {
                print("✅ All synced tasks deleted from calendar (\(successCount) events)")
            }
        } else {
            syncStatus = .error("Processed \(successCount + cleanedCount) events, \(errorCount) failed")
            print("⚠️ Deletion completed with errors: \(successCount) deleted, \(cleanedCount) cleaned, \(errorCount) failed")
        }
    }
    
    func getSyncedTasksCount() -> Int {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys.filter { $0.hasPrefix("calendar_event_") }.count
    }
    
    private func storeEventId(_ eventId: String, for taskId: UUID) async {
        let key = "calendar_event_\(taskId.uuidString)"
        UserDefaults.standard.set(eventId, forKey: key)
    }
    
    private func getEventId(for taskId: UUID) async -> String? {
        let key = "calendar_event_\(taskId.uuidString)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    private func removeEventId(for taskId: UUID) async {
        let key = "calendar_event_\(taskId.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
    }
}