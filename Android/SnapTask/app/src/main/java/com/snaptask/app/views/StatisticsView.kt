package com.snaptask.app

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.UUID
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

private val vm = StatisticsViewModel
private val comparisonColors = listOf(Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFF10B981))
private const val maxCompared = 3
private val qualityColor = Color(0xFFF5B400)
private val difficultyColor = Color(0xFFFF6B3D)

private fun one(value: Double) = "%.1f".format(appLocale, value)

private fun bucketLabel(date: Date, unit: CalUnit, range: TimeRange): String = when (unit) {
    CalUnit.day -> if (range == TimeRange.week) date.skeleton("EEE") else date.skeleton("d")
    CalUnit.week -> date.skeleton("dMMM")
    else -> if (range == TimeRange.allTime) date.skeleton("MMMyy") else date.skeleton("MMM")
}

private fun bucketTitle(date: Date, unit: CalUnit): String = when (unit) {
    CalUnit.day -> date.skeleton("EEEEdMMM")
    CalUnit.week -> "stats_week_of".localized(date.skeleton("dMMM"))
    else -> date.skeleton("MMMMy")
}

@Composable
fun StatisticsView() {
    val theme = theme
    val presenter = LocalPresenter.current
    var tab by remember { mutableStateOf(0) }
    val locked = !SubscriptionManager.hasAccess(PremiumFeature.advancedStatistics)
    val tabs = listOf("overview", "streaks", "consistency", "performance")
    val periods = listOf(TimeRange.week, TimeRange.month, TimeRange.year, TimeRange.allTime)
    val range = vm.selectedTimeRange
    // The numbers follow every change of the data they come from.
    LaunchedEffect(range, TaskManager.tasks, CategoryManager.categories, TimeTrackingStore.revision, MoodManager.entries, TaskManager.trackingSessions) { vm.update() }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor).statusBarsPadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        T("statistics".localized, Fonts.largeTitle.bold, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 8.dp))
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            StatsSegmentedControl(
                tabs.indices.toList(), tab, { tab = it }, { tabs[it].localized },
                isLocked = { it != 0 && locked },
                onLockedTap = { presenter.sheet { PremiumPaywallView() } },
            )
            StatsSegmentedControl(periods, range, { vm.selectedTimeRange = it }, {
                when (it) {
                    TimeRange.today -> "today"
                    TimeRange.week -> "stats_period_7d"
                    TimeRange.month -> "stats_period_30d"
                    TimeRange.year -> "stats_period_12m"
                    TimeRange.allTime -> "stats_period_all"
                }.localized
            })
        }
        Crossfade(tab, Modifier.weight(1f).fillMaxWidth(), animationSpec = tween(200), label = "statsTab") { selected ->
            when {
                selected == 0 -> OverviewStatsTab()
                locked -> PremiumRequiredTab()
                selected == 1 -> StreaksStatsTab()
                selected == 2 -> ConsistencyStatsTab()
                else -> PerformanceStatsTab()
            }
        }
    }
}

@Composable
private fun PremiumRequiredTab() {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(Modifier.fillMaxSize().padding(top = 60.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(Modifier.size(80.dp).background(Color.SysPurple.copy(alpha = 0.1f), CircleShape), contentAlignment = Alignment.Center) { SF("chart.line.uptrend.xyaxis", Color.SysPurple, 36.dp) }
            Column(Modifier.padding(horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("premium_required".localized, Fonts.title2.bold, align = TextAlign.Center)
                T("premium_feature_locked".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
            }
        }
        Column(Modifier.padding(horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("advanced_statistics_desc".localized, Fonts.body, theme.secondaryTextColor, TextAlign.Center)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Brush.horizontalGradient(listOf(Color.SysPurple, Color.SysPink)))
                    .pressable { presenter.sheet { PremiumPaywallView() } }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                T("upgrade_to_pro".localized, Fonts.headline, Color.White, maxLines = 1)
                SF("arrow.right", Color.White, 18.dp)
            }
        }
    }
}

@Composable
private fun TabColumn(spacing: Int = 14, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = tabBarInset() + 24.dp),
        verticalArrangement = Arrangement.spacedBy(spacing.dp),
        content = content,
    )
}

// MARK: - Charts

private data class BarSegment(val value: Double, val color: Color)
private data class StatBar(val segments: List<BarSegment>, val annotation: String? = null)

/** Vertical bars (stacked when several segments), Swift Charts' `BarMark`. */
@Composable
private fun StatsBars(
    bars: List<StatBar>,
    labels: List<String?>,
    modifier: Modifier,
    yMax: Double? = null,
    average: Double? = null,
    yTicks: List<Double> = emptyList(),
    yFormat: (Double) -> String = { it.toInt().toString() },
    corner: Dp = 3.dp,
    selected: Int? = null,
    onSelect: ((Int?) -> Unit)? = null,
    tooltip: (@Composable (Int) -> Unit)? = null,
) {
    val theme = theme
    val measurer = rememberTextMeasurer()
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, color = theme.secondaryTextColor)
    val annotationStyle = TextStyle(fontFamily = Inter, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = theme.secondaryTextColor)
    val grid = theme.secondaryTextColor.copy(alpha = 0.2f)
    val avgColor = theme.textColor.copy(alpha = 0.35f)
    val computedMax = yMax ?: bars.maxOfOrNull { b -> b.segments.sumOf { it.value } }?.takeIf { it > 0 } ?: 1.0
    val density = LocalDensity.current
    val axisWidth = if (yTicks.isEmpty()) 0.dp else with(density) { yTicks.maxOf { measurer.measure(yFormat(it), labelStyle).size.width }.toDp() + 6.dp }
    var width by remember { mutableStateOf(0f) }
    Box(modifier) {
        Canvas(
            Modifier
                .fillMaxSize()
                .then(
                    if (onSelect != null) {
                        Modifier
                            .pointerInput(bars.size) {
                                detectTapGestures { position ->
                                    val left = axisWidth.toPx()
                                    val index = ((position.x - left) / ((size.width - left) / bars.size)).toInt()
                                    onSelect(index.takeIf { it in bars.indices && it != selected })
                                }
                            }
                    } else Modifier,
                ),
        ) {
            width = size.width
            val left = axisWidth.toPx()
            val axisHeight = 20.dp.toPx()
            val plot = size.height - axisHeight
            fun y(value: Double) = (plot * (1 - value / computedMax)).toFloat()
            yTicks.forEach { tick ->
                drawLine(grid, Offset(left, y(tick)), Offset(size.width, y(tick)), 0.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())))
                val text = measurer.measure(yFormat(tick), labelStyle)
                drawText(text, topLeft = Offset(0f, (y(tick) - text.size.height / 2).coerceIn(0f, plot - text.size.height / 2)))
            }
            val slot = (size.width - left) / bars.size
            val barWidth = slot * 0.68f
            val radius = CornerRadius(corner.toPx())
            bars.forEachIndexed { index, bar ->
                val x = left + slot * index + (slot - barWidth) / 2
                val alpha = if (selected == null || selected == index) 1f else 0.4f
                var bottom = plot
                bar.segments.forEach { segment ->
                    if (segment.value > 0) {
                        val height = (plot * (segment.value / computedMax)).toFloat()
                        drawRoundRect(segment.color.copy(alpha = segment.color.alpha * alpha), Offset(x, bottom - height), Size(barWidth, height), radius)
                        bottom -= height
                    }
                }
                bar.annotation?.let { note ->
                    val text = measurer.measure(note, annotationStyle)
                    drawText(text, topLeft = Offset(x + barWidth / 2 - text.size.width / 2, (bottom - text.size.height - 2.dp.toPx()).coerceAtLeast(0f)))
                }
                labels.getOrNull(index)?.let { label ->
                    val text = measurer.measure(label, labelStyle)
                    val labelX = (left + slot * index + slot / 2 - text.size.width / 2).coerceIn(left, size.width - text.size.width)
                    drawText(text, topLeft = Offset(labelX, plot + 4.dp.toPx()))
                }
            }
            average?.let {
                drawLine(avgColor, Offset(left, y(it)), Offset(size.width, y(it)), 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())))
            }
        }
        if (selected != null && tooltip != null && bars.isNotEmpty()) {
            // Above the bar, kept inside the chart.
            val slotDp = with(density) { ((width - axisWidth.toPx()) / bars.size).toDp() }
            val center = axisWidth + slotDp * selected + slotDp / 2
            val alignment = if (with(density) { center.toPx() } < width / 2) Alignment.TopStart else Alignment.TopEnd
            Box(Modifier.align(alignment).padding(start = if (alignment == Alignment.TopStart) maxOf(center - 30.dp, 0.dp) else 0.dp, end = if (alignment == Alignment.TopEnd) maxOf(with(density) { width.toDp() } - center - 30.dp, 0.dp) else 0.dp)) {
                tooltip(selected)
            }
        }
    }
}

private data class ComparisonSeries(
    val id: String,
    val name: String,
    val color: Color,
    val points: List<ComparisonPoint>,
    val cadence: HabitCadence = HabitCadence.day,
) {
    /** Weekly/monthly/yearly tasks (or very few values): a smooth line would suggest data that doesn't exist. */
    val isSparse get() = cadence != HabitCadence.day || points.size < 4
    val average get() = points.takeIf { it.isNotEmpty() }?.map { it.value }?.average()
}

/** Up to three selected items plus an optional dashed "overall" reference. */
@Composable
private fun ComparisonLineChart(
    series: List<ComparisonSeries>,
    reference: ComparisonSeries?,
    unit: CalUnit,
    yMin: Double,
    yMax: Double,
    yTicks: List<Double>,
    format: (Double) -> String,
    axisLabel: (Date) -> String,
    tooltipTitle: (Date) -> String,
    modifier: Modifier,
) {
    val theme = theme
    val accent = theme.accentColor
    val overallIsMain = series.isEmpty()
    val dates = (series.flatMap { s -> s.points.map { it.date } } + (reference?.points?.map { it.date } ?: emptyList())).distinct().sorted()
    var selected by remember(dates) { mutableStateOf<Date?>(null) }
    val measurer = rememberTextMeasurer()
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, color = theme.secondaryTextColor)
    val density = LocalDensity.current
    val axisWidth = with(density) { yTicks.maxOf { measurer.measure(format(it), labelStyle).size.width }.toDp() + 6.dp }
    val grid = theme.secondaryTextColor.copy(alpha = 0.2f)
    val secondary = theme.secondaryTextColor
    if (dates.isEmpty()) return
    val first = dates.first().epochSeconds.toDouble()
    val last = dates.last().epochSeconds.toDouble()
    fun xFraction(date: Date) = if (last > first) ((date.epochSeconds - first) / (last - first)).toFloat() else 0.5f

    Box(modifier) {
        Canvas(
            Modifier.fillMaxSize().pointerInput(dates) {
                fun pick(x: Float): Date {
                    val left = axisWidth.toPx()
                    val fraction = ((x - left) / (size.width - left)).coerceIn(0f, 1f)
                    return dates.minBy { abs(xFraction(it) - fraction) }
                }
                detectTapGestures { position ->
                    val date = pick(position.x)
                    selected = if (selected == date) null else date
                }
            },
        ) {
            val left = axisWidth.toPx()
            val axisHeight = 20.dp.toPx()
            val plot = size.height - axisHeight
            val plotWidth = size.width - left
            fun px(date: Date) = left + xFraction(date) * plotWidth
            fun py(value: Double) = (plot * (1 - (value - yMin) / (yMax - yMin))).toFloat()
            yTicks.forEach { tick ->
                drawLine(grid, Offset(left, py(tick)), Offset(size.width, py(tick)), 0.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())))
                val text = measurer.measure(format(tick), labelStyle)
                drawText(text, topLeft = Offset(0f, (py(tick) - text.size.height / 2).coerceIn(0f, plot - text.size.height / 2)))
            }
            // X labels: about six.
            val stride = max(1, ceil(dates.size / 6.0).toInt())
            var lastEnd = -1000f
            dates.forEachIndexed { index, date ->
                if (index % stride == 0) {
                    val text = measurer.measure(axisLabel(date), labelStyle)
                    val x = (px(date) - text.size.width / 2).coerceIn(left, size.width - text.size.width)
                    if (x > lastEnd + 4.dp.toPx()) {
                        drawText(text, topLeft = Offset(x, plot + 4.dp.toPx()))
                        lastEnd = x + text.size.width
                    }
                }
            }
            reference?.let { ref ->
                if (ref.points.isNotEmpty()) {
                    val path = monotonePath(ref.points.map { Offset(px(it.date), py(it.value)) })
                    if (overallIsMain) {
                        val area = Path().apply {
                            addPath(path)
                            lineTo(px(ref.points.last().date), plot)
                            lineTo(px(ref.points.first().date), plot)
                            close()
                        }
                        drawPath(area, Brush.verticalGradient(listOf(accent.copy(alpha = 0.25f), accent.copy(alpha = 0.02f)), 0f, plot))
                        drawPath(path, accent, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
                    } else {
                        drawPath(path, secondary.copy(alpha = 0.55f), style = Stroke(1.5.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
                    }
                }
            }
            series.forEach { item ->
                if (item.isSparse) {
                    item.average?.let { average ->
                        drawLine(item.color.copy(alpha = 0.45f), Offset(left, py(average)), Offset(size.width, py(average)), 1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx())))
                        val text = measurer.measure("Ø " + format(average), TextStyle(fontFamily = Inter, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = item.color))
                        drawText(text, topLeft = Offset(size.width - text.size.width, (py(average) - text.size.height - 2.dp.toPx()).coerceAtLeast(0f)))
                    }
                    if (item.points.size > 1) {
                        val path = Path()
                        item.points.forEachIndexed { index, point ->
                            if (index == 0) path.moveTo(px(point.date), py(point.value))
                            else {
                                path.lineTo(px(point.date), py(item.points[index - 1].value))
                                path.lineTo(px(point.date), py(point.value))
                            }
                        }
                        drawPath(path, item.color.copy(alpha = 0.6f), style = Stroke(1.5.dp.toPx()))
                    }
                    val radius = if (item.points.size <= 3) 5.5.dp.toPx() else 3.8.dp.toPx()
                    item.points.forEach { point ->
                        drawCircle(item.color, radius, Offset(px(point.date), py(point.value)))
                        if (item.points.size <= 6) {
                            val text = measurer.measure(format(point.value), TextStyle(fontFamily = Inter, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = item.color))
                            drawText(text, topLeft = Offset((px(point.date) - text.size.width / 2).coerceIn(0f, size.width - text.size.width), (py(point.value) - radius - text.size.height - 2.dp.toPx()).coerceAtLeast(0f)))
                        }
                    }
                } else {
                    val offsets = item.points.map { Offset(px(it.date), py(it.value)) }
                    drawPath(monotonePath(offsets), item.color, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
                    if (item.points.size <= 14) offsets.forEach { drawCircle(item.color, 2.5.dp.toPx(), it) }
                }
            }
            selected?.let { date -> drawLine(secondary.copy(alpha = 0.35f), Offset(px(date), 0f), Offset(px(date), plot), 1.dp.toPx()) }
        }
        selected?.let { date ->
            val lines = buildList {
                series.forEach { item -> item.points.firstOrNull { it.date == date }?.let { add(item.color to "${item.name}: ${format(it.value)}") } }
                reference?.points?.firstOrNull { it.date == date }?.let { add((if (overallIsMain) accent else secondary) to "${reference.name}: ${format(it.value)}") }
            }
            val alignment = if (xFraction(date) < 0.5f) Alignment.TopEnd else Alignment.TopStart
            ChartTooltip(tooltipTitle(date), lines, Modifier.align(alignment).padding(start = axisWidth))
        }
    }
}

/** Monotone cubic interpolation, as `.interpolationMethod(.monotone)`. */
private fun monotonePath(points: List<Offset>): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points[0].x, points[0].y)
    if (points.size == 1) return path
    val n = points.size
    val dx = FloatArray(n - 1) { points[it + 1].x - points[it].x }
    val slope = FloatArray(n - 1) { if (dx[it] != 0f) (points[it + 1].y - points[it].y) / dx[it] else 0f }
    val tangent = FloatArray(n)
    tangent[0] = slope[0]
    tangent[n - 1] = slope[n - 2]
    for (i in 1 until n - 1) tangent[i] = if (slope[i - 1] * slope[i] <= 0f) 0f else (slope[i - 1] + slope[i]) / 2
    for (i in 0 until n - 1) {
        if (slope[i] == 0f) {
            tangent[i] = 0f
            tangent[i + 1] = 0f
        } else {
            val a = tangent[i] / slope[i]
            val b = tangent[i + 1] / slope[i]
            val s = a * a + b * b
            if (s > 9f) {
                val t = 3f / kotlin.math.sqrt(s)
                tangent[i] = t * a * slope[i]
                tangent[i + 1] = t * b * slope[i]
            }
        }
    }
    for (i in 0 until n - 1) {
        val h = dx[i] / 3
        path.cubicTo(points[i].x + h, points[i].y + tangent[i] * h, points[i + 1].x - h, points[i + 1].y - tangent[i + 1] * h, points[i + 1].x, points[i + 1].y)
    }
    return path
}

private data class ComparisonItem(val id: String, val name: String, val icon: String)

/** Pick up to three items to compare; selected pills take the series color and move to the front. */
@Composable
private fun ComparisonChips(items: List<ComparisonItem>, selection: List<String>, onChange: (List<String>) -> Unit) {
    val theme = theme
    val scroll = rememberScrollState()
    val ordered = selection.mapNotNull { id -> items.firstOrNull { it.id == id } } + items.filter { it.id !in selection }
    LaunchedEffect(selection) { scroll.animateScrollTo(0) }

    @Composable
    fun chip(title: String, icon: String, selected: Boolean, color: Color, onClick: () -> Unit) {
        val foreground = if (selected) Color.White else theme.textColor
        Row(
            Modifier.height(28.dp).clip(CircleShape).background(if (selected) color else theme.textColor.copy(alpha = 0.06f)).tap(onClick = onClick).padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            SF(icon, foreground, 12.dp)
            T(title, Fonts.caption.medium, foreground, maxLines = 1)
        }
    }

    Row(Modifier.horizontalScroll(scroll).padding(vertical = 1.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        chip("stats_overall".localized, "sum", selection.isEmpty(), theme.accentColor) { onChange(emptyList()) }
        ordered.forEach { item ->
            key(item.id) {
                val index = selection.indexOf(item.id)
                chip(item.name, item.icon, index >= 0, if (index >= 0) comparisonColors[index % comparisonColors.size] else theme.accentColor) {
                    onChange(
                        if (index >= 0) selection - item.id
                        else (if (selection.size >= maxCompared) selection.drop(1) else selection) + item.id,
                    )
                }
            }
        }
    }
}

@Composable
private fun ComparisonLegend(series: List<ComparisonSeries>, trailing: (ComparisonSeries) -> String?) {
    val theme = theme
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        series.forEach { item ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.size(8.dp).background(item.color, CircleShape))
                T(item.name, Fonts.caption.medium, modifier = Modifier.weight(1f, fill = false), maxLines = 1)
                if (item.cadence != HabitCadence.day) {
                    T(item.cadence.localizedName, systemFont(10, FontWeight.SemiBold), item.color, maxLines = 1, modifier = Modifier.clip(CircleShape).background(item.color.copy(alpha = 0.12f)).padding(horizontal = 6.dp, vertical = 2.dp))
                }
                Spacer(Modifier.weight(1f))
                if (item.isSparse) T(if (item.points.size == 1) "stats_values_one".localized else "stats_values_count".localized(item.points.size), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                trailing(item)?.let { T(it, Fonts.caption.bold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.widthIn(min = 40.dp)) }
            }
        }
        if (series.any { it.isSparse }) T("stats_sparse_note".localized, Fonts.caption2, theme.secondaryTextColor)
    }
}

// MARK: - Overview

@Composable
private fun OverviewStatsTab() {
    val theme = theme
    val data = vm.data
    val overview = data.overview
    TabColumn {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(
                    "${overview.completed}", "stats_completed".localized, "checkmark.circle.fill", theme.accentColor, Modifier.weight(1f).fillMaxHeight(),
                    if (overview.pending > 0) "stats_of_scheduled_pending".localized(overview.total, overview.pending) else "stats_of_scheduled".localized(overview.total),
                )
                StatTile(StatsFormat.percent(overview.rate), "stats_completion_rate".localized, "chart.bar.fill", Color.SysBlue, Modifier.weight(1f).fillMaxHeight(), "stats_active_days_of".localized(overview.activeDays, overview.daysInPeriod))
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(
                    StatsFormat.hours(overview.trackedHours), "stats_time_spent".localized, "clock.fill", Color.SysPurple, Modifier.weight(1f).fillMaxHeight(),
                    if (overview.daysInPeriod > 0) "stats_per_day_avg".localized(StatsFormat.hours(overview.trackedHours / overview.daysInPeriod)) else null,
                )
                StatTile("${data.currentStreak}", "stats_active_streak".localized, "flame.fill", Color.SysOrange, Modifier.weight(1f).fillMaxHeight(), "stats_record_days".localized(data.bestStreak))
            }
        }
        TimeDistributionChartCard()
        CompletionChartCard()
        MoodTrendCard()
    }
}

private data class DonutSliceData(val id: String, val name: String, val color: Color, val hours: Double, val previousHours: Double?, val icon: String, val stats: List<CategoryStat>)

private fun displayCategoryName(name: String) = if (name == "Uncategorized") "uncategorized".localized else name

@Composable
private fun TimeDistributionChartCard() {
    val theme = theme
    val presenter = LocalPresenter.current
    val data = vm.data
    val other = theme.secondaryTextColor.copy(alpha = 0.4f)
    val sorted = data.categoryStats.sortedByDescending { it.hours }
    val previous = data.previousCategoryHours
    val hasPrevious = data.hasPreviousPeriod
    val slices = sorted.take(5).map { stat ->
        DonutSliceData(stat.name, displayCategoryName(stat.name), colorFromHex(stat.color), stat.hours, if (hasPrevious) previous[stat.name] ?: 0.0 else null, stat.icon ?: if (stat.categoryId == null) "questionmark.circle" else "tag.fill", listOf(stat))
    } + sorted.drop(5).takeIf { it.isNotEmpty() }?.let { rest ->
        listOf(DonutSliceData("__other", "stats_other".localized, other, rest.sumOf { it.hours }, if (hasPrevious) rest.sumOf { previous[it.name] ?: 0.0 } else null, "ellipsis.circle", rest))
    }.orEmpty()
    val total = slices.sumOf { it.hours }
    var pinnedId by remember(data.range) { mutableStateOf<String?>(null) }
    val selected = slices.firstOrNull { it.id == pinnedId }

    fun open(slice: DonutSliceData) = presenter.sheet { NavigationStack { CategoryDetailSheet(slice, total) } }

    StatsCard(
        "time_distribution".localized,
        if (slices.isEmpty()) null else "stats_tap_category_hint".localized,
        trailing = if (slices.isNotEmpty() && hasPrevious) ({ DeltaBadge(total, previous.values.sum()) }) else null,
    ) {
        if (slices.isEmpty()) {
            StatsEmptyState("clock", "stats_no_time_title".localized, "stats_no_time_message".localized)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                DonutChart(
                    slices.map { PieSlice(it.hours.toFloat(), it.color) },
                    Modifier.size(170.dp),
                    selectedIndex = slices.indexOfFirst { it.id == pinnedId }.takeIf { it >= 0 },
                    onSelect = { index ->
                        val hit = index?.let { slices.getOrNull(it) }
                        when {
                            hit == null -> if (pinnedId != null) selected?.let { open(it) }
                            hit.id == pinnedId -> open(hit)
                            else -> {
                                Haptics.light()
                                pinnedId = hit.id
                            }
                        }
                    },
                ) {
                    Column(Modifier.widthIn(max = 96.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        selected?.let { SF(it.icon, it.color, 15.dp) }
                        ShrinkText(StatsFormat.hours(selected?.hours ?: total), Fonts.title3.bold.monospacedDigit, theme.textColor)
                        ShrinkText(selected?.name ?: "stats_total".localized, Fonts.caption2, theme.secondaryTextColor, minScale = 0.75f)
                        if (selected != null) {
                            T(StatsFormat.percent(if (total > 0) selected.hours / total else 0.0), Fonts.caption2.semibold.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                            Row(Modifier.padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                                T("stats_details".localized, systemFont(10, FontWeight.SemiBold), theme.accentColor, maxLines = 1)
                                SF("chevron.right", theme.accentColor, 10.dp)
                            }
                        }
                    }
                }
                Column {
                    slices.forEachIndexed { index, slice ->
                        key(slice.id) {
                            val fraction = if (total > 0) slice.hours / total else 0.0
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .alpha(if (selected == null || selected.id == slice.id) 1f else 0.4f)
                                    .tap { open(slice) }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                CategoryIconTile(slice.icon, slice.color, 28.dp)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                    Row {
                                        T(slice.name, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                                        T(StatsFormat.hours(slice.hours), Fonts.subheadline.semibold.monospacedDigit, maxLines = 1)
                                    }
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        BoxWithConstraints(Modifier.weight(1f).height(5.dp).clip(CircleShape).background(slice.color.copy(alpha = 0.15f))) {
                                            Box(Modifier.width(maxOf(4.dp, maxWidth * fraction.toFloat())).fillMaxHeight().clip(CircleShape).background(slice.color))
                                        }
                                        T(StatsFormat.percent(fraction), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, TextAlign.End, Modifier.widthIn(min = 32.dp), maxLines = 1)
                                        if (slice.previousHours != null && (pinnedId == null || pinnedId == slice.id)) {
                                            Box(Modifier.widthIn(min = 44.dp), contentAlignment = Alignment.CenterEnd) { DeltaBadge(slice.hours, slice.previousHours, compact = true) }
                                        }
                                    }
                                }
                                SF("chevron.right", theme.secondaryTextColor.copy(alpha = 0.5f), 12.dp)
                            }
                        }
                        if (index < slices.lastIndex) Box(Modifier.padding(start = 38.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                    }
                }
            }
        }
    }
}

/** "+12%" / "−8%" versus the previous period of the same length. */
@Composable
private fun DeltaBadge(current: Double, previous: Double, compact: Boolean = false) {
    val theme = theme
    if (previous <= 0) {
        if (current > 0) T("stats_new".localized, Fonts.caption2.semibold, Color.SysBlue, maxLines = 1)
        return
    }
    val rounded = Math.round((current - previous) / previous * 100).toInt()
    val color = if (rounded > 0) Color.SysGreen else if (rounded < 0) Color.SysOrange else theme.secondaryTextColor
    Row(
        Modifier
            .then(if (compact) Modifier else Modifier.clip(CircleShape).background(color.copy(alpha = 0.12f)).padding(horizontal = 7.dp, vertical = 3.dp)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        SF(if (rounded > 0) "arrow.up" else if (rounded < 0) "arrow.down" else "equal", color, if (compact) 10.dp else 12.dp)
        T(if (abs(rounded) > 999) ">999%" else "${abs(rounded)}%", (if (compact) Fonts.caption2 else Fonts.caption).semibold.monospacedDigit, color, maxLines = 1)
    }
}

@Composable
private fun CategoryDetailSheet(slice: DonutSliceData, totalHours: Double) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val navigator = LocalNavigator.current
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(if (slice.stats.size == 1) "" else "stats_other".localized, trailing = { BarButton("done".localized, bold = true, onClick = dismiss) })
        if (slice.stats.size == 1) {
            CategoryDetailContent(slice.stats[0], totalHours, Modifier.weight(1f))
        } else {
            FormPage(Modifier.weight(1f)) {
                FormSection {
                    slice.stats.forEachIndexed { index, stat ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .tap {
                                    navigator?.push {
                                        Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
                                            NavBar(displayCategoryName(stat.name))
                                            CategoryDetailContent(stat, totalHours, Modifier.weight(1f))
                                        }
                                    }
                                }
                                .padding(horizontal = 16.dp, vertical = 9.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            CategoryIconTile(stat.icon ?: "tag.fill", colorFromHex(stat.color), 30.dp)
                            T(displayCategoryName(stat.name), Fonts.body, modifier = Modifier.weight(1f))
                            T(StatsFormat.hours(stat.hours), Fonts.body.monospacedDigit, Color.Secondary, maxLines = 1)
                            SF("chevron.right", Color.Tertiary, 16.dp)
                        }
                        if (index < slice.stats.lastIndex) RowDivider(56.dp)
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryDetailContent(stat: CategoryStat, totalHours: Double, modifier: Modifier) {
    val theme = theme
    val color = colorFromHex(stat.color)
    val data = vm.data
    val detail = remember(stat, data) { stat.categoryId?.let { vm.categoryDetail(it) } }
    val unit = vm.bucketUnit(data.range, false)
    Column(modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            CategoryIconTile(stat.icon ?: "tag.fill", color, 56.dp)
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                T(displayCategoryName(stat.name), Fonts.title3.bold)
                T("stats_share_of_time".localized(StatsFormat.percent(if (totalHours > 0) stat.hours / totalHours else 0.0)), Fonts.subheadline, theme.secondaryTextColor)
            }
        }
        if (detail == null) {
            StatsCard("stats_no_data_title".localized) {
                StatsEmptyState("tag", StatsFormat.hours(stat.hours), "stats_uncategorized_detail".localized)
            }
        } else {
            val days = max(1, data.overview.daysInPeriod)
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(
                    StatsFormat.hours(detail.hours), "stats_time_spent".localized, "clock.fill", color, Modifier.weight(1f).fillMaxHeight(),
                    detail.previousHours?.let { if (it > 0) "stats_previous_period".localized(StatsFormat.hours(it)) else "stats_new".localized },
                )
                StatTile(StatsFormat.hours(detail.hours / days), "stats_daily_average".localized, "calendar", Color.SysBlue, Modifier.weight(1f).fillMaxHeight())
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("${detail.completions}", "stats_completed".localized, "checkmark.circle.fill", Color.SysGreen, Modifier.weight(1f).fillMaxHeight(), "stats_tasks_count".localized(detail.tasks.size))
                StatTile(StatsFormat.hours(detail.trackedSessionHours), "stats_tracked_sessions".localized, "stopwatch.fill", Color.SysPurple, Modifier.weight(1f).fillMaxHeight())
            }
            val average = if (detail.buckets.isEmpty()) 0.0 else detail.buckets.sumOf { it.second } / detail.buckets.size
            var selected by remember { mutableStateOf<Int?>(null) }
            StatsCard("stats_trend".localized, "stats_average_hours".localized(StatsFormat.hours(average))) {
                val most = detail.buckets.maxOfOrNull { it.second }?.takeIf { it > 0 } ?: 1.0
                val tickStep = max(1.0, ceil(most / 3))
                val stride = max(1, ceil(detail.buckets.size / 6.0).toInt())
                StatsBars(
                    detail.buckets.map { StatBar(listOf(BarSegment(it.second, color))) },
                    detail.buckets.mapIndexed { index, bucket -> if (index % stride == 0) bucketLabel(bucket.first, unit, data.range) else null },
                    Modifier.fillMaxWidth().height(170.dp),
                    yMax = ceil(most / tickStep) * tickStep,
                    average = average,
                    yTicks = generateSequence(0.0) { it + tickStep }.takeWhile { it <= ceil(most / tickStep) * tickStep }.toList(),
                    yFormat = { "${it.toInt()}h" },
                    selected = selected,
                    onSelect = { selected = it },
                    tooltip = { index -> ChartTooltip(bucketTitle(detail.buckets[index].first, unit), listOf(color to StatsFormat.hours(detail.buckets[index].second))) },
                )
            }
            StatsCard("stats_tasks_in_category".localized) {
                if (detail.tasks.isEmpty()) {
                    StatsEmptyState("checklist", "stats_no_data_title".localized, "stats_no_data_period".localized)
                } else {
                    val top = detail.tasks.first().hours
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        detail.tasks.take(10).forEach { task ->
                            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Box(Modifier.width(18.dp), contentAlignment = Alignment.Center) { SF(task.icon, color, 14.dp) }
                                    T(task.name, Fonts.subheadline, modifier = Modifier.weight(1f))
                                    T("stats_times".localized(task.completions), Fonts.caption2.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                                    T(StatsFormat.hours(task.hours), Fonts.subheadline.semibold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.widthIn(min = 56.dp))
                                }
                                BoxWithConstraints(Modifier.fillMaxWidth().height(5.dp)) {
                                    Box(Modifier.width(maxOf(4.dp, maxWidth * (if (top > 0) task.hours / top else 0.0).toFloat())).fillMaxHeight().clip(CircleShape).background(color.copy(alpha = 0.8f)))
                                }
                            }
                        }
                    }
                }
            }
            val best = detail.weekdayHours.maxByOrNull { it.second }?.takeIf { it.second > 0 }
            StatsCard("stats_by_weekday".localized, best?.let { "stats_most_time_on".localized(weekdaySymbol(it.first)) }) {
                StatsBars(
                    detail.weekdayHours.map { (weekday, hours) -> StatBar(listOf(BarSegment(hours, if (weekday == best?.first) color else color.copy(alpha = 0.4f)))) },
                    detail.weekdayHours.map { shortWeekdaySymbol(it.first) },
                    Modifier.fillMaxWidth().height(110.dp),
                    corner = 4.dp,
                )
            }
        }
    }
}

@Composable
private fun CompletionChartCard() {
    val theme = theme
    val data = vm.data
    val buckets = data.completionBuckets
    val unit = vm.bucketUnit(data.range, false)
    val completedColor = theme.accentColor
    val missedColor = theme.secondaryTextColor.copy(alpha = 0.22f)
    val average = if (buckets.isEmpty()) 0.0 else buckets.sumOf { it.completed }.toDouble() / buckets.size
    var selected by remember(data.range) { mutableStateOf<Int?>(null) }
    val perName = when (unit) {
        CalUnit.day -> "stats_per_day"
        CalUnit.week -> "stats_per_week"
        else -> "stats_per_month"
    }.localized
    StatsCard("task_completion_rate".localized, "stats_average_per_bucket".localized(if (average >= 10) Math.round(average).toString() else one(average), perName)) {
        if (buckets.all { it.total == 0 }) {
            StatsEmptyState("checklist", "stats_no_tasks_title".localized, "stats_no_tasks_message".localized)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val most = buckets.maxOf { it.completed + it.missed + it.pending }.coerceAtLeast(1)
                val step = max(1, ceil(most / 3.0).toInt())
                val top = ceil(most.toDouble() / step).toInt() * step
                val labels = buckets.mapIndexed { index, bucket ->
                    val show = when {
                        unit == CalUnit.day && data.range == TimeRange.week -> true
                        unit == CalUnit.day -> index % 7 == 0
                        data.range == TimeRange.allTime -> index % max(1, ceil(buckets.size / 6.0).toInt()) == 0
                        else -> index % 2 == 0
                    }
                    if (show) bucketLabel(bucket.start, unit, data.range) else null
                }
                StatsBars(
                    buckets.map { StatBar(listOf(BarSegment(it.completed.toDouble(), completedColor), BarSegment(it.missed.toDouble(), missedColor), BarSegment(it.pending.toDouble(), completedColor.copy(alpha = 0.3f)))) },
                    labels,
                    Modifier.fillMaxWidth().height(180.dp),
                    yMax = top.toDouble(),
                    average = average,
                    yTicks = (0..top step step).map { it.toDouble() },
                    selected = selected,
                    onSelect = { selected = it },
                    tooltip = { index ->
                        val bucket = buckets[index]
                        val title = when (unit) {
                            CalUnit.day -> bucket.start.skeleton("EEEEdMMM")
                            CalUnit.week -> "${bucket.start.skeleton("dMMM")} – ${bucket.end.skeleton("dMMM")}"
                            else -> bucket.start.skeleton("MMMMy")
                        }
                        ChartTooltip(
                            title,
                            listOf(completedColor to "${bucket.completed}/${bucket.total} · ${StatsFormat.percent(bucket.rate)}") +
                                if (bucket.pending > 0) listOf(completedColor.copy(alpha = 0.3f) to "stats_todo_count".localized(bucket.pending)) else emptyList(),
                        )
                    },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    LegendDot(completedColor, "completed".localized)
                    LegendDot(missedColor, "stats_legend_missed".localized)
                    if (buckets.any { it.pending > 0 }) LegendDot(completedColor.copy(alpha = 0.3f), "stats_legend_todo_today".localized)
                }
            }
        }
    }
}

// MARK: - Mood

private data class MoodBucket(val start: Date, val average: Double, val minScore: Int, val maxScore: Int, val count: Int)

private fun moodFor(score: Double): MoodType = MoodType.entries.firstOrNull { it.score == Math.round(score).toInt().coerceIn(1, 7) } ?: MoodType.neutral

@Composable
private fun MoodTrendCard() {
    val theme = theme
    val presenter = LocalPresenter.current
    val data = vm.data
    val range = data.range
    val end = now().startOfDay()
    val moods = MoodManager.entries
    val start = when (range) {
        TimeRange.allTime -> moods.keys.minOrNull() ?: end
        TimeRange.today, TimeRange.week -> end.addingDays(-6)
        else -> range.dateRangeStart.startOfDay()
    }
    val entries = MoodManager.entriesIn(start, end)
    val daysInRange = java.time.temporal.ChronoUnit.DAYS.between(start.z(), end.z()).toInt() + 1
    val unit = when (range) {
        TimeRange.today, TimeRange.week, TimeRange.month -> CalUnit.day
        TimeRange.year -> CalUnit.week
        TimeRange.allTime -> if (daysInRange > 400) CalUnit.month else CalUnit.week
    }
    val buckets = entries.groupBy { unit.start(it.first) }.map { (bucketStart, items) ->
        val scores = items.map { it.second.score }
        MoodBucket(bucketStart, scores.average(), scores.min(), scores.max(), scores.size)
    }.sortedBy { it.start }
    val add: @Composable () -> Unit = {
        Row(
            Modifier.height(28.dp).clip(CircleShape).background(theme.accentColor).pressable { presenter.sheet(SheetDetent.medium) { MoodSelectionView(now()) } }.padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            SF("plus", Color.White, 14.dp)
            T("add".localized, Fonts.caption.semibold, Color.White, maxLines = 1)
        }
    }
    StatsCard("mood_trend".localized, trailing = add) {
        if (entries.isEmpty()) {
            StatsEmptyState("face.smiling", "stats_no_mood_title".localized, "add_mood_to_see_trend".localized)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                val average = entries.map { it.second.score }.average()
                val type = moodFor(average)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    T(type.emoji, systemFont(34), maxLines = 1)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        T(type.localizedName.replaceFirstChar { it.titlecase(appLocale) }, Fonts.headline)
                        T("stats_mood_average".localized(one(average)), Fonts.caption, theme.secondaryTextColor)
                    }
                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        T("${entries.size}/$daysInRange", Fonts.headline.monospacedDigit, maxLines = 1)
                        T("stats_days_logged".localized, Fonts.caption, theme.secondaryTextColor, maxLines = 1)
                    }
                }
                MoodChart(buckets, unit, range, Modifier.fillMaxWidth().height(180.dp))
                // Distribution
                val counts = MoodType.entries.map { it to entries.count { entry -> entry.second == it } }
                val total = max(1, entries.size)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        counts.filter { it.second > 0 }.forEach { (mood, count) ->
                            Box(Modifier.weight(count.toFloat() / total).fillMaxHeight().background(colorFromHex(mood.colorHex)))
                        }
                    }
                    Row {
                        counts.forEach { (mood, count) ->
                            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                T(mood.emoji, systemFont(15), modifier = Modifier.alpha(if (count == 0) 0.3f else 1f), maxLines = 1)
                                T(if (count == 0) "–" else StatsFormat.percent(count.toDouble() / total), systemFont(10, FontWeight.Medium).monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                            }
                        }
                    }
                }
                // Completion rate on good-mood days vs the other days, when both groups have enough data.
                var goodCompleted = 0
                var goodTotal = 0
                var goodDays = 0
                var otherCompleted = 0
                var otherTotal = 0
                var otherDays = 0
                entries.forEach { (date, mood) ->
                    val day = data.dailyCompletion[date.startOfDay()]
                    if (day != null && day.total > 0) {
                        if (mood.score >= 5) {
                            goodCompleted += day.completed
                            goodTotal += day.total
                            goodDays++
                        } else {
                            otherCompleted += day.completed
                            otherTotal += day.total
                            otherDays++
                        }
                    }
                }
                if (goodDays >= 3 && otherDays >= 3) {
                    val good = goodCompleted.toDouble() / goodTotal
                    val other = otherCompleted.toDouble() / otherTotal
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.SysYellow.copy(alpha = 0.1f)).padding(10.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        SF("lightbulb.fill", Color.SysYellow, 15.dp)
                        // Below 5 points the difference is noise: say so instead of implying a link.
                        T(
                            if (abs(good - other) < 0.05) "stats_mood_insight_none".localized(StatsFormat.percent(good))
                            else "stats_mood_insight".localized(StatsFormat.percent(good), StatsFormat.percent(other)),
                            Fonts.caption,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MoodChart(buckets: List<MoodBucket>, unit: CalUnit, range: TimeRange, modifier: Modifier) {
    val theme = theme
    val accent = theme.accentColor
    val measurer = rememberTextMeasurer()
    val labelStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, color = theme.secondaryTextColor)
    val emojiStyle = TextStyle(fontSize = 13.sp)
    val secondary = theme.secondaryTextColor
    val daily = unit == CalUnit.day
    var selected by remember(buckets) { mutableStateOf<Date?>(null) }
    val first = buckets.first().start.epochSeconds.toDouble()
    val last = buckets.last().start.epochSeconds.toDouble()
    fun fraction(date: Date) = if (last > first) ((date.epochSeconds - first) / (last - first)).toFloat() else 0.5f
    val pointColors = buckets.associate { it.start to colorFromHex(moodFor(it.average).colorHex) }
    Box(modifier) {
        Canvas(
            Modifier.fillMaxSize().pointerInput(buckets) {
                detectTapGestures { position ->
                    val left = 24.dp.toPx()
                    val value = ((position.x - left) / (size.width - left - 8.dp.toPx())).coerceIn(0f, 1f)
                    val date = buckets.minBy { abs(fraction(it.start) - value) }.start
                    selected = if (selected == date) null else date
                }
            },
        ) {
            val left = 24.dp.toPx()
            val axisHeight = 20.dp.toPx()
            val plot = size.height - axisHeight
            val plotWidth = size.width - left - 8.dp.toPx()
            fun px(date: Date) = left + fraction(date) * plotWidth
            fun py(score: Double) = (plot * (1 - (score - 0.5) / 7.0)).toFloat()
            listOf(1.0, 4.0, 7.0).forEach { score ->
                val isNeutral = score == 4.0
                drawLine(
                    secondary.copy(alpha = if (isNeutral) 0.25f else 0.15f),
                    Offset(left, py(score)), Offset(size.width, py(score)),
                    (if (isNeutral) 1.dp else 0.5.dp).toPx(),
                    pathEffect = PathEffect.dashPathEffect(if (isNeutral) floatArrayOf(4.dp.toPx(), 3.dp.toPx()) else floatArrayOf(3.dp.toPx(), 3.dp.toPx())),
                )
                val text = measurer.measure(moodFor(score).emoji, emojiStyle)
                drawText(text, topLeft = Offset(0f, py(score) - text.size.height / 2))
            }
            if (!daily && buckets.size > 1) {
                val band = Path().apply {
                    buckets.forEachIndexed { index, bucket -> if (index == 0) moveTo(px(bucket.start), py(bucket.maxScore.toDouble())) else lineTo(px(bucket.start), py(bucket.maxScore.toDouble())) }
                    buckets.asReversed().forEach { lineTo(px(it.start), py(it.minScore.toDouble())) }
                    close()
                }
                drawPath(band, accent.copy(alpha = 0.15f))
            }
            val offsets = buckets.map { Offset(px(it.start), py(it.average)) }
            drawPath(monotonePath(offsets), if (daily) accent.copy(alpha = 0.4f) else accent, style = Stroke((if (daily) 1.5.dp else 2.5.dp).toPx(), cap = StrokeCap.Round))
            if (daily) {
                val radius = (if (buckets.size > 14) 2.8.dp else 4.4.dp).toPx()
                buckets.forEach { drawCircle(pointColors[it.start] ?: accent, radius, Offset(px(it.start), py(it.average))) }
            }
            val stride = max(1, ceil(buckets.size / 6.0).toInt())
            var lastEnd = -1000f
            buckets.forEachIndexed { index, bucket ->
                if (index % stride == 0) {
                    val label = when (range) {
                        TimeRange.today, TimeRange.week -> bucket.start.skeleton("EEE")
                        TimeRange.month -> bucket.start.skeleton("dMMM")
                        TimeRange.year -> bucket.start.skeleton("MMM")
                        TimeRange.allTime -> bucket.start.skeleton("MMMyy")
                    }
                    val text = measurer.measure(label, labelStyle)
                    val x = (px(bucket.start) - text.size.width / 2).coerceIn(left, size.width - text.size.width)
                    if (x > lastEnd + 4.dp.toPx()) {
                        drawText(text, topLeft = Offset(x, plot + 4.dp.toPx()))
                        lastEnd = x + text.size.width
                    }
                }
            }
            selected?.let { date -> drawLine(secondary.copy(alpha = 0.35f), Offset(px(date), 0f), Offset(px(date), plot), 1.dp.toPx()) }
        }
        selected?.let { date ->
            val bucket = buckets.first { it.start == date }
            val type = moodFor(bucket.average)
            val lines = if (daily) {
                listOf(colorFromHex(type.colorHex) to "${type.emoji} ${type.localizedName.replaceFirstChar { it.titlecase(appLocale) }}")
            } else {
                listOf(
                    colorFromHex(type.colorHex) to "${type.emoji} " + "stats_mood_average".localized(one(bucket.average)),
                    theme.secondaryTextColor to "stats_mood_days".localized(bucket.count),
                )
            }
            ChartTooltip(bucketTitle(date, unit), lines, Modifier.align(if (fraction(date) < 0.5f) Alignment.TopEnd else Alignment.TopStart).padding(start = 24.dp))
        }
    }
}

// MARK: - Streaks

@Composable
private fun StreaksStatsTab() {
    val theme = theme
    val presenter = LocalPresenter.current
    var sortRaw by appStorage("statsHabitSort", "currentStreak")
    val sorts = listOf("currentStreak" to "stats_sort_current", "bestStreak" to "stats_sort_best", "rate" to "stats_sort_rate", "name" to "stats_sort_name")
    val list = vm.data.habitSummaries
    val habits = when (sortRaw) {
        "bestStreak" -> list.sortedWith(compareByDescending<HabitSummary> { it.bestStreak }.thenByDescending { it.currentStreak })
        "rate" -> list.sortedByDescending { it.periodRate }
        "name" -> list.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name })
        else -> list.sortedWith(compareByDescending<HabitSummary> { it.currentStreak }.thenByDescending { it.bestStreak })
    }
    TabColumn(10) {
        if (habits.isEmpty()) {
            StatsCard("streaks".localized) { StatsEmptyState("flame", "stats_no_habits_title".localized, "stats_no_habits_message".localized) }
        } else {
            Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                T("stats_habits_count".localized(habits.size), Fonts.footnote.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                IOSMenu(sorts.map { (raw, key) -> MenuItem(key.localized, checked = sortRaw == raw) { sortRaw = raw } }) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        SF("arrow.up.arrow.down", theme.accentColor, 14.dp)
                        T((sorts.firstOrNull { it.first == sortRaw }?.second ?: "stats_sort_current").localized, Fonts.footnote.semibold, theme.accentColor, maxLines = 1)
                    }
                }
            }
            habits.forEach { habit ->
                key(habit.taskId) {
                    HabitRow(habit) { presenter.sheet { HabitDetailView(habit) } }
                }
            }
        }
    }
}

@Composable
private fun HabitRow(habit: HabitSummary, onClick: () -> Unit) {
    val theme = theme
    val color = colorFromHex(habit.color)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(theme.surfaceColor).pressable(onClick = onClick).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CategoryIconTile(habit.icon, color, 34.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                T(habit.name, Fonts.subheadline.semibold)
                val caption = listOfNotNull(habit.categoryName, if (habit.cadence == HabitCadence.day) null else habit.cadence.localizedName).joinToString(" · ")
                if (caption.isNotEmpty()) T(caption, Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                HabitMetric("flame.fill", Color.SysOrange, "${habit.currentStreak}")
                HabitMetric("trophy.fill", Color.SysYellow, "${habit.bestStreak}")
                T(StatsFormat.percent(habit.periodRate), Fonts.subheadline.bold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.widthIn(min = 40.dp))
            }
            SF("chevron.right", theme.secondaryTextColor.copy(alpha = 0.5f), 12.dp)
        }
        HabitCadenceHeatmap(habit, compact = true)
    }
}

@Composable
private fun HabitMetric(icon: String, tint: Color, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        SF(icon, tint, 13.dp)
        T(value, Fonts.subheadline.semibold.monospacedDigit, maxLines = 1)
    }
}

@Composable
private fun HabitDetailView(habit: HabitSummary) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val color = colorFromHex(habit.color)
    val data = vm.data
    val range = data.range
    val days = if (habit.cadence != HabitCadence.day) {
        habit.periods.filter { habit.cadence.unit.add(it.date, 1) > data.periodStart && it.date <= data.periodEnd }
    } else habit.days.filter { it.date >= data.periodStart && it.date <= data.periodEnd }
    val bucketUnit = when (habit.cadence) {
        HabitCadence.week -> CalUnit.month
        HabitCadence.month, HabitCadence.year -> CalUnit.year
        HabitCadence.day -> if (range == TimeRange.today || range == TimeRange.week || range == TimeRange.month) CalUnit.week else CalUnit.month
    }
    val resolved = days.filter { it.state == HabitDayState.done || it.state == HabitDayState.missed }
    val buckets = resolved.groupBy { bucketUnit.start(it.date) }.map { (start, items) -> Triple(start, items.count { it.state == HabitDayState.done }, items.size) }.sortedBy { it.first }
    val weekdays = weekdayOrder().mapNotNull { weekday ->
        val items = resolved.filter { it.date.weekday == weekday }
        if (items.isEmpty()) null else weekday to items.count { it.state == HabitDayState.done }.toDouble() / items.size
    }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("", trailing = { BarButton("done".localized, bold = true, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                CategoryIconTile(habit.icon, color, 56.dp)
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    T(habit.name, Fonts.title3.bold)
                    habit.categoryName?.let { T(it, Fonts.subheadline, theme.secondaryTextColor) }
                }
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("${habit.currentStreak}", "current".localized, "flame.fill", Color.SysOrange, Modifier.weight(1f).fillMaxHeight())
                StatTile("${habit.bestStreak}", "best".localized, "trophy.fill", Color.SysYellow, Modifier.weight(1f).fillMaxHeight())
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(StatsFormat.percent(habit.periodRate), "stats_completion_rate".localized, "chart.bar.fill", color, Modifier.weight(1f).fillMaxHeight())
                StatTile("${habit.periodCompleted}/${habit.periodTotal}", "completed".localized, "checkmark.circle.fill", Color.SysGreen, Modifier.weight(1f).fillMaxHeight())
            }
            StatsCard("stats_calendar".localized) {
                HabitCadenceHeatmap(habit)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    LegendDot(color, "stats_legend_done".localized)
                    LegendDot(color.copy(alpha = 0.2f), "stats_legend_missed".localized)
                    if (habit.cadence == HabitCadence.day) LegendDot(theme.secondaryTextColor.copy(alpha = 0.08f), "stats_legend_not_scheduled".localized)
                }
            }
            if (habit.cadence != HabitCadence.year) {
                StatsCard(
                    "stats_trend".localized,
                    when (bucketUnit) {
                        CalUnit.year -> "stats_rate_per_year"
                        CalUnit.month -> "stats_rate_per_month"
                        else -> "stats_rate_per_week"
                    }.localized,
                ) {
                    if (buckets.isEmpty()) {
                        StatsEmptyState("chart.bar", "stats_no_data_title".localized, "stats_no_data_period".localized)
                    } else {
                        val stride = max(1, ceil(buckets.size / 6.0).toInt())
                        StatsBars(
                            buckets.map { StatBar(listOf(BarSegment(it.second.toDouble() / it.third * 100, color))) },
                            buckets.mapIndexed { index, bucket ->
                                if (index % stride != 0) null else when (bucketUnit) {
                                    CalUnit.year -> bucket.first.skeleton("y")
                                    CalUnit.month -> bucket.first.skeleton("MMM")
                                    else -> bucket.first.skeleton("dMMM")
                                }
                            },
                            Modifier.fillMaxWidth().height(150.dp),
                            yMax = 100.0,
                            yTicks = listOf(0.0, 50.0, 100.0),
                            yFormat = { "${it.toInt()}%" },
                        )
                    }
                }
            }
            if (habit.cadence == HabitCadence.day) {
                StatsCard("stats_by_weekday".localized) {
                    if (weekdays.isEmpty()) {
                        StatsEmptyState("calendar", "stats_no_data_title".localized, "stats_no_data_period".localized)
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            weekdays.forEach { (weekday, rate) ->
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    T(shortWeekdaySymbol(weekday), Fonts.caption.medium, theme.secondaryTextColor, modifier = Modifier.width(34.dp), maxLines = 1)
                                    BoxWithConstraints(Modifier.weight(1f).height(8.dp).clip(CircleShape).background(color.copy(alpha = 0.15f))) {
                                        Box(Modifier.width(maxOf(6.dp, maxWidth * rate.toFloat())).fillMaxHeight().clip(CircleShape).background(color))
                                    }
                                    T(StatsFormat.percent(rate), Fonts.caption.semibold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.width(40.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Heatmaps

@Composable
private fun HabitCadenceHeatmap(habit: HabitSummary, compact: Boolean = false) {
    val color = colorFromHex(habit.color)
    when (habit.cadence) {
        HabitCadence.day -> HabitHeatmap(habit.days, color, if (compact) 9.dp else 14.dp, if (compact) 2.dp else 3.dp, !compact, !compact)
        else -> HabitPeriodGrid(habit.periods, habit.cadence, color, compact)
    }
}

/** Calendar heatmap with fixed-size cells: as many weeks as fit (compact) or all history scrolling from today. */
@Composable
private fun HabitHeatmap(days: List<HabitDay>, color: Color, cell: Dp, spacing: Dp, showsLabels: Boolean, scrollable: Boolean) {
    val theme = theme
    val labelHeight = if (showsLabels) 16.dp else 0.dp
    val weekdayWidth = if (showsLabels) 26.dp else 0.dp
    val gridHeight = cell * 7 + spacing * 6
    val offColor = theme.secondaryTextColor.copy(alpha = 0.08f)
    val missedColor = color.copy(alpha = 0.2f)
    val measurer = rememberTextMeasurer()
    val monthStyle = TextStyle(fontFamily = Inter, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = theme.secondaryTextColor)

    val columns: List<List<HabitDay?>> = remember(days) {
        if (days.isEmpty()) emptyList() else {
            val leading = (days.first().date.weekday - firstWeekdayNumber + 7) % 7
            val slots = ArrayList<HabitDay?>()
            repeat(leading) { slots += null }
            slots += days
            repeat((7 - slots.size % 7) % 7) { slots += null }
            slots.chunked(7)
        }
    }
    BoxWithConstraints(Modifier.fillMaxWidth().height(labelHeight + gridHeight)) {
        val fitting = max(1, ((maxWidth - weekdayWidth + spacing) / (cell + spacing)).toInt())
        val base = if (scrollable) columns else columns.takeLast(fitting)
        val shown: List<List<HabitDay?>> = List(max(0, fitting - base.size)) { List(7) { null } } + base
        val width = (cell + spacing) * shown.size - spacing
        Row {
            if (showsLabels) {
                Column(Modifier.width(weekdayWidth)) {
                    Spacer(Modifier.height(labelHeight))
                    weekdayOrder().forEachIndexed { row, weekday ->
                        Box(Modifier.height(cell), contentAlignment = Alignment.CenterStart) {
                            if (row % 2 == 0) T(shortWeekdaySymbol(weekday), systemFont(9, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
                        }
                        if (row < 6) Spacer(Modifier.height(spacing))
                    }
                }
            }
            val scroll = rememberScrollState()
            LaunchedEffect(scrollable, shown.size) { if (scrollable) scroll.scrollTo(scroll.maxValue) }
            Canvas(
                Modifier
                    .then(if (scrollable) Modifier.horizontalScroll(scroll) else Modifier)
                    .size(width, labelHeight + gridHeight),
            ) {
                val cellPx = cell.toPx()
                val gap = spacing.toPx()
                val top = labelHeight.toPx()
                val radius = CornerRadius(cellPx * 0.28f)
                var lastLabel = -100f
                shown.forEachIndexed { columnIndex, column ->
                    val x = columnIndex * (cellPx + gap)
                    if (showsLabels) {
                        val present = column.filterNotNull()
                        val month = present.firstOrNull { it.date.dayOfMonth == 1 } ?: if (columnIndex == 0) present.firstOrNull() else null
                        if (month != null && x - lastLabel > 28.dp.toPx()) {
                            drawText(measurer.measure(month.date.skeleton("MMM"), monthStyle), topLeft = Offset(x, 0f))
                            lastLabel = x
                        }
                    }
                    column.forEachIndexed { rowIndex, day ->
                        val y = top + rowIndex * (cellPx + gap)
                        when (day?.state) {
                            null -> if (columnIndex < shown.lastIndex) drawRoundRect(offColor, Offset(x, y), Size(cellPx, cellPx), radius)
                            HabitDayState.done -> drawRoundRect(color, Offset(x, y), Size(cellPx, cellPx), radius)
                            HabitDayState.missed -> drawRoundRect(missedColor, Offset(x, y), Size(cellPx, cellPx), radius)
                            HabitDayState.pending -> {
                                drawRoundRect(offColor, Offset(x, y), Size(cellPx, cellPx), radius)
                                val inset = 0.75.dp.toPx()
                                drawRoundRect(color, Offset(x + inset, y + inset), Size(cellPx - inset * 2, cellPx - inset * 2), radius, style = Stroke(1.5.dp.toPx()))
                            }
                            HabitDayState.off -> drawRoundRect(offColor, Offset(x, y), Size(cellPx, cellPx), radius)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodCell(period: HabitDay?, color: Color, compact: Boolean, modifier: Modifier = Modifier) {
    val theme = theme
    val shape = RoundedCornerShape(if (compact) 3.dp else 4.dp)
    val maxSize = if (compact) 18.dp else 26.dp
    Box(modifier, contentAlignment = Alignment.Center) {
        val base = Modifier.widthIn(max = maxSize).fillMaxWidth().aspectRatio(1f).clip(shape)
        when (period?.state) {
            HabitDayState.done -> Box(base.background(color))
            HabitDayState.missed -> Box(base.background(color.copy(alpha = 0.2f)))
            HabitDayState.pending -> Box(base.background(theme.secondaryTextColor.copy(alpha = 0.08f)).border(1.5.dp, color, shape))
            else -> Box(base.background(theme.secondaryTextColor.copy(alpha = 0.06f)))
        }
    }
}


/** Weeks: a column per month. Months: a row per year. Years: a cell per year. */
@Composable
private fun HabitPeriodGrid(periods: List<HabitDay>, cadence: HabitCadence, color: Color, compact: Boolean) {
    val theme = theme
    val spacing = if (compact) 3.dp else 4.dp
    val labelFont = systemFont(if (compact) 9 else 10, FontWeight.Medium)
    when (cadence) {
        HabitCadence.month -> {
            val byYear = periods.groupBy { it.date.yearNumber }
            val years = byYear.keys.sorted().takeLast(if (compact) 2 else 3)
            Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
                Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    Spacer(Modifier.width(30.dp))
                    (1..12).forEach { month ->
                        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                            T(java.time.Month.of(month).getDisplayName(java.time.format.TextStyle.NARROW, appLocale), labelFont, theme.secondaryTextColor, maxLines = 1)
                        }
                    }
                }
                years.forEach { year ->
                    Row(horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.CenterVertically) {
                        T("$year", labelFont.monospacedDigit, theme.secondaryTextColor, modifier = Modifier.width(30.dp), maxLines = 1)
                        (1..12).forEach { month -> PeriodCell(byYear[year]?.firstOrNull { it.date.month == month }, color, compact, Modifier.weight(1f)) }
                    }
                }
            }
        }
        HabitCadence.week -> {
            val recent = periods.takeLast(if (compact) 26 else 53)
            val byMonth = recent.groupBy { it.date.startOfMonth() }.toSortedMap()
            Row(horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.Top) {
                byMonth.forEach { (month, weeks) ->
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(spacing)) {
                        T(java.time.Month.of(month.month).getDisplayName(java.time.format.TextStyle.NARROW, appLocale), labelFont, theme.secondaryTextColor, maxLines = 1)
                        weeks.forEach { PeriodCell(it, color, compact, Modifier.fillMaxWidth()) }
                    }
                }
            }
        }
        else -> {
            Row(horizontalArrangement = Arrangement.spacedBy(spacing * 2)) {
                periods.takeLast(6).forEach { year ->
                    Column(Modifier.widthIn(max = if (compact) 44.dp else 56.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        PeriodCell(year, color, compact, Modifier.width(if (compact) 18.dp else 26.dp))
                        T(year.date.skeleton("y"), labelFont.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                    }
                }
            }
        }
    }
}

// MARK: - Consistency

@Composable
private fun ConsistencyStatsTab() {
    val theme = theme
    val presenter = LocalPresenter.current
    val data = vm.data
    var compared by remember { mutableStateOf<List<String>>(emptyList()) }
    LaunchedEffect(data.habitSummaries) {
        val ids = data.habitSummaries.map { it.taskId.toString() }
        compared = compared.filter { it in ids }
    }
    val comparedHabits = compared.mapNotNull { id -> data.habitSummaries.firstOrNull { it.taskId.toString() == id } }
    val unit = vm.bucketUnit(data.range, true)
    val window = RollingRate.window(unit, data.range)

    TabColumn {
        // Trend
        val habits = data.habitSummaries.filter { it.periodTotal > 0 }.sortedByDescending { it.periodTotal }
        val overall = ComparisonSeries("overall", "stats_overall".localized, theme.accentColor, RollingRate.points(data.trendBuckets.map { Triple(it.start, it.completed, it.total) }, window))
        val selectedSeries = comparedHabits.mapIndexed { index, habit ->
            ComparisonSeries(habit.taskId.toString(), habit.name, comparisonColors[index % comparisonColors.size], habit.rateSeries(unit, data.periodStart, data.periodEnd, if (habit.cadence == HabitCadence.day) window else 1), habit.cadence)
        }
        val base = "stats_period_rate".localized(StatsFormat.percent(data.overview.rate))
        val active = data.trendBuckets.filter { it.total > 0 }
        val subtitle = run {
            if (active.size < 4) return@run base
            val half = active.size / 2
            val first = active.take(half)
            val second = active.takeLast(half)
            val firstTotal = first.sumOf { it.total }
            val secondTotal = second.sumOf { it.total }
            if (firstTotal == 0 || secondTotal == 0) return@run base
            val delta = ((second.sumOf { it.completed }.toDouble() / secondTotal - first.sumOf { it.completed }.toDouble() / firstTotal) * 100).toInt()
            base + " · " + if (delta == 0) "stats_trend_stable".localized else "stats_trend_delta".localized(if (delta > 0) "+$delta" else "$delta")
        }
        StatsCard("stats_trend".localized, subtitle) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ComparisonChips(habits.map { ComparisonItem(it.taskId.toString(), it.name, it.icon) }, compared) { compared = it }
                if (overall.points.isEmpty()) {
                    StatsEmptyState("chart.line.uptrend.xyaxis", "stats_no_data_title".localized, "stats_no_data_period".localized)
                } else {
                    key(data.range, compared) {
                        ComparisonLineChart(
                            selectedSeries, overall, unit, 0.0, 100.0, listOf(0.0, 25.0, 50.0, 75.0, 100.0),
                            { "${Math.round(it)}%" },
                            { date ->
                                when (data.range) {
                                    TimeRange.today, TimeRange.week -> date.skeleton("EEE")
                                    TimeRange.month -> date.skeleton("dMMM")
                                    TimeRange.year -> date.skeleton("MMM")
                                    TimeRange.allTime -> date.skeleton("MMMyy")
                                }
                            },
                            { bucketTitle(it, unit) },
                            Modifier.fillMaxWidth().height(200.dp),
                        )
                    }
                    if (selectedSeries.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            ComparisonLegend(selectedSeries) { item -> data.habitSummaries.firstOrNull { it.taskId.toString() == item.id }?.let { StatsFormat.percent(it.periodRate) } }
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(Modifier.size(8.dp, 2.dp).background(theme.secondaryTextColor.copy(alpha = 0.55f)))
                                T("stats_overall".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                                T(StatsFormat.percent(data.overview.rate), Fonts.caption.semibold.monospacedDigit, theme.secondaryTextColor, TextAlign.End, Modifier.width(40.dp), maxLines = 1)
                            }
                        }
                    }
                    if (window > 1) {
                        T("stats_rolling_note".localized(if (unit == CalUnit.week) "stats_n_weeks".localized(window) else "stats_n_days".localized(window)), Fonts.caption2, theme.secondaryTextColor)
                    }
                }
            }
        }
        // Weekday
        val focus = comparedHabits.singleOrNull()
        val rates = if (focus == null) data.weekdayRates else weekdayOrder().map { weekday ->
            val items = focus.days.filter { it.date >= data.periodStart && it.date <= data.periodEnd && it.date.weekday == weekday && (it.state == HabitDayState.done || it.state == HabitDayState.missed) }
            WeekdayRate(weekday, items.count { it.state == HabitDayState.done }, items.size)
        }
        val activeRates = rates.filter { it.total > 0 }
        val top = activeRates.maxByOrNull { it.rate }
        val bottom = activeRates.minByOrNull { it.rate }
        val best = if (top != null && bottom != null && top.rate - bottom.rate >= 0.05) top else null
        val accent = if (focus != null) comparisonColors[0] else theme.accentColor
        val bestText = best?.let { "stats_best_day".localized(weekdaySymbol(it.weekday)) } ?: if (activeRates.isNotEmpty()) "stats_weekdays_even".localized else null
        StatsCard("stats_by_weekday".localized, listOfNotNull(focus?.name, bestText).joinToString(" · ").ifEmpty { null }) {
            if (activeRates.isEmpty()) {
                StatsEmptyState("calendar", "stats_no_data_title".localized, "stats_no_data_period".localized)
            } else {
                StatsBars(
                    rates.map { item -> StatBar(listOf(BarSegment(item.rate * 100, if (best == null || item.weekday == best.weekday) accent else accent.copy(alpha = 0.45f))), if (item.total > 0) StatsFormat.percent(item.rate) else "–") },
                    rates.map { shortWeekdaySymbol(it.weekday) },
                    Modifier.fillMaxWidth().height(120.dp),
                    yMax = 115.0,
                    corner = 4.dp,
                )
            }
        }
        // Ranking
        var showsAll by remember { mutableStateOf(false) }
        val ranked = data.habitSummaries.filter { it.periodTotal > 0 }.sortedWith(
            compareByDescending<HabitSummary> { it.periodTotal >= 4 }.thenByDescending { it.periodRate }.thenByDescending { it.periodTotal },
        )
        StatsCard("stats_by_habit".localized, "stats_by_habit_subtitle".localized) {
            if (ranked.isEmpty()) {
                StatsEmptyState("list.bullet", "stats_no_habits_title".localized, "stats_no_habits_message".localized)
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    (if (showsAll) ranked else ranked.take(8)).forEach { habit ->
                        key(habit.taskId) {
                            val color = colorFromHex(habit.color)
                            Column(Modifier.fillMaxWidth().pressable { presenter.sheet { HabitDetailView(habit) } }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Box(Modifier.width(16.dp), contentAlignment = Alignment.Center) { SF(habit.icon, color, 13.dp) }
                                    T(habit.name, Fonts.caption.medium, modifier = Modifier.weight(1f))
                                    T("${habit.periodCompleted}/${habit.periodTotal}", Fonts.caption2.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                                    T(StatsFormat.percent(habit.periodRate), Fonts.caption.bold.monospacedDigit, align = TextAlign.End, maxLines = 1, modifier = Modifier.width(38.dp))
                                }
                                BoxWithConstraints(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(color.copy(alpha = 0.15f))) {
                                    Box(Modifier.width(maxOf(6.dp, maxWidth * habit.periodRate.toFloat())).fillMaxHeight().clip(CircleShape).background(color))
                                }
                            }
                        }
                    }
                    if (ranked.size > 8) {
                        T(
                            if (showsAll) "stats_show_less".localized else "stats_show_all".localized(ranked.size),
                            Fonts.footnote.semibold,
                            theme.accentColor,
                            TextAlign.Center,
                            Modifier.fillMaxWidth().tap { showsAll = !showsAll },
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Performance

private data class PerformanceBucket(val start: Date, val quality: Double?, val difficulty: Double?, val count: Int)

private fun performanceBuckets(completions: List<TaskCompletionAnalytics>, unit: CalUnit): List<PerformanceBucket> =
    completions.filter { it.qualityRating != null || it.difficultyRating != null }
        .groupBy { unit.start(it.date) }
        .map { (start, items) ->
            PerformanceBucket(
                start,
                items.mapNotNull { it.qualityRating }.takeIf { it.isNotEmpty() }?.average(),
                items.mapNotNull { it.difficultyRating }.takeIf { it.isNotEmpty() }?.average(),
                items.size,
            )
        }
        .sortedBy { it.start }

private fun analyticsIcon(task: TaskPerformanceAnalytics): String {
    val source = TaskManager.task(task.taskId) ?: return "checkmark.circle"
    return if (source.icon.isEmpty() || source.icon == "circle") source.category?.icon ?: "checkmark.circle" else source.icon
}

@Composable
private fun PerformanceStatsTab() {
    val theme = theme
    val presenter = LocalPresenter.current
    val data = vm.data
    val range = data.range
    var compared by remember { mutableStateOf<List<String>>(emptyList()) }
    var metricIsQuality by remember { mutableStateOf(true) }
    var sortRaw by appStorage("statsPerformanceSort", "ratings")
    val rated = data.taskPerformanceAnalytics.filter { it.averageDifficulty != null || it.averageQuality != null }.sortedByDescending { it.completions.size }
    LaunchedEffect(rated.map { it.taskId }) { compared = compared.filter { id -> rated.any { it.taskId.toString() == id } } }
    val sorted = when (sortRaw) {
        "quality" -> rated.sortedByDescending { it.averageQuality ?: 0.0 }
        "difficulty" -> rated.sortedByDescending { it.averageDifficulty ?: 0.0 }
        "name" -> rated.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.taskName })
        else -> rated
    }
    val unit = range.performanceUnit

    TabColumn {
        if (rated.isEmpty()) {
            StatsCard("performance".localized) { StatsEmptyState("speedometer", "no_performance_data".localized, "complete_recurring_tasks_performance".localized) }
        } else {
            val all = rated.flatMap { it.completions }
            val q = all.mapNotNull { it.qualityRating }
            val d = all.mapNotNull { it.difficultyRating }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("${all.size}", "stats_ratings".localized, "checkmark.seal.fill", Color.SysBlue, Modifier.weight(1f).fillMaxHeight(), "stats_tasks_count".localized(rated.size))
                StatTile(if (q.isEmpty()) "–" else one(q.average()), "quality".localized, "star.fill", qualityColor, Modifier.weight(1f).fillMaxHeight(), "stats_average_short".localized)
                StatTile(if (d.isEmpty()) "–" else one(d.average()), "difficulty".localized, "bolt.fill", difficultyColor, Modifier.weight(1f).fillMaxHeight(), "stats_average_short".localized)
            }
            QualityDifficultyMap(rated) { task -> presenter.sheet { PerformanceTaskDetailView(task, range) } }

            fun metricPoints(buckets: List<PerformanceBucket>) = buckets.mapNotNull { bucket -> (if (metricIsQuality) bucket.quality else bucket.difficulty)?.let { ComparisonPoint(bucket.start, it) } }
            val overall = ComparisonSeries("overall", "stats_overall".localized, theme.accentColor, metricPoints(performanceBuckets(all, unit)))
            val selected = compared.mapIndexedNotNull { index, id ->
                val task = rated.firstOrNull { it.taskId.toString() == id } ?: return@mapIndexedNotNull null
                val cadence = TaskManager.task(task.taskId)?.let { vm.cadence(it) } ?: HabitCadence.day
                ComparisonSeries(id, task.taskName, comparisonColors[index % comparisonColors.size], metricPoints(performanceBuckets(task.completions, unit)), cadence)
            }
            StatsCard(
                "stats_trend".localized,
                trailing = {
                    SegmentedControl(listOf(true, false), metricIsQuality, { metricIsQuality = it }, { (if (it) "quality" else "difficulty").localized }, Modifier.width(170.dp))
                },
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ComparisonChips(rated.map { ComparisonItem(it.taskId.toString(), it.taskName, analyticsIcon(it)) }, compared) { compared = it }
                    if (overall.points.isNotEmpty() || selected.isNotEmpty()) {
                        key(range, metricIsQuality, compared) {
                            ComparisonLineChart(
                                selected, overall, unit, 0.0, 10.0, listOf(0.0, 5.0, 10.0), { one(it) },
                                { date -> if (unit == CalUnit.month) date.skeleton("MMM") else date.skeleton("dMMM") },
                                { bucketTitle(it, unit) },
                                Modifier.fillMaxWidth().height(190.dp),
                            )
                        }
                    }
                    if (selected.isNotEmpty()) ComparisonLegend(selected) { item -> item.average?.let { one(it) } }
                }
            }
            val sorts = listOf("ratings" to "stats_ratings", "quality" to "quality", "difficulty" to "difficulty", "name" to "stats_sort_name")
            StatsCard(
                "tasks_with_performance_data".localized,
                trailing = {
                    IOSMenu(sorts.map { (raw, key) -> MenuItem(key.localized, checked = sortRaw == raw) { sortRaw = raw } }) {
                        SF("arrow.up.arrow.down", theme.accentColor, 22.dp)
                    }
                },
            ) {
                Column {
                    sorted.forEachIndexed { index, task ->
                        key(task.taskId) { PerformanceTaskRow(task) { presenter.sheet { PerformanceTaskDetailView(task, range) } } }
                        if (index < sorted.lastIndex) Box(Modifier.padding(start = 42.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                    }
                }
            }
        }
    }
}

@Composable
private fun PerformanceTaskRow(task: TaskPerformanceAnalytics, onClick: () -> Unit) {
    val theme = theme
    val categoryColor = colorFromHex(task.categoryColor ?: "#6366F1")
    Row(Modifier.fillMaxWidth().pressable(onClick = onClick).padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box {
            CategoryIconTile(analyticsIcon(task), categoryColor, 30.dp)
            // Only a real change is worth a badge.
            if (task.improvementTrend == ImprovementTrend.improving || task.improvementTrend == ImprovementTrend.declining) {
                Box(
                    Modifier
                        .align(Alignment.BottomEnd)
                        .offset(4.dp, 4.dp)
                        .size(14.dp)
                        .background(if (task.improvementTrend == ImprovementTrend.improving) Color.SysGreen else Color.SysOrange, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { SF(task.improvementTrend.icon, Color.White, 9.dp) }
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(task.taskName, Fonts.subheadline.medium)
            T("stats_ratings_count".localized(task.completions.size), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
        }
        task.averageQuality?.let { PerformanceValue("star.fill", qualityColor, one(it)) }
        task.averageDifficulty?.let { PerformanceValue("bolt.fill", difficultyColor, one(it)) }
        SF("chevron.right", theme.secondaryTextColor.copy(alpha = 0.5f), 12.dp)
    }
}

@Composable
private fun PerformanceValue(icon: String, tint: Color, text: String) {
    Row(Modifier.widthIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.End)) {
        SF(icon, tint, 12.dp)
        T(text, Fonts.caption.semibold.monospacedDigit, maxLines = 1)
    }
}

/** One dot per task: where each task sits between "easy/hard" and "low/high quality". */
@Composable
private fun QualityDifficultyMap(tasks: List<TaskPerformanceAnalytics>, onOpen: (TaskPerformanceAnalytics) -> Unit) {
    val theme = theme
    val points = tasks.filter { it.averageQuality != null && it.averageDifficulty != null }
    var selectedId by remember(tasks.size) { mutableStateOf<UUID?>(null) }
    val selected = points.firstOrNull { it.taskId == selectedId }
    val measurer = rememberTextMeasurer()
    StatsCard("stats_quality_vs_difficulty".localized, "stats_map_hint".localized) {
        if (points.isEmpty()) {
            StatsEmptyState("circle.grid.cross", "stats_no_data_title".localized, "stats_no_data_period".localized)
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val maxCount = max(1, points.maxOf { it.completions.size })
                val minQuality = points.minOf { it.averageQuality!! }
                val yLow = max(0.0, min(4.0, Math.floor(minQuality - 1)))
                val maxDifficulty = points.maxOf { it.averageDifficulty!! }
                val xHigh = min(10.0, max(6.0, ceil(maxDifficulty + 1)))
                val labelStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, color = theme.secondaryTextColor)
                val quadrantStyle = TextStyle(fontFamily = Inter, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = theme.secondaryTextColor.copy(alpha = 0.7f))
                val nameStyle = TextStyle(fontFamily = Inter, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = theme.textColor)
                val grid = theme.secondaryTextColor.copy(alpha = 0.2f)
                val divider = theme.secondaryTextColor.copy(alpha = 0.25f)
                val background = theme.backgroundColor
                val colors = points.associate { it.taskId to colorFromHex(it.categoryColor ?: "#6366F1") }
                val quadrants = listOf("stats_quadrant_easy_good".localized, "stats_quadrant_hard_good".localized, "stats_quadrant_easy_low".localized, "stats_quadrant_hard_low".localized)
                val qualityLabel = "quality".localized
                val difficultyLabel = "difficulty".localized
                Canvas(
                    Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                        .pointerInput(points) {
                            detectTapGestures { position ->
                                val left = 22.dp.toPx()
                                val bottom = 36.dp.toPx()
                                val top = 16.dp.toPx()
                                val plotW = size.width - left
                                val plotH = size.height - bottom - top
                                var best: UUID? = null
                                var distance = Float.MAX_VALUE
                                points.forEach { task ->
                                    val x = left + (task.averageDifficulty!! / xHigh).toFloat() * plotW
                                    val y = top + ((10 - task.averageQuality!!) / (10 - yLow)).toFloat() * plotH
                                    val d = hypot(x - position.x, y - position.y)
                                    if (d < 28.dp.toPx() && d < distance) {
                                        best = task.taskId
                                        distance = d
                                    }
                                }
                                selectedId = if (best == selectedId) null else best
                            }
                        },
                ) {
                    val left = 22.dp.toPx()
                    val bottom = 36.dp.toPx()
                    val top = 16.dp.toPx()
                    val plotW = size.width - left
                    val plotH = size.height - bottom - top
                    fun px(value: Double) = left + (value / xHigh).toFloat() * plotW
                    fun py(value: Double) = top + ((10 - value) / (10 - yLow)).toFloat() * plotH
                    drawText(measurer.measure(qualityLabel, labelStyle), topLeft = Offset(0f, 0f))
                    val dash = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))
                    var xTick = 0
                    while (xTick <= xHigh) {
                        drawLine(grid, Offset(px(xTick.toDouble()), top), Offset(px(xTick.toDouble()), top + plotH), 0.5.dp.toPx(), pathEffect = dash)
                        val text = measurer.measure("$xTick", labelStyle)
                        drawText(text, topLeft = Offset((px(xTick.toDouble()) - text.size.width / 2).coerceIn(0f, size.width - text.size.width), top + plotH + 2.dp.toPx()))
                        xTick++
                    }
                    var yTick = yLow.toInt()
                    while (yTick <= 10) {
                        drawLine(grid, Offset(left, py(yTick.toDouble())), Offset(size.width, py(yTick.toDouble())), 0.5.dp.toPx(), pathEffect = dash)
                        val text = measurer.measure("$yTick", labelStyle)
                        drawText(text, topLeft = Offset(0f, py(yTick.toDouble()) - text.size.height / 2))
                        yTick++
                    }
                    val xLabel = measurer.measure(difficultyLabel, labelStyle)
                    drawText(xLabel, topLeft = Offset(size.width - xLabel.size.width, size.height - xLabel.size.height))
                    drawLine(divider, Offset(px(5.0), top), Offset(px(5.0), top + plotH), 1.dp.toPx())
                    drawLine(divider, Offset(left, py(5.0)), Offset(size.width, py(5.0)), 1.dp.toPx())
                    val pad = 6.dp.toPx()
                    quadrants.forEachIndexed { index, label ->
                        val text = measurer.measure(label, quadrantStyle)
                        val x = if (index % 2 == 0) left + pad else size.width - text.size.width - pad
                        val y = if (index < 2) top + pad else top + plotH - text.size.height - pad
                        drawText(text, topLeft = Offset(x, y))
                    }
                    points.forEach { task ->
                        val isSelected = task.taskId == selectedId
                        val area = if (isSelected) 260f else 60f + 140f * task.completions.size / maxCount
                        val radius = kotlin.math.sqrt(area / Math.PI.toFloat()).dp.toPx()
                        val center = Offset(px(task.averageDifficulty!!), py(task.averageQuality!!))
                        drawCircle((colors[task.taskId] ?: Color.Gray).copy(alpha = if (selectedId == null || isSelected) 0.85f else 0.25f), radius, center)
                        if (isSelected) {
                            val text = measurer.measure(task.taskName, nameStyle, maxLines = 1)
                            val x = (center.x - text.size.width / 2).coerceIn(0f, size.width - text.size.width)
                            val y = (center.y - radius - text.size.height - 4.dp.toPx()).coerceAtLeast(0f)
                            drawRoundRect(background, Offset(x - 6.dp.toPx(), y - 2.dp.toPx()), Size(text.size.width + 12.dp.toPx(), text.size.height + 4.dp.toPx()), CornerRadius(20.dp.toPx()))
                            drawText(text, topLeft = Offset(x, y))
                        }
                    }
                }
                selected?.let { task ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(theme.backgroundColor).pressable { onOpen(task) }.padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Box(Modifier.size(10.dp).background(colorFromHex(task.categoryColor ?: "#6366F1"), CircleShape))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                            T(task.taskName, Fonts.subheadline.semibold)
                            T("stats_ratings_count".localized(task.completions.size), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
                        }
                        PerformanceLabel("star.fill", qualityColor, one(task.averageQuality ?: 0.0))
                        PerformanceLabel("bolt.fill", difficultyColor, one(task.averageDifficulty ?: 0.0))
                        SF("chevron.right", theme.secondaryTextColor, 12.dp)
                    }
                }
            }
        }
    }
}

@Composable
private fun PerformanceLabel(icon: String, tint: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        SF(icon, tint, 13.dp)
        T(text, Fonts.caption.semibold, tint, maxLines = 1)
    }
}

@Composable
private fun PerformanceTaskDetailView(task: TaskPerformanceAnalytics, range: TimeRange) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val durations = task.completions.mapNotNull { it.actualDuration }.filter { it > 0 }
    val unit = range.performanceUnit
    val buckets = performanceBuckets(task.completions, unit)
    var selectedDate by remember { mutableStateOf<Date?>(null) }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(task.taskName, trailing = { BarButton("done".localized, bold = true, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(task.averageQuality?.let { one(it) } ?: "–", "quality".localized, "star.fill", qualityColor, Modifier.weight(1f).fillMaxHeight())
                StatTile(task.averageDifficulty?.let { one(it) } ?: "–", "difficulty".localized, "bolt.fill", difficultyColor, Modifier.weight(1f).fillMaxHeight())
            }
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile(if (durations.isEmpty()) "–" else StatsFormat.hours(durations.average() / 3600), "stats_avg_duration".localized, "clock.fill", Color.SysBlue, Modifier.weight(1f).fillMaxHeight())
                StatTile(task.estimationAccuracy?.let { StatsFormat.percent(it) } ?: "–", "stats_estimate_accuracy".localized, "scope", Color.SysPurple, Modifier.weight(1f).fillMaxHeight())
            }
            StatsCard("stats_quality_difficulty".localized) {
                if (buckets.isEmpty()) {
                    StatsEmptyState("chart.xyaxis.line", "stats_no_data_title".localized, "stats_no_data_period".localized)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        val qualitySeries = ComparisonSeries("q", "quality".localized, qualityColor, buckets.mapNotNull { b -> b.quality?.let { ComparisonPoint(b.start, it) } })
                        val difficultySeries = ComparisonSeries("d", "difficulty".localized, difficultyColor, buckets.mapNotNull { b -> b.difficulty?.let { ComparisonPoint(b.start, it) } })
                        ComparisonLineChart(
                            listOf(qualitySeries, difficultySeries).map { it.copy(cadence = HabitCadence.day) }, null, unit, 0.0, 10.0, listOf(0.0, 5.0, 10.0), { one(it) },
                            { date -> if (unit == CalUnit.month) date.skeleton("MMM") else date.skeleton("dMMM") },
                            { bucketTitle(it, unit) },
                            Modifier.fillMaxWidth().height(180.dp),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            LegendDot(qualityColor, "quality".localized)
                            LegendDot(difficultyColor, "difficulty".localized)
                        }
                    }
                }
            }
            StatsCard("stats_recent_ratings".localized) {
                val recent = task.completions.sortedByDescending { it.date }.take(30)
                Column {
                    recent.forEachIndexed { index, completion ->
                        Row(Modifier.padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            T(completion.date.skeleton("EEEdMMMy"), Fonts.subheadline, modifier = Modifier.weight(1f))
                            completion.qualityRating?.let { PerformanceLabel("star.fill", qualityColor, "$it") }
                            completion.difficultyRating?.let { PerformanceLabel("bolt.fill", difficultyColor, "$it") }
                            completion.actualDuration?.takeIf { it > 0 }?.let {
                                T(StatsFormat.hours(it / 3600), Fonts.caption.monospacedDigit, theme.secondaryTextColor, TextAlign.End, Modifier.widthIn(min = 44.dp), maxLines = 1)
                            }
                        }
                        if (index < recent.lastIndex) Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.divider))
                    }
                }
            }
        }
    }
}
