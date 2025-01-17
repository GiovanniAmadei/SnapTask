import Foundation
import SwiftUI
import Combine

class TaskFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var hasDuration: Bool = false
    @Published var duration: TimeInterval = 3600
    @Published var icon: String = "circle.fill"
    @Published var selectedCategory: Category?
    @Published var selectedPriority: Priority = .medium
    @Published var subtasks: [Subtask] = []
    @Published var isRecurring: Bool = false
    @Published var isDailyRecurrence: Bool = true
    @Published var selectedDays: Set<Int> = []
    @Published var recurrenceEndDate: Date = Date().addingTimeInterval(86400 * 30)
    @Published var isPomodoroEnabled: Bool = false
    @Published var pomodoroSettings = PomodoroSettings()
    @Published private(set) var categories: [Category] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let settingsViewModel = SettingsViewModel.shared
    
    init(initialDate: Date = Date()) {
        self.startDate = initialDate
        // Get initial categories
        categories = settingsViewModel.categories
        
        // Listen for category updates
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.categories = SettingsViewModel.shared.categories
                }
            }
            .store(in: &cancellables)
            
        // Also observe the SettingsViewModel directly
        settingsViewModel.$categories
            .sink { [weak self] newCategories in
                DispatchQueue.main.async {
                    self?.categories = newCategories
                }
            }
            .store(in: &cancellables)
    }
    
    var isValid: Bool {
        !name.isEmpty
    }
    
    func createTask() -> TodoTask {
        var task = TodoTask(
            id: UUID(),
            name: name,
            description: description.isEmpty ? nil : description,
            startTime: startDate,
            duration: duration,
            hasDuration: hasDuration,
            category: selectedCategory,
            priority: selectedPriority,
            icon: icon
        )
        
        if isRecurring {
            task.recurrence = Recurrence(
                type: isDailyRecurrence ? .daily : .weekly(days: selectedDays),
                endDate: recurrenceEndDate
            )
        }
        
        if isPomodoroEnabled {
            task.pomodoroSettings = pomodoroSettings
        }
        
        task.subtasks = subtasks
        
        return task
    }
    
    func addSubtask(name: String) {
        let subtask = Subtask(id: UUID(), name: name, isCompleted: false)
        subtasks.append(subtask)
    }
    
    func removeSubtask(at offsets: IndexSet) {
        subtasks.remove(atOffsets: offsets)
    }
} 