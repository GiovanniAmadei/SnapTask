import Foundation
import SwiftUI
import Combine

enum RecurrenceType: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

@MainActor
class TaskFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var location: TaskLocation?
    @Published var startDate: Date = Date()
    @Published var hasDuration: Bool = false
    @Published var duration: TimeInterval = 3600
    @Published var icon: String = "circle.fill"
    @Published var selectedCategory: Category?
    @Published var selectedPriority: Priority = .medium
    @Published var subtasks: [Subtask] = []
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: RecurrenceType = .daily
    @Published var selectedDays: Set<Int> = []
    @Published var selectedMonthlyDays: Set<Int> = []
    @Published var weeklyTimes: [Int: Date] = [:] 
    @Published var hasRecurrenceEndDate: Bool = false
    @Published var recurrenceEndDate: Date = Date().addingTimeInterval(86400 * 30)
    @Published var trackInStatistics: Bool = true
    @Published var isPomodoroEnabled = false
    @Published var pomodoroSettings = PomodoroSettings(
        workDuration: 25 * 60,
        breakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        sessionsUntilLongBreak: 4,
        totalSessions: 4,
        totalDuration: 120
    )
    
    @Published var hasRewardPoints = false
    @Published var rewardPoints = 5
    
    @Published private(set) var categories: [Category] = []
    var taskId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    private let settingsViewModel = SettingsViewModel.shared
    
    private var isInitialized = false
    
    init(initialDate: Date) {
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        self.startDate = startDate
        categories = settingsViewModel.categories
        
        setupObservers()
        isInitialized = true
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .sink { [weak self] _ in
                guard let self = self, self.isInitialized else { return }
                let newCategories = SettingsViewModel.shared.categories
                if self.categories != newCategories {
                    DispatchQueue.main.async {
                        self.categories = newCategories
                    }
                }
            }
            .store(in: &cancellables)
            
        CategoryManager.shared.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCategories in
                guard let self = self, self.isInitialized else { return }
                if self.categories != newCategories {
                    self.categories = newCategories
                }
            }
            .store(in: &cancellables)
    }
    
    var isValid: Bool {
        !name.isEmpty
    }
    
    var recurrenceDisplayText: String {
        switch recurrenceType {
        case .daily:
            return "Daily"
        case .weekly:
            return selectedDays.isEmpty ? "Weekly" : "\(selectedDays.count) days"
        case .monthly:
            return selectedMonthlyDays.isEmpty ? "Monthly" : "\(selectedMonthlyDays.count) days"
        }
    }
    
    var isDailyRecurrence: Bool {
        get { recurrenceType == .daily }
        set { recurrenceType = newValue ? .daily : .weekly }
    }
    
    func createTask() -> TodoTask {
        let id = taskId ?? UUID()
        
        let recurrence: Recurrence? = isRecurring ? {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: self.startDate)
            let endDate = hasRecurrenceEndDate ? recurrenceEndDate : nil
            
            switch recurrenceType {
            case .daily:
                return Recurrence(type: .daily, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
            case .weekly:
                return Recurrence(type: .weekly(days: selectedDays), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
            case .monthly:
                return Recurrence(type: .monthly(days: selectedMonthlyDays), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
            }
        }() : nil
        
        return TodoTask(
            id: id,
            name: name,
            description: description.isEmpty ? nil : description,
            location: location,
            startTime: startDate,
            duration: duration,
            hasDuration: hasDuration,
            category: selectedCategory,
            priority: selectedPriority,
            icon: icon,
            recurrence: recurrence,
            pomodoroSettings: isPomodoroEnabled ? pomodoroSettings : nil,
            subtasks: subtasks,
            hasRewardPoints: hasRewardPoints,
            rewardPoints: rewardPoints
        )
    }
    
    func addSubtask(name: String) {
        let subtask = Subtask(id: UUID(), name: name, isCompleted: false)
        subtasks.append(subtask)
    }
    
    func removeSubtask(at offsets: IndexSet) {
        subtasks.remove(atOffsets: offsets)
    }
    
    func reset() {
        name = ""
        description = ""
        location = nil
        startDate = Date()
        hasDuration = false
        duration = 3600
        icon = "circle.fill"
        selectedCategory = nil
        selectedPriority = .medium
        subtasks = []
        isRecurring = false
        recurrenceType = .daily
        selectedDays = []
        selectedMonthlyDays = []
        weeklyTimes = [:]
        hasRecurrenceEndDate = false
        recurrenceEndDate = Date().addingTimeInterval(86400 * 30)
        trackInStatistics = true
        isPomodoroEnabled = false
        pomodoroSettings = PomodoroSettings(
            workDuration: 25 * 60,
            breakDuration: 5 * 60,
            longBreakDuration: 15 * 60,
            sessionsUntilLongBreak: 4,
            totalSessions: 4,
            totalDuration: 120
        )
        hasRewardPoints = false
        rewardPoints = 5
        taskId = nil
    }
    
    static var shared: TaskFormViewModel?
}
