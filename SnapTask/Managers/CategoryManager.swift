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
        // Categories will start empty and users can create their own
        if categories.isEmpty {
            print("CategoryManager: Starting with empty categories - users can create their own")
            saveCategories()
        }
    }
    
    private func createDefaultCategories() -> [Category] {
        // Return empty array - no default categories
        return []
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
        
        // Check if there are tasks using this category
        let tasksUsingCategory = TaskManager.shared.tasks.filter { $0.category?.id == category.id }
        if !tasksUsingCategory.isEmpty {
            print("CategoryManager: Category '\(category.name)' is being used by \(tasksUsingCategory.count) task(s)")
            
            // Post notification to show confirmation alert to user
            NotificationCenter.default.post(
                name: .categoryDeletionWarning, 
                object: nil, 
                userInfo: [
                    "category": category,
                    "taskCount": tasksUsingCategory.count
                ]
            )
            return
        }
        
        // If no tasks are using this category, delete directly
        categories.removeAll { $0.id == category.id }
        saveCategories()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteCategory(category)
        print("CategoryManager: Removed category locally: \(category.name)")
    }
    
    func forceRemoveCategory(_ category: Category) async {
        // Force removal even if tasks are using it (tasks will lose their category)
        guard !isUpdatingFromSync else { return }
        
        // Remove category reference from all tasks using it
        let tasksUsingCategory = TaskManager.shared.tasks.filter { $0.category?.id == category.id }
        for task in tasksUsingCategory {
            var updatedTask = task
            updatedTask.category = nil
            await TaskManager.shared.updateTask(updatedTask)
        }
        
        categories.removeAll { $0.id == category.id }
        saveCategories()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteCategory(category)
        print("CategoryManager: Force removed category and updated \(tasksUsingCategory.count) tasks: \(category.name)")
    }
    
    func updateCategory(_ category: Category) {
        guard !isUpdatingFromSync else { return }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
            
            // Sync with CloudKit
            CloudKitService.shared.saveCategory(category)
            print("CategoryManager: Updated category locally: \(category.name)")

            // Propagate the updated category to all tasks that reference it
            let tasksUsingCategory = TaskManager.shared.tasks.filter { $0.category?.id == category.id }
            if !tasksUsingCategory.isEmpty {
                print("CategoryManager: Updating \(tasksUsingCategory.count) task(s) with new category data")
                for task in tasksUsingCategory {
                    var updatedTask = task
                    updatedTask.category = category
                    Task {
                        await TaskManager.shared.updateTask(updatedTask)
                    }
                }
            }

            // Notify listeners that categories changed (for forms, pickers, etc.)
            NotificationCenter.default.post(name: .categoriesDidUpdate, object: nil)
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
        print("CategoryManager: Resetting to empty categories")
        
        // Clear all local data
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: "deletedCategoryIDs")
        
        // No default categories to create - start empty
        categories = []
        saveCategories()
        
        print("CategoryManager: Reset completed with empty categories")
    }
    
    func performCompleteReset() {
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
        
        // Start with empty categories - no defaults
        categories = []
        saveCategories()
        
        // Trigger full CloudKit sync
        CloudKitService.shared.syncNow()
        
        print("CategoryManager: Complete reset finished with empty categories")
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
    static let categoryDeletionWarning = Notification.Name("categoryDeletionWarning")
    static let categoryDeletionBlocked = Notification.Name("categoryDeletionBlocked")
    static let defaultCategoryDeletionAttempted = Notification.Name("defaultCategoryDeletionAttempted")
}