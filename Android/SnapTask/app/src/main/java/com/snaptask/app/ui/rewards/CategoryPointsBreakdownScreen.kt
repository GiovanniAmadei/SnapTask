package com.snaptask.app.ui.rewards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import com.snaptask.app.data.model.Category
import com.snaptask.app.data.model.Reward
import com.snaptask.app.ui.statistics.parseColor

/**
 * Category Points Breakdown matching iOS CategoryPointsBreakdownView.
 * Shows per-category points analytics.
 */
@Composable
fun CategoryPointsBreakdownScreen(
    rewards: List<Reward>,
    categories: List<Category>,
    onDismiss: () -> Unit,
) {
    // Group rewards by category
    val categoryData = remember(rewards, categories) {
        val generalRewards = rewards.filter { it.isGeneralReward }
        val generalPoints = generalRewards.sumOf { it.redemptions.size * it.pointsCost }

        val categoryBreakdown = categories.mapNotNull { category ->
            val categoryRewards = rewards.filter { it.categoryId == category.id }
            if (categoryRewards.isEmpty()) return@mapNotNull null
            val totalPoints = categoryRewards.sumOf { it.redemptions.size * it.pointsCost }
            val totalRedemptions = categoryRewards.sumOf { it.redemptions.size }
            CategoryPointsData(
                categoryName = category.name,
                categoryColor = category.color,
                totalPoints = totalPoints,
                totalRedemptions = totalRedemptions,
                rewardCount = categoryRewards.size,
            )
        }

        val generalData = if (generalRewards.isNotEmpty()) {
            CategoryPointsData(
                categoryName = "General",
                categoryColor = "#607D8B",
                totalPoints = generalPoints,
                totalRedemptions = generalRewards.sumOf { it.redemptions.size },
                rewardCount = generalRewards.size,
            )
        } else null

        val all = buildList {
            if (generalData != null) add(generalData)
            addAll(categoryBreakdown)
        }.sortedByDescending { it.totalPoints }

        all
    }

    val totalPoints = categoryData.sumOf { it.totalPoints }

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
                "Points by Category",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        // Total card
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f),
            ),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Filled.PieChart,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp),
                )
                Spacer(modifier = Modifier.width(14.dp))
                Column {
                    Text(
                        "Total Points Spent",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        "$totalPoints pts",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Category list
        if (categoryData.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "No category data yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(categoryData, key = { it.categoryName }) { data ->
                    CategoryPointsCard(data = data, maxPoints = totalPoints)
                }
                item { Spacer(modifier = Modifier.height(16.dp)) }
            }
        }
    }
}

private data class CategoryPointsData(
    val categoryName: String,
    val categoryColor: String,
    val totalPoints: Int,
    val totalRedemptions: Int,
    val rewardCount: Int,
)

@Composable
private fun CategoryPointsCard(data: CategoryPointsData, maxPoints: Int) {
    val color = parseColor(data.categoryColor)
    val progress = if (maxPoints > 0) data.totalPoints.toFloat() / maxPoints else 0f

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(14.dp)
                        .clip(CircleShape)
                        .background(color),
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    data.categoryName,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "${data.totalPoints} pts",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = color,
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Progress bar
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = color,
                trackColor = color.copy(alpha = 0.1f),
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row {
                Text(
                    "${data.rewardCount} rewards",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    "${data.totalRedemptions} redemptions",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
