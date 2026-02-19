package com.snaptask.app.ui.onboarding

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
import androidx.compose.ui.unit.dp

/**
 * What's New screen matching iOS WhatsNewView.
 * Shows changelog and new features for the current version.
 */

private data class ChangelogEntry(
    val version: String,
    val title: String,
    val changes: List<String>,
)

@Composable
fun WhatsNewScreen(
    onDismiss: () -> Unit,
) {
    val changelog = remember {
        listOf(
            ChangelogEntry(
                version = "1.0",
                title = "Initial Release",
                changes = listOf(
                    "📋 Task management with flexible scheduling",
                    "⏱️ Pomodoro and stopwatch focus modes",
                    "🏆 Reward system with points and redemptions",
                    "💰 Finance tracking with budgets and goals",
                    "📊 Comprehensive statistics and analytics",
                    "📓 Daily journal with mood tracking",
                    "🎯 Eisenhower Matrix for task prioritization",
                    "🔄 Advanced recurrence settings",
                    "🏷️ Category management with custom colors",
                    "⚙️ Customizable themes and settings",
                ),
            ),
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
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
                "What's New",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        changelog.forEach { entry ->
            Text(
                "VERSION ${entry.version}",
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                entry.title,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )

            Spacer(modifier = Modifier.height(12.dp))

            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                ),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    entry.changes.forEach { change ->
                        Text(
                            change,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}
