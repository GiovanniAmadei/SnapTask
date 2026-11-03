package com.snaptask.app

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.NumberFormat
import java.util.UUID
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.min

// MARK: - Style

private enum class Family { small, medium, large }

@Composable
private fun family(): Family {
    val size = LocalSize.current
    return when {
        size.width < 200.dp -> Family.small
        size.height >= 250.dp -> Family.large
        else -> Family.medium
    }
}

private val orange = ColorProvider(day = Color(0xFFFF9500), night = Color(0xFFFF9F0A))
private val pink = ColorProvider(day = Color(0xFFFF2D55), night = Color(0xFFFF375F))
private val green = ColorProvider(day = Color(0xFF34C759), night = Color(0xFF30D158))
private val red = ColorProvider(day = Color(0xFFFF3B30), night = Color(0xFFFF453A))
private val white = ColorProvider(day = Color.White, night = Color.White)
private val background = ColorProvider(day = Color(0.98f, 0.98f, 0.99f), night = Color(0.08f, 0.08f, 0.1f))
private val textColor = ColorProvider(day = Color(0.1f, 0.1f, 0.15f), night = Color.White)
private val secondaryText = ColorProvider(day = Color(0.45f, 0.45f, 0.5f), night = Color(0.65f, 0.65f, 0.7f))
private val faint = ColorProvider(day = Color(0.45f, 0.45f, 0.5f, 0.2f), night = Color(0.65f, 0.65f, 0.7f, 0.2f))
private val faintStrong = ColorProvider(day = Color(0.45f, 0.45f, 0.5f, 0.3f), night = Color(0.65f, 0.65f, 0.7f, 0.3f))

private fun Context.isNight() = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
private fun Context.px(dp: Dp) = (dp.value * resources.displayMetrics.density).toInt().coerceAtLeast(1)
private val Context.secondaryArgb get() = if (isNight()) Color(0.65f, 0.65f, 0.7f) else Color(0.45f, 0.45f, 0.5f)
private val Context.orangeArgb get() = if (isNight()) Color(0xFFFF9F0A) else Color(0xFFFF9500)
private val Context.pinkArgb get() = if (isNight()) Color(0xFFFF375F) else Color(0xFFFF2D55)

@Composable
private fun Label(
    text: String,
    size: Int,
    color: ColorProvider = textColor,
    weight: FontWeight = FontWeight.Normal,
    modifier: GlanceModifier = GlanceModifier,
    maxLines: Int = 1,
    align: TextAlign? = null,
) {
    Text(text, modifier, TextStyle(color = color, fontSize = size.sp, fontWeight = weight, textAlign = align), maxLines)
}

@Composable
private fun Symbol(name: String, color: ColorProvider, size: Dp, modifier: GlanceModifier = GlanceModifier) {
    val context = LocalContext.current
    Image(ImageProvider(WidgetArt.symbol(name, context.px(size))), null, modifier.size(size), colorFilter = ColorFilter.tint(color))
}

@Composable
private fun Dot(color: ColorProvider, size: Dp) {
    Box(GlanceModifier.size(size).background(color).cornerRadius(size / 2)) {}
}

@Composable
private fun CategoryBar(color: ColorProvider, height: Dp, corner: Dp = 2.dp) {
    Box(GlanceModifier.width(3.dp).height(height).background(color).cornerRadius(corner)) {}
}

/** The capsule with the orange and pink gradient. */
@Composable
private fun GradientCapsule(icon: String, text: String) {
    Row(
        GlanceModifier.background(ImageProvider(R.drawable.widget_capsule)).padding(horizontal = 8.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Symbol(icon, white, 11.dp)
        Spacer(GlanceModifier.width(4.dp))
        Label(text, 11, white, FontWeight.Bold)
    }
}

@Composable
private fun Rule(modifier: GlanceModifier = GlanceModifier.fillMaxWidth().height(1.dp)) {
    Box(modifier.background(faint)) {}
}

@Composable
private fun Bar(progress: Double, color: ColorProvider, height: Dp = 4.dp) {
    LinearProgressIndicator(progress.toFloat().coerceIn(0f, 1f), GlanceModifier.fillMaxWidth().height(height).cornerRadius(height / 2), color = color, backgroundColor = faint)
}

/** `minimumScaleFactor`: a smaller font instead of a cut number. */
private fun fittedSize(text: String, width: Dp, base: Int, smallest: Int = 11): Int =
    min(base.toFloat(), width.value / (text.length.coerceAtLeast(1) * 0.6f)).toInt().coerceAtLeast(smallest)

private fun openIntent(context: Context, configure: Intent.() -> Unit = {}) =
    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP).apply(configure)

private suspend fun widgetId(context: Context, id: GlanceId) = GlanceAppWidgetManager(context).getAppWidgetId(id)

// MARK: - Tasks

private val taskIdKey = ActionParameters.Key<String>("taskId")

class ToggleTaskAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[taskIdKey]?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: return
        withContext(Dispatchers.Main) { TaskManager.toggleTaskCompletion(id) }
    }
}

private fun scopedTasks(scope: WidgetScope): List<TodoTask> {
    val today = now()
    val tasks = TaskManager.tasks
    val filtered = when (scope) {
        WidgetScope.today -> tasks.filter { it.occurs(today) }
        WidgetScope.week -> {
            val start = today.startOfWeek()
            val end = start.addingDays(6)
            tasks.filter { task ->
                if (task.timeScope != TaskTimeScope.week) return@filter false
                if (task.recurrence != null) return@filter task.occursInWeek(start)
                val taskStart = task.scopeStartDate ?: return@filter false
                val taskEnd = task.scopeEndDate ?: return@filter false
                taskStart.isSameDay(start) && taskEnd.isSameDay(end)
            }
        }
        WidgetScope.month -> tasks.filter { task ->
            if (task.timeScope != TaskTimeScope.month) return@filter false
            if (task.recurrence != null) return@filter task.occursInMonth(today.startOfMonth())
            task.scopeStartDate?.isSameMonth(today) == true
        }
        WidgetScope.year -> tasks.filter { task ->
            if (task.timeScope != TaskTimeScope.year && task.timeScope != TaskTimeScope.longTerm) return@filter false
            if (task.recurrence != null) return@filter task.occursInYear(today.startOfYear())
            task.scopeStartDate?.isSameYear(today) == true
        }
    }
    // By time only, so the order doesn't jump when a task is checked.
    return filtered.sortedBy { it.startTime }
}

private fun TodoTask.isCompleted(date: Date) = completions[completionKey(date)]?.isCompleted == true

private val TodoTask.barColor: ColorProvider
    get() = category?.color?.let { hex -> colorFromHex(hex).let { ColorProvider(day = it, night = it) } } ?: orange

private fun scopeLabel(scope: WidgetScope) = when (scope) {
    WidgetScope.today -> "Today"
    WidgetScope.week -> "Week"
    WidgetScope.month -> "Month"
    WidgetScope.year -> "Year"
}.localized

class TaskWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = widgetId(context, id)
        provideContent {
            val scope = WidgetSettings.scope(appWidgetId)
            val tasks = scopedTasks(scope)
            val date = now()
            val open = actionStartActivity(openIntent(context) { putExtra("openTab", 0) })
            Box(GlanceModifier.fillMaxSize().background(background).clickable(open)) {
                when (family()) {
                    Family.small -> SmallTasks(tasks, date)
                    Family.medium -> MediumTasks(tasks, date, scope)
                    Family.large -> LargeTasks(tasks, date, scope)
                }
            }
        }
    }
}

class TaskWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TaskWidget()
}

private fun dateTitle(date: Date) = date.format("d MMM").replaceFirstChar { it.titlecase(appLocale) }.let { text ->
    text.split(" ").joinToString(" ") { part -> part.replaceFirstChar { it.titlecase(appLocale) } }
}

@Composable
private fun CheckBox(task: TodoTask, date: Date, size: Dp, ringColor: Color? = null) {
    val context = LocalContext.current
    val done = task.isCompleted(date)
    val bitmap = if (done) {
        WidgetArt.checked(context.px(size), context.orangeArgb.argb(), context.pinkArgb.argb())
    } else {
        val color = ringColor?.argb() ?: context.secondaryArgb.argb(0.4f)
        WidgetArt.ring(context.px(size), context.px(1.5.dp).toFloat(), color)
    }
    Box(
        GlanceModifier.size(size + 12.dp).clickable(actionRunCallback<ToggleTaskAction>(actionParametersOf(taskIdKey to task.id.uuidString))),
        contentAlignment = Alignment.Center,
    ) {
        Image(ImageProvider(bitmap), null, GlanceModifier.size(size))
    }
}

@Composable
private fun SmallTasks(tasks: List<TodoTask>, date: Date) {
    val context = LocalContext.current
    val height = LocalSize.current.height
    val completed = tasks.count { it.isCompleted(date) }
    Column(GlanceModifier.fillMaxSize().padding(12.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Label(dateTitle(date), 11, orange, FontWeight.Bold)
            Spacer(GlanceModifier.defaultWeight())
            Label("$completed", 11, orange, FontWeight.Bold)
            Label("/${tasks.size}", 11, secondaryText, FontWeight.Bold)
        }
        Spacer(GlanceModifier.height(6.dp))
        if (tasks.isEmpty()) {
            Spacer(GlanceModifier.defaultWeight())
            Label("0", 22, textColor, FontWeight.Bold, GlanceModifier.fillMaxWidth(), align = TextAlign.Center)
            Spacer(GlanceModifier.defaultWeight())
        } else {
            val open = tasks.filter { !it.isCompleted(date) }
            val shown = (if (open.isEmpty()) tasks else open).take(min(3, ((height.value - 50) / 32).toInt().coerceAtLeast(1)))
            shown.forEach { task ->
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    CategoryBar(task.barColor, 26.dp)
                    Spacer(GlanceModifier.width(6.dp))
                    Column(GlanceModifier.defaultWeight().clickable(actionStartActivity(openIntent(context) { putExtra("openTaskId", task.id.uuidString) }))) {
                        Label(task.name, 12, textColor, FontWeight.Medium)
                        if (task.hasSpecificTime) Label(task.startTime.timeText(), 9, orange, FontWeight.Medium)
                    }
                    CheckBox(task, date, 20.dp, if (task.isCompleted(date)) null else context.orangeArgb)
                }
            }
            Spacer(GlanceModifier.defaultWeight())
            if (open.isNotEmpty()) Bar(completed.toDouble() / tasks.size, orange, 5.dp)
        }
    }
}

@Composable
private fun TaskHeader(date: Date, scope: WidgetScope) {
    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        GradientCapsule("calendar", dateTitle(date))
        Spacer(GlanceModifier.defaultWeight())
        Label(scopeLabel(scope), 10, secondaryText, FontWeight.Medium)
    }
}

@Composable
private fun EmptyTasks(iconSize: Dp, textSize: Int) {
    Column(GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
        Symbol("checkmark.circle.fill", orange, iconSize)
        Spacer(GlanceModifier.height(4.dp))
        Label("No tasks".localized, textSize, secondaryText)
    }
}

@Composable
private fun CompactTaskRow(task: TodoTask, date: Date, modifier: GlanceModifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        CategoryBar(task.barColor, 20.dp, 1.5.dp)
        Spacer(GlanceModifier.width(6.dp))
        Label(task.name, 11, textColor, FontWeight.Medium, GlanceModifier.defaultWeight())
        CheckBox(task, date, 16.dp)
    }
}

@Composable
private fun MediumTasks(tasks: List<TodoTask>, date: Date, scope: WidgetScope) {
    Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
        TaskHeader(date, scope)
        Spacer(GlanceModifier.height(6.dp))
        if (tasks.isEmpty()) {
            EmptyTasks(24.dp, 11)
        } else {
            Row(GlanceModifier.fillMaxWidth()) {
                Column(GlanceModifier.defaultWeight()) {
                    tasks.take(3).forEach { CompactTaskRow(it, date, GlanceModifier.fillMaxWidth()) }
                }
                Spacer(GlanceModifier.width(12.dp))
                Column(GlanceModifier.defaultWeight()) {
                    tasks.drop(3).take(3).forEach { CompactTaskRow(it, date, GlanceModifier.fillMaxWidth()) }
                    if (tasks.size > 6) Label("+ %lld more".localized(tasks.size - 6), 9, orange, FontWeight.Medium)
                }
            }
        }
    }
}

@Composable
private fun LargeTasks(tasks: List<TodoTask>, date: Date, scope: WidgetScope) {
    val context = LocalContext.current
    val available = ((LocalSize.current.height.value - 60) / 40).toInt().coerceAtLeast(1)
    val limit = min(7, available)
    Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
        TaskHeader(date, scope)
        Spacer(GlanceModifier.height(8.dp))
        if (tasks.isEmpty()) {
            EmptyTasks(32.dp, 13)
        } else {
            val shown = tasks.take(limit)
            Column(GlanceModifier.fillMaxWidth()) {
            shown.forEachIndexed { index, task ->
                Column(GlanceModifier.fillMaxWidth()) {
                    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        CategoryBar(task.barColor, 32.dp)
                        Spacer(GlanceModifier.width(8.dp))
                        Column(GlanceModifier.defaultWeight().clickable(actionStartActivity(openIntent(context) { putExtra("openTaskId", task.id.uuidString) }))) {
                            Label(task.name, 12, textColor, FontWeight.Medium)
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                if (task.hasSpecificTime) {
                                    Symbol("clock", secondaryText, 9.dp)
                                    Spacer(GlanceModifier.width(2.dp))
                                    Label(task.startTime.timeText(), 9, secondaryText, FontWeight.Medium)
                                    Spacer(GlanceModifier.width(6.dp))
                                }
                                task.category?.let { category ->
                                    val color = colorFromHex(category.color)
                                    Label(
                                        category.name, 8, ColorProvider(day = color, night = color), FontWeight.Medium,
                                        GlanceModifier.background(color.copy(alpha = 0.15f)).cornerRadius(3.dp).padding(horizontal = 4.dp, vertical = 1.dp),
                                    )
                                    Spacer(GlanceModifier.width(6.dp))
                                }
                                val priority = colorFromHex(task.priority.colorHex)
                                Symbol(task.priority.icon, ColorProvider(day = priority, night = priority), 10.dp)
                            }
                        }
                        CheckBox(task, date, 20.dp)
                    }
                    if (index < shown.lastIndex) Rule(GlanceModifier.fillMaxWidth().height(1.dp))
                }
            }
            }
            Spacer(GlanceModifier.defaultWeight())
            if (tasks.size > limit) {
                Row(GlanceModifier.fillMaxWidth()) {
                    Spacer(GlanceModifier.defaultWeight())
                    Label("+ %lld more →".localized(tasks.size - limit), 10, orange, FontWeight.Medium)
                }
            }
        }
    }
}

// MARK: - Performance

private fun formatHours(hours: Double): String {
    if (hours < 1) return "${"%.0f".format(hours * 60)}m"
    val whole = hours.toInt()
    val minutes = ((hours - whole) * 60).toInt()
    return if (minutes > 0) "${whole}h ${minutes}m" else "${whole}h"
}

private fun rangeLabel(range: TimeRange) = when (range) {
    TimeRange.today -> "Today"
    TimeRange.week -> "Week"
    TimeRange.month -> "Month"
    TimeRange.year -> "Year"
    TimeRange.allTime -> "All Time"
}.localized

private fun percent(value: Double) = "%.0f%%".format(value * 100)

private class PerformanceEntry(range: TimeRange) {
    val categories = StatisticsViewModel.widgetCategoryStats(range).sortedByDescending { it.hours }
    val bars = StatisticsViewModel.widgetCompletionStats(range)
    val totalHours = categories.sumOf { it.hours }
    val completed = bars.sumOf { it.completedTasks }
    val total = bars.sumOf { it.totalTasks }
    val rate = if (total > 0) completed.toDouble() / total else 0.0
}

@Composable
private fun rememberEntry(range: TimeRange) = remember(range, TaskManager.tasks) { PerformanceEntry(range) }

private val CategoryStat.provider: ColorProvider
    get() = colorFromHex(color).let { ColorProvider(day = it, night = it) }

@Composable
private fun Donut(stats: List<CategoryStat>, size: Dp) {
    val context = LocalContext.current
    Image(ImageProvider(WidgetArt.donut(stats.map { it.hours to colorFromHex(it.color).argb() }, context.px(size))), null, GlanceModifier.size(size))
}

/** Widgets can hold ten children per row: more bars are split in two. */
@Composable
private fun CompletionBars(entry: PerformanceEntry, chartHeight: Dp, labelSize: Int, preferredWidth: Dp, corner: Dp, availableWidth: Dp) {
    val bars = entry.bars
    val width = minOf(preferredWidth, (availableWidth - 4.dp * (bars.size - 1).coerceAtLeast(0)) / bars.size.coerceAtLeast(1))
    Row(GlanceModifier.fillMaxWidth()) {
        val perRow = if (bars.size > 10) ceil(bars.size / 2.0).toInt() else bars.size.coerceAtLeast(1)
        bars.chunked(perRow).forEach { group ->
            Row(GlanceModifier.defaultWeight()) {
                group.forEach { stat ->
                    Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(GlanceModifier.size(width, chartHeight).background(faint).cornerRadius(corner), contentAlignment = Alignment.BottomCenter) {
                            if (stat.completedTasks > 0) {
                                Box(GlanceModifier.size(width, chartHeight * (stat.completedTasks.toFloat() / stat.totalTasks.coerceAtLeast(1))).background(orange).cornerRadius(corner)) {}
                            }
                        }
                        Spacer(GlanceModifier.height(3.dp))
                        Label(stat.day, labelSize, secondaryText, FontWeight.Medium)
                    }
                }
            }
        }
    }
}

@Composable
private fun LegendItem(color: ColorProvider, text: String, size: Int, dot: Dp) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Dot(color, dot)
        Spacer(GlanceModifier.width(4.dp))
        Label(text, size, secondaryText)
    }
}

@Composable
private fun PerformanceContentView(content: PerformanceContent, entry: PerformanceEntry) {
    val small = family() == Family.small
    when {
        content == PerformanceContent.timeDistribution && small -> SmallTime(entry)
        content == PerformanceContent.timeDistribution -> MediumTime(entry)
        small -> SmallCompletion(entry)
        else -> MediumCompletion(entry)
    }
}

@Composable
private fun EmptyChart(icon: String) {
    Column(GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
        Symbol(icon, orange, 24.dp)
        Spacer(GlanceModifier.height(4.dp))
        Label("No data".localized, 11, secondaryText)
    }
}

@Composable
private fun SmallTime(entry: PerformanceEntry) {
    val size = LocalSize.current
    val donut = minOf(70.dp, maxOf(54.dp, size.height * 0.42f))
    Column(GlanceModifier.fillMaxSize().padding(12.dp)) {
        Row(GlanceModifier.fillMaxWidth()) {
            Label("Time".localized, 11, orange, FontWeight.Bold)
            Spacer(GlanceModifier.defaultWeight())
            Label(formatHours(entry.totalHours), 11, textColor, FontWeight.Bold)
        }
        Spacer(GlanceModifier.height(8.dp))
        if (entry.categories.isEmpty()) {
            EmptyChart("chart.pie")
        } else {
            Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                Donut(entry.categories, donut)
                Spacer(GlanceModifier.width(10.dp))
                Column(GlanceModifier.defaultWeight()) {
                    entry.categories.take(3).forEach { stat ->
                        Row(GlanceModifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                            Dot(stat.provider, 6.dp)
                            Spacer(GlanceModifier.width(4.dp))
                            Label(stat.name, 9, textColor, FontWeight.Medium, GlanceModifier.defaultWeight())
                            Label(formatHours(stat.hours), 9, secondaryText, FontWeight.Medium)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MediumTime(entry: PerformanceEntry) {
    val context = LocalContext.current
    Row(GlanceModifier.fillMaxSize().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(GlanceModifier.width(100.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Label("Time Distribution".localized, 11, orange, FontWeight.Bold, align = TextAlign.Center, maxLines = 2)
            Spacer(GlanceModifier.height(8.dp))
            Box(GlanceModifier.size(80.dp), contentAlignment = Alignment.Center) {
                if (entry.categories.isEmpty()) {
                    Image(ImageProvider(WidgetArt.ring(context.px(80.dp), context.px(12.dp).toFloat(), context.secondaryArgb.argb(0.2f))), null, GlanceModifier.size(80.dp))
                    Label("No data".localized, 9, secondaryText)
                } else {
                    Donut(entry.categories, 80.dp)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Label(formatHours(entry.totalHours), fittedSize(formatHours(entry.totalHours), 46.dp, 14, 9), textColor, FontWeight.Bold)
                        Label("total".localized, 8, secondaryText)
                    }
                }
            }
        }
        Spacer(GlanceModifier.width(16.dp))
        Column(GlanceModifier.defaultWeight()) {
            val rows = min(6, ((LocalSize.current.height.value - 28) / 28).toInt().coerceAtLeast(1))
            entry.categories.take(rows).forEach { stat ->
                Row(GlanceModifier.fillMaxWidth().padding(bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    CategoryBar(stat.provider, 20.dp)
                    Spacer(GlanceModifier.width(6.dp))
                    Column(GlanceModifier.defaultWeight()) {
                        Label(stat.name, 11, textColor, FontWeight.Medium)
                        Label(formatHours(stat.hours), 9, secondaryText)
                    }
                    Label(percent(stat.hours / maxOf(entry.totalHours, 0.01)), 10, stat.provider, FontWeight.Medium)
                }
            }
            if (entry.categories.size > rows) Label("+ %lld more".localized(entry.categories.size - rows), 9, orange)
        }
    }
}

@Composable
private fun SmallCompletion(entry: PerformanceEntry) {
    val size = LocalSize.current
    Column(GlanceModifier.fillMaxSize().padding(12.dp)) {
        Row(GlanceModifier.fillMaxWidth()) {
            Label("Completion".localized, 11, orange, FontWeight.Bold)
            Spacer(GlanceModifier.defaultWeight())
            Label(percent(entry.rate), 11, textColor, FontWeight.Bold)
        }
        Spacer(GlanceModifier.height(8.dp))
        if (entry.bars.isEmpty()) {
            EmptyChart("chart.bar")
        } else {
            Spacer(GlanceModifier.defaultWeight())
            CompletionBars(entry, maxOf(40.dp, minOf(90.dp, size.height * 0.42f)), 7, if (entry.bars.size > 7) 9.dp else 12.dp, 2.dp, size.width - 24.dp)
            Spacer(GlanceModifier.height(4.dp))
            Row {
                LegendItem(orange, "Done".localized, 8, 5.dp)
                Spacer(GlanceModifier.width(8.dp))
                LegendItem(faintStrong, "Total".localized, 8, 5.dp)
            }
        }
    }
}

@Composable
private fun MediumCompletion(entry: PerformanceEntry) {
    val size = LocalSize.current
    Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            GradientCapsule("chart.bar.fill", "Task Completion Rate".localized)
            Spacer(GlanceModifier.defaultWeight())
            Label(percent(entry.rate), 14, orange, FontWeight.Bold)
        }
        Spacer(GlanceModifier.height(8.dp))
        if (entry.bars.isEmpty()) {
            Box(GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) { Label("No data".localized, 11, secondaryText) }
        } else {
            val chart = (size.height - 104.dp).coerceAtLeastDp(36.dp)
            CompletionBars(entry, minOf(68.dp, chart), 9, 20.dp, 4.dp, size.width - 28.dp)
            Spacer(GlanceModifier.height(4.dp))
            Row {
                LegendItem(orange, "Completed".localized, 9, 8.dp)
                Spacer(GlanceModifier.width(16.dp))
                LegendItem(faint, "Total".localized, 9, 8.dp)
            }
        }
    }
}

private fun Dp.coerceAtLeastDp(minimum: Dp) = if (this < minimum) minimum else this

@Composable
private fun LargeCombined(entry: PerformanceEntry, range: TimeRange) {
    val context = LocalContext.current
    val size = LocalSize.current
    val donut = minOf(132.dp, maxOf(90.dp, size.height * 0.3f))
    val chart = minOf(220.dp, maxOf(56.dp, size.height - donut - 150.dp))
    Column(GlanceModifier.fillMaxSize().padding(12.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            GradientCapsule("chart.bar.xaxis", "Performance".localized)
            Spacer(GlanceModifier.defaultWeight())
            Label(rangeLabel(range), 10, secondaryText, FontWeight.Medium)
        }
        Spacer(GlanceModifier.height(10.dp))
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(GlanceModifier.size(donut), contentAlignment = Alignment.Center) {
                if (entry.categories.isEmpty()) {
                    Image(ImageProvider(WidgetArt.ring(context.px(donut), context.px(10.dp).toFloat(), context.secondaryArgb.argb(0.2f))), null, GlanceModifier.size(donut))
                    Symbol("clock", faintStrong, 24.dp)
                } else {
                    Donut(entry.categories, donut)
                    Label(formatHours(entry.totalHours), fittedSize(formatHours(entry.totalHours), donut * 0.58f, 14, 9), textColor, FontWeight.Bold)
                }
            }
            Spacer(GlanceModifier.width(16.dp))
            Column(GlanceModifier.defaultWeight()) {
                Label("Time Distribution".localized, 11, orange, FontWeight.Bold)
                Spacer(GlanceModifier.height(4.dp))
                if (entry.categories.isEmpty()) {
                    Label("No time tracked".localized, 11, secondaryText)
                } else {
                    entry.categories.take(5).forEach { stat ->
                        Row(GlanceModifier.fillMaxWidth().padding(bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                            Dot(stat.provider, 8.dp)
                            Spacer(GlanceModifier.width(6.dp))
                            Label(stat.name, 11, textColor, FontWeight.Medium, GlanceModifier.defaultWeight())
                            Label(formatHours(stat.hours), 10, secondaryText)
                        }
                    }
                    if (entry.categories.size > 5) Label("+ %lld more".localized(entry.categories.size - 5), 9, orange)
                }
            }
        }
        Spacer(GlanceModifier.height(10.dp))
        Rule()
        Spacer(GlanceModifier.height(10.dp))
        // A widget column holds ten children: the rest goes in its own column.
        Column(GlanceModifier.fillMaxWidth()) {
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Label("Task Completion Rate".localized, 11, orange, FontWeight.Bold)
                Spacer(GlanceModifier.defaultWeight())
                Label(percent(entry.rate), 14, textColor, FontWeight.Bold)
            }
            Spacer(GlanceModifier.height(8.dp))
            if (entry.bars.isEmpty()) {
                Box(GlanceModifier.fillMaxWidth().height(72.dp), contentAlignment = Alignment.Center) { Label("No data".localized, 11, secondaryText) }
            } else {
                CompletionBars(entry, chart, 10, if (range == TimeRange.year) 18.dp else 20.dp, 4.dp, size.width - 24.dp)
                Spacer(GlanceModifier.height(4.dp))
                Row {
                    LegendItem(orange, "${entry.completed} ${"done".localized}", 10, 8.dp)
                    Spacer(GlanceModifier.width(16.dp))
                    LegendItem(faintStrong, "${entry.total} ${"total".localized}", 10, 8.dp)
                }
            }
        }
    }
}

class PerformanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = widgetId(context, id)
        provideContent {
            val entry = rememberEntry(WidgetSettings.timeRange(appWidgetId))
            val open = actionStartActivity(openIntent(context) { putExtra("openTab", 4) })
            Box(GlanceModifier.fillMaxSize().background(background).clickable(open)) {
                PerformanceContentView(WidgetSettings.content(appWidgetId), entry)
            }
        }
    }
}

class PerformanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PerformanceWidget()
}

class PerformanceWidgetLarge : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = widgetId(context, id)
        provideContent {
            val range = WidgetSettings.timeRange(appWidgetId)
            val entry = rememberEntry(range)
            val open = actionStartActivity(openIntent(context) { putExtra("openTab", 4) })
            Box(GlanceModifier.fillMaxSize().background(background).clickable(open)) {
                LargeCombined(entry, range)
            }
        }
    }
}

class PerformanceWidgetLargeReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PerformanceWidgetLarge()
}

// MARK: - Finance

private fun amount(value: Double, symbol: String): String {
    val format = NumberFormat.getNumberInstance(appLocale).apply { maximumFractionDigits = 0 }
    return "$symbol${format.format(abs(value))}"
}

private class WidgetBudgetItem(val id: String, val name: String, val icon: String, val limit: Double, val spent: Double) {
    val progress get() = if (limit > 0) min(spent / limit, 1.0) else 0.0
    val color get() = progressColor(progress)
    val colorValue: Color get() = if (progress > 0.8) Color(0xFFFF9500) else Color(0xFF34C759)
}

private fun progressColor(progress: Double) = if (progress > 1.0) red else if (progress > 0.8) orange else green

private fun widgetBudgets(): List<WidgetBudgetItem> {
    val period = FinanceManager.currentMonthPeriod()
    return FinanceManager.budgets.map { budget ->
        WidgetBudgetItem(budget.id.uuidString, FinanceManager.budgetDisplayName(budget), FinanceManager.budgetIcon(budget), budget.monthlyLimit, FinanceManager.spentAmount(budget, period))
    }
}

private val hasFinanceData get() = FinanceManager.entries.isNotEmpty() || FinanceManager.startingBalance != 0.0
private val currencySymbol get() = FinanceManager.selectedCurrency.symbol

class FinanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = widgetId(context, id)
        provideContent {
            val mode = WidgetSettings.balanceMode(appWidgetId)
            val open = actionStartActivity(openIntent(context) { putExtra("openTab", 3) })
            Box(GlanceModifier.fillMaxSize().background(background).clickable(open)) {
                val income = FinanceManager.monthlyIncome
                val expenses = FinanceManager.monthlyExpenses
                val balance = if (mode == FinanceBalanceMode.total) FinanceManager.currentBalance else income - expenses
                when {
                    family() == Family.large -> LargeFinance(mode, balance, income, expenses)
                    !hasFinanceData -> {
                        Column(GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
                            Symbol("eurosign.circle", green, 26.dp)
                            Spacer(GlanceModifier.height(6.dp))
                            Label("No finance data".localized, 11, secondaryText, align = TextAlign.Center, maxLines = 2)
                        }
                    }
                    family() == Family.small -> SmallFinance(mode, balance, income, expenses)
                    else -> MediumFinance(mode, balance, income, expenses)
                }
            }
        }
    }
}

class FinanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FinanceWidget()
}

private fun balanceColor(value: Double) = if (value >= 0) textColor else red

@Composable
private fun FinanceTitle() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Symbol("eurosign.circle.fill", green, 11.dp)
        Spacer(GlanceModifier.width(4.dp))
        Label("Finance".localized, 10, secondaryText, FontWeight.Bold)
    }
}

@Composable
private fun SmallFinance(mode: FinanceBalanceMode, balance: Double, income: Double, expenses: Double) {
    val size = LocalSize.current
    val symbol = currencySymbol
    Column(GlanceModifier.fillMaxSize().padding(14.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            FinanceTitle()
            Spacer(GlanceModifier.defaultWeight())
            Label((if (mode == FinanceBalanceMode.total) "Total" else "Month").localized, 9, secondaryText)
        }
        val text = amount(balance, symbol)
        Box(GlanceModifier.fillMaxWidth().defaultWeight(), contentAlignment = Alignment.CenterStart) {
            Label(text, fittedSize(text, size.width - 28.dp, 28), balanceColor(balance), FontWeight.Bold)
        }
        Rule()
        Spacer(GlanceModifier.height(6.dp))
        Row(GlanceModifier.fillMaxWidth()) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Symbol("arrow.down", green, 8.dp)
                    Spacer(GlanceModifier.width(3.dp))
                    Label("Income".localized, 9, secondaryText)
                }
                val value = amount(income, symbol)
                Label(value, fittedSize(value, (size.width - 28.dp) / 2, 12, 8), green, FontWeight.Bold)
            }
            Spacer(GlanceModifier.defaultWeight())
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Label("Expenses".localized, 9, secondaryText)
                    Spacer(GlanceModifier.width(3.dp))
                    Symbol("arrow.up", red, 8.dp)
                }
                val value = amount(expenses, symbol)
                Label(value, fittedSize(value, (size.width - 28.dp) / 2, 12, 8), red, FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun MediumFinance(mode: FinanceBalanceMode, balance: Double, income: Double, expenses: Double) {
    val size = LocalSize.current
    val symbol = currencySymbol
    val net = income - expenses
    val target = FinanceManager.monthlyBudgetTarget
    val progress = if (target > 0) min(expenses / target, 1.0) else 0.0
    val budgets = widgetBudgets()
    Row(GlanceModifier.fillMaxSize()) {
        Column(GlanceModifier.defaultWeight().fillMaxHeight().padding(start = 14.dp, top = 14.dp, bottom = 14.dp)) {
            FinanceTitle()
            Spacer(GlanceModifier.height(6.dp))
            Label((if (mode == FinanceBalanceMode.total) "Total Balance" else "This Month").localized, 10, secondaryText)
            val text = amount(balance, symbol)
            Box(GlanceModifier.fillMaxWidth().defaultWeight(), contentAlignment = Alignment.CenterStart) {
                Label(text, fittedSize(text, size.width / 2 - 20.dp, 26), balanceColor(balance), FontWeight.Bold)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                val color = if (net >= 0) green else red
                Symbol(if (net >= 0) "arrow.up.right" else "arrow.down.right", color, 9.dp)
                Spacer(GlanceModifier.width(3.dp))
                Label(amount(net, symbol), 10, color, FontWeight.Medium)
                Spacer(GlanceModifier.width(3.dp))
                Label("net".localized, 9, secondaryText)
            }
        }
        Box(GlanceModifier.width(1.dp).fillMaxHeight().padding(vertical = 12.dp)) { Rule(GlanceModifier.fillMaxSize()) }
        Column(GlanceModifier.defaultWeight().fillMaxHeight().padding(horizontal = 12.dp, vertical = 14.dp)) {
            FinanceRow("arrow.down.circle.fill", green, "Income".localized, amount(income, symbol))
            Spacer(GlanceModifier.defaultWeight())
            FinanceRow("arrow.up.circle.fill", red, "Expenses".localized, amount(expenses, symbol))
            if (target > 0) {
                Spacer(GlanceModifier.defaultWeight())
                Row(GlanceModifier.fillMaxWidth()) {
                    Label("Budget".localized, 10, secondaryText)
                    Spacer(GlanceModifier.defaultWeight())
                    Label(percent(progress), 10, progressColor(progress), FontWeight.Bold)
                }
                Spacer(GlanceModifier.height(3.dp))
                Bar(progress, progressColor(progress))
            } else if (budgets.isNotEmpty()) {
                Spacer(GlanceModifier.defaultWeight())
                BudgetBar(budgets[0], symbol, showAmount = false)
            }
        }
    }
}

@Composable
private fun FinanceRow(icon: String, color: ColorProvider, label: String, value: String) {
    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Symbol(icon, color, 11.dp)
        Spacer(GlanceModifier.width(6.dp))
        Label(label, 10, secondaryText)
        Spacer(GlanceModifier.defaultWeight())
        Label(value, 12, textColor, FontWeight.Bold)
    }
}

@Composable
private fun BudgetBar(budget: WidgetBudgetItem, symbol: String, showAmount: Boolean) {
    Column(GlanceModifier.fillMaxWidth()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Symbol(budget.icon, budget.color, 10.dp)
            Spacer(GlanceModifier.width(4.dp))
            Label(budget.name, 10, secondaryText, modifier = GlanceModifier.defaultWeight())
            if (showAmount) {
                Label("${amount(budget.spent, symbol)} / ${amount(budget.limit, symbol)}", 9, budget.color, FontWeight.Medium)
            } else {
                Label(percent(budget.progress), 10, budget.color, FontWeight.Bold)
            }
        }
        Spacer(GlanceModifier.height(3.dp))
        Bar(budget.progress, budget.color)
    }
}

@Composable
private fun LargeFinance(mode: FinanceBalanceMode, balance: Double, income: Double, expenses: Double) {
    val size = LocalSize.current
    val symbol = currencySymbol
    val net = income - expenses
    val target = FinanceManager.monthlyBudgetTarget
    val progress = if (target > 0) min(expenses / target, 1.0) else 0.0
    val budgets = widgetBudgets()
    Column(GlanceModifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 14.dp)) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Symbol("eurosign.circle.fill", green, 15.dp)
            Spacer(GlanceModifier.width(6.dp))
            Label("Finance".localized, 17, textColor, FontWeight.Bold)
            Spacer(GlanceModifier.defaultWeight())
            Label((if (mode == FinanceBalanceMode.total) "Total Balance" else "This Month").localized, 12, secondaryText)
        }
        Spacer(GlanceModifier.height(4.dp))
        val text = amount(balance, symbol)
        Label(text, fittedSize(text, size.width - 32.dp, 36), balanceColor(balance), FontWeight.Bold)
        Spacer(GlanceModifier.height(10.dp))
        Rule()
        Row(GlanceModifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            StatCell("arrow.down", "Income".localized, amount(income, symbol), green)
            Rule(GlanceModifier.width(1.dp).height(36.dp))
            StatCell("arrow.up", "Expenses".localized, amount(expenses, symbol), red)
            Rule(GlanceModifier.width(1.dp).height(36.dp))
            StatCell(if (net >= 0) "arrow.up.right" else "arrow.down.right", "Net".localized, amount(net, symbol), if (net >= 0) green else red)
        }
        Rule()
        Column(GlanceModifier.fillMaxWidth()) {
            if (target > 0) {
                Spacer(GlanceModifier.height(8.dp))
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Label("Budget".localized, 15, textColor, FontWeight.Medium)
                    Spacer(GlanceModifier.defaultWeight())
                    Label("${amount(expenses, symbol)} / ${amount(target, symbol)}", 12, progressColor(progress))
                }
                Spacer(GlanceModifier.height(5.dp))
                Bar(progress, progressColor(progress), 5.dp)
            }
            if (budgets.isNotEmpty()) {
                Spacer(GlanceModifier.height(8.dp))
                Label("Category Budgets".localized, 12, secondaryText, FontWeight.Bold)
                val rows = min(5, ((size.height.value - 230) / 26).toInt().coerceAtLeast(1))
                budgets.take(rows).forEach { budget ->
                    Box(GlanceModifier.fillMaxWidth().padding(top = 6.dp)) { BudgetBar(budget, symbol, showAmount = true) }
                }
            }
        }
    }
}

@Composable
private fun androidx.glance.layout.RowScope.StatCell(icon: String, label: String, value: String, color: ColorProvider) {
    Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Symbol(icon, color, 9.dp)
            Spacer(GlanceModifier.width(3.dp))
            Label(label, 11, secondaryText)
        }
        Label(value, fittedSize(value, LocalSize.current.width / 3 - 16.dp, 13, 8), color, FontWeight.Bold)
    }
}

// MARK: - Budgets

class FinanceBudgetWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = widgetId(context, id)
        provideContent {
            val selectedId = WidgetSettings.budgetCategory(appWidgetId)
            val budgets = widgetBudgets()
            val open = actionStartActivity(openIntent(context) { putExtra("openTab", 3) })
            Box(GlanceModifier.fillMaxSize().background(background).clickable(open)) {
                if (budgets.isEmpty()) {
                    Column(GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
                        Symbol("chart.bar.fill", faintStrong, 28.dp)
                        Spacer(GlanceModifier.height(6.dp))
                        Label("No budgets".localized, 12, secondaryText, align = TextAlign.Center)
                    }
                } else {
                    val selected = budgets.firstOrNull { it.id == selectedId }
                    val spent = budgets.sumOf { it.spent }
                    val limit = budgets.sumOf { it.limit }
                    val progress = if (limit > 0) min(spent / limit, 1.0) else 0.0
                    val totalCell = GaugeData("Total".localized, "chart.bar.fill", spent, limit, progress, totalColorValue(progress))
                    when (family()) {
                        Family.small -> {
                            val cell = selected?.let(::cellOf) ?: totalCell
                            GaugeCell(cell, GlanceModifier.fillMaxSize(), LocalSize.current.width, 20)
                        }
                        Family.medium -> {
                            val cells = if (selected != null) listOf(cellOf(selected), totalCell) else budgets.take(2).map(::cellOf)
                            Row(GlanceModifier.fillMaxSize()) {
                                cells.forEachIndexed { index, cell ->
                                    if (index > 0) Box(GlanceModifier.width(1.dp).fillMaxHeight().padding(vertical = 12.dp)) { Rule(GlanceModifier.fillMaxSize()) }
                                    GaugeCell(cell, GlanceModifier.defaultWeight().fillMaxHeight(), LocalSize.current.width / cells.size, 18)
                                }
                            }
                        }
                        Family.large -> LargeBudgets(budgets, totalCell)
                    }
                }
            }
        }
    }
}

class FinanceBudgetWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FinanceBudgetWidget()
}

private class GaugeData(val name: String, val icon: String, val spent: Double, val limit: Double, val progress: Double, val color: Color)

private fun cellOf(budget: WidgetBudgetItem) = GaugeData(budget.name, budget.icon, budget.spent, budget.limit, budget.progress, budget.colorValue)

private fun totalColorValue(progress: Double) = if (progress > 0.8) Color(0xFFFF9500) else Color(0.9f, 0.45f, 0.2f)

@Composable
private fun GaugeCell(cell: GaugeData, modifier: GlanceModifier, width: Dp, amountSize: Int) {
    val context = LocalContext.current
    val symbol = currencySymbol
    val color = ColorProvider(day = cell.color, night = cell.color)
    val height = LocalSize.current.height
    val gaugeWidth = minOf(width - 28.dp, height * 0.9f)
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Row(GlanceModifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Symbol(cell.icon, color, 10.dp)
            Spacer(GlanceModifier.width(4.dp))
            Label(cell.name.uppercase(appLocale), 9, secondaryText, FontWeight.Bold, GlanceModifier.defaultWeight())
            Label(percent(cell.progress), 9, color, FontWeight.Bold)
        }
        Spacer(GlanceModifier.defaultWeight())
        Box(contentAlignment = Alignment.BottomCenter) {
            Image(ImageProvider(WidgetArt.gauge(cell.progress, cell.color.argb(), context.secondaryArgb.argb(0.2f), context.px(gaugeWidth))), null, GlanceModifier.width(gaugeWidth).height(gaugeWidth * 0.615f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val text = amount(cell.spent, symbol)
                Label(text, fittedSize(text, gaugeWidth * 0.6f, amountSize, 9), textColor, FontWeight.Bold)
                Label("spent".localized, 8, secondaryText)
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        Row(GlanceModifier.width(gaugeWidth).padding(bottom = 10.dp)) {
            Label(amount(0.0, symbol), 8, secondaryText)
            Spacer(GlanceModifier.defaultWeight())
            Label(amount(cell.limit, symbol), 8, secondaryText)
        }
    }
}

@Composable
private fun LargeBudgets(budgets: List<WidgetBudgetItem>, total: GaugeData) {
    val size = LocalSize.current
    val symbol = currencySymbol
    val color = ColorProvider(day = total.color, night = total.color)
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Symbol("chart.bar.fill", color, 15.dp)
            Spacer(GlanceModifier.width(6.dp))
            Label("Category Budgets".localized, 17, textColor, FontWeight.Bold)
            Spacer(GlanceModifier.defaultWeight())
            Label("This Month".localized, 12, secondaryText)
        }
        Row(GlanceModifier.fillMaxWidth().height(130.dp), verticalAlignment = Alignment.CenterVertically) {
            GaugeCell(total, GlanceModifier.width(size.width * 0.44f).fillMaxHeight(), size.width * 0.44f, 22)
            Column(GlanceModifier.defaultWeight().padding(start = 12.dp, end = 16.dp)) {
                Label("Total Budget".localized, 15, textColor, FontWeight.Bold)
                Spacer(GlanceModifier.height(5.dp))
                StatRow("Spent".localized, amount(total.spent, symbol), color)
                StatRow("Limit".localized, amount(total.limit, symbol), textColor)
                val remaining = total.limit - total.spent
                StatRow("Remaining".localized, amount(maxOf(remaining, 0.0), symbol), if (remaining >= 0) green else red)
                Spacer(GlanceModifier.height(5.dp))
                Bar(total.progress, color, 5.dp)
            }
        }
        Box(GlanceModifier.fillMaxWidth().padding(horizontal = 16.dp)) { Rule() }
        val rows = min(6, ((size.height.value - 180) / 32).toInt().coerceAtLeast(1))
        budgets.take(rows).forEach { budget ->
            Column(GlanceModifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 7.dp)) {
                Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Symbol(budget.icon, budget.color, 12.dp)
                    Spacer(GlanceModifier.width(8.dp))
                    Label(budget.name, 12, textColor, modifier = GlanceModifier.defaultWeight())
                    Label(amount(budget.spent, symbol), 11, budget.color, FontWeight.Bold)
                    Label(" / ", 10, secondaryText)
                    Label(amount(budget.limit, symbol), 11, secondaryText)
                }
                Spacer(GlanceModifier.height(3.dp))
                Bar(budget.progress, budget.color)
            }
        }
    }
}

@Composable
private fun StatRow(label: String, value: String, color: ColorProvider) {
    Row(GlanceModifier.fillMaxWidth().padding(bottom = 3.dp), verticalAlignment = Alignment.CenterVertically) {
        Label(label, 11, secondaryText)
        Spacer(GlanceModifier.defaultWeight())
        Label(value, 11, color, FontWeight.Bold)
    }
}
