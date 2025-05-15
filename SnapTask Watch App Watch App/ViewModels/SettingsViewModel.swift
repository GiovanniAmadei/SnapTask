import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var priorities: [Priority] = []
    @Published var pomodoroSettings = PomodoroSettings(
        workDuration: 25.0 * 60.0,
        breakDuration: 5.0 * 60.0,
        longBreakDuration: 15.0 * 60.0,
        sessionsUntilLongBreak: 4
    )
    
    private let taskManager = TaskManager.shared
    private let categoriesKey = "savedCategories"
    
    init() {
        loadCategories()
        loadPriorities()
        loadPomodoroSettings()
        
        // Add default categories if none exist
        if categories.isEmpty {
            addDefaultCategories()
        }
    }
    
    func loadCategories() {
        var shouldAddDefaults = true
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey) {
            do {
                categories = try JSONDecoder().decode([Category].self, from: data)
                // Check if we have the default categories
                let defaultNames = ["Work", "Personal Care", "Leisure"]
                shouldAddDefaults = categories.filter { defaultNames.contains($0.name) }.count != defaultNames.count
            } catch {
                print("Error loading categories: \(error)")
                categories = []
            }
        }
        
        if shouldAddDefaults {
            addDefaultCategories()
        }
    }
    
    private func addDefaultCategories() {
        let defaultCategories = [
            Category(id: UUID(), name: "Work", color: "#E74C3C"),        // Rosso più piacevole
            Category(id: UUID(), name: "Personal Care", color: "#2ECC71"), // Verde più piacevole
            Category(id: UUID(), name: "Leisure", color: "#3498DB")      // Blu più piacevole
        ]
        
        // Merge with existing categories, keeping any custom ones
        let existingCustomCategories = categories.filter { category in
            !defaultCategories.contains { $0.name == category.name }
        }
        
        categories = defaultCategories + existingCustomCategories
        saveCategories()
        
        // Force sync with iOS app
        UserDefaults.standard.synchronize()
    }
    
    func loadPriorities() {
        self.priorities = Priority.allCases
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    func removeCategory(at indexSet: IndexSet) {
        categories.remove(atOffsets: indexSet)
        saveCategories()
    }
    
    func removeCategory(withID id: UUID) {
        categories.removeAll { $0.id == id }
        saveCategories()
    }
    
    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesKey)
        } catch {
            print("Error saving categories: \(error)")
        }
    }
    
    private func loadPomodoroSettings() {
        if let data = UserDefaults.standard.data(forKey: "watchPomodoroSettings"),
           let settings = try? JSONDecoder().decode(PomodoroSettings.self, from: data) {
            pomodoroSettings = settings
        }
    }
    
    func savePomodoroSettings() {
        if let encoded = try? JSONEncoder().encode(pomodoroSettings) {
            UserDefaults.standard.set(encoded, forKey: "watchPomodoroSettings")
        }
    }
    
    func updatePomodoroSettings(workDuration: Int, breakDuration: Int, longBreakDuration: Int, sessionsUntilLongBreak: Int) {
        let newSettings = PomodoroSettings(
            workDuration: Double(workDuration) * 60.0, // Convert to seconds
            breakDuration: Double(breakDuration) * 60.0, // Convert to seconds
            longBreakDuration: Double(longBreakDuration) * 60.0, // Convert to seconds
            sessionsUntilLongBreak: sessionsUntilLongBreak
        )
        self.pomodoroSettings = newSettings
        
        // Aggiorna le impostazioni di default per i nuovi task
        UserDefaults.standard.set(Double(workDuration) * 60.0, forKey: "defaultWorkDuration")
        UserDefaults.standard.set(Double(breakDuration) * 60.0, forKey: "defaultBreakDuration")
        UserDefaults.standard.set(Double(longBreakDuration) * 60.0, forKey: "defaultLongBreakDuration")
        UserDefaults.standard.set(sessionsUntilLongBreak, forKey: "defaultSessionsUntilLongBreak")
    }
    
    // Add method to clear all data
    func clearAllData() {
        categories = []
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: "watchPomodoroSettings")
        UserDefaults.standard.removeObject(forKey: "defaultWorkDuration")
        UserDefaults.standard.removeObject(forKey: "defaultBreakDuration")
        UserDefaults.standard.removeObject(forKey: "defaultLongBreakDuration")
        UserDefaults.standard.removeObject(forKey: "defaultSessionsUntilLongBreak")
        UserDefaults.standard.synchronize()
        
        // Reset to default values
        pomodoroSettings = PomodoroSettings(
            workDuration: 25.0 * 60.0,
            breakDuration: 5.0 * 60.0,
            longBreakDuration: 15.0 * 60.0,
            sessionsUntilLongBreak: 4
        )
    }
} 