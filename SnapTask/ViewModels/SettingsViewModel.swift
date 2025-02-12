import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let categoryManager = CategoryManager.shared
    @Published private(set) var priorities: [Priority] = []
    private let prioritiesKey = "savedPriorities"
    
    init() {
        loadPriorities()
        // Add default categories if none exist
        if categories.isEmpty {
            let defaultCategories = [
                Category(id: UUID(), name: "Work", color: "#FF6B6B"),
                Category(id: UUID(), name: "Study", color: "#4ECDC4"),
                Category(id: UUID(), name: "Sport", color: "#45B7D5")
            ]
            defaultCategories.forEach { addCategory($0) }
        }
    }
    
    // MARK: - Categories
    var categories: [Category] {
        categoryManager.categories
    }
    
    func addCategory(_ category: Category) {
        categoryManager.updateCategory(category)
    }
    
    func updateCategory(_ category: Category) {
        categoryManager.updateCategory(category)
    }
    
    func deleteCategory(_ category: Category) {
        categoryManager.deleteCategory(category)
    }
    
    func removeCategory(at indexSet: IndexSet) {
        indexSet.forEach { index in
            if index < categories.count {
                categoryManager.deleteCategory(categories[index])
            }
        }
    }
    
    // MARK: - Priorities
    func addPriority(_ priority: Priority) {
        if !priorities.contains(priority) {
            priorities.append(priority)
            savePriorities()
        }
    }
    
    func removePriority(at indexSet: IndexSet) {
        priorities.remove(atOffsets: indexSet)
        savePriorities()
    }
    
    private func loadPriorities() {
        if let data = UserDefaults.standard.data(forKey: prioritiesKey),
           let decoded = try? JSONDecoder().decode([Priority].self, from: data) {
            priorities = decoded
        } else {
            // Default priorities
            priorities = [.low, .medium, .high]
            savePriorities()
        }
    }
    
    private func savePriorities() {
        if let encoded = try? JSONEncoder().encode(priorities) {
            UserDefaults.standard.set(encoded, forKey: prioritiesKey)
        }
    }
} 