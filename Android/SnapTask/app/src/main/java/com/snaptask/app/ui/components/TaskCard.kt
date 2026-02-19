package com.snaptask.app.ui.components

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snaptask.app.data.model.Subtask
import com.snaptask.app.data.model.TodoTask
import java.util.UUID

/**
 * Faithful port of iOS TaskCard.swift
 */
@Composable
fun TaskCard(
    task: TodoTask,
    isCompleted: Boolean,
    completedSubtasks: Set<UUID>,
    onToggleComplete: () -> Unit,
    onToggleSubtask: (UUID) -> Unit,
    onTaskTap: () -> Unit,
    onPomodoroTap: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    var isExpanded by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .border(
                width = 1.dp,
                color = Color.Gray.copy(alpha = 0.2f),
                shape = RoundedCornerShape(12.dp),
            )
            .clickable { onTaskTap() }
            .animateContentSize(),
    ) {
        // Header della task
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Checkmark
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clickable(onClick = onToggleComplete),
                contentAlignment = Alignment.Center,
            ) {
                TaskCheckmark(isCompleted = isCompleted)
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Titolo e categoria
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = task.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isCompleted) MaterialTheme.colorScheme.onSurfaceVariant
                    else MaterialTheme.colorScheme.onSurface,
                    textDecoration = if (isCompleted) TextDecoration.LineThrough else TextDecoration.None,
                )

                task.category?.let { category ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(parseHexColor(category.color)),
                        )
                        Text(
                            text = category.name,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            // Info button per aprire i dettagli
            IconButton(
                onClick = { onTaskTap() },
                modifier = Modifier.size(32.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.Gray.copy(alpha = 0.1f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Info",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Pulsante Pomodoro (se disponibile)
            if (task.pomodoroSettings != null && onPomodoroTap != null) {
                Spacer(modifier = Modifier.width(4.dp))
                IconButton(
                    onClick = onPomodoroTap,
                    modifier = Modifier.size(36.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f))
                            .border(
                                width = 1.dp,
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f),
                                shape = CircleShape,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Default.Timer,
                            contentDescription = "Pomodoro",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            // Pulsante espandi (se ci sono subtask)
            if (task.subtasks.isNotEmpty()) {
                val rotation by animateFloatAsState(
                    targetValue = if (isExpanded) 180f else 0f,
                    animationSpec = spring(dampingRatio = 0.7f, stiffness = 400f),
                    label = "expandRotation",
                )
                IconButton(
                    onClick = { isExpanded = !isExpanded },
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.ExpandMore,
                        contentDescription = if (isExpanded) "Collapse" else "Expand",
                        modifier = Modifier.rotate(rotation),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        // Subtasks (se espanso)
        if (isExpanded && task.subtasks.isNotEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 44.dp, end = 12.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                task.subtasks.forEach { subtask ->
                    SubtaskRow(
                        subtask = subtask,
                        isCompleted = subtask.id in completedSubtasks,
                        onToggle = { onToggleSubtask(subtask.id) },
                    )
                }
            }
        }
    }
}

// MARK: - TaskCheckmark
@Composable
fun TaskCheckmark(isCompleted: Boolean) {
    Box(
        modifier = Modifier.size(22.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (isCompleted) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Completed",
                    modifier = Modifier.size(12.dp),
                    tint = Color.White,
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .border(
                        width = 1.5.dp,
                        color = Color.Gray.copy(alpha = 0.5f),
                        shape = CircleShape,
                    ),
            )
        }
    }
}

// MARK: - SubtaskRow
@Composable
fun SubtaskRow(
    subtask: Subtask,
    isCompleted: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(20.dp)
                .clickable(onClick = onToggle),
            contentAlignment = Alignment.Center,
        ) {
            SubtaskCheckmark(isCompleted = isCompleted)
        }

        Spacer(modifier = Modifier.width(8.dp))

        Text(
            text = subtask.name,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.weight(1f))
    }
}

// MARK: - SubtaskCheckmark
@Composable
fun SubtaskCheckmark(isCompleted: Boolean) {
    Box(
        modifier = Modifier.size(18.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (isCompleted) {
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Completed",
                    modifier = Modifier.size(10.dp),
                    tint = Color.White,
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .border(
                        width = 1.5.dp,
                        color = Color.Gray.copy(alpha = 0.5f),
                        shape = CircleShape,
                    ),
            )
        }
    }
}

/**
 * Parse hex color string (e.g. "#FF6366F1" or "FF6366F1") to Compose Color
 */
fun parseHexColor(hex: String): Color {
    val cleanHex = hex.removePrefix("#")
    return try {
        Color(android.graphics.Color.parseColor("#$cleanHex"))
    } catch (e: Exception) {
        Color.Gray
    }
}
