import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()
    private let categoryManager = CategoryManager.shared
    @Published private(set) var priorities: [Priority] = []
    private let prioritiesKey = "savedPriorities"
    private var cancellables = Set<AnyCancellable>()
    
    @Published var autoCompleteTaskWithSubtasks: Bool {
        didSet {
            UserDefaults.standard.set(autoCompleteTaskWithSubtasks, forKey: "autoCompleteTaskWithSubtasks")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var showCategoryGradients: Bool {
        didSet {
            UserDefaults.standard.set(showCategoryGradients, forKey: "showCategoryGradients")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var eisenhowerTodayRequireSpecificTime: Bool {
        didSet {
            UserDefaults.standard.set(eisenhowerTodayRequireSpecificTime, forKey: "eisenhowerTodayRequireSpecificTime")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var eisenhowerTodayUrgentHours: Int {
        didSet {
            UserDefaults.standard.set(eisenhowerTodayUrgentHours, forKey: "eisenhowerTodayUrgentHours")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var eisenhowerWeekUrgentHours: Int {
        didSet {
            UserDefaults.standard.set(eisenhowerWeekUrgentHours, forKey: "eisenhowerWeekUrgentHours")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var eisenhowerMonthUrgentDays: Int {
        didSet {
            UserDefaults.standard.set(eisenhowerMonthUrgentDays, forKey: "eisenhowerMonthUrgentDays")
            UserDefaults.standard.synchronize()
        }
    }
    
    @Published var eisenhowerYearUrgentDays: Int {
        didSet {
            UserDefaults.standard.set(eisenhowerYearUrgentDays, forKey: "eisenhowerYearUrgentDays")
            UserDefaults.standard.synchronize()
        }
    }
    
    func resetEisenhowerUrgencyDefaults() {
        eisenhowerTodayRequireSpecificTime = true
        eisenhowerTodayUrgentHours = 4
        eisenhowerWeekUrgentHours = 24
        eisenhowerMonthUrgentDays = 3
        eisenhowerYearUrgentDays = 14
    }
    
    init() {
        self.autoCompleteTaskWithSubtasks = UserDefaults.standard.bool(forKey: "autoCompleteTaskWithSubtasks")
        if !UserDefaults.standard.objectExists(forKey: "autoCompleteTaskWithSubtasks") {
            self.autoCompleteTaskWithSubtasks = true
            UserDefaults.standard.set(true, forKey: "autoCompleteTaskWithSubtasks")
        }
        
        self.showCategoryGradients = UserDefaults.standard.bool(forKey: "showCategoryGradients")
        if !UserDefaults.standard.objectExists(forKey: "showCategoryGradients") {
            self.showCategoryGradients = true
            UserDefaults.standard.set(true, forKey: "showCategoryGradients")
        }
        
        if UserDefaults.standard.objectExists(forKey: "eisenhowerTodayRequireSpecificTime") {
            self.eisenhowerTodayRequireSpecificTime = UserDefaults.standard.bool(forKey: "eisenhowerTodayRequireSpecificTime")
        } else {
            self.eisenhowerTodayRequireSpecificTime = true
            UserDefaults.standard.set(true, forKey: "eisenhowerTodayRequireSpecificTime")
        }
        
        if UserDefaults.standard.objectExists(forKey: "eisenhowerTodayUrgentHours") {
            self.eisenhowerTodayUrgentHours = UserDefaults.standard.integer(forKey: "eisenhowerTodayUrgentHours")
        } else {
            self.eisenhowerTodayUrgentHours = 4
            UserDefaults.standard.set(4, forKey: "eisenhowerTodayUrgentHours")
        }
        
        if UserDefaults.standard.objectExists(forKey: "eisenhowerWeekUrgentHours") {
            self.eisenhowerWeekUrgentHours = UserDefaults.standard.integer(forKey: "eisenhowerWeekUrgentHours")
        } else {
            self.eisenhowerWeekUrgentHours = 24
            UserDefaults.standard.set(24, forKey: "eisenhowerWeekUrgentHours")
        }
        
        if UserDefaults.standard.objectExists(forKey: "eisenhowerMonthUrgentDays") {
            self.eisenhowerMonthUrgentDays = UserDefaults.standard.integer(forKey: "eisenhowerMonthUrgentDays")
        } else {
            self.eisenhowerMonthUrgentDays = 3
            UserDefaults.standard.set(3, forKey: "eisenhowerMonthUrgentDays")
        }
        
        if UserDefaults.standard.objectExists(forKey: "eisenhowerYearUrgentDays") {
            self.eisenhowerYearUrgentDays = UserDefaults.standard.integer(forKey: "eisenhowerYearUrgentDays")
        } else {
            self.eisenhowerYearUrgentDays = 14
            UserDefaults.standard.set(14, forKey: "eisenhowerYearUrgentDays")
        }
        
        loadPriorities()
        
        // Subscribe to CategoryManager changes to keep the view updated
        categoryManager.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
    
    func forceDeleteCategory(_ category: Category) async {
        await categoryManager.forceRemoveCategory(category)
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

extension UserDefaults {
    func objectExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}