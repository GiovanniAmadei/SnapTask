package com.snaptask.app.ui.rewards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snaptask.app.data.model.Reward
import com.snaptask.app.data.model.RewardFrequency

import java.util.Date
import java.util.UUID

/**
 * RewardFormScreen — faithful port of iOS RewardFormView.swift.
 * Create/edit rewards with name, description, icon, category, points cost, and frequency.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RewardFormScreen(
    initialReward: Reward? = null,
    onSave: (Reward) -> Unit,
    onCancel: () -> Unit,
) {
    var rewardName by remember { mutableStateOf(initialReward?.name ?: "") }
    var rewardDescription by remember { mutableStateOf(initialReward?.description ?: "") }
    var pointsCost by remember { mutableIntStateOf(initialReward?.pointsCost ?: 100) }
    var selectedFrequency by remember { mutableStateOf(initialReward?.frequency ?: RewardFrequency.DAILY) }
    var icon by remember { mutableStateOf(initialReward?.icon ?: "gift") }
    var selectedCategoryId by remember { mutableStateOf(initialReward?.categoryId) }
    var isGeneralReward by remember { mutableStateOf(initialReward?.categoryId == null) }
    var useCustomPoints by remember {
        val presetPoints = listOf(1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500)
        mutableStateOf(initialReward != null && initialReward.pointsCost !in presetPoints)
    }
    var customPointsText by remember { mutableStateOf((initialReward?.pointsCost ?: 100).toString()) }

    val canSave = rewardName.isNotBlank() && (isGeneralReward || selectedCategoryId != null)

    val isEditing = initialReward != null
    val title = if (isEditing) "Edit Reward" else "New Reward"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background),
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onCancel) {
                Text("Cancel", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onBackground,
            )
            TextButton(
                onClick = {
                    val reward = Reward(
                        id = initialReward?.id ?: UUID.randomUUID(),
                        name = rewardName.trim(),
                        description = rewardDescription.ifBlank { null },
                        pointsCost = pointsCost,
                        frequency = selectedFrequency,
                        icon = icon,
                        redemptions = initialReward?.redemptions ?: emptyList(),
                        creationDate = initialReward?.creationDate ?: Date(),
                        lastModifiedDate = Date(),
                        categoryId = if (isGeneralReward) null else selectedCategoryId,
                        categoryName = null, // Could be resolved from category repository
                    )
                    onSave(reward)
                },
                enabled = canSave,
            ) {
                Text(
                    "Save",
                    fontWeight = FontWeight.SemiBold,
                    color = if (canSave) MaterialTheme.colorScheme.primary else Color.Gray,
                )
            }
        }

        // Scrollable form content
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // ── Reward Details Card ──
            ModernFormCard(title = "Reward Details", icon = Icons.Default.CardGiftcard) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Reward Name
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "Reward Name",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        OutlinedTextField(
                            value = rewardName,
                            onValueChange = { rewardName = it },
                            placeholder = { Text("Enter reward name") },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            singleLine = true,
                        )
                    }

                    // Description
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "Description",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        OutlinedTextField(
                            value = rewardDescription,
                            onValueChange = { rewardDescription = it },
                            placeholder = { Text("Add description") },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            minLines = 2,
                            maxLines = 4,
                        )
                    }
                }
            }

            // ── Category Card ──
            ModernFormCard(title = "Category", icon = Icons.Default.Folder) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Use Specific Category toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "Use Specific Category",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Text(
                                "Use points from a specific category",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(
                            checked = !isGeneralReward,
                            onCheckedChange = {
                                isGeneralReward = !it
                                if (isGeneralReward) selectedCategoryId = null
                            },
                        )
                    }
                }
            }

            // ── Points Card ──
            ModernFormCard(title = "Points", icon = Icons.Default.Star) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Custom Points toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "Custom Points",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Switch(
                            checked = useCustomPoints,
                            onCheckedChange = { useCustomPoints = it },
                        )
                    }

                    // Cost
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "Cost",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurface,
                        )

                        if (useCustomPoints) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                OutlinedTextField(
                                    value = customPointsText,
                                    onValueChange = { newValue ->
                                        val filtered = newValue.filter { it.isDigit() }
                                        customPointsText = filtered
                                        filtered.toIntOrNull()?.let { pts ->
                                            if (pts in 1..999) pointsCost = pts
                                        }
                                    },
                                    modifier = Modifier.width(80.dp),
                                    shape = RoundedCornerShape(8.dp),
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    singleLine = true,
                                    textStyle = LocalTextStyle.current.copy(textAlign = TextAlign.Center),
                                )
                                Text(
                                    "(1-999)",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        } else {
                            // Preset dropdown
                            val presetPoints = listOf(1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500)
                            var expanded by remember { mutableStateOf(false) }
                            ExposedDropdownMenuBox(
                                expanded = expanded,
                                onExpandedChange = { expanded = it },
                            ) {
                                OutlinedTextField(
                                    value = "$pointsCost pts",
                                    onValueChange = { },
                                    readOnly = true,
                                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                                    modifier = Modifier
                                        .width(120.dp)
                                        .menuAnchor(),
                                    shape = RoundedCornerShape(8.dp),
                                    singleLine = true,
                                    textStyle = LocalTextStyle.current.copy(textAlign = TextAlign.Center),
                                )
                                ExposedDropdownMenu(
                                    expanded = expanded,
                                    onDismissRequest = { expanded = false },
                                ) {
                                    presetPoints.forEach { pts ->
                                        DropdownMenuItem(
                                            text = { Text("$pts") },
                                            onClick = {
                                                pointsCost = pts
                                                customPointsText = "$pts"
                                                expanded = false
                                            },
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Point Guidelines
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            "Point Guidelines:",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text("• 1-10: Quick rewards (snack, short break)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("• 15-50: Regular rewards (movie, meal out)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("• 75-200: Complex rewards (shopping, trip)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("• 250-500: Premium rewards (big purchase)", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            // ── Frequency Card ──
            ModernFormCard(title = "Frequency", icon = Icons.Default.Repeat) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Segmented button row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        RewardFrequency.entries.forEach { frequency ->
                            val isSelected = selectedFrequency == frequency
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(
                                        if (isSelected) MaterialTheme.colorScheme.primary
                                        else MaterialTheme.colorScheme.surfaceVariant,
                                    )
                                    .clickable { selectedFrequency = frequency }
                                    .padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = frequency.shortDisplayName,
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontWeight = FontWeight.Medium,
                                        fontSize = 10.sp,
                                    ),
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                                    else MaterialTheme.colorScheme.onSurface,
                                    maxLines = 1,
                                )
                            }
                        }
                    }

                    // Frequency description
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "Point accumulation period:",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Medium),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = when (selectedFrequency) {
                                RewardFrequency.DAILY -> "Daily rewards reset every day. Only today's points count."
                                RewardFrequency.WEEKLY -> "Weekly rewards accumulate points throughout the week."
                                RewardFrequency.MONTHLY -> "Monthly rewards accumulate points throughout the month."
                                RewardFrequency.YEARLY -> "Yearly rewards accumulate points throughout the year."
                                RewardFrequency.ONE_TIME -> "One-time rewards use all accumulated points ever."
                            },
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            // ── Save Button ──
            Button(
                onClick = {
                    val reward = Reward(
                        id = initialReward?.id ?: UUID.randomUUID(),
                        name = rewardName.trim(),
                        description = rewardDescription.ifBlank { null },
                        pointsCost = pointsCost,
                        frequency = selectedFrequency,
                        icon = icon,
                        redemptions = initialReward?.redemptions ?: emptyList(),
                        creationDate = initialReward?.creationDate ?: Date(),
                        lastModifiedDate = Date(),
                        categoryId = if (isGeneralReward) null else selectedCategoryId,
                        categoryName = null,
                    )
                    onSave(reward)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(16.dp),
                enabled = canSave,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    disabledContainerColor = Color.Gray.copy(alpha = 0.3f),
                ),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                    Text(
                        "Save Reward",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    )
                }
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

// ─── ModernFormCard ─────────────────────────────────────────────────────────

@Composable
private fun ModernFormCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Section header
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            content()
        }
    }
}
