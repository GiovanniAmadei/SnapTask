package com.snaptask.app.ui.finance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.*
import com.snaptask.app.data.repository.FinanceRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel for the Finance tab.
 * Bridges FinanceRepository to the Compose UI.
 */
@HiltViewModel
class FinanceViewModel @Inject constructor(
    private val repository: FinanceRepository,
) : ViewModel() {

    val entries: StateFlow<List<FinanceEntry>> = repository.entries
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Recalculate immediately when an entry or any persisted finance setting changes.
    private val calculationInput: Flow<List<FinanceEntry>> =
        combine(entries, repository.settings) { list, _ -> list }

    // Derived data
    val currentBalance: StateFlow<Double> = calculationInput.map { repository.currentBalance(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val monthlyIncome: StateFlow<Double> = calculationInput.map { repository.monthlyIncome(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val monthlyExpenses: StateFlow<Double> = calculationInput.map { repository.monthlyExpenses(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val netFlow: StateFlow<Double> = calculationInput.map {
        repository.netFlow(it, repository.currentMonthPeriod())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val stressLevel: StateFlow<FinancialStressLevel> = calculationInput.map {
        repository.financialStressLevel(it)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), FinancialStressLevel.BALANCED)

    val monthlySavingsRate: StateFlow<Double> = calculationInput.map {
        repository.monthlySavingsRate(it)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val activeSubscriptions: StateFlow<List<FinanceEntry>> = calculationInput.map {
        repository.activeSubscriptions(it)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val monthlySubscriptionCost: StateFlow<Double> = calculationInput.map {
        repository.monthlySubscriptionCost(it)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val expenseBreakdown: StateFlow<List<Pair<FinanceCategory, Double>>> = calculationInput.map {
        repository.expenseBreakdown(it, repository.currentMonthPeriod())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // ── Properties delegated to repository ──

    val selectedCurrency: SupportedCurrency get() = repository.selectedCurrency
    val startingBalance: Double get() = repository.startingBalance
    val monthlyBudgetTarget: Double get() = repository.monthlyBudgetTarget
    val savingsGoalPercent: Double get() = repository.savingsGoalPercent
    val savingsGoalAmount: Double get() = repository.savingsGoalAmount
    val savingsGoalIsPercent: Boolean get() = repository.savingsGoalIsPercent
    val savingsGoalConfigured: Boolean get() = repository.savingsGoalConfigured
    val monthlyIncomeGoal: Double get() = repository.monthlyIncomeGoal
    val budgets: List<FinanceBudget> get() = repository.budgets
    val financialGoals: List<FinancialGoal> get() = repository.financialGoals
    val customCategories: List<CustomFinanceCategory> get() = repository.customCategories

    // ── Budget Progress ──

    fun budgetProgress(): Double? = repository.budgetProgress(entries.value)
    fun savingsProgress(): Double? = repository.savingsProgress(entries.value)
    fun incomeProgress(): Double? = repository.incomeProgress(entries.value)
    fun runwayMonths(): Double? = repository.runwayMonths(entries.value)

    fun budgetUsage(category: FinanceCategory): Double =
        repository.budgetUsage(entries.value, category)

    fun budgetUsage(budget: FinanceBudget): Double = repository.budgetUsage(entries.value, budget)
    fun spentAmount(budget: FinanceBudget): Double = repository.spentAmount(entries.value, budget)

    fun topExpenseCategory(): FinanceCategory? = repository.topExpenseCategory(entries.value)

    // ── Entry CRUD ──

    fun addEntry(entry: FinanceEntry) {
        viewModelScope.launch { repository.addEntry(entry) }
    }

    fun updateEntry(entry: FinanceEntry) {
        viewModelScope.launch { repository.updateEntry(entry) }
    }

    fun deleteEntry(entry: FinanceEntry) {
        viewModelScope.launch { repository.removeEntry(entry) }
    }

    // ── Budget CRUD ──

    fun addBudget(budget: FinanceBudget) = repository.addBudget(budget)
    fun updateBudget(budget: FinanceBudget) = repository.updateBudget(budget)
    fun removeBudget(budget: FinanceBudget) = repository.removeBudget(budget)

    // ── Goal CRUD ──

    fun addGoal(goal: FinancialGoal) = repository.addFinancialGoal(goal)
    fun updateGoal(goal: FinancialGoal) = repository.updateFinancialGoal(goal)
    fun removeGoal(goal: FinancialGoal) = repository.removeFinancialGoal(goal)

    // ── Settings ──

    fun setStartingBalance(amount: Double) = repository.setStartingBalance(amount)
    fun setMonthlyBudgetTarget(amount: Double) = repository.setMonthlyBudgetTarget(amount)
    fun setSavingsGoalPercent(percent: Double) = repository.setSavingsGoalPercent(percent)
    fun setSavingsGoalAmount(amount: Double) = repository.setSavingsGoalAmount(amount)
    fun setSavingsGoalIsPercent(isPercent: Boolean) = repository.setSavingsGoalIsPercent(isPercent)
    fun setMonthlyIncomeGoal(amount: Double) = repository.setMonthlyIncomeGoal(amount)
    fun setSelectedCurrency(currency: SupportedCurrency) = repository.setSelectedCurrency(currency)

    // ── Custom Category ──

    fun addCustomCategory(category: CustomFinanceCategory) = repository.addCustomCategory(category)
    fun updateCustomCategory(category: CustomFinanceCategory) = repository.updateCustomCategory(category)
    fun removeCustomCategory(category: CustomFinanceCategory) = repository.removeCustomCategory(category)

    // ── Category Override ──

    fun setCategoryOverride(category: FinanceCategory, name: String?, icon: String?) =
        repository.setCategoryOverride(category, name, icon)

    fun displayName(category: FinanceCategory): String = repository.displayName(category)
    fun icon(category: FinanceCategory): String = repository.icon(category)
    fun categoryDisplayName(entry: FinanceEntry): String = repository.categoryDisplayName(entry)
    fun categoryIcon(entry: FinanceEntry): String = repository.categoryIcon(entry)
    fun budgetDisplayName(budget: FinanceBudget): String =
        repository.customCategory(budget.customCategoryId)?.name ?: repository.displayName(budget.category)
    fun budgetColorHex(budget: FinanceBudget): String =
        if (budget.customCategoryId != null) repository.colorHex(budget.customCategoryId) else repository.colorHex(budget.category)

    // ── Currency Formatting ──

    fun formatCurrency(amount: Double): String = repository.formatCurrency(amount)

    // ── Reset ──

    fun resetAll() = repository.resetAll()
}
