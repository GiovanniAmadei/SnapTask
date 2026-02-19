package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.RecurrenceType
import com.snaptask.app.data.model.TaskTimeScope
import java.util.*

/**
 * Enhanced Recurrence Settings merging iOS ContextualRecurrenceSettingsView +
 * EnhancedRecurrenceSettingsView. Scope-aware recurrence with intervals.
 */

enum class ContextualRecurrenceOption(val displayName: String, val description: String) {
    DAILY("Daily", "Repeats every day"),
    WEEKDAYS("Weekdays", "Monday to Friday"),
    CUSTOM_DAYS("Custom Days", "Choose specific days"),
    WEEKLY("Weekly", "Repeats every week"),
    BIWEEKLY("Bi-weekly", "Every two weeks"),
    MONTHLY("Monthly", "Repeats every month"),
    YEARLY("Yearly", "Repeats every year"),
    NONE("None", "No recurrence");
}

@Composable
fun EnhancedRecurrenceScreen(
    selectedScope: TaskTimeScope,
    isDailyRecurrence: Boolean,
    selectedDays: Set<Int>,
    recurrenceType: RecurrenceType?,
    dayInterval: Int,
    weekInterval: Int,
    onRecurrenceTypeChanged: (ContextualRecurrenceOption) -> Unit,
    onDaysChanged: (Set<Int>) -> Unit,
    onDayIntervalChanged: (Int) -> Unit,
    onWeekIntervalChanged: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val weekdays = listOf(
        Calendar.MONDAY to "Mon",
        Calendar.TUESDAY to "Tue",
        Calendar.WEDNESDAY to "Wed",
        Calendar.THURSDAY to "Thu",
        Calendar.FRIDAY to "Fri",
        Calendar.SATURDAY to "Sat",
        Calendar.SUNDAY to "Sun",
    )

    val availableOptions = remember(selectedScope) {
        when (selectedScope) {
            TaskTimeScope.TODAY -> listOf(
                ContextualRecurrenceOption.DAILY,
                ContextualRecurrenceOption.WEEKDAYS,
                ContextualRecurrenceOption.CUSTOM_DAYS,
                ContextualRecurrenceOption.NONE,
            )
            TaskTimeScope.WEEK -> listOf(
                ContextualRecurrenceOption.WEEKLY,
                ContextualRecurrenceOption.BIWEEKLY,
                ContextualRecurrenceOption.CUSTOM_DAYS,
                ContextualRecurrenceOption.NONE,
            )
            TaskTimeScope.MONTH -> listOf(
                ContextualRecurrenceOption.MONTHLY,
                ContextualRecurrenceOption.CUSTOM_DAYS,
                ContextualRecurrenceOption.NONE,
            )
            TaskTimeScope.YEAR -> listOf(
                ContextualRecurrenceOption.YEARLY,
                ContextualRecurrenceOption.NONE,
            )
            else -> listOf(ContextualRecurrenceOption.NONE)
        }
    }

    var selectedOption by remember {
        mutableStateOf(
            when {
                isDailyRecurrence -> ContextualRecurrenceOption.DAILY
                selectedDays.isNotEmpty() -> ContextualRecurrenceOption.CUSTOM_DAYS
                recurrenceType is RecurrenceType.WEEKLY -> ContextualRecurrenceOption.WEEKLY
                recurrenceType is RecurrenceType.MONTHLY -> ContextualRecurrenceOption.MONTHLY
                recurrenceType is RecurrenceType.YEARLY -> ContextualRecurrenceOption.YEARLY
                else -> ContextualRecurrenceOption.NONE
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Recurrence Settings",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Scope indicator
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f),
            ),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.DateRange,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    "Scope: ${selectedScope.displayName}",
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Recurrence summary card
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.Repeat,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    "Repeats: ${selectedOption.displayName}",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Options
        Text(
            "RECURRENCE OPTIONS",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        ) {
            Column(modifier = Modifier.padding(8.dp)) {
                availableOptions.forEachIndexed { index, option ->
                    val isSelected = selectedOption == option
                    val bgColor = if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f) else Color.Transparent
                    val borderColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(bgColor)
                            .border(
                                if (isSelected) 1.5.dp else 0.dp,
                                borderColor,
                                RoundedCornerShape(12.dp),
                            )
                            .clickable {
                                selectedOption = option
                                onRecurrenceTypeChanged(option)
                            }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                option.displayName,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Text(
                                option.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (isSelected) {
                            Icon(
                                Icons.Filled.CheckCircle,
                                contentDescription = "Selected",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                    if (index < availableOptions.lastIndex) {
                        Spacer(modifier = Modifier.height(4.dp))
                    }
                }
            }
        }

        // Weekday picker (for CUSTOM_DAYS)
        if (selectedOption == ContextualRecurrenceOption.CUSTOM_DAYS) {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                "SELECT DAYS",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                weekdays.forEach { (dayNum, dayName) ->
                    val isSelected = selectedDays.contains(dayNum)
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(CircleShape)
                            .background(
                                if (isSelected) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.surfaceVariant,
                            )
                            .clickable {
                                val newSet = selectedDays.toMutableSet()
                                if (isSelected) newSet.remove(dayNum) else newSet.add(dayNum)
                                onDaysChanged(newSet)
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            dayName,
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }

        // Interval setting (for daily/weekly)
        if (selectedOption == ContextualRecurrenceOption.DAILY && selectedScope == TaskTimeScope.TODAY) {
            Spacer(modifier = Modifier.height(16.dp))
            IntervalSetting(
                label = "Every N days",
                value = dayInterval,
                onValueChange = onDayIntervalChanged,
            )
        }

        if (selectedOption == ContextualRecurrenceOption.WEEKLY) {
            Spacer(modifier = Modifier.height(16.dp))
            IntervalSetting(
                label = "Every N weeks",
                value = weekInterval,
                onValueChange = onWeekIntervalChanged,
            )
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun IntervalSetting(
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit,
) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                label,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )
            IconButton(
                onClick = { if (value > 1) onValueChange(value - 1) },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(Icons.Filled.Remove, contentDescription = "Decrease")
            }
            Text(
                "$value",
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            IconButton(
                onClick = { onValueChange(value + 1) },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Increase")
            }
        }
    }
}
