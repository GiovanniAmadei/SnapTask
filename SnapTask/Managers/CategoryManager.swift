import Foundation
import Combine

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    @Published private(set) var categories: [Category] = []
    private let categoriesKey = "savedCategories"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCategories()
        setupNotifications()
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
        saveCategories()
        notifyCategoryUpdates()
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
        notifyCategoryUpdates()
    }
    
    func clearAllData() {
        categories = []
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.synchronize()
        notifyCategoryUpdates()
    }
    
    func importCategories(_ newCategories: [Category]) {
        // Create a dictionary of existing categories by ID for quick lookup
        let existingCategoriesDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        
        // Merge new categories with existing ones, prioritizing new ones in case of conflict
        var updatedCategories = existingCategoriesDict
        
        for category in newCategories {
            updatedCategories[category.id] = category
        }
        
        // Convert back to array
        categories = Array(updatedCategories.values)
        
        // Save the updated categories
        saveCategories()
    }
    
    private func loadCategories() {
        var shouldAddDefaults = true
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
            // Check if we have the default categories
            let defaultNames = ["Work", "Personal Care", "Leisure"]
            shouldAddDefaults = categories.filter { defaultNames.contains($0.name) }.count != defaultNames.count
        }
        
        if shouldAddDefaults {
            addDefaultCategories()
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
            UserDefaults.standard.synchronize() // Ensure changes are saved immediately
            notifyCategoryUpdates()
        }
    }
    
    private func notifyCategoryUpdates() {
        NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
        objectWillChange.send()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        // Add observer for UserDefaults changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.loadCategories()
            }
            .store(in: &cancellables)
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
    }
}

extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
} 