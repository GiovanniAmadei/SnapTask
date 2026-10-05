import Foundation
import Combine
import UIKit
import WidgetKit

enum FinanceExpenseBreakdownKey: Hashable, Identifiable {
    case builtIn(FinanceCategory)
    case custom(UUID)

    var id: String {
        switch self {
        case .builtIn(let category):
            return "builtIn:\(category.rawValue)"
        case .custom(let id):
            return "custom:\(id.uuidString)"
        }
    }
}

@MainActor
class FinanceManager: ObservableObject {
    static let shared = FinanceManager()
    
    @Published var entries: [FinanceEntry] = []
    @Published var budgets: [FinanceBudget] = []
    @Published var financialGoals: [FinancialGoal] = []
    @Published var startingBalance: Double = 0
    @Published var monthlyBudgetTarget: Double = 0
    @Published var savingsGoalPercent: Double = 0
    @Published var savingsGoalAmount: Double = 0
    @Published var savingsGoalIsPercent: Bool = true
    @Published var monthlyIncomeGoal: Double = 0
    @Published var customCategories: [CustomFinanceCategory] = []
    @Published var categoryOverrides: [FinanceCategoryOverride] = []
    @Published var hiddenBuiltInCategories: Set<String> = []
    @Published var selectedCurrency: SupportedCurrency = .eur
    
    private let entriesKey = "savedFinanceEntries"
    private let budgetsKey = "savedFinanceBudgets"
    private let financialGoalsKey = "savedFinancialGoals"
    private let startingBalanceKey = "financeStartingBalance"
    private let monthlyBudgetTargetKey = "financeMonthlyBudgetTarget"
    private let savingsGoalPercentKey = "financeSavingsGoalPercent"
    private let savingsGoalAmountKey = "financeSavingsGoalAmount"
    private let savingsGoalIsPercentKey = "financeSavingsGoalIsPercent"
    private let monthlyIncomeGoalKey = "financeMonthlyIncomeGoal"
    private let customCategoriesKey = "financeCustomCategories"
    private let categoryOverridesKey = "financeCategoryOverrides"
    private let hiddenBuiltInCategoriesKey = "financeHiddenBuiltInCategories"
    private let selectedCurrencyKey = "financeSelectedCurrency"
    private var cancellables: Set<AnyCancellable> = []
    private var isApplyingCloudSettings: Bool = false
    
    private init() {
        loadAll()
        setupCloudKitSettingsObserver()
    }

    private func setupCloudKitSettingsObserver() {
        NotificationCenter.default.publisher(for: .cloudKitSettingsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let settings = notification.object as? [String: Any] else { return }
                self.applyRemoteFinanceSettings(settings)
            }
            .store(in: &cancellables)
    }

    private func applyRemoteFinanceSettings(_ settings: [String: Any]) {
        isApplyingCloudSettings = true
        defer { isApplyingCloudSettings = false }

        if let startingBalance = (settings["finance_startingBalance"] as? Double) {
            self.startingBalance = startingBalance
            UserDefaults.standard.set(startingBalance, forKey: startingBalanceKey)
        } else if let startingBalance = (settings["finance_startingBalance"] as? NSNumber)?.doubleValue {
            self.startingBalance = startingBalance
            UserDefaults.standard.set(startingBalance, forKey: startingBalanceKey)
        }

        if let monthlyBudgetTarget = (settings["finance_monthlyBudgetTarget"] as? Double) {
            self.monthlyBudgetTarget = monthlyBudgetTarget
            UserDefaults.standard.set(monthlyBudgetTarget, forKey: monthlyBudgetTargetKey)
        } else if let monthlyBudgetTarget = (settings["finance_monthlyBudgetTarget"] as? NSNumber)?.doubleValue {
            self.monthlyBudgetTarget = monthlyBudgetTarget
            UserDefaults.standard.set(monthlyBudgetTarget, forKey: monthlyBudgetTargetKey)
        }

        if let savingsGoalPercent = (settings["finance_savingsGoalPercent"] as? Double) {
            self.savingsGoalPercent = savingsGoalPercent
            UserDefaults.standard.set(savingsGoalPercent, forKey: savingsGoalPercentKey)
        } else if let savingsGoalPercent = (settings["finance_savingsGoalPercent"] as? NSNumber)?.doubleValue {
            self.savingsGoalPercent = savingsGoalPercent
            UserDefaults.standard.set(savingsGoalPercent, forKey: savingsGoalPercentKey)
        }

        if let savingsGoalAmount = (settings["finance_savingsGoalAmount"] as? Double) {
            self.savingsGoalAmount = savingsGoalAmount
            UserDefaults.standard.set(savingsGoalAmount, forKey: savingsGoalAmountKey)
        } else if let savingsGoalAmount = (settings["finance_savingsGoalAmount"] as? NSNumber)?.doubleValue {
            self.savingsGoalAmount = savingsGoalAmount
            UserDefaults.standard.set(savingsGoalAmount, forKey: savingsGoalAmountKey)
        }

        if let savingsGoalIsPercent = (settings["finance_savingsGoalIsPercent"] as? Bool) {
            self.savingsGoalIsPercent = savingsGoalIsPercent
            UserDefaults.standard.set(savingsGoalIsPercent, forKey: savingsGoalIsPercentKey)
        } else if let savingsGoalIsPercent = (settings["finance_savingsGoalIsPercent"] as? NSNumber)?.boolValue {
            self.savingsGoalIsPercent = savingsGoalIsPercent
            UserDefaults.standard.set(savingsGoalIsPercent, forKey: savingsGoalIsPercentKey)
        }

        if let monthlyIncomeGoal = (settings["finance_monthlyIncomeGoal"] as? Double) {
            self.monthlyIncomeGoal = monthlyIncomeGoal
            UserDefaults.standard.set(monthlyIncomeGoal, forKey: monthlyIncomeGoalKey)
        } else if let monthlyIncomeGoal = (settings["finance_monthlyIncomeGoal"] as? NSNumber)?.doubleValue {
            self.monthlyIncomeGoal = monthlyIncomeGoal
            UserDefaults.standard.set(monthlyIncomeGoal, forKey: monthlyIncomeGoalKey)
        }

        if let currencyRaw = settings["finance_selectedCurrency"] as? String,
           let currency = SupportedCurrency(rawValue: currencyRaw) {
            self.selectedCurrency = currency
            UserDefaults.standard.set(currencyRaw, forKey: selectedCurrencyKey)
        }

        // Apply category overrides
        if let overridesJSON = settings["finance_categoryOverrides"] as? String,
           let data = overridesJSON.data(using: .utf8),
           let overrides = try? JSONDecoder().decode([FinanceCategoryOverride].self, from: data) {
            self.categoryOverrides = overrides
            if let encoded = try? JSONEncoder().encode(overrides) {
                UserDefaults.standard.set(encoded, forKey: categoryOverridesKey)
            }
        }

        // Apply hidden built-in categories
        if let hidden = settings["finance_hiddenBuiltInCategories"] as? [String] {
            self.hiddenBuiltInCategories = Set(hidden)
            UserDefaults.standard.set(hidden, forKey: hiddenBuiltInCategoriesKey)
        }

        notifyFinanceChanged()
    }

    private func syncFinanceSettingsToCloud() {
        guard !isApplyingCloudSettings else { return }
        guard CloudKitService.shared.isCloudKitEnabled else { return }

        var payload: [String: Any] = [
            "finance_startingBalance": startingBalance,
            "finance_monthlyBudgetTarget": monthlyBudgetTarget,
            "finance_savingsGoalPercent": savingsGoalPercent,
            "finance_savingsGoalAmount": savingsGoalAmount,
            "finance_savingsGoalIsPercent": savingsGoalIsPercent,
            "finance_monthlyIncomeGoal": monthlyIncomeGoal,
            "finance_selectedCurrency": selectedCurrency.rawValue,
            "lastUpdated": Date().timeIntervalSince1970,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]

        // Sync category overrides (built-in category customisations)
        if let overridesData = try? JSONEncoder().encode(categoryOverrides),
           let overridesJSON = String(data: overridesData, encoding: .utf8) {
            payload["finance_categoryOverrides"] = overridesJSON
        }

        // Sync hidden built-in categories
        payload["finance_hiddenBuiltInCategories"] = Array(hiddenBuiltInCategories)

        CloudKitService.shared.saveAppSettings(payload)
    }
    
    // MARK: - Starting Balance
    
    func setStartingBalance(_ amount: Double) {
        startingBalance = amount
        UserDefaults.standard.set(amount, forKey: startingBalanceKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setMonthlyBudgetTarget(_ amount: Double) {
        monthlyBudgetTarget = amount
        UserDefaults.standard.set(amount, forKey: monthlyBudgetTargetKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setSavingsGoalPercent(_ percent: Double) {
        savingsGoalPercent = min(max(percent, 0), 100)
        UserDefaults.standard.set(savingsGoalPercent, forKey: savingsGoalPercentKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setSavingsGoalAmount(_ amount: Double) {
        savingsGoalAmount = max(amount, 0)
        UserDefaults.standard.set(savingsGoalAmount, forKey: savingsGoalAmountKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setSavingsGoalIsPercent(_ isPercent: Bool) {
        savingsGoalIsPercent = isPercent
        UserDefaults.standard.set(isPercent, forKey: savingsGoalIsPercentKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setMonthlyIncomeGoal(_ amount: Double) {
        monthlyIncomeGoal = amount
        UserDefaults.standard.set(amount, forKey: monthlyIncomeGoalKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func setSelectedCurrency(_ currency: SupportedCurrency) {
        selectedCurrency = currency
        UserDefaults.standard.set(currency.rawValue, forKey: selectedCurrencyKey)
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    // MARK: - Custom Category CRUD with CloudKit
    
    func addCustomCategory(_ category: CustomFinanceCategory) {
        guard !customCategories.contains(where: { $0.id == category.id }) else { return }
        customCategories.append(category)
        saveCustomCategories()
        notifyFinanceChanged()
        CloudKitService.shared.saveCustomFinanceCategory(category)
    }
    
    func updateCustomCategory(_ category: CustomFinanceCategory) {
        guard let index = customCategories.firstIndex(where: { $0.id == category.id }) else { return }
        customCategories[index] = category
        saveCustomCategories()
        notifyFinanceChanged()
        CloudKitService.shared.saveCustomFinanceCategory(category)
    }
    
    /// Removes a custom category. With `reassignEntries` the movements that used it fall back to
    /// "Other" and its budgets are dropped, so nothing is left pointing to a category that no longer exists.
    func removeCustomCategory(_ category: CustomFinanceCategory, reassignEntries: Bool = false) {
        if reassignEntries {
            let now = Date()
            var moved: [FinanceEntry] = []
            for index in entries.indices where entries[index].customCategoryId == category.id {
                entries[index].customCategoryId = nil
                entries[index].category = .other
                entries[index].lastModifiedDate = now
                moved.append(entries[index])
            }
            if !moved.isEmpty {
                saveEntries()
                moved.forEach { CloudKitService.shared.saveFinanceEntry($0) }
            }
            for budget in budgets where budget.customCategoryId == category.id {
                removeBudget(budget)
            }
        }
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()
        notifyFinanceChanged()
        CloudKitService.shared.deleteCustomFinanceCategory(category)
    }
    
    func customCategory(for id: UUID?) -> CustomFinanceCategory? {
        guard let id = id else { return nil }
        return customCategories.first { $0.id == id }
    }
    
    // MARK: - Built-in Category Overrides
    
    func setCategoryOverride(_ category: FinanceCategory, customName: String?, customIcon: String?, customColorHex: String?) {
        var list = categoryOverrides.filter { $0.categoryRawValue != category.rawValue }
        if customName != nil || customIcon != nil || customColorHex != nil {
            list.append(FinanceCategoryOverride(
                categoryRawValue: category.rawValue,
                customName: customName,
                customIcon: customIcon,
                customColorHex: customColorHex
            ))
        }
        categoryOverrides = list
        saveCategoryOverrides()
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }

    func setCategoryOverride(_ category: FinanceCategory, customName: String?, customIcon: String?) {
        let existingColor = override(for: category)?.customColorHex
        setCategoryOverride(category, customName: customName, customIcon: customIcon, customColorHex: existingColor)
    }
    
    // MARK: - Hidden Built-in Categories
    
    func hideBuiltInCategory(_ category: FinanceCategory) {
        hiddenBuiltInCategories.insert(category.rawValue)
        saveHiddenBuiltInCategories()
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func restoreBuiltInCategory(_ category: FinanceCategory) {
        hiddenBuiltInCategories.remove(category.rawValue)
        saveHiddenBuiltInCategories()
        notifyFinanceChanged()
        syncFinanceSettingsToCloud()
    }
    
    func isHidden(_ category: FinanceCategory) -> Bool {
        hiddenBuiltInCategories.contains(category.rawValue)
    }
    
    var visibleExpenseCategories: [FinanceCategory] {
        FinanceCategory.allCases.filter { !$0.isIncomeCategory && !isHidden($0) }
    }
    
    var visibleIncomeCategories: [FinanceCategory] {
        FinanceCategory.allCases.filter { $0.isIncomeCategory && !isHidden($0) }
    }
    
    private func saveHiddenBuiltInCategories() {
        let array = Array(hiddenBuiltInCategories)
        UserDefaults.standard.set(array, forKey: hiddenBuiltInCategoriesKey)
    }
    
    func override(for category: FinanceCategory) -> FinanceCategoryOverride? {
        categoryOverrides.first { $0.categoryRawValue == category.rawValue }
    }
    
    func displayName(for category: FinanceCategory) -> String {
        override(for: category)?.customName ?? category.displayName
    }
    
    func icon(for category: FinanceCategory) -> String {
        override(for: category)?.customIcon ?? category.icon
    }

    func colorHex(for category: FinanceCategory) -> String {
        override(for: category)?.customColorHex ?? baseColorHex(for: category)
    }

    func colorHex(for customCategoryId: UUID?) -> String {
        guard let id = customCategoryId else { return baseColorHex(for: .other) }
        if let custom = customCategory(for: id), let hex = custom.colorHex {
            return hex
        }
        // Fallback: deterministic stable hash (djb2) — Swift's hashValue is salted
        // per-process and changes every launch, so we use a stable string hash.
        let palette = [
            "#3B82F6", "#F97316", "#10B981", "#EF4444", "#8B5CF6", "#06B6D4",
            "#F59E0B", "#EC4899", "#84CC16", "#A855F7", "#14B8A6", "#6366F1"
        ]
        let stableHash = id.uuidString.unicodeScalars.reduce(5381) { (hash: UInt64, scalar) in
            (hash &* 31) &+ UInt64(scalar.value)
        }
        return palette[Int(stableHash % UInt64(palette.count))]
    }

    func budgetColorHex(for budget: FinanceBudget) -> String {
        if budget.customCategoryId != nil {
            return colorHex(for: budget.customCategoryId)
        }
        return colorHex(for: budget.category)
    }

    func expenseBreakdownColorHex(for key: FinanceExpenseBreakdownKey) -> String {
        switch key {
        case .builtIn(let category):
            return colorHex(for: category)
        case .custom(let id):
            return colorHex(for: id)
        }
    }

    func baseColorHex(for category: FinanceCategory) -> String {
        switch category {
        case .housing: return "#3B82F6"
        case .food: return "#F97316"
        case .transport: return "#10B981"
        case .health: return "#EF4444"
        case .entertainment: return "#8B5CF6"
        case .education: return "#06B6D4"
        case .clothing: return "#EC4899"
        case .utilities: return "#F59E0B"
        case .insurance: return "#6366F1"
        case .salary: return "#22C55E"
        case .freelance: return "#14B8A6"
        case .passive: return "#A855F7"
        case .gifts: return "#F43F5E"
        case .other: return "#94A3B8"
        }
    }
    
    func categoryDisplayName(for entry: FinanceEntry) -> String {
        if let customId = entry.customCategoryId,
           let custom = customCategory(for: customId) {
            return custom.name
        }
        return displayName(for: entry.category)
    }
    
    func categoryIcon(for entry: FinanceEntry) -> String {
        if let customId = entry.customCategoryId,
           let custom = customCategory(for: customId) {
            return custom.icon
        }
        return icon(for: entry.category)
    }

    func categoryColorHex(for entry: FinanceEntry) -> String {
        if let customId = entry.customCategoryId {
            return colorHex(for: customId)
        }
        return colorHex(for: entry.category)
    }

    func budgetDisplayName(for budget: FinanceBudget) -> String {
        if let custom = customCategory(for: budget.customCategoryId) {
            return custom.name
        }
        return displayName(for: budget.category)
    }

    func budgetIcon(for budget: FinanceBudget) -> String {
        if let custom = customCategory(for: budget.customCategoryId) {
            return custom.icon
        }
        return icon(for: budget.category)
    }
    
    /// Starting balance plus everything that already happened, counting every repetition of
    /// recurring entries (and ignoring movements dated in the future).
    var currentBalance: Double {
        let allTime = DateInterval(start: .distantPast, end: Date())
        let totalFlow = realizedOccurrences(in: allTime).reduce(0.0) { $0 + $1.entry.signedAmount }
        return startingBalance + totalFlow
    }
    
    // MARK: - Entry CRUD
    
    func addEntry(_ entry: FinanceEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        saveEntries()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinanceEntry(entry)
    }
    
    func updateEntry(_ entry: FinanceEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.lastModifiedDate = Date()
        entries[index] = updated
        saveEntries()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinanceEntry(updated)
    }
    
    /// Adds a copy of `entry` dated now (recurring entries keep their repetition).
    func duplicateEntry(_ entry: FinanceEntry) {
        let now = Date()
        let keepsEndDate = (entry.recurringEndDate ?? .distantPast) > now
        addEntry(FinanceEntry(
            name: entry.name,
            amount: entry.amount,
            type: entry.type,
            category: entry.category,
            customCategoryId: entry.customCategoryId,
            date: now,
            notes: entry.notes,
            isRecurring: entry.isRecurring,
            recurringFrequency: entry.recurringFrequency,
            recurringEndDate: keepsEndDate ? entry.recurringEndDate : nil,
            tags: entry.tags
        ))
    }
    
    func removeEntry(_ entry: FinanceEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
        notifyFinanceChanged()
        CloudKitService.shared.deleteFinanceEntry(entry)
    }
    
    // MARK: - Budget CRUD
    
    func addBudget(_ budget: FinanceBudget) {
        guard !budgets.contains(where: { $0.id == budget.id }) else { return }
        budgets.append(budget)
        saveBudgets()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinanceBudget(budget)
    }
    
    func updateBudget(_ budget: FinanceBudget) {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else { return }
        budgets[index] = budget
        saveBudgets()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinanceBudget(budget)
    }
    
    func removeBudget(_ budget: FinanceBudget) {
        budgets.removeAll { $0.id == budget.id }
        saveBudgets()
        notifyFinanceChanged()
        CloudKitService.shared.deleteFinanceBudget(budget)
    }
    
    // MARK: - Financial Goal CRUD
    
    func addFinancialGoal(_ goal: FinancialGoal) {
        guard !financialGoals.contains(where: { $0.id == goal.id }) else { return }
        financialGoals.append(goal)
        saveFinancialGoals()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinancialGoal(goal)
    }
    
    func updateFinancialGoal(_ goal: FinancialGoal) {
        guard let index = financialGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        var updated = goal
        updated.lastModifiedDate = Date()
        financialGoals[index] = updated
        saveFinancialGoals()
        notifyFinanceChanged()
        CloudKitService.shared.saveFinancialGoal(updated)
    }
    
    func removeFinancialGoal(_ goal: FinancialGoal) {
        financialGoals.removeAll { $0.id == goal.id }
        saveFinancialGoals()
        notifyFinanceChanged()
        CloudKitService.shared.deleteFinancialGoal(goal)
    }
    
    // MARK: - Queries: Entries
    
    func entries(for period: DateInterval) -> [FinanceEntry] {
        entries.filter { period.contains($0.date) }
    }
    
    func entries(ofType type: FinanceEntryType) -> [FinanceEntry] {
        entries.filter { $0.type == type }
    }
    
    func entries(forCategory category: FinanceCategory) -> [FinanceEntry] {
        entries.filter { $0.category == category }
    }
    
    var subscriptions: [FinanceEntry] {
        entries.filter { $0.type == .subscription && $0.isRecurring }
    }
    
    var activeSubscriptions: [FinanceEntry] {
        subscriptions.filter { entry in
            guard let endDate = entry.recurringEndDate else { return true }
            return endDate > Date()
        }
    }
    
    // MARK: - Occurrences (recurring entries expanded into dated movements)
    
    /// Dates on which `entry` happens inside `period` (start included, end excluded).
    /// One-off entries happen once; recurring entries repeat from their date until their end date.
    func occurrenceDates(of entry: FinanceEntry, in period: DateInterval) -> [Date] {
        guard entry.isRecurring, let frequency = entry.recurringFrequency else {
            return (entry.date >= period.start && entry.date < period.end) ? [entry.date] : []
        }
        
        let calendar = Calendar.current
        let step = frequency.calendarStep
        var limit = period.end
        if let endDate = entry.recurringEndDate,
           let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) {
            limit = min(limit, dayAfterEnd)
        }
        guard entry.date < limit else { return [] }
        
        // Skip straight to the first repetition that can fall inside the period.
        var index = 0
        if period.start > entry.date {
            let parts = calendar.dateComponents([step.component], from: entry.date, to: period.start)
            let elapsed: Int
            switch step.component {
            case .day: elapsed = parts.day ?? 0
            case .month: elapsed = parts.month ?? 0
            default: elapsed = parts.year ?? 0
            }
            index = max(elapsed / step.value - 1, 0)
        }
        
        var dates: [Date] = []
        while index < 10_000,
              let date = calendar.date(byAdding: step.component, value: step.value * index, to: entry.date),
              date < limit {
            if date >= period.start { dates.append(date) }
            index += 1
        }
        return dates
    }
    
    /// Every dated movement inside `period`, oldest first.
    func occurrences(in period: DateInterval) -> [FinanceOccurrence] {
        entries
            .flatMap { entry in
                occurrenceDates(of: entry, in: period).map { FinanceOccurrence(entry: entry, date: $0) }
            }
            .sorted { $0.date < $1.date }
    }
    
    /// Same as `occurrences(in:)` but only what already happened (up to now).
    func realizedOccurrences(in period: DateInterval) -> [FinanceOccurrence] {
        let now = Date()
        guard period.start < now else { return [] }
        return occurrences(in: DateInterval(start: period.start, end: min(period.end, now)))
    }
    
    /// Next time a recurring entry will be charged/received.
    func nextOccurrence(of entry: FinanceEntry, after date: Date = Date()) -> Date? {
        guard entry.isRecurring else { return nil }
        let horizon = Calendar.current.date(byAdding: .year, value: 2, to: date) ?? date.addingTimeInterval(2 * 365 * 86_400)
        return occurrenceDates(of: entry, in: DateInterval(start: date, end: horizon)).first
    }
    
    // MARK: - Calculations: Period
    
    func totalIncome(for period: DateInterval) -> Double {
        realizedOccurrences(in: period)
            .filter { !$0.entry.type.isOutflow }
            .reduce(0) { $0 + $1.entry.amount }
    }
    
    func totalExpenses(for period: DateInterval) -> Double {
        realizedOccurrences(in: period)
            .filter { $0.entry.type.isOutflow }
            .reduce(0) { $0 + $1.entry.amount }
    }
    
    func netFlow(for period: DateInterval) -> Double {
        totalIncome(for: period) - totalExpenses(for: period)
    }
    
    func savingsRate(for period: DateInterval) -> Double {
        let income = totalIncome(for: period)
        guard income > 0 else { return 0 }
        let net = netFlow(for: period)
        return max(net / income, 0)
    }
    
    // MARK: - Calculations: Monthly
    
    func currentMonthPeriod() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        return DateInterval(start: start, end: end)
    }
    
    /// Income received so far this month (recurring entries count when they actually come in).
    var monthlyIncome: Double {
        totalIncome(for: currentMonthPeriod())
    }

    /// Money spent so far this month (recurring entries count when they are actually charged).
    var monthlyExpenses: Double {
        totalExpenses(for: currentMonthPeriod())
    }
    
    var monthlySubscriptionCost: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyEquivalent }
    }
    
    var monthlyBurnRate: Double {
        monthlyExpenses
    }
    
    var monthlySavingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return max((monthlyIncome - monthlyExpenses) / monthlyIncome, 0)
    }
    
    // MARK: - Calculations: Yearly (YTD)
    
    func currentYearPeriod() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? now
        return DateInterval(start: start, end: end)
    }
    
    /// YTD = from Jan 1 of current year to now
    func yearToDatePeriod() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
        return DateInterval(start: start, end: now)
    }
    
    var yearlyIncome: Double {
        totalIncome(for: yearToDatePeriod())
    }
    
    var yearlyExpenses: Double {
        totalExpenses(for: yearToDatePeriod())
    }
    
    var yearlyNetFlow: Double {
        yearlyIncome - yearlyExpenses
    }
    
    var yearlySavingsRate: Double {
        guard yearlyIncome > 0 else { return 0 }
        return max(yearlyNetFlow / yearlyIncome, 0)
    }
    
    var yearlyAverageMonthlyIncome: Double {
        let calendar = Calendar.current
        let now = Date()
        let monthsElapsed = max(calendar.component(.month, from: now), 1)
        return yearlyIncome / Double(monthsElapsed)
    }
    
    var yearlyAverageMonthlyExpenses: Double {
        let calendar = Calendar.current
        let now = Date()
        let monthsElapsed = max(calendar.component(.month, from: now), 1)
        return yearlyExpenses / Double(monthsElapsed)
    }
    
    /// Breakdown of expenses by month for the current year (for charts)
    func yearlyMonthlyBreakdown() -> [(month: Int, income: Double, expenses: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return (1...currentMonth).map { month in
            guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else {
                return (month: month, income: 0, expenses: 0)
            }
            let period = DateInterval(start: start, end: end)
            return (
                month: month,
                income: totalIncome(for: period),
                expenses: totalExpenses(for: period)
            )
        }
    }
    
    /// Expense breakdown by category for the current year
    func yearlyExpenseBreakdown() -> [(FinanceCategory, Double)] {
        expenseBreakdown(for: yearToDatePeriod())
    }
    
    /// Top expense category for the year
    var topYearlyExpenseCategory: FinanceCategory? {
        yearlyExpenseBreakdown().first?.0
    }
    
    /// Projected annual income based on YTD average
    var projectedAnnualIncome: Double {
        yearlyAverageMonthlyIncome * 12
    }
    
    /// Projected annual expenses based on YTD average
    var projectedAnnualExpenses: Double {
        yearlyAverageMonthlyExpenses * 12
    }
    
    // MARK: - Calculations: Stress & Freedom
    
    var financialStressLevel: FinancialStressLevel {
        var score = 0.0
        var factors = 0
        
        // Factor 1: Expense/Income ratio
        if monthlyIncome > 0 {
            let ratio = monthlyExpenses / monthlyIncome
            score += max(0, min(1, 1.0 - ratio))
            factors += 1
        }
        
        // Factor 2: Budget adherence
        if monthlyBudgetTarget > 0 {
            let budgetRatio = monthlyExpenses / monthlyBudgetTarget
            score += max(0, min(1, 1.0 - (budgetRatio - 1.0)))
            factors += 1
        }
        
        // Factor 3: Savings goal
        if savingsGoalIsPercent {
            if savingsGoalPercent > 0 && monthlyIncome > 0 {
                let actualSavingsPercent = monthlySavingsRate * 100
                let savingsRatio = actualSavingsPercent / savingsGoalPercent
                score += max(0, min(1, savingsRatio))
                factors += 1
            }
        } else {
            if savingsGoalAmount > 0 {
                let actualSavings = max(monthlyIncome - monthlyExpenses, 0)
                let savingsRatio = actualSavings / savingsGoalAmount
                score += max(0, min(1, savingsRatio))
                factors += 1
            }
        }
        
        // Factor 4: Income goal
        if monthlyIncomeGoal > 0 {
            let incomeRatio = monthlyIncome / monthlyIncomeGoal
            score += max(0, min(1, incomeRatio))
            factors += 1
        }
        
        // If no goals set, use simple expense/income ratio
        guard factors > 0 else {
            let ratio = monthlyIncome > 0 ? monthlyExpenses / monthlyIncome : 1.0
            switch ratio {
            case ..<0.5: return .comfortable
            case 0.5..<0.75: return .balanced
            case 0.75..<0.95: return .tight
            case 0.95..<1.1: return .stressed
            default: return .critical
            }
        }
        
        let avg = score / Double(factors)
        switch avg {
        case 0.8...: return .comfortable
        case 0.6..<0.8: return .balanced
        case 0.4..<0.6: return .tight
        case 0.2..<0.4: return .stressed
        default: return .critical
        }
    }
    
    // MARK: - Goal Progress
    
    var budgetProgress: Double? {
        guard monthlyBudgetTarget > 0 else { return nil }
        return monthlyExpenses / monthlyBudgetTarget
    }
    
    var savingsProgress: Double? {
        if savingsGoalIsPercent {
            guard savingsGoalPercent > 0, monthlyIncome > 0 else { return nil }
            return (monthlySavingsRate * 100) / savingsGoalPercent
        } else {
            guard savingsGoalAmount > 0 else { return nil }
            let actualSavings = monthlyIncome - monthlyExpenses
            return max(actualSavings, 0) / savingsGoalAmount
        }
    }
    
    var savingsGoalConfigured: Bool {
        savingsGoalIsPercent ? savingsGoalPercent > 0 : savingsGoalAmount > 0
    }
    
    var incomeProgress: Double? {
        guard monthlyIncomeGoal > 0 else { return nil }
        return monthlyIncome / monthlyIncomeGoal
    }
    
    var runwayMonths: Double? {
        guard monthlyBurnRate > 0 else { return nil }
        let balance = currentBalance
        guard balance > 0 else { return 0 }
        return balance / monthlyBurnRate
    }
    
    // MARK: - Budget Tracking

    private func _spentAmount(for budget: FinanceBudget, in period: DateInterval) -> Double {
        realizedOccurrences(in: period)
            .map(\.entry)
            .filter {
                guard $0.type.isOutflow else { return false }
                if let customId = budget.customCategoryId {
                    return $0.customCategoryId == customId
                }
                return $0.customCategoryId == nil && $0.category == budget.category
            }
            .reduce(0) { $0 + $1.amount }
    }

    func spentAmount(for budget: FinanceBudget, in period: DateInterval) -> Double {
        _spentAmount(for: budget, in: period)
    }

    func budgetUsage(for budget: FinanceBudget) -> Double {
        guard budget.isActive else { return 0 }
        let period = currentMonthPeriod()
        let spent = _spentAmount(for: budget, in: period)
        return budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0
    }

    func overBudgetCategories() -> [(FinanceBudget, Double)] {
        budgets.filter { $0.isActive }.compactMap { budget in
            let usage = budgetUsage(for: budget)
            return usage > 1.0 ? (budget, usage) : nil
        }
    }
    
    // MARK: - Expense Breakdown

    func expenseBreakdownDetailed(for period: DateInterval) -> [(FinanceExpenseBreakdownKey, Double)] {
        let expenseEntries = realizedOccurrences(in: period).map(\.entry).filter { $0.type.isOutflow }
        var breakdown: [FinanceExpenseBreakdownKey: Double] = [:]

        for entry in expenseEntries {
            if let customId = entry.customCategoryId {
                breakdown[.custom(customId), default: 0] += entry.amount
            } else {
                breakdown[.builtIn(entry.category), default: 0] += entry.amount
            }
        }

        return breakdown.sorted { $0.value > $1.value }
    }

    func expenseBreakdownDisplayName(for key: FinanceExpenseBreakdownKey) -> String {
        switch key {
        case .builtIn(let category):
            return displayName(for: category)
        case .custom(let id):
            return customCategory(for: id)?.name ?? displayName(for: .other)
        }
    }

    func expenseBreakdownIcon(for key: FinanceExpenseBreakdownKey) -> String {
        switch key {
        case .builtIn(let category):
            return icon(for: category)
        case .custom(let id):
            return customCategory(for: id)?.icon ?? icon(for: .other)
        }
    }

    func expenseBreakdownColorCategory(for key: FinanceExpenseBreakdownKey) -> FinanceCategory {
        switch key {
        case .builtIn(let category):
            return category
        case .custom:
            return .other
        }
    }

    func expenseBreakdown(for period: DateInterval) -> [(FinanceCategory, Double)] {
        let expenseEntries = realizedOccurrences(in: period).map(\.entry).filter { $0.type.isOutflow }
        var breakdown: [FinanceCategory: Double] = [:]

        for entry in expenseEntries {
            breakdown[entry.category, default: 0] += entry.amount
        }

        return breakdown.sorted { $0.value > $1.value }
    }
    
    var topExpenseCategory: FinanceCategory? {
        let period = currentMonthPeriod()
        return expenseBreakdown(for: period).first?.0
    }
    
    // MARK: - Snapshot for LifeOrchestration
    
    func generateSnapshotSummary() -> FinanceSnapshotSummary {
        let period = currentMonthPeriod()
        return FinanceSnapshotSummary(
            totalIncome: totalIncome(for: period),
            totalExpenses: totalExpenses(for: period),
            netFlow: netFlow(for: period),
            savingsRate: savingsRate(for: period),
            stressLevel: financialStressLevel,
            topExpenseCategory: topExpenseCategory?.displayName,
            monthlyBurnRate: monthlyBurnRate,
            runwayMonths: runwayMonths
        )
    }
    
    // MARK: - Formatting
    
    private var formatterCache: [String: NumberFormatter] = [:]
    
    /// Amount in the selected currency. `showCents: false` drops the decimals for compact spots
    /// (summaries, gauges); currencies without minor units (JPY, KRW) never show them.
    func formatCurrency(_ amount: Double, showCents: Bool = true) -> String {
        let currency = selectedCurrency
        let naturalDigits = (currency == .jpy || currency == .krw) ? 0 : 2
        let digits = showCents ? naturalDigits : 0
        let key = "\(currency.rawValue)-\(digits)-\(Locale.current.identifier)"
        let formatter: NumberFormatter
        if let cached = formatterCache[key] {
            formatter = cached
        } else {
            formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.rawValue
            formatter.currencySymbol = currency.symbol
            formatter.minimumFractionDigits = digits
            formatter.maximumFractionDigits = digits
            formatterCache[key] = formatter
        }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.symbol)\(amount)"
    }
    
    /// "67,2%" / "67.2%" following the device locale. `fraction` is 0...1.
    func formatPercent(_ fraction: Double, maxFractionDigits: Int = 0) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0...maxFractionDigits)))
    }
    
    /// "5 Oct" in the language chosen inside the app (adds the year for dates outside the current year).
    func formatShortDate(_ date: Date) -> String {
        let locale = Locale(identifier: LanguageManager.shared.actualLanguageCode)
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        let style = sameYear
            ? Date.FormatStyle().locale(locale).day().month(.abbreviated)
            : Date.FormatStyle().locale(locale).day().month(.abbreviated).year()
        return date.formatted(style)
    }
    
    // MARK: - Persistence
    
    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            print("Error saving finance entries: \(error)")
        }
    }
    
    private func saveBudgets() {
        do {
            let data = try JSONEncoder().encode(budgets)
            UserDefaults.standard.set(data, forKey: budgetsKey)
        } catch {
            print("Error saving finance budgets: \(error)")
        }
    }
    
    private func saveFinancialGoals() {
        do {
            let data = try JSONEncoder().encode(financialGoals)
            UserDefaults.standard.set(data, forKey: financialGoalsKey)
        } catch {
            print("Error saving financial goals: \(error)")
        }
    }
    
    private func saveCustomCategories() {
        do {
            let data = try JSONEncoder().encode(customCategories)
            UserDefaults.standard.set(data, forKey: customCategoriesKey)
        } catch {
            print("Error saving custom categories: \(error)")
        }
    }
    
    private func saveCategoryOverrides() {
        do {
            let data = try JSONEncoder().encode(categoryOverrides)
            UserDefaults.standard.set(data, forKey: categoryOverridesKey)
        } catch {
            print("Error saving category overrides: \(error)")
        }
    }
    
    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: entriesKey) {
            entries = (try? JSONDecoder().decode([FinanceEntry].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: financialGoalsKey) {
            financialGoals = (try? JSONDecoder().decode([FinancialGoal].self, from: data)) ?? []
        }
        startingBalance = UserDefaults.standard.double(forKey: startingBalanceKey)
        monthlyBudgetTarget = UserDefaults.standard.double(forKey: monthlyBudgetTargetKey)
        savingsGoalPercent = UserDefaults.standard.double(forKey: savingsGoalPercentKey)
        savingsGoalAmount = UserDefaults.standard.double(forKey: savingsGoalAmountKey)
        savingsGoalIsPercent = UserDefaults.standard.object(forKey: savingsGoalIsPercentKey) as? Bool ?? true
        monthlyIncomeGoal = UserDefaults.standard.double(forKey: monthlyIncomeGoalKey)
        if let data = UserDefaults.standard.data(forKey: customCategoriesKey) {
            customCategories = (try? JSONDecoder().decode([CustomFinanceCategory].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: budgetsKey) {
            budgets = (try? JSONDecoder().decode([FinanceBudget].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: categoryOverridesKey) {
            categoryOverrides = (try? JSONDecoder().decode([FinanceCategoryOverride].self, from: data)) ?? []
        }
        if let array = UserDefaults.standard.array(forKey: hiddenBuiltInCategoriesKey) as? [String] {
            hiddenBuiltInCategories = Set(array)
        }
        if let currencyRaw = UserDefaults.standard.string(forKey: selectedCurrencyKey),
           let currency = SupportedCurrency(rawValue: currencyRaw) {
            selectedCurrency = currency
        }
    }
    
    func resetAll(syncToCloud: Bool = false) {
        if syncToCloud {
            entries.forEach { CloudKitService.shared.deleteFinanceEntry($0) }
            budgets.forEach { CloudKitService.shared.deleteFinanceBudget($0) }
            financialGoals.forEach { CloudKitService.shared.deleteFinancialGoal($0) }
            customCategories.forEach { CloudKitService.shared.deleteCustomFinanceCategory($0) }
        }
        entries.removeAll()
        budgets.removeAll()
        financialGoals.removeAll()
        startingBalance = 0
        monthlyBudgetTarget = 0
        savingsGoalPercent = 0
        savingsGoalAmount = 0
        savingsGoalIsPercent = true
        monthlyIncomeGoal = 0
        UserDefaults.standard.removeObject(forKey: entriesKey)
        UserDefaults.standard.removeObject(forKey: budgetsKey)
        UserDefaults.standard.removeObject(forKey: financialGoalsKey)
        UserDefaults.standard.removeObject(forKey: startingBalanceKey)
        UserDefaults.standard.removeObject(forKey: monthlyBudgetTargetKey)
        UserDefaults.standard.removeObject(forKey: savingsGoalPercentKey)
        UserDefaults.standard.removeObject(forKey: savingsGoalAmountKey)
        UserDefaults.standard.removeObject(forKey: savingsGoalIsPercentKey)
        UserDefaults.standard.removeObject(forKey: monthlyIncomeGoalKey)
        customCategories.removeAll()
        categoryOverrides.removeAll()
        hiddenBuiltInCategories.removeAll()
        UserDefaults.standard.removeObject(forKey: customCategoriesKey)
        UserDefaults.standard.removeObject(forKey: categoryOverridesKey)
        UserDefaults.standard.removeObject(forKey: hiddenBuiltInCategoriesKey)
        objectWillChange.send()
        notifyFinanceChanged()
        if syncToCloud { syncFinanceSettingsToCloud() }
    }
    
    private func notifyFinanceChanged() {
        NotificationCenter.default.post(name: .financeDataDidUpdate, object: nil)
        writeWidgetData()
    }
    
    private func writeWidgetData() {
        guard let shared = UserDefaults(suiteName: "group.com.snapTask.shared") else { return }
        shared.set(currentBalance, forKey: "finance_balance")
        shared.set(monthlyIncome, forKey: "finance_monthlyIncome")
        shared.set(monthlyExpenses, forKey: "finance_monthlyExpenses")
        shared.set(monthlyBudgetTarget, forKey: "finance_monthlyBudgetTarget")
        shared.set(selectedCurrency.rawValue, forKey: "finance_currencyCode")
        shared.set(selectedCurrency.symbol, forKey: "finance_currencySymbol")
        shared.set(startingBalance, forKey: "finance_startingBalance")
        
        // Write budget data as JSON array
        let budgetData = budgets.filter { $0.isActive }.map { budget -> [String: Any] in
            let period = currentMonthPeriod()
            let spent = spentAmount(for: budget, in: period)
            return [
                "categoryRaw": budget.category.rawValue,
                "customCategoryId": budget.customCategoryId?.uuidString as Any,
                "categoryName": budgetDisplayName(for: budget),
                "categoryIcon": budgetIcon(for: budget),
                "monthlyLimit": budget.monthlyLimit,
                "spent": spent
            ]
        }
        if let encoded = try? JSONSerialization.data(withJSONObject: budgetData) {
            shared.set(encoded, forKey: "finance_budgets")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let financeDataDidUpdate = Notification.Name("financeDataDidUpdate")
}

// MARK: - CloudKit Merge Functions

extension FinanceManager {
    
    @discardableResult
    func mergeEntriesFromCloud(_ remoteEntries: [FinanceEntry]) -> Bool {
        guard !remoteEntries.isEmpty else { return false }
        
        var hasChanges = false
        let localMap = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        for remoteEntry in remoteEntries {
            if let localEntry = localMap[remoteEntry.id] {
                // Use the newer version based on lastModifiedDate
                if remoteEntry.lastModifiedDate > localEntry.lastModifiedDate {
                    if let index = entries.firstIndex(where: { $0.id == remoteEntry.id }) {
                        entries[index] = remoteEntry
                        hasChanges = true
                    }
                }
            } else {
                // New entry from cloud
                entries.append(remoteEntry)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveEntries()
            notifyFinanceChanged()
        }
        return hasChanges
    }
    
    @discardableResult
    func mergeBudgetsFromCloud(_ remoteBudgets: [FinanceBudget]) -> Bool {
        guard !remoteBudgets.isEmpty else { return false }
        
        var hasChanges = false
        
        // Budgets have no edit date: a copy that changed on iCloud is an edit made on another
        // device (edits still uploading from here are filtered out by CloudKitService).
        for remoteBudget in remoteBudgets {
            if let index = budgets.firstIndex(where: { $0.id == remoteBudget.id }) {
                if budgets[index] != remoteBudget {
                    budgets[index] = remoteBudget
                    hasChanges = true
                }
            } else {
                budgets.append(remoteBudget)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveBudgets()
            notifyFinanceChanged()
        }
        return hasChanges
    }
    
    @discardableResult
    func mergeGoalsFromCloud(_ remoteGoals: [FinancialGoal]) -> Bool {
        guard !remoteGoals.isEmpty else { return false }
        
        var hasChanges = false
        let localMap = Dictionary(financialGoals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        for remoteGoal in remoteGoals {
            if let localGoal = localMap[remoteGoal.id] {
                // Use the newer version based on lastModifiedDate
                if remoteGoal.lastModifiedDate > localGoal.lastModifiedDate {
                    if let index = financialGoals.firstIndex(where: { $0.id == remoteGoal.id }) {
                        financialGoals[index] = remoteGoal
                        hasChanges = true
                    }
                }
            } else {
                financialGoals.append(remoteGoal)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveFinancialGoals()
            notifyFinanceChanged()
        }
        return hasChanges
    }
    
    @discardableResult
    func mergeCustomCategoriesFromCloud(_ remoteCategories: [CustomFinanceCategory]) -> Bool {
        guard !remoteCategories.isEmpty else { return false }
        
        var hasChanges = false
        
        // Edits made on another device are applied too, not only new categories.
        for remoteCategory in remoteCategories {
            if let index = customCategories.firstIndex(where: { $0.id == remoteCategory.id }) {
                if customCategories[index] != remoteCategory {
                    customCategories[index] = remoteCategory
                    hasChanges = true
                }
            } else {
                customCategories.append(remoteCategory)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveCustomCategories()
            notifyFinanceChanged()
        }
        return hasChanges
    }
}
