package com.snaptask.app.ui.rewards

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R
import com.snaptask.app.data.model.Reward
import com.snaptask.app.data.model.RewardFrequency
import com.snaptask.app.ui.components.parseHexColor
import java.util.UUID

/**
 * RewardsScreen — faithful port of iOS RewardsView.swift.
 * Displays available points, reward frequency filter, quick actions, and reward cards.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RewardsScreen(
    viewModel: RewardViewModel = hiltViewModel(),
) {
    val allRewards by viewModel.allRewards.collectAsState()
    val dailyPoints by viewModel.dailyPoints.collectAsState()
    val weeklyPoints by viewModel.weeklyPoints.collectAsState()
    val monthlyPoints by viewModel.monthlyPoints.collectAsState()
    val yearlyPoints by viewModel.yearlyPoints.collectAsState()

    var selectedFilter by remember { mutableStateOf(RewardFrequency.DAILY) }
    var showAddReward by remember { mutableStateOf(false) }
    var editingReward by remember { mutableStateOf<Reward?>(null) }
    var showPointsHistory by remember { mutableStateOf(false) }
    var showRedeemedRewards by remember { mutableStateOf(false) }

    val filteredRewards = remember(allRewards, selectedFilter) {
        allRewards.filter { it.frequency == selectedFilter }
            .sortedBy { it.pointsCost }
    }

    val primaryGradient = Brush.linearGradient(
        colors = listOf(
            MaterialTheme.colorScheme.primary,
            MaterialTheme.colorScheme.tertiary,
        ),
    )

    LaunchedEffect(Unit) {
        viewModel.updatePoints()
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background),
        ) {
            // Header — "Rewards" title
            Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text(
                    text = stringResource(R.string.rewards_title),
                    style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
                    color = MaterialTheme.colorScheme.onBackground,
                )
            }

            // Scrollable content
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    bottom = 100.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Unified Points & Filter View
                item {
                    UnifiedPointsFilterCard(
                        selectedFilter = selectedFilter,
                        onFilterChanged = { selectedFilter = it },
                        dailyPoints = dailyPoints,
                        weeklyPoints = weeklyPoints,
                        monthlyPoints = monthlyPoints,
                        yearlyPoints = yearlyPoints,
                        currentFilteredPoints = when (selectedFilter) {
                            RewardFrequency.DAILY -> dailyPoints
                            RewardFrequency.WEEKLY -> weeklyPoints
                            RewardFrequency.MONTHLY -> monthlyPoints
                            RewardFrequency.YEARLY -> yearlyPoints
                            RewardFrequency.ONE_TIME -> viewModel.currentPoints(RewardFrequency.ONE_TIME)
                        },
                    )
                }

                // Quick Actions
                item {
                    QuickActionsRow(
                        onPointsHistoryTapped = { showPointsHistory = true },
                        onRedeemedRewardsTapped = { showRedeemedRewards = true },
                    )
                }

                // Rewards List Header
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = "Available Rewards",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = MaterialTheme.colorScheme.onBackground,
                        )
                        Text(
                            text = "${filteredRewards.size} rewards",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                // Rewards List or Empty State
                if (filteredRewards.isEmpty()) {
                    item {
                        EmptyRewardsView()
                    }
                } else {
                    items(filteredRewards, key = { it.id }) { reward ->
                        RewardCard(
                            reward = reward,
                            canRedeem = viewModel.canRedeemReward(reward),
                            currentPoints = viewModel.currentPoints(reward.frequency),
                            onRedeemTapped = { viewModel.redeemReward(reward) },
                            onEditTapped = { editingReward = reward },
                            onDeleteTapped = { viewModel.removeReward(reward) },
                        )
                    }
                }
            }
        }

        // FAB — Add Reward Button (centered at bottom, like iOS)
        AddRewardButton(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 16.dp),
            onClick = { showAddReward = true },
        )
    }

    // Add Reward sheet
    if (showAddReward) {
        ModalBottomSheet(
            onDismissRequest = { showAddReward = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            RewardFormScreen(
                onSave = { reward ->
                    viewModel.addReward(reward)
                    showAddReward = false
                },
                onCancel = { showAddReward = false },
            )
        }
    }

    // Edit Reward sheet
    editingReward?.let { reward ->
        ModalBottomSheet(
            onDismissRequest = { editingReward = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            RewardFormScreen(
                initialReward = reward,
                onSave = { updatedReward ->
                    viewModel.updateReward(updatedReward)
                    editingReward = null
                },
                onCancel = { editingReward = null },
            )
        }
    }
}

// ─── Unified Points & Filter Card ───────────────────────────────────────────

@Composable
private fun UnifiedPointsFilterCard(
    selectedFilter: RewardFrequency,
    onFilterChanged: (RewardFrequency) -> Unit,
    dailyPoints: Int,
    weeklyPoints: Int,
    monthlyPoints: Int,
    yearlyPoints: Int,
    currentFilteredPoints: Int,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Header with total points
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text(
                        text = "Available Points",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(6.dp))
                    Row(
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = "$currentFilteredPoints",
                            style = MaterialTheme.typography.headlineLarge.copy(
                                fontWeight = FontWeight.Bold,
                                fontSize = 32.sp,
                            ),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = selectedFilter.displayName,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontWeight = FontWeight.Medium,
                            ),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 4.dp),
                        )
                    }
                }

                // Detail chevron button
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = "Details",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                    Text(
                        text = "Tap for\ndetails",
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        lineHeight = 11.sp,
                    )
                }
            }

            // Period breakdown chips
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                CompactPointsChip(title = "Today", points = dailyPoints, color = MaterialTheme.colorScheme.primary)
                CompactPointsChip(title = "Wk", points = weeklyPoints, color = MaterialTheme.colorScheme.secondary)
                CompactPointsChip(title = "Mo", points = monthlyPoints, color = MaterialTheme.colorScheme.tertiary)
                CompactPointsChip(title = "Yr", points = yearlyPoints, color = MaterialTheme.colorScheme.primary.copy(alpha = 0.8f))
            }

            // Filter Section
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Filter by Frequency",
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "$currentFilteredPoints pts available",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    listOf(
                        RewardFrequency.DAILY,
                        RewardFrequency.WEEKLY,
                        RewardFrequency.MONTHLY,
                        RewardFrequency.YEARLY,
                    ).forEach { frequency ->
                        val isSelected = selectedFilter == frequency
                        val bgColor by animateColorAsState(
                            targetValue = if (isSelected) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                            label = "filterBg",
                        )
                        val textColor by animateColorAsState(
                            targetValue = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            },
                            label = "filterText",
                        )

                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(bgColor)
                                .clickable { onFilterChanged(frequency) }
                                .padding(vertical = 8.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(3.dp),
                        ) {
                            Icon(
                                imageVector = when (frequency) {
                                    RewardFrequency.DAILY -> Icons.Default.WbSunny
                                    RewardFrequency.WEEKLY -> Icons.Default.DateRange
                                    RewardFrequency.MONTHLY -> Icons.Default.CalendarMonth
                                    RewardFrequency.YEARLY -> Icons.Default.Star
                                    else -> Icons.Default.AllInclusive
                                },
                                contentDescription = frequency.displayName,
                                tint = textColor,
                                modifier = Modifier.size(14.dp),
                            )
                            Text(
                                text = frequency.shortDisplayName,
                                style = MaterialTheme.typography.labelSmall.copy(
                                    fontWeight = FontWeight.Medium,
                                    fontSize = 10.sp,
                                ),
                                color = textColor,
                                maxLines = 1,
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─── Compact Points Chip ────────────────────────────────────────────────────

@Composable
private fun CompactPointsChip(
    title: String,
    points: Int,
    color: Color,
) {
    val abbreviated = remember(points) {
        when {
            points >= 1_000_000 -> String.format("%.1fM", points / 1_000_000.0).replace(".0M", "M")
            points >= 1_000 -> String.format("%.1fk", points / 1_000.0).replace(".0k", "k")
            else -> "$points"
        }
    }

    Row(
        modifier = Modifier
            .background(
                color = color.copy(alpha = 0.08f),
                shape = RoundedCornerShape(8.dp),
            )
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(color),
        )
        Text(
            text = abbreviated,
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
            ),
            color = color,
            maxLines = 1,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
            ),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
    }
}

// ─── Quick Actions ──────────────────────────────────────────────────────────

@Composable
private fun QuickActionsRow(
    onPointsHistoryTapped: () -> Unit,
    onRedeemedRewardsTapped: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CompactActionCard(
            modifier = Modifier.weight(1f),
            title = "Points History",
            icon = Icons.Default.ShowChart,
            color = MaterialTheme.colorScheme.primary,
            onClick = onPointsHistoryTapped,
        )
        CompactActionCard(
            modifier = Modifier.weight(1f),
            title = "Redeemed Rewards",
            icon = Icons.Default.CardGiftcard,
            color = MaterialTheme.colorScheme.secondary,
            onClick = onRedeemedRewardsTapped,
        )
    }
}

@Composable
private fun CompactActionCard(
    modifier: Modifier = Modifier,
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    onClick: () -> Unit,
) {
    Card(
        modifier = modifier.clickable(onClick = onClick),
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = color,
                modifier = Modifier.size(12.dp),
            )
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

// ─── Reward Card ────────────────────────────────────────────────────────────

@Composable
fun RewardCard(
    reward: Reward,
    canRedeem: Boolean,
    currentPoints: Int,
    onRedeemTapped: () -> Unit,
    onEditTapped: () -> Unit,
    onDeleteTapped: () -> Unit,
) {
    var isAnimating by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isAnimating) 0.95f else 1f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = 600f),
        label = "rewardScale",
    )

    val progress = remember(currentPoints, reward.pointsCost) {
        if (reward.pointsCost > 0) {
            (currentPoints.toFloat() / reward.pointsCost.toFloat()).coerceIn(0f, 1f)
        } else 0f
    }

    val (hasBeenRedeemed, redemptionCount) = remember(reward.redemptions) {
        reward.redemptionInfo()
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onEditTapped() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
    ) {
        Box {
            // Progress fill background
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .matchParentSize()
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                                MaterialTheme.colorScheme.secondary.copy(alpha = 0.20f),
                            ),
                        ),
                    ),
            )

            // Card content
            Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Header row: icon + title
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Icon circle
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(
                                Brush.linearGradient(
                                    colors = if (canRedeem) {
                                        listOf(
                                            MaterialTheme.colorScheme.primary,
                                            MaterialTheme.colorScheme.secondary,
                                        )
                                    } else {
                                        listOf(
                                            Color.Gray.copy(alpha = 0.4f),
                                            Color.Gray.copy(alpha = 0.5f),
                                        )
                                    },
                                ),
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Default.CardGiftcard,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(18.dp),
                        )
                    }

                    // Title + tags
                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = reward.name,
                                style = MaterialTheme.typography.bodyLarge.copy(
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 16.sp,
                                ),
                                color = MaterialTheme.colorScheme.onSurface,
                                maxLines = 2,
                                modifier = Modifier.weight(1f, fill = false),
                            )
                            Spacer(Modifier.width(8.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                // Type tag
                                RewardTypeTag(reward = reward)
                                // Redemption tag
                                if (redemptionCount > 1) {
                                    RedemptionCounterTag(count = redemptionCount)
                                } else if (hasBeenRedeemed) {
                                    RedemptionIndicator()
                                }
                            }
                        }
                        if (!reward.description.isNullOrEmpty()) {
                            Text(
                                text = reward.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                            )
                        }
                    }
                }

                // Category tag (if category-specific)
                if (!reward.isGeneralReward && !reward.categoryName.isNullOrEmpty()) {
                    Row {
                        Box(
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                                    RoundedCornerShape(8.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primary),
                                )
                                Text(
                                    text = reward.categoryName!!,
                                    style = MaterialTheme.typography.labelSmall.copy(
                                        fontWeight = FontWeight.Medium,
                                        fontSize = 11.sp,
                                    ),
                                    color = MaterialTheme.colorScheme.primary,
                                    maxLines = 1,
                                )
                            }
                        }
                        Spacer(Modifier.weight(1f))
                    }
                }

                // Bottom row: points + redeem button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column {
                        Text(
                            text = "$currentPoints/${reward.pointsCost} points",
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontWeight = FontWeight.Medium,
                                fontSize = 13.sp,
                            ),
                            color = if (canRedeem) {
                                parseHexColor("00C853")
                            } else {
                                MaterialTheme.colorScheme.primary
                            },
                        )
                        if (!canRedeem) {
                            val missing = reward.pointsCost - maxOf(currentPoints, 0)
                            Text(
                                text = "Need $missing more points",
                                style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }

                    Button(
                        onClick = {
                            if (canRedeem) {
                                isAnimating = true
                                onRedeemTapped()
                            }
                        },
                        enabled = canRedeem,
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (canRedeem) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                Color.Gray.copy(alpha = 0.3f)
                            },
                        ),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    ) {
                        Text(
                            text = "Redeem",
                            style = MaterialTheme.typography.labelMedium.copy(
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 12.sp,
                            ),
                        )
                    }
                }
            }
        }
    }
}

// ─── Tag Composables ────────────────────────────────────────────────────────

@Composable
private fun RewardTypeTag(reward: Reward) {
    val color = if (reward.isGeneralReward) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.secondary
    }

    Box(
        modifier = Modifier
            .background(color.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = if (reward.isGeneralReward) Icons.Default.Star else Icons.Default.Folder,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(8.dp),
            )
            Text(
                text = if (reward.isGeneralReward) "General" else reward.frequency.shortDisplayName,
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Medium,
                    fontSize = 10.sp,
                ),
                color = color,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun RedemptionIndicator() {
    Box(
        modifier = Modifier
            .background(Color(0xFF4CAF50).copy(alpha = 0.12f), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = Color(0xFF4CAF50),
                modifier = Modifier.size(8.dp),
            )
            Text(
                text = "Redeemed",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Medium,
                    fontSize = 9.sp,
                ),
                color = Color(0xFF4CAF50),
            )
        }
    }
}

@Composable
private fun RedemptionCounterTag(count: Int) {
    Box(
        modifier = Modifier
            .background(Color(0xFF4CAF50).copy(alpha = 0.15f), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = Color(0xFF4CAF50),
                modifier = Modifier.size(8.dp),
            )
            Text(
                text = "${count}x",
                style = MaterialTheme.typography.labelSmall.copy(
                    fontWeight = FontWeight.Bold,
                    fontSize = 9.sp,
                ),
                color = Color(0xFF4CAF50),
            )
        }
    }
}

// ─── Empty State ────────────────────────────────────────────────────────────

@Composable
private fun EmptyRewardsView() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Default.CardGiftcard,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp),
                )
            }

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "No Rewards Yet",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "Create your first reward to stay motivated!",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ─── Add Reward FAB ─────────────────────────────────────────────────────────

@Composable
private fun AddRewardButton(
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(dampingRatio = 0.5f, stiffness = 600f),
        label = "fabScale",
    )

    Box(
        modifier = modifier
            .size(56.dp)
            .shadow(
                elevation = 8.dp,
                shape = CircleShape,
                ambientColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
            )
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.primary,
                        MaterialTheme.colorScheme.tertiary,
                    ),
                ),
            )
            .clickable {
                isPressed = true
                onClick()
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Default.Add,
            contentDescription = "Add Reward",
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.onPrimary,
        )
    }
}
