package com.snaptask.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.service.quicksettings.TileService
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.graphics.vector.VectorGroup
import androidx.compose.ui.graphics.vector.VectorPath
import androidx.compose.ui.unit.dp
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** `WidgetCenter.reloadAllTimelines()`, a moment after the last change. */
object WidgetRefresher {
    private var pending: Job? = null

    fun request() {
        pending?.cancel()
        pending = MainScope.launch {
            delay(400)
            val context = App.context
            runCatching {
                TaskWidget().updateAll(context)
                PerformanceWidget().updateAll(context)
                PerformanceWidgetLarge().updateAll(context)
                FinanceWidget().updateAll(context)
                FinanceBudgetWidget().updateAll(context)
            }
        }
    }
}

// MARK: - Options of each widget

enum class WidgetScope { today, week, month, year }
enum class PerformanceContent { timeDistribution, completionRate }
enum class FinanceBalanceMode { total, monthly }

/** What the user chose for each widget instance (the widget intents on iOS). */
object WidgetSettings {
    /** Read while drawing, so an open widget redraws when an option changes. */
    var version by mutableStateOf(0)
        private set

    private fun get(id: Int, name: String): String? {
        version
        return Defaults.string("widget_${id}_$name")
    }

    private fun set(id: Int, name: String, value: String) {
        Defaults.set("widget_${id}_$name", value)
        version++
        WidgetRefresher.request()
    }

    fun scope(id: Int) = WidgetScope.entries.firstOrNull { it.name == get(id, "scope") } ?: WidgetScope.today
    fun setScope(id: Int, value: WidgetScope) = set(id, "scope", value.name)

    fun content(id: Int) = PerformanceContent.entries.firstOrNull { it.name == get(id, "content") } ?: PerformanceContent.timeDistribution
    fun setContent(id: Int, value: PerformanceContent) {
        set(id, "content", value.name)
        // "Today" and "All Time" aren't offered for the completion rate.
        if (value == PerformanceContent.completionRate && timeRange(id) !in completionRanges) setTimeRange(id, TimeRange.week)
    }

    val completionRanges = listOf(TimeRange.week, TimeRange.month, TimeRange.year)

    fun timeRange(id: Int) = TimeRange.entries.firstOrNull { it.name == get(id, "range") } ?: TimeRange.week
    fun setTimeRange(id: Int, value: TimeRange) = set(id, "range", value.name)

    fun balanceMode(id: Int) = FinanceBalanceMode.entries.firstOrNull { it.name == get(id, "balance") } ?: FinanceBalanceMode.total
    fun setBalanceMode(id: Int, value: FinanceBalanceMode) = set(id, "balance", value.name)

    fun budgetCategory(id: Int) = get(id, "budget")
    fun setBudgetCategory(id: Int, value: String) = set(id, "budget", value)
}

/** The screen shown to set a widget up: on Android it replaces "Edit Widget". */
class WidgetConfigActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        setResult(RESULT_CANCELED, result)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        enableEdgeToEdge()
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(id)?.provider?.className ?: ""
        setContent {
            AppTheme {
                val presenter = remember { Presenter() }
                CompositionLocalProvider(LocalPresenter provides presenter) {
                    presenter.Host {
                        WidgetConfigScreen(provider, id) {
                            setResult(RESULT_OK, result)
                            finish()
                        }
                    }
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun <T> ChoiceSection(title: String, options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit) {
    val theme = theme
    FormSection(title) {
        options.forEachIndexed { index, option ->
            FormRow(
                label(option), divider = index < options.lastIndex, onClick = { onSelect(option) },
                trailing = { if (option == selected) SF("checkmark", theme.accentColor, 18.dp) },
            )
        }
    }
}

@androidx.compose.runtime.Composable
private fun WidgetConfigScreen(provider: String, id: Int, onDone: () -> Unit) {
    val theme = theme
    val rangeLabel: (TimeRange) -> String = {
        when (it) {
            TimeRange.today -> "Today"
            TimeRange.week -> "Week"
            TimeRange.month -> "Month"
            TimeRange.year -> "Year"
            TimeRange.allTime -> "All Time"
        }.localized
    }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor).statusBarsPadding()) {
        NavBar(
            when {
                provider.endsWith("FinanceBudgetWidgetReceiver") -> "Category Budgets"
                provider.endsWith("FinanceWidgetReceiver") -> "Finance"
                provider.contains("Performance") -> "Performance"
                else -> "SnapTask"
            }.localized,
            trailing = { BarButton("done".localized, bold = true, color = theme.accentColor, onClick = onDone) },
        )
        FormPage(Modifier.weight(1f)) {
            when {
                provider.endsWith("FinanceBudgetWidgetReceiver") -> {
                    val budgets = FinanceManager.budgets
                    val options = listOf("all") + budgets.map { it.id.uuidString }
                    ChoiceSection("Category".localized, options, WidgetSettings.budgetCategory(id) ?: "all", { option ->
                        if (option == "all") "Total Budget".localized else budgets.first { it.id.uuidString == option }.let(FinanceManager::budgetDisplayName)
                    }) { WidgetSettings.setBudgetCategory(id, it) }
                }
                provider.endsWith("FinanceWidgetReceiver") -> ChoiceSection(
                    "Balance Mode".localized, FinanceBalanceMode.entries, WidgetSettings.balanceMode(id),
                    { (if (it == FinanceBalanceMode.total) "Total Balance" else "This Month").localized },
                ) { WidgetSettings.setBalanceMode(id, it) }
                provider.endsWith("PerformanceWidgetLargeReceiver") -> ChoiceSection(
                    "Time Range".localized, TimeRange.entries, WidgetSettings.timeRange(id), rangeLabel,
                ) { WidgetSettings.setTimeRange(id, it) }
                provider.endsWith("PerformanceWidgetReceiver") -> {
                    val content = WidgetSettings.content(id)
                    ChoiceSection(
                        "Performance Type".localized, PerformanceContent.entries, content,
                        { (if (it == PerformanceContent.timeDistribution) "Time Distribution" else "Task Completion Rate").localized },
                    ) { WidgetSettings.setContent(id, it) }
                    ChoiceSection(
                        "Time Range".localized,
                        if (content == PerformanceContent.completionRate) WidgetSettings.completionRanges else TimeRange.entries,
                        WidgetSettings.timeRange(id), rangeLabel,
                    ) { WidgetSettings.setTimeRange(id, it) }
                }
                else -> ChoiceSection(
                    "Scope".localized, WidgetScope.entries, WidgetSettings.scope(id),
                    {
                        when (it) {
                            WidgetScope.today -> "Today"
                            WidgetScope.week -> "Week"
                            WidgetScope.month -> "Month"
                            WidgetScope.year -> "Year"
                        }.localized
                    },
                ) { WidgetSettings.setScope(id, it) }
            }
        }
    }
}

// MARK: - Quick add

/** The Control Center button of iOS. */
class QuickAddTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java)
            .putExtra("quickAdd", true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (android.os.Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(android.app.PendingIntent.getActivity(this, 0, intent, android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(intent)
        }
    }
}

/** The long-press menu of the launcher icon: the App Shortcuts of iOS. */
object AppShortcuts {
    fun publish(context: Context) {
        fun shortcut(id: String, label: String, icon: Int, configure: Intent.() -> Unit) = ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setIcon(IconCompat.createWithResource(context, icon))
            .setIntent(Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW).apply(configure))
            .build()
        runCatching {
            ShortcutManagerCompat.setDynamicShortcuts(
                context,
                listOf(
                    shortcut("quick_add", "Quick Add Task".localized, R.drawable.ic_shortcut_add) { putExtra("quickAdd", true) },
                    shortcut("today", "Today".localized, R.drawable.ic_shortcut_today) { putExtra("openTab", 0) },
                ),
            )
        }
    }
}

// MARK: - Drawing

/** A widget can show only images: what the app draws with Compose is drawn here into a bitmap. */
internal object WidgetArt {
    private val symbols = HashMap<String, Bitmap>()

    /** In white: the widget tints it. */
    fun symbol(name: String, sizePx: Int): Bitmap = synchronized(symbols) {
        symbols.getOrPut("$name@$sizePx") {
            val vector = sfSymbol(name)
            val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.scale(sizePx / vector.viewportWidth, sizePx / vector.viewportHeight)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE }
            fun draw(group: VectorGroup) {
                group.forEach { node ->
                    when (node) {
                        is VectorGroup -> draw(node)
                        is VectorPath -> canvas.drawPath(PathParser().addPathNodes(node.pathData).toPath().asAndroidPath().apply {
                            fillType = if (node.pathFillType == androidx.compose.ui.graphics.PathFillType.EvenOdd) android.graphics.Path.FillType.EVEN_ODD else android.graphics.Path.FillType.WINDING
                        }, paint)
                    }
                }
            }
            draw(vector.root)
            bitmap
        }
    }

    fun donut(slices: List<Pair<Double, Int>>, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val total = slices.sumOf { it.first }
        val stroke = sizePx / 2f * 0.4f
        val inset = stroke / 2
        val rect = RectF(inset, inset, sizePx - inset, sizePx - inset)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
        }
        var start = -90f
        slices.forEach { (value, color) ->
            val sweep = if (total > 0) (value / total * 360).toFloat() else 0f
            paint.color = color
            canvas.drawArc(rect, start, sweep, false, paint)
            start += sweep
        }
        return bitmap
    }

    fun ring(sizePx: Int, strokePx: Float, color: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokePx
            this.color = color
        }
        Canvas(bitmap).drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f - strokePx / 2, paint)
        return bitmap
    }

    /** The filled checkbox of a completed task. */
    fun checked(sizePx: Int, from: Int, to: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = android.graphics.LinearGradient(0f, 0f, sizePx.toFloat(), sizePx.toFloat(), from, to, android.graphics.Shader.TileMode.CLAMP)
        }
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, paint)
        val mark = sizePx * 3 / 5
        val offset = (sizePx - mark) / 2f
        canvas.drawBitmap(symbol("checkmark", mark), offset, offset, Paint(Paint.ANTI_ALIAS_FLAG))
        return bitmap
    }

    /** The half circle of the budget widget. */
    fun gauge(progress: Double, color: Int, track: Int, widthPx: Int): Bitmap {
        val stroke = widthPx * 0.115f
        val height = (widthPx / 2f + stroke).toInt()
        val bitmap = Bitmap.createBitmap(widthPx, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inset = stroke / 2
        val rect = RectF(inset, inset, widthPx - inset, widthPx - inset)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        paint.color = track
        canvas.drawArc(rect, 180f, 180f, false, paint)
        if (progress > 0) {
            paint.color = color
            canvas.drawArc(rect, 180f, (180 * progress.coerceAtMost(1.0)).toFloat(), false, paint)
        }
        return bitmap
    }
}

internal fun Color.argb(alpha: Float = this.alpha): Int =
    android.graphics.Color.argb((alpha * 255).toInt(), (red * 255).toInt(), (green * 255).toInt(), (blue * 255).toInt())
