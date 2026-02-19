import Foundation
import Combine

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
    private let selectedCurrencyKey = "financeSelectedCurrency"
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {
        loadAll()
    }
    
    // MARK: - Starting Balance
    
    func setStartingBalance(_ amount: Double) {
        startingBalance = amount
        UserDefaults.standard.set(amount, forKey: startingBalanceKey)
        notifyFinanceChanged()
    }
    
    func setMonthlyBudgetTarget(_ amount: Double) {
        monthlyBudgetTarget = amount
        UserDefaults.standard.set(amount, forKey: monthlyBudgetTargetKey)
        notifyFinanceChanged()
    }
    
    func setSavingsGoalPercent(_ percent: Double) {
        savingsGoalPercent = min(max(percent, 0), 100)
        UserDefaults.standard.set(savingsGoalPercent, forKey: savingsGoalPercentKey)
        notifyFinanceChanged()
    }
    
    func setSavingsGoalAmount(_ amount: Double) {
        savingsGoalAmount = max(amount, 0)
        UserDefaults.standard.set(savingsGoalAmount, forKey: savingsGoalAmountKey)
        notifyFinanceChanged()
    }
    
    func setSavingsGoalIsPercent(_ isPercent: Bool) {
        savingsGoalIsPercent = isPercent
        UserDefaults.standard.set(isPercent, forKey: savingsGoalIsPercentKey)
        notifyFinanceChanged()
    }
    
    func setMonthlyIncomeGoal(_ amount: Double) {
        monthlyIncomeGoal = amount
        UserDefaults.standard.set(amount, forKey: monthlyIncomeGoalKey)
        notifyFinanceChanged()
    }
    
    func setSelectedCurrency(_ currency: SupportedCurrency) {
        selectedCurrency = currency
        UserDefaults.standard.set(currency.rawValue, forKey: selectedCurrencyKey)
        notifyFinanceChanged()
    }
    
    // MARK: - Custom Category CRUD
    
    func addCustomCategory(_ category: CustomFinanceCategory) {
        guard !customCategories.contains(where: { $0.id == category.id }) else { return }
        customCategories.append(category)
        saveCustomCategories()
        notifyFinanceChanged()
    }
    
    func updateCustomCategory(_ category: CustomFinanceCategory) {
        guard let index = customCategories.firstIndex(where: { $0.id == category.id }) else { return }
        customCategories[index] = category
        saveCustomCategories()
        notifyFinanceChanged()
    }
    
    func removeCustomCategory(_ category: CustomFinanceCategory) {
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()
        notifyFinanceChanged()
    }
    
    func customCategory(for id: UUID?) -> CustomFinanceCategory? {
        guard let id = id else { return nil }
        return customCategories.first { $0.id == id }
    }
    
    // MARK: - Built-in Category Overrides
    
    func setCategoryOverride(_ category: FinanceCategory, customName: String?, customIcon: String?) {
        var list = categoryOverrides.filter { $0.categoryRawValue != category.rawValue }
        if customName != nil || customIcon != nil {
            list.append(FinanceCategoryOverride(
                categoryRawValue: category.rawValue,
                customName: customName,
                customIcon: customIcon
            ))
        }
        categoryOverrides = list
        saveCategoryOverrides()
        notifyFinanceChanged()
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
    
    var currentBalance: Double {
        let totalFlow = entries.reduce(0.0) { $0 + $1.signedAmount }
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
    
    // MARK: - Custom Category CRUD with CloudKit
    
    func addCustomCategory(_ category: CustomFinanceCategory) {
        guard !customCategories.contains(where: { $0.id == category.id }) else { return }
        customCategories.append(category)
        saveCustomCategories()
        notifyFinanceChanged()
        CloudKitService.shared.saveCustomFinanceCategory(category)
    }
    
    func removeCustomCategory(_ category: CustomFinanceCategory) {
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()
        notifyFinanceChanged()
        CloudKitService.shared.deleteCustomFinanceCategory(category)
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
    
    // MARK: - Calculations: Period
    
    func totalIncome(for period: DateInterval) -> Double {
        entries(for: period)
            .filter { !$0.type.isOutflow }
            .reduce(0) { $0 + $1.amount }
    }
    
    func totalExpenses(for period: DateInterval) -> Double {
        entries(for: period)
            .filter { $0.type.isOutflow }
            .reduce(0) { $0 + $1.amount }
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
    
    var monthlyIncome: Double {
        let recurring = entries.filter { $0.isRecurring && !$0.type.isOutflow }
            .reduce(0) { $0 + $1.monthlyEquivalent }
        let oneTime = totalIncome(for: currentMonthPeriod())
        return recurring + oneTime
    }
    
    var monthlyExpenses: Double {
        let recurring = entries.filter { $0.isRecurring && $0.type.isOutflow }
            .reduce(0) { $0 + $1.monthlyEquivalent }
        let oneTime = totalExpenses(for: currentMonthPeriod())
        return recurring + oneTime
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
    
    func budgetUsage(for category: FinanceCategory) -> Double {
        guard let budget = budgets.first(where: { $0.category == category && $0.isActive }) else { return 0 }
        let period = currentMonthPeriod()
        let spent = entries(for: period)
            .filter { $0.category == category && $0.type.isOutflow }
            .reduce(0) { $0 + $1.amount }
        return budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0
    }
    
    func overBudgetCategories() -> [(FinanceCategory, Double)] {
        budgets.filter { $0.isActive }.compactMap { budget in
            let usage = budgetUsage(for: budget.category)
            return usage > 1.0 ? (budget.category, usage) : nil
        }
    }
    
    // MARK: - Expense Breakdown
    
    func expenseBreakdown(for period: DateInterval) -> [(FinanceCategory, Double)] {
        let expenseEntries = entries(for: period).filter { $0.type.isOutflow }
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
        if let data = UserDefaults.standard.data(forKey: budgetsKey) {
            budgets = (try? JSONDecoder().decode([FinanceBudget].self, from: data)) ?? []
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
        if let data = UserDefaults.standard.data(forKey: categoryOverridesKey) {
            categoryOverrides = (try? JSONDecoder().decode([FinanceCategoryOverride].self, from: data)) ?? []
        }
        if let currencyRaw = UserDefaults.standard.string(forKey: selectedCurrencyKey),
           let currency = SupportedCurrency(rawValue: currencyRaw) {
            selectedCurrency = currency
        }
    }
    
    func resetAll() {
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
        UserDefaults.standard.removeObject(forKey: customCategoriesKey)
        UserDefaults.standard.removeObject(forKey: categoryOverridesKey)
    }
    
    private func notifyFinanceChanged() {
        NotificationCenter.default.post(name: .financeDataDidUpdate, object: nil)
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
        let localMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        
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
        let localMap = Dictionary(uniqueKeysWithValues: budgets.map { ($0.id, $0) })
        
        for remoteBudget in remoteBudgets {
            if let localBudget = localMap[remoteBudget.id] {
                // Use the newer version based on creationDate as proxy
                if remoteBudget.creationDate > localBudget.creationDate {
                    if let index = budgets.firstIndex(where: { $0.id == remoteBudget.id }) {
                        budgets[index] = remoteBudget
                        hasChanges = true
                    }
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
        let localMap = Dictionary(uniqueKeysWithValues: financialGoals.map { ($0.id, $0) })
        
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
        let localMap = Dictionary(uniqueKeysWithValues: customCategories.map { ($0.id, $0) })
        
        for remoteCategory in remoteCategories {
            if localMap[remoteCategory.id] == nil {
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
