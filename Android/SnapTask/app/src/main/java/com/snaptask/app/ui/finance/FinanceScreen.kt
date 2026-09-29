package com.snaptask.app.ui.finance

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R
import com.snaptask.app.data.model.*
import com.snaptask.app.ui.components.parseHexColor
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Finance dashboard — faithful port of iOS FinanceDashboardView.
 * Sections: balance card, quick actions, financial goals, summary, stress level,
 * budget management (gauge), trend chart, recent entries, subscriptions.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FinanceScreen(
    viewModel: FinanceViewModel = hiltViewModel(),
) {
    val entries by viewModel.entries.collectAsState()
    val currentBalance by viewModel.currentBalance.collectAsState()
    val monthlyIncome by viewModel.monthlyIncome.collectAsState()
    val monthlyExpenses by viewModel.monthlyExpenses.collectAsState()
    val netFlow by viewModel.netFlow.collectAsState()
    val stressLevel by viewModel.stressLevel.collectAsState()
    val savingsRate by viewModel.monthlySavingsRate.collectAsState()
    val activeSubscriptions by viewModel.activeSubscriptions.collectAsState()
    val monthlySubCost by viewModel.monthlySubscriptionCost.collectAsState()
    val expenseBreakdown by viewModel.expenseBreakdown.collectAsState()

    var showEntryForm by remember { mutableStateOf(false) }
    var editingEntry by remember { mutableStateOf<FinanceEntry?>(null) }
    var showSettings by remember { mutableStateOf(false) }

    val surfaceColor = MaterialTheme.colorScheme.surface
    val onSurface = MaterialTheme.colorScheme.onSurface
    val cardColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // ── Header ──
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.finance_title),
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                    color = onSurface,
                )
                Spacer(modifier = Modifier.weight(1f))
                IconButton(onClick = { showSettings = true }) {
                    Icon(Icons.Default.Settings, "settings", tint = onSurface.copy(alpha = 0.7f))
                }
            }
        }

        // ── Balance Card ──
        item {
            BalanceCard(
                balance = currentBalance,
                income = monthlyIncome,
                expenses = monthlyExpenses,
                netFlow = netFlow,
                formatCurrency = viewModel::formatCurrency,
            )
        }

        // ── Quick Actions ──
        item {
            QuickActionsRow(
                onAddIncome = {
                    editingEntry = null
                    showEntryForm = true
                },
                onAddExpense = {
                    editingEntry = null
                    showEntryForm = true
                },
            )
        }

        // ── Financial Goals ──
        if (viewModel.financialGoals.isNotEmpty()) {
            item {
                GoalsSection(
                    goals = viewModel.financialGoals,
                    formatCurrency = viewModel::formatCurrency,
                )
            }
        }

        // ── Summary ──
        item {
            SummarySection(
                budgetProgress = viewModel.budgetProgress(),
                savingsProgress = viewModel.savingsProgress(),
                incomeProgress = viewModel.incomeProgress(),
                monthlyBudgetTarget = viewModel.monthlyBudgetTarget,
                savingsGoalPercent = viewModel.savingsGoalPercent,
                savingsGoalAmount = viewModel.savingsGoalAmount,
                savingsGoalIsPercent = viewModel.savingsGoalIsPercent,
                monthlyIncomeGoal = viewModel.monthlyIncomeGoal,
                monthlyIncome = monthlyIncome,
                monthlyExpenses = monthlyExpenses,
                savingsRate = savingsRate,
                runwayMonths = viewModel.runwayMonths(),
                formatCurrency = viewModel::formatCurrency,
            )
        }

        // ── Stress Level ──
        item {
            StressSection(stressLevel = stressLevel)
        }

        // ── Budget Management (Gauge) ──
        if (viewModel.budgets.isNotEmpty() || viewModel.monthlyBudgetTarget > 0) {
            item {
                BudgetManagementSection(
                    budgets = viewModel.budgets,
                    monthlyBudgetTarget = viewModel.monthlyBudgetTarget,
                    monthlyExpenses = monthlyExpenses,
                    budgetProgress = viewModel.budgetProgress() ?: 0.0,
                    formatCurrency = viewModel::formatCurrency,
                    displayName = viewModel::budgetDisplayName,
                    colorHex = viewModel::budgetColorHex,
                    budgetUsage = viewModel::budgetUsage,
                )
            }
        }

        // ── Expense Breakdown ──
        if (expenseBreakdown.isNotEmpty()) {
            item {
                ExpenseBreakdownSection(
                    breakdown = expenseBreakdown,
                    displayName = viewModel::displayName,
                    formatCurrency = viewModel::formatCurrency,
                )
            }
        }

        // ── Recent Entries ──
        item {
            RecentEntriesSection(
                entries = entries.sortedByDescending { it.date }.take(8),
                formatCurrency = viewModel::formatCurrency,
                categoryDisplayName = viewModel::categoryDisplayName,
                categoryIcon = viewModel::categoryIcon,
            )
        }

        // ── Subscriptions ──
        if (activeSubscriptions.isNotEmpty()) {
            item {
                SubscriptionsSection(
                    subscriptions = activeSubscriptions,
                    totalMonthlyCost = monthlySubCost,
                    formatCurrency = viewModel::formatCurrency,
                )
            }
        }

        // ── Bottom spacer for tab bar ──
        item { Spacer(modifier = Modifier.height(80.dp)) }
    }

    // ── Entry Form Sheet ──
    if (showEntryForm) {
        ModalBottomSheet(
            onDismissRequest = { showEntryForm = false },
            containerColor = MaterialTheme.colorScheme.surface,
        ) {
            FinanceEntryFormScreen(
                initialEntry = editingEntry,
                viewModel = viewModel,
                onDismiss = { showEntryForm = false },
            )
        }
    }

    // ── Settings Sheet ──
    if (showSettings) {
        ModalBottomSheet(
            onDismissRequest = { showSettings = false },
            containerColor = MaterialTheme.colorScheme.surface,
        ) {
            FinanceSettingsScreen(
                viewModel = viewModel,
                onDismiss = { showSettings = false },
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Balance Card
// ════════════════════════════════════════════════════════════════

@Composable
private fun BalanceCard(
    balance: Double,
    income: Double,
    expenses: Double,
    netFlow: Double,
    formatCurrency: (Double) -> String,
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF1A1A2E),
        ),
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                stringResource(R.string.finance_current_balance),
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.6f),
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                formatCurrency(balance),
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.5).sp,
                ),
                color = Color.White,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Row(modifier = Modifier.fillMaxWidth()) {
                BalanceItem(
                    label = "Income",
                    amount = formatCurrency(income),
                    color = Color(0xFF22C55E),
                    icon = "↓",
                    modifier = Modifier.weight(1f),
                )
                BalanceItem(
                    label = "Expenses",
                    amount = formatCurrency(expenses),
                    color = Color(0xFFEF4444),
                    icon = "↑",
                    modifier = Modifier.weight(1f),
                )
                BalanceItem(
                    label = "Net",
                    amount = (if (netFlow >= 0) "+" else "") + formatCurrency(netFlow),
                    color = if (netFlow >= 0) Color(0xFF22C55E) else Color(0xFFEF4444),
                    icon = if (netFlow >= 0) "📈" else "📉",
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun BalanceItem(
    label: String,
    amount: String,
    color: Color,
    icon: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(icon, fontSize = 18.sp)
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.5f),
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            amount,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
            color = color,
        )
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Quick Actions
// ════════════════════════════════════════════════════════════════

@Composable
private fun QuickActionsRow(
    onAddIncome: () -> Unit,
    onAddExpense: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        QuickActionButton(
            label = "Add Income",
            icon = Icons.Default.ArrowDownward,
            color = Color(0xFF22C55E),
            onClick = onAddIncome,
            modifier = Modifier.weight(1f),
        )
        QuickActionButton(
            label = "Add Expense",
            icon = Icons.Default.ArrowUpward,
            color = Color(0xFFEF4444),
            onClick = onAddExpense,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun QuickActionButton(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.12f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(icon, contentDescription = label, tint = color, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text(label, style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold), color = color)
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Financial Goals
// ════════════════════════════════════════════════════════════════

@Composable
private fun GoalsSection(
    goals: List<FinancialGoal>,
    formatCurrency: (Double) -> String,
) {
    DashboardCard(title = "Financial Goals", icon = Icons.Default.Flag) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            goals.filter { it.isActive }.forEach { goal ->
                GoalRow(goal = goal, formatCurrency = formatCurrency)
            }
        }
    }
}

@Composable
private fun GoalRow(
    goal: FinancialGoal,
    formatCurrency: (Double) -> String,
) {
    val progress by animateFloatAsState(
        targetValue = goal.progress.toFloat(),
        animationSpec = tween(600),
        label = "goalProgress",
    )
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                goal.name,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            Text(
                "${(goal.progress * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                color = Color(0xFF22C55E),
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp)),
            color = Color(0xFF22C55E),
            trackColor = Color(0xFF22C55E).copy(alpha = 0.15f),
        )
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                formatCurrency(goal.currentAmount),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                formatCurrency(goal.targetAmount),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Summary Section
// ════════════════════════════════════════════════════════════════

@Composable
private fun SummarySection(
    budgetProgress: Double?,
    savingsProgress: Double?,
    incomeProgress: Double?,
    monthlyBudgetTarget: Double,
    savingsGoalPercent: Double,
    savingsGoalAmount: Double,
    savingsGoalIsPercent: Boolean,
    monthlyIncomeGoal: Double,
    monthlyIncome: Double,
    monthlyExpenses: Double,
    savingsRate: Double,
    runwayMonths: Double?,
    formatCurrency: (Double) -> String,
) {
    DashboardCard(title = "Summary", icon = Icons.Default.Assessment) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Budget progress
            if (budgetProgress != null) {
                SummaryRow(
                    label = "Budget",
                    value = "${(budgetProgress * 100).toInt()}% used",
                    extra = "${formatCurrency(monthlyExpenses)} / ${formatCurrency(monthlyBudgetTarget)}",
                    color = when {
                        budgetProgress > 1.0 -> Color(0xFFEF4444)
                        budgetProgress > 0.8 -> Color(0xFFF97316)
                        else -> Color(0xFF22C55E)
                    },
                )
            }

            // Savings rate
            SummaryRow(
                label = "Savings Rate",
                value = "${(savingsRate * 100).toInt()}%",
                extra = null,
                color = when {
                    savingsRate < 0.1 -> Color(0xFFEF4444)
                    savingsRate < 0.2 -> Color(0xFFF97316)
                    else -> Color(0xFF22C55E)
                },
            )

            // Income progress
            if (incomeProgress != null) {
                SummaryRow(
                    label = "Income Goal",
                    value = "${(incomeProgress * 100).toInt()}%",
                    extra = "${formatCurrency(monthlyIncome)} / ${formatCurrency(monthlyIncomeGoal)}",
                    color = if (incomeProgress >= 1.0) Color(0xFF22C55E) else Color(0xFFF97316),
                )
            }

            // Runway
            if (runwayMonths != null) {
                SummaryRow(
                    label = "Runway",
                    value = "${runwayMonths.toInt()} months",
                    extra = null,
                    color = when {
                        runwayMonths < 1 -> Color(0xFFEF4444)
                        runwayMonths < 3 -> Color(0xFFF97316)
                        else -> Color(0xFF22C55E)
                    },
                )
            }
        }
    }
}

@Composable
private fun SummaryRow(
    label: String,
    value: String,
    extra: String?,
    color: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Column(horizontalAlignment = Alignment.End) {
            Text(
                value,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = color,
            )
            if (extra != null) {
                Text(
                    extra,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Stress Level
// ════════════════════════════════════════════════════════════════

@Composable
private fun StressSection(stressLevel: FinancialStressLevel) {
    DashboardCard(title = "Financial Health", icon = Icons.Default.Favorite) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val color = parseHexColor(stressLevel.color)
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(color.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                val emoji = when (stressLevel) {
                    FinancialStressLevel.COMFORTABLE -> "😊"
                    FinancialStressLevel.BALANCED -> "🙂"
                    FinancialStressLevel.TIGHT -> "😐"
                    FinancialStressLevel.STRESSED -> "😟"
                    FinancialStressLevel.CRITICAL -> "😰"
                }
                Text(emoji, fontSize = 24.sp)
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    stressLevel.name.lowercase()
                        .replaceFirstChar { it.uppercaseChar() },
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = color,
                )
                Text(
                    when (stressLevel) {
                        FinancialStressLevel.COMFORTABLE -> "Finances are in great shape!"
                        FinancialStressLevel.BALANCED -> "Good balance, keep it up"
                        FinancialStressLevel.TIGHT -> "Getting tight, watch spending"
                        FinancialStressLevel.STRESSED -> "Under pressure, cut costs"
                        FinancialStressLevel.CRITICAL -> "Critical — take action now"
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Budget Management (Gauge)
// ════════════════════════════════════════════════════════════════

@Composable
private fun BudgetManagementSection(
    budgets: List<FinanceBudget>,
    monthlyBudgetTarget: Double,
    monthlyExpenses: Double,
    budgetProgress: Double,
    formatCurrency: (Double) -> String,
    displayName: (FinanceBudget) -> String,
    colorHex: (FinanceBudget) -> String,
    budgetUsage: (FinanceBudget) -> Double,
) {
    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A2E)),
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                "Budget Management",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = Color.White,
            )
            Spacer(modifier = Modifier.height(16.dp))

            // ── Overall Gauge ──
            if (monthlyBudgetTarget > 0) {
                val remaining = (monthlyBudgetTarget - monthlyExpenses).coerceAtLeast(0.0)
                val spentPercent = if (monthlyBudgetTarget > 0) {
                    ((monthlyExpenses / monthlyBudgetTarget) * 100).toInt().coerceAtMost(999)
                } else 0

                BudgetGauge(
                    progress = budgetProgress.toFloat().coerceIn(0f, 1.2f),
                    spentPercent = spentPercent,
                    remaining = remaining,
                    totalLimit = monthlyBudgetTarget,
                    formatCurrency = formatCurrency,
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // ── Category Budget Cards ──
            if (budgets.isNotEmpty()) {
                val cal = java.util.Calendar.getInstance()
                val daysLeft = cal.getActualMaximum(java.util.Calendar.DAY_OF_MONTH) -
                    cal.get(java.util.Calendar.DAY_OF_MONTH)

                LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(budgets.filter { it.isActive }) { budget ->
                        val usage = budgetUsage(budget)
                        val spent = budget.monthlyLimit * usage
                        BudgetCategoryCard(
                            label = displayName(budget),
                            limit = budget.monthlyLimit,
                            spent = spent,
                            daysLeft = daysLeft,
                            categoryColor = parseHexColor(colorHex(budget)),
                            formatCurrency = formatCurrency,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BudgetGauge(
    progress: Float,
    spentPercent: Int,
    remaining: Double,
    totalLimit: Double,
    formatCurrency: (Double) -> String,
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        animationSpec = tween(800),
        label = "gaugeProgress",
    )
    val gaugeColor = when {
        progress > 1.0f -> Color(0xFFEF4444)
        progress > 0.8f -> Color(0xFFF97316)
        else -> Color.White
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(170.dp),
            contentAlignment = Alignment.Center,
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(170.dp),
            ) {
                val w = size.width
                val h = size.height
                val radius = (min(w, h * 2) / 2) - 20f
                val centerX = w / 2
                val centerY = h - 10f
                val strokeWidth = 14f

                // Background arc
                drawArc(
                    color = Color.White.copy(alpha = 0.1f),
                    startAngle = 180f,
                    sweepAngle = 180f,
                    useCenter = false,
                    topLeft = Offset(centerX - radius, centerY - radius),
                    size = Size(radius * 2, radius * 2),
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                )

                // Filled arc
                drawArc(
                    color = gaugeColor,
                    startAngle = 180f,
                    sweepAngle = 180f * animatedProgress,
                    useCenter = false,
                    topLeft = Offset(centerX - radius, centerY - radius),
                    size = Size(radius * 2, radius * 2),
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                )

                // Needle dot
                val angle = Math.toRadians((180.0 + animatedProgress * 180.0))
                val tipX = centerX + radius * cos(angle).toFloat()
                val tipY = centerY + radius * sin(angle).toFloat()
                drawCircle(
                    color = Color.White,
                    radius = 6f,
                    center = Offset(tipX, tipY),
                )
            }

            // Center text
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.offset(y = 20.dp),
            ) {
                Text(
                    "$spentPercent%",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = gaugeColor,
                )
                Text(
                    formatCurrency(remaining),
                    style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                    color = Color.White,
                )
                Text(
                    "left this month",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.5f),
                )
            }
        }

        // Min & Max labels
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp)
                .offset(y = (-8).dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                "0.00",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.4f),
            )
            Text(
                formatCurrency(totalLimit),
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.4f),
            )
        }
    }
}

@Composable
private fun BudgetCategoryCard(
    label: String,
    limit: Double,
    spent: Double,
    daysLeft: Int,
    categoryColor: Color,
    formatCurrency: (Double) -> String,
) {
    val remaining = (limit - spent).coerceAtLeast(0.0)
    val progress = if (limit > 0) (spent / limit).toFloat().coerceIn(0f, 1f) else 0f
    val spentPercent = if (limit > 0) ((spent / limit) * 100).toInt().coerceAtMost(999) else 0
    val spentColor = when {
        limit > 0 && spent / limit > 1.0 -> Color(0xFFEF4444)
        limit > 0 && spent / limit > 0.8 -> Color(0xFFF97316)
        else -> Color(0xFF22C55E)
    }

    Card(
        modifier = Modifier.width(180.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.06f)),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                label,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                "$daysLeft days left",
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f),
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "$spentPercent% SPENT",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 11.sp,
                ),
                color = spentColor,
            )
            Text(
                formatCurrency(remaining),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = Color.White,
            )
            Text(
                "left this month",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                color = Color.White.copy(alpha = 0.5f),
            )
            Spacer(modifier = Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = categoryColor,
                trackColor = Color.White.copy(alpha = 0.1f),
            )
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Expense Breakdown
// ════════════════════════════════════════════════════════════════

@Composable
private fun ExpenseBreakdownSection(
    breakdown: List<Pair<FinanceCategory, Double>>,
    displayName: (FinanceCategory) -> String,
    formatCurrency: (Double) -> String,
) {
    val total = breakdown.sumOf { it.second }

    DashboardCard(title = "Expense Breakdown", icon = Icons.Default.PieChart) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            breakdown.take(6).forEach { (category, amount) ->
                val percent = if (total > 0) ((amount / total) * 100).toInt() else 0
                val color = getCategoryColor(category)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(color),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        displayName(category),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        "$percent%",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        formatCurrency(amount),
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Recent Entries
// ════════════════════════════════════════════════════════════════

@Composable
private fun RecentEntriesSection(
    entries: List<FinanceEntry>,
    formatCurrency: (Double) -> String,
    categoryDisplayName: (FinanceEntry) -> String,
    categoryIcon: (FinanceEntry) -> String,
) {
    DashboardCard(title = "Recent Entries", icon = Icons.Default.Receipt) {
        if (entries.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Default.AccountBalanceWallet,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    modifier = Modifier.size(32.dp),
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "No finance entries",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                entries.forEach { entry ->
                    EntryRow(
                        entry = entry,
                        formatCurrency = formatCurrency,
                        categoryDisplayName = categoryDisplayName,
                    )
                }
            }
        }
    }
}

@Composable
private fun EntryRow(
    entry: FinanceEntry,
    formatCurrency: (Double) -> String,
    categoryDisplayName: (FinanceEntry) -> String,
) {
    val typeColor = parseHexColor(entry.type.color)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Icon circle
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(typeColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            val icon = when (entry.type) {
                FinanceEntryType.INCOME -> Icons.Default.ArrowDownward
                FinanceEntryType.EXPENSE -> Icons.Default.ArrowUpward
                FinanceEntryType.SUBSCRIPTION -> Icons.Default.Repeat
                FinanceEntryType.SAVING -> Icons.Default.AccountBalance
                FinanceEntryType.INVESTMENT -> Icons.Default.TrendingUp
                FinanceEntryType.DEBT -> Icons.Default.CreditCard
            }
            Icon(icon, contentDescription = null, tint = typeColor, modifier = Modifier.size(16.dp))
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                entry.name,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    categoryDisplayName(entry),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
                if (entry.isRecurring) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        Icons.Default.Repeat,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                        modifier = Modifier.size(10.dp),
                    )
                }
            }
        }
        Text(
            (if (entry.type.isOutflow) "-" else "+") + formatCurrency(entry.amount),
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            color = if (entry.type.isOutflow) Color(0xFFEF4444) else Color(0xFF22C55E),
        )
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Subscriptions
// ════════════════════════════════════════════════════════════════

@Composable
private fun SubscriptionsSection(
    subscriptions: List<FinanceEntry>,
    totalMonthlyCost: Double,
    formatCurrency: (Double) -> String,
) {
    DashboardCard(title = "Active Subscriptions", icon = Icons.Default.Repeat) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(modifier = Modifier.weight(1f))
            Text(
                "${formatCurrency(totalMonthlyCost)}/mo",
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                color = Color(0xFFF97316),
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            subscriptions.forEach { sub ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        sub.name,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        formatCurrency(sub.amount),
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    if (sub.recurringFrequency != null) {
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            "/ ${sub.recurringFrequency?.displayName}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        )
                    }
                }
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Shared Dashboard Card
// ════════════════════════════════════════════════════════════════

@Composable
private fun DashboardCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 12.dp),
            ) {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    title,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            content()
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Helpers
// ════════════════════════════════════════════════════════════════

private fun getCategoryColor(category: FinanceCategory): Color {
    return when (category) {
        FinanceCategory.HOUSING -> Color(0xFF3B82F6)
        FinanceCategory.FOOD -> Color(0xFFF97316)
        FinanceCategory.TRANSPORT -> Color(0xFF8B5CF6)
        FinanceCategory.HEALTH -> Color(0xFFEF4444)
        FinanceCategory.ENTERTAINMENT -> Color(0xFFEC4899)
        FinanceCategory.EDUCATION -> Color(0xFF06B6D4)
        FinanceCategory.CLOTHING -> Color(0xFFF59E0B)
        FinanceCategory.UTILITIES -> Color(0xFF6366F1)
        FinanceCategory.INSURANCE -> Color(0xFF14B8A6)
        FinanceCategory.SALARY -> Color(0xFF22C55E)
        FinanceCategory.FREELANCE -> Color(0xFF10B981)
        FinanceCategory.PASSIVE -> Color(0xFF84CC16)
        FinanceCategory.GIFTS -> Color(0xFFA855F7)
        FinanceCategory.OTHER -> Color(0xFF6B7280)
    }
}
