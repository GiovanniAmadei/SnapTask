import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var priorities: [Priority] = []
    
    private let categoriesKey = "user_categories"
    private let prioritiesKey = "user_priorities"
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance to share categories across the app
    static let shared = SettingsViewModel()
    
    init() {
        loadCategories()
        loadPriorities()
        
        // Observe changes and save
        $categories
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveCategories()
                // Post notification for category updates
                NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
            }
            .store(in: &cancellables)
        
        $priorities
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePriorities()
            }
            .store(in: &cancellables)
    }
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey) {
            do {
                categories = try JSONDecoder().decode([Category].self, from: data)
            } catch {
                print("Error loading categories: \(error)")
                categories = defaultCategories
            }
        } else {
            categories = defaultCategories
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
    
    private func loadPriorities() {
        if let data = UserDefaults.standard.data(forKey: prioritiesKey) {
            do {
                priorities = try JSONDecoder().decode([Priority].self, from: data)
            } catch {
                print("Error loading priorities: \(error)")
                priorities = Priority.allCases
            }
        } else {
            priorities = Priority.allCases
        }
    }
    
    private func savePriorities() {
        do {
            let data = try JSONEncoder().encode(priorities)
            UserDefaults.standard.set(data, forKey: prioritiesKey)
        } catch {
            print("Error saving priorities: \(error)")
        }
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        }
    }
    
    func removeCategory(at indexSet: IndexSet) {
        categories.remove(atOffsets: indexSet)
    }
    
    func addPriority(_ priority: Priority) {
        priorities.append(priority)
    }
    
    func removePriority(at indexSet: IndexSet) {
        priorities.remove(atOffsets: indexSet)
    }
    
    private var defaultCategories: [Category] = [
        Category(id: UUID(), name: "Work", color: "#FF0000"),
        Category(id: UUID(), name: "Personal", color: "#00FF00"),
        Category(id: UUID(), name: "Study", color: "#0000FF")
    ]
}

// Add notification name
extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
} 