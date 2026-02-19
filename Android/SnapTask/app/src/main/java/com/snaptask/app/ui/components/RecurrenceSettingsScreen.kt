package com.snaptask.app.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Recurrence settings screen matching iOS RecurrenceSettingsView.
 * Daily toggle + individual weekday selectors.
 */
@Composable
fun RecurrenceSettingsScreen(
    isDailyRecurrence: Boolean,
    selectedDays: Set<Int>,
    onDailyRecurrenceChanged: (Boolean) -> Unit,
    onSelectedDaysChanged: (Set<Int>) -> Unit,
    onDismiss: () -> Unit,
) {
    val weekdays = listOf(
        1 to "Monday",
        2 to "Tuesday",
        3 to "Wednesday",
        4 to "Thursday",
        5 to "Friday",
        6 to "Saturday",
        7 to "Sunday",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Repeat Settings",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Daily toggle
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Daily",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = isDailyRecurrence,
                    onCheckedChange = onDailyRecurrenceChanged,
                )
            }
        }

        // Weekday selectors (only when not daily)
        if (!isDailyRecurrence) {
            Spacer(modifier = Modifier.height(16.dp))

            Text(
                "SELECT DAYS",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(modifier = Modifier.height(8.dp))

            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                ),
            ) {
                Column {
                    weekdays.forEachIndexed { index, (dayNum, dayName) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                dayName,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f),
                            )
                            Switch(
                                checked = selectedDays.contains(dayNum),
                                onCheckedChange = { isChecked ->
                                    val newSet = selectedDays.toMutableSet()
                                    if (isChecked) newSet.add(dayNum) else newSet.remove(dayNum)
                                    onSelectedDaysChanged(newSet)
                                },
                            )
                        }
                        if (index < weekdays.lastIndex) {
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}
