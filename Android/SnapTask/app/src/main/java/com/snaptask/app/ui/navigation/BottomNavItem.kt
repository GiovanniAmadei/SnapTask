package com.snaptask.app.ui.navigation

import com.snaptask.app.R
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Bottom navigation destinations matching the iOS app's 5 tabs:
 * Timeline, Focus, Rewards, Finance, Statistics.
 * Use labelResId with stringResource() in UI for localization.
 */
enum class BottomNavItem(
    val route: String,
    val labelResId: Int,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector,
) {
    TIMELINE(
        route = "timeline",
        labelResId = R.string.nav_timeline,
        selectedIcon = Icons.Filled.CalendarMonth,
        unselectedIcon = Icons.Outlined.CalendarMonth,
    ),
    FOCUS(
        route = "focus",
        labelResId = R.string.nav_focus,
        selectedIcon = Icons.Filled.Timer,
        unselectedIcon = Icons.Outlined.Timer,
    ),
    REWARDS(
        route = "rewards",
        labelResId = R.string.nav_rewards,
        selectedIcon = Icons.Filled.EmojiEvents,
        unselectedIcon = Icons.Outlined.EmojiEvents,
    ),
    FINANCE(
        route = "finance",
        labelResId = R.string.nav_finance,
        selectedIcon = Icons.Filled.Payments,
        unselectedIcon = Icons.Outlined.Payments,
    ),
    STATISTICS(
        route = "statistics",
        labelResId = R.string.nav_statistics,
        selectedIcon = Icons.Filled.BarChart,
        unselectedIcon = Icons.Outlined.BarChart,
    ),
}
