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
        categoryManager.addCategory(category)
    }
    
    func updateCategory(_ category: Category) {
        categoryManager.updateCategory(category)
    }
    
    func deleteCategory(_ category: Category) {
        categoryManager.removeCategory(category)
    }
    
    func removeCategory(at indexSet: IndexSet) {
        indexSet.forEach { index in
            if index < categories.count {
                categoryManager.removeCategory(categories[index])
            }
        }
    }
    
    func deleteCategories(at offsets: IndexSet) {
        let categoriesToDelete = offsets.map { CategoryManager.shared.categories[$0] }
        for category in categoriesToDelete {
            CategoryManager.shared.removeCategory(category)
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
    
    func importPriorities(_ newPriorities: [Priority]) {
        // Merge with existing priorities, avoiding duplicates
        let existingPrioritiesSet = Set(priorities)
        let newPrioritiesSet = Set(newPriorities)
        
        // Combine both sets to get all unique priorities
        let allPriorities = existingPrioritiesSet.union(newPrioritiesSet)
        
        priorities = Array(allPriorities)
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
            UserDefaults.standard.synchronize()
        }
    }
}
