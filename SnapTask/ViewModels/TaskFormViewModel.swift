import Foundation
import SwiftUI
import Combine

enum RecurrenceType: String, CaseIterable {
    case daily = "daily_enum"
    case weekly = "weekly_enum"
    case monthly = "monthly_enum"
    case yearly = "yearly_enum"
    
    var localizedString: String {
        return self.rawValue.localized
    }
}

enum MonthlySelectionType: String, CaseIterable {
    case days = "days_enum"
    case ordinal = "patterns_enum"
    
    var localizedString: String {
        return self.rawValue.localized
    }
}

@MainActor
class TaskFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var location: TaskLocation?
    @Published var startDate: Date = Date()
    @Published var hasSpecificTime: Bool = true
    @Published var hasDuration: Bool = false
    @Published var duration: TimeInterval = 3600 {
        didSet {
            if duration.isNaN || duration <= 0 {
                duration = 3600
            }
        }
    }
    @Published var icon: String = "circle.fill"
    @Published var selectedCategory: Category?
    @Published var selectedPriority: Priority = .medium
    @Published var subtasks: [Subtask] = []
    @Published var hasNotification: Bool = false
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: RecurrenceType = .daily
    @Published var selectedDays: Set<Int> = []
    @Published var selectedMonthlyDays: Set<Int> = []
    @Published var monthlySelectionType: MonthlySelectionType = .days
    @Published var selectedOrdinalPatterns: Set<Recurrence.OrdinalPattern> = []
    @Published var yearlyDate: Date = Date()
    @Published var weeklyTimes: [Int: Date] = [:]
    @Published var hasRecurrenceEndDate: Bool = false
    @Published var recurrenceEndDate: Date = Date().addingTimeInterval(86400 * 30)
    @Published var trackInStatistics: Bool = true
    @Published var hasRewardPoints = false
    @Published var rewardPoints = 5 {
        didSet {
            if rewardPoints < 1 {
                rewardPoints = 1
            } else if rewardPoints > 999 {
                rewardPoints = 999
            }
        }
    }
    @Published var useCustomPoints = false
    @Published var customPointsText = "5"
    
    @Published private(set) var categories: [Category] = []
    var taskId: UUID?
    
    private var cancellables = Set<AnyCancellable>()
    private let settingsViewModel = SettingsViewModel.shared
    
    private var isInitialized = false
    
    init(initialDate: Date) {
        let calendar = Calendar.current
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        self.startDate = startDate
        self.yearlyDate = startDate
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
            return "daily_enum".localized
        case .weekly:
            return selectedDays.isEmpty ? "weekly_enum".localized : String(format: "weekly_days_format".localized, selectedDays.count)
        case .monthly:
            switch monthlySelectionType {
            case .days:
                return selectedMonthlyDays.isEmpty ? "monthly_enum".localized : String(format: "monthly_days_format".localized, selectedMonthlyDays.count)
            case .ordinal:
                return selectedOrdinalPatterns.isEmpty ? "monthly_patterns".localized : String(format: "monthly_patterns_format".localized, selectedOrdinalPatterns.count)
            }
        case .yearly:
            return "yearly_enum".localized
        }
    }
    
    var isDailyRecurrence: Bool {
        get { recurrenceType == .daily }
        set { recurrenceType = newValue ? .daily : .weekly }
    }
    
    func createTask() -> TodoTask {
        let id = taskId ?? UUID()
        
        let taskStartTime: Date
        if hasSpecificTime {
            taskStartTime = startDate
        } else {
            // For tasks without specific time, use start of day
            let calendar = Calendar.current
            taskStartTime = calendar.startOfDay(for: startDate)
        }
        
        let recurrence: Recurrence? = isRecurring ? {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: taskStartTime)
            let endDate = hasRecurrenceEndDate ? recurrenceEndDate : nil
            
            switch recurrenceType {
            case .daily:
                return Recurrence(type: .daily, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
            case .weekly:
                return Recurrence(type: .weekly(days: selectedDays), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
            case .monthly:
                switch monthlySelectionType {
                case .days:
                    return Recurrence(type: .monthly(days: selectedMonthlyDays), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
                case .ordinal:
                    return Recurrence(type: .monthlyOrdinal(patterns: selectedOrdinalPatterns), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
                }
            case .yearly:
                return Recurrence(type: .yearly, startDate: calendar.startOfDay(for: yearlyDate), endDate: endDate, trackInStatistics: trackInStatistics)
            }
        }() : nil
        
        return TodoTask(
            id: id,
            name: name,
            description: description.isEmpty ? nil : description,
            location: location,
            startTime: taskStartTime,
            hasSpecificTime: hasSpecificTime,
            duration: duration,
            hasDuration: hasDuration,
            category: selectedCategory,
            priority: selectedPriority,
            icon: icon,
            recurrence: recurrence,
            pomodoroSettings: nil,
            subtasks: subtasks,
            hasRewardPoints: hasRewardPoints,
            rewardPoints: rewardPoints,
            hasNotification: hasNotification
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
        hasSpecificTime = true
        hasDuration = false
        duration = 3600
        icon = "circle.fill"
        selectedCategory = nil
        selectedPriority = .medium
        subtasks = []
        hasNotification = false
        isRecurring = false
        recurrenceType = .daily
        selectedDays = []
        selectedMonthlyDays = []
        monthlySelectionType = .days
        selectedOrdinalPatterns = []
        selectedMonthlyDays = []
        monthlySelectionType = .days
        selectedOrdinalPatterns = []
        yearlyDate = Date()
        weeklyTimes = [:]
        hasRecurrenceEndDate = false
        recurrenceEndDate = Date().addingTimeInterval(86400 * 30)
        trackInStatistics = true
        hasRewardPoints = false
        rewardPoints = 5
        useCustomPoints = false
        customPointsText = "5"
        taskId = nil
    }
    
    static var shared: TaskFormViewModel?
}