package com.snaptask.app.ui.timeline

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.*

/**
 * Eisenhower Matrix View - matches iOS EisenhowerMatrixView
 * Quadrant-based task organization:
 * - Do First (Urgent + Important) - HIGH priority
 * - Schedule (Not Urgent + Important) - MEDIUM priority  
 * - Delegate (Urgent + Not Important) - LOW priority
 * - Eliminate (Neither) - None/Completed
 */
@Composable
fun EisenhowerMatrixView(
    viewModel: TimelineViewModel,
    onTaskClick: (TodoTask) -> Unit,
) {
    val tasks by viewModel.tasksForSelectedDate.collectAsState()
    val selectedDate by viewModel.selectedDate.collectAsState()

    // Filter tasks into quadrants based on priority
    val doFirstTasks = tasks.filter { it.priority == Priority.HIGH && !viewModel.isTaskCompleted(it, selectedDate) }
    val scheduleTasks = tasks.filter { it.priority == Priority.MEDIUM && !viewModel.isTaskCompleted(it, selectedDate) }
    val delegateTasks = tasks.filter { it.priority == Priority.LOW && !viewModel.isTaskCompleted(it, selectedDate) }
    val eliminateTasks = tasks.filter { viewModel.isTaskCompleted(it, selectedDate) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(8.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Header
        Text(
            text = "Eisenhower Matrix",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
        )

        // Top row: Do First | Delegate
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MatrixQuadrant(
                title = "Do First",
                subtitle = "Urgent & Important",
                icon = Icons.Default.PriorityHigh,
                color = Color(0xFFE53935),
                tasks = doFirstTasks,
                viewModel = viewModel,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )

            MatrixQuadrant(
                title = "Delegate",
                subtitle = "Urgent, Not Important",
                icon = Icons.Default.Person,
                color = Color(0xFF1E88E5),
                tasks = delegateTasks,
                viewModel = viewModel,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
        }

        // Bottom row: Schedule | Eliminate
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MatrixQuadrant(
                title = "Schedule",
                subtitle = "Not Urgent, Important",
                icon = Icons.Default.Event,
                color = Color(0xFF43A047),
                tasks = scheduleTasks,
                viewModel = viewModel,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )

            MatrixQuadrant(
                title = "Done",
                subtitle = "Completed Tasks",
                icon = Icons.Default.CheckCircle,
                color = Color(0xFF757575),
                tasks = eliminateTasks,
                viewModel = viewModel,
                onTaskClick = onTaskClick,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(modifier = Modifier.height(100.dp))
    }
}

/**
 * Single quadrant in the Eisenhower Matrix
 */
@Composable
private fun MatrixQuadrant(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    tasks: List<TodoTask>,
    viewModel: TimelineViewModel,
    onTaskClick: (TodoTask) -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier
            .heightIn(min = 200.dp, max = 400.dp),
        colors = CardDefaults.cardColors(
            containerColor = color.copy(alpha = 0.08f),
        ),
        border = androidx.compose.foundation.BorderStroke(
            width = 1.dp,
            color = color.copy(alpha = 0.3f),
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = color,
                    modifier = Modifier.size(20.dp),
                )
                Column {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = color,
                    )
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = color.copy(alpha = 0.15f),
                ) {
                    Text(
                        text = "${tasks.size}",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = color,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            HorizontalDivider(color = color.copy(alpha = 0.2f))

            Spacer(modifier = Modifier.height(8.dp))

            // Tasks list
            if (tasks.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "No tasks",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                tasks.forEach { task ->
                    MatrixTaskItem(
                        task = task,
                        viewModel = viewModel,
                        onClick = { onTaskClick(task) },
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
        }
    }
}

/**
 * Single task item in the matrix
 */
@Composable
private fun MatrixTaskItem(
    task: TodoTask,
    viewModel: TimelineViewModel,
    onClick: () -> Unit,
) {
    val selectedDate by viewModel.selectedDate.collectAsState()
    val isCompleted = viewModel.isTaskCompleted(task, selectedDate)

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Category dot
            task.category?.let { category ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(
                            color = Color(android.graphics.Color.parseColor(category.color)),
                            shape = androidx.compose.foundation.shape.CircleShape,
                        ),
                )
                Spacer(modifier = Modifier.width(8.dp))
            } ?: run {
                Spacer(modifier = Modifier.width(16.dp))
            }

            // Task name
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = task.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    textDecoration = if (isCompleted) TextDecoration.LineThrough else null,
                    color = if (isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                )

                // Time info
                if (task.hasSpecificTime) {
                    val timeStr = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
                        .format(task.startTime)
                    Text(
                        text = timeStr,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Completion checkbox
            IconButton(
                onClick = { viewModel.toggleTaskCompletion(task.id) },
                modifier = Modifier.size(28.dp),
            ) {
                Icon(
                    imageVector = if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                    contentDescription = null,
                    tint = if (isCompleted) Color(0xFF4CAF50) else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
