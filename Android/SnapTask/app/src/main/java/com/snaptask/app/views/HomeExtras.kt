package com.snaptask.app

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle as JavaTextStyle
import java.util.UUID

private val vm = TimelineViewModel

// MARK: - Eisenhower matrix

private enum class EisenhowerQuadrant(val titleKey: String, val subtitleKey: String, val hex: Long, val icon: String) {
    doNow("eisenhower_do_now", "eisenhower_important_urgent", 0xFFEF4444, "flame.fill"),
    schedule("eisenhower_schedule", "eisenhower_important_not_urgent", 0xFF3B82F6, "calendar"),
    delegate("eisenhower_delegate", "eisenhower_not_important_urgent", 0xFFF59E0B, "person.2.fill"),
    eliminate("eisenhower_eliminate", "eisenhower_not_important_not_urgent", 0xFF8E8E93, "trash.fill");

    val color: Color get() = Color(hex)
}

@Composable
fun EisenhowerMatrixView(modifier: Modifier = Modifier) {
    val theme = theme
    val presenter = LocalPresenter.current
    var expanded by remember { mutableStateOf<EisenhowerQuadrant?>(null) }
    val quadrants = vm.eisenhowerQuadrants(vm.applyingStatusFilter(vm.tasks))
    val byQuadrant = EisenhowerQuadrant.entries.zip(quadrants).toMap()
    val axisWidth = 24.dp
    val spacing = 8.dp

    fun toggle(quadrant: EisenhowerQuadrant) {
        Haptics.light()
        expanded = if (expanded == quadrant) null else quadrant
    }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(axisWidth)
                    .background(theme.primaryColor.copy(alpha = 0.12f), CircleShape)
                    .pressable {
                        Haptics.light()
                        presenter.sheet { NavigationStack { EisenhowerSettingsView(showDone = true) } }
                    },
                contentAlignment = Alignment.Center,
            ) { SF("slider.horizontal.3", theme.primaryColor, 15.dp) }
            if (expanded == null) {
                AxisLabel("eisenhower_axis_urgent".localized, "alarm.fill", Modifier.weight(1f))
                AxisLabel("eisenhower_axis_not_urgent".localized, "hourglass", Modifier.weight(1f))
            }
        }
        AnimatedContent(
            expanded,
            modifier = Modifier.fillMaxWidth().weight(1f),
            transitionSpec = { (fadeIn(tween(300)) + scaleIn(tween(300), 0.97f)) togetherWith (fadeOut(tween(250)) + scaleOut(tween(250), 1.03f)) },
            label = "matrix",
        ) { open ->
            if (open != null) {
                MatrixQuadrant(open, byQuadrant[open] ?: emptyList(), true, Modifier.fillMaxSize()) { toggle(open) }
            } else {
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(spacing)) {
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(spacing)) {
                        RowAxisLabel("eisenhower_axis_important".localized, axisWidth)
                        MatrixQuadrant(EisenhowerQuadrant.doNow, byQuadrant[EisenhowerQuadrant.doNow] ?: emptyList(), false, Modifier.weight(1f).fillMaxHeight()) { toggle(EisenhowerQuadrant.doNow) }
                        MatrixQuadrant(EisenhowerQuadrant.schedule, byQuadrant[EisenhowerQuadrant.schedule] ?: emptyList(), false, Modifier.weight(1f).fillMaxHeight()) { toggle(EisenhowerQuadrant.schedule) }
                    }
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(spacing)) {
                        RowAxisLabel("eisenhower_axis_not_important".localized, axisWidth)
                        MatrixQuadrant(EisenhowerQuadrant.delegate, byQuadrant[EisenhowerQuadrant.delegate] ?: emptyList(), false, Modifier.weight(1f).fillMaxHeight()) { toggle(EisenhowerQuadrant.delegate) }
                        MatrixQuadrant(EisenhowerQuadrant.eliminate, byQuadrant[EisenhowerQuadrant.eliminate] ?: emptyList(), false, Modifier.weight(1f).fillMaxHeight()) { toggle(EisenhowerQuadrant.eliminate) }
                    }
                }
            }
        }
    }
}

@Composable
private fun AxisLabel(text: String, icon: String, modifier: Modifier) {
    val color = theme.secondaryTextColor
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        SF(icon, color, 11.dp)
        T(text.uppercase(appLocale), systemFont(11, FontWeight.Bold).copy(letterSpacing = androidx.compose.ui.unit.TextUnit(0.4f, androidx.compose.ui.unit.TextUnitType.Sp)), color, maxLines = 1)
    }
}

@Composable
private fun RowAxisLabel(text: String, width: androidx.compose.ui.unit.Dp) {
    Box(Modifier.width(width).fillMaxHeight(), contentAlignment = Alignment.Center) {
        T(
            text.uppercase(appLocale),
            systemFont(11, FontWeight.Bold),
            theme.secondaryTextColor,
            maxLines = 1,
            modifier = Modifier
                .rotate(-90f)
                .layout { measurable, constraints ->
                    // Vertical text: measured at its full length, not at the column's width.
                    val placeable = measurable.measure(constraints.copy(maxWidth = androidx.compose.ui.unit.Constraints.Infinity))
                    layout(placeable.height, placeable.width) { placeable.place((placeable.height - placeable.width) / 2, (placeable.width - placeable.height) / 2) }
                },
        )
    }
}

@Composable
private fun MatrixQuadrant(quadrant: EisenhowerQuadrant, tasks: List<TodoTask>, isExpanded: Boolean, modifier: Modifier, onToggle: () -> Unit) {
    val theme = theme
    val color = quadrant.color
    val shape = RoundedCornerShape(20.dp)
    val sorted = tasks.withIndex().sortedWith(compareBy<IndexedValue<TodoTask>> {
        when (vm.progressState(it.value)) {
            TaskProgressState.inProgress -> 0
            TaskProgressState.todo -> 1
            TaskProgressState.completed -> 2
        }
    }.thenBy { it.index }).map { it.value }
    val openCount = tasks.count { vm.progressState(it) != TaskProgressState.completed }

    Column(
        modifier
            .shadow(if (theme.systemDark) 0.dp else 5.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .background(Brush.verticalGradient(listOf(color.copy(alpha = 0.13f), color.copy(alpha = 0.02f))))
            .border(1.dp, color.copy(alpha = 0.25f), shape)
    ) {
        Column(
            Modifier.fillMaxWidth().pressable(onClick = onToggle).padding(start = 12.dp, end = 12.dp, top = 12.dp, bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                T(quadrant.titleKey.localized, systemFont(13, FontWeight.Bold), color, modifier = Modifier.weight(1f))
                Box(
                    Modifier
                        .defaultMinSize(22.dp, 20.dp)
                        .clip(CircleShape)
                        .background(if (openCount > 0) color else color.copy(alpha = 0.35f))
                        .padding(horizontal = 7.dp),
                    contentAlignment = Alignment.Center,
                ) { T("$openCount", systemFont(12, FontWeight.Bold).monospacedDigit, Color.White, maxLines = 1) }
                if (isExpanded) {
                    Box(Modifier.size(22.dp).background(color.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) {
                        SF("arrow.down.right.and.arrow.up.left", color, 13.dp)
                    }
                }
            }
            if (isExpanded) T(quadrant.subtitleKey.localized, systemFont(12, FontWeight.Medium), theme.secondaryTextColor)
        }
        LazyColumn(
            Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(start = 7.dp, end = 7.dp, top = 2.dp, bottom = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(sorted, key = { it.id }) { task ->
                Box(Modifier.animateItem()) { MatrixTaskRow(task, color) }
            }
            if (tasks.isEmpty()) {
                item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        SF(quadrant.icon, color.copy(alpha = 0.35f), 20.dp)
                        T("empty".localized, Fonts.caption.medium, theme.secondaryTextColor.copy(alpha = 0.8f))
                    }
                }
            }
        }
    }
}

@Composable
private fun MatrixTaskRow(task: TodoTask, tint: Color) {
    val theme = theme
    val presenter = LocalPresenter.current
    val state = vm.progressState(task)
    val isCompleted = state == TaskProgressState.completed
    val date = vm.progressDate(task)
    val categoryTint = task.category?.let { colorFromHex(it.color) } ?: theme.accentColor
    val shape = RoundedCornerShape(12.dp)
    val completedSubtasks = task.completions[task.completionKey(date)]?.completedSubtasks?.size ?: 0

    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(theme.backgroundColor.copy(alpha = 0.85f))
            .border(if (state == TaskProgressState.inProgress) 1.2.dp else 1.dp, if (state == TaskProgressState.inProgress) Color.SysBlue.copy(alpha = 0.6f) else tint.copy(alpha = 0.12f), shape)
            .tap { presenter.sheet { NavigationStack { TaskDetailView(taskId = task.id, targetDate = date) } } }
            .padding(horizontal = 10.dp, vertical = 9.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        T(task.name, systemFont(13, FontWeight.SemiBold), modifier = Modifier.fillMaxWidth())
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Box(Modifier.size(20.dp).clip(RoundedCornerShape(6.dp)).background(categoryTint.copy(alpha = 0.16f)), contentAlignment = Alignment.Center) {
                SF(displayIcon(task), categoryTint, 12.dp)
            }
            val time = task.hasSpecificTime
            val subs = task.subtasks.isNotEmpty()
            Box(Modifier.weight(1f)) {
                if (time || subs) {
                    // Time and subtasks when they fit; otherwise the subtasks step aside.
                    ViewThatFits(
                        { MatrixChips(task, time, subs, completedSubtasks) },
                        { MatrixChips(task, time, false, completedSubtasks) },
                        {},
                    )
                }
            }
            Box(
                Modifier
                    .size(width = 26.dp, height = 22.dp)
                    .taskStatusGestures(
                        onTap = {
                            if (isCompleted) Haptics.light() else Haptics.success()
                            vm.toggleTaskCompletion(task.id)
                        },
                        onLongPress = {
                            InProgressTip.markLearned()
                            TaskManager.toggleInProgress(task.id, date)
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) { TaskStatusIcon(state, tint.copy(alpha = 0.8f), size = 20.dp) }
        }
    }
}

@Composable
private fun MatrixChips(task: TodoTask, time: Boolean, subtasks: Boolean, completed: Int) {
    val theme = theme
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        @Composable
        fun chip(text: String, icon: String? = null) {
            Row(
                Modifier.clip(CircleShape).background(theme.surfaceColor).padding(horizontal = 5.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                if (icon != null) SF(icon, theme.secondaryTextColor, 10.dp)
                T(text, systemFont(10, FontWeight.Medium).monospacedDigit, theme.secondaryTextColor, maxLines = 1)
            }
        }
        if (time) chip(task.startTime.timeText())
        if (subtasks) chip("$completed/${task.subtasks.size}", "checklist")
    }
}

/** The rules of the matrix (`EisenhowerSettingsView`). */
@Composable
fun EisenhowerSettingsView(showDone: Boolean = false) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val settings = SettingsViewModel
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("eisenhower_settings_title".localized, trailing = if (showDone) ({ BarButton("done".localized, bold = true, onClick = dismiss) }) else null)
        FormPage(Modifier.weight(1f)) {
            FormSection(footer = "eisenhower_settings_intro".localized) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    EisenhowerQuadrant.entries.chunked(2).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { quadrant ->
                                Row(
                                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(quadrant.color.copy(alpha = 0.08f)).padding(10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    Box(Modifier.size(26.dp).background(quadrant.color.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
                                        SF(quadrant.icon, quadrant.color, 13.dp)
                                    }
                                    FitText(listOf(quadrant.titleKey.localized), listOf(12), quadrant.color)
                                }
                            }
                        }
                    }
                }
            }
            FormSection("eisenhower_importance_section".localized) {
                SettingToggle(
                    "eisenhower_medium_important_title".localized,
                    "eisenhower_medium_important_desc".localized,
                    settings.eisenhowerMediumIsImportant,
                    "exclamationmark.circle.fill",
                ) { settings.eisenhowerMediumIsImportant = it }
            }
            FormSection("eisenhower_urgency_section".localized, "eisenhower_threshold_desc".localized) {
                ThresholdRow("today".localized, "sun.max.fill", Color.SysOrange, settings.eisenhowerTodayUrgentHours, 0..24, 1, true) { settings.eisenhowerTodayUrgentHours = it }
                SettingToggle(
                    "eisenhower_today_require_specific_time_title".localized,
                    "eisenhower_today_require_specific_time_desc".localized,
                    settings.eisenhowerTodayRequireSpecificTime,
                    null,
                ) { settings.eisenhowerTodayRequireSpecificTime = it }
                ThresholdRow("week".localized, "calendar.badge.clock", Color.SysBlue, settings.eisenhowerWeekUrgentHours, 0..168, 6, true) { settings.eisenhowerWeekUrgentHours = it }
                ThresholdRow("month".localized, "calendar", Color.SysGreen, settings.eisenhowerMonthUrgentDays, 0..31, 1, false) { settings.eisenhowerMonthUrgentDays = it }
                ThresholdRow("year".localized, "calendar.circle.fill", Color.SysPurple, settings.eisenhowerYearUrgentDays, 0..60, 1, false) { settings.eisenhowerYearUrgentDays = it }
            }
            FormSection {
                FormRow("reset_to_defaults".localized, icon = "arrow.counterclockwise", iconTint = theme.accentColor, titleColor = theme.accentColor, divider = false, onClick = { settings.resetEisenhowerUrgencyDefaults() })
            }
        }
    }
}

@Composable
private fun SettingToggle(title: String, description: String, checked: Boolean, icon: String?, onChange: (Boolean) -> Unit) {
    val theme = theme
    Column(Modifier.fillMaxWidth().padding(start = if (icon == null) 52.dp else 16.dp, end = 16.dp, top = 10.dp, bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (icon != null) SF(icon, Color(0xFFEF4444), 20.dp)
            T(title, Fonts.body, modifier = Modifier.weight(1f))
            IOSToggle(checked, onChange, tint = theme.accentColor)
        }
        T(description, Fonts.caption, theme.secondaryTextColor)
    }
}

/** "Urgent from 1 day, 12 hours before the deadline", written in the user's language. */
private fun thresholdDescription(amount: Int, hours: Boolean): String {
    if (amount <= 0) return "eisenhower_only_overdue".localized
    val format = android.icu.text.MeasureFormat.getInstance(appLocale, android.icu.text.MeasureFormat.FormatWidth.WIDE)
    val measures = if (hours) {
        listOfNotNull(
            (amount / 24).takeIf { it > 0 }?.let { android.icu.util.Measure(it, android.icu.util.MeasureUnit.DAY) },
            (amount % 24).takeIf { it > 0 }?.let { android.icu.util.Measure(it, android.icu.util.MeasureUnit.HOUR) },
        )
    } else listOf(android.icu.util.Measure(amount, android.icu.util.MeasureUnit.DAY))
    return "eisenhower_urgent_within_format".localized(format.formatMeasures(*measures.toTypedArray()))
}

@Composable
private fun ThresholdRow(title: String, icon: String, color: Color, value: Int, range: IntRange, step: Int, hours: Boolean, onChange: (Int) -> Unit) {
    val theme = theme
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(icon, color, 20.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, Fonts.body)
            T(thresholdDescription(value, hours), Fonts.caption, theme.secondaryTextColor)
        }
        IOSStepper(
            { onChange((value - step).coerceAtLeast(range.first)) },
            { onChange((value + step).coerceAtMost(range.last)) },
            value > range.first,
            value < range.last,
        )
    }
    RowDivider()
}

// MARK: - Organization

@Composable
fun TimelineOrganizationView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val organizations = if (vm.selectedTimeScope == TaskTimeScope.today) TimelineOrganization.entries else TimelineOrganization.entries.filter { it != TimelineOrganization.time }

    @Composable
    fun card(title: String, content: @Composable ColumnScope.() -> Unit) {
        Column(
            Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(theme.backgroundColor)
                .border(1.dp, theme.borderColor, RoundedCornerShape(16.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            T(title, systemFont(18, FontWeight.SemiBold))
            content()
        }
    }

    @Composable
    fun option(selected: Boolean, onClick: () -> Unit, content: @Composable RowScope.() -> Unit) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(if (selected) theme.primaryColor.copy(alpha = 0.1f) else theme.surfaceColor)
                .border(if (selected) 2.dp else 1.dp, if (selected) theme.primaryColor else theme.borderColor, RoundedCornerShape(12.dp))
                .tap(onClick = onClick)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            content = content,
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "organize_tasks".localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = { BarButton("done".localized, bold = true, color = theme.primaryColor, onClick = dismiss) },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 16.dp, bottom = 32.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            card("organization_mode_title".localized) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    organizations.forEach { organization ->
                        option(vm.organization == organization, { vm.organization = organization }) {
                            Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(organization.icon, theme.primaryColor, 18.dp) }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                T(organization.displayName, Fonts.body)
                                val description = when (organization) {
                                    TimelineOrganization.time -> "sort_by_time_description"
                                    TimelineOrganization.category -> "group_by_category_description"
                                    TimelineOrganization.priority -> "group_by_priority_description"
                                    TimelineOrganization.status -> "group_by_status_description"
                                    TimelineOrganization.eisenhower -> "group_by_urgency_importance_description"
                                    TimelineOrganization.none -> null
                                }
                                description?.let { T(it.localized, Fonts.caption, theme.secondaryTextColor) }
                            }
                            if (vm.organization == organization) SF("checkmark.circle.fill", theme.primaryColor, 20.dp)
                        }
                    }
                }
            }
            card("status_filter_title".localized) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    TaskStatusFilter.entries.forEach { status ->
                        val visible = status in vm.visibleStatuses
                        val lastVisible = visible && vm.visibleStatuses.size == 1
                        Box(Modifier.alpha(if (lastVisible) 0.8f else 1f)) {
                            option(visible, {
                                if (lastVisible) Haptics.heavy() else {
                                    Haptics.light()
                                    vm.toggleVisibleStatus(status)
                                }
                            }) {
                                Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(status.icon, colorFromHex(status.colorHex), 18.dp) }
                                Spacer(Modifier.width(4.dp))
                                T(status.displayName, Fonts.body, modifier = Modifier.weight(1f))
                                SF(if (visible) "checkmark.circle.fill" else "circle", if (visible) theme.primaryColor else theme.secondaryTextColor.copy(alpha = 0.5f), 22.dp)
                            }
                        }
                    }
                }
                T("status_visibility_footer".localized, Fonts.caption, theme.secondaryTextColor)
            }
            if (vm.selectedTimeScope == TaskTimeScope.today && vm.organization == TimelineOrganization.time) {
                card("time_sort_order_title".localized) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        TimeSortOrder.entries.forEach { order ->
                            option(vm.timeSortOrder == order, { vm.timeSortOrder = order }) {
                                Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
                                    SF(if (order == TimeSortOrder.ascending) "arrow.up" else "arrow.down", theme.secondaryTextColor, 16.dp)
                                }
                                T(order.displayName, Fonts.body, modifier = Modifier.weight(1f))
                                if (vm.timeSortOrder == order) SF("checkmark", theme.primaryColor, 20.dp)
                            }
                        }
                    }
                }
            }
            Row(
                Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(theme.primaryColor.copy(alpha = 0.1f))
                    .border(1.dp, theme.primaryColor.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                    .pressable { vm.resetView() }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SF("arrow.clockwise", theme.primaryColor, 20.dp)
                T("reset_to_default".localized, Fonts.headline, theme.primaryColor)
            }
        }
    }
}

// MARK: - Calendar with media

private data class DayStats(var taskCount: Int = 0, var photoCount: Int = 0, var voiceMemoCount: Int = 0, var notesCount: Int = 0, var hasJournal: Boolean = false) {
    val hasNotes: Boolean get() = notesCount > 0
}

private fun tasksOnDate(date: Date): List<TodoTask> = TaskManager.tasks.filter { TaskRules.isDayTask(it, date) }

private fun tasksForScope(scope: TaskTimeScope, start: Date): List<TodoTask> = TaskManager.tasks.filter { task ->
    if (task.timeScope != scope) return@filter false
    when (scope) {
        TaskTimeScope.week -> if (task.recurrence != null) task.occursInWeek(start)
        else task.scopeStartDate?.isSameDay(start) == true && task.scopeEndDate?.isSameDay(start.addingDays(6)) == true
        TaskTimeScope.month -> if (task.recurrence != null) task.occursInMonth(start) else task.scopeStartDate?.isSameMonth(start) == true
        TaskTimeScope.year -> if (task.recurrence != null) task.occursInYear(start) else task.scopeStartDate?.isSameYear(start) == true
        else -> true
    }
}

private fun dayStats(date: Date): DayStats {
    val tasks = tasksOnDate(date)
    val stats = DayStats(taskCount = tasks.size)
    for (task in tasks) {
        stats.photoCount += task.photos.count { it.createdAt.isSameDay(date) }
        stats.voiceMemoCount += task.voiceMemos.count { it.createdAt.isSameDay(date) }
        if (!task.completions[task.completionKey(date)]?.notes.isNullOrEmpty()) stats.notesCount++
    }
    stats.hasJournal = JournalManager.entriesByDay[date.startOfDay()]?.isEmpty == false
    return stats
}

private fun rangeStats(tasks: List<TodoTask>, start: Date?, endExclusive: Date?): DayStats {
    val stats = DayStats(taskCount = tasks.size)
    fun inRange(date: Date) = start == null || endExclusive == null || (date >= start && date < endExclusive)
    for (task in tasks) {
        stats.photoCount += task.photos.count { inRange(it.createdAt) }
        stats.voiceMemoCount += task.voiceMemos.count { inRange(it.createdAt) }
        if (task.completions.any { inRange(it.key) && !it.value.notes.isNullOrEmpty() }) stats.notesCount++
    }
    return stats
}

@Composable
fun MediaHubCalendarView(onSelect: (Date) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var displayedMonth by remember { mutableStateOf(YearMonth.from(vm.selectedDate.z())) }
    var selectedDay by remember { mutableStateOf<Date?>(vm.selectedDate.startOfDay()) }
    var scope by remember { mutableStateOf(TaskTimeScope.today) }
    var selectedWeek by remember { mutableStateOf<Date?>(null) }
    var selectedMonth by remember { mutableStateOf<Date?>(null) }
    var selectedYear by remember { mutableStateOf<Date?>(null) }
    var displayedYear by remember { mutableStateOf(now().yearNumber) }
    var isExpanded by remember { mutableStateOf(false) }
    val player = remember { AudioPlayerObject() }
    var playingMemoId by remember { mutableStateOf<UUID?>(null) }
    DisposableEffect(Unit) { onDispose { player.release() } }

    fun togglePlayback(memo: TaskVoiceMemo) {
        if (playingMemoId == memo.id && player.isPlaying) {
            player.pause()
            playingMemoId = null
        } else {
            player.release()
            player.play(memo.audioPath)
            playingMemoId = memo.id
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "calendar".localized,
            leading = {
                BarButton("today".localized, color = theme.primaryColor) {
                    displayedMonth = YearMonth.now()
                    selectedDay = now().startOfDay()
                }
            },
            trailing = {
                BarButton("done".localized, color = theme.accentColor) {
                    selectedDay?.let(onSelect)
                    dismiss()
                }
            },
        )
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            listOf(TaskTimeScope.today, TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year, TaskTimeScope.longTerm).forEach { item ->
                val selected = scope == item
                val color = if (selected) theme.backgroundColor else theme.textColor
                val name = when (item) {
                    TaskTimeScope.today -> "day"
                    TaskTimeScope.week -> "week"
                    TaskTimeScope.month -> "month"
                    TaskTimeScope.year -> "year"
                    else -> "long_term"
                }.localized
                Row(
                    Modifier
                        .clip(CircleShape)
                        .background(if (selected) theme.primaryColor else theme.surfaceColor)
                        .tap {
                            scope = item
                            if (item != TaskTimeScope.today) selectedDay = null
                        }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    SF(item.icon, color, 14.dp)
                    T(name, systemFont(13, FontWeight.Medium), color, maxLines = 1)
                }
            }
        }

        // Header
        if (isExpanded && scope == TaskTimeScope.today) {
            selectedDay?.let { day ->
                HeaderRow(day.format("EEEE, d MMM"), {
                    Haptics.light()
                    selectedDay = day.addingDays(-1)
                    displayedMonth = YearMonth.from(day.addingDays(-1).z())
                }, {
                    Haptics.light()
                    selectedDay = day.addingDays(1)
                    displayedMonth = YearMonth.from(day.addingDays(1).z())
                })
            }
        } else when (scope) {
            TaskTimeScope.today, TaskTimeScope.week -> HeaderRow(
                displayedMonth.atDay(1).instant().format("LLLL yyyy").replaceFirstChar { it.titlecase(appLocale) },
                { displayedMonth = displayedMonth.minusMonths(1) },
                { displayedMonth = displayedMonth.plusMonths(1) },
            )
            TaskTimeScope.month -> HeaderRow("$displayedYear", { displayedYear-- }, { displayedYear++ })
            TaskTimeScope.year -> {
                val decade = displayedYear / 10 * 10
                HeaderRow("$decade - ${decade + 9}", { displayedYear -= 10 }, { displayedYear += 10 })
            }
            else -> Unit
        }

        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val calendarHeight = if (isExpanded) 0.dp else minOf(maxHeight * 0.42f, 330.dp)
            Column(Modifier.fillMaxSize()) {
                if (!isExpanded && scope != TaskTimeScope.longTerm) {
                    Box(Modifier.fillMaxWidth().height(calendarHeight)) {
                        when (scope) {
                            TaskTimeScope.today -> DayGrid(displayedMonth, selectedDay) { selectedDay = it }
                            TaskTimeScope.week -> WeekGrid(displayedMonth, selectedWeek) { selectedWeek = it }
                            TaskTimeScope.month -> MonthGrid(displayedYear, selectedMonth) { selectedMonth = it }
                            else -> YearGrid(displayedYear, selectedYear) { selectedYear = it }
                        }
                    }
                    Box(Modifier.padding(vertical = 4.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                }
                Box(Modifier.weight(1f).fillMaxWidth()) {
                    when (scope) {
                        TaskTimeScope.today -> {
                            val day = selectedDay
                            if (day == null) SelectPrompt("select_day_to_view_media") else {
                                val stats = dayStats(day)
                                val tasks = tasksOnDate(day)
                                val entry = JournalManager.entriesByDay[day.startOfDay()]?.takeIf { !it.isEmpty }
                                DetailColumn(day.format("EEEE, d MMM"), stats, isExpanded, { isExpanded = !isExpanded }) {
                                    entry?.let { JournalCard(it) }
                                    if (tasks.isEmpty() && entry == null) {
                                        EmptyScope("calendar.badge.minus", "no_tasks_for_day", 40)
                                    } else tasks.forEach { task ->
                                        key(task.id) { CalendarTaskCard(task, day, player, playingMemoId, ::togglePlayback) }
                                    }
                                }
                            }
                        }
                        TaskTimeScope.week -> {
                            val start = selectedWeek
                            if (start == null) SelectPrompt("select_week_to_view") else {
                                val end = start.addingDays(6)
                                val tasks = tasksForScope(TaskTimeScope.week, start)
                                val title = if (start.isSameMonth(end)) "${start.format("d")} - ${end.format("d MMM yyyy")}" else "${start.format("d MMM")} - ${end.format("d MMM yyyy")}"
                                ScopeDetail(title, tasks, rangeStats(tasks, start, end.addingDays(1)), isExpanded, { isExpanded = !isExpanded }, "target", "no_weekly_tasks", start, end, player, playingMemoId, ::togglePlayback)
                            }
                        }
                        TaskTimeScope.month -> {
                            val start = selectedMonth
                            if (start == null) SelectPrompt("select_month_to_view") else {
                                val end = start.endOfMonth()
                                val tasks = tasksForScope(TaskTimeScope.month, start)
                                ScopeDetail(start.format("LLLL yyyy").replaceFirstChar { it.titlecase(appLocale) }, tasks, rangeStats(tasks, start, end.addingDays(1)), isExpanded, { isExpanded = !isExpanded }, "calendar", "no_monthly_tasks", start, end, player, playingMemoId, ::togglePlayback)
                            }
                        }
                        TaskTimeScope.year -> {
                            val start = selectedYear
                            if (start == null) SelectPrompt("select_year_to_view") else {
                                val end = start.endOfYear()
                                val tasks = tasksForScope(TaskTimeScope.year, start)
                                ScopeDetail(start.yearNumber.toString(), tasks, rangeStats(tasks, start, end.addingDays(1)), isExpanded, { isExpanded = !isExpanded }, "trophy.fill", "no_yearly_tasks", start, end, player, playingMemoId, ::togglePlayback)
                            }
                        }
                        else -> {
                            val tasks = tasksForScope(TaskTimeScope.longTerm, now())
                            ScopeDetail("long_term".localized, tasks, rangeStats(tasks, null, null), isExpanded, { isExpanded = !isExpanded }, "sparkles", "no_long_term_tasks", null, null, player, playingMemoId, ::togglePlayback)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderRow(title: String, onPrevious: () -> Unit, onNext: () -> Unit) {
    val theme = theme
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        BarIcon("chevron.left", theme.primaryColor, onClick = onPrevious)
        T(title, Fonts.headline, align = TextAlign.Center, modifier = Modifier.weight(1f))
        BarIcon("chevron.right", theme.primaryColor, onClick = onNext)
    }
}

@Composable
private fun WeekdayHeader() {
    val first = firstDayOfWeek
    Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, bottom = 8.dp)) {
        for (index in 0 until 7) {
            T(
                first.plus(index.toLong()).getDisplayName(JavaTextStyle.NARROW, appLocale),
                Fonts.caption.medium,
                theme.secondaryTextColor,
                TextAlign.Center,
                Modifier.weight(1f),
            )
        }
    }
}

private fun daysInMonth(month: YearMonth): List<LocalDate?> {
    val first = month.atDay(1)
    val leading = ((first.dayOfWeek.value - firstDayOfWeek.value) + 7) % 7
    val days = ArrayList<LocalDate?>()
    repeat(leading) { days += null }
    for (day in 1..month.lengthOfMonth()) days += month.atDay(day)
    while (days.size % 7 != 0) days += null
    return days
}

@Composable
private fun Dots(photo: Boolean, memo: Boolean, notes: Boolean, journal: Boolean, size: Int = 4, spacing: Int = 2) {
    Row(Modifier.height(6.dp), horizontalArrangement = Arrangement.spacedBy(spacing.dp), verticalAlignment = Alignment.CenterVertically) {
        if (photo) Box(Modifier.size(size.dp).background(Color.SysBlue, CircleShape))
        if (memo) Box(Modifier.size(size.dp).background(Color.SysPink, CircleShape))
        if (notes) Box(Modifier.size(size.dp).background(Color.SysOrange, CircleShape))
        if (journal) Box(Modifier.size(size.dp).background(Color.SysPurple, CircleShape))
    }
}

@Composable
private fun DayGrid(month: YearMonth, selected: Date?, onSelect: (Date) -> Unit) {
    val theme = theme
    Column(Modifier.fillMaxSize()) {
        WeekdayHeader()
        val weeks = daysInMonth(month).chunked(7)
        Column(Modifier.padding(horizontal = 12.dp).weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            weeks.forEach { week ->
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    week.forEach { day ->
                        Box(Modifier.weight(1f).fillMaxHeight()) {
                            if (day != null) {
                                val date = day.instant()
                                val isSelected = selected?.isSameDay(date) == true
                                val isToday = date.isToday()
                                val stats = remember(date, TaskManager.tasks, JournalManager.entriesByDay) { dayStats(date) }
                                Column(
                                    Modifier
                                        .fillMaxSize()
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(if (isSelected) theme.primaryColor else if (isToday) theme.primaryColor.copy(alpha = 0.1f) else Color.Transparent)
                                        .border(1.dp, if (isToday && !isSelected) theme.primaryColor.copy(alpha = 0.3f) else Color.Transparent, RoundedCornerShape(8.dp))
                                        .tap { onSelect(date) },
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
                                ) {
                                    T(
                                        "${day.dayOfMonth}",
                                        systemFont(14, if (isSelected) FontWeight.Bold else FontWeight.Medium),
                                        if (isSelected) theme.backgroundColor else if (isToday) theme.primaryColor else theme.textColor,
                                        maxLines = 1,
                                    )
                                    Dots(stats.photoCount > 0, stats.voiceMemoCount > 0, stats.hasNotes, stats.hasJournal)
                                    if (stats.taskCount > 0) {
                                        T("${stats.taskCount}", systemFont(9, FontWeight.SemiBold), if (isSelected) theme.backgroundColor.copy(alpha = 0.8f) else theme.secondaryTextColor, maxLines = 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WeekGrid(month: YearMonth, selected: Date?, onSelect: (Date) -> Unit) {
    val theme = theme
    val currentWeek = now().startOfWeek()
    Column(Modifier.fillMaxSize()) {
        WeekdayHeader()
        Column(Modifier.padding(horizontal = 12.dp).weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            daysInMonth(month).chunked(7).forEach { week ->
                val anyDay = week.firstOrNull { it != null }?.instant()
                val weekStart = anyDay?.startOfWeek()
                val stats = weekStart?.let { start -> remember(start, TaskManager.tasks) { rangeStats(tasksForScope(TaskTimeScope.week, start), start, start.addingDays(7)) } }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        week.forEachIndexed { index, day ->
                            Box(Modifier.weight(1f).fillMaxHeight()) {
                                if (day != null) {
                                    val date = day.instant()
                                    val start = date.startOfWeek()
                                    val isSelectedWeek = selected?.isSameDay(start) == true
                                    val isToday = date.isToday()
                                    val ghost = selected == null && start.isSameDay(currentWeek)
                                    val shape = RoundedCornerShape(
                                        topStart = if (index == 0) 8.dp else 0.dp,
                                        bottomStart = if (index == 0) 8.dp else 0.dp,
                                        topEnd = if (index == 6) 8.dp else 0.dp,
                                        bottomEnd = if (index == 6) 8.dp else 0.dp,
                                    )
                                    Box(
                                        Modifier
                                            .fillMaxSize()
                                            .clip(shape)
                                            .background(
                                                when {
                                                    isSelectedWeek -> theme.primaryColor
                                                    ghost -> theme.primaryColor.copy(alpha = 0.18f)
                                                    isToday -> theme.primaryColor.copy(alpha = 0.1f)
                                                    else -> Color.Transparent
                                                }
                                            )
                                            .border(1.dp, if (isToday && !isSelectedWeek) theme.primaryColor.copy(alpha = 0.3f) else Color.Transparent, shape)
                                            .tap { onSelect(start) },
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        T(
                                            "${day.dayOfMonth}",
                                            systemFont(14, if (isSelectedWeek) FontWeight.Bold else FontWeight.Medium),
                                            if (isSelectedWeek) theme.backgroundColor else if (isToday) theme.primaryColor else theme.textColor,
                                            maxLines = 1,
                                        )
                                    }
                                }
                            }
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(8.dp), contentAlignment = Alignment.Center) {
                        if (stats != null && stats.taskCount > 0) Dots(stats.photoCount > 0, stats.voiceMemoCount > 0, stats.hasNotes, false, spacing = 6)
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodCell(title: String, count: Int, stats: DayStats, isSelected: Boolean, isCurrent: Boolean, showTasksWord: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val theme = theme
    Column(
        modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) theme.primaryColor else if (isCurrent) theme.primaryColor.copy(alpha = 0.1f) else theme.surfaceColor)
            .border(1.dp, if (isCurrent && !isSelected) theme.primaryColor.copy(alpha = 0.3f) else Color.Transparent, RoundedCornerShape(12.dp))
            .tap(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
    ) {
        T(title, systemFont(15, if (isSelected) FontWeight.Bold else FontWeight.Medium), if (isSelected) theme.backgroundColor else if (isCurrent) theme.primaryColor else theme.textColor, maxLines = 1)
        if (count > 0) {
            T(
                if (showTasksWord) "$count " + "tasks".localized.lowercase(appLocale) else "$count",
                systemFont(10, FontWeight.SemiBold),
                if (isSelected) theme.backgroundColor.copy(alpha = 0.8f) else theme.secondaryTextColor,
                maxLines = 1,
            )
            if (showTasksWord) {
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (stats.photoCount > 0) {
                        SF("photo.fill", Color.SysBlue, 11.dp)
                        T("${stats.photoCount}", systemFont(10), Color.SysBlue)
                    }
                    if (stats.voiceMemoCount > 0) {
                        SF("waveform", Color.SysPink, 11.dp)
                        T("${stats.voiceMemoCount}", systemFont(10), Color.SysPink)
                    }
                }
            } else Dots(stats.photoCount > 0, stats.voiceMemoCount > 0, stats.notesCount > 0, false, size = 5, spacing = 3)
        }
    }
}

@Composable
private fun MonthGrid(year: Int, selected: Date?, onSelect: (Date) -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        (1..12).chunked(3).forEach { row ->
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { month ->
                    val date = LocalDate.of(year, month, 1).instant()
                    val stats = remember(date, TaskManager.tasks) { rangeStats(tasksForScope(TaskTimeScope.month, date), date, date.addingMonths(1)) }
                    PeriodCell(date.format("MMM"), stats.taskCount, stats, selected?.isSameMonth(date) == true, date.isSameMonth(now()), false, Modifier.weight(1f)) { onSelect(date) }
                }
            }
        }
    }
}

@Composable
private fun YearGrid(displayedYear: Int, selected: Date?, onSelect: (Date) -> Unit) {
    val decade = displayedYear / 10 * 10
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        (decade..decade + 9).chunked(2).forEach { row ->
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { year ->
                    val date = LocalDate.of(year, 1, 1).instant()
                    val stats = remember(date, TaskManager.tasks) { rangeStats(tasksForScope(TaskTimeScope.year, date), date, date.addingYears(1)) }
                    PeriodCell("$year", stats.taskCount, stats, selected?.yearNumber == year, now().yearNumber == year, true, Modifier.weight(1f)) { onSelect(date) }
                }
            }
        }
    }
}

@Composable
private fun SelectPrompt(key: String) {
    val theme = theme
    Column(Modifier.fillMaxWidth().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SF("hand.tap", theme.secondaryTextColor.copy(alpha = 0.5f), 30.dp)
        T(key.localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
    }
}

@Composable
private fun EmptyScope(icon: String, key: String, size: Int) {
    val theme = theme
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SF(icon, theme.secondaryTextColor.copy(alpha = 0.5f), size.dp)
        T(key.localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
    }
}

@Composable
private fun MediaBadge(icon: String, count: Int, color: Color) {
    Row(
        Modifier.clip(CircleShape).background(color.copy(alpha = 0.15f)).padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        SF(icon, color, 11.dp)
        T("$count", systemFont(11, FontWeight.SemiBold), color, maxLines = 1)
    }
}

@Composable
private fun DetailColumn(title: String, stats: DayStats, isExpanded: Boolean, onToggle: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().background(theme.backgroundColor).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            T(title, systemFont(14, FontWeight.SemiBold), modifier = Modifier.weight(1f))
            T("${stats.taskCount}", systemFont(11, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
            if (stats.photoCount > 0) MediaBadge("photo.fill", stats.photoCount, Color.SysBlue)
            if (stats.voiceMemoCount > 0) MediaBadge("waveform", stats.voiceMemoCount, Color.SysPink)
            if (stats.notesCount > 0) MediaBadge("note.text", stats.notesCount, Color.SysOrange)
            if (stats.hasJournal) MediaBadge("book.closed.fill", 1, Color.SysPurple)
            Row(
                Modifier
                    .clip(CircleShape)
                    .background(theme.primaryColor.copy(alpha = 0.12f))
                    .tap {
                        Haptics.light()
                        onToggle()
                    }
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                SF(if (isExpanded) "arrow.down.right.and.arrow.up.left" else "arrow.up.left.and.arrow.down.right", theme.primaryColor, 12.dp)
                T(if (isExpanded) "collapse".localized else "expand".localized, systemFont(11, FontWeight.SemiBold), theme.primaryColor, maxLines = 1)
            }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(vertical = 8.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

@Composable
private fun ScopeDetail(
    title: String, tasks: List<TodoTask>, stats: DayStats, isExpanded: Boolean, onToggle: () -> Unit,
    emptyIcon: String, emptyKey: String, rangeStart: Date?, rangeEnd: Date?,
    player: AudioPlayerObject, playingMemoId: UUID?, onToggleMemo: (TaskVoiceMemo) -> Unit,
) {
    DetailColumn(title, stats, isExpanded, onToggle) {
        if (tasks.isEmpty()) EmptyScope(emptyIcon, emptyKey, 30)
        else tasks.forEach { task -> key(task.id) { CalendarScopeTaskCard(task, rangeStart, rangeEnd, player, playingMemoId, onToggleMemo) } }
    }
}

@Composable
private fun JournalCard(entry: JournalEntry) {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.SysPurple.copy(alpha = 0.08f))
            .border(1.dp, Color.SysPurple.copy(alpha = 0.2f), RoundedCornerShape(12.dp))
            .pressable { presenter.sheet { JournalView(date = entry.date) } }
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF("book.closed.fill", Color.SysPurple, 16.dp)
            T("journal".localized, Fonts.subheadline.medium, Color.SysPurple, modifier = Modifier.weight(1f))
            entry.mood?.let { T(it.emoji, systemFont(16)) }
            SF("chevron.right", Color.SysGray, 14.dp)
        }
        if (entry.title.isNotEmpty()) T(entry.title, Fonts.subheadline.medium)
        if (entry.text.isNotEmpty()) T(entry.text, Fonts.caption, theme.secondaryTextColor)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            @Composable
            fun item(icon: String, count: Int, color: Color) {
                if (count == 0) return
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                    SF(icon, color, 12.dp)
                    T("$count", Fonts.caption, color)
                }
            }
            item("photo.fill", entry.photos.size, Color.SysBlue)
            item("waveform", entry.voiceMemos.size, Color.SysPink)
            item("tag.fill", entry.tags.size, Color.SysGreen)
        }
    }
}

@Composable
private fun Chip(text: String, color: Color, background: Color, icon: String? = null, iconColor: Color = color, shape: androidx.compose.ui.graphics.Shape = RoundedCornerShape(4.dp)) {
    Row(
        Modifier.clip(shape).background(background).padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        if (icon != null) SF(icon, iconColor, 11.dp)
        T(text, systemFont(10, FontWeight.Medium), color, maxLines = 1)
    }
}

@Composable
private fun CardFrame(task: TodoTask, content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(14.dp)
    val base = task.category?.let { colorFromHex(it.color) }
    Column(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(shape)
            .background(theme.surfaceColor)
            .then(if (base != null) Modifier.background(Brush.linearGradient(listOf(base.copy(alpha = 0.12f), base.copy(alpha = 0.05f), base.copy(alpha = 0.01f), Color.Transparent))) else Modifier)
            .border(1.dp, base?.copy(alpha = 0.22f) ?: theme.borderColor.copy(alpha = 0.6f), shape)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        content = content,
    )
}

@Composable
private fun AccentBar(color: Color) {
    Box(Modifier.size(width = 4.dp, height = 18.dp).clip(RoundedCornerShape(2.dp)).background(Brush.verticalGradient(listOf(color, color.copy(alpha = 0.7f)))))
}

private fun shortDuration(seconds: Double): String {
    val h = seconds.toInt() / 3600
    val m = seconds.toInt() % 3600 / 60
    return if (h > 0) (if (m > 0) "${h}h ${m}m" else "${h}h") else "${m}m"
}

@Composable
private fun PhotoStrip(photos: List<TaskPhoto>, label: String) {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            SF("photo", Color.SysBlue, 14.dp)
            T(label, Fonts.caption.medium, Color.SysBlue)
        }
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            photos.forEach { photo ->
                FileImage(
                    photo.thumbnailPath,
                    Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .border(1.dp, theme.borderColor.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
                        .tap { presenter.fullScreen { NavigationStack { FullScreenPhoto(photo.photoPath) } } },
                )
            }
        }
    }
}

@Composable
private fun MemoRow(memo: TaskVoiceMemo, isPlaying: Boolean, currentTime: Double, onTap: () -> Unit) {
    val theme = theme
    val progress = if (memo.duration > 0) (currentTime / memo.duration).toFloat().coerceIn(0f, 1f) else 0f
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Color.SysPink.copy(alpha = if (isPlaying) 0.15f else 0.08f))
            .border(1.dp, if (isPlaying) Color.SysPink.copy(alpha = 0.3f) else Color.Transparent, RoundedCornerShape(8.dp))
            .tap(onClick = onTap)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SF(if (isPlaying) "pause.circle.fill" else "play.circle.fill", Color.SysPink, 22.dp)
            T(memo.displayName, Fonts.caption, modifier = Modifier.weight(1f))
            if (isPlaying) T("${formatClock(currentTime)} / ${formatClock(memo.duration)}", Fonts.caption.monospacedDigit, Color.SysPink, maxLines = 1)
            else T(formatClock(memo.duration), Fonts.caption.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
        }
        if (isPlaying || currentTime > 0) {
            Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.SysPink.copy(alpha = 0.2f))) {
                Box(Modifier.fillMaxWidth(progress).fillMaxHeight().background(Color.SysPink))
            }
        }
    }
}

@Composable
private fun NotesBlock(notes: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            SF("note.text", Color.SysOrange, 14.dp)
            T("notes".localized, Fonts.caption.medium, Color.SysOrange)
        }
        T(
            notes, Fonts.caption, theme.secondaryTextColor,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(Color.SysOrange.copy(alpha = 0.08f))
                .border(1.dp, Color.SysOrange.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
                .padding(8.dp),
        )
    }
}

@Composable
private fun CalendarTaskCard(task: TodoTask, date: Date, player: AudioPlayerObject, playingMemoId: UUID?, onToggleMemo: (TaskVoiceMemo) -> Unit) {
    val theme = theme
    val categoryColor = task.category?.let { colorFromHex(it.color) } ?: theme.primaryColor
    val completion = task.completions[task.completionKey(date)]
    val isCompleted = completion?.isCompleted == true
    val photos = task.photos.filter { it.createdAt.isSameDay(date) }
    val memos = task.voiceMemos.filter { it.createdAt.isSameDay(date) }
    val notes = completion?.notes?.takeIf { it.isNotEmpty() }
    val hasMedia = photos.isNotEmpty() || memos.isNotEmpty() || notes != null || (completion?.difficultyRating != null && completion.qualityRating != null)

    CardFrame(task) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AccentBar(categoryColor)
            T(task.name, Fonts.headline, modifier = Modifier.weight(1f))
            Box(
                Modifier.tap {
                    if (isCompleted) Haptics.light() else Haptics.success()
                    TaskManager.toggleTaskCompletion(task.id, date)
                }
            ) { TaskStatusIcon(if (isCompleted) TaskProgressState.completed else TaskProgressState.todo, theme.secondaryTextColor.copy(alpha = 0.5f), size = 22.dp) }
        }
        Row(Modifier.padding(start = 12.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            task.category?.let { Chip(it.name, colorFromHex(it.color), colorFromHex(it.color).copy(alpha = 0.14f), shape = CircleShape) }
            if (task.hasSpecificTime) Chip(task.startTime.timeText(), theme.secondaryTextColor, theme.surfaceColor, "clock")
            else Chip("all_day".localized, Color.SysBlue, Color.SysBlue.copy(alpha = 0.12f))
            val priorityColor = colorFromHex(task.priority.colorHex)
            Chip(task.priority.displayName, priorityColor, priorityColor.copy(alpha = 0.12f), task.priority.icon)
            if (task.hasRewardPoints && task.rewardPoints > 0) Chip("${task.rewardPoints}pt", theme.textColor, Color.SysYellow.copy(alpha = 0.14f), "star.fill", Color.SysYellow)
            val actual = completion?.actualDuration
            when {
                actual != null && actual > 0 -> Chip(shortDuration(actual), Color.SysGreen, Color.SysGreen.copy(alpha = 0.12f), "hourglass")
                task.totalTrackedTime > 0 -> Chip(shortDuration(task.totalTrackedTime), Color.SysGreen, Color.SysGreen.copy(alpha = 0.12f), "hourglass")
                task.hasDuration && task.duration > 0 -> Chip(shortDuration(task.duration), theme.secondaryTextColor, theme.surfaceColor, "hourglass")
            }
            if (task.recurrence != null && task.currentStreak > 0) Chip("${task.currentStreak}", Color.SysOrange, Color.SysOrange.copy(alpha = 0.14f), "flame.fill")
            if (task.subtasks.isNotEmpty()) Chip("${completion?.completedSubtasks?.size ?: 0}/${task.subtasks.size}", theme.secondaryTextColor, theme.surfaceColor, "checklist")
        }
        task.description?.takeIf { it.isNotEmpty() }?.let { T(it, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(start = 12.dp)) }
        if (hasMedia) {
            Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.padding(vertical = 2.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                if (photos.isNotEmpty()) PhotoStrip(photos, "photos".localized)
                if (memos.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            SF("waveform", Color.SysPink, 14.dp)
                            T("voice_memos".localized, Fonts.caption.medium, Color.SysPink)
                        }
                        memos.forEach { memo -> MemoRow(memo, playingMemoId == memo.id && player.isPlaying, if (playingMemoId == memo.id) player.currentTime else 0.0) { onToggleMemo(memo) } }
                    }
                }
                notes?.let { NotesBlock(it) }
                val difficulty = completion?.difficultyRating
                val quality = completion?.qualityRating
                if (difficulty != null && quality != null) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        RatingChip("flame.fill", "difficulty".localized, "$difficulty/10", Color.SysRed)
                        RatingChip("star.fill", "quality".localized, "$quality/10", Color.SysGreen)
                    }
                }
            }
        }
    }
}

@Composable
private fun RatingChip(icon: String, label: String, value: String, color: Color) {
    Row(
        Modifier.clip(RoundedCornerShape(6.dp)).background(color.copy(alpha = 0.08f)).padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SF(icon, color, 13.dp)
        T(label, systemFont(10), theme.secondaryTextColor, maxLines = 1)
        T(value, systemFont(11, FontWeight.SemiBold), color, maxLines = 1)
    }
}

@Composable
private fun CalendarScopeTaskCard(task: TodoTask, rangeStart: Date?, rangeEnd: Date?, player: AudioPlayerObject, playingMemoId: UUID?, onToggleMemo: (TaskVoiceMemo) -> Unit) {
    val theme = theme
    val categoryColor = task.category?.let { colorFromHex(it.color) } ?: theme.primaryColor
    val start = rangeStart?.startOfDay()
    val endExclusive = rangeEnd?.startOfDay()?.addingDays(1)
    fun inRange(date: Date) = start == null || endExclusive == null || (date >= start && date < endExclusive)
    val photos = task.photos.filter { inRange(it.createdAt) }
    val memos = task.voiceMemos.filter { inRange(it.createdAt) }
    val completions = task.completions.filter { inRange(it.key) }.values
    val isCompleted = completions.any { it.isCompleted }
    val latest = completions.sortedByDescending { it.completionDate ?: distantPast }.firstOrNull()
    val notes = latest?.notes?.takeIf { it.isNotEmpty() }

    CardFrame(task) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AccentBar(categoryColor)
            T(task.name, Fonts.headline, modifier = Modifier.weight(1f))
            TaskStatusIcon(if (isCompleted) TaskProgressState.completed else TaskProgressState.todo, theme.secondaryTextColor.copy(alpha = 0.5f), size = 22.dp)
        }
        Row(Modifier.padding(start = 12.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            task.category?.let { Chip(it.name, colorFromHex(it.color), colorFromHex(it.color).copy(alpha = 0.14f), shape = CircleShape) }
            val priorityColor = colorFromHex(task.priority.colorHex)
            Chip(task.priority.displayName, priorityColor, priorityColor.copy(alpha = 0.12f), task.priority.icon)
            if (task.hasRewardPoints && task.rewardPoints > 0) Chip("${task.rewardPoints}pt", theme.textColor, Color.SysYellow.copy(alpha = 0.14f), "star.fill", Color.SysYellow)
            if (task.totalTrackedTime > 0) Chip(shortDuration(task.totalTrackedTime), Color.SysGreen, Color.SysGreen.copy(alpha = 0.12f), "hourglass")
        }
        task.description?.takeIf { it.isNotEmpty() }?.let { T(it, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(start = 12.dp)) }
        if (photos.isNotEmpty() || memos.isNotEmpty() || notes != null) {
            Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.padding(vertical = 2.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                if (photos.isNotEmpty()) PhotoStrip(photos, "${photos.size} " + "photos".localized.lowercase(appLocale))
                if (memos.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            SF("waveform", Color.SysPink, 14.dp)
                            T("${memos.size} " + "voice_memos".localized.lowercase(appLocale), Fonts.caption.medium, Color.SysPink)
                        }
                        memos.forEach { memo -> MemoRow(memo, playingMemoId == memo.id && player.isPlaying, if (playingMemoId == memo.id) player.currentTime else 0.0) { onToggleMemo(memo) } }
                    }
                }
                notes?.let { NotesBlock(it) }
            }
        }
    }
}
