package com.snaptask.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Assignment
import androidx.compose.material.icons.automirrored.filled.MenuBook
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
import androidx.compose.ui.res.stringResource
import com.snaptask.app.R

/**
 * Task creation options matching iOS TaskCreationOptionsView.
 * Quick task creation with preset templates.
 */

data class TaskTemplate(
    val title: String,
    val description: String,
    val icon: ImageVector,
    val color: Color,
    val defaultName: String,
)

@Composable
fun TaskCreationOptionsScreen(
    onCreateTask: (String, String) -> Unit,
    onCreateBlank: () -> Unit,
    onDismiss: () -> Unit,
) {
    val templates = remember {
        listOf(
            TaskTemplate("Quick Task", "Simple one-time task", Icons.Filled.FlashOn, Color(0xFF4CAF50), "New Task"),
            TaskTemplate("Daily Habit", "Repeating daily task", Icons.Filled.Repeat, Color(0xFF2196F3), "Daily Habit"),
            TaskTemplate("Meeting", "Scheduled meeting", Icons.Filled.Groups, Color(0xFF9C27B0), "Meeting"),
            TaskTemplate("Workout", "Exercise session", Icons.Filled.FitnessCenter, Color(0xFFFF5722), "Workout"),
            TaskTemplate("Study", "Learning session", Icons.AutoMirrored.Filled.MenuBook, Color(0xFFFF9800), "Study Session"),
            TaskTemplate("Project", "Multi-step project task", Icons.AutoMirrored.Filled.Assignment, Color(0xFF00BCD4), "Project Task"),
            TaskTemplate("Reminder", "Quick reminder", Icons.Filled.NotificationImportant, Color(0xFFF44336), "Reminder"),
            TaskTemplate("Shopping", "Shopping list", Icons.Filled.ShoppingCart, Color(0xFF8BC34A), "Shopping"),
        )
    }

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
                stringResource(R.string.task_creation_title),
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Blank task button
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
            ),
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onCreateBlank),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp),
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        stringResource(R.string.task_creation_blank_task),
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    Text(
                        stringResource(R.string.task_creation_blank_task_subtitle),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            stringResource(R.string.task_creation_templates),
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        // Template grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.height(320.dp),
        ) {
            items(templates) { template ->
                TemplateCard(
                    template = template,
                    onClick = {
                        onCreateTask(template.defaultName, template.title)
                        onDismiss()
                    },
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}

@Composable
private fun TemplateCard(
    template: TaskTemplate,
    onClick: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(template.color.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    template.icon,
                    contentDescription = null,
                    tint = template.color,
                    modifier = Modifier.size(22.dp),
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                template.title,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
            )
            Text(
                template.description,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
