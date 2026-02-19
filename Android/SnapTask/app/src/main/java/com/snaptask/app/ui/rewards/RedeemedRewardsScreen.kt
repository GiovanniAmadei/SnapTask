package com.snaptask.app.ui.rewards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
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
import androidx.compose.ui.unit.sp
import com.snaptask.app.data.model.Reward
import java.text.SimpleDateFormat
import java.util.*

/**
 * Redeemed Rewards screen matching iOS RedeemedRewardsView.
 * Shows redeemed rewards history with time filters and details.
 */
@Composable
fun RedeemedRewardsScreen(
    rewards: List<Reward>,
    onDismiss: () -> Unit,
) {
    var selectedFilter by remember { mutableStateOf(PointsTimeFilter.ALL) }

    val filteredRewards = remember(rewards, selectedFilter) {
        rewards
            .filter { it.redemptions.any { date -> dateMatchesRedeemFilter(date, selectedFilter) } }
            .map { reward ->
                reward to reward.redemptions.filter { dateMatchesRedeemFilter(it, selectedFilter) }
            }
    }

    val totalRedeemed = filteredRewards.sumOf { it.second.size }

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
                "Redeemed Rewards",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        // Time filter chips
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(PointsTimeFilter.entries.toList()) { filter ->
                FilterChip(
                    selected = selectedFilter == filter,
                    onClick = { selectedFilter = filter },
                    label = { Text(filter.displayName, fontSize = 13.sp) },
                    shape = RoundedCornerShape(20.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Summary card
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFFFF6B6B).copy(alpha = 0.08f),
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
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFFF6B6B).copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Filled.Redeem,
                        contentDescription = null,
                        tint = Color(0xFFFF6B6B),
                        modifier = Modifier.size(22.dp),
                    )
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column {
                    Text(
                        "Total Redeemed",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        "$totalRedeemed times",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    "${filteredRewards.size} rewards",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Rewards list
        if (filteredRewards.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Filled.Redeem,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                        modifier = Modifier.size(64.dp),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        "No redeemed rewards",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                    )
                    Text(
                        "Redeem rewards with your earned points!",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(filteredRewards, key = { it.first.id }) { (reward, redemptions) ->
                    RedeemedRewardCard(reward = reward, redemptions = redemptions)
                }

                item { Spacer(modifier = Modifier.height(16.dp)) }
            }
        }
    }
}

@Composable
private fun RedeemedRewardCard(reward: Reward, redemptions: List<Date>) {
    val totalPointsSpent = redemptions.size * reward.pointsCost
    val dateFormat = remember { SimpleDateFormat("MMM d, yyyy 'at' HH:mm", Locale.getDefault()) }
    val lastRedeemed = redemptions.maxOrNull()

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
            // Top row: icon, name, points
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(
                            Color(0xFFFF6B6B).copy(alpha = 0.15f),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Filled.CardGiftcard,
                        contentDescription = null,
                        tint = Color(0xFFFF6B6B),
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        reward.name,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    if (reward.description != null) {
                        Text(
                            reward.description,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        "$totalPointsSpent pts",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                        color = Color(0xFFFF6B6B),
                    )
                    Text(
                        "${redemptions.size} times",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Last redeemed
            if (lastRedeemed != null) {
                Spacer(modifier = Modifier.height(10.dp))
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                Spacer(modifier = Modifier.height(8.dp))
                Row {
                    Text(
                        "Last redeemed:",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        dateFormat.format(lastRedeemed),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}

private fun dateMatchesRedeemFilter(date: Date, filter: PointsTimeFilter): Boolean {
    val calendar = Calendar.getInstance()
    val now = Date()
    return when (filter) {
        PointsTimeFilter.ALL -> true
        PointsTimeFilter.DAY -> {
            calendar.time = now
            calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0); calendar.set(Calendar.MILLISECOND, 0)
            date >= calendar.time
        }
        PointsTimeFilter.WEEK -> {
            calendar.time = now
            calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
            calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0); calendar.set(Calendar.MILLISECOND, 0)
            date >= calendar.time
        }
        PointsTimeFilter.MONTH -> {
            calendar.time = now
            calendar.set(Calendar.DAY_OF_MONTH, 1)
            calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0); calendar.set(Calendar.MILLISECOND, 0)
            date >= calendar.time
        }
        PointsTimeFilter.YEAR -> {
            calendar.time = now
            calendar.set(Calendar.DAY_OF_YEAR, 1)
            calendar.set(Calendar.HOUR_OF_DAY, 0); calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0); calendar.set(Calendar.MILLISECOND, 0)
            date >= calendar.time
        }
    }
}
