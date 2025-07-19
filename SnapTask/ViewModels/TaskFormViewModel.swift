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

// MARK: - Contextual Recurrence Types
enum ContextualRecurrenceType {
    // For today scope
    case everyDay
    case everyTwoDays
    case everyThreeDays
    case everyWeekday
    case everyWeekend
    
    // For week scope
    case everyWeek
    case everyTwoWeeks
    case everyThreeWeeks
    case everyMonthFromWeek
    
    // For month scope
    case everyMonth
    case everyTwoMonths
    case everyThreeMonths
    case everySixMonths
    
    // For year scope
    case everyYear
    case everyTwoYears
    case everyThreeYears
    
    var localizedString: String {
        switch self {
        case .everyDay: return "every_day".localized
        case .everyTwoDays: return "every_2_days".localized
        case .everyThreeDays: return "every_3_days".localized
        case .everyWeekday: return "every_weekday".localized
        case .everyWeekend: return "every_weekend".localized
        case .everyWeek: return "every_week".localized
        case .everyTwoWeeks: return "every_2_weeks".localized
        case .everyThreeWeeks: return "every_3_weeks".localized
        case .everyMonthFromWeek: return "every_month".localized
        case .everyMonth: return "every_month".localized
        case .everyTwoMonths: return "every_2_months".localized
        case .everyThreeMonths: return "every_3_months".localized
        case .everySixMonths: return "every_6_months".localized
        case .everyYear: return "every_year".localized
        case .everyTwoYears: return "every_2_years".localized
        case .everyThreeYears: return "every_3_years".localized
        }
    }
    
    static func availableTypes(for timeScope: TaskTimeScope) -> [ContextualRecurrenceType] {
        switch timeScope {
        case .today:
            return [.everyDay, .everyTwoDays, .everyThreeDays, .everyWeekday, .everyWeekend]
        case .week:
            return [.everyWeek, .everyTwoWeeks, .everyThreeWeeks, .everyMonthFromWeek]
        case .month:
            return [.everyMonth, .everyTwoMonths, .everyThreeMonths, .everySixMonths]
        case .year:
            return [.everyYear, .everyTwoYears, .everyThreeYears]
        case .longTerm:
            return [] // Long term tasks don't have recurrence
        }
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
    @Published var contextualRecurrenceType: ContextualRecurrenceType = .everyDay
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
    
    // MARK: - TimeScope Properties
    @Published var selectedTimeScope: TaskTimeScope = .today
    @Published var selectedWeekDate: Date = Date()
    @Published var selectedMonthDate: Date = Date()
    @Published var selectedYearDate: Date = Date()
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
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
        setupContextualRecurrenceObserver()
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
    
    private func setupContextualRecurrenceObserver() {
        // Observer quando cambia il timeScope
        $selectedTimeScope
            .sink { [weak self] newTimeScope in
                guard let self = self else { return }
                self.updateContextualRecurrenceType(for: newTimeScope)
                self.updateDefaultSpecificTime(for: newTimeScope)
            }
            .store(in: &cancellables)
        
        // Observer quando si attiva la ricorrenza
        $isRecurring
            .sink { [weak self] isRecurring in
                guard let self = self, isRecurring else { return }
                self.updateContextualRecurrenceType(for: self.selectedTimeScope)
            }
            .store(in: &cancellables)
    }
    
    private func updateContextualRecurrenceType(for timeScope: TaskTimeScope) {
        let availableTypes = ContextualRecurrenceType.availableTypes(for: timeScope)
        if !availableTypes.isEmpty {
            contextualRecurrenceType = availableTypes[0] // Set default to first option
        }
    }
    
    private func updateDefaultSpecificTime(for timeScope: TaskTimeScope) {
        // Only set hasSpecificTime to true by default for today scope
        if timeScope == .today {
            hasSpecificTime = true
        } else {
            hasSpecificTime = false
        }
    }
    
    var isValid: Bool {
        !name.isEmpty
    }
    
    // MARK: - TimeScope Helper Properties
    
    var timeScopeDescription: String {
        switch selectedTimeScope {
        case .today:
            return "task_happens_today".localized
        case .week:
            return "task_happens_this_week".localized
        case .month:
            return "task_happens_this_month".localized
        case .year:
            return "task_happens_this_year".localized
        case .longTerm:
            return "long_term_goal".localized
        }
    }
    
    var selectedPeriodDisplayText: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            formatter.dateStyle = .medium
            return formatter.string(from: startDate)
        case .week:
            let weekStart = calendar.startOfWeek(for: selectedWeekDate)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            formatter.dateStyle = .short
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        case .month:
            return "\(calendar.monthSymbols[selectedMonth - 1]) \(selectedYear)"
        case .year:
            return String(selectedYear)
        case .longTerm:
            return "long_term_goal".localized
        }
    }
    
    var selectedWeekRangeText: String {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: selectedWeekDate)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(currentYear...(currentYear + 10))
    }
    
    var availableContextualRecurrenceTypes: [ContextualRecurrenceType] {
        return ContextualRecurrenceType.availableTypes(for: selectedTimeScope)
    }
    
    var recurrenceDisplayText: String {
        if selectedTimeScope == .longTerm {
            return "no_recurrence_long_term".localized
        }
        return contextualRecurrenceType.localizedString
    }
    
    var isDailyRecurrence: Bool {
        get { recurrenceType == .daily }
        set { recurrenceType = newValue ? .daily : .weekly }
    }
    
    var shouldShowRecurrenceOption: Bool {
        // Nascondiamo l'opzione ricorrenza per le task a lungo termine
        return selectedTimeScope != .longTerm
    }
    
    func createTask() -> TodoTask {
        let id = taskId ?? UUID()
        
        let taskStartTime: Date
        let scopeStartDate: Date?
        let scopeEndDate: Date?
        
        // Handle different time scopes with selected periods
        switch selectedTimeScope {
        case .today:
            taskStartTime = hasSpecificTime ? startDate : Calendar.current.startOfDay(for: startDate)
            scopeStartDate = nil
            scopeEndDate = nil
        case .week:
            let weekStart = Calendar.current.startOfWeek(for: selectedWeekDate)
            taskStartTime = weekStart
            scopeStartDate = weekStart
            scopeEndDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)
        case .month:
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth
            components.day = 1
            let monthStart = calendar.date(from: components) ?? Date()
            taskStartTime = monthStart
            scopeStartDate = monthStart
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            scopeEndDate = calendar.date(byAdding: .day, value: -1, to: monthEnd!)
        case .year:
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = 1
            components.day = 1
            let yearStart = calendar.date(from: components) ?? Date()
            taskStartTime = yearStart
            scopeStartDate = yearStart
            var endComponents = DateComponents()
            endComponents.year = selectedYear
            endComponents.month = 12
            endComponents.day = 31
            scopeEndDate = calendar.date(from: endComponents)
        case .longTerm:
            taskStartTime = Calendar.current.startOfDay(for: startDate)
            scopeStartDate = nil
            scopeEndDate = nil
        }
        
        let recurrence: Recurrence? = isRecurring ? createContextualRecurrence(startDate: taskStartTime) : nil
        
        return TodoTask(
            id: id,
            name: name,
            description: description.isEmpty ? nil : description,
            location: location,
            startTime: taskStartTime,
            hasSpecificTime: hasSpecificTime && selectedTimeScope == .today,
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
            hasNotification: hasNotification && selectedTimeScope == .today,
            timeScope: selectedTimeScope,
            scopeStartDate: scopeStartDate,
            scopeEndDate: scopeEndDate
        )
    }
    
    private func createContextualRecurrence(startDate: Date) -> Recurrence? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: startDate)
        let endDate = hasRecurrenceEndDate ? recurrenceEndDate : nil
        
        switch contextualRecurrenceType {
        // Today scope recurrences
        case .everyDay:
            return Recurrence(type: .daily, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyTwoDays:
            // TODO: Implement interval-based daily recurrence
            return Recurrence(type: .daily, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyThreeDays:
            // TODO: Implement interval-based daily recurrence
            return Recurrence(type: .daily, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyWeekday:
            return Recurrence(type: .weekly(days: [2, 3, 4, 5, 6]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyWeekend:
            return Recurrence(type: .weekly(days: [1, 7]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        
        // Week scope recurrences
        case .everyWeek:
            let weekday = calendar.component(.weekday, from: startDate)
            return Recurrence(type: .weekly(days: [weekday]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyTwoWeeks:
            // TODO: Implement interval-based weekly recurrence
            let weekday = calendar.component(.weekday, from: startDate)
            return Recurrence(type: .weekly(days: [weekday]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyThreeWeeks:
            // TODO: Implement interval-based weekly recurrence
            let weekday = calendar.component(.weekday, from: startDate)
            return Recurrence(type: .weekly(days: [weekday]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyMonthFromWeek:
            // TODO: Implement interval-based weekly recurrence
            let weekday = calendar.component(.weekday, from: startDate)
            return Recurrence(type: .weekly(days: [weekday]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        
        // Month scope recurrences
        case .everyMonth:
            let day = calendar.component(.day, from: startDate)
            return Recurrence(type: .monthly(days: [day]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyTwoMonths:
            // TODO: Implement interval-based monthly recurrence
            let day = calendar.component(.day, from: startDate)
            return Recurrence(type: .monthly(days: [day]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyThreeMonths:
            // TODO: Implement interval-based monthly recurrence
            let day = calendar.component(.day, from: startDate)
            return Recurrence(type: .monthly(days: [day]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everySixMonths:
            // TODO: Implement interval-based monthly recurrence
            let day = calendar.component(.day, from: startDate)
            return Recurrence(type: .monthly(days: [day]), startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        
        // Year scope recurrences
        case .everyYear:
            return Recurrence(type: .yearly, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyTwoYears:
            // TODO: Implement interval-based yearly recurrence
            return Recurrence(type: .yearly, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        case .everyThreeYears:
            // TODO: Implement interval-based yearly recurrence
            return Recurrence(type: .yearly, startDate: startDate, endDate: endDate, trackInStatistics: trackInStatistics)
        }
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
        contextualRecurrenceType = .everyDay
        selectedDays = []
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
        selectedTimeScope = .today
        selectedWeekDate = Date()
        selectedMonthDate = Date()
        selectedYearDate = Date()
        selectedMonth = Calendar.current.component(.month, from: Date())
        selectedYear = Calendar.current.component(.year, from: Date())
        taskId = nil
    }
    
    static var shared: TaskFormViewModel?
}