package com.snaptask.app.data.model

import java.util.Calendar
import java.util.Date
import java.util.UUID

// ── Finance Entry Type ──
// Faithful port of iOS FinanceEntryType enum

enum class FinanceEntryType(val displayName: String, val icon: String, val color: String) {
    INCOME("Income", "arrow_downward", "#22C55E"),
    EXPENSE("Expense", "arrow_upward", "#EF4444"),
    SUBSCRIPTION("Subscription", "repeat", "#F97316"),
    SAVING("Saving", "account_balance", "#3B82F6"),
    INVESTMENT("Investment", "trending_up", "#8B5CF6"),
    DEBT("Debt", "credit_card", "#DC2626");

    val isOutflow: Boolean
        get() = when (this) {
            INCOME, SAVING, INVESTMENT -> false
            EXPENSE, SUBSCRIPTION, DEBT -> true
        }

    companion object {
        fun fromString(value: String): FinanceEntryType = entries.find {
            it.name.equals(value, ignoreCase = true)
        } ?: EXPENSE
    }
}

// ── Finance Category ──
// Faithful port of iOS FinanceCategory enum

enum class FinanceCategory(val displayName: String, val icon: String) {
    HOUSING("Housing", "home"),
    FOOD("Food", "restaurant"),
    TRANSPORT("Transport", "directions_car"),
    HEALTH("Health", "favorite"),
    ENTERTAINMENT("Entertainment", "sports_esports"),
    EDUCATION("Education", "menu_book"),
    CLOTHING("Clothing", "checkroom"),
    UTILITIES("Utilities", "bolt"),
    INSURANCE("Insurance", "shield"),
    SALARY("Salary", "work"),
    FREELANCE("Freelance", "laptop"),
    PASSIVE("Passive", "trending_up"),
    GIFTS("Gifts", "card_giftcard"),
    OTHER("Other", "more_horiz");

    val isIncomeCategory: Boolean
        get() = this in listOf(SALARY, FREELANCE, PASSIVE)

    companion object {
        fun fromString(value: String): FinanceCategory = entries.find {
            it.name.equals(value, ignoreCase = true)
        } ?: OTHER
    }
}

// ── Subscription Frequency ──

enum class SubscriptionFrequency(val displayName: String) {
    WEEKLY("Weekly"),
    MONTHLY("Monthly"),
    QUARTERLY("Quarterly"),
    YEARLY("Yearly");

    val monthlyMultiplier: Double
        get() = when (this) {
            WEEKLY -> 4.33
            MONTHLY -> 1.0
            QUARTERLY -> 1.0 / 3.0
            YEARLY -> 1.0 / 12.0
        }

    companion object {
        fun fromString(value: String): SubscriptionFrequency = entries.find {
            it.name.equals(value, ignoreCase = true)
        } ?: MONTHLY
    }
}

// ── Finance Entry ──

data class FinanceEntry(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var amount: Double,
    var type: FinanceEntryType,
    var category: FinanceCategory = FinanceCategory.OTHER,
    var customCategoryId: UUID? = null,
    var date: Date = Date(),
    var notes: String? = null,
    var isRecurring: Boolean = false,
    var recurringFrequency: SubscriptionFrequency? = null,
    var recurringEndDate: Date? = null,
    var tags: List<String> = emptyList(),
    val creationDate: Date = Date(),
    var lastModifiedDate: Date = Date(),
) {
    val monthlyEquivalent: Double
        get() {
            if (!isRecurring || recurringFrequency == null) return amount
            return amount * recurringFrequency!!.monthlyMultiplier
        }

    val signedAmount: Double
        get() = if (type.isOutflow) -amount else amount

    init {
        amount = kotlin.math.abs(amount)
        if (isRecurring && recurringFrequency == null) {
            recurringFrequency = SubscriptionFrequency.MONTHLY
        }
        if (!isRecurring) recurringFrequency = null
    }
}

// ── Finance Budget ──

data class FinanceBudget(
    val id: UUID = UUID.randomUUID(),
    var category: FinanceCategory,
    var customCategoryId: UUID? = null,
    var monthlyLimit: Double,
    var isActive: Boolean = true,
    val creationDate: Date = Date(),
)

// ── Financial Goal ──

data class FinancialGoal(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var targetAmount: Double,
    var currentAmount: Double = 0.0,
    var targetDate: Date? = null,
    var type: FinancialGoalType = FinancialGoalType.SAVINGS,
    var isActive: Boolean = true,
    val creationDate: Date = Date(),
    var lastModifiedDate: Date = Date(),
) {
    val progress: Double
        get() = if (targetAmount > 0) (currentAmount / targetAmount).coerceIn(0.0, 1.0) else 0.0

    val remainingAmount: Double
        get() = (targetAmount - currentAmount).coerceAtLeast(0.0)

    val monthlyNeeded: Double?
        get() {
            val target = targetDate ?: return null
            val cal = Calendar.getInstance()
            val now = Date()
            val months = ((target.time - now.time) / (30L * 24 * 60 * 60 * 1000)).toInt()
            return if (months > 0) remainingAmount / months else remainingAmount
        }
}

// ── Financial Goal Type ──

enum class FinancialGoalType(val displayName: String, val icon: String) {
    SAVINGS("Savings", "account_balance"),
    DEBT_PAYOFF("Debt Payoff", "credit_card"),
    INVESTMENT("Investment", "trending_up"),
    EMERGENCY("Emergency", "shield"),
    PURCHASE("Purchase", "shopping_cart");

    companion object {
        fun fromString(value: String): FinancialGoalType = entries.find {
            it.name.equals(value, ignoreCase = true)
        } ?: SAVINGS
    }
}

// ── Financial Stress Level ──

enum class FinancialStressLevel(val color: String) {
    COMFORTABLE("#22C55E"),
    BALANCED("#3B82F6"),
    TIGHT("#F59E0B"),
    STRESSED("#F97316"),
    CRITICAL("#EF4444");
}

// ── Finance Snapshot Summary ──

data class FinanceSnapshotSummary(
    val totalIncome: Double,
    val totalExpenses: Double,
    val netFlow: Double,
    val savingsRate: Double,
    val stressLevel: FinancialStressLevel,
    val topExpenseCategory: String?,
    val monthlyBurnRate: Double,
    val runwayMonths: Double?,
)

// ── Custom Finance Category ──

data class CustomFinanceCategory(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var icon: String = "label",
    var colorHex: String? = null,
    var isExpenseCategory: Boolean = true,
    val creationDate: Date = Date(),
)

// ── Finance Category Override ──

data class FinanceCategoryOverride(
    val categoryRawValue: String,
    var customName: String? = null,
    var customIcon: String? = null,
    var customColorHex: String? = null,
)

/**
 * The complete finance configuration stored in DataStore. Keeping it as one
 * value makes budget/category/settings updates atomic and survives restarts,
 * just like the iOS UserDefaults-backed FinanceManager.
 */
data class FinanceSettingsState(
    val budgets: List<FinanceBudget> = emptyList(),
    val financialGoals: List<FinancialGoal> = emptyList(),
    val startingBalance: Double = 0.0,
    val monthlyBudgetTarget: Double = 0.0,
    val savingsGoalPercent: Double = 0.0,
    val savingsGoalAmount: Double = 0.0,
    val savingsGoalIsPercent: Boolean = true,
    val monthlyIncomeGoal: Double = 0.0,
    val customCategories: List<CustomFinanceCategory> = emptyList(),
    val categoryOverrides: List<FinanceCategoryOverride> = emptyList(),
    val hiddenBuiltInCategories: Set<String> = emptySet(),
    val selectedCurrencyCode: String = SupportedCurrency.EUR.code,
)

// ── Supported Currencies ──

enum class SupportedCurrency(val code: String, val symbol: String) {
    EUR("EUR", "€"),
    USD("USD", "$"),
    GBP("GBP", "£"),
    CHF("CHF", "CHF"),
    JPY("JPY", "¥"),
    CNY("CNY", "¥"),
    CAD("CAD", "CA$"),
    AUD("AUD", "A$"),
    BRL("BRL", "R$"),
    INR("INR", "₹"),
    KRW("KRW", "₩"),
    SEK("SEK", "kr"),
    NOK("NOK", "kr"),
    DKK("DKK", "kr"),
    PLN("PLN", "zł"),
    CZK("CZK", "Kč"),
    MXN("MXN", "MX$"),
    TRY_("TRY", "₺");

    val displayName: String get() = "$symbol - $code"

    companion object {
        fun fromCode(code: String): SupportedCurrency = entries.find {
            it.code.equals(code, ignoreCase = true)
        } ?: EUR
    }
}
