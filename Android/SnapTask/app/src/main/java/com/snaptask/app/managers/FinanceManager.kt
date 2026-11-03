package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import java.text.NumberFormat
import java.time.temporal.ChronoUnit
import java.util.Currency
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/** `DateInterval`: start included, end excluded. */
data class DatePeriod(val start: Date, val end: Date) {
    fun contains(date: Date) = date >= start && date < end
}

sealed class FinanceExpenseBreakdownKey {
    data class BuiltIn(val category: FinanceCategory) : FinanceExpenseBreakdownKey()
    data class Custom(val id: UUID) : FinanceExpenseBreakdownKey()
}

object FinanceManager {
    private const val entriesKey = "savedFinanceEntries"
    private const val budgetsKey = "savedFinanceBudgets"
    private const val financialGoalsKey = "savedFinancialGoals"
    private const val startingBalanceKey = "financeStartingBalance"
    private const val monthlyBudgetTargetKey = "financeMonthlyBudgetTarget"
    private const val savingsGoalPercentKey = "financeSavingsGoalPercent"
    private const val savingsGoalAmountKey = "financeSavingsGoalAmount"
    private const val savingsGoalIsPercentKey = "financeSavingsGoalIsPercent"
    private const val monthlyIncomeGoalKey = "financeMonthlyIncomeGoal"
    private const val customCategoriesKey = "financeCustomCategories"
    private const val categoryOverridesKey = "financeCategoryOverrides"
    private const val hiddenBuiltInCategoriesKey = "financeHiddenBuiltInCategories"
    private const val selectedCurrencyKey = "financeSelectedCurrency"

    private val entriesSerializer = ListSerializer(FinanceEntry.serializer())
    private val budgetsSerializer = ListSerializer(FinanceBudget.serializer())
    private val goalsSerializer = ListSerializer(FinancialGoal.serializer())
    private val customSerializer = ListSerializer(CustomFinanceCategory.serializer())
    private val overridesSerializer = ListSerializer(FinanceCategoryOverride.serializer())
    private val hiddenSerializer = SetSerializer(String.serializer())

    var entries by mutableStateOf<List<FinanceEntry>>(emptyList())
        private set
    var budgets by mutableStateOf<List<FinanceBudget>>(emptyList())
        private set
    var financialGoals by mutableStateOf<List<FinancialGoal>>(emptyList())
        private set
    var startingBalance by mutableStateOf(0.0)
        private set
    var monthlyBudgetTarget by mutableStateOf(0.0)
        private set
    var savingsGoalPercent by mutableStateOf(0.0)
        private set
    var savingsGoalAmount by mutableStateOf(0.0)
        private set
    var savingsGoalIsPercent by mutableStateOf(true)
        private set
    var monthlyIncomeGoal by mutableStateOf(0.0)
        private set
    var customCategories by mutableStateOf<List<CustomFinanceCategory>>(emptyList())
        private set
    var categoryOverrides by mutableStateOf<List<FinanceCategoryOverride>>(emptyList())
        private set
    var hiddenBuiltInCategories by mutableStateOf<Set<String>>(emptySet())
        private set
    var selectedCurrency by mutableStateOf(SupportedCurrency.eur)
        private set

    fun load() {
        entries = Store.load(entriesKey, entriesSerializer) ?: emptyList()
        budgets = Store.load(budgetsKey, budgetsSerializer) ?: emptyList()
        financialGoals = Store.load(financialGoalsKey, goalsSerializer) ?: emptyList()
        customCategories = Store.load(customCategoriesKey, customSerializer) ?: emptyList()
        categoryOverrides = Store.load(categoryOverridesKey, overridesSerializer) ?: emptyList()
        hiddenBuiltInCategories = Store.load(hiddenBuiltInCategoriesKey, hiddenSerializer) ?: emptySet()
        startingBalance = Defaults.double(startingBalanceKey)
        monthlyBudgetTarget = Defaults.double(monthlyBudgetTargetKey)
        savingsGoalPercent = Defaults.double(savingsGoalPercentKey)
        savingsGoalAmount = Defaults.double(savingsGoalAmountKey)
        savingsGoalIsPercent = if (Defaults.contains(savingsGoalIsPercentKey)) Defaults.bool(savingsGoalIsPercentKey) else true
        monthlyIncomeGoal = Defaults.double(monthlyIncomeGoalKey)
        SupportedCurrency.from(Defaults.string(selectedCurrencyKey))?.let { selectedCurrency = it }
    }

    private fun notifyFinanceChanged() = WidgetRefresher.request()

    private fun saveEntries() = Store.save(entriesKey, entriesSerializer, entries)
    private fun saveBudgets() = Store.save(budgetsKey, budgetsSerializer, budgets)
    private fun saveFinancialGoals() = Store.save(financialGoalsKey, goalsSerializer, financialGoals)
    private fun saveCustomCategories() = Store.save(customCategoriesKey, customSerializer, customCategories)
    private fun saveCategoryOverrides() = Store.save(categoryOverridesKey, overridesSerializer, categoryOverrides)
    private fun saveHidden() = Store.save(hiddenBuiltInCategoriesKey, hiddenSerializer, hiddenBuiltInCategories)

    // MARK: Goals of the month

    fun updateStartingBalance(amount: Double) {
        startingBalance = amount
        Defaults.set(startingBalanceKey, amount)
        notifyFinanceChanged()
    }

    fun updateMonthlyBudgetTarget(amount: Double) {
        monthlyBudgetTarget = amount
        Defaults.set(monthlyBudgetTargetKey, amount)
        notifyFinanceChanged()
    }

    fun updateSavingsGoalPercent(percent: Double) {
        savingsGoalPercent = percent.coerceIn(0.0, 100.0)
        Defaults.set(savingsGoalPercentKey, savingsGoalPercent)
        notifyFinanceChanged()
    }

    fun updateSavingsGoalAmount(amount: Double) {
        savingsGoalAmount = max(amount, 0.0)
        Defaults.set(savingsGoalAmountKey, savingsGoalAmount)
        notifyFinanceChanged()
    }

    fun updateSavingsGoalIsPercent(isPercent: Boolean) {
        savingsGoalIsPercent = isPercent
        Defaults.set(savingsGoalIsPercentKey, isPercent)
        notifyFinanceChanged()
    }

    fun updateMonthlyIncomeGoal(amount: Double) {
        monthlyIncomeGoal = amount
        Defaults.set(monthlyIncomeGoalKey, amount)
        notifyFinanceChanged()
    }

    fun updateSelectedCurrency(currency: SupportedCurrency) {
        selectedCurrency = currency
        Defaults.set(selectedCurrencyKey, currency.rawValue)
        notifyFinanceChanged()
    }

    // MARK: Custom categories

    fun addCustomCategory(category: CustomFinanceCategory) {
        if (customCategories.any { it.id == category.id }) return
        customCategories = customCategories + category
        saveCustomCategories()
        notifyFinanceChanged()
    }

    fun updateCustomCategory(category: CustomFinanceCategory) {
        customCategories = customCategories.map { if (it.id == category.id) category else it }
        saveCustomCategories()
        notifyFinanceChanged()
    }

    /** With `reassignEntries` its movements fall back to "Other" and its budgets are dropped. */
    fun removeCustomCategory(category: CustomFinanceCategory, reassignEntries: Boolean = false) {
        if (reassignEntries) {
            val time = now()
            if (entries.any { it.customCategoryId == category.id }) {
                entries = entries.map { if (it.customCategoryId == category.id) it.copy(customCategoryId = null, category = FinanceCategory.other, lastModifiedDate = time) else it }
                saveEntries()
            }
            budgets.filter { it.customCategoryId == category.id }.forEach { removeBudget(it) }
        }
        customCategories = customCategories.filter { it.id != category.id }
        saveCustomCategories()
        notifyFinanceChanged()
    }

    fun customCategory(id: UUID?): CustomFinanceCategory? = id?.let { wanted -> customCategories.firstOrNull { it.id == wanted } }

    // MARK: Built-in categories

    fun setCategoryOverride(category: FinanceCategory, customName: String?, customIcon: String?, customColorHex: String?) {
        var list = categoryOverrides.filter { it.categoryRawValue != category.rawValue }
        if (customName != null || customIcon != null || customColorHex != null) {
            list = list + FinanceCategoryOverride(category.rawValue, customName, customIcon, customColorHex)
        }
        categoryOverrides = list
        saveCategoryOverrides()
        notifyFinanceChanged()
    }

    fun hideBuiltInCategory(category: FinanceCategory) {
        hiddenBuiltInCategories = hiddenBuiltInCategories + category.rawValue
        saveHidden()
        notifyFinanceChanged()
    }

    fun restoreBuiltInCategory(category: FinanceCategory) {
        hiddenBuiltInCategories = hiddenBuiltInCategories - category.rawValue
        saveHidden()
        notifyFinanceChanged()
    }

    fun isHidden(category: FinanceCategory) = category.rawValue in hiddenBuiltInCategories
    val visibleExpenseCategories get() = FinanceCategory.entries.filter { !it.isIncomeCategory && !isHidden(it) }
    val visibleIncomeCategories get() = FinanceCategory.entries.filter { it.isIncomeCategory && !isHidden(it) }

    fun override(category: FinanceCategory) = categoryOverrides.firstOrNull { it.categoryRawValue == category.rawValue }
    fun displayName(category: FinanceCategory) = override(category)?.customName ?: category.displayName
    fun icon(category: FinanceCategory) = override(category)?.customIcon ?: category.icon
    fun colorHex(category: FinanceCategory) = override(category)?.customColorHex ?: baseColorHex(category)

    fun colorHex(customCategoryId: UUID?): String {
        val id = customCategoryId ?: return baseColorHex(FinanceCategory.other)
        customCategory(id)?.colorHex?.let { return it }
        // Fallback: a stable hash, the same on iOS.
        val palette = listOf("#3B82F6", "#F97316", "#10B981", "#EF4444", "#8B5CF6", "#06B6D4", "#F59E0B", "#EC4899", "#84CC16", "#A855F7", "#14B8A6", "#6366F1")
        var hash = 5381UL
        id.uuidString.forEach { hash = hash * 31UL + it.code.toULong() }
        return palette[(hash % palette.size.toULong()).toInt()]
    }

    fun budgetColorHex(budget: FinanceBudget) = if (budget.customCategoryId != null) colorHex(budget.customCategoryId) else colorHex(budget.category)

    fun expenseBreakdownColorHex(key: FinanceExpenseBreakdownKey) = when (key) {
        is FinanceExpenseBreakdownKey.BuiltIn -> colorHex(key.category)
        is FinanceExpenseBreakdownKey.Custom -> colorHex(key.id)
    }

    fun baseColorHex(category: FinanceCategory) = when (category) {
        FinanceCategory.housing -> "#3B82F6"
        FinanceCategory.food -> "#F97316"
        FinanceCategory.transport -> "#10B981"
        FinanceCategory.health -> "#EF4444"
        FinanceCategory.entertainment -> "#8B5CF6"
        FinanceCategory.education -> "#06B6D4"
        FinanceCategory.clothing -> "#EC4899"
        FinanceCategory.utilities -> "#F59E0B"
        FinanceCategory.insurance -> "#6366F1"
        FinanceCategory.salary -> "#22C55E"
        FinanceCategory.freelance -> "#14B8A6"
        FinanceCategory.passive -> "#A855F7"
        FinanceCategory.gifts -> "#F43F5E"
        FinanceCategory.other -> "#94A3B8"
    }

    fun categoryDisplayName(entry: FinanceEntry) = customCategory(entry.customCategoryId)?.name ?: displayName(entry.category)
    fun categoryIcon(entry: FinanceEntry) = customCategory(entry.customCategoryId)?.icon ?: icon(entry.category)
    fun categoryColorHex(entry: FinanceEntry) = if (entry.customCategoryId != null) colorHex(entry.customCategoryId) else colorHex(entry.category)
    fun budgetDisplayName(budget: FinanceBudget) = customCategory(budget.customCategoryId)?.name ?: displayName(budget.category)
    fun budgetIcon(budget: FinanceBudget) = customCategory(budget.customCategoryId)?.icon ?: icon(budget.category)

    /** Starting balance plus everything that already happened, counting every repetition. */
    val currentBalance: Double
        get() = startingBalance + realizedOccurrences(DatePeriod(distantPast, now())).sumOf { it.entry.signedAmount }

    // MARK: Entries

    fun addEntry(entry: FinanceEntry) {
        if (entries.any { it.id == entry.id }) return
        entries = entries + entry
        saveEntries()
        notifyFinanceChanged()
    }

    fun updateEntry(entry: FinanceEntry) {
        if (entries.none { it.id == entry.id }) return
        val updated = entry.copy(lastModifiedDate = now())
        entries = entries.map { if (it.id == entry.id) updated else it }
        saveEntries()
        notifyFinanceChanged()
    }

    /** Adds a copy of `entry` dated now (recurring entries keep their repetition). */
    fun duplicateEntry(entry: FinanceEntry) {
        val time = now()
        val keepsEndDate = (entry.recurringEndDate ?: distantPast) > time
        addEntry(
            FinanceEntry.create(
                name = entry.name,
                amount = entry.amount,
                type = entry.type,
                category = entry.category,
                customCategoryId = entry.customCategoryId,
                date = time,
                notes = entry.notes,
                isRecurring = entry.isRecurring,
                recurringFrequency = entry.recurringFrequency,
                recurringEndDate = if (keepsEndDate) entry.recurringEndDate else null,
                tags = entry.tags,
            ),
        )
    }

    fun removeEntry(entry: FinanceEntry) {
        entries = entries.filter { it.id != entry.id }
        saveEntries()
        notifyFinanceChanged()
    }

    // MARK: Budgets

    fun addBudget(budget: FinanceBudget) {
        if (budgets.any { it.id == budget.id }) return
        budgets = budgets + budget
        saveBudgets()
        notifyFinanceChanged()
    }

    fun updateBudget(budget: FinanceBudget) {
        budgets = budgets.map { if (it.id == budget.id) budget else it }
        saveBudgets()
        notifyFinanceChanged()
    }

    fun removeBudget(budget: FinanceBudget) {
        budgets = budgets.filter { it.id != budget.id }
        saveBudgets()
        notifyFinanceChanged()
    }

    // MARK: Financial goals

    fun addFinancialGoal(goal: FinancialGoal) {
        if (financialGoals.any { it.id == goal.id }) return
        financialGoals = financialGoals + goal
        saveFinancialGoals()
        notifyFinanceChanged()
    }

    fun updateFinancialGoal(goal: FinancialGoal) {
        val updated = goal.copy(lastModifiedDate = now())
        financialGoals = financialGoals.map { if (it.id == goal.id) updated else it }
        saveFinancialGoals()
        notifyFinanceChanged()
    }

    fun removeFinancialGoal(goal: FinancialGoal) {
        financialGoals = financialGoals.filter { it.id != goal.id }
        saveFinancialGoals()
        notifyFinanceChanged()
    }

    // MARK: Queries

    fun entries(period: DatePeriod) = entries.filter { period.contains(it.date) }
    val subscriptions get() = entries.filter { it.type == FinanceEntryType.subscription && it.isRecurring }
    val activeSubscriptions get() = subscriptions.filter { entry -> entry.recurringEndDate?.let { it > now() } ?: true }

    /** Dates on which `entry` happens inside `period`. Recurring entries repeat from their date until their end date. */
    fun occurrenceDates(entry: FinanceEntry, period: DatePeriod): List<Date> {
        val frequency = entry.recurringFrequency
        if (!entry.isRecurring || frequency == null) return if (period.contains(entry.date)) listOf(entry.date) else emptyList()
        var limit = period.end
        entry.recurringEndDate?.let { limit = minOf(limit, it.startOfDay().addingDays(1)) }
        if (entry.date >= limit) return emptyList()

        // Skip straight to the first repetition that can fall inside the period.
        var index = 0
        if (period.start > entry.date) {
            val elapsed = when (frequency) {
                SubscriptionFrequency.weekly -> ChronoUnit.DAYS.between(entry.date.z(), period.start.z()).toInt() / 7
                SubscriptionFrequency.monthly -> ChronoUnit.MONTHS.between(entry.date.z(), period.start.z()).toInt()
                SubscriptionFrequency.quarterly -> ChronoUnit.MONTHS.between(entry.date.z(), period.start.z()).toInt() / 3
                SubscriptionFrequency.yearly -> ChronoUnit.YEARS.between(entry.date.z(), period.start.z()).toInt()
            }
            index = max(elapsed - 1, 0)
        }
        val dates = ArrayList<Date>()
        while (index < 10_000) {
            val date = frequency.next(entry.date, index)
            if (date >= limit) break
            if (date >= period.start) dates += date
            index++
        }
        return dates
    }

    fun occurrences(period: DatePeriod): List<FinanceOccurrence> =
        entries.flatMap { entry -> occurrenceDates(entry, period).map { FinanceOccurrence(entry, it) } }.sortedBy { it.date }

    /** Only what already happened (up to now). */
    fun realizedOccurrences(period: DatePeriod): List<FinanceOccurrence> {
        val time = now()
        if (period.start >= time) return emptyList()
        return occurrences(DatePeriod(period.start, minOf(period.end, time)))
    }

    fun nextOccurrence(entry: FinanceEntry, after: Date = now()): Date? {
        if (!entry.isRecurring) return null
        return occurrenceDates(entry, DatePeriod(after, after.addingYears(2))).firstOrNull()
    }

    // MARK: Calculations

    fun totalIncome(period: DatePeriod) = realizedOccurrences(period).filter { !it.entry.type.isOutflow }.sumOf { it.entry.amount }
    fun totalExpenses(period: DatePeriod) = realizedOccurrences(period).filter { it.entry.type.isOutflow }.sumOf { it.entry.amount }
    fun netFlow(period: DatePeriod) = totalIncome(period) - totalExpenses(period)

    fun savingsRate(period: DatePeriod): Double {
        val income = totalIncome(period)
        if (income <= 0) return 0.0
        return max(netFlow(period) / income, 0.0)
    }

    fun currentMonthPeriod(): DatePeriod {
        val start = now().startOfMonth()
        return DatePeriod(start, start.addingMonths(1))
    }

    val monthlyIncome get() = totalIncome(currentMonthPeriod())
    val monthlyExpenses get() = totalExpenses(currentMonthPeriod())
    val monthlySubscriptionCost get() = activeSubscriptions.sumOf { it.monthlyEquivalent }
    val monthlyBurnRate get() = monthlyExpenses
    val monthlySavingsRate: Double
        get() {
            val income = monthlyIncome
            return if (income > 0) max((income - monthlyExpenses) / income, 0.0) else 0.0
        }

    fun currentYearPeriod(): DatePeriod {
        val start = now().startOfYear()
        return DatePeriod(start, start.addingYears(1))
    }

    fun yearToDatePeriod() = DatePeriod(now().startOfYear(), now())

    val yearlyIncome get() = totalIncome(yearToDatePeriod())
    val yearlyExpenses get() = totalExpenses(yearToDatePeriod())
    val yearlyNetFlow get() = yearlyIncome - yearlyExpenses
    val yearlySavingsRate: Double
        get() {
            val income = yearlyIncome
            return if (income > 0) max((income - yearlyExpenses) / income, 0.0) else 0.0
        }
    val yearlyAverageMonthlyIncome get() = yearlyIncome / max(now().month, 1)
    val yearlyAverageMonthlyExpenses get() = yearlyExpenses / max(now().month, 1)

    fun yearlyMonthlyBreakdown(): List<Triple<Int, Double, Double>> {
        val start = now().startOfYear()
        return (1..now().month).map { month ->
            val monthStart = start.addingMonths(month - 1)
            val period = DatePeriod(monthStart, monthStart.addingMonths(1))
            Triple(month, totalIncome(period), totalExpenses(period))
        }
    }

    fun yearlyExpenseBreakdown() = expenseBreakdown(yearToDatePeriod())
    val topYearlyExpenseCategory get() = yearlyExpenseBreakdown().firstOrNull()?.first
    val projectedAnnualIncome get() = yearlyAverageMonthlyIncome * 12
    val projectedAnnualExpenses get() = yearlyAverageMonthlyExpenses * 12

    val financialStressLevel: FinancialStressLevel
        get() {
            var score = 0.0
            var factors = 0
            val income = monthlyIncome
            val expenses = monthlyExpenses
            if (income > 0) {
                score += (1.0 - expenses / income).coerceIn(0.0, 1.0)
                factors++
            }
            if (monthlyBudgetTarget > 0) {
                score += (1.0 - (expenses / monthlyBudgetTarget - 1.0)).coerceIn(0.0, 1.0)
                factors++
            }
            if (savingsGoalIsPercent) {
                if (savingsGoalPercent > 0 && income > 0) {
                    score += (monthlySavingsRate * 100 / savingsGoalPercent).coerceIn(0.0, 1.0)
                    factors++
                }
            } else if (savingsGoalAmount > 0) {
                score += (max(income - expenses, 0.0) / savingsGoalAmount).coerceIn(0.0, 1.0)
                factors++
            }
            if (monthlyIncomeGoal > 0) {
                score += (income / monthlyIncomeGoal).coerceIn(0.0, 1.0)
                factors++
            }
            if (factors == 0) {
                val ratio = if (income > 0) expenses / income else 1.0
                return when {
                    ratio < 0.5 -> FinancialStressLevel.comfortable
                    ratio < 0.75 -> FinancialStressLevel.balanced
                    ratio < 0.95 -> FinancialStressLevel.tight
                    ratio < 1.1 -> FinancialStressLevel.stressed
                    else -> FinancialStressLevel.critical
                }
            }
            val average = score / factors
            return when {
                average >= 0.8 -> FinancialStressLevel.comfortable
                average >= 0.6 -> FinancialStressLevel.balanced
                average >= 0.4 -> FinancialStressLevel.tight
                average >= 0.2 -> FinancialStressLevel.stressed
                else -> FinancialStressLevel.critical
            }
        }

    val budgetProgress: Double? get() = if (monthlyBudgetTarget > 0) monthlyExpenses / monthlyBudgetTarget else null

    val savingsProgress: Double?
        get() = if (savingsGoalIsPercent) {
            if (savingsGoalPercent > 0 && monthlyIncome > 0) monthlySavingsRate * 100 / savingsGoalPercent else null
        } else {
            if (savingsGoalAmount > 0) max(monthlyIncome - monthlyExpenses, 0.0) / savingsGoalAmount else null
        }

    val savingsGoalConfigured get() = if (savingsGoalIsPercent) savingsGoalPercent > 0 else savingsGoalAmount > 0
    val incomeProgress: Double? get() = if (monthlyIncomeGoal > 0) monthlyIncome / monthlyIncomeGoal else null

    val runwayMonths: Double?
        get() {
            val burn = monthlyBurnRate
            if (burn <= 0) return null
            val balance = currentBalance
            return if (balance > 0) balance / burn else 0.0
        }

    fun spentAmount(budget: FinanceBudget, period: DatePeriod): Double =
        realizedOccurrences(period).map { it.entry }.filter { entry ->
            entry.type.isOutflow && if (budget.customCategoryId != null) entry.customCategoryId == budget.customCategoryId
            else entry.customCategoryId == null && entry.category == budget.category
        }.sumOf { it.amount }

    fun budgetUsage(budget: FinanceBudget): Double {
        if (!budget.isActive) return 0.0
        return if (budget.monthlyLimit > 0) spentAmount(budget, currentMonthPeriod()) / budget.monthlyLimit else 0.0
    }

    fun overBudgetCategories(): List<Pair<FinanceBudget, Double>> =
        budgets.filter { it.isActive }.mapNotNull { budget -> budgetUsage(budget).takeIf { it > 1.0 }?.let { budget to it } }

    fun expenseBreakdownDetailed(period: DatePeriod): List<Pair<FinanceExpenseBreakdownKey, Double>> {
        val breakdown = LinkedHashMap<FinanceExpenseBreakdownKey, Double>()
        realizedOccurrences(period).map { it.entry }.filter { it.type.isOutflow }.forEach { entry ->
            val key = entry.customCategoryId?.let { FinanceExpenseBreakdownKey.Custom(it) } ?: FinanceExpenseBreakdownKey.BuiltIn(entry.category)
            breakdown[key] = (breakdown[key] ?: 0.0) + entry.amount
        }
        return breakdown.toList().sortedByDescending { it.second }
    }

    fun expenseBreakdownDisplayName(key: FinanceExpenseBreakdownKey) = when (key) {
        is FinanceExpenseBreakdownKey.BuiltIn -> displayName(key.category)
        is FinanceExpenseBreakdownKey.Custom -> customCategory(key.id)?.name ?: displayName(FinanceCategory.other)
    }

    fun expenseBreakdownIcon(key: FinanceExpenseBreakdownKey) = when (key) {
        is FinanceExpenseBreakdownKey.BuiltIn -> icon(key.category)
        is FinanceExpenseBreakdownKey.Custom -> customCategory(key.id)?.icon ?: icon(FinanceCategory.other)
    }

    fun expenseBreakdown(period: DatePeriod): List<Pair<FinanceCategory, Double>> {
        val breakdown = LinkedHashMap<FinanceCategory, Double>()
        realizedOccurrences(period).map { it.entry }.filter { it.type.isOutflow }.forEach { entry ->
            breakdown[entry.category] = (breakdown[entry.category] ?: 0.0) + entry.amount
        }
        return breakdown.toList().sortedByDescending { it.second }
    }

    val topExpenseCategory get() = expenseBreakdown(currentMonthPeriod()).firstOrNull()?.first

    // MARK: Formatting

    /** Amount in the selected currency. `showCents = false` drops the decimals; JPY and KRW never show them. */
    fun formatCurrency(amount: Double, showCents: Boolean = true): String {
        val currency = selectedCurrency
        val natural = if (currency == SupportedCurrency.jpy || currency == SupportedCurrency.krw) 0 else 2
        val digits = if (showCents) natural else 0
        val format = NumberFormat.getCurrencyInstance(appLocale)
        format.currency = Currency.getInstance(currency.rawValue)
        (format as? java.text.DecimalFormat)?.let { decimal ->
            decimal.decimalFormatSymbols = decimal.decimalFormatSymbols.apply { currencySymbol = currency.symbol }
        }
        format.minimumFractionDigits = digits
        format.maximumFractionDigits = digits
        return format.format(amount)
    }

    /** "67,2%" / "67.2%" in the app's language. `fraction` is 0...1. */
    fun formatPercent(fraction: Double, maxFractionDigits: Int = 0): String {
        val format = NumberFormat.getPercentInstance(appLocale)
        format.maximumFractionDigits = maxFractionDigits
        return format.format(fraction)
    }

    /** "5 Oct" (adds the year for dates outside the current year). */
    fun formatShortDate(date: Date): String = if (date.isSameYear(now())) date.skeleton("dMMM") else date.skeleton("dMMMy")

    fun resetAll() {
        entries = emptyList()
        budgets = emptyList()
        financialGoals = emptyList()
        customCategories = emptyList()
        categoryOverrides = emptyList()
        hiddenBuiltInCategories = emptySet()
        startingBalance = 0.0
        monthlyBudgetTarget = 0.0
        savingsGoalPercent = 0.0
        savingsGoalAmount = 0.0
        savingsGoalIsPercent = true
        monthlyIncomeGoal = 0.0
        listOf(entriesKey, budgetsKey, financialGoalsKey, customCategoriesKey, categoryOverridesKey, hiddenBuiltInCategoriesKey).forEach { Store.remove(it) }
        listOf(startingBalanceKey, monthlyBudgetTargetKey, savingsGoalPercentKey, savingsGoalAmountKey, savingsGoalIsPercentKey, monthlyIncomeGoalKey).forEach { Defaults.remove(it) }
        notifyFinanceChanged()
    }

    /** Backup import. */
    fun importAll(
        newEntries: List<FinanceEntry>, newBudgets: List<FinanceBudget>, newGoals: List<FinancialGoal>,
        newCustom: List<CustomFinanceCategory>, newOverrides: List<FinanceCategoryOverride>, newHidden: Set<String>,
    ) {
        entries = newEntries
        budgets = newBudgets
        financialGoals = newGoals
        customCategories = newCustom
        categoryOverrides = newOverrides
        hiddenBuiltInCategories = newHidden
        saveEntries()
        saveBudgets()
        saveFinancialGoals()
        saveCustomCategories()
        saveCategoryOverrides()
        saveHidden()
        notifyFinanceChanged()
    }
}
