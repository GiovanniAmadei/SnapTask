import Foundation
import Combine

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    @Published var categories: [Category] = []
    
    private let categoriesKey = "savedCategories"
    
    private init() {
        loadCategories()
    }
    
    func addCategory(_ category: Category) {
        guard !categories.contains(where: { $0.id == category.id || $0.name == category.name }) else {
            print("CategoryManager: Category already exists, skipping: \(category.name)")
            return
        }
        
        categories.append(category)
        saveCategories()
        
        Task { @MainActor in
            CloudKitService.shared.saveCategory(category)
        }
        print("CategoryManager: Added category locally: \(category.name)")
    }
    
    func removeCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
        
        Task { @MainActor in
            CloudKitService.shared.deleteCategory(category)
        }
        print("CategoryManager: Removed category locally: \(category.name)")
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
            
            Task { @MainActor in
                CloudKitService.shared.saveCategory(category)
            }
            print("CategoryManager: Updated category locally: \(category.name)")
        }
    }
    
    func importCategories(_ newCategories: [Category]) {
        categories = newCategories
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
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey) {
            do {
                categories = try JSONDecoder().decode([Category].self, from: data)
            } catch {
                print("Error loading categories: \(error)")
            }
        }
    }
    
    func resetToDefaults() {
        print("CategoryManager: Resetting to default categories")
        
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        
        UserDefaults.standard.removeObject(forKey: "deletedCategoryIDs")
        
        let defaultCategories = [
            Category(id: UUID(), name: "Work", color: "007AFF"),
            Category(id: UUID(), name: "Personal", color: "34C759"), 
            Category(id: UUID(), name: "Health", color: "FF3B30")
        ]
        
        categories = defaultCategories
        saveCategories()
        
        Task { @MainActor in
            for category in defaultCategories {
                CloudKitService.shared.saveCategory(category)
            }
        }
        
        print("CategoryManager: Reset completed with \(categories.count) default categories")
    }
    
    private func clearAllCloudKitCategories() async {
        print("CategoryManager: Clearing CloudKit categories")
    }
    
    func ensureDefaultCategoriesExistAndSync() {
        if categories.isEmpty {
            print("CategoryManager: No categories found locally or from CloudKit after initial sync. Creating defaults.")
            let defaultCategories = [
                Category(id: UUID(), name: "Work", color: "007AFF"),
                Category(id: UUID(), name: "Personal", color: "34C759"),
                Category(id: UUID(), name: "Health", color: "FF3B30")
            ]
            
            categories = defaultCategories
            saveCategories() // Salva localmente
            
            Task { @MainActor in
                for category in defaultCategories {
                    CloudKitService.shared.saveCategory(category)
                }
            }
            print("CategoryManager: Created and synced \(defaultCategories.count) default categories.")
        } else {
            print("CategoryManager: Categories already exist. No need to create defaults.")
        }
    }
    
    func addCategoryWithCheck(_ category: Category) {
        guard !categories.contains(where: { $0.id == category.id || $0.name == category.name }) else {
            print("CategoryManager: Category already exists, skipping: \(category.name)")
            return
        }
        
        categories.append(category)
        saveCategories()
        
        Task { @MainActor in
            CloudKitService.shared.saveCategory(category)
        }
    }
    
    func importCategoriesWithCheck(_ newCategories: [Category]) {
        print("CategoryManager: Importing \(newCategories.count) categories")
        
        var uniqueCategories: [Category] = []
        var seenIDs = Set<UUID>()
        var seenNames = Set<String>()
        
        for category in newCategories {
            if !seenIDs.contains(category.id) && !seenNames.contains(category.name) {
                uniqueCategories.append(category)
                seenIDs.insert(category.id)
                seenNames.insert(category.name)
            }
        }
        
        categories = uniqueCategories
        saveCategories()
        print("CategoryManager: Imported \(uniqueCategories.count) unique categories")
    }
}

extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
}
