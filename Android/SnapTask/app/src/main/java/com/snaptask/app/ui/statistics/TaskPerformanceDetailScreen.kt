package com.snaptask.app.ui.statistics

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.*

// ---- Time Range Enum ----

private enum class TaskPerfTimeRange(val displayName: String) {
    WEEK("Week"),
    MONTH("Month"),
    YEAR("Year"),
    ALL("All Time");

    fun filterCompletions(
        completions: List<StatisticsViewModel.TaskCompletionAnalytics>
    ): List<StatisticsViewModel.TaskCompletionAnalytics> {
        val calendar = Calendar.getInstance()
        val now = Date()
        val cutoff = when (this) {
            WEEK -> { calendar.add(Calendar.WEEK_OF_YEAR, -1); calendar.time }
            MONTH -> { calendar.add(Calendar.MONTH, -1); calendar.time }
            YEAR -> { calendar.add(Calendar.YEAR, -1); calendar.time }
            ALL -> Date(0)
        }
        return completions.filter { !it.date.before(cutoff) }
    }
}

// ---- Main Detail Screen ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskPerformanceDetailScreen(
    task: StatisticsViewModel.TaskPerformanceAnalytics,
    onDismiss: () -> Unit,
) {
    var selectedTimeRange by remember { mutableStateOf(TaskPerfTimeRange.MONTH) }
    val filteredCompletions = remember(selectedTimeRange, task) {
        selectedTimeRange.filterCompletions(task.completions)
    }
    val hasQualityData = filteredCompletions.any { it.qualityRating != null }
    val hasDifficultyData = filteredCompletions.any { it.difficultyRating != null }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Task Performance") },
                actions = {
                    TextButton(onClick = onDismiss) {
                        Text("Done")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Time range selector
            item { TimeRangeSection(selectedTimeRange) { selectedTimeRange = it } }

            // Task info card
            item { TaskInfoCard(task, filteredCompletions) }

            // Quality chart
            if (hasQualityData) {
                item { QualityChartSection(task, filteredCompletions, selectedTimeRange) }
            }

            // Difficulty chart
            if (hasDifficultyData) {
                item { DifficultyChartSection(task, filteredCompletions, selectedTimeRange) }
            }

            // Completions list
            item { CompletionsSection(filteredCompletions, selectedTimeRange) }

            item { Spacer(modifier = Modifier.height(32.dp)) }
        }
    }
}

// ---- Time Range Section ----

@Composable
private fun TimeRangeSection(
    selected: TaskPerfTimeRange,
    onSelected: (TaskPerfTimeRange) -> Unit,
) {
    DetailCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = "Time Range",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TaskPerfTimeRange.entries.forEach { range ->
                    val isSelected = selected == range
                    Surface(
                        onClick = { onSelected(range) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(6.dp),
                        color = if (isSelected)
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                        else
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f),
                        border = BorderStroke(
                            1.dp,
                            if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
                        ),
                    ) {
                        Text(
                            text = range.displayName,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium
                            ),
                            color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}

// ---- Task Info Card ----

@Composable
private fun TaskInfoCard(
    task: StatisticsViewModel.TaskPerformanceAnalytics,
    filteredCompletions: List<StatisticsViewModel.TaskCompletionAnalytics>,
) {
    val filteredQuality = filteredCompletions.mapNotNull { it.qualityRating }
    val filteredDifficulty = filteredCompletions.mapNotNull { it.difficultyRating }
    val filteredDuration = filteredCompletions.mapNotNull { it.actualDuration }

    DetailCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (task.categoryColor != null) {
                    Box(
                        modifier = Modifier
                            .width(6.dp)
                            .height(50.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(parseColor(task.categoryColor))
                    )
                }
                Column {
                    Text(
                        text = task.taskName,
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    )
                    if (task.categoryName != null) {
                        Text(
                            text = task.categoryName,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                DetailMetricCard(
                    title = "Completions",
                    value = "${filteredCompletions.size}",
                    color = MaterialTheme.colorScheme.primary,
                    icon = Icons.Filled.CheckCircle,
                    modifier = Modifier.weight(1f),
                )
                if (filteredQuality.isNotEmpty()) {
                    val avgQuality = filteredQuality.sum().toDouble() / filteredQuality.size
                    DetailMetricCard(
                        title = "Quality",
                        value = String.format("%.1f", avgQuality),
                        color = Color(0xFFFBBF24),
                        icon = Icons.Filled.Star,
                        modifier = Modifier.weight(1f),
                    )
                }
                if (filteredDifficulty.isNotEmpty()) {
                    val avgDifficulty = filteredDifficulty.sum().toDouble() / filteredDifficulty.size
                    DetailMetricCard(
                        title = "Difficulty",
                        value = String.format("%.1f", avgDifficulty),
                        color = Color(0xFFF97316),
                        icon = Icons.Filled.Bolt,
                        modifier = Modifier.weight(1f),
                    )
                }
                if (filteredDuration.isNotEmpty()) {
                    val avgDuration = filteredDuration.sum() / filteredDuration.size
                    DetailMetricCard(
                        title = "Time",
                        value = formatDuration(avgDuration),
                        color = Color(0xFF22C55E),
                        icon = Icons.Filled.Schedule,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailMetricCard(
    title: String,
    value: String,
    color: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.08f))
            .padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(12.dp), tint = color)
            Text(
                text = value,
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                maxLines = 1,
            )
        }
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

// ---- Quality Chart Section ----

@Composable
private fun QualityChartSection(
    task: StatisticsViewModel.TaskPerformanceAnalytics,
    filteredCompletions: List<StatisticsViewModel.TaskCompletionAnalytics>,
    timeRange: TaskPerfTimeRange,
) {
    val qualityPoints = filteredCompletions
        .mapNotNull { c -> c.qualityRating?.let { Pair(c.date, it.toFloat()) } }
        .sortedBy { it.first }

    DetailCard {
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
                    text = "Quality Over Time (${timeRange.displayName})",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                )
            }

            if (qualityPoints.isNotEmpty()) {
                LineChart(
                    series = listOf(
                        LineChartSeries(
                            points = qualityPoints.mapIndexed { i, p ->
                                LineChartPoint(i.toFloat(), p.second)
                            },
                            color = parseColor(task.categoryColor ?: "#6366F1"),
                            lineWidth = 3f,
                            showPoints = true,
                        )
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    yDomain = 0f..10f,
                )
            } else {
                Text(
                    text = "No quality ratings in ${timeRange.displayName.lowercase()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 40.dp),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ---- Difficulty Chart Section ----

@Composable
private fun DifficultyChartSection(
    task: StatisticsViewModel.TaskPerformanceAnalytics,
    filteredCompletions: List<StatisticsViewModel.TaskCompletionAnalytics>,
    timeRange: TaskPerfTimeRange,
) {
    val difficultyPoints = filteredCompletions
        .mapNotNull { c -> c.difficultyRating?.let { Pair(c.date, it.toFloat()) } }
        .sortedBy { it.first }

    DetailCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Bolt,
                    contentDescription = null,
                    tint = Color(0xFFF97316),
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Difficulty Over Time (${timeRange.displayName})",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                )
            }

            if (difficultyPoints.isNotEmpty()) {
                LineChart(
                    series = listOf(
                        LineChartSeries(
                            points = difficultyPoints.mapIndexed { i, p ->
                                LineChartPoint(i.toFloat(), p.second)
                            },
                            color = parseColor(task.categoryColor ?: "#6366F1"),
                            lineWidth = 3f,
                            showPoints = true,
                        )
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    yDomain = 0f..10f,
                )
            } else {
                Text(
                    text = "No difficulty ratings in ${timeRange.displayName.lowercase()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 40.dp),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ---- Completions Section ----

@Composable
private fun CompletionsSection(
    completions: List<StatisticsViewModel.TaskCompletionAnalytics>,
    timeRange: TaskPerfTimeRange,
) {
    DetailCard {
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
                    text = "Completions (${timeRange.displayName})",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                )
            }

            if (completions.isEmpty()) {
                Text(
                    text = "No completions in ${timeRange.displayName.lowercase()}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 20.dp),
                    textAlign = TextAlign.Center,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    completions.sortedByDescending { it.date }.forEach { completion ->
                        CompletionRow(completion)
                    }
                }
            }
        }
    }
}

@Composable
private fun CompletionRow(completion: StatisticsViewModel.TaskCompletionAnalytics) {
    val dateFormat = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())
    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = dateFormat.format(completion.date),
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
            )
            Text(
                text = timeFormat.format(completion.date),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            completion.qualityRating?.let { quality ->
                CompletionBadge(
                    icon = Icons.Filled.Star,
                    value = "$quality",
                    color = Color(0xFFFBBF24),
                )
            }
            completion.difficultyRating?.let { difficulty ->
                CompletionBadge(
                    icon = Icons.Filled.Bolt,
                    value = "$difficulty",
                    color = Color(0xFFF97316),
                )
            }
            completion.actualDuration?.let { duration ->
                val minutes = (duration / 60).toInt()
                CompletionBadge(
                    icon = Icons.Filled.Schedule,
                    value = "${minutes}m",
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun CompletionBadge(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    color: Color,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(color.copy(alpha = 0.1f))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(12.dp), tint = color)
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
        )
    }
}

// ---- Shared ----

@Composable
private fun DetailCard(
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
            modifier = Modifier.padding(20.dp),
            content = content,
        )
    }
}

private fun formatDuration(seconds: Double): String {
    val hours = (seconds / 3600).toInt()
    val minutes = (seconds % 3600 / 60).toInt()
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
