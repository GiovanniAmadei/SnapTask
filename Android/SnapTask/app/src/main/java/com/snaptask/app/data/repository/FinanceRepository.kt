package com.snaptask.app.data.repository

import com.snaptask.app.data.local.SnapTaskPreferences
import com.snaptask.app.data.local.dao.FinanceEntryDao
import com.snaptask.app.data.local.entity.FinanceEntryEntity
import com.snaptask.app.data.model.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.Calendar
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Faithful port of iOS FinanceManager.
 * Manages finance entries, budgets, goals, settings, and calculations.
 * In-memory for budgets/goals/settings (mirroring iOS UserDefaults approach).
 * Room persistence for entries.
 */
@Singleton
class FinanceRepository @Inject constructor(
    private val financeEntryDao: FinanceEntryDao,
    private val preferences: SnapTaskPreferences,
) {
    // ── Observable data ──
    val entries: Flow<List<FinanceEntry>> = financeEntryDao.getAllEntries()
        .map { list -> list.map { it.toModel() } }

    // In-memory state (mirroring iOS UserDefaults)
    var budgets: List<FinanceBudget> = emptyList()
        private set
    var financialGoals: List<FinancialGoal> = emptyList()
        private set
    var startingBalance: Double = 0.0
        private set
    var monthlyBudgetTarget: Double = 0.0
        private set
    var savingsGoalPercent: Double = 0.0
        private set
    var savingsGoalAmount: Double = 0.0
        private set
    var savingsGoalIsPercent: Boolean = true
        private set
    var monthlyIncomeGoal: Double = 0.0
        private set
    var customCategories: List<CustomFinanceCategory> = emptyList()
        private set
    var categoryOverrides: List<FinanceCategoryOverride> = emptyList()
        private set
    var selectedCurrency: SupportedCurrency = SupportedCurrency.EUR
        private set

    // ── Setters (mirroring iOS FinanceManager) ──

    fun setStartingBalance(amount: Double) { startingBalance = amount }
    fun setMonthlyBudgetTarget(amount: Double) { monthlyBudgetTarget = amount }
    fun setSavingsGoalPercent(percent: Double) { savingsGoalPercent = percent.coerceIn(0.0, 100.0) }
    fun setSavingsGoalAmount(amount: Double) { savingsGoalAmount = amount.coerceAtLeast(0.0) }
    fun setSavingsGoalIsPercent(isPercent: Boolean) { savingsGoalIsPercent = isPercent }
    fun setMonthlyIncomeGoal(amount: Double) { monthlyIncomeGoal = amount }
    fun setSelectedCurrency(currency: SupportedCurrency) { selectedCurrency = currency }

    // ── Custom Category CRUD ──

    fun addCustomCategory(category: CustomFinanceCategory) {
        if (customCategories.any { it.id == category.id }) return
        customCategories = customCategories + category
    }

    fun updateCustomCategory(category: CustomFinanceCategory) {
        customCategories = customCategories.map { if (it.id == category.id) category else it }
    }

    fun removeCustomCategory(category: CustomFinanceCategory) {
        customCategories = customCategories.filter { it.id != category.id }
    }

    fun customCategory(forId: UUID?): CustomFinanceCategory? {
        if (forId == null) return null
        return customCategories.find { it.id == forId }
    }

    // ── Category Override CRUD ──

    fun setCategoryOverride(category: FinanceCategory, customName: String?, customIcon: String?) {
        val list = categoryOverrides.filter { it.categoryRawValue != category.name }.toMutableList()
        if (customName != null || customIcon != null) {
            list.add(FinanceCategoryOverride(category.name, customName, customIcon))
        }
        categoryOverrides = list
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
        budgets = budgets + budget
    }

    fun updateBudget(budget: FinanceBudget) {
        budgets = budgets.map { if (it.id == budget.id) budget else it }
    }

    fun removeBudget(budget: FinanceBudget) {
        budgets = budgets.filter { it.id != budget.id }
    }

    // ── Financial Goal CRUD ──

    fun addFinancialGoal(goal: FinancialGoal) {
        if (financialGoals.any { it.id == goal.id }) return
        financialGoals = financialGoals + goal
    }

    fun updateFinancialGoal(goal: FinancialGoal) {
        financialGoals = financialGoals.map {
            if (it.id == goal.id) goal.copy(lastModifiedDate = Date()) else it
        }
    }

    fun removeFinancialGoal(goal: FinancialGoal) {
        financialGoals = financialGoals.filter { it.id != goal.id }
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
        val oneTime = totalIncome(entriesList, currentMonthPeriod())
        return recurring + oneTime
    }

    fun monthlyExpenses(entriesList: List<FinanceEntry>): Double {
        val recurring = entriesList
            .filter { it.isRecurring && it.type.isOutflow }
            .sumOf { it.monthlyEquivalent }
        val oneTime = totalExpenses(entriesList, currentMonthPeriod())
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

    fun budgetUsage(entriesList: List<FinanceEntry>, category: FinanceCategory): Double {
        val budget = budgets.find { it.category == category && it.isActive } ?: return 0.0
        val period = currentMonthPeriod()
        val spent = entriesList
            .filter { it.date.time in period && it.category == category && it.type.isOutflow }
            .sumOf { it.amount }
        return if (budget.monthlyLimit > 0) spent / budget.monthlyLimit else 0.0
    }

    fun overBudgetCategories(entriesList: List<FinanceEntry>): List<Pair<FinanceCategory, Double>> {
        return budgets.filter { it.isActive }.mapNotNull { budget ->
            val usage = budgetUsage(entriesList, budget.category)
            if (usage > 1.0) budget.category to usage else null
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
        budgets = emptyList()
        financialGoals = emptyList()
        startingBalance = 0.0
        monthlyBudgetTarget = 0.0
        savingsGoalPercent = 0.0
        savingsGoalAmount = 0.0
        savingsGoalIsPercent = true
        monthlyIncomeGoal = 0.0
        customCategories = emptyList()
        categoryOverrides = emptyList()
    }

    // ── Currency Format Helper ──

    fun formatCurrency(amount: Double): String {
        val formatter = java.text.NumberFormat.getCurrencyInstance()
        formatter.currency = java.util.Currency.getInstance(selectedCurrency.code)
        formatter.maximumFractionDigits = 0
        return formatter.format(amount)
    }
}
