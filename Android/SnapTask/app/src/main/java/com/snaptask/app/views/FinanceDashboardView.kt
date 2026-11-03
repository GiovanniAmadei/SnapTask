package com.snaptask.app

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.UUID
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

private val fm = FinanceManager

enum class ChartPeriod(val key: String, val trendBucketCount: Int, val axisStride: Int) {
    day("period_day", 14, 3),
    week("period_week", 8, 2),
    month("period_month", 6, 1),
    year("period_year", 4, 1);

    val displayName get() = key.localized

    fun interval(reference: Date): DatePeriod = when (this) {
        day -> reference.startOfDay().let { DatePeriod(it, it.addingDays(1)) }
        week -> reference.startOfWeek().let { DatePeriod(it, it.addingDays(7)) }
        month -> reference.startOfMonth().let { DatePeriod(it, it.addingMonths(1)) }
        year -> reference.startOfYear().let { DatePeriod(it, it.addingYears(1)) }
    }

    fun moved(date: Date, by: Int): Date = when (this) {
        day -> date.addingDays(by)
        week -> date.addingWeeks(by)
        month -> date.addingMonths(by)
        year -> date.addingYears(by)
    }
}

private enum class ChartStyle(val icon: String) { pie("chart.pie.fill"), bar("chart.bar.fill") }

private data class BreakdownSlice(val id: String, val name: String, val icon: String, val colorHex: String, val value: Double)
private data class TrendItem(val interval: DatePeriod, val income: Double, val expenses: Double)

private fun whole(amount: Double) = fm.formatCurrency(amount, showCents = false)
private fun cappedPercent(fraction: Double) = if (fraction > 9.99) ">" + fm.formatPercent(9.99) else fm.formatPercent(fraction)

@Composable
fun FinanceDashboardView() {
    val theme = theme
    val presenter = LocalPresenter.current
    val navigator = LocalNavigator.current
    var layoutRaw by appStorage(FinanceCardLayout.storageKey, "")
    val layout = if (layoutRaw.isEmpty()) FinanceCardLayout.default else FinanceCardLayout.from(layoutRaw)
    val activeGoals = fm.financialGoals.filter { it.isActive }
    val totalExceeded = fm.monthlyBudgetTarget > 0 && fm.monthlyExpenses > fm.monthlyBudgetTarget
    val hasGoals = fm.monthlyBudgetTarget > 0 || fm.savingsGoalConfigured || fm.monthlyIncomeGoal > 0

    Column(Modifier.fillMaxSize().background(theme.backgroundColor).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            T("finance".localized, Fonts.largeTitle.bold, modifier = Modifier.weight(1f))
            Box(Modifier.tap { navigator?.push { FinanceSettingsView() } }) { SF("gearshape", theme.primaryColor, 24.dp) }
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = tabBarInset() + 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            BalanceCard()
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(theme.primaryColor)
                    .pressable { presenter.sheet { NavigationStack { FinanceEntryFormView(null) } } }
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SF("plus.circle.fill", theme.buttonTextColor, 18.dp)
                T("add_entry".localized, Fonts.subheadline.semibold, theme.buttonTextColor, maxLines = 1)
            }
            layout.visibleCards.forEach { card ->
                key(card) {
                    when (card) {
                        FinanceDashboardCard.recentEntries -> RecentEntriesSection()
                        FinanceDashboardCard.monthlyGoals -> if (hasGoals) GoalProgressSection()
                        FinanceDashboardCard.savingsGoals -> if (activeGoals.isNotEmpty()) FinancialGoalsCard(activeGoals)
                        FinanceDashboardCard.budgetAlerts -> if (fm.overBudgetCategories().isNotEmpty() || totalExceeded) BudgetAlertsCard(totalExceeded)
                        FinanceDashboardCard.breakdown -> ExpenseBreakdownCard()
                        FinanceDashboardCard.trend -> TrendCard()
                        FinanceDashboardCard.summary -> SummaryCard()
                        FinanceDashboardCard.subscriptions -> if (fm.activeSubscriptions.isNotEmpty()) SubscriptionsSection()
                        FinanceDashboardCard.budget -> if (budgetGaugeTotals() != null) BudgetManagementCard()
                    }
                }
            }
            Row(
                Modifier
                    .padding(top = 4.dp)
                    .clip(CircleShape)
                    .background(theme.primaryColor.copy(alpha = 0.1f))
                    .pressable { presenter.sheet { NavigationStack { FinanceCardLayoutView(showsDoneButton = true) } } }
                    .padding(vertical = 8.dp, horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                SF("slider.horizontal.3", theme.primaryColor, 15.dp)
                T("finance_customize_cards".localized, Fonts.footnote.semibold, theme.primaryColor, maxLines = 1)
            }
        }
    }
}

@Composable
private fun FinanceCard(modifier: Modifier = Modifier, spacing: Int = 14, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxWidth().themedCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(spacing.dp), content = content)
}

@Composable
private fun CardHeader(title: String, icon: String, iconTint: Color = theme.primaryColor, trailing: (@Composable () -> Unit)? = null) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SF(icon, iconTint, 17.dp)
        ShrinkText(title, Fonts.subheadline.semibold, theme.textColor, Modifier.weight(1f), minScale = 0.8f)
        trailing?.invoke()
    }
}

@Composable
private fun BalanceCard() {
    val theme = theme
    val balance = fm.currentBalance
    Column(
        Modifier.fillMaxWidth().themedCard().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        T("current_balance".localized, Fonts.subheadline, theme.secondaryTextColor)
        ShrinkText(fm.formatCurrency(balance), systemFont(34, FontWeight.Bold).monospacedDigit, if (balance >= 0) Color.SysGreen else Color.SysRed)
        if (fm.startingBalance != 0.0) {
            val change = balance - fm.startingBalance
            val color = if (change >= 0) Color.SysGreen else Color.SysRed
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                SF(if (change >= 0) "arrow.up.right" else "arrow.down.right", color, 13.dp)
                T(fm.formatCurrency(abs(change)), Fonts.subheadline.medium.monospacedDigit, color, maxLines = 1)
                T("since_start".localized, Fonts.caption, color, maxLines = 1)
            }
        }
    }
}

// MARK: - Goals

@Composable
private fun GoalBar(fraction: Double, color: Color, height: Int = 6) {
    Box(Modifier.fillMaxWidth().height(height.dp).clip(RoundedCornerShape(3.dp)).background(theme.secondaryTextColor.copy(alpha = 0.15f))) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0.0, 1.0).toFloat()).fillMaxHeight().clip(RoundedCornerShape(3.dp)).background(color))
    }
}

@Composable
private fun goalColor(progress: Double, inverted: Boolean): Color = if (inverted) {
    if (progress > 1.0) Color.SysRed else if (progress > 0.8) Color.SysOrange else Color.SysGreen
} else {
    if (progress >= 1.0) Color.SysGreen else if (progress >= 0.6) Color.SysOrange else Color.SysRed
}

@Composable
private fun GoalRow(icon: String, title: String, current: String, target: String, progress: Double, inverted: Boolean) {
    val color = goalColor(progress, inverted)
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SF(icon, color, 15.dp)
            T(title, Fonts.caption.medium, modifier = Modifier.weight(1f))
            T("$current / $target", Fonts.caption.monospacedDigit, color, maxLines = 1)
        }
        GoalBar(progress, color)
    }
}

@Composable
private fun GoalProgressSection() {
    FinanceCard(spacing = 10) {
        CardHeader("monthly_goals".localized, "target")
        fm.budgetProgress?.let { progress ->
            GoalRow("cart.fill", "monthly_budget_target".localized, whole(fm.monthlyExpenses), whole(fm.monthlyBudgetTarget), min(progress, 1.5), true)
        }
        fm.savingsProgress?.let { progress ->
            if (fm.savingsGoalIsPercent) {
                GoalRow("banknote.fill", "savings_goal".localized, fm.formatPercent(fm.monthlySavingsRate, 1), fm.formatPercent(fm.savingsGoalPercent / 100, 1), min(progress, 1.5), false)
            } else {
                GoalRow("banknote.fill", "savings_goal".localized, whole(max(fm.monthlyIncome - fm.monthlyExpenses, 0.0)), whole(fm.savingsGoalAmount), min(progress, 1.5), false)
            }
        }
        fm.incomeProgress?.let { progress ->
            GoalRow("arrow.down.circle.fill", "income_goal".localized, whole(fm.monthlyIncome), whole(fm.monthlyIncomeGoal), min(progress, 1.5), false)
        }
    }
}

@Composable
private fun FinancialGoalsCard(goals: List<FinancialGoal>) {
    val theme = theme
    val presenter = LocalPresenter.current
    FinanceCard {
        CardHeader("financial_goals".localized, "flag.checkered")
        goals.forEach { goal ->
            key(goal.id) {
                val color = if (goal.isCompleted) Color.SysGreen else theme.primaryColor
                val monthly = goal.monthlyNeeded
                val info = when {
                    goal.isCompleted -> "goal_completed".localized
                    monthly != null && goal.targetDate != null -> "goal_save_per_month".localized(whole(monthly))
                    else -> "goal_to_go".localized(whole(goal.remainingAmount))
                }
                Column(
                    Modifier.fillMaxWidth().pressable { presenter.sheet { NavigationStack { FinancialGoalFormView(goal) } } },
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SF(goal.type.icon, color, 15.dp)
                        T(goal.name, Fonts.caption.medium, modifier = Modifier.weight(1f))
                        T(fm.formatPercent(goal.progress), Fonts.caption.bold.monospacedDigit, color, maxLines = 1)
                    }
                    GoalBar(goal.progress, color)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("${whole(goal.currentAmount)} / ${whole(goal.targetAmount)}", Fonts.caption2.monospacedDigit, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                        T(info, Fonts.caption2, if (goal.isCompleted) Color.SysGreen else theme.secondaryTextColor, TextAlign.End)
                    }
                }
            }
        }
    }
}

// MARK: - Budget

private data class BudgetItem(val id: UUID, val label: String, val icon: String, val limit: Double, val spent: Double, val color: Color)

private fun budgetItems(): List<BudgetItem> {
    val period = fm.currentMonthPeriod()
    return fm.budgets.filter { it.isActive }.map { budget ->
        BudgetItem(budget.id, fm.budgetDisplayName(budget), fm.budgetIcon(budget), budget.monthlyLimit, fm.spentAmount(budget, period), colorFromHex(fm.budgetColorHex(budget)))
    }
}

/** The monthly budget when set, otherwise the sum of the category budgets. */
private fun budgetGaugeTotals(): Pair<Double, Double>? {
    if (fm.monthlyBudgetTarget > 0) return fm.monthlyBudgetTarget to fm.monthlyExpenses
    val items = budgetItems()
    if (items.isEmpty()) return null
    return items.sumOf { it.limit } to items.sumOf { it.spent }
}

@Composable
private fun BudgetManagementCard() {
    val theme = theme
    val items = budgetItems()
    FinanceCard(spacing = 16) {
        CardHeader("budget_management".localized, FinanceDashboardCard.budget.icon)
        budgetGaugeTotals()?.let { (limit, spent) ->
            val remaining = max(limit - spent, 0.0)
            val time = now()
            val days = max(time.daysInMonth - time.dayOfMonth + 1, 0)
            var pace = "budget_days_left".localized(days)
            if (remaining > 0 && days > 0) pace += " · " + "budget_daily_allowance".localized(whole(remaining / days))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                BudgetOverallGauge(
                    if (limit > 0) min(spent / limit, 1.5) else 0.0,
                    if (limit > 0) min(spent / limit * 100, 999.0).toInt() else 0,
                    remaining,
                    max(spent - limit, 0.0),
                    limit,
                )
                ShrinkText(pace, Fonts.caption, theme.secondaryTextColor, minScale = 0.8f)
            }
        }
        if (items.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                items.forEach { item -> key(item.id) { BudgetCategoryRow(item) } }
            }
        }
    }
}

@Composable
private fun BudgetOverallGauge(progress: Double, spentPercent: Int, remaining: Double, overAmount: Double, totalLimit: Double) {
    val theme = theme
    val shown = remember { Animatable(0f) }
    LaunchedEffect(progress) {
        shown.animateTo(progress.toFloat(), tween(if (shown.value == 0f) 900 else 500, easing = FastOutSlowInEasing))
    }
    val isOver = overAmount > 0
    val color = if (progress > 1.0) Color.SysRed else if (progress > 0.8) Color.SysOrange else theme.primaryColor
    val trackColor = theme.secondaryTextColor.copy(alpha = 0.12f)
    val lineShare = 0.06f
    val aspect = (1 - lineShare) / 2 + lineShare
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1 / aspect), contentAlignment = Alignment.BottomCenter) {
            val lineDp = maxWidth * lineShare
            Canvas(Modifier.fillMaxSize()) {
                val line = size.width * lineShare
                val diameter = size.width - line
                val topLeft = Offset(line / 2, size.height - line / 2 - diameter / 2)
                drawArc(trackColor, 180f, 180f, false, topLeft, Size(diameter, diameter), style = Stroke(line, cap = StrokeCap.Round))
                val drawn = shown.value.coerceIn(0f, 1f)
                if (drawn > 0.004f) drawArc(color, 180f, 180f * drawn, false, topLeft, Size(diameter, diameter), style = Stroke(line, cap = StrokeCap.Round))
                val angle = Math.toRadians((180 + 180 * drawn).toDouble())
                val center = Offset(size.width / 2, size.height - line / 2)
                val dot = Offset(center.x + (diameter / 2) * cos(angle).toFloat(), center.y + (diameter / 2) * sin(angle).toFloat())
                drawCircle(Color.Black.copy(alpha = 0.18f), line * 0.32f, dot)
                drawCircle(Color.White, line * 0.25f, dot)
            }
            Column(
                Modifier.padding(start = lineDp * 1.6f, end = lineDp * 1.6f, bottom = lineDp * 0.4f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                ShrinkText("$spentPercent% " + "budget_spent".localized, Fonts.caption.semibold, color, minScale = 0.7f)
                ShrinkText(whole(if (isOver) overAmount else remaining), systemFont(30, FontWeight.Bold).monospacedDigit, if (isOver) Color.SysRed else theme.textColor)
                ShrinkText((if (isOver) "over_budget" else "left_this_month").localized, Fonts.caption, theme.secondaryTextColor, minScale = 0.7f)
            }
        }
        Row {
            T(whole(0.0), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, modifier = Modifier.weight(1f), maxLines = 1)
            T(whole(totalLimit), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
        }
    }
}

@Composable
private fun BudgetCategoryRow(item: BudgetItem) {
    val theme = theme
    val ratio = if (item.limit > 0) item.spent / item.limit else 0.0
    val isOver = item.spent > item.limit
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.size(30.dp).background(item.color.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) { SF(item.icon, item.color, 15.dp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                T(item.label, Fonts.footnote.semibold)
                T(
                    if (isOver) "amount_over".localized(whole(item.spent - item.limit)) else "amount_left".localized(whole(max(item.limit - item.spent, 0.0))),
                    Fonts.caption,
                    if (isOver) Color.SysRed else theme.secondaryTextColor,
                    maxLines = 1,
                )
            }
            T("${whole(item.spent)} / ${whole(item.limit)}", Fonts.caption.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
        }
        Box(Modifier.padding(start = 40.dp)) {
            ThinBar(ratio, if (isOver) Color.SysRed else if (ratio > 0.8) Color.SysOrange else item.color, item.spent > 0)
        }
    }
}

@Composable
private fun ThinBar(fraction: Double, color: Color, showsMinimum: Boolean = fraction > 0) {
    BoxWithConstraints(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(theme.secondaryTextColor.copy(alpha = 0.12f))) {
        val width = if (showsMinimum) maxOf(maxWidth * fraction.coerceIn(0.0, 1.0).toFloat(), 6.dp) else 0.dp
        Box(Modifier.width(width).fillMaxHeight().clip(CircleShape).background(color))
    }
}

@Composable
private fun BudgetAlertsCard(totalExceeded: Boolean) {
    FinanceCard(spacing = 8) {
        CardHeader("over_budget".localized, "exclamationmark.triangle.fill", Color.SysOrange)
        @Composable
        fun row(icon: String, title: String, usage: Double) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.width(20.dp), contentAlignment = Alignment.Center) { SF(icon, Color.SysRed, 14.dp) }
                Spacer(Modifier.width(8.dp))
                T(title, Fonts.caption, modifier = Modifier.weight(1f))
                T(cappedPercent(usage), Fonts.caption.bold.monospacedDigit, Color.SysRed, maxLines = 1)
            }
        }
        if (totalExceeded) row("cart.fill", "budget_total".localized, fm.monthlyExpenses / fm.monthlyBudgetTarget)
        fm.overBudgetCategories().forEach { (budget, usage) -> key(budget.id) { row(fm.budgetIcon(budget), fm.budgetDisplayName(budget), usage) } }
    }
}

// MARK: - Summary

@Composable
private fun <V> FinancePillPicker(selection: V, options: List<V>, onSelect: (V) -> Unit, fillsWidth: Boolean = false, label: @Composable (V, Color) -> Unit) {
    val theme = theme
    Row(
        Modifier.then(if (fillsWidth) Modifier.fillMaxWidth() else Modifier).clip(CircleShape).background(theme.secondaryTextColor.copy(alpha = 0.1f)).padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        options.forEach { option ->
            val selected = option == selection
            val color = if (selected) theme.buttonTextColor else theme.secondaryTextColor
            Box(
                Modifier
                    .then(if (fillsWidth) Modifier.weight(1f) else Modifier)
                    .clip(CircleShape)
                    .background(if (selected) theme.primaryColor else Color.Transparent)
                    .tap { onSelect(option) }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center,
            ) { label(option, color) }
        }
    }
}

@Composable
private fun FlowColumns(income: Double, expenses: Double) {
    val net = income - expenses
    Row {
        FlowColumn("income".localized, whole(income), Color.SysGreen, Color.SysGreen, Modifier.weight(1f))
        FlowColumn("expenses".localized, whole(expenses), Color.SysRed, Color.SysRed, Modifier.weight(1f))
        FlowColumn("net".localized, (if (net >= 0) "+" else "−") + whole(abs(net)), if (net >= 0) Color.SysGreen else Color.SysRed, null, Modifier.weight(1f))
    }
}

@Composable
private fun FlowColumn(title: String, value: String, color: Color, dot: Color?, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            if (dot != null) Box(Modifier.size(7.dp).background(dot.copy(alpha = 0.8f), CircleShape))
            ShrinkText(title, Fonts.caption, theme.secondaryTextColor, minScale = 0.8f)
        }
        ShrinkText(value, Fonts.subheadline.bold.monospacedDigit, color)
    }
}

@Composable
private fun SummaryStat(title: String, caption: String, value: String, color: Color, modifier: Modifier) {
    val theme = theme
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        ShrinkText(title, Fonts.caption2, theme.secondaryTextColor, minScale = 0.8f)
        ShrinkText(value, Fonts.footnote.semibold.monospacedDigit, color, minScale = 0.7f)
        ShrinkText(caption, Fonts.caption2, theme.secondaryTextColor.copy(alpha = 0.7f), minScale = 0.8f)
    }
}

@Composable
private fun SummaryCard() {
    val theme = theme
    var isYearly by remember { mutableStateOf(false) }
    val income = if (isYearly) fm.yearlyIncome else fm.monthlyIncome
    val expenses = if (isYearly) fm.yearlyExpenses else fm.monthlyExpenses
    val rate = if (isYearly) fm.yearlySavingsRate else fm.monthlySavingsRate
    val rateColor = if (rate >= 0.2) Color.SysGreen else if (rate >= 0.1) Color.SysOrange else Color.SysRed
    FinanceCard(Modifier.animateContentSize(tween(250)), spacing = 16) {
        CardHeader(if (isYearly) "yearly_overview".localized + " ${now().yearNumber}" else "monthly_overview".localized, FinanceDashboardCard.summary.icon)
        FinancePillPicker(isYearly, listOf(false, true), { isYearly = it }, fillsWidth = true) { yearly, color ->
            ShrinkText((if (yearly) "ytd" else "period_month").localized, Fonts.caption.semibold, color, minScale = 0.8f)
        }
        FlowColumns(income, expenses)
        if (isYearly) {
            val projected = fm.projectedAnnualIncome - fm.projectedAnnualExpenses
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.fillMaxWidth().height(1.dp).background(theme.secondaryTextColor.copy(alpha = 0.12f)))
                Row {
                    SummaryStat("avg_monthly".localized, "income".localized, whole(fm.yearlyAverageMonthlyIncome), Color.SysGreen, Modifier.weight(1f))
                    SummaryStat("avg_monthly".localized, "expenses".localized, whole(fm.yearlyAverageMonthlyExpenses), Color.SysRed, Modifier.weight(1f))
                    SummaryStat("projected".localized, "annual_net".localized, (if (projected >= 0) "+" else "−") + whole(abs(projected)), if (projected >= 0) Color.SysGreen else Color.SysRed, Modifier.weight(1f))
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T((if (isYearly) "ytd_savings_rate" else "savings_rate").localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                T(fm.formatPercent(rate), Fonts.caption.bold.monospacedDigit, rateColor, maxLines = 1)
            }
            ThinBar(rate, rateColor)
        }
    }
}

@Composable
private fun EmptyChartPlaceholder() {
    val theme = theme
    Column(Modifier.fillMaxWidth().height(140.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically)) {
        SF("chart.bar", theme.secondaryTextColor.copy(alpha = 0.35f), 26.dp)
        T("no_data_yet".localized, Fonts.caption, theme.secondaryTextColor)
    }
}

// MARK: - Breakdown

/** "Oggi", "lun 28 set", "28 set – 4 ott", "Settembre 2026", "2026" */
private fun periodLabel(period: ChartPeriod, interval: DatePeriod): String = when (period) {
    ChartPeriod.day -> when {
        interval.start.isToday() -> "today".localized
        interval.start.isSameDay(now().addingDays(-1)) -> "yesterday".localized
        else -> interval.start.skeleton("EEEdMMM")
    }
    ChartPeriod.week -> "${interval.start.skeleton("dMMM")} – ${interval.end.addingDays(-1).skeleton("dMMM")}"
    ChartPeriod.month -> interval.start.skeleton("MMMMy").replaceFirstChar { it.titlecase(appLocale) }
    ChartPeriod.year -> interval.start.skeleton("y")
}

private fun breakdownSlices(interval: DatePeriod): List<BreakdownSlice> {
    val all = fm.expenseBreakdownDetailed(interval)
    val maxSlices = 6
    val keep = if (all.size > maxSlices) maxSlices - 1 else all.size
    fun idOf(key: FinanceExpenseBreakdownKey) = when (key) {
        is FinanceExpenseBreakdownKey.BuiltIn -> "builtIn:${key.category.rawValue}"
        is FinanceExpenseBreakdownKey.Custom -> "custom:${key.id}"
    }
    val slices = all.take(keep).map { (key, value) ->
        BreakdownSlice(idOf(key), fm.expenseBreakdownDisplayName(key), fm.expenseBreakdownIcon(key), fm.expenseBreakdownColorHex(key), value)
    }.toMutableList()
    val rest = all.drop(keep).sumOf { it.second }
    if (rest > 0) {
        val index = slices.indexOfFirst { it.id == "builtIn:other" }
        if (index >= 0) slices[index] = slices[index].copy(value = slices[index].value + rest)
        else slices += BreakdownSlice("others", fm.displayName(FinanceCategory.other), "ellipsis.circle.fill", fm.colorHex(FinanceCategory.other), rest)
    }
    return slices
}

@Composable
private fun ExpenseBreakdownCard() {
    val theme = theme
    var period by remember { mutableStateOf(ChartPeriod.month) }
    var offset by remember { mutableStateOf(0) }
    var style by remember { mutableStateOf(ChartStyle.pie) }
    var selectedId by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(period) { offset = 0 }
    LaunchedEffect(period, offset, style) { selectedId = null }
    val interval = period.interval(period.moved(now(), offset))
    val slices = breakdownSlices(interval)
    val total = slices.sumOf { it.value }

    FinanceCard(Modifier.animateContentSize(tween(250))) {
        CardHeader("expense_breakdown".localized, FinanceDashboardCard.breakdown.icon) {
            FinancePillPicker(style, ChartStyle.entries, { style = it }) { option, color -> SF(option.icon, color, 14.dp) }
        }
        FinancePillPicker(period, ChartPeriod.entries, { period = it }, fillsWidth = true) { option, color ->
            ShrinkText(option.displayName, Fonts.caption.semibold, color, minScale = 0.8f)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            NavigatorButton("chevron.left", true) { offset -= 1 }
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { ShrinkText(periodLabel(period, interval), Fonts.footnote.semibold, theme.textColor, minScale = 0.8f) }
            NavigatorButton("chevron.right", offset < 0) { offset += 1 }
        }
        if (slices.isEmpty()) {
            EmptyChartPlaceholder()
        } else if (style == ChartStyle.pie) {
            val selected = slices.firstOrNull { it.id == selectedId }
            DonutChart(
                slices.map { PieSlice(it.value.toFloat(), colorFromHex(it.colorHex)) },
                Modifier.fillMaxWidth().height(190.dp),
                selectedIndex = slices.indexOfFirst { it.id == selectedId }.takeIf { it >= 0 },
                onSelect = { index ->
                    val id = index?.let { slices.getOrNull(it)?.id }
                    selectedId = if (id == selectedId) null else id
                },
            ) {
                Column(Modifier.widthIn(max = 110.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    ShrinkText(selected?.name ?: "total".localized, Fonts.caption.medium, selected?.let { colorFromHex(it.colorHex) } ?: theme.secondaryTextColor, minScale = 0.7f)
                    ShrinkText(whole(selected?.value ?: total), systemFont(22, FontWeight.Bold).monospacedDigit, theme.textColor, minScale = 0.5f)
                    if (selected != null) T(fm.formatPercent(if (total > 0) selected.value / total else 0.0, 1), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                }
            }
            Column {
                slices.forEach { slice ->
                    key(slice.id) {
                        val color = colorFromHex(slice.colorHex)
                        val isSelected = slice.id == selectedId
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (isSelected) color.copy(alpha = 0.12f) else Color.Transparent)
                                .tap { selectedId = if (isSelected) null else slice.id }
                                .padding(vertical = 7.dp, horizontal = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Box(Modifier.size(8.dp).background(color, CircleShape))
                            T(slice.name, Fonts.footnote, modifier = Modifier.weight(1f))
                            T(fm.formatPercent(if (total > 0) slice.value / total else 0.0, 1), Fonts.caption.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                            T(fm.formatCurrency(slice.value), Fonts.footnote.semibold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.widthIn(min = 78.dp))
                        }
                    }
                }
            }
        } else {
            val most = slices.maxOf { it.value }
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                slices.forEach { slice ->
                    key(slice.id) {
                        val color = colorFromHex(slice.colorHex)
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(Modifier.size(26.dp).background(color.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) { SF(slice.icon, color, 13.dp) }
                                T(slice.name, Fonts.footnote.medium, modifier = Modifier.weight(1f))
                                T(fm.formatCurrency(slice.value), Fonts.footnote.semibold.monospacedDigit, maxLines = 1)
                            }
                            Row(Modifier.padding(start = 36.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(Modifier.weight(1f)) { ThinBar(if (most > 0) slice.value / most else 0.0, color) }
                                T(fm.formatPercent(if (total > 0) slice.value / total else 0.0, 1), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, align = TextAlign.End, maxLines = 1, modifier = Modifier.widthIn(min = 40.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NavigatorButton(icon: String, enabled: Boolean, onClick: () -> Unit) {
    val theme = theme
    Box(
        Modifier
            .size(30.dp)
            .alpha(if (enabled) 1f else 0.3f)
            .background(theme.primaryColor.copy(alpha = 0.1f), CircleShape)
            .tap(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { SF(icon, theme.primaryColor, 14.dp) }
}

// MARK: - Trend

private fun trendBuckets(period: ChartPeriod): List<TrendItem> {
    val current = period.interval(now()).start
    return (period.trendBucketCount - 1 downTo 0).map { back ->
        val interval = period.interval(period.moved(current, -back))
        TrendItem(interval, fm.totalIncome(interval), fm.totalExpenses(interval))
    }
}

/** Axis labels: 950, 1.5k, -2k */
private fun formatCompact(value: Double): String {
    val sign = if (value < 0) "−" else ""
    val magnitude = abs(value)
    if (magnitude >= 1000) {
        val thousands = magnitude / 1000
        val digits = if (thousands < 10 && thousands % 1 != 0.0) 1 else 0
        return sign + java.text.NumberFormat.getNumberInstance(appLocale).apply { maximumFractionDigits = digits; minimumFractionDigits = digits }.format(thousands) + "k"
    }
    return sign + java.text.NumberFormat.getIntegerInstance(appLocale).format(magnitude)
}

private fun trendAxisLabel(period: ChartPeriod, date: Date) = when (period) {
    ChartPeriod.day, ChartPeriod.week -> date.skeleton("dMMM")
    ChartPeriod.month -> date.skeleton("MMM")
    ChartPeriod.year -> date.skeleton("y")
}

@Composable
private fun TrendCard() {
    val theme = theme
    var period by remember { mutableStateOf(ChartPeriod.month) }
    var selection by remember { mutableStateOf<Date?>(null) }
    LaunchedEffect(period) { selection = null }
    val data = trendBuckets(period)
    val hasValues = data.any { it.income > 0 || it.expenses > 0 }
    FinanceCard {
        CardHeader("finance_trend".localized, FinanceDashboardCard.trend.icon)
        FinancePillPicker(period, ChartPeriod.entries, { period = it }, fillsWidth = true) { option, color ->
            ShrinkText(option.displayName, Fonts.caption.semibold, color, minScale = 0.8f)
        }
        if (hasValues) {
            TrendChart(data, period, selection) { tapped -> selection = if (tapped == selection) null else tapped }
            Box(Modifier.fillMaxWidth().height(1.dp).background(theme.secondaryTextColor.copy(alpha = 0.12f)))
            val selected = data.firstOrNull { it.interval.start == selection }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val rangeKey = when (period) {
                    ChartPeriod.day -> "last_n_days"
                    ChartPeriod.week -> "last_n_weeks"
                    ChartPeriod.month -> "last_n_months"
                    ChartPeriod.year -> "last_n_years"
                }
                T(selected?.let { periodLabel(period, it.interval) } ?: rangeKey.localized(period.trendBucketCount), Fonts.caption.semibold, theme.secondaryTextColor)
                FlowColumns(selected?.income ?: data.sumOf { it.income }, selected?.expenses ?: data.sumOf { it.expenses })
            }
        } else {
            EmptyChartPlaceholder()
        }
    }
}

/** Income above the line, expenses below it: one bar per day / week / month / year. */
@Composable
private fun TrendChart(data: List<TrendItem>, period: ChartPeriod, selection: Date?, onTap: (Date?) -> Unit) {
    val theme = theme
    val measurer = rememberTextMeasurer()
    val labelColor = theme.secondaryTextColor
    val gridColor = theme.secondaryTextColor.copy(alpha = 0.2f)
    val zeroColor = theme.secondaryTextColor.copy(alpha = 0.3f)
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, color = labelColor)
    val top = data.maxOf { it.income }
    val bottom = data.maxOf { it.expenses }
    val most = niceStep(max(top, bottom))
    val hasIncome = top > 0
    val hasExpenses = bottom > 0
    val maxY = if (hasIncome) most * ceil(top / most) else 0.0
    val minY = if (hasExpenses) -most * ceil(bottom / most) else 0.0
    val ticks = generateSequence(minY) { it + most }.takeWhile { it <= maxY + most * 0.01 }.toList()
    val green = Color.SysGreen
    val red = Color.SysRed
    val density = LocalDensity.current
    val axisWidth = remember(ticks) { with(density) { ticks.maxOf { measurer.measure(formatCompact(it), labelStyle).size.width }.toDp() + 6.dp } }

    Canvas(
        Modifier
            .fillMaxWidth()
            .height(190.dp)
            .pointerInput(data) {
                detectTapGestures { position ->
                    val left = axisWidth.toPx()
                    val slot = (size.width - left) / data.size
                    val index = ((position.x - left) / slot).toInt()
                    onTap(data.getOrNull(index)?.interval?.start)
                }
            },
    ) {
        val left = axisWidth.toPx()
        val axisHeight = 20.dp.toPx()
        val plot = size.height - axisHeight
        val range = (maxY - minY).takeIf { it > 0 } ?: 1.0
        fun y(value: Double) = (plot * (1 - (value - minY) / range)).toFloat()
        ticks.forEach { tick ->
            drawLine(gridColor, Offset(left, y(tick)), Offset(size.width, y(tick)), 0.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())))
            val text = measurer.measure(formatCompact(tick), labelStyle)
            drawText(text, topLeft = Offset(0f, (y(tick) - text.size.height / 2).coerceIn(0f, plot)))
        }
        val slot = (size.width - left) / data.size
        val barWidth = slot * 0.62f
        val corner = CornerRadius(3.dp.toPx())
        data.forEachIndexed { index, item ->
            val x = left + slot * index + (slot - barWidth) / 2
            val dimmed = selection != null && selection != item.interval.start
            val alpha = if (dimmed) 0.25f else 0.8f
            if (item.income > 0) drawRoundRect(green.copy(alpha = alpha), Offset(x, y(item.income)), Size(barWidth, y(0.0) - y(item.income)), corner)
            if (item.expenses > 0) drawRoundRect(red.copy(alpha = alpha), Offset(x, y(0.0)), Size(barWidth, y(-item.expenses) - y(0.0)), corner)
            if (index % period.axisStride == 0) {
                val text = measurer.measure(trendAxisLabel(period, item.interval.start), labelStyle)
                val labelX = (left + slot * index + slot / 2 - text.size.width / 2).coerceIn(left, size.width - text.size.width)
                drawText(text, topLeft = Offset(labelX, plot + 4.dp.toPx()))
            }
        }
        drawLine(zeroColor, Offset(left, y(0.0)), Offset(size.width, y(0.0)), 1.dp.toPx())
    }
}

private fun niceStep(most: Double): Double {
    if (most <= 0) return 1.0
    val rough = most / 2
    val magnitude = Math.pow(10.0, Math.floor(Math.log10(rough)))
    val normalized = rough / magnitude
    val nice = if (normalized <= 1) 1.0 else if (normalized <= 2) 2.0 else if (normalized <= 5) 5.0 else 10.0
    return nice * magnitude
}

// MARK: - Entries

@Composable
private fun FinanceEntryRow(entry: FinanceEntry) {
    val theme = theme
    val tint = colorFromHex(entry.type.color)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(32.dp).background(tint.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) { SF(fm.categoryIcon(entry), tint, 15.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            ShrinkText(entry.name, Fonts.subheadline.medium, theme.textColor, minScale = 0.8f)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                T(fm.categoryDisplayName(entry), Fonts.caption, theme.secondaryTextColor, maxLines = 1)
                if (entry.isRecurring) SF("repeat", theme.secondaryTextColor, 11.dp)
            }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T((if (entry.type.isOutflow) "-" else "+") + fm.formatCurrency(entry.amount), Fonts.subheadline.bold.monospacedDigit, if (entry.type.isOutflow) Color.SysRed else Color.SysGreen, maxLines = 1)
            T(fm.formatShortDate(entry.date), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
        }
    }
}

@Composable
private fun RecentEntriesSection() {
    val theme = theme
    val presenter = LocalPresenter.current
    FinanceCard(spacing = 10) {
        CardHeader("recent_entries".localized, FinanceDashboardCard.recentEntries.icon) {
            T(
                "show_more".localized,
                Fonts.caption.semibold,
                theme.primaryColor,
                maxLines = 1,
                modifier = Modifier
                    .alpha(if (fm.entries.isEmpty()) 0f else 1f)
                    .tap(enabled = fm.entries.isNotEmpty()) { presenter.sheet { NavigationStack { FinanceAllEntriesView() } } },
            )
        }
        if (fm.entries.isEmpty()) {
            Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SF("banknote", theme.secondaryTextColor.copy(alpha = 0.4f), 30.dp)
                T("no_finance_entries".localized, Fonts.caption, theme.secondaryTextColor)
            }
        } else {
            fm.entries.sortedByDescending { it.date }.take(4).forEach { entry ->
                key(entry.id) {
                    var menuOpen by remember { mutableStateOf(false) }
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .pressable(onLongPress = {
                                Haptics.medium()
                                menuOpen = true
                            }) { presenter.sheet { NavigationStack { FinanceEntryFormView(entry) } } }
                            .padding(vertical = 4.dp),
                    ) {
                        FinanceEntryRow(entry)
                        if (menuOpen) {
                            MenuPopup(
                                listOf(
                                    MenuItem("edit".localized, "pencil") { presenter.sheet { NavigationStack { FinanceEntryFormView(entry) } } },
                                    MenuItem("duplicate".localized, "plus.square.on.square") { fm.duplicateEntry(entry) },
                                    MenuItem("delete".localized, "trash", destructive = true) { fm.removeEntry(entry) },
                                ),
                            ) { menuOpen = false }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SubscriptionsSection() {
    val theme = theme
    val presenter = LocalPresenter.current
    FinanceCard(spacing = 10) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF("repeat.circle.fill", Color.SysOrange, 18.dp)
            T("active_subscriptions".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
            T(fm.formatCurrency(fm.monthlySubscriptionCost) + "per_month".localized, Fonts.caption.bold.monospacedDigit, Color.SysOrange, maxLines = 1)
        }
        fm.activeSubscriptions.forEach { sub ->
            key(sub.id) {
                val parts = buildList {
                    fm.nextOccurrence(sub)?.let { add("next_charge".localized(fm.formatShortDate(it))) }
                    sub.recurringEndDate?.let { add("recurring_ends_on".localized(fm.formatShortDate(it))) }
                }
                Row(
                    Modifier
                        .fillMaxWidth()
                        .tap { presenter.sheet { NavigationStack { FinanceEntryFormView(sub) } } }
                        .padding(vertical = 3.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T(sub.name, Fonts.subheadline)
                        if (parts.isNotEmpty()) T(parts.joinToString(" · "), Fonts.caption2, theme.secondaryTextColor)
                    }
                    T(fm.formatCurrency(sub.amount), Fonts.subheadline.medium.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                    sub.recurringFrequency?.let { T("/ " + it.displayName, Fonts.caption, theme.secondaryTextColor, maxLines = 1, modifier = Modifier.padding(top = 2.dp)) }
                }
            }
        }
    }
}

// MARK: - All entries

@Composable
internal fun FinanceAllEntriesView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    var search by remember { mutableStateOf("") }
    val query = search.trim()
    val filtered = fm.entries.sortedByDescending { it.date }.filter { entry ->
        query.isEmpty() || listOf(entry.name, fm.categoryDisplayName(entry), entry.notes ?: "").any { it.contains(query, ignoreCase = true) }
    }
    val groups = filtered.groupBy { it.date.startOfMonth() }.toList().sortedByDescending { it.first }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("all_entries".localized, trailing = { BarButton("done".localized, bold = true, onClick = dismiss) })
        Row(
            Modifier
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(Color.TertiaryFill)
                .padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            SF("magnifyingglass", Color.Secondary, 18.dp)
            PlainField(search, { search = it }, "search_entries".localized, modifier = Modifier.weight(1f))
        }
        if (groups.isEmpty()) {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                T((if (search.isEmpty()) "no_finance_entries" else "no_results_found").localized, Fonts.subheadline, theme.secondaryTextColor)
            }
        } else {
            FormPage(Modifier.weight(1f)) {
                groups.forEach { (month, entries) ->
                    FormSection(month.skeleton("MMMMy").replaceFirstChar { it.titlecase(appLocale) }) {
                        entries.forEachIndexed { index, entry ->
                            key(entry.id) {
                                SwipeRow(
                                    leading = listOf(SwipeAction2("plus.square.on.square", "duplicate".localized, theme.primaryColor) { fm.duplicateEntry(entry) }),
                                    trailing = listOf(
                                        SwipeAction2("pencil", "edit".localized, Color.SysBlue) { presenter.sheet { NavigationStack { FinanceEntryFormView(entry) } } },
                                        SwipeAction2("trash", "delete".localized, Color.SysRed) { fm.removeEntry(entry) },
                                    ),
                                ) {
                                    Box(
                                        Modifier
                                            .fillMaxWidth()
                                            .background(theme.surfaceColor)
                                            .tap { presenter.sheet { NavigationStack { FinanceEntryFormView(entry) } } }
                                            .padding(horizontal = 16.dp, vertical = 10.dp),
                                    ) { FinanceEntryRow(entry) }
                                }
                            }
                            if (index < entries.lastIndex) RowDivider()
                        }
                    }
                }
            }
        }
    }
}

data class SwipeAction2(val icon: String, val title: String, val color: Color, val action: () -> Unit)

/** `.swipeActions` for a row that is not in a `List`. */
@Composable
fun SwipeRow(leading: List<SwipeAction2> = emptyList(), trailing: List<SwipeAction2> = emptyList(), content: @Composable () -> Unit) {
    val density = LocalDensity.current
    val width = with(density) { 74.dp.toPx() }
    val offset = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val maxRight = width * leading.size
    val maxLeft = -width * trailing.size
    fun settle(target: Float) {
        scope.launch { offset.animateTo(target, androidx.compose.animation.core.spring(dampingRatio = 0.85f, stiffness = 400f)) }
    }
    @Composable
    fun button(action: SwipeAction2) {
        Column(
            Modifier.width(74.dp).fillMaxHeight().background(action.color).tap {
                settle(0f)
                action.action()
            },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
        ) {
            SF(action.icon, Color.White, 18.dp)
            T(action.title, Fonts.caption2.semibold, Color.White, maxLines = 1)
        }
    }
    Box(Modifier.fillMaxWidth()) {
        Row(Modifier.matchParentSize()) {
            leading.forEach { button(it) }
            Spacer(Modifier.weight(1f))
            trailing.forEach { button(it) }
        }
        Box(
            Modifier
                .offset { androidx.compose.ui.unit.IntOffset(offset.value.toInt(), 0) }
                .androidxDraggable(
                    onDelta = { delta -> scope.launch { offset.snapTo((offset.value + delta).coerceIn(maxLeft, maxRight)) } },
                    onStop = {
                        settle(
                            when {
                                offset.value > maxRight / 2 && maxRight > 0 -> maxRight
                                offset.value < maxLeft / 2 && maxLeft < 0 -> maxLeft
                                else -> 0f
                            },
                        )
                    },
                ),
        ) { content() }
    }
}

@Composable
private fun Modifier.androidxDraggable(onDelta: (Float) -> Unit, onStop: () -> Unit): Modifier =
    this.then(
        Modifier.draggable(
            androidx.compose.foundation.gestures.rememberDraggableState(onDelta),
            androidx.compose.foundation.gestures.Orientation.Horizontal,
            onDragStopped = { onStop() },
        ),
    )
