package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.ui.statistics.parseColor
import java.text.SimpleDateFormat
import java.util.*

/**
 * Due Tasks screen matching iOS DueTasksView.
 * Shows overdue and due-today tasks.
 */
@Composable
fun DueTasksScreen(
    overdueTasks: List<TodoTask>,
    dueTodayTasks: List<TodoTask>,
    onToggleCompletion: (UUID) -> Unit,
    onTaskClick: (UUID) -> Unit,
    onDismiss: () -> Unit,
) {
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }

    Column(modifier = Modifier.fillMaxSize()) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Due Tasks",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Overdue section
            if (overdueTasks.isNotEmpty()) {
                item {
                    Text(
                        "OVERDUE",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = Color(0xFFEF4444),
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
                items(overdueTasks, key = { it.id }) { task ->
                    DueTaskCard(
                        task = task,
                        isOverdue = true,
                        timeFormat = timeFormat,
                        onToggle = { onToggleCompletion(task.id) },
                        onClick = { onTaskClick(task.id) },
                    )
                }
            }

            // Due today section
            if (dueTodayTasks.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "DUE TODAY",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = Color(0xFFF59E0B),
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
                items(dueTodayTasks, key = { it.id }) { task ->
                    DueTaskCard(
                        task = task,
                        isOverdue = false,
                        timeFormat = timeFormat,
                        onToggle = { onToggleCompletion(task.id) },
                        onClick = { onTaskClick(task.id) },
                    )
                }
            }

            // Empty state
            if (overdueTasks.isEmpty() && dueTodayTasks.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 64.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                Icons.Filled.CheckCircle,
                                contentDescription = null,
                                tint = Color(0xFF22C55E).copy(alpha = 0.5f),
                                modifier = Modifier.size(64.dp),
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "All caught up!",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                "No overdue or due tasks",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                            )
                        }
                    }
                }
            }

            item { Spacer(modifier = Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun DueTaskCard(
    task: TodoTask,
    isOverdue: Boolean,
    timeFormat: SimpleDateFormat,
    onToggle: () -> Unit,
    onClick: () -> Unit,
) {
    val accentColor = if (isOverdue) Color(0xFFEF4444) else Color(0xFFF59E0B)
    val isCompleted = task.completionDates.any { date ->
        TodoTask.isSameDay(date, Date())
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Completion toggle
            IconButton(
                onClick = onToggle,
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    imageVector = if (isCompleted) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                    contentDescription = null,
                    tint = if (isCompleted) Color(0xFF22C55E) else accentColor,
                    modifier = Modifier.size(22.dp),
                )
            }

            Spacer(modifier = Modifier.width(10.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    task.name,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        timeFormat.format(task.startTime),
                        style = MaterialTheme.typography.labelSmall,
                        color = accentColor,
                    )
                    task.category?.let { cat ->
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(parseColor(cat.color)),
                        )
                        Text(
                            cat.name,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            if (isOverdue) {
                Icon(
                    Icons.Filled.Warning,
                    contentDescription = "Overdue",
                    tint = accentColor,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}
