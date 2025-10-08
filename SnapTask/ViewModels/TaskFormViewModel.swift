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
        case .all:
            return [] // "All" è solo vista, nessuna ricorrenza contestuale
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

enum WeekRecurrenceMode: String, CaseIterable {
    case everyNWeeks
    case specificWeeksOfMonth
    case moduloPattern
}

enum MonthRecurrenceMode: String, CaseIterable {
    case everyNMonths
    case specificMonths
}

enum YearRecurrenceMode: String, CaseIterable {
    case everyNYears
    case moduloPattern
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
    @Published var notificationLeadTimeMinutes: Int = 0
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: RecurrenceType = .daily
    @Published var contextualRecurrenceType: ContextualRecurrenceType = .everyDay
    @Published var selectedDays: Set<Int> = []
    @Published var selectedMonthlyDays: Set<Int> = []
    @Published var monthlySelectionType: MonthlySelectionType = .days
    @Published var selectedOrdinalPatterns: Set<Recurrence.OrdinalPattern> = []
    @Published var yearlyDate: Date = Date()
    @Published var weeklyTimes: [Int: Date] = [:]
    @Published var dayInterval: Int = 1
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
    @Published var autoCarryOver: Bool = false

    // MARK: - TimeScope Properties
    @Published var selectedTimeScope: TaskTimeScope = .today
    @Published var selectedWeekDate: Date = Date()
    @Published var selectedMonthDate: Date = Date()
    @Published var selectedYearDate: Date = Date()
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // MARK: - Contextual Recurrence (NEW)
    @Published var weekRecurrenceMode: WeekRecurrenceMode = .everyNWeeks
    @Published var weekInterval: Int = 1
    @Published var weekSelectedOrdinals: Set<Int> = [] // 1..5 and -1 for last
    @Published var weekModuloK: Int = 2
    @Published var weekModuloOffset: Int = 0
    
    @Published var monthRecurrenceMode: MonthRecurrenceMode = .everyNMonths
    @Published var monthInterval: Int = 1
    @Published var monthSelectedMonths: Set<Int> = [] // 1..12
    
    @Published var yearRecurrenceMode: YearRecurrenceMode = .everyNYears
    @Published var yearInterval: Int = 1
    @Published var yearModuloK: Int = 2
    @Published var yearModuloOffset: Int = 0
    
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
        case .all:
            return "" // Non usato nel form
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
        case .all:
            return "" // Non usato nel form
        }
    }
    
    // Title for the Time Scope menu button
    var timeScopeTitle: String {
        switch selectedTimeScope {
        case .today:
            let cal = Calendar.current
            if cal.isDateInToday(startDate) {
                return TaskTimeScope.today.displayName
            } else {
                let f = DateFormatter()
                // Localized format like "7 Sep 2025"
                f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
                return f.string(from: startDate)
            }
        default:
            return selectedTimeScope.displayName
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
        return contextualRecurrenceSummary
    }
    
    var contextualRecurrenceSummary: String {
        switch selectedTimeScope {
        case .today:
            return contextualRecurrenceType.localizedString
        case .week:
            switch weekRecurrenceMode {
            case .everyNWeeks:
                return weekInterval == 1 ? "Ogni settimana" : "Ogni \(weekInterval) settimane"
            case .specificWeeksOfMonth:
                if weekSelectedOrdinals.isEmpty { return "Seleziona settimane del mese" }
                let ordinals = weekSelectedOrdinals
                    .sorted(by: { ordinalSortOrder($0) < ordinalSortOrder($1) })
                    .map { ordinalDisplay($0) }
                    .joined(separator: ", ")
                return "Settimane del mese: \(ordinals)"
            case .moduloPattern:
                if weekModuloK == 2 {
                    return weekModuloOffset == 0 ? "Settimane pari" : "Settimane dispari"
                } else {
                    return "Ogni \(weekModuloK)-esima settimana (offset \(weekModuloOffset + 1))"
                }
            }
        case .month:
            switch monthRecurrenceMode {
            case .everyNMonths:
                return monthInterval == 1 ? "Ogni mese" : "Ogni \(monthInterval) mesi"
            case .specificMonths:
                if monthSelectedMonths.isEmpty { return "Seleziona mesi specifici" }
                let months = monthSelectedMonths.sorted().map { Calendar.current.monthSymbols[$0 - 1].capitalized }
                return "Mesi: \(months.joined(separator: ", "))"
            }
        case .year:
            switch yearRecurrenceMode {
            case .everyNYears:
                return yearInterval == 1 ? "Ogni anno" : "Ogni \(yearInterval) anni"
            case .moduloPattern:
                if yearModuloK == 2 {
                    return yearModuloOffset == 0 ? "Anni pari" : "Anni dispari"
                } else {
                    return "Ogni \(yearModuloK) anni (offset \(yearModuloOffset + 1))"
                }
            }
        case .longTerm:
            return "Nessuna ricorrenza"
        case .all:
            return "" // Non applicabile nel form
        }
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
            // Use specific time if set, otherwise use week start
            taskStartTime = hasSpecificTime ? 
                Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: startDate), 
                                    minute: Calendar.current.component(.minute, from: startDate), 
                                    second: 0, 
                                    of: weekStart) ?? weekStart : weekStart
            scopeStartDate = weekStart
            scopeEndDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)
        case .month:
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth
            components.day = 1
            let monthStart = calendar.date(from: components) ?? Date()
            // Use specific time if set, otherwise use month start
            taskStartTime = hasSpecificTime ? 
                calendar.date(bySettingHour: calendar.component(.hour, from: startDate), 
                            minute: calendar.component(.minute, from: startDate), 
                            second: 0, 
                            of: monthStart) ?? monthStart : monthStart
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
            // Use specific time if set, otherwise use year start
            taskStartTime = hasSpecificTime ? 
                calendar.date(bySettingHour: calendar.component(.hour, from: startDate), 
                            minute: calendar.component(.minute, from: startDate), 
                            second: 0, 
                            of: yearStart) ?? yearStart : yearStart
            scopeStartDate = yearStart
            var endComponents = DateComponents()
            endComponents.year = selectedYear
            endComponents.month = 12
            endComponents.day = 31
            scopeEndDate = calendar.date(from: endComponents)
        case .longTerm:
            taskStartTime = hasSpecificTime ? startDate : Calendar.current.startOfDay(for: startDate)
            scopeStartDate = nil
            scopeEndDate = nil
        case .all:
            // Tratta "All" come "Today" nel form per evitare task con scope non valido
            taskStartTime = hasSpecificTime ? startDate : Calendar.current.startOfDay(for: startDate)
            scopeStartDate = nil
            scopeEndDate = nil
        }
        
        let recurrence: Recurrence?
        if isRecurring {
            if selectedTimeScope == .today {
                recurrence = createEnhancedRecurrence(startDate: taskStartTime)
            } else {
                recurrence = createContextualRecurrence(startDate: taskStartTime)
            }
        } else {
            recurrence = nil
        }
        
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
            hasNotification: hasNotification,
            timeScope: (selectedTimeScope == .all ? .today : selectedTimeScope),
            scopeStartDate: scopeStartDate,
            scopeEndDate: scopeEndDate,
            notificationLeadTimeMinutes: notificationLeadTimeMinutes,
            autoCarryOver: autoCarryOver
        )
    }
    
    private func createEnhancedRecurrence(startDate: Date) -> Recurrence? {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDate = hasRecurrenceEndDate ? calendar.startOfDay(for: recurrenceEndDate) : nil
        
        switch recurrenceType {
        case .daily:
            var rec = Recurrence(type: .daily, startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            if dayInterval > 1 { rec.dayInterval = dayInterval }
            return rec
            
        case .weekly:
            var days = selectedDays
            if days.isEmpty {
                // Default to weekday of startDay if user didn't pick any
                let wd = calendar.component(.weekday, from: startDay)
                days.insert(wd)
            }
            return Recurrence(type: .weekly(days: days), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            
        case .monthly:
            if monthlySelectionType == .days {
                var days = selectedMonthlyDays
                if days.isEmpty {
                    let d = calendar.component(.day, from: startDay)
                    days.insert(d)
                }
                return Recurrence(type: .monthly(days: days), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            } else {
                let patterns = selectedOrdinalPatterns
                if patterns.isEmpty {
                    // Fallback: first occurrence of the weekday of startDay
                    let wd = calendar.component(.weekday, from: startDay)
                    let pattern = Recurrence.OrdinalPattern(ordinal: 1, weekday: wd)
                    return Recurrence(type: .monthlyOrdinal(patterns: [pattern]), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
                } else {
                    return Recurrence(type: .monthlyOrdinal(patterns: patterns), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
                }
            }
            
        case .yearly:
            // Anchor yearly recurrence to the chosen yearlyDate’s month/day
            let yearlyStart = calendar.startOfDay(for: yearlyDate)
            return Recurrence(type: .yearly, startDate: yearlyStart, endDate: endDate, trackInStatistics: trackInStatistics)
        }
    }
    
    private func createContextualRecurrence(startDate: Date) -> Recurrence? {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDate = hasRecurrenceEndDate ? calendar.startOfDay(for: recurrenceEndDate) : nil
        
        switch selectedTimeScope {
        case .week:
            // Build WEEK-scope recurrence using WeekRecurrenceMode (ignore legacy contextualRecurrenceType here)
            let weekday = calendar.component(.weekday, from: startDay)
            var rec = Recurrence(
                type: .weekly(days: [weekday]),
                startDate: startDay,
                endDate: endDate,
                trackInStatistics: trackInStatistics
            )
            switch weekRecurrenceMode {
            case .everyNWeeks:
                rec.weekInterval = max(1, weekInterval)
            case .specificWeeksOfMonth:
                // Use ordinals of week-of-month (1..5, -1=last) to show in specific weeks each month
                rec.weekSelectedOrdinals = weekSelectedOrdinals.isEmpty ? [weekOrdinalInMonth(startDay)] : weekSelectedOrdinals
                rec.monthInterval = 1
            case .moduloPattern:
                rec.weekModuloK = max(2, weekModuloK)
                rec.weekModuloOffset = max(0, min(weekModuloK - 1, weekModuloOffset))
            }
            return rec
            
        case .month:
            // Build MONTH-scope recurrence using MonthRecurrenceMode
            let day = calendar.component(.day, from: startDay)
            var rec = Recurrence(
                type: .monthly(days: [day]),
                startDate: startDay,
                endDate: endDate,
                trackInStatistics: trackInStatistics
            )
            switch monthRecurrenceMode {
            case .everyNMonths:
                rec.monthInterval = max(1, monthInterval)
            case .specificMonths:
                rec.monthSelectedMonths = monthSelectedMonths.isEmpty ? [calendar.component(.month, from: startDay)] : monthSelectedMonths
            }
            return rec
            
        case .year:
            // Build YEAR-scope recurrence using YearRecurrenceMode
            var rec = Recurrence(
                type: .yearly,
                startDate: startDay,
                endDate: endDate,
                trackInStatistics: trackInStatistics
            )
            switch yearRecurrenceMode {
            case .everyNYears:
                rec.yearInterval = max(1, yearInterval)
            case .moduloPattern:
                rec.yearModuloK = max(2, yearModuloK)
                rec.yearModuloOffset = max(0, min(yearModuloK - 1, yearModuloOffset))
            }
            return rec
            
        case .today:
            // For daily scope, keep using the enhanced editor (already uses weekly/monthly/monthlyOrdinal/yearly concrete patterns)
            // Legacy contextual types like everyTwoDays can be extended later if needed.
            return createEnhancedRecurrence(startDate: startDay)
            
        case .longTerm:
            return nil
        case .all:
            return nil // Nessuna ricorrenza in modalità All nel form
        }
    }
    
    private func weekOrdinalInMonth(_ date: Date) -> Int {
        let calendar = Calendar.current
        let ord = calendar.component(.weekOfMonth, from: date)
        // Check if it's last week of the month
        let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: calendar.startOfWeek(for: date))!
        let isLast = calendar.component(.month, from: nextWeekStart) != calendar.component(.month, from: date)
        return isLast ? -1 : ord
    }

    func addSubtask(name: String) {
        let subtask = Subtask(id: UUID(), name: name, isCompleted: false)
        subtasks.append(subtask)
    }
    
    func removeSubtask(at offsets: IndexSet) {
        subtasks.remove(atOffsets: offsets)
    }
    
    func removeSubtask(withId id: UUID) {
        subtasks.removeAll { $0.id == id }
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
        notificationLeadTimeMinutes = 0
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
        dayInterval = 1
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
        autoCarryOver = false
    }
    
    static var shared: TaskFormViewModel?
    
    private func ordinalDisplay(_ value: Int) -> String {
        switch value {
        case 1: return "1ª"
        case 2: return "2ª"
        case 3: return "3ª"
        case 4: return "4ª"
        case 5: return "5ª"
        case -1: return "ultima"
        default: return "\(value)ª"
        }
    }
    
    private func ordinalSortOrder(_ value: Int) -> Int {
        // -1 (last) should come after 5
        return value == -1 ? 6 : value
    }
}