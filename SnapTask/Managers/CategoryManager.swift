import Foundation
import Combine

@MainActor
class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    @Published var categories: [Category] = []
    
    private let categoriesKey = "savedCategories"
    private var isUpdatingFromSync = false
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {
        loadCategories()
        setupCloudKitObservers()
        ensureDefaultCategoriesExist()
    }
    
    private func setupCloudKitObservers() {
        // Listen for CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // CloudKit data changed, sync will handle updates
                print("📥 CloudKit categories data changed")
            }
            .store(in: &cancellables)
    }
    
    private func ensureDefaultCategoriesExist() {
        if categories.isEmpty {
            print("CategoryManager: Creating default categories")
            let defaultCategories = createDefaultCategories()
            categories = defaultCategories
            saveCategories()
        }
    }
    
    private func createDefaultCategories() -> [Category] {
        return [
            Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(), name: "Work", color: "007AFF"),
            Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(), name: "Personal", color: "34C759"),
            Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(), name: "Health", color: "FF3B30")
        ]
    }
    
    func addCategory(_ category: Category) {
        guard !isUpdatingFromSync else { return }
        guard !categories.contains(where: { $0.id == category.id || $0.name.lowercased() == category.name.lowercased() }) else {
            print("CategoryManager: Category already exists, skipping: \(category.name)")
            return
        }
        
        categories.append(category)
        saveCategories()
        
        // Sync with CloudKit
        CloudKitService.shared.saveCategory(category)
        print("CategoryManager: Added category locally: \(category.name)")
    }
    
    func removeCategory(_ category: Category) {
        guard !isUpdatingFromSync else { return }
        
        // Don't allow removing default categories
        let defaultIds = createDefaultCategories().map { $0.id }
        if defaultIds.contains(category.id) {
            print("CategoryManager: Cannot remove default category: \(category.name)")
            return
        }
        
        categories.removeAll { $0.id == category.id }
        saveCategories()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteCategory(category)
        print("CategoryManager: Removed category locally: \(category.name)")
    }
    
    func updateCategory(_ category: Category) {
        guard !isUpdatingFromSync else { return }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
            
            // Sync with CloudKit
            CloudKitService.shared.saveCategory(category)
            print("CategoryManager: Updated category locally: \(category.name)")
        }
    }
    
    func importCategories(_ newCategories: [Category]) {
        isUpdatingFromSync = true
        
        // Merge categories intelligently
        var mergedCategories: [Category] = []
        var seenIds = Set<UUID>()
        var seenNames = Set<String>()
        
        // First, add existing categories that aren't duplicated
        for category in categories {
            let normalizedName = category.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenIds.contains(category.id) && !seenNames.contains(normalizedName) {
                mergedCategories.append(category)
                seenIds.insert(category.id)
                seenNames.insert(normalizedName)
            }
        }
        
        // Then add new categories that aren't duplicates
        for category in newCategories {
            let normalizedName = category.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenIds.contains(category.id) && !seenNames.contains(normalizedName) {
                mergedCategories.append(category)
                seenIds.insert(category.id)
                seenNames.insert(normalizedName)
            }
        }
        
        // Ensure we always have default categories
        if mergedCategories.isEmpty {
            mergedCategories = createDefaultCategories()
        }
        
        categories = mergedCategories
        saveCategories()
        isUpdatingFromSync = false
        
        print("CategoryManager: Imported \(mergedCategories.count) unique categories")
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
        
        // Clear all local data
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: "deletedCategoryIDs")
        
        // Create fresh default categories
        let defaultCategories = createDefaultCategories()
        categories = defaultCategories
        saveCategories()
        
        // Force sync with CloudKit
        for category in defaultCategories {
            CloudKitService.shared.saveCategory(category)
        }
        
        print("CategoryManager: Reset completed with \(categories.count) default categories")
    }
    
    func performCompleteReset() async {
        print("CategoryManager: Performing complete reset")
        
        // Clear all local data
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: "deletedCategoryIDs")
        
        // Clear CloudKit deletion markers
        var deletionTracker = CloudKitService.DeletionTracker()
        deletionTracker.categories.removeAll()
        let data = try? JSONEncoder().encode(deletionTracker)
        UserDefaults.standard.set(data, forKey: "cloudkit_deleted_items")
        
        // Wait a moment for cleanup
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create fresh default categories with new UUIDs
        let defaultCategories = [
            Category(id: UUID(), name: "Work", color: "007AFF"),
            Category(id: UUID(), name: "Personal", color: "34C759"),
            Category(id: UUID(), name: "Health", color: "FF3B30")
        ]
        
        categories = defaultCategories
        saveCategories()
        
        // Force sync with CloudKit
        for category in defaultCategories {
            CloudKitService.shared.saveCategory(category)
        }
        
        // Trigger full CloudKit sync
        CloudKitService.shared.syncNow()
        
        print("CategoryManager: Complete reset finished with \(categories.count) fresh categories")
    }
    
    func debugCategoryStatus() {
        print("=== CATEGORY DEBUG STATUS ===")
        print("Local categories count: \(categories.count)")
        for (index, category) in categories.enumerated() {
            print("  \(index + 1). \(category.name) (ID: \(category.id.uuidString.prefix(8))..., Color: \(category.color))")
        }
        
        // Check UserDefaults
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let saved = try? JSONDecoder().decode([Category].self, from: data) {
            print("UserDefaults categories count: \(saved.count)")
        } else {
            print("No categories in UserDefaults")
        }
        
        // Check CloudKit deletion markers
        if let data = UserDefaults.standard.data(forKey: "cloudkit_deleted_items"),
           let tracker = try? JSONDecoder().decode(CloudKitService.DeletionTracker.self, from: data) {
            print("Deleted category IDs: \(tracker.categories.count)")
            for id in tracker.categories.prefix(5) {
                print("  - \(id.prefix(8))...")
            }
        }
        print("===========================")
    }
}

extension Notification.Name {
    static let categoriesDidUpdate = Notification.Name("categoriesDidUpdate")
}
