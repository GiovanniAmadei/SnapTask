package com.snaptask.app.ui.statistics

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R
import com.snaptask.app.data.model.TodoTask
import java.text.SimpleDateFormat
import java.util.*

// ---- Tab Enum ----

private enum class StatisticsTab(@androidx.annotation.StringRes val titleResId: Int) {
    OVERVIEW(com.snaptask.app.R.string.statistics_overview),
    STREAKS(com.snaptask.app.R.string.statistics_streaks),
    CONSISTENCY(com.snaptask.app.R.string.statistics_consistency),
    PERFORMANCE(com.snaptask.app.R.string.statistics_performance),
}

// ---- Main Screen ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatisticsScreen(
    viewModel: StatisticsViewModel = hiltViewModel()
) {
    var selectedTab by remember { mutableStateOf(StatisticsTab.OVERVIEW) }
    val surfaceColor = MaterialTheme.colorScheme.surface
    val onSurfaceColor = MaterialTheme.colorScheme.onSurface

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Header
        Text(
            text = stringResource(R.string.nav_statistics),
            style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
            modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 8.dp)
        )

        // Tab selector
        ScrollableTabRow(
            selectedTabIndex = selectedTab.ordinal,
            modifier = Modifier.fillMaxWidth(),
            edgePadding = 16.dp,
            containerColor = Color.Transparent,
            contentColor = MaterialTheme.colorScheme.primary,
            divider = {},
        ) {
            StatisticsTab.entries.forEach { tab ->
                Tab(
                    selected = selectedTab == tab,
                    onClick = { selectedTab = tab },
                    text = {
                        Text(
                            text = stringResource(tab.titleResId),
                            fontWeight = if (selectedTab == tab) FontWeight.SemiBold else FontWeight.Medium,
                            fontSize = 14.sp,
                        )
                    }
                )
            }
        }

        HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)

        // Tab content
        when (selectedTab) {
            StatisticsTab.OVERVIEW -> OverviewTab(viewModel)
            StatisticsTab.STREAKS -> StreaksTab(viewModel)
            StatisticsTab.CONSISTENCY -> ConsistencyTab(viewModel)
            StatisticsTab.PERFORMANCE -> PerformanceTab(viewModel)
        }
    }
}

// ====================
// OVERVIEW TAB
// ====================

@Composable
private fun OverviewTab(viewModel: StatisticsViewModel) {
    val categoryStats by viewModel.categoryStats.collectAsState()
    val currentStreak by viewModel.currentStreak.collectAsState()
    val bestStreak by viewModel.bestStreak.collectAsState()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item { TimeDistributionCard(viewModel) }
        item { TaskCompletionCard(viewModel) }
        item { OverallStreakCard(currentStreak, bestStreak) }
        item { MoodTrendCard() }
        item { Spacer(modifier = Modifier.height(80.dp)) }
    }
}

// ---- Time Distribution Card ----

@Composable
private fun TimeDistributionCard(viewModel: StatisticsViewModel) {
    val categoryStats by viewModel.categoryStats.collectAsState()
    val selectedRange by viewModel.selectedTimeRange.collectAsState()

    StatCard {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            // Header
            Text(
                text = stringResource(R.string.stat_time_distribution),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            )

            // Time range selector
            TimeRangeSelector(
                selected = selectedRange,
                onSelected = { viewModel.setTimeRange(it) }
            )

            if (categoryStats.isEmpty()) {
                EmptyStateView(
                    icon = Icons.Outlined.PieChart,
                    title = stringResource(R.string.stat_no_time_data),
                    subtitle = stringResource(R.string.stat_complete_tasks_distribution)
                )
            } else {
                // Pie chart
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    PieChart(
                        slices = categoryStats.map { stat ->
                            PieChartSlice(
                                value = stat.hours.toFloat(),
                                color = parseColor(stat.color),
                                label = stat.name
                            )
                        },
                        modifier = Modifier.size(170.dp),
                    )
                }

                // Legend grid - 2 columns
                val rows = categoryStats.chunked(2)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    rows.forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            row.forEach { stat ->
                                CategoryLegendItem(
                                    stat = stat,
                                    modifier = Modifier.weight(1f)
                                )
                            }
                            if (row.size < 2) Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryLegendItem(
    stat: StatisticsViewModel.CategoryStat,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(parseColor(stat.color))
        )
        Column {
            Text(
                text = stat.name,
                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = formatTimeValue(stat.hours),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// ---- Task Completion Card ----

private enum class CompletionPeriod(val displayName: String, val daysCount: Int, val dayOffset: Int) {
    WEEK("7d", 7, -6),
    MONTH("30d", 30, -29),
    YEAR("1y", 365, -364),
}

@Composable
private fun TaskCompletionCard(viewModel: StatisticsViewModel) {
    var selectedPeriod by remember { mutableStateOf(CompletionPeriod.WEEK) }

    val completionStats = remember(selectedPeriod, viewModel) {
        computeCompletionStats(viewModel, selectedPeriod)
    }

    val hasData = completionStats.any { it.totalTasks > 0 }

    StatCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Header
            Text(
                text = stringResource(R.string.stat_task_completion_rate),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            )

            // Period selector
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                CompletionPeriod.entries.forEach { period ->
                    PillButton(
                        text = period.displayName,
                        isSelected = selectedPeriod == period,
                        onClick = { selectedPeriod = period },
                        modifier = Modifier.weight(1f),
                    )
                }
            }

            if (hasData) {
                // Bar chart
                BarChart(
                    data = completionStats.map { stat ->
                        BarChartData(
                            label = stat.day,
                            primaryValue = stat.completedTasks.toFloat(),
                            secondaryValue = maxOf(0, stat.totalTasks - stat.completedTasks).toFloat(),
                            primaryColor = MaterialTheme.colorScheme.primary,
                            secondaryColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(130.dp),
                )

                // Legend + avg rate
                val totalCompleted = completionStats.sumOf { it.completedTasks }
                val totalTasks = completionStats.sumOf { it.totalTasks }
                val avgRate = if (totalTasks > 0) (totalCompleted.toDouble() / totalTasks * 100).toInt() else 0

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        ChartLegendItem(color = Color(0xFF22C55E), label = stringResource(R.string.stat_completed))
                        ChartLegendItem(color = Color.Gray.copy(alpha = 0.3f), label = stringResource(R.string.stat_total))
                    }
                    Text(
                        text = "$avgRate%",
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    )
                }
            } else {
                EmptyStateView(
                    icon = Icons.Outlined.BarChart,
                    title = stringResource(R.string.stat_no_completion_data),
                    subtitle = stringResource(R.string.stat_complete_tasks_trends)
                )
            }
        }
    }
}

// ---- Overall Streak Card ----

@Composable
private fun OverallStreakCard(currentStreak: Int, bestStreak: Int) {
    StatCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(
                text = stringResource(R.string.stat_overall_streak),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(30.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Current streak
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$currentStreak",
                        style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
                        color = Color(0xFFF97316), // orange
                    )
                    Text(
                        text = stringResource(R.string.stat_current),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                // Divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(50.dp)
                        .background(MaterialTheme.colorScheme.outlineVariant)
                )

                // Best streak
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$bestStreak",
                        style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
                        color = Color(0xFFEF4444), // red
                    )
                    Text(
                        text = stringResource(R.string.stat_best),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

// ---- Mood Trend Card (Stub) ----

@Composable
private fun MoodTrendCard() {
    StatCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.stat_mood_trend),
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                )
                Spacer(modifier = Modifier.weight(1f))
            }

            // Empty state - mood tracking not yet wired
            Icon(
                imageVector = Icons.Outlined.SentimentSatisfied,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = stringResource(R.string.stat_no_mood_data),
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
            )
            Text(
                text = stringResource(R.string.stat_track_mood),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ====================
// STREAKS TAB
// ====================

private enum class StreakViewMode { CHART, HEATMAP }

@Composable
private fun StreaksTab(viewModel: StatisticsViewModel) {
    val taskStreaks by viewModel.taskStreaks.collectAsState()
    var viewMode by remember { mutableStateOf(StreakViewMode.CHART) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // View mode toggle
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                PillButton(
                    text = stringResource(R.string.stat_chart),
                    isSelected = viewMode == StreakViewMode.CHART,
                    onClick = { viewMode = StreakViewMode.CHART },
                    modifier = Modifier.weight(1f),
                )
                PillButton(
                    text = stringResource(R.string.stat_heat_map),
                    isSelected = viewMode == StreakViewMode.HEATMAP,
                    onClick = { viewMode = StreakViewMode.HEATMAP },
                    modifier = Modifier.weight(1f),
                )
            }
        }

        if (taskStreaks.isEmpty()) {
            item {
                EmptyStateView(
                    icon = Icons.Outlined.LocalFireDepartment,
                    title = stringResource(R.string.stat_no_streaks_yet),
                    subtitle = stringResource(R.string.stat_complete_recurring_streaks),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        } else {
            items(taskStreaks, key = { it.taskId }) { streak ->
                TaskStreakCard(
                    taskStreak = streak,
                    viewMode = viewMode,
                    viewModel = viewModel,
                )
            }
        }

        item { Spacer(modifier = Modifier.height(80.dp)) }
    }
}

@Composable
private fun TaskStreakCard(
    taskStreak: StatisticsViewModel.TaskStreak,
    viewMode: StreakViewMode,
    viewModel: StatisticsViewModel,
) {
    val categoryColor = parseColor(taskStreak.categoryColor ?: "#6366F1")
    var selectedTimeRange by remember { mutableStateOf(HeatMapTimeRange.THREE_MONTHS) }

    StatCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (taskStreak.categoryColor != null) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(categoryColor)
                    )
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = taskStreak.taskName,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (taskStreak.categoryName != null) {
                        Text(
                            text = taskStreak.categoryName,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = "${(taskStreak.completionRate * 100).toInt()}%",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    )
                    Text(
                        text = stringResource(R.string.stat_complete),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Stats row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    StreakStatItem(stringResource(R.string.stat_current), taskStreak.currentStreak, Color(0xFFF97316))
                    StreakStatItem(stringResource(R.string.stat_best), taskStreak.bestStreak, Color(0xFFEF4444))
                    StreakStatItem(
                        stringResource(R.string.stat_done),
                        taskStreak.completedOccurrences,
                        Color(0xFF22C55E),
                        suffix = "/${taskStreak.totalOccurrences}"
                    )
                }

                // Time range selector (small pills)
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    HeatMapTimeRange.entries.forEach { range ->
                        SmallPillButton(
                            text = range.label,
                            isSelected = selectedTimeRange == range,
                            selectedColor = categoryColor,
                            onClick = { selectedTimeRange = range },
                        )
                    }
                }
            }

            // Chart or heatmap
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp)
            ) {
                if (viewMode == StreakViewMode.CHART) {
                    val filteredHistory = taskStreak.streakHistory.let { history ->
                        val calendar = Calendar.getInstance()
                        val today = Date()
                        val daysBack = selectedTimeRange.weeksCount * 7
                        calendar.time = today
                        calendar.add(Calendar.DAY_OF_YEAR, -daysBack)
                        val startDate = calendar.time
                        history.filter { !it.date.before(startDate) }
                    }

                    if (filteredHistory.isNotEmpty()) {
                        LineChart(
                            series = listOf(
                                LineChartSeries(
                                    points = filteredHistory.mapIndexed { index, point ->
                                        LineChartPoint(
                                            x = index.toFloat(),
                                            y = point.streakValue.toFloat()
                                        )
                                    },
                                    color = categoryColor,
                                    lineWidth = 2f,
                                    showPoints = true,
                                )
                            ),
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                } else {
                    // Heat map
                    val heatMapCells = buildHeatMapCells(
                        taskStreak = taskStreak,
                        weeksCount = selectedTimeRange.weeksCount,
                        viewModel = viewModel,
                    )
                    HeatMapGrid(
                        cells = heatMapCells,
                        categoryColor = categoryColor,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
        }
    }
}

@Composable
private fun StreakStatItem(
    label: String,
    value: Int,
    color: Color,
    suffix: String = "",
) {
    Column {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = "$value",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = color,
            )
            if (suffix.isNotEmpty()) {
                Text(
                    text = suffix,
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = Color(0xFF22C55E),
                )
            }
        }
    }
}

// ====================
// CONSISTENCY TAB
// ====================

@Composable
private fun ConsistencyTab(viewModel: StatisticsViewModel) {
    val consistencyTasks by viewModel.consistency.collectAsState()
    var selectedTimeRange by remember { mutableStateOf(StatisticsViewModel.ConsistencyTimeRange.WEEK) }
    var selectedTaskId by remember { mutableStateOf<UUID?>(null) }
    var penalizeMissedTasks by remember { mutableStateOf(true) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            StatCard {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Header
                    Text(
                        text = stringResource(R.string.stat_task_progress_over_time),
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    Text(
                        text = stringResource(R.string.stat_track_recurring),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    // Time range picker
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StatisticsViewModel.ConsistencyTimeRange.entries.forEach { range ->
                            PillButton(
                                text = range.displayName,
                                isSelected = selectedTimeRange == range,
                                onClick = { selectedTimeRange = range },
                                modifier = Modifier.weight(1f),
                            )
                        }
                    }

                    if (consistencyTasks.isEmpty()) {
                        EmptyStateView(
                            icon = Icons.Outlined.Timeline,
                            title = stringResource(R.string.stat_no_consistency_data),
                            subtitle = stringResource(R.string.stat_add_recurring_consistency),
                        )
                    } else {
                        // Chart
                        val seriesList = consistencyTasks.mapNotNull { task ->
                            if (selectedTaskId != null && task.id != selectedTaskId) return@mapNotNull null
                            val points = viewModel.consistencyPoints(task, selectedTimeRange)
                            if (points.isEmpty()) return@mapNotNull null
                            LineChartSeries(
                                points = points.map { LineChartPoint(it.first, it.second) },
                                color = parseColor(task.category?.color ?: "#6366F1"),
                                label = task.name,
                                lineWidth = if (selectedTaskId == task.id || selectedTaskId == null) 3f else 1.5f,
                                showPoints = selectedTaskId == task.id,
                            )
                        }

                        if (seriesList.isNotEmpty()) {
                            LineChart(
                                series = seriesList,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(200.dp),
                            )
                        }

                        // Penalty toggle
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.06f))
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.stat_penalize_missed),
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                                )
                                Text(
                                    text = stringResource(R.string.stat_progress_decreases),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Switch(
                                checked = penalizeMissedTasks,
                                onCheckedChange = { penalizeMissedTasks = it }
                            )
                        }

                        // Task legend
                        Text(
                            text = stringResource(R.string.stat_tasks),
                            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold),
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            consistencyTasks.forEach { task ->
                                val isSelected = selectedTaskId == task.id
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(
                                            if (isSelected)
                                                parseColor(task.category?.color ?: "#6366F1").copy(alpha = 0.15f)
                                            else
                                                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                                        )
                                        .clickable {
                                            selectedTaskId = if (selectedTaskId == task.id) null else task.id
                                        }
                                        .padding(horizontal = 12.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(10.dp)
                                            .clip(CircleShape)
                                            .background(parseColor(task.category?.color ?: "#6366F1"))
                                    )
                                    Text(
                                        text = task.name,
                                        style = MaterialTheme.typography.bodyMedium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        modifier = Modifier.weight(1f),
                                    )
                                    if (task.category != null) {
                                        Text(
                                            text = task.category.name,
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        item { Spacer(modifier = Modifier.height(80.dp)) }
    }
}

// ====================
// PERFORMANCE TAB
// ====================

@Composable
private fun PerformanceTab(viewModel: StatisticsViewModel) {
    val analytics by viewModel.taskPerformanceAnalytics.collectAsState()
    val topPerforming by viewModel.topPerformingTasks.collectAsState()
    val needsImprovement by viewModel.tasksNeedingImprovement.collectAsState()
    val selectedRange by viewModel.selectedTimeRange.collectAsState()
    var selectedTask by remember { mutableStateOf<StatisticsViewModel.TaskPerformanceAnalytics?>(null) }

    if (selectedTask != null) {
        TaskPerformanceDetailScreen(
            task = selectedTask!!,
            onDismiss = { selectedTask = null }
        )
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (analytics.isEmpty()) {
            item {
                EmptyStateView(
                    icon = Icons.Outlined.TrendingUp,
                    title = stringResource(R.string.stat_no_performance_data),
                    subtitle = stringResource(R.string.stat_complete_quality_ratings),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        } else {
            // Time range selector
            item {
                TimeRangeSelector(
                    selected = selectedRange,
                    onSelected = { viewModel.setTimeRange(it) }
                )
            }

            // Summary stats
            item {
                PerformanceSummaryCard(analytics)
            }

            // Top performing tasks
            if (topPerforming.isNotEmpty()) {
                item {
                    StatCard {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Filled.Star,
                                    contentDescription = null,
                                    tint = Color(0xFFFBBF24),
                                    modifier = Modifier.size(20.dp),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.stat_top_performing),
                                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                                )
                            }
                            topPerforming.forEach { task ->
                                TaskPerformanceRow(task) { selectedTask = task }
                            }
                        }
                    }
                }
            }

            // Tasks needing improvement
            if (needsImprovement.isNotEmpty()) {
                item {
                    StatCard {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Filled.TrendingDown,
                                    contentDescription = null,
                                    tint = Color(0xFFF97316),
                                    modifier = Modifier.size(20.dp),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.stat_needs_improvement),
                                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                                )
                            }
                            needsImprovement.forEach { task ->
                                TaskPerformanceRow(task) { selectedTask = task }
                            }
                        }
                    }
                }
            }

            // All tasks with performance data
            item {
                StatCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Filled.List,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.stat_all_tasks_performance),
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                            )
                        }
                        analytics.forEach { task ->
                            TaskPerformanceRow(task) { selectedTask = task }
                        }
                    }
                }
            }
        }

        item { Spacer(modifier = Modifier.height(80.dp)) }
    }
}

@Composable
private fun PerformanceSummaryCard(analytics: List<StatisticsViewModel.TaskPerformanceAnalytics>) {
    val avgQuality = analytics.mapNotNull { it.averageQuality }.let {
        if (it.isNotEmpty()) it.average() else null
    }
    val avgDifficulty = analytics.mapNotNull { it.averageDifficulty }.let {
        if (it.isNotEmpty()) it.average() else null
    }
    val avgAccuracy = analytics.mapNotNull { it.estimationAccuracy }.let {
        if (it.isNotEmpty()) it.average() else null
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (avgQuality != null) {
            PerformanceStatBadge(
                title = stringResource(R.string.stat_avg_quality),
                value = String.format("%.1f", avgQuality),
                color = Color(0xFFFBBF24),
                modifier = Modifier.weight(1f),
            )
        }
        if (avgDifficulty != null) {
            PerformanceStatBadge(
                title = stringResource(R.string.stat_avg_difficulty),
                value = String.format("%.1f", avgDifficulty),
                color = Color(0xFFF97316),
                modifier = Modifier.weight(1f),
            )
        }
        if (avgAccuracy != null) {
            PerformanceStatBadge(
                title = stringResource(R.string.stat_estimation),
                value = "${(avgAccuracy * 100).toInt()}%",
                color = Color(0xFF22C55E),
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PerformanceStatBadge(
    title: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            color = color,
            maxLines = 1,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

@Composable
private fun TaskPerformanceRow(
    task: StatisticsViewModel.TaskPerformanceAnalytics,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (task.categoryColor != null) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(32.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(parseColor(task.categoryColor))
            )
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = task.taskName,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (task.categoryName != null) {
                Text(
                    text = task.categoryName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Metric badges
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (task.averageQuality != null) {
                MetricBadge(
                    icon = Icons.Filled.Star,
                    value = String.format("%.1f", task.averageQuality),
                    color = Color(0xFFFBBF24),
                )
            }
            if (task.averageDifficulty != null) {
                MetricBadge(
                    icon = Icons.Filled.Bolt,
                    value = String.format("%.1f", task.averageDifficulty),
                    color = Color(0xFFF97316),
                )
            }
            MetricBadge(
                icon = Icons.Filled.CheckCircle,
                value = "${task.completions.size}",
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun MetricBadge(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    color: Color,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(3.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(horizontal = 4.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(10.dp),
            tint = color,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
            maxLines = 1,
        )
    }
}

// ====================
// SHARED COMPONENTS
// ====================

@Composable
private fun StatCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            content = content,
        )
    }
}

@Composable
private fun TimeRangeSelector(
    selected: StatisticsViewModel.TimeRange,
    onSelected: (StatisticsViewModel.TimeRange) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        StatisticsViewModel.TimeRange.entries.forEach { range ->
            PillButton(
                text = range.displayName,
                isSelected = selected == range,
                onClick = { onSelected(range) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PillButton(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val containerColor = if (isSelected)
        MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
    else
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)

    val borderColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
    val textColor = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface

    Surface(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(6.dp),
        color = containerColor,
        border = BorderStroke(1.dp, borderColor),
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
            style = MaterialTheme.typography.labelSmall.copy(
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium
            ),
            color = textColor,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

@Composable
private fun SmallPillButton(
    text: String,
    isSelected: Boolean,
    selectedColor: Color,
    onClick: () -> Unit,
) {
    val containerColor = if (isSelected) selectedColor else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    val textColor = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(4.dp),
        color = containerColor,
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
            color = textColor,
            maxLines = 1,
        )
    }
}

@Composable
private fun EmptyStateView(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

// ---- Enums ----

private enum class HeatMapTimeRange(val label: String, val weeksCount: Int) {
    ONE_MONTH("1M", 5),
    THREE_MONTHS("3M", 13),
    SIX_MONTHS("6M", 26),
    YEAR("1Y", 52),
}

// ---- Helper Functions ----

private fun computeCompletionStats(
    viewModel: StatisticsViewModel,
    period: CompletionPeriod,
): List<StatisticsViewModel.WeeklyStat> {
    val calendar = Calendar.getInstance()
    val today = Date()
    calendar.time = today
    calendar.add(Calendar.DAY_OF_YEAR, period.dayOffset)
    val startDate = calendar.time

    return when (period) {
        CompletionPeriod.WEEK -> {
            (0..6).map { dayOffset ->
                calendar.time = startDate
                calendar.add(Calendar.DAY_OF_YEAR, dayOffset)
                val date = calendar.time
                val dayStats = viewModel.getWeeklyStatsForDay(date)
                val sdf = SimpleDateFormat("EEE", Locale.getDefault())
                StatisticsViewModel.WeeklyStat(
                    day = sdf.format(date),
                    completedTasks = dayStats.first,
                    totalTasks = dayStats.second,
                    completionRate = dayStats.third,
                )
            }
        }
        CompletionPeriod.MONTH -> {
            (0 until 5).map { weekOffset ->
                val weekStats = viewModel.getWeeklyStatsForWeekOffset(weekOffset)
                StatisticsViewModel.WeeklyStat(
                    day = "W${weekOffset + 1}",
                    completedTasks = weekStats.first,
                    totalTasks = weekStats.second,
                    completionRate = weekStats.third,
                )
            }
        }
        CompletionPeriod.YEAR -> {
            (0 until 12).map { monthOffset ->
                calendar.time = startDate
                calendar.add(Calendar.MONTH, monthOffset)
                val monthStart = calendar.time
                val monthStats = viewModel.getMonthlyStatsForMonth(monthStart)
                val sdf = SimpleDateFormat("MMM", Locale.getDefault())
                StatisticsViewModel.WeeklyStat(
                    day = sdf.format(monthStart),
                    completedTasks = monthStats.first,
                    totalTasks = monthStats.second,
                    completionRate = monthStats.third,
                )
            }
        }
    }
}

private fun buildHeatMapCells(
    taskStreak: StatisticsViewModel.TaskStreak,
    weeksCount: Int,
    viewModel: StatisticsViewModel,
): List<List<HeatMapCell>> {
    val calendar = Calendar.getInstance()
    val today = Recurrence.startOfDay(Date())
    calendar.time = today

    // Find the start date (going back weeksCount * 7 days)
    calendar.add(Calendar.DAY_OF_YEAR, -(weeksCount * 7 - 1))
    val startDate = calendar.time

    // Get the task to check occurrences
    val tasks = viewModel.recurringTasks.value
    val task = tasks.find { it.id == taskStreak.taskId }

    val weeks = mutableListOf<List<HeatMapCell>>()
    var currentDate = startDate

    for (week in 0 until weeksCount) {
        val weekCells = mutableListOf<HeatMapCell>()
        for (day in 0 until 7) {
            val dayDate = Recurrence.startOfDay(currentDate)
            val isScheduled = task?.let { viewModel.shouldTaskOccurOnDate(it, dayDate) } ?: false
            val isCompleted = task?.completions?.get(dayDate.time)?.isCompleted == true
            weekCells.add(HeatMapCell(date = dayDate, isCompleted = isCompleted, isScheduled = isScheduled))
            calendar.time = currentDate
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            currentDate = calendar.time
        }
        weeks.add(weekCells)
    }

    return weeks
}

private fun formatTimeValue(hours: Double): String {
    val totalMinutes = (hours * 60).toInt()
    val displayHours = totalMinutes / 60
    val displayMinutes = totalMinutes % 60
    return if (displayHours > 0) "${displayHours}h ${displayMinutes}m" else "${displayMinutes}m"
}

// Need to import Recurrence for startOfDay
private typealias Recurrence = com.snaptask.app.data.model.Recurrence
