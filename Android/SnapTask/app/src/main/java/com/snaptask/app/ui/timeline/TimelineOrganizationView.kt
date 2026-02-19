package com.snaptask.app.ui.timeline

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
import com.snaptask.app.data.model.*

/**
 * Timeline Organization View - matches iOS TimelineOrganizationView
 * Sheet for configuring view mode, organization, and filters.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineOrganizationView(
    viewModel: TimelineViewModel,
    onDismiss: () -> Unit,
) {
    val viewMode by viewModel.viewMode.collectAsState()
    val organization by viewModel.organization.collectAsState()
    val timeSortOrder by viewModel.timeSortOrder.collectAsState()
    val selectedScope by viewModel.selectedScope.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("View Options", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // View Mode Section
            SectionHeader("View Mode")

            ViewModeSelector(
                selectedMode = viewMode,
                onModeSelected = { viewModel.setViewMode(it) },
                enabled = selectedScope == TaskTimeScope.TODAY,
            )

            HorizontalDivider()

            // Organization Section
            SectionHeader("Organization")

            OrganizationSelector(
                selectedOrganization = organization,
                onOrganizationSelected = { viewModel.setOrganization(it) },
            )

            HorizontalDivider()

            // Time Sort Order Section (only when organized by time)
            if (organization == TimelineOrganization.TIME || organization == TimelineOrganization.NONE) {
                SectionHeader("Sort Order")

                TimeSortOrderSelector(
                    selectedOrder = timeSortOrder,
                    onOrderSelected = { viewModel.setTimeSortOrder(it) },
                )

                HorizontalDivider()
            }

            // Reset Button
            OutlinedButton(
                onClick = {
                    viewModel.resetView()
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Reset to Defaults")
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

/**
 * Section header text
 */
@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

/**
 * View Mode Selector (List vs Timeline)
 */
@Composable
private fun ViewModeSelector(
    selectedMode: TimelineViewMode,
    onModeSelected: (TimelineViewMode) -> Unit,
    enabled: Boolean = true,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (!enabled) {
            Text(
                text = "Timeline view only available for Today scope",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TimelineViewMode.entries.forEach { mode ->
                val isSelected = selectedMode == mode
                val isDisabled = !enabled && mode == TimelineViewMode.TIMELINE

                val icon = when (mode) {
                    TimelineViewMode.LIST -> Icons.Default.ViewList
                    TimelineViewMode.TIMELINE -> Icons.Default.Schedule
                }

                val label = when (mode) {
                    TimelineViewMode.LIST -> "List View"
                    TimelineViewMode.TIMELINE -> "Timeline"
                }

                Card(
                    onClick = { if (!isDisabled) onModeSelected(mode) },
                    modifier = Modifier.weight(1f),
                    colors = CardDefaults.cardColors(
                        containerColor = when {
                            isDisabled -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                            isSelected -> MaterialTheme.colorScheme.primaryContainer
                            else -> MaterialTheme.colorScheme.surfaceVariant
                        },
                    ),
                    border = if (isSelected) {
                        androidx.compose.foundation.BorderStroke(
                            width = 2.dp,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    } else null,
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = when {
                                isDisabled -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                                isSelected -> MaterialTheme.colorScheme.primary
                                else -> MaterialTheme.colorScheme.onSurfaceVariant
                            },
                            modifier = Modifier.size(28.dp),
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        Text(
                            text = label,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = when {
                                isDisabled -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                                isSelected -> MaterialTheme.colorScheme.primary
                                else -> MaterialTheme.colorScheme.onSurfaceVariant
                            },
                        )
                    }
                }
            }
        }
    }
}

/**
 * Organization Selector
 */
@Composable
private fun OrganizationSelector(
    selectedOrganization: TimelineOrganization,
    onOrganizationSelected: (TimelineOrganization) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TimelineOrganization.entries.forEach { org ->
            OrganizationOption(
                organization = org,
                isSelected = selectedOrganization == org,
                onClick = { onOrganizationSelected(org) },
            )
        }
    }
}

/**
 * Single organization option
 */
@Composable
private fun OrganizationOption(
    organization: TimelineOrganization,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val (icon, title, description) = when (organization) {
        TimelineOrganization.NONE -> Triple(
            Icons.Default.Sort,
            "Default",
            "Sorted by time, no grouping"
        )
        TimelineOrganization.TIME -> Triple(
            Icons.Default.Schedule,
            "By Time",
            "Grouped by morning, afternoon, evening"
        )
        TimelineOrganization.CATEGORY -> Triple(
            Icons.Default.Label,
            "By Category",
            "Grouped by task categories"
        )
        TimelineOrganization.PRIORITY -> Triple(
            Icons.Default.Flag,
            "By Priority",
            "Sorted by priority level"
        )
        TimelineOrganization.EISENHOWER -> Triple(
            Icons.Default.GridView,
            "Eisenhower Matrix",
            "Quadrant-based organization"
        )
    }

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surfaceVariant
            },
        ),
        border = if (isSelected) {
            androidx.compose.foundation.BorderStroke(
                width = 2.dp,
                color = MaterialTheme.colorScheme.primary,
            )
        } else null,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (isSelected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                modifier = Modifier.size(24.dp),
            )

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    },
                )
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (isSelected) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = "Selected",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

/**
 * Time Sort Order Selector
 */
@Composable
private fun TimeSortOrderSelector(
    selectedOrder: TimeSortOrder,
    onOrderSelected: (TimeSortOrder) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TimeSortOrder.entries.forEach { order ->
            val isSelected = selectedOrder == order

            val (icon, label) = when (order) {
                TimeSortOrder.ASCENDING -> Pair(Icons.Default.ArrowUpward, "Early to Late")
                TimeSortOrder.DESCENDING -> Pair(Icons.Default.ArrowDownward, "Late to Early")
            }

            Card(
                onClick = { onOrderSelected(order) },
                modifier = Modifier.weight(1f),
                colors = CardDefaults.cardColors(
                    containerColor = if (isSelected) {
                        MaterialTheme.colorScheme.secondaryContainer
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    },
                ),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = if (isSelected) {
                            MaterialTheme.colorScheme.secondary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.size(20.dp),
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    Text(
                        text = label,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                        color = if (isSelected) {
                            MaterialTheme.colorScheme.secondary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }
            }
        }
    }
}
