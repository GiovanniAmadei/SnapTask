package com.snaptask.app.ui.finance

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.*
import java.util.Date
import java.util.UUID

/**
 * Faithful port of iOS FinanceEntryFormView.
 * Direction (income/expense) toggle, details, category, recurrence, notes, save.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FinanceEntryFormScreen(
    initialEntry: FinanceEntry? = null,
    viewModel: FinanceViewModel,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(initialEntry?.name ?: "") }
    var amountText by remember { mutableStateOf(initialEntry?.let { String.format("%.2f", it.amount) } ?: "") }
    var isExpense by remember { mutableStateOf(initialEntry?.type?.isOutflow ?: true) }
    var category by remember { mutableStateOf(initialEntry?.category ?: FinanceCategory.OTHER) }
    var selectedCustomCategoryId by remember { mutableStateOf(initialEntry?.customCategoryId) }
    var notes by remember { mutableStateOf(initialEntry?.notes ?: "") }
    var isRecurring by remember { mutableStateOf(initialEntry?.isRecurring ?: false) }
    var recurringFrequency by remember { mutableStateOf(initialEntry?.recurringFrequency ?: SubscriptionFrequency.MONTHLY) }

    val resolvedType by remember {
        derivedStateOf {
            if (isRecurring && isExpense) FinanceEntryType.SUBSCRIPTION
            else if (isExpense) FinanceEntryType.EXPENSE
            else FinanceEntryType.INCOME
        }
    }

    val canSave = name.isNotBlank() &&
        (amountText.replace(",", ".").toDoubleOrNull() ?: 0.0) > 0.0

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
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            }
            Text(
                if (initialEntry != null) "Edit Entry" else "New Entry",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface,
            )
            TextButton(
                onClick = {
                    val amount = amountText.replace(",", ".").toDoubleOrNull() ?: return@TextButton
                    if (initialEntry != null) {
                        viewModel.updateEntry(
                            initialEntry.copy(
                                name = name.trim(),
                                amount = amount,
                                type = resolvedType,
                                category = category,
                                customCategoryId = selectedCustomCategoryId,
                                notes = notes.ifEmpty { null },
                                isRecurring = isRecurring,
                                recurringFrequency = if (isRecurring) recurringFrequency else null,
                                lastModifiedDate = Date(),
                            ),
                        )
                    } else {
                        viewModel.addEntry(
                            FinanceEntry(
                                name = name.trim(),
                                amount = amount,
                                type = resolvedType,
                                category = category,
                                customCategoryId = selectedCustomCategoryId,
                                notes = notes.ifEmpty { null },
                                isRecurring = isRecurring,
                                recurringFrequency = if (isRecurring) recurringFrequency else null,
                            ),
                        )
                    }
                    onDismiss()
                },
                enabled = canSave,
            ) {
                Text(
                    "Save",
                    color = if (canSave) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }

        // ── Direction Toggle ──
        FormCard(title = "Direction", iconVector = Icons.Default.SwapHoriz) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                DirectionButton(
                    label = "Outflow",
                    icon = Icons.Default.ArrowUpward,
                    color = Color(0xFFEF4444),
                    isSelected = isExpense,
                    onClick = {
                        isExpense = true
                        if (category.isIncomeCategory) category = FinanceCategory.OTHER
                    },
                    modifier = Modifier.weight(1f),
                )
                DirectionButton(
                    label = "Inflow",
                    icon = Icons.Default.ArrowDownward,
                    color = Color(0xFF22C55E),
                    isSelected = !isExpense,
                    onClick = {
                        isExpense = false
                        if (!category.isIncomeCategory && category != FinanceCategory.OTHER && category != FinanceCategory.GIFTS) {
                            category = FinanceCategory.SALARY
                        }
                    },
                    modifier = Modifier.weight(1f),
                )
            }
        }

        // ── Details ──
        FormCard(title = "Details", iconVector = Icons.Default.Description) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                // Name
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Entry Name") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                )

                // Amount
                OutlinedTextField(
                    value = amountText,
                    onValueChange = { amountText = it },
                    label = { Text("Amount") },
                    leadingIcon = {
                        Text(
                            viewModel.selectedCurrency.symbol,
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = if (isExpense) Color(0xFFEF4444) else Color(0xFF22C55E),
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    shape = RoundedCornerShape(10.dp),
                )
            }
        }

        // ── Category ──
        FormCard(title = "Category", iconVector = Icons.Default.Folder) {
            val filteredCategories = FinanceCategory.entries.filter {
                if (isExpense) !it.isIncomeCategory
                else it.isIncomeCategory || it == FinanceCategory.OTHER || it == FinanceCategory.GIFTS
            }
            var expanded by remember { mutableStateOf(false) }

            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = !expanded },
            ) {
                OutlinedTextField(
                    value = if (selectedCustomCategoryId != null) {
                        viewModel.customCategories.find { it.id == selectedCustomCategoryId }?.name ?: category.displayName
                    } else category.displayName,
                    onValueChange = {},
                    readOnly = true,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    shape = RoundedCornerShape(10.dp),
                )
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false },
                ) {
                    filteredCategories.forEach { cat ->
                        DropdownMenuItem(
                            text = { Text(viewModel.displayName(cat)) },
                            onClick = {
                                category = cat
                                selectedCustomCategoryId = null
                                expanded = false
                            },
                        )
                    }
                    // Custom categories
                    val customCats = viewModel.customCategories.filter { it.isExpenseCategory == isExpense }
                    if (customCats.isNotEmpty()) {
                        HorizontalDivider()
                        customCats.forEach { custom ->
                            DropdownMenuItem(
                                text = { Text(custom.name) },
                                onClick = {
                                    selectedCustomCategoryId = custom.id
                                    category = FinanceCategory.OTHER
                                    expanded = false
                                },
                            )
                        }
                    }
                }
            }
        }

        // ── Recurrence ──
        FormCard(title = "Recurrence", iconVector = Icons.Default.Repeat) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "Recurring",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    Switch(
                        checked = isRecurring,
                        onCheckedChange = { isRecurring = it },
                    )
                }

                AnimatedVisibility(visible = isRecurring) {
                    Column {
                        Text(
                            "Frequency",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            SubscriptionFrequency.entries.forEach { freq ->
                                FilterChip(
                                    selected = recurringFrequency == freq,
                                    onClick = { recurringFrequency = freq },
                                    label = { Text(freq.displayName, style = MaterialTheme.typography.labelSmall) },
                                    modifier = Modifier.weight(1f),
                                )
                            }
                        }
                    }
                }
            }
        }

        // ── Notes ──
        FormCard(title = "Notes", iconVector = Icons.Default.Notes) {
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes (optional)") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 4,
                shape = RoundedCornerShape(10.dp),
            )
        }

        // ── Save Button ──
        Button(
            onClick = {
                val amount = amountText.replace(",", ".").toDoubleOrNull() ?: return@Button
                if (initialEntry != null) {
                    viewModel.updateEntry(
                        initialEntry.copy(
                            name = name.trim(),
                            amount = amount,
                            type = resolvedType,
                            category = category,
                            customCategoryId = selectedCustomCategoryId,
                            notes = notes.ifEmpty { null },
                            isRecurring = isRecurring,
                            recurringFrequency = if (isRecurring) recurringFrequency else null,
                        ),
                    )
                } else {
                    viewModel.addEntry(
                        FinanceEntry(
                            name = name.trim(),
                            amount = amount,
                            type = resolvedType,
                            category = category,
                            customCategoryId = selectedCustomCategoryId,
                            notes = notes.ifEmpty { null },
                            isRecurring = isRecurring,
                            recurringFrequency = if (isRecurring) recurringFrequency else null,
                        ),
                    )
                }
                onDismiss()
            },
            enabled = canSave,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(16.dp),
        ) {
            Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Save", style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold))
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

// ── Direction Button ──

@Composable
private fun DirectionButton(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .then(
                if (isSelected) Modifier.background(color.copy(alpha = 0.1f))
                    .border(1.5.dp, color.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                else Modifier,
            )
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                icon,
                contentDescription = label,
                tint = if (isSelected) color else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier.size(28.dp),
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Medium),
                color = if (isSelected) color else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }
    }
}

// ── Form Card ──

@Composable
private fun FormCard(
    title: String,
    iconVector: androidx.compose.ui.graphics.vector.ImageVector,
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
                    iconVector,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
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
