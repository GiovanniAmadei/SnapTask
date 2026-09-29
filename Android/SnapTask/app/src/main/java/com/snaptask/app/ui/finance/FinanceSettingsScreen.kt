package com.snaptask.app.ui.finance

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.snaptask.app.R
import com.snaptask.app.data.model.*

/**
 * Faithful port of iOS FinanceSettingsView.
 * Currency, starting balance, monthly budget target, savings goal, income goal,
 * category management, category budgets, reset.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FinanceSettingsScreen(
    viewModel: FinanceViewModel,
    onDismiss: () -> Unit,
) {
    var balanceText by remember { mutableStateOf(if (viewModel.startingBalance > 0) String.format("%.2f", viewModel.startingBalance) else "") }
    var budgetText by remember { mutableStateOf(if (viewModel.monthlyBudgetTarget > 0) String.format("%.2f", viewModel.monthlyBudgetTarget) else "") }
    var savingsText by remember {
        mutableStateOf(
            if (viewModel.savingsGoalIsPercent) {
                if (viewModel.savingsGoalPercent > 0) String.format("%.0f", viewModel.savingsGoalPercent) else ""
            } else {
                if (viewModel.savingsGoalAmount > 0) String.format("%.2f", viewModel.savingsGoalAmount) else ""
            },
        )
    }
    var savingsIsPercent by remember { mutableStateOf(viewModel.savingsGoalIsPercent) }
    var incomeText by remember { mutableStateOf(if (viewModel.monthlyIncomeGoal > 0) String.format("%.2f", viewModel.monthlyIncomeGoal) else "") }
    var showCurrencyPicker by remember { mutableStateOf(false) }

    // Auto-save on changes
    DisposableEffect(Unit) {
        onDispose {
            balanceText.replace(",", ".").toDoubleOrNull()?.let { viewModel.setStartingBalance(it) }
            budgetText.replace(",", ".").toDoubleOrNull()?.let { viewModel.setMonthlyBudgetTarget(it) }
            savingsText.replace(",", ".").toDoubleOrNull()?.let {
                if (savingsIsPercent) viewModel.setSavingsGoalPercent(it)
                else viewModel.setSavingsGoalAmount(it)
            }
            incomeText.replace(",", ".").toDoubleOrNull()?.let { viewModel.setMonthlyIncomeGoal(it) }
            viewModel.setSavingsGoalIsPercent(savingsIsPercent)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        // ── Header ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(modifier = Modifier.width(48.dp))
            Text(
                stringResource(R.string.finance_settings_title),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface,
            )
            IconButton(onClick = onDismiss) {
                Icon(Icons.Default.Close, contentDescription = stringResource(R.string.action_close))
            }
        }

        // ── Currency ──
        SettingsCard(title = stringResource(R.string.finance_currency)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showCurrencyPicker = true }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    viewModel.selectedCurrency.displayName,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        // ── Starting Balance ──
        SettingsCard(title = stringResource(R.string.finance_starting_balance)) {
            OutlinedTextField(
                value = balanceText,
                onValueChange = { balanceText = it },
                leadingIcon = { CurrencyLabel(viewModel.selectedCurrency.symbol) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = { Text("0.00") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                shape = RoundedCornerShape(10.dp),
            )
            Text(
                stringResource(R.string.finance_starting_balance_footer),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // ── Monthly Budget Target ──
        SettingsCard(title = stringResource(R.string.finance_monthly_budget_target)) {
            OutlinedTextField(
                value = budgetText,
                onValueChange = { budgetText = it },
                leadingIcon = { CurrencyLabel(viewModel.selectedCurrency.symbol) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = { Text("0.00") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                shape = RoundedCornerShape(10.dp),
            )
            Text(
                stringResource(R.string.finance_monthly_budget_target_footer),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // ── Savings Goal ──
        SettingsCard(title = stringResource(R.string.finance_savings_goal)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(
                    selected = savingsIsPercent,
                    onClick = { savingsIsPercent = true },
                    label = { Text(stringResource(R.string.finance_savings_goal_percentage)) },
                    modifier = Modifier.weight(1f),
                )
                FilterChip(
                    selected = !savingsIsPercent,
                    onClick = { savingsIsPercent = false },
                    label = { Text(stringResource(R.string.finance_savings_goal_fixed_amount)) },
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = savingsText,
                onValueChange = { savingsText = it },
                leadingIcon = {
                    if (savingsIsPercent) {
                        // No leading icon for percentage
                    } else {
                        CurrencyLabel(viewModel.selectedCurrency.symbol)
                    }
                },
                trailingIcon = {
                    if (savingsIsPercent) {
                        Text(
                            "%",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = { Text(if (savingsIsPercent) "0" else "0.00") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                shape = RoundedCornerShape(10.dp),
            )
            Text(
                if (savingsIsPercent) stringResource(R.string.finance_savings_goal_percent_footer)
                else stringResource(R.string.finance_savings_goal_fixed_amount_footer),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // ── Monthly Income Goal ──
        SettingsCard(title = stringResource(R.string.finance_income_goal)) {
            OutlinedTextField(
                value = incomeText,
                onValueChange = { incomeText = it },
                leadingIcon = { CurrencyLabel(viewModel.selectedCurrency.symbol) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = { Text("0.00") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                shape = RoundedCornerShape(10.dp),
            )
            Text(
                stringResource(R.string.finance_income_goal_footer),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // ── Category Budgets ──
        SettingsCard(title = stringResource(R.string.finance_category_budgets)) {
            if (viewModel.budgets.isNotEmpty()) {
                viewModel.budgets.forEach { budget ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            viewModel.budgetDisplayName(budget),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            viewModel.formatCurrency(budget.monthlyLimit),
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                        val usage = viewModel.budgetUsage(budget)
                        if (usage > 0) {
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                "${(usage * 100).toInt()}%",
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                color = when {
                                    usage > 1.0 -> Color(0xFFEF4444)
                                    usage > 0.8 -> Color(0xFFF97316)
                                    else -> Color(0xFF22C55E)
                                },
                            )
                        }
                    }
                }
            }
            Text(
                stringResource(R.string.finance_category_budgets_footer),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // ── Reset ──
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f),
            ),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { viewModel.resetAll() }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    stringResource(R.string.finance_reset_all_data),
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }

    // ── Currency Picker Dialog ──
    if (showCurrencyPicker) {
        AlertDialog(
            onDismissRequest = { showCurrencyPicker = false },
            title = { Text(stringResource(R.string.finance_select_currency)) },
            text = {
                Column(modifier = Modifier.heightIn(max = 400.dp).verticalScroll(rememberScrollState())) {
                    SupportedCurrency.entries.forEach { currency ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.setSelectedCurrency(currency)
                                    showCurrencyPicker = false
                                }
                                .padding(vertical = 12.dp, horizontal = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                currency.displayName,
                                style = MaterialTheme.typography.bodyMedium,
                                color = if (currency == viewModel.selectedCurrency) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurface
                                },
                                fontWeight = if (currency == viewModel.selectedCurrency) FontWeight.Bold else FontWeight.Normal,
                            )
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showCurrencyPicker = false }) {
                    Text(stringResource(R.string.action_close))
                }
            },
        )
    }
}

// ── Settings Card ──

@Composable
private fun SettingsCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(bottom = 8.dp),
            )
            content()
        }
    }
}

// ── Currency Label ──

@Composable
private fun CurrencyLabel(symbol: String) {
    Text(
        symbol,
        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
    )
}
