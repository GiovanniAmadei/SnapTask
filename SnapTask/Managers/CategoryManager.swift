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
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
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
    }
}

extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
} 