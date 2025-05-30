import Foundation
import Combine

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    @Published var categories: [Category] = []
    private let categoriesKey = "savedCategories"
    
    init() {
        loadCategories()
        createDefaultCategoriesIfNeeded()
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
    }
    
    func removeCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }
    
    func updateCategory(_ updatedCategory: Category) {
        if let index = categories.firstIndex(where: { $0.id == updatedCategory.id }) {
            categories[index] = updatedCategory
            saveCategories()
        }
    }
    
    private func createDefaultCategoriesIfNeeded() {
        if categories.isEmpty {
            let defaultCategories = [
                Category(name: "Work", color: "#3B82F6"),
                Category(name: "Personal", color: "#10B981"),
                Category(name: "Health", color: "#F59E0B"),
                Category(name: "Study", color: "#8B5CF6")
            ]
            
            categories = defaultCategories
            saveCategories()
        }
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
}
