package com.snaptask.app.data.repository

import com.snaptask.app.data.local.SnapTaskPreferences
import com.snaptask.app.data.local.dao.FinanceEntryDao
import com.snaptask.app.data.local.entity.FinanceEntryEntity
import com.snaptask.app.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Faithful port of iOS FinanceManager.
 * Manages finance entries, budgets, goals, settings, and calculations.
 * Room persistence for entries and DataStore persistence for the FinanceManager
 * configuration (budgets, goals, preferences and custom categories).
 */
@Singleton
class FinanceRepository @Inject constructor(
    private val financeEntryDao: FinanceEntryDao,
    private val preferences: SnapTaskPreferences,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _settings = MutableStateFlow(FinanceSettingsState())
    val settings: StateFlow<FinanceSettingsState> = _settings.asStateFlow()

    // ── Observable data ──
    val entries: Flow<List<FinanceEntry>> = financeEntryDao.getAllEntries()
        .map { list -> list.map { it.toModel() } }

    val budgets: List<FinanceBudget> get() = settings.value.budgets
    val financialGoals: List<FinancialGoal> get() = settings.value.financialGoals
    val startingBalance: Double get() = settings.value.startingBalance
    val monthlyBudgetTarget: Double get() = settings.value.monthlyBudgetTarget
    val savingsGoalPercent: Double get() = settings.value.savingsGoalPercent
    val savingsGoalAmount: Double get() = settings.value.savingsGoalAmount
    val savingsGoalIsPercent: Boolean get() = settings.value.savingsGoalIsPercent
    val monthlyIncomeGoal: Double get() = settings.value.monthlyIncomeGoal
    val customCategories: List<CustomFinanceCategory> get() = settings.value.customCategories
    val categoryOverrides: List<FinanceCategoryOverride> get() = settings.value.categoryOverrides
    val hiddenBuiltInCategories: Set<String> get() = settings.value.hiddenBuiltInCategories
    val selectedCurrency: SupportedCurrency get() = SupportedCurrency.fromCode(settings.value.selectedCurrencyCode)

    init {
        scope.launch {
            preferences.financeSettings.collect { stored -> _settings.value = stored }
        }
    }

    private fun updateSettings(transform: (FinanceSettingsState) -> FinanceSettingsState) {
        val updated = transform(settings.value)
        _settings.value = updated
        scope.launch { preferences.setFinanceSettings(updated) }
    }

    // ── Setters (mirroring iOS FinanceManager) ──

    fun setStartingBalance(amount: Double) = updateSettings { it.copy(startingBalance = amount) }
    fun setMonthlyBudgetTarget(amount: Double) = updateSettings { it.copy(monthlyBudgetTarget = amount) }
    fun setSavingsGoalPercent(percent: Double) = updateSettings { it.copy(savingsGoalPercent = percent.coerceIn(0.0, 100.0)) }
    fun setSavingsGoalAmount(amount: Double) = updateSettings { it.copy(savingsGoalAmount = amount.coerceAtLeast(0.0)) }
    fun setSavingsGoalIsPercent(isPercent: Boolean) = updateSettings { it.copy(savingsGoalIsPercent = isPercent) }
    fun setMonthlyIncomeGoal(amount: Double) = updateSettings { it.copy(monthlyIncomeGoal = amount) }
    fun setSelectedCurrency(currency: SupportedCurrency) = updateSettings { it.copy(selectedCurrencyCode = currency.code) }

    // ── Custom Category CRUD ──

    fun addCustomCategory(category: CustomFinanceCategory) {
        if (customCategories.any { it.id == category.id }) return
        updateSettings { it.copy(customCategories = it.customCategories + category) }
    }

    fun updateCustomCategory(category: CustomFinanceCategory) {
        updateSettings { state -> state.copy(customCategories = state.customCategories.map { if (it.id == category.id) category else it }) }
    }

    fun removeCustomCategory(category: CustomFinanceCategory) {
        updateSettings { state -> state.copy(customCategories = state.customCategories.filter { it.id != category.id }) }
    }

    fun customCategory(forId: UUID?): CustomFinanceCategory? {
        if (forId == null) return null
        return customCategories.find { it.id == forId }
    }

    // ── Category Override CRUD ──

    fun setCategoryOverride(category: FinanceCategory, customName: String?, customIcon: String?, customColorHex: String? = override(forCategory = category)?.customColorHex) {
        val list = categoryOverrides.filter { it.categoryRawValue != category.name }.toMutableList()
        if (customName != null || customIcon != null || customColorHex != null) {
            list.add(FinanceCategoryOverride(category.name, customName, customIcon, customColorHex))
        }
        updateSettings { it.copy(categoryOverrides = list) }
    }

    fun override(forCategory: FinanceCategory): FinanceCategoryOverride? {
        return categoryOverrides.find { it.categoryRawValue == forCategory.name }
    }

    fun displayName(forCategory: FinanceCategory): String {
        return override(forCategory)?.customName ?: forCategory.displayName
    }

    fun icon(forCategory: FinanceCategory): String {
        return override(forCategory)?.customIcon ?: forCategory.icon
    }

    fun colorHex(forCategory: FinanceCategory): String =
        override(forCategory)?.customColorHex ?: baseColorHex(forCategory)

    fun colorHex(forCustomCategoryId: UUID?): String {
        customCategory(forCustomCategoryId)?.colorHex?.let { return it }
        val palette = listOf("#3B82F6", "#F97316", "#10B981", "#EF4444", "#8B5CF6", "#06B6D4", "#F59E0B", "#EC4899")
        val value = forCustomCategoryId?.toString()?.fold(5381) { hash, char -> hash * 31 + char.code } ?: 0
        return palette[kotlin.math.abs(value) % palette.size]
    }

    fun baseColorHex(category: FinanceCategory): String = when (category) {
        FinanceCategory.HOUSING -> "#3B82F6"
        FinanceCategory.FOOD -> "#F97316"
        FinanceCategory.TRANSPORT -> "#10B981"
        FinanceCategory.HEALTH -> "#EF4444"
        FinanceCategory.ENTERTAINMENT -> "#8B5CF6"
        FinanceCategory.EDUCATION -> "#06B6D4"
        FinanceCategory.CLOTHING -> "#EC4899"
        FinanceCategory.UTILITIES -> "#F59E0B"
        FinanceCategory.INSURANCE -> "#6366F1"
        FinanceCategory.SALARY -> "#22C55E"
        FinanceCategory.FREELANCE -> "#14B8A6"
        FinanceCategory.PASSIVE -> "#A855F7"
        FinanceCategory.GIFTS -> "#F43F5E"
        FinanceCategory.OTHER -> "#94A3B8"
    }

    fun categoryDisplayName(forEntry: FinanceEntry): String {
        val custom = customCategory(forEntry.customCategoryId)
        if (custom != null) return custom.name
        return displayName(forEntry.category)
    }

    fun categoryIcon(forEntry: FinanceEntry): String {
        val custom = customCategory(forEntry.customCategoryId)
        if (custom != null) return custom.icon
        return icon(forEntry.category)
    }

    // ── Entry CRUD ──

    suspend fun addEntry(entry: FinanceEntry) {
        financeEntryDao.insertEntry(FinanceEntryEntity.fromModel(entry))
    }

    suspend fun updateEntry(entry: FinanceEntry) {
        val updated = entry.copy(lastModifiedDate = Date())
        financeEntryDao.updateEntry(FinanceEntryEntity.fromModel(updated))
    }

    suspend fun removeEntry(entry: FinanceEntry) {
        financeEntryDao.deleteEntry(FinanceEntryEntity.fromModel(entry))
    }

    // ── Budget CRUD ──

    fun addBudget(budget: FinanceBudget) {
        if (budgets.any { it.id == budget.id }) return
        updateSettings { it.copy(budgets = it.budgets + budget) }
    }

    fun updateBudget(budget: FinanceBudget) {
        updateSettings { state -> state.copy(budgets = state.budgets.map { if (it.id == budget.id) budget else it }) }
    }

    fun removeBudget(budget: FinanceBudget) {
        updateSettings { state -> state.copy(budgets = state.budgets.filter { it.id != budget.id }) }
    }

    // ── Financial Goal CRUD ──

    fun addFinancialGoal(goal: FinancialGoal) {
        if (financialGoals.any { it.id == goal.id }) return
        updateSettings { it.copy(financialGoals = it.financialGoals + goal) }
    }

    fun updateFinancialGoal(goal: FinancialGoal) {
        updateSettings { state -> state.copy(financialGoals = state.financialGoals.map {
            if (it.id == goal.id) goal.copy(lastModifiedDate = Date()) else it
        }) }
    }

    fun removeFinancialGoal(goal: FinancialGoal) {
        updateSettings { state -> state.copy(financialGoals = state.financialGoals.filter { it.id != goal.id }) }
    }

    // ── Calculations (operate on snapshot list) ──

    fun currentBalance(entriesList: List<FinanceEntry>): Double {
        val totalFlow = entriesList.sumOf { it.signedAmount }
        return startingBalance + totalFlow
    }

    fun totalIncome(entriesList: List<FinanceEntry>, period: LongRange): Double {
        return entriesList
            .filter { it.date.time in period && !it.type.isOutflow }
            .sumOf { it.amount }
    }

    fun totalExpenses(entriesList: List<FinanceEntry>, period: LongRange): Double {
        return entriesList
            .filter { it.date.time in period && it.type.isOutflow }
            .sumOf { it.amount }
    }

    fun netFlow(entriesList: List<FinanceEntry>, period: LongRange): Double {
        return totalIncome(entriesList, period) - totalExpenses(entriesList, period)
    }

    fun savingsRate(entriesList: List<FinanceEntry>, period: LongRange): Double {
        val income = totalIncome(entriesList, period)
        if (income <= 0) return 0.0
        return (netFlow(entriesList, period) / income).coerceAtLeast(0.0)
    }

    fun currentMonthPeriod(): LongRange {
        val cal = Calendar.getInstance()
        cal.set(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.MONTH, 1)
        val end = cal.timeInMillis
        return start..end
    }

    fun monthlyIncome(entriesList: List<FinanceEntry>): Double {
        val recurring = entriesList
            .filter { it.isRecurring && !it.type.isOutflow }
            .sumOf { it.monthlyEquivalent }
        val oneTime = entriesList
            .filter { it.date.time in currentMonthPeriod() && !it.type.isOutflow && !it.isRecurring }
            .sumOf { it.amount }
        return recurring + oneTime
    }

    fun monthlyExpenses(entriesList: List<FinanceEntry>): Double {
        val recurring = entriesList
            .filter { it.isRecurring && it.type.isOutflow }
            .sumOf { it.monthlyEquivalent }
        val oneTime = entriesList
            .filter { it.date.time in currentMonthPeriod() && it.type.isOutflow && !it.isRecurring }
            .sumOf { it.amount }
        return recurring + oneTime
    }

    fun monthlySubscriptionCost(entriesList: List<FinanceEntry>): Double {
        return activeSubscriptions(entriesList).sumOf { it.monthlyEquivalent }
    }

    fun monthlySavingsRate(entriesList: List<FinanceEntry>): Double {
        val income = monthlyIncome(entriesList)
        if (income <= 0) return 0.0
        return ((income - monthlyExpenses(entriesList)) / income).coerceAtLeast(0.0)
    }

    fun activeSubscriptions(entriesList: List<FinanceEntry>): List<FinanceEntry> {
        return entriesList.filter { it.type == FinanceEntryType.SUBSCRIPTION && it.isRecurring }
            .filter { entry ->
                val endDate = entry.recurringEndDate ?: return@filter true
                endDate.after(Date())
            }
    }

    // ── Stress Level (faithful port from iOS) ──

    fun financialStressLevel(entriesList: List<FinanceEntry>): FinancialStressLevel {
        val mIncome = monthlyIncome(entriesList)
        val mExpenses = monthlyExpenses(entriesList)
        var score = 0.0
        var factors = 0

        // Factor 1: Expense/Income ratio
        if (mIncome > 0) {
            val ratio = mExpenses / mIncome
            score += (1.0 - ratio).coerceIn(0.0, 1.0)
            factors++
        }

        // Factor 2: Budget adherence
        if (monthlyBudgetTarget > 0) {
            val budgetRatio = mExpenses / monthlyBudgetTarget
            score += (1.0 - (budgetRatio - 1.0)).coerceIn(0.0, 1.0)
            factors++
        }

        // Factor 3: Savings goal
        if (savingsGoalIsPercent) {
            if (savingsGoalPercent > 0 && mIncome > 0) {
                val actualSavingsPercent = monthlySavingsRate(entriesList) * 100
                val savingsRatio = actualSavingsPercent / savingsGoalPercent
                score += savingsRatio.coerceIn(0.0, 1.0)
                factors++
            }
        } else {
            if (savingsGoalAmount > 0) {
                val actualSavings = (mIncome - mExpenses).coerceAtLeast(0.0)
                val savingsRatio = actualSavings / savingsGoalAmount
                score += savingsRatio.coerceIn(0.0, 1.0)
                factors++
            }
        }

        // Factor 4: Income goal
        if (monthlyIncomeGoal > 0) {
            val incomeRatio = mIncome / monthlyIncomeGoal
            score += incomeRatio.coerceIn(0.0, 1.0)
            factors++
        }

        // If no goals set, use simple expense/income ratio
        if (factors == 0) {
            val ratio = if (mIncome > 0) mExpenses / mIncome else 1.0
            return when {
                ratio < 0.5 -> FinancialStressLevel.COMFORTABLE
                ratio < 0.75 -> FinancialStressLevel.BALANCED
                ratio < 0.95 -> FinancialStressLevel.TIGHT
                ratio < 1.1 -> FinancialStressLevel.STRESSED
                else -> FinancialStressLevel.CRITICAL
            }
        }

        val avg = score / factors
        return when {
            avg >= 0.8 -> FinancialStressLevel.COMFORTABLE
            avg >= 0.6 -> FinancialStressLevel.BALANCED
            avg >= 0.4 -> FinancialStressLevel.TIGHT
            avg >= 0.2 -> FinancialStressLevel.STRESSED
            else -> FinancialStressLevel.CRITICAL
        }
    }

    // ── Budget / Goal Progress ──

    fun budgetProgress(entriesList: List<FinanceEntry>): Double? {
        if (monthlyBudgetTarget <= 0) return null
        return monthlyExpenses(entriesList) / monthlyBudgetTarget
    }

    fun savingsProgress(entriesList: List<FinanceEntry>): Double? {
        val mIncome = monthlyIncome(entriesList)
        val mExpenses = monthlyExpenses(entriesList)
        return if (savingsGoalIsPercent) {
            if (savingsGoalPercent <= 0 || mIncome <= 0) null
            else (monthlySavingsRate(entriesList) * 100) / savingsGoalPercent
        } else {
            if (savingsGoalAmount <= 0) null
            else (mIncome - mExpenses).coerceAtLeast(0.0) / savingsGoalAmount
        }
    }

    val savingsGoalConfigured: Boolean
        get() = if (savingsGoalIsPercent) savingsGoalPercent > 0 else savingsGoalAmount > 0

    fun incomeProgress(entriesList: List<FinanceEntry>): Double? {
        if (monthlyIncomeGoal <= 0) return null
        return monthlyIncome(entriesList) / monthlyIncomeGoal
    }

    fun runwayMonths(entriesList: List<FinanceEntry>): Double? {
        val burn = monthlyExpenses(entriesList)
        if (burn <= 0) return null
        val balance = currentBalance(entriesList)
        if (balance <= 0) return 0.0
        return balance / burn
    }

    // ── Budget Tracking ──

    fun spentAmount(entriesList: List<FinanceEntry>, budget: FinanceBudget, period: LongRange = currentMonthPeriod()): Double {
        return entriesList
            .filter { entry ->
                entry.date.time in period && entry.type.isOutflow &&
                    if (budget.customCategoryId != null) entry.customCategoryId == budget.customCategoryId
                    else entry.customCategoryId == null && entry.category == budget.category
            }
            .sumOf { it.amount }
    }

    fun budgetUsage(entriesList: List<FinanceEntry>, budget: FinanceBudget): Double {
        if (!budget.isActive) return 0.0
        val spent = spentAmount(entriesList, budget)
        return if (budget.monthlyLimit > 0) spent / budget.monthlyLimit else 0.0
    }

    /** Compatibility overload for callers that select a built-in category. */
    fun budgetUsage(entriesList: List<FinanceEntry>, category: FinanceCategory): Double {
        val budget = budgets.find { it.category == category && it.customCategoryId == null && it.isActive } ?: return 0.0
        return budgetUsage(entriesList, budget)
    }

    fun overBudgetCategories(entriesList: List<FinanceEntry>): List<Pair<FinanceBudget, Double>> {
        return budgets.filter { it.isActive }.mapNotNull { budget ->
            val usage = budgetUsage(entriesList, budget)
            if (usage > 1.0) budget to usage else null
        }
    }

    // ── Expense Breakdown ──

    fun expenseBreakdown(entriesList: List<FinanceEntry>, period: LongRange): List<Pair<FinanceCategory, Double>> {
        val breakdown = mutableMapOf<FinanceCategory, Double>()
        entriesList
            .filter { it.date.time in period && it.type.isOutflow }
            .forEach { entry ->
                breakdown[entry.category] = (breakdown[entry.category] ?: 0.0) + entry.amount
            }
        return breakdown.entries.sortedByDescending { it.value }.map { it.key to it.value }
    }

    fun topExpenseCategory(entriesList: List<FinanceEntry>): FinanceCategory? {
        return expenseBreakdown(entriesList, currentMonthPeriod()).firstOrNull()?.first
    }

    // ── Reset ──

    fun resetAll() {
        updateSettings { FinanceSettingsState() }
    }

    // ── Currency Format Helper ──

    fun formatCurrency(amount: Double): String {
        val formatter = java.text.NumberFormat.getCurrencyInstance()
        formatter.currency = java.util.Currency.getInstance(selectedCurrency.code)
        formatter.maximumFractionDigits = 0
        return formatter.format(amount)
    }
}
