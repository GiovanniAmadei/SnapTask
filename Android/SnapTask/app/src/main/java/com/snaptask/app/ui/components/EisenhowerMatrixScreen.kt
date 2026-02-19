package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.unit.sp
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.ui.statistics.parseColor
import java.text.SimpleDateFormat
import java.util.*

/**
 * Eisenhower Priority Matrix matching iOS EisenhowerMatrixView.
 * 4-quadrant grid: Do Now, Schedule, Delegate, Eliminate.
 */
@Composable
fun EisenhowerMatrixScreen(
    doNowTasks: List<TodoTask>,
    scheduleTasks: List<TodoTask>,
    delegateTasks: List<TodoTask>,
    eliminateTasks: List<TodoTask>,
    onToggleCompletion: (UUID) -> Unit,
    onTaskClick: (UUID) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Top row: Q1 (Do Now) | Q2 (Schedule)
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MatrixQuadrant(
                title = "Do Now",
                subtitle = "Important & Urgent",
                tasks = doNowTasks,
                quadrantColor = Color(0xFFEF4444),
                icon = Icons.Filled.Bolt,
                onToggleCompletion = onToggleCompletion,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
            MatrixQuadrant(
                title = "Schedule",
                subtitle = "Important & Not Urgent",
                tasks = scheduleTasks,
                quadrantColor = Color(0xFF3B82F6),
                icon = Icons.Filled.Schedule,
                onToggleCompletion = onToggleCompletion,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
        }

        // Bottom row: Q3 (Delegate) | Q4 (Eliminate)
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MatrixQuadrant(
                title = "Delegate",
                subtitle = "Not Important & Urgent",
                tasks = delegateTasks,
                quadrantColor = Color(0xFFF59E0B),
                icon = Icons.Filled.People,
                onToggleCompletion = onToggleCompletion,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
            MatrixQuadrant(
                title = "Eliminate",
                subtitle = "Not Important & Not Urgent",
                tasks = eliminateTasks,
                quadrantColor = Color(0xFF6B7280),
                icon = Icons.Filled.Delete,
                onToggleCompletion = onToggleCompletion,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun MatrixQuadrant(
    title: String,
    subtitle: String,
    tasks: List<TodoTask>,
    quadrantColor: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onToggleCompletion: (UUID) -> Unit,
    onTaskClick: (UUID) -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        border = CardDefaults.outlinedCardBorder().copy(
            brush = androidx.compose.ui.graphics.SolidColor(quadrantColor.copy(alpha = 0.18f)),
        ),
        modifier = modifier.fillMaxHeight(),
    ) {
        Column {
            // Header
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        quadrantColor.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp),
                    )
                    .padding(horizontal = 10.dp, vertical = 10.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = quadrantColor,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        title,
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = quadrantColor,
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        "${tasks.size}",
                        style = MaterialTheme.typography.labelSmall,
                        color = quadrantColor,
                    )
                }
                Text(
                    subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }

            // Task list
            if (tasks.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        "No tasks",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(horizontal = 6.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(tasks, key = { it.id }) { task ->
                        TaskRowCard(
                            task = task,
                            quadrantColor = quadrantColor,
                            onToggle = { onToggleCompletion(task.id) },
                            onClick = { onTaskClick(task.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TaskRowCard(
    task: TodoTask,
    quadrantColor: Color,
    onToggle: () -> Unit,
    onClick: () -> Unit,
) {
    val isCompleted = task.completionDates.any { date ->
        TodoTask.isSameDay(date, Date())
    }
    val hourFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.background)
            .border(1.dp, quadrantColor.copy(alpha = 0.15f), RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // Task info
        Column(modifier = Modifier.weight(1f)) {
            Text(
                task.name,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                task.startTime.let { time ->
                    Text(
                        hourFormat.format(time),
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                task.category?.let { cat ->
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(parseColor(cat.color))
                            .align(Alignment.CenterVertically),
                    )
                }
            }
        }

        // Completion toggle
        IconButton(
            onClick = onToggle,
            modifier = Modifier.size(28.dp),
        ) {
            Icon(
                imageVector = if (isCompleted) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                contentDescription = if (isCompleted) "Completed" else "Incomplete",
                tint = if (isCompleted) Color(0xFF22C55E) else quadrantColor,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}
