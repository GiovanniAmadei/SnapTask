package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.TaskTimeScope
import com.snaptask.app.data.model.TimelineOrganization

/**
 * Timeline organization/filter screen merging iOS
 * TimelineFilterView + TimelineOrganizationView.
 * Allows choosing organization mode and time sort order.
 */
@Composable
fun TimelineOrganizationScreen(
    currentOrganization: TimelineOrganization,
    currentTimeSortAscending: Boolean,
    selectedScope: TaskTimeScope,
    onSelectOrganization: (TimelineOrganization) -> Unit,
    onToggleTimeSortOrder: () -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit,
) {
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
            TextButton(onClick = onDismiss) { Text("Cancel") }
            Text(
                "Organize Tasks",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Organization Mode Section
        Text(
            "ORGANIZATION MODE",
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
                // Filter organizations based on scope (time is only for TODAY)
                val availableOrganizations = if (selectedScope == TaskTimeScope.TODAY) {
                    TimelineOrganization.entries.toList()
                } else {
                    TimelineOrganization.entries.filter { it != TimelineOrganization.TIME }
                }

                availableOrganizations.forEachIndexed { index, org ->
                    OrganizationOptionRow(
                        organization = org,
                        isSelected = currentOrganization == org,
                        onClick = { onSelectOrganization(org) },
                    )
                    if (index < availableOrganizations.lastIndex) {
                        Spacer(modifier = Modifier.height(4.dp))
                    }
                }
            }
        }

        // Time Sort Order (only when time organization is active on today scope)
        if (selectedScope == TaskTimeScope.TODAY && currentOrganization == TimelineOrganization.TIME) {
            Spacer(modifier = Modifier.height(20.dp))

            Text(
                "TIME SORT ORDER",
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
                    // Ascending
                    SortOrderRow(
                        title = "Ascending",
                        subtitle = "Earliest first",
                        icon = Icons.Filled.ArrowUpward,
                        isSelected = currentTimeSortAscending,
                        onClick = { if (!currentTimeSortAscending) onToggleTimeSortOrder() },
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    // Descending
                    SortOrderRow(
                        title = "Descending",
                        subtitle = "Latest first",
                        icon = Icons.Filled.ArrowDownward,
                        isSelected = !currentTimeSortAscending,
                        onClick = { if (currentTimeSortAscending) onToggleTimeSortOrder() },
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Reset button
        OutlinedButton(
            onClick = {
                onReset()
                onDismiss()
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MaterialTheme.colorScheme.primary,
            ),
        ) {
            Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Reset to Default", fontWeight = FontWeight.SemiBold)
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}

@Composable
private fun OrganizationOptionRow(
    organization: TimelineOrganization,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val icon: ImageVector = when (organization) {
        TimelineOrganization.NONE -> Icons.AutoMirrored.Filled.ViewList
        TimelineOrganization.TIME -> Icons.Filled.Schedule
        TimelineOrganization.CATEGORY -> Icons.Filled.Sell
        TimelineOrganization.PRIORITY -> Icons.Filled.Flag
        TimelineOrganization.EISENHOWER -> Icons.Filled.GridView
    }

    val description = when (organization) {
        TimelineOrganization.NONE -> "Default view"
        TimelineOrganization.TIME -> "Sort by time"
        TimelineOrganization.CATEGORY -> "Group by category"
        TimelineOrganization.PRIORITY -> "Group by priority"
        TimelineOrganization.EISENHOWER -> "Eisenhower matrix"
    }

    val borderColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
    val bgColor = if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f) else Color.Transparent

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .border(
                width = if (isSelected) 1.5.dp else 0.dp,
                color = borderColor,
                shape = RoundedCornerShape(12.dp),
            )
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                organization.displayName,
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                description,
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
}

@Composable
private fun SortOrderRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
    val bgColor = if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f) else Color.Transparent

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .border(
                width = if (isSelected) 1.5.dp else 0.dp,
                color = borderColor,
                shape = RoundedCornerShape(12.dp),
            )
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(18.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (isSelected) {
            Icon(
                Icons.Filled.Check,
                contentDescription = "Selected",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
