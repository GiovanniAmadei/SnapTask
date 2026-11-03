package com.snaptask.app

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.format.FormatStyle
import java.util.UUID
import kotlin.math.roundToInt

private val focusColorDefault = "#4F46E5"
private val breakColorDefault = "#059669"

@Composable
private fun pomodoroColors(): Pair<Color, Color> {
    val focus by appStorage("pomodoroFocusColor", focusColorDefault)
    val pause by appStorage("pomodoroBreakColor", breakColorDefault)
    return colorFromHex(focus) to colorFromHex(pause)
}

// MARK: - Focus tab

@Composable
fun FocusTabView() {
    val theme = theme
    val presenter = LocalPresenter.current
    val tracker = TimeTrackerViewModel
    val pomodoro = PomodoroViewModel
    val started = tracker.activeSessions.filter { it.isRunning || it.elapsedTime > 0 || it.isPaused }

    fun openPomodoro() {
        if (!pomodoro.hasActiveTask) pomodoro.initializeGeneralSession()
        presenter.sheet { NavigationStack { PomodoroTabView() } }
    }
    fun openTimer(sessionId: UUID?) {
        presenter.sheet {
            if (sessionId != null) TimeTrackerView(sessionId = sessionId, presentationStyle = TimerPresentationStyle.fullscreen, allowExpand = false)
            else TimeTrackerView(mode = TrackingMode.simple, presentationStyle = TimerPresentationStyle.fullscreen, allowExpand = false)
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 24.dp + tabBarInset()),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        T("focus_mode".localized, Fonts.largeTitle.bold)
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            FocusModeCard("simple_timer".localized, "freeform_focus_session".localized, "stopwatch", Color.SysYellow, listOf(Color.SysYellow, Color.SysOrange)) {
                if (tracker.activeSessions.size < 2) openTimer(null)
            }
            FocusModeCard("pomodoro_technique".localized, "25min_work_sessions_5min_breaks".localized, "timer", Color.SysRed, listOf(Color.SysRed, Color.SysPink)) {
                if (pomodoro.hasActiveTask) {
                    presenter.sheet {
                        SessionConflictView(
                            currentSession = "pomodoro_session".localized,
                            newSession = "pomodoro_session".localized,
                            onCancel = {},
                            onSaveAndReplace = {
                                pomodoro.stop()
                                openPomodoro()
                            },
                            onDiscardAndReplace = {
                                pomodoro.stop()
                                openPomodoro()
                            },
                        )
                    }
                } else openPomodoro()
            }
        }
        if (started.isNotEmpty() || pomodoro.hasActiveTask) {
            FocusCard {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SF("play.circle.fill", theme.accentColor, 20.dp)
                    T("active_sessions".localized, Fonts.headline, modifier = Modifier.weight(1f))
                    T("${started.size} " + "timers".localized, Fonts.caption, theme.secondaryTextColor, maxLines = 1)
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    started.forEach { session -> key(session.id) { ActiveTimerSessionRow(session) { openTimer(session.id) } } }
                    if (pomodoro.hasActiveTask) ActivePomodoroSessionRow { openPomodoro() }
                }
            }
        }
        FocusCard {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SF("chart.bar.fill", Color.SysGreen, 20.dp)
                T("todays_focus".localized, Fonts.headline)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                StatItem("total_time".localized, formatFocusDuration(TaskManager.getTodaysTrackedTime()), Color.SysGreen)
                StatItem("sessions".localized, "${TaskManager.trackingSessions.count { it.startTime.isToday() }}", theme.accentColor)
            }
        }
        RecentSessionsCard()
    }
}

@Composable
private fun FocusCard(content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(if (theme.systemDark) 0.dp else 8.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        content = content,
    )
}

@Composable
private fun FocusModeCard(title: String, description: String, icon: String, color: Color, gradient: List<Color>, onClick: () -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(18.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .shadow(if (theme.systemDark) 0.dp else 8.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(1.2.dp, Brush.linearGradient(gradient.map { it.copy(alpha = 0.35f) }), shape)
            .pressable {
                Haptics.light()
                onClick()
            }
            .padding(18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.size(56.dp).background(Brush.linearGradient(gradient.map { it.copy(alpha = 0.15f) }), CircleShape), contentAlignment = Alignment.Center) {
            SF(icon, color, 26.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(title, Fonts.headline)
            T(description, Fonts.subheadline, theme.secondaryTextColor)
        }
        SF("chevron.right", theme.secondaryTextColor.copy(alpha = 0.7f), 16.dp)
    }
}

@Composable
private fun StatItem(title: String, value: String, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        T(title, Fonts.caption, theme.secondaryTextColor)
        T(value, Fonts.title2.bold, color, maxLines = 1)
    }
}

@Composable
private fun SessionRowFrame(color: Color, onClick: () -> Unit, content: @Composable RowScope.() -> Unit) {
    val dark = theme.isDark
    val shape = RoundedCornerShape(14.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(color.copy(alpha = if (dark) 0.15f else 0.08f))
            .border(1.dp, color.copy(alpha = if (dark) 0.35f else 0.25f), shape)
            .pressable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        content = content,
    )
}

@Composable
private fun ActiveTimerSessionRow(session: TrackingSession, onTap: () -> Unit) {
    val theme = theme
    SessionRowFrame(Color.SysOrange, onTap) {
        Box(Modifier.size(40.dp).background(Color.SysOrange.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
            SF("stopwatch.fill", Color.SysOrange, 18.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T("simple_timer".localized, Fonts.subheadline.semibold)
            T(session.taskName ?: "focus_session".localized, Fonts.caption, theme.secondaryTextColor)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T(formatElapsed(session.elapsedTime), Fonts.headline.bold.monospacedDigit, Color.SysOrange, maxLines = 1)
            val tint = if (session.isPaused) Color.SysOrange else Color.SysGreen
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(Modifier.size(6.dp).background(tint, CircleShape))
                T((if (session.isPaused) "paused" else "running").localized, Fonts.caption2.semibold, tint, maxLines = 1)
            }
        }
    }
}

@Composable
private fun ActivePomodoroSessionRow(onTap: () -> Unit) {
    val theme = theme
    val vm = PomodoroViewModel
    val working = vm.effectivePhase == PomodoroState.working
    val phaseColor = Color(if (working) 0xFF4F46E5 else 0xFF059669)
    SessionRowFrame(phaseColor, onTap) {
        Box(Modifier.size(40.dp).background(phaseColor.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
            SF(if (working) "brain.head.profile" else "cup.and.saucer.fill", phaseColor, 18.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T("pomodoro_timer".localized, Fonts.subheadline.semibold)
            T(vm.activeTask?.name ?: "focus_session".localized, Fonts.caption, theme.secondaryTextColor)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T(formatTimer(vm.timeRemaining), Fonts.headline.bold.monospacedDigit, phaseColor, maxLines = 1)
            val paused = vm.state == PomodoroState.paused
            val tint = if (paused) Color.SysOrange else if (working) Color.SysIndigo else Color.SysGreen
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(Modifier.size(6.dp).background(tint, CircleShape))
                T(if (paused) "paused".localized else if (working) "focus".localized else "break".localized, Fonts.caption2.semibold, tint, maxLines = 1)
            }
        }
    }
}

@Composable
private fun RecentSessionsCard() {
    val theme = theme
    val presenter = LocalPresenter.current
    val sessions = TaskManager.trackingSessions.sortedByDescending { it.startTime }
    FocusCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF("clock.fill", Color.SysOrange, 20.dp)
            T("recent_sessions".localized, Fonts.headline, modifier = Modifier.weight(1f))
            if (sessions.size > 3) {
                Row(
                    Modifier.tap { presenter.sheet { AllSessionsView() } },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    T("view_all".localized + " (${sessions.size})", Fonts.caption.medium, theme.accentColor, maxLines = 1)
                    SF("chevron.right", theme.accentColor, 12.dp)
                }
            }
        }
        val recent = sessions.take(3)
        if (recent.isEmpty()) {
            T("no_sessions_yet".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center, Modifier.fillMaxWidth().padding(vertical = 20.dp))
        } else {
            Column {
                recent.forEachIndexed { index, session ->
                    key(session.id) {
                        SessionRowWithActions(session, { presenter.sheet { SessionEditView(session) } }, { TaskManager.deleteTrackingSession(session) })
                    }
                    if (index < recent.lastIndex) Box(Modifier.padding(start = 12.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
                }
            }
        }
    }
}

@Composable
private fun SessionRow(session: TrackingSession) {
    val theme = theme
    val categoryColor = session.categoryId?.let { id ->
        CategoryManager.categories.firstOrNull { it.id == id }?.color
            ?: session.taskId?.let { TaskManager.task(it) }?.category?.color
    }?.let { colorFromHex(it) }
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.padding(end = 8.dp).size(width = 3.dp, height = 24.dp).clip(RoundedCornerShape(2.dp)).background(categoryColor ?: Color.Transparent))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(session.taskName ?: "general_focus".localized, Fonts.subheadline.medium)
            T(session.startTime.dateStyle(FormatStyle.MEDIUM) + ", " + session.startTime.timeText(), Fonts.caption, theme.secondaryTextColor)
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(formatFocusDuration(session.effectiveWorkTime), Fonts.subheadline.medium, maxLines = 1)
            T(session.mode.displayName, Fonts.caption, theme.secondaryTextColor, maxLines = 1)
        }
    }
}

@Composable
private fun SessionRowWithActions(session: TrackingSession, onEdit: () -> Unit, onDelete: () -> Unit) {
    val theme = theme
    val density = LocalDensity.current
    val actionWidth = with(density) { 140.dp.toPx() }
    val scope = rememberCoroutineScope()
    val offset = remember { Animatable(0f) }
    fun settle(target: Float) {
        scope.launch { offset.animateTo(target, spring(dampingRatio = 0.8f, stiffness = 300f)) }
    }
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))) {
        Row(Modifier.matchParentSize(), horizontalArrangement = Arrangement.End) {
            SwipeAction("pencil", "edit".localized, Color.SysOrange) {
                settle(0f)
                onEdit()
            }
            SwipeAction("trash", "delete".localized, Color.SysRed) {
                settle(0f)
                onDelete()
            }
        }
        Box(
            Modifier
                .offset { IntOffset(offset.value.roundToInt(), 0) }
                .background(theme.surfaceColor)
                .draggable(
                    rememberDraggableState { delta -> scope.launch { offset.snapTo((offset.value + delta).coerceIn(-actionWidth, 0f)) } },
                    Orientation.Horizontal,
                    onDragStopped = { settle(if (-offset.value > actionWidth / 2) -actionWidth else 0f) },
                )
                .then(if (offset.value < 0f) Modifier.tap { settle(0f) } else Modifier)
                .padding(vertical = 8.dp),
        ) { SessionRow(session) }
    }
}

@Composable
private fun SwipeAction(icon: String, title: String, color: Color, onClick: () -> Unit) {
    Column(
        Modifier.width(70.dp).fillMaxHeight().background(color).tap(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
    ) {
        SF(icon, Color.White, 18.dp)
        T(title, Fonts.caption2.semibold, Color.White, maxLines = 1)
    }
}

@Composable
internal fun AllSessionsView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val groups = TaskManager.trackingSessions
        .sortedByDescending { it.startTime }
        .groupBy { it.startTime.dateStyle(FormatStyle.MEDIUM) }
        .toList()
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("all_sessions".localized, leading = { BarButton("done".localized, color = theme.accentColor, onClick = dismiss) })
        FormPage(Modifier.weight(1f)) {
            groups.forEach { (day, sessions) ->
                FormSection(day) {
                    sessions.forEachIndexed { index, session ->
                        key(session.id) {
                            Box(Modifier.padding(horizontal = 12.dp)) {
                                SessionRowWithActions(session, { presenter.sheet { SessionEditView(session) } }, { TaskManager.deleteTrackingSession(session) })
                            }
                        }
                        if (index < sessions.lastIndex) RowDivider()
                    }
                }
            }
        }
    }
}

@Composable
fun SessionEditView(session: TrackingSession) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var startTime by remember { mutableStateOf(session.startTime) }
    val totalMinutes = (session.effectiveWorkTime / 60).toInt()
    var hours by remember { mutableStateOf(totalMinutes / 60) }
    var minutes by remember { mutableStateOf(totalMinutes % 60) }
    var categoryId by remember { mutableStateOf(session.categoryId) }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "edit_session".localized,
            leading = { BarButton("cancel".localized, color = theme.accentColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, bold = true, color = theme.accentColor) {
                    val duration = (hours * 60 + minutes) * 60.0
                    val category = categoryId?.let { id -> CategoryManager.categories.firstOrNull { it.id == id } }
                    TaskManager.updateTrackingSession(
                        session.copy(
                            startTime = startTime,
                            endTime = startTime.plusSeconds(duration.toLong()),
                            totalDuration = duration,
                            elapsedTime = duration,
                            pausedDuration = 0.0,
                            categoryId = category?.id,
                            categoryName = category?.name,
                        ),
                    )
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("timing".localized) {
                DateRow("start_time".localized, startTime, { startTime = it })
                Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("duration".localized, Fonts.body, modifier = Modifier.padding(start = 16.dp))
                    Row {
                        WheelPicker((0..23).toList(), hours, { hours = it }, { "$it h" }, Modifier.weight(1f), rowHeight = 32.dp, visibleRows = 3)
                        WheelPicker((0..59).toList(), minutes, { minutes = it }, { "$it m" }, Modifier.weight(1f), rowHeight = 32.dp, visibleRows = 3)
                    }
                }
            }
            FormSection("category".localized) {
                IOSMenu(
                    listOf(MenuItem("none".localized, checked = categoryId == null) { categoryId = null }) +
                        CategoryManager.categories.map { category ->
                            MenuItem(category.name, checked = categoryId == category.id) { categoryId = category.id }
                        },
                    Modifier.fillMaxWidth(),
                ) {
                    FormRow(
                        "category".localized,
                        value = CategoryManager.categories.firstOrNull { it.id == categoryId }?.name ?: "none".localized,
                        chevron = true,
                        divider = false,
                    )
                }
            }
            FormSection("info".localized) {
                FormRow("task".localized, value = session.taskName ?: "general_focus".localized)
                FormRow("mode".localized, value = session.mode.displayName)
                FormRow("device".localized, value = session.deviceDisplayInfo, divider = false)
            }
        }
    }
}

// MARK: - Session conflict

@Composable
fun SessionConflictView(
    currentSession: String,
    newSession: String,
    onCancel: () -> Unit,
    onSaveAndReplace: (() -> Unit)? = null,
    onDiscardAndReplace: (() -> Unit)? = null,
    onKeepBoth: (() -> Unit)? = null,
) {
    val theme = theme
    val dismiss = LocalDismiss.current
    Column(
        Modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp)
            .navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Column(Modifier.padding(top = 42.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(72.dp).background(Brush.radialGradient(listOf(theme.accentColor.copy(alpha = 0.18f), theme.accentColor.copy(alpha = 0.04f), Color.Transparent)), CircleShape), contentAlignment = Alignment.Center) {
                Box(
                    Modifier
                        .size(54.dp)
                        .background(theme.accentColor.copy(alpha = 0.12f), CircleShape)
                        .border(1.5.dp, theme.accentColor.copy(alpha = 0.35f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) { SF("exclamationmark.triangle.fill", theme.accentColor, 26.dp) }
            }
            T("session_conflict".localized, Fonts.title2.bold)
            T("active_session_running_desc".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center, Modifier.padding(horizontal = 32.dp))
        }
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ConflictCard("current_session".localized, currentSession, "play.circle.fill", Color.SysGreen)
            val active = PomodoroViewModel.activeTask
            ConflictCard("new_session".localized, if (active != null) "pomodoro".localized + ": ${active.name}" else newSession, "plus.circle.fill", theme.accentColor)
        }
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            fun act(block: () -> Unit) {
                Haptics.medium()
                dismiss()
                block()
            }
            onKeepBoth?.let { ConflictAction("keep_both".localized, "square.on.square.fill", theme.accentColor) { act(it) } }
            onSaveAndReplace?.let { ConflictAction("save_and_replace".localized, "checkmark.circle.fill", Color.SysGreen) { act(it) } }
            onDiscardAndReplace?.let { ConflictAction("discard_and_replace".localized, "trash.fill", Color.SysRed) { act(it) } }
            T(
                "cancel".localized,
                Fonts.subheadline.semibold,
                theme.secondaryTextColor,
                TextAlign.Center,
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(theme.surfaceColor)
                    .border(1.dp, theme.borderColor.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                    .pressable {
                        Haptics.light()
                        onCancel()
                        dismiss()
                    }
                    .padding(vertical = 14.dp),
            )
        }
    }
}

@Composable
private fun ConflictCard(title: String, name: String, icon: String, tint: Color) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(theme.surfaceColor).border(1.2.dp, tint.copy(alpha = 0.25f), shape).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(42.dp).background(tint.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, tint, 22.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T(title.uppercase(appLocale), systemFont(11, FontWeight.Bold), tint)
            T(name, Fonts.subheadline.semibold)
        }
    }
}

@Composable
private fun ConflictAction(title: String, icon: String, tint: Color, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(tint.copy(alpha = 0.08f))
            .border(1.dp, tint.copy(alpha = 0.22f), shape)
            .pressable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(36.dp).background(tint.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, tint, 18.dp) }
        T(title, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
        SF("chevron.right", theme.secondaryTextColor, 14.dp)
    }
}

// MARK: - Mode selection

@Composable
fun TrackingModeSelectionView(task: TodoTask, onSelect: (TrackingMode) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val tracker = TimeTrackerViewModel
    val pomodoro = PomodoroViewModel

    fun startMode(mode: TrackingMode) {
        dismiss()
        onSelect(mode)
    }
    fun check(mode: TrackingMode) {
        if (!tracker.hasActiveSession && !pomodoro.hasActiveTask) {
            startMode(mode)
            return
        }
        val name = when {
            tracker.hasActiveSession -> tracker.currentSession?.taskName?.let { "simple_timer".localized + ": $it" } ?: "simple_timer_session".localized
            else -> pomodoro.activeTask?.name?.let { "pomodoro".localized + ": $it" } ?: "pomodoro_session".localized
        }
        presenter.sheet {
            SessionConflictView(
                currentSession = name,
                newSession = mode.displayName,
                onCancel = {},
                onSaveAndReplace = {
                    if (tracker.hasActiveSession) tracker.saveCurrentSession()
                    if (pomodoro.hasActiveTask) pomodoro.stop()
                    startMode(mode)
                },
                onDiscardAndReplace = {
                    if (tracker.hasActiveSession) tracker.discardCurrentSession()
                    if (pomodoro.hasActiveTask) pomodoro.stop()
                    startMode(mode)
                },
                onKeepBoth = { startMode(mode) },
            )
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("select_mode".localized, trailing = { BarButton("cancel".localized, onClick = dismiss) })
        Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                T("track_task_format".localized(task.name), Fonts.title2.semibold, align = TextAlign.Center)
                T("choose_tracking_mode".localized, Fonts.subheadline, Color.Secondary, TextAlign.Center)
            }
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                TrackingModeCard(TrackingMode.simple, Color.SysYellow) { check(TrackingMode.simple) }
                TrackingModeCard(TrackingMode.pomodoro, Color.SysRed) { check(TrackingMode.pomodoro) }
            }
        }
    }
}

@Composable
private fun TrackingModeCard(mode: TrackingMode, tint: Color, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .shadow(2.dp, shape, clip = false)
            .clip(shape)
            .background(Color.SystemBackground)
            .pressable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.size(40.dp).background(tint.copy(alpha = 0.1f), CircleShape), contentAlignment = Alignment.Center) { SF(mode.icon, tint, 22.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(mode.displayName, Fonts.headline, Color.Primary)
            T(mode.description, Fonts.subheadline, Color.Secondary)
        }
        SF("chevron.right", Color.Secondary, 16.dp)
    }
}

// MARK: - Rings

/** The hero of the timers: ambient glow, plate, track and the ring on top. */
@Composable
private fun TimerRing(
    size: Dp,
    lineWidth: Dp,
    glowSize: Dp,
    glowColor: Color,
    glowOn: Boolean,
    trackColor: Color,
    plateColor: Color,
    progress: Float,
    ringColors: List<Color>,
    content: @Composable ColumnScope.() -> Unit,
) {
    val infinite = rememberInfiniteTransition(label = "glow")
    val pulse by infinite.animateFloat(0.7f, 1f, infiniteRepeatable(tween(2200, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "glowPulse")
    val animatedProgress by animateFloatAsState(progress, tween(300), label = "ring")
    val glow by animateFloatAsState(if (glowOn) 1f else 0.3f, tween(300), label = "glowOn")
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(glowSize)
                .alpha(glow * (if (glowOn) pulse else 1f))
                .background(Brush.radialGradient(listOf(glowColor, glowColor, Color.Transparent)), CircleShape),
        )
        Box(Modifier.size(size).clip(CircleShape).background(plateColor))
        Canvas(Modifier.size(size)) {
            val stroke = lineWidth.toPx()
            val inset = stroke / 2
            val arc = Size(this.size.width - stroke, this.size.height - stroke)
            drawArc(trackColor, 0f, 360f, false, Offset(inset, inset), arc, style = Stroke(stroke))
            if (animatedProgress > 0f) {
                drawArc(
                    Brush.linearGradient(ringColors, Offset.Zero, Offset(this.size.width, this.size.height)),
                    -90f,
                    360f * animatedProgress,
                    false,
                    Offset(inset, inset),
                    arc,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, content = content)
    }
}

// MARK: - Pomodoro

@Composable
fun PomodoroTabView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val navigator = LocalNavigator.current
    val vm = PomodoroViewModel
    val (focusColor, breakColor) = pomodoroColors()
    var showingCompletion by remember { mutableStateOf(false) }
    var completedFocusTime by remember { mutableStateOf(0.0) }
    // iOS clears the task here too when the session has not started; on Android whoever opens this
    // screen decides (see FocusTabView), so that a Pomodoro on a task stays on that task.
    LaunchedEffect(vm.state) {
        if (vm.state == PomodoroState.completed && !showingCompletion) {
            completedFocusTime = maxOf(1.0, vm.totalTrackedFocusTime)
            showingCompletion = true
        }
    }

    fun handleStop() {
        Haptics.medium()
        if (vm.state == PomodoroState.notStarted) {
            vm.stop()
            dismiss()
        } else {
            completedFocusTime = vm.totalTrackedFocusTime
            vm.pause()
            showingCompletion = true
        }
    }
    fun togglePlayPause() {
        if (vm.state == PomodoroState.notStarted || vm.state == PomodoroState.paused) {
            Haptics.medium()
            vm.start()
        } else {
            Haptics.light()
            vm.pause()
        }
    }

    AnimatedContent(
        showingCompletion,
        modifier = Modifier.fillMaxSize().background(theme.backgroundColor),
        transitionSpec = { fadeIn(tween(300)) + scaleIn(tween(300), 0.96f) togetherWith fadeOut(tween(200)) },
        label = "completion",
    ) { completion ->
        if (completion) {
            PomodoroCompletionView(vm.activeTask, completedFocusTime)
        } else {
            Column(Modifier.fillMaxSize()) {
                NavBar(
                    "pomodoro".localized,
                    leading = {
                        CircleIconButton("minus", theme.textColor, onClick = dismiss)
                    },
                    trailing = {
                        CircleIconButton("xmark", Color.SysRed) {
                            vm.stop()
                            vm.clearActiveTask()
                            dismiss()
                        }
                    },
                )
                PomodoroSessionView(focusColor, breakColor, ::handleStop, ::togglePlayPause, Modifier.weight(1f)) {
                    PomodoroScreenHeader(
                        vm.activeTask?.name ?: "general_focus_session".localized,
                        vm.activeTask?.category?.name,
                        vm.activeTask?.category?.let { colorFromHex(it.color) },
                        "${vm.currentSession}/${vm.totalSessions}",
                    ) {
                        navigator?.push { ContextualPomodoroSettingsView(if (vm.activeTask != null) PomodoroContext.task else PomodoroContext.general) }
                    }
                }
            }
        }
    }
}

@Composable
private fun CircleIconButton(icon: String, tint: Color, onClick: () -> Unit) {
    Box(Modifier.size(32.dp).background(tint.copy(alpha = 0.12f), CircleShape).tap(onClick = onClick), contentAlignment = Alignment.Center) {
        SF(icon, tint, 16.dp)
    }
}

@Composable
private fun PomodoroScreenHeader(title: String, subtitle: String?, accent: Color?, sessionText: String, onSettings: () -> Unit) {
    val theme = theme
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (accent != null) Box(Modifier.size(10.dp).background(accent, CircleShape))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(title, Fonts.title3.semibold)
                if (!subtitle.isNullOrEmpty()) T(subtitle, Fonts.caption, theme.secondaryTextColor)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier
                    .clip(CircleShape)
                    .background(theme.surfaceColor)
                    .border(1.dp, theme.borderColor.copy(alpha = 0.6f), CircleShape)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                T("session".localized, Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
                T(sessionText, Fonts.caption.semibold.monospacedDigit, maxLines = 1)
            }
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(30.dp).background(theme.accentColor.copy(alpha = 0.12f), CircleShape).tap(onClick = onSettings), contentAlignment = Alignment.Center) {
                SF("gear", theme.accentColor, 16.dp)
            }
        }
    }
}

@Composable
private fun PomodoroSessionView(
    focusColor: Color,
    breakColor: Color,
    onStop: () -> Unit,
    onTogglePlayPause: () -> Unit,
    modifier: Modifier = Modifier,
    header: @Composable () -> Unit,
) {
    val theme = theme
    val vm = PomodoroViewModel
    val working = vm.effectivePhase == PomodoroState.working
    val phaseColor = if (working) focusColor else breakColor
    val running = vm.state == PomodoroState.working || vm.state == PomodoroState.onBreak
    val inactive = vm.state == PomodoroState.notStarted || vm.state == PomodoroState.completed
    val primaryColor = if (inactive) theme.primaryColor else phaseColor

    val phaseLabel = when {
        vm.state == PomodoroState.paused -> "paused".localized
        working -> "focus_time".localized
        else -> "break_time".localized
    }
    val isLongBreakNext = vm.currentSession % maxOf(1, vm.settings.sessionsUntilLongBreak) == 0
    val breakMinutes = ((if (isLongBreakNext) vm.settings.longBreakDuration else vm.settings.breakDuration) / 60).toInt()
    val hint = when {
        vm.state == PomodoroState.paused -> "paused".localized
        vm.state == PomodoroState.completed -> null
        vm.state == PomodoroState.notStarted -> "focus_time".localized + " · ${(vm.settings.workDuration / 60).toInt()} " + "min_unit".localized
        working -> (if (isLongBreakNext) "long_break" else "short_break").localized + " · $breakMinutes " + "min_unit".localized
        vm.currentSession + 1 > vm.totalSessions -> "completed".localized
        else -> "session".localized + " ${vm.currentSession + 1}/${vm.totalSessions}"
    }

    BoxWithConstraints(modifier.fillMaxWidth()) {
    val pageHeight = maxHeight
    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = pageHeight),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
    Column {
        Box(Modifier.padding(start = 20.dp, end = 20.dp, top = 8.dp)) { header() }
        Box(Modifier.padding(top = 16.dp, bottom = 24.dp)) {
            TimerRing(
                224.dp, 8.dp, 270.dp, phaseColor.copy(alpha = 0.12f), running,
                theme.borderColor.copy(alpha = 0.3f), theme.surfaceColor.copy(alpha = 0.6f),
                vm.progress.toFloat(), listOf(phaseColor, phaseColor.copy(alpha = 0.7f)),
            ) {
                Row(
                    Modifier
                        .clip(CircleShape)
                        .background(phaseColor.copy(alpha = 0.12f))
                        .border(1.dp, phaseColor.copy(alpha = 0.25f), CircleShape)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Box(Modifier.size(7.dp).background(phaseColor, CircleShape))
                    T(phaseLabel, Fonts.caption.semibold, theme.secondaryTextColor, maxLines = 1)
                }
                Spacer(Modifier.height(8.dp))
                T(formatTimer(vm.timeRemaining), systemFont(46, FontWeight.Bold).monospacedDigit, phaseColor, maxLines = 1)
                Spacer(Modifier.height(8.dp))
                T("${(vm.progress * 100).toInt()}%", Fonts.caption.bold, theme.secondaryTextColor, maxLines = 1)
            }
        }
        val shape = RoundedCornerShape(18.dp)
        Column(
            Modifier
                .padding(horizontal = 20.dp)
                .fillMaxWidth()
                .shadow(if (theme.systemDark) 0.dp else 8.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(shape)
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor.copy(alpha = 0.35f), shape)
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                SF("timelapse", theme.accentColor, 15.dp)
                T("session_overview".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
                T("${(vm.timeRemaining / 60).toInt()} " + "min_unit".localized + " " + "left".localized, Fonts.footnote.medium, theme.secondaryTextColor, maxLines = 1)
            }
            ModernSessionTimeline(focusColor, breakColor)
            if (hint != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SF("arrow.turn.down.right", theme.secondaryTextColor, 12.dp)
                    T(hint, Fonts.caption, theme.secondaryTextColor)
                }
            }
        }
    }
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 24.dp).navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(22.dp), verticalAlignment = Alignment.CenterVertically) {
                ControlButton("forward.fill", 50.dp, 22.dp, phaseColor, inactive) { vm.skip() }
                ControlButton(if (running) "pause.fill" else "play.fill", 70.dp, 30.dp, primaryColor, false, pulsing = running, onClick = onTogglePlayPause)
                ControlButton("checkmark", 50.dp, 22.dp, Color.SysGreen, inactive, onClick = onStop)
            }
            AnimatedVisibility(!inactive, enter = fadeIn(tween(200)), exit = fadeOut(tween(200))) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SF("clock", theme.secondaryTextColor, 13.dp)
                    T("finishes_at".localized + " " + now().plusSeconds(vm.timeRemaining.toLong()).timeText(), Fonts.footnote, theme.secondaryTextColor, maxLines = 1)
                }
            }
        }
    }
    }
}

@Composable
private fun ControlButton(icon: String, size: Dp, iconSize: Dp, color: Color, disabled: Boolean, pulsing: Boolean = false, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (disabled) 0.9f else 1f, tween(200), label = "scale")
    val infinite = rememberInfiniteTransition(label = "halo")
    val halo by infinite.animateFloat(1f, 1.1f, infiniteRepeatable(tween(1000, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "haloPulse")
    Box(contentAlignment = Alignment.Center) {
    if (pulsing && !disabled) Box(Modifier.size(size * 1.2f).scale(halo).alpha(0.7f).background(color.copy(alpha = 0.3f), CircleShape))
    Box(
        Modifier
            .scale(scale)
            .size(size)
            .shadow(if (disabled) 0.dp else (if (size > 60.dp) 8.dp else 4.dp), CircleShape, clip = false, ambientColor = color, spotColor = color)
            .clip(CircleShape)
            .background(if (disabled) Brush.verticalGradient(listOf(Color.SysGray.copy(alpha = 0.3f), Color.SysGray.copy(alpha = 0.3f))) else Brush.verticalGradient(listOf(color, color.copy(alpha = 0.8f))))
            .pressable(enabled = !disabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { SF(icon, Color.White, iconSize) }
    }
}

@Composable
private fun ModernSessionTimeline(focusColor: Color, breakColor: Color) {
    val vm = PomodoroViewModel
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
            for (session in 1..vm.totalSessions) SessionIndicator(session, focusColor, breakColor)
        }
        SessionSegments(6.dp, 2.dp, focusColor, breakColor, Color.SysGray.copy(alpha = 0.2f), Color.SysGray.copy(alpha = 0.15f))
    }
}

/** One segment per session: work then break, proportional to their durations. */
@Composable
private fun SessionSegments(height: Dp, spacing: Dp, focusColor: Color, breakColor: Color, workTrack: Color, breakTrack: Color, modifier: Modifier = Modifier) {
    val vm = PomodoroViewModel
    val settings = vm.settings
    Row(modifier.fillMaxWidth().height(height), horizontalArrangement = Arrangement.spacedBy(spacing)) {
        for (session in 1..vm.totalSessions) {
            val divisor = maxOf(1, settings.sessionsUntilLongBreak)
            val breakDuration = if (session % divisor == 0) settings.longBreakDuration else settings.breakDuration
            val total = settings.workDuration + breakDuration
            val workPortion = (settings.workDuration / total).toFloat()
            var workFill = 0f
            var breakFill = 0f
            if (session < vm.currentSession) {
                workFill = 1f
                breakFill = 1f
            } else if (session == vm.currentSession) {
                if (vm.effectivePhase == PomodoroState.working) {
                    if (vm.state != PomodoroState.notStarted) workFill = (1 - vm.timeRemaining / settings.workDuration).toFloat().coerceIn(0f, 1f)
                } else {
                    workFill = 1f
                    breakFill = (1 - vm.timeRemaining / breakDuration).toFloat().coerceIn(0f, 1f)
                }
            }
            Row(Modifier.weight(1f).fillMaxHeight()) {
                Box(Modifier.weight(workPortion).fillMaxHeight().clip(RoundedCornerShape(height / 2)).background(workTrack)) {
                    Box(Modifier.fillMaxWidth(workFill).fillMaxHeight().clip(RoundedCornerShape(height / 2)).background(focusColor))
                }
                Box(Modifier.weight(1 - workPortion).fillMaxHeight().clip(RoundedCornerShape(height / 2)).background(breakTrack)) {
                    Box(Modifier.fillMaxWidth(breakFill).fillMaxHeight().clip(RoundedCornerShape(height / 2)).background(breakColor))
                }
            }
        }
    }
}

@Composable
private fun SessionIndicator(session: Int, focusColor: Color, breakColor: Color) {
    val vm = PomodoroViewModel
    val current = vm.currentSession
    val onBreak = vm.effectivePhase == PomodoroState.onBreak
    Column(Modifier.alpha(if (session <= current) 1f else 0.5f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        T("$session", Fonts.caption2.medium, if (session == current) Color.Primary else Color.Secondary, maxLines = 1)
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
            val workDone = session < current || session == current
            Box(Modifier.size(8.dp).background(if (workDone) focusColor else Color.SysGray.copy(alpha = 0.3f), CircleShape))
            if (session < current || (session == current && onBreak)) {
                val opacity = if (session == current) 0.3f + 0.7f * vm.progress.toFloat() else 1f
                Box(Modifier.size(6.dp).alpha(opacity).background(breakColor, CircleShape))
            }
        }
    }
}

@Composable
fun MiniPomodoroWidget(onTap: () -> Unit) {
    val theme = theme
    val vm = PomodoroViewModel
    val (focusColor, breakColor) = pomodoroColors()
    val shape = RoundedCornerShape(20.dp)
    val running = vm.state == PomodoroState.working || vm.state == PomodoroState.onBreak
    Row(
        Modifier
            .height(32.dp)
            .shadow(6.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .pressable(onClick = onTap)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            PulsingDot(if (vm.effectivePhase == PomodoroState.working) focusColor else breakColor, running, vm.state == PomodoroState.paused)
            T(if (vm.effectivePhase == PomodoroState.working) "focus".localized else "break".localized, systemFont(12, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
        }
        T(formatTimer(vm.timeRemaining), systemFont(14, FontWeight.SemiBold).monospacedDigit, maxLines = 1)
        SessionSegments(4.dp, 0.dp, focusColor, breakColor, theme.borderColor.copy(alpha = 0.3f), theme.borderColor.copy(alpha = 0.2f), Modifier.width(36.dp))
    }
}

@Composable
private fun PulsingDot(color: Color, pulsing: Boolean, dimmed: Boolean) {
    val infinite = rememberInfiniteTransition(label = "dot")
    val pulse by infinite.animateFloat(1f, 0.4f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dotPulse")
    Box(Modifier.size(8.dp).alpha(if (dimmed) 0.5f else if (pulsing) pulse else 1f).background(color, CircleShape))
}

@Composable
fun MiniTimerWidget(sessionId: UUID, onTap: () -> Unit) {
    val theme = theme
    val session = TimeTrackerViewModel.getSession(sessionId)
    val shape = RoundedCornerShape(20.dp)
    Row(
        Modifier
            .height(32.dp)
            .shadow(6.dp, shape, clip = false, ambientColor = Color.Black.copy(alpha = 0.15f), spotColor = Color.Black.copy(alpha = 0.15f))
            .clip(shape)
            .background(if (theme.systemDark) Color.Gray6 else Color.White)
            .pressable(onClick = onTap)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            PulsingDot(Color.SysYellow, session?.isRunning == true && session.isPaused != true, session?.isPaused == true)
            T(if (session?.isPaused == true) "paused".localized else "timer".localized, systemFont(12, FontWeight.Medium), Color.Secondary, maxLines = 1)
        }
        T(TimeTrackerViewModel.formattedElapsedTime(sessionId), systemFont(14, FontWeight.SemiBold).monospacedDigit, Color.Primary, maxLines = 1)
        T(session?.taskName ?: "focus".localized, systemFont(12, FontWeight.Medium), Color.Secondary, maxLines = 1, modifier = Modifier.widthIn(max = 90.dp))
    }
}

// MARK: - Pomodoro settings

private data class PomodoroPreset(val id: String, val name: String, val subtitle: String, val icon: String, val work: Int, val shortBreak: Int, val longBreak: Int, val sessions: Int, val sessionsUntilLong: Int)

private val pomodoroPresets = listOf(
    PomodoroPreset("classic", "Classic", "25 · 5 · 4", "circle.grid.2x2.fill", 25, 5, 15, 4, 4),
    PomodoroPreset("deep", "Deep", "50 · 10 · 3", "brain.head.profile", 50, 10, 20, 3, 3),
    PomodoroPreset("sprint", "Sprint", "15 · 3 · 6", "bolt.fill", 15, 3, 10, 6, 4),
)

@Composable
fun ContextualPomodoroSettingsView(context: PomodoroContext) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val (focusColor, breakColor) = pomodoroColors()
    var local by remember { mutableStateOf(PomodoroSettingsManager.settings(context)) }
    var useTimeDuration by remember { mutableStateOf(local.totalDuration > 0) }
    val matching = pomodoroPresets.firstOrNull { p ->
        (local.workDuration / 60).toInt() == p.work && (local.breakDuration / 60).toInt() == p.shortBreak &&
            (local.longBreakDuration / 60).toInt() == p.longBreak && local.totalSessions == p.sessions && local.sessionsUntilLongBreak == p.sessionsUntilLong
    }?.id

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            (if (context == PomodoroContext.general) "general_pomodoro_settings" else "task_pomodoro_settings").localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, bold = true, color = theme.primaryColor) {
                    PomodoroSettingsManager.updateSettings(local, context)
                    if (PomodoroViewModel.context == context) PomodoroViewModel.applySettingsToCurrentSession()
                    Haptics.success()
                    dismiss()
                }
            },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 24.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SettingsSectionCard("info.circle.fill", theme.accentColor, "about".localized) {
                T((if (context == PomodoroContext.general) "general_focus_sessions_description" else "task_pomodoro_sessions_description").localized, Fonts.footnote, theme.secondaryTextColor)
            }
            SettingsSectionCard("wand.and.stars", focusColor, "presets".localized) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    pomodoroPresets.forEach { preset ->
                        PresetChip(preset, matching == preset.id, focusColor, Modifier.weight(1f)) {
                            val applied = local.copy(
                                workDuration = preset.work * 60.0,
                                breakDuration = preset.shortBreak * 60.0,
                                longBreakDuration = preset.longBreak * 60.0,
                                totalSessions = preset.sessions,
                                sessionsUntilLongBreak = preset.sessionsUntilLong,
                            )
                            local = applied.copy(totalDuration = applied.estimatedTotalTime / 60)
                            Haptics.light()
                        }
                    }
                }
            }
            SettingsSectionCard("timer", focusColor, "work_session".localized + " & " + "break".localized) {
                DurationStepperRow("brain.head.profile", focusColor, "duration".localized, (local.workDuration / 60).toInt(), 1..120, 5, "min_unit".localized) { local = local.copy(workDuration = it * 60.0) }
                CardDivider()
                DurationStepperRow("cup.and.saucer.fill", breakColor, "short_break".localized, (local.breakDuration / 60).toInt(), 1..60, 1, "min_unit".localized) { local = local.copy(breakDuration = it * 60.0) }
                CardDivider()
                DurationStepperRow("moon.zzz.fill", breakColor, "long_break".localized, (local.longBreakDuration / 60).toInt(), 1..120, 5, "min_unit".localized) { local = local.copy(longBreakDuration = it * 60.0) }
            }
            SettingsSectionCard("square.stack.3d.up.fill", theme.accentColor, "session_configuration".localized) {
                ThemedSegmentedPicker(useTimeDuration, listOf(false, true), { useTimeDuration = it }, label = { T((if (it) "total_duration" else "number_of_sessions").localized, Fonts.footnote.medium, maxLines = 1) })
                if (useTimeDuration) {
                    DurationStepperRow("clock.fill", theme.accentColor, "total_duration".localized, local.totalDuration.toInt(), 30..480, 15, "min_unit".localized) {
                        local = local.copy(totalDuration = it.toDouble(), totalSessions = local.sessionsForDuration(it.toDouble()))
                    }
                    InfoRow("estimated_sessions".localized, "${local.totalSessions}")
                } else {
                    DurationStepperRow("number", theme.accentColor, "total_sessions".localized, local.totalSessions, 1..20, 1, "") {
                        val updated = local.copy(totalSessions = it)
                        local = updated.copy(totalDuration = updated.estimatedTotalTime / 60)
                    }
                    InfoRow("estimated_duration".localized, formatFocusDuration(local.estimatedTotalTime))
                }
                CardDivider()
                DurationStepperRow("arrow.triangle.2.circlepath", breakColor, "sessions_until_long_break".localized, local.sessionsUntilLongBreak, 1..10, 1, "") { local = local.copy(sessionsUntilLongBreak = it) }
            }
            val workSeconds = local.totalSessions * local.workDuration
            val totalSeconds = local.estimatedTotalTime
            val breakSeconds = maxOf(0.0, totalSeconds - workSeconds)
            val workRatio = if (totalSeconds > 0) (workSeconds / totalSeconds).toFloat() else 0f
            SettingsSectionCard("chart.pie.fill", theme.accentColor, "summary".localized) {
                Row(Modifier.fillMaxWidth().height(10.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    if (workRatio > 0f) Box(Modifier.weight(workRatio).fillMaxHeight().clip(RoundedCornerShape(4.dp)).background(Brush.horizontalGradient(listOf(focusColor, focusColor.copy(alpha = 0.7f)))))
                    if (workRatio < 1f) Box(Modifier.weight(1 - workRatio).fillMaxHeight().clip(RoundedCornerShape(4.dp)).background(Brush.horizontalGradient(listOf(breakColor, breakColor.copy(alpha = 0.7f)))))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    SummaryLegend(focusColor, "work_time".localized, formatFocusDuration(workSeconds), Modifier.weight(1f))
                    SummaryLegend(breakColor, "break_time".localized, formatFocusDuration(breakSeconds), Modifier.weight(1f))
                }
                CardDivider()
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("total_time".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
                    T(formatFocusDuration(totalSeconds), Fonts.subheadline.bold.monospacedDigit, focusColor, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun CardDivider() = Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.borderColor.copy(alpha = 0.5f)))

@Composable
private fun SettingsSectionCard(icon: String, tint: Color, title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().themedCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF(icon, tint, 16.dp)
            T(title, Fonts.subheadline.semibold)
        }
        content()
    }
}

@Composable
private fun DurationStepperRow(icon: String, tint: Color, title: String, value: Int, range: IntRange, step: Int, unit: String, onChange: (Int) -> Unit) {
    val theme = theme
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(22.dp).background(tint.copy(alpha = 0.14f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, tint, 14.dp) }
        T(title, Fonts.subheadline, modifier = Modifier.weight(1f))
        Row(
            Modifier
                .clip(CircleShape)
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor.copy(alpha = 0.6f), CircleShape)
                .padding(horizontal = 6.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            @Composable
            fun button(name: String, enabled: Boolean, next: Int) {
                Box(
                    Modifier
                        .size(24.dp)
                        .alpha(if (enabled) 1f else 0.4f)
                        .tap(enabled = enabled) {
                            onChange(next)
                            Haptics.light()
                        },
                    contentAlignment = Alignment.Center,
                ) { SF(name, theme.primaryColor, 13.dp) }
            }
            button("minus", value > range.first, (value - step).coerceAtLeast(range.first))
            T(if (unit.isEmpty()) "$value" else "$value $unit", Fonts.footnote.semibold.monospacedDigit, align = TextAlign.Center, maxLines = 1, modifier = Modifier.widthIn(min = 54.dp))
            button("plus", value < range.last, (value + step).coerceAtMost(range.last))
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    val theme = theme
    Row(verticalAlignment = Alignment.CenterVertically) {
        T(label, Fonts.footnote, theme.secondaryTextColor, modifier = Modifier.weight(1f))
        T(value, Fonts.footnote.semibold, maxLines = 1)
    }
}

@Composable
private fun SummaryLegend(color: Color, label: String, value: String, modifier: Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.size(8.dp).background(color, CircleShape))
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            T(label, Fonts.caption2, theme.secondaryTextColor)
            T(value, Fonts.caption.semibold.monospacedDigit, maxLines = 1)
        }
    }
}

@Composable
private fun PresetChip(preset: PomodoroPreset, selected: Boolean, focusColor: Color, modifier: Modifier, onClick: () -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier
            .clip(shape)
            .background(if (selected) Brush.verticalGradient(listOf(focusColor, focusColor.copy(alpha = 0.8f))) else Brush.verticalGradient(listOf(theme.surfaceColor, theme.surfaceColor)))
            .border(if (selected) 2.dp else 1.dp, if (selected) focusColor else theme.borderColor.copy(alpha = 0.6f), shape)
            .pressable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SF(preset.icon, if (selected) Color.White else focusColor, 18.dp)
        T(preset.name, Fonts.footnote.semibold, if (selected) Color.White else theme.textColor, maxLines = 1)
        T(preset.subtitle, Fonts.caption2.monospacedDigit, if (selected) Color.White.copy(alpha = 0.85f) else theme.secondaryTextColor, maxLines = 1)
    }
}

/** `PomodoroColorsView`, opened from the customization settings. */
@Composable
fun PomodoroColorsView() {
    val theme = theme
    var focus by appStorage("pomodoroFocusColor", focusColorDefault)
    var pause by appStorage("pomodoroBreakColor", breakColorDefault)
    val options = listOf("#4F46E5", "#7C3AED", "#EC4899", "#EF4444", "#F97316", "#EAB308", "#059669", "#0D9488", "#0891B2", "#4338CA")
    val focusColor = colorFromHex(focus)
    val breakColor = colorFromHex(pause)

    @Composable
    fun grid(selected: String, onSelect: (String) -> Unit) {
        Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            options.chunked(5).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    row.forEach { hex ->
                        val color = colorFromHex(hex)
                        val isSelected = selected == hex
                        val scale by animateFloatAsState(if (isSelected) 1.1f else 1f, tween(200), label = "dot")
                        Box(Modifier.size(42.dp), contentAlignment = Alignment.Center) {
                            if (isSelected) Box(Modifier.size(42.dp).border(2.dp, color, CircleShape))
                            Box(
                                Modifier
                                    .scale(scale)
                                    .size(32.dp)
                                    .background(color, CircleShape)
                                    .border(if (isSelected) 3.dp else 0.dp, Color.White, CircleShape)
                                    .tap { onSelect(hex) },
                            )
                        }
                    }
                }
            }
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("colors".localized)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Column(
                Modifier
                    .padding(start = 16.dp, end = 16.dp, top = 8.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.Gray6)
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                T("preview".localized, Fonts.headline)
                Box(contentAlignment = Alignment.Center) {
                    Canvas(Modifier.size(120.dp)) {
                        val stroke = 6.dp.toPx()
                        val arc = Size(size.width - stroke, size.height - stroke)
                        drawArc(focusColor.copy(alpha = 0.2f), 0f, 360f, false, Offset(stroke / 2, stroke / 2), arc, style = Stroke(stroke))
                        drawArc(Brush.linearGradient(listOf(focusColor, focusColor.copy(alpha = 0.7f))), -90f, 216f, false, Offset(stroke / 2, stroke / 2), arc, style = Stroke(stroke, cap = StrokeCap.Round))
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        T("15:00", systemFont(20, FontWeight.Bold), focusColor)
                        T("focus".localized, Fonts.caption, Color.Secondary)
                    }
                }
                Row(Modifier.padding(horizontal = 20.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    Box(Modifier.weight(1f).height(6.dp).clip(CircleShape).background(Brush.horizontalGradient(listOf(focusColor, focusColor.copy(alpha = 0.7f)))))
                    Box(Modifier.width(40.dp).height(6.dp).alpha(0.5f).clip(CircleShape).background(Brush.horizontalGradient(listOf(breakColor, breakColor.copy(alpha = 0.7f)))))
                }
            }
            FormSection("focus_time".localized) { grid(focus) { focus = it } }
            FormSection("break_time".localized) { grid(pause) { pause = it } }
        }
    }
}

// MARK: - Time tracker

enum class TimerPresentationStyle { sheet, fullscreen }

@Composable
fun TimeTrackerView(
    sessionId: UUID? = null,
    task: TodoTask? = null,
    mode: TrackingMode = TrackingMode.simple,
    presentationStyle: TimerPresentationStyle,
    allowExpand: Boolean,
) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val vm = TimeTrackerViewModel
    val resolvedTask = remember {
        task ?: sessionId?.let { vm.getSession(it) }?.taskId?.let { TaskManager.task(it) }
    }
    val resolvedMode = remember { sessionId?.let { vm.getSession(it)?.mode } ?: mode }
    var currentId by remember {
        mutableStateOf(sessionId ?: vm.activeSessions.firstOrNull { it.taskId == resolvedTask?.id }?.id)
    }
    val session = currentId?.let { vm.getSession(it) }
    val compact = presentationStyle == TimerPresentationStyle.sheet
    val completed = vm.completedSession

    fun playPause() {
        val id = currentId ?: vm.startSession(resolvedTask, resolvedMode).also { currentId = it }
        val current = vm.getSession(id)
        when {
            current?.isRunning != true -> {
                Haptics.medium()
                vm.startTimer(id)
            }
            current.isPaused -> {
                Haptics.medium()
                vm.resumeSession(id)
            }
            else -> {
                Haptics.light()
                vm.pauseSession(id)
            }
        }
    }
    fun complete() {
        Haptics.medium()
        currentId?.let { vm.stopSession(it) }
    }
    fun close() {
        currentId?.let { vm.removeSession(it) }
        dismiss()
    }

    val showCompletion = vm.showingCompletion && completed != null
    AnimatedContent(
        showCompletion,
        modifier = Modifier
            .animateContentSize(tween(300))
            .then(if (compact && !showCompletion) Modifier.fillMaxWidth().height(410.dp) else Modifier.fillMaxWidth().fillMaxHeight(if (compact) 0.92f else 1f))
            .background(theme.backgroundColor),
        transitionSpec = { fadeIn(tween(300)) + scaleIn(tween(300), 0.96f) togetherWith fadeOut(tween(200)) },
        label = "trackerCompletion",
    ) { completion ->
        val finished = vm.completedSession
        if (completion && finished != null) {
            TimeTrackingCompletionView(
                resolvedTask,
                finished,
                onSave = {
                    currentId?.let { vm.saveSession(it) }
                    dismiss()
                },
                onDiscard = {
                    currentId?.let { vm.discardSession(it) }
                    dismiss()
                },
                onContinue = { vm.continueAfterCompletion() },
            )
        } else if (compact) {
            CompactTimer(resolvedTask, session, currentId, allowExpand, dismiss, {
                val id = currentId
                dismiss()
                presenter.sheet {
                    if (id != null) TimeTrackerView(sessionId = id, presentationStyle = TimerPresentationStyle.fullscreen, allowExpand = false)
                    else TimeTrackerView(task = resolvedTask, mode = resolvedMode, presentationStyle = TimerPresentationStyle.fullscreen, allowExpand = false)
                }
            }, ::close, ::playPause, ::complete)
        } else {
            FullscreenTimer(resolvedTask, session, currentId, dismiss, ::close, ::playPause, ::complete)
        }
    }
}

@Composable
private fun StatePill(session: TrackingSession?, dotSize: Dp, font: androidx.compose.ui.text.TextStyle, readyText: Boolean) {
    val theme = theme
    val paused = session?.isPaused == true
    val running = session?.isRunning == true
    if (paused || running) {
        val tint = if (paused) Color.SysOrange else Color.SysGreen
        Row(
            Modifier
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.12f))
                .border(0.8.dp, tint.copy(alpha = 0.3f), CircleShape)
                .padding(horizontal = 8.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Box(Modifier.size(dotSize).background(tint, CircleShape))
            T((if (paused) "paused" else "running").localized.uppercase(appLocale), font, tint, maxLines = 1)
        }
    } else if (readyText) {
        T("ready_to_start".localized, systemFont(10, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
    }
}

@Composable
private fun CompactTimer(
    task: TodoTask?, session: TrackingSession?, sessionId: UUID?, allowExpand: Boolean,
    onCollapse: () -> Unit, onExpand: () -> Unit, onClose: () -> Unit, onPlayPause: () -> Unit, onComplete: () -> Unit,
) {
    val theme = theme
    val active = session?.isRunning == true || session?.isPaused == true
    val categoryColor = task?.category?.let { colorFromHex(it.color) }
    val pillColor = categoryColor ?: theme.accentColor
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 14.dp), contentAlignment = Alignment.Center) {
            Row(
                Modifier.clip(CircleShape).background(pillColor.copy(alpha = 0.14f)).padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                if (task != null) Box(Modifier.size(7.dp).background(pillColor, CircleShape)) else SF("stopwatch.fill", pillColor, 11.dp)
                T(task?.category?.name?.uppercase(appLocale) ?: "TIMER".localized, systemFont(10, FontWeight.Bold), pillColor, maxLines = 1)
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(34.dp).shadow(if (theme.systemDark) 0.dp else 4.dp, CircleShape, clip = false).clip(CircleShape).background(theme.surfaceColor).tap(onClick = onCollapse),
                    contentAlignment = Alignment.Center,
                ) { SF("minus", theme.textColor, 16.dp) }
                Spacer(Modifier.weight(1f))
                if (allowExpand) {
                    Box(Modifier.padding(end = 8.dp).size(34.dp).background(theme.accentColor.copy(alpha = 0.12f), CircleShape).tap(onClick = onExpand), contentAlignment = Alignment.Center) {
                        SF("arrow.up.left.and.arrow.down.right", theme.accentColor, 15.dp)
                    }
                }
                Box(Modifier.size(34.dp).background(Color.SysRed.copy(alpha = 0.12f), CircleShape).tap(onClick = onClose), contentAlignment = Alignment.Center) {
                    SF("xmark", Color.SysRed, 15.dp)
                }
            }
        }
        T(task?.name ?: "simple_timer".localized, Fonts.title3.bold, align = TextAlign.Center, modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 8.dp))
        Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
        TimerRing(
            142.dp, 6.dp, 170.dp, theme.accentColor.copy(alpha = 0.14f), session?.isRunning == true,
            theme.borderColor.copy(alpha = 0.35f), theme.surfaceColor, 1f,
            if (session?.isRunning == true) listOf(theme.accentColor, theme.primaryColor) else listOf(theme.borderColor.copy(alpha = 0.4f), theme.borderColor.copy(alpha = 0.4f)),
        ) {
            T(sessionId?.let { TimeTrackerViewModel.formattedElapsedTime(it) } ?: "00:00", systemFont(28, FontWeight.Bold).monospacedDigit, maxLines = 1)
            Spacer(Modifier.height(5.dp))
            StatePill(session, 5.dp, systemFont(9, FontWeight.Bold), true)
        }
        Spacer(Modifier.weight(1f).heightIn(min = 8.dp))
        TimerControls(session, active, 64.dp, 26.dp, 52.dp, 22.dp, 24.dp, onPlayPause, onComplete)
        Spacer(Modifier.height(20.dp).navigationBarsPadding())
    }
}

@Composable
private fun TimerControls(
    session: TrackingSession?, active: Boolean, mainSize: Dp, mainIcon: Dp, checkSize: Dp, checkIcon: Dp, spacing: Dp,
    onPlayPause: () -> Unit, onComplete: () -> Unit,
) {
    val theme = theme
    val scale by animateFloatAsState(if (active) 1f else 0.95f, tween(200), label = "check")
    val running = session?.isRunning == true && session.isPaused != true
    Row(horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(mainSize)
                .shadow(8.dp, CircleShape, clip = false, ambientColor = theme.accentColor, spotColor = theme.accentColor)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(theme.accentColor, theme.primaryColor)))
                .pressable(onClick = onPlayPause),
            contentAlignment = Alignment.Center,
        ) { SF(if (running) "pause.fill" else "play.fill", Color.White, mainIcon) }
        Box(
            Modifier
                .scale(scale)
                .alpha(if (active) 1f else 0.4f)
                .size(checkSize)
                .clip(CircleShape)
                .background(Color.SysGreen.copy(alpha = 0.14f))
                .border(1.5.dp, Color.SysGreen.copy(alpha = 0.35f), CircleShape)
                .pressable(enabled = active, onClick = onComplete),
            contentAlignment = Alignment.Center,
        ) { SF("checkmark", Color.SysGreen, checkIcon) }
    }
}

@Composable
private fun FullscreenTimer(
    task: TodoTask?, session: TrackingSession?, sessionId: UUID?,
    onCollapse: () -> Unit, onClose: () -> Unit, onPlayPause: () -> Unit, onComplete: () -> Unit,
) {
    val theme = theme
    val active = session?.isRunning == true || session?.isPaused == true
    Column(Modifier.fillMaxSize().navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(34.dp).shadow(if (theme.systemDark) 0.dp else 3.dp, CircleShape, clip = false).clip(CircleShape).background(theme.surfaceColor).tap(onClick = onCollapse), contentAlignment = Alignment.Center) {
                SF("minus", theme.textColor, 16.dp)
            }
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(34.dp).background(Color.SysRed.copy(alpha = 0.12f), CircleShape).tap(onClick = onClose), contentAlignment = Alignment.Center) {
                SF("xmark", Color.SysRed, 16.dp)
            }
        }
        Spacer(Modifier.height(40.dp))
        if (task != null) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    task.category?.let { Box(Modifier.size(8.dp).background(colorFromHex(it.color), CircleShape)) }
                    T(task.name, systemFont(22, FontWeight.Bold), align = TextAlign.Center)
                }
                T("focus_session".localized, systemFont(14, FontWeight.Medium), theme.secondaryTextColor)
            }
        } else {
            T("simple_timer".localized, systemFont(24, FontWeight.Bold))
        }
        Spacer(Modifier.height(40.dp))
        TimerRing(
            210.dp, 8.dp, 250.dp, theme.accentColor.copy(alpha = 0.12f), session?.isRunning == true,
            theme.borderColor.copy(alpha = 0.3f), theme.surfaceColor.copy(alpha = 0.6f), 1f,
            if (session?.isRunning == true) listOf(theme.accentColor, theme.primaryColor) else listOf(theme.borderColor.copy(alpha = 0.4f), theme.borderColor.copy(alpha = 0.4f)),
        ) {
            T(sessionId?.let { TimeTrackerViewModel.formattedElapsedTime(it) } ?: "00:00", systemFont(42, FontWeight.Bold).monospacedDigit, maxLines = 1)
            Spacer(Modifier.height(8.dp))
            StatePill(session, 6.dp, Fonts.caption2.bold, false)
        }
        Spacer(Modifier.height(24.dp))
        T(
            if (session?.isRunning == true) (if (session.isPaused) "tap_play_to_resume" else "session_in_progress").localized else "ready_to_start".localized,
            Fonts.subheadline.medium,
            theme.secondaryTextColor,
            TextAlign.Center,
        )
        Spacer(Modifier.weight(1f))
        TimerControls(session, active, 70.dp, 28.dp, 56.dp, 22.dp, 28.dp, onPlayPause, onComplete)
        Spacer(Modifier.height(40.dp))
    }
}

// MARK: - Completion

/** Records the time where the user chose, as `saveToStatistics` does on iOS. */
private fun saveToStatistics(categoryId: UUID?, timeSpent: Double, taskName: String? = null, taskId: UUID? = null, color: String = "#6366F1") {
    val key = when {
        categoryId != null -> "category_${categoryId.uuidString}"
        taskId != null && taskName != null -> "task_${taskId.uuidString}".also { TimeTrackingStore.setCategoryMetadata(it, taskName, color) }
        else -> "uncategorized"
    }
    val data = TimeTrackingStore.load().toMutableMap()
    val dateKey = now().startOfDay().toString()
    val day = (data[dateKey] ?: emptyMap()).toMutableMap()
    day[key] = (day[key] ?: 0.0) + timeSpent / 3600.0
    data[dateKey] = day
    TimeTrackingStore.save(data)
}

@Composable
fun PomodoroCompletionView(task: TodoTask?, focusTimeCompleted: Double) {
    val dismiss = LocalDismiss.current
    val vm = PomodoroViewModel
    val placeholderName = "general_focus_session".localized

    fun finish() {
        vm.stop()
        vm.clearActiveTask()
        dismiss()
    }

    FocusCompletionContent(
        titleKey = "pomodoro_complete",
        subtitleKey = "you_focused_for",
        placeholderKey = "task_name_placeholder",
        taskName = task?.name ?: placeholderName,
        seconds = focusTimeCompleted,
        task = task,
        mode = null,
        preselected = task?.category,
        onSave = { name, time, trackAsTask, category ->
            val hasTask = task != null && TaskManager.task(task.id) != null
            val asTask = trackAsTask && hasTask
            val session = TrackingSession(
                taskId = if (asTask) task?.id else null,
                taskName = if (asTask) name else category?.name ?: name,
                mode = TrackingMode.pomodoro,
                categoryId = if (asTask) task?.category?.id else category?.id,
                categoryName = if (asTask) task?.category?.name else category?.name,
                elapsedTime = time,
                totalDuration = time,
                isCompleted = true,
                endTime = now(),
            )
            val today = now().startOfDay()
            if (hasTask && task != null && (asTask || category != null)) {
                TaskManager.toggleTaskCompletion(task.id, today)
                TaskManager.addTrackedTime(time, task.id)
                TaskManager.updateTaskRating(task.id, actualDuration = time, date = today)
            }
            TaskManager.saveTrackingSession(session)
            when {
                asTask && task != null -> saveToStatistics(task.category?.id, time, name, task.id, task.category?.color ?: "#6366F1")
                category != null -> saveToStatistics(category.id, time)
                else -> saveToStatistics(null, time)
            }
            finish()
        },
        onContinue = dismiss,
        onSkip = ::finish,
    )
}

@Composable
fun TimeTrackingCompletionView(task: TodoTask?, session: TrackingSession?, onSave: () -> Unit, onDiscard: () -> Unit, onContinue: () -> Unit) {
    FocusCompletionContent(
        titleKey = "focus_session_complete",
        subtitleKey = "focused_for",
        placeholderKey = "enter_task_name",
        taskName = task?.name ?: session?.taskName ?: "focus_session".localized,
        seconds = session?.effectiveWorkTime ?: 0.0,
        task = task,
        mode = session?.mode,
        preselected = task?.category ?: session?.categoryId?.let { id -> CategoryManager.categories.firstOrNull { it.id == id } },
        onSave = { name, time, trackAsTask, category ->
            val today = now().startOfDay()
            val exists = task != null && TaskManager.task(task.id) != null
            fun saveSession(categoryId: UUID?, categoryName: String?) {
                session?.let {
                    TaskManager.saveTrackingSession(it.copy(categoryId = categoryId, categoryName = categoryName, totalDuration = time, elapsedTime = time, lastModifiedDate = now()))
                }
            }
            if (trackAsTask && task != null) {
                if (exists) {
                    val current = TaskManager.task(task.id)
                    TaskManager.toggleTaskCompletion(task.id, today)
                    TaskManager.updateTaskRating(task.id, actualDuration = time, date = today)
                    if (current?.category == null) {
                        // Without a category the time shows under the task's own name in the statistics.
                        val data = TimeTrackingStore.load().toMutableMap()
                        val dateKey = today.toString()
                        val day = (data[dateKey] ?: emptyMap()).toMutableMap()
                        val added = time / 3600.0
                        val uncategorized = day["uncategorized"] ?: 0.0
                        if (uncategorized > 0) {
                            if (uncategorized - added > 0) day["uncategorized"] = uncategorized - added else day.remove("uncategorized")
                        }
                        val taskKey = "task_${task.id.uuidString}"
                        day[taskKey] = (day[taskKey] ?: 0.0) + added
                        data[dateKey] = day
                        TimeTrackingStore.setCategoryMetadata(taskKey, name, "#6366F1")
                        TimeTrackingStore.save(data)
                    }
                    saveSession(current?.category?.id, current?.category?.name)
                } else {
                    saveToStatistics(null, time, "$name (deleted)", task.id)
                }
            } else if (category != null) {
                if (exists && task != null) {
                    TaskManager.toggleTaskCompletion(task.id, today)
                    TaskManager.updateTaskRating(task.id, actualDuration = time, date = today)
                    saveSession(category.id, category.name)
                }
                saveToStatistics(category.id, time)
            } else if (exists && task != null) {
                TaskManager.toggleTaskCompletion(task.id, today)
                TaskManager.updateTaskRating(task.id, actualDuration = time, date = today)
                saveSession(null, null)
            } else {
                saveToStatistics(null, time)
            }
            onSave()
        },
        onContinue = onContinue,
        onSkip = onDiscard,
    )
}

@Composable
private fun FocusCompletionContent(
    titleKey: String,
    subtitleKey: String,
    placeholderKey: String,
    taskName: String,
    seconds: Double,
    task: TodoTask?,
    mode: TrackingMode?,
    preselected: Category?,
    onSave: (name: String, seconds: Double, trackAsTask: Boolean, category: Category?) -> Unit,
    onContinue: () -> Unit,
    onSkip: () -> Unit,
) {
    val theme = theme
    var name by remember { mutableStateOf(taskName) }
    val totalMinutes = (seconds / 60).toInt()
    var hours by remember { mutableStateOf(totalMinutes / 60) }
    var minutes by remember { mutableStateOf(totalMinutes % 60) }
    var editing by remember { mutableStateOf(false) }
    var trackAsTask by remember { mutableStateOf(false) }
    var selectedCategory by remember { mutableStateOf(preselected) }
    val focusTime = (hours * 3600 + minutes * 60).toDouble()
    val canSave = focusTime > 0
    val shape = RoundedCornerShape(18.dp)
    val others = CategoryManager.categories.filter { it.id != task?.category?.id }

    fun save() {
        Haptics.success()
        onSave(name, focusTime, trackAsTask, selectedCategory)
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "focus_session".localized,
            showBack = false,
            trailing = { BarButton("save".localized, enabled = canSave, bold = true, color = theme.accentColor, onClick = ::save) },
        )
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Column(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.size(96.dp), contentAlignment = Alignment.Center) {
                    Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(theme.accentColor.copy(alpha = 0.15f), Color.Transparent)), CircleShape))
                    Box(Modifier.size(84.dp).background(Brush.linearGradient(listOf(theme.accentColor.copy(alpha = 0.2f), Color.SysGreen.copy(alpha = 0.2f))), CircleShape))
                    SF("checkmark.circle.fill", theme.accentColor, 50.dp)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    T(titleKey.localized, Fonts.title2.bold, align = TextAlign.Center)
                    T(subtitleKey.localized + " " + formatFocusDuration(focusTime), Fonts.subheadline, theme.secondaryTextColor)
                }
            }
            Column(
                Modifier
                    .padding(horizontal = 20.dp)
                    .fillMaxWidth()
                    .shadow(if (theme.systemDark) 0.dp else 8.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                    .clip(shape)
                    .background(theme.surfaceColor)
                    .border(1.dp, theme.borderColor.copy(alpha = 0.4f), shape)
                    .padding(18.dp)
                    .animateContentSize(tween(200)),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SF("slider.horizontal.3", theme.accentColor, 15.dp)
                    T("session_details".localized, Fonts.headline.semibold, modifier = Modifier.weight(1f))
                    T((if (editing) "done" else "edit").localized, Fonts.subheadline.semibold, theme.accentColor, maxLines = 1, modifier = Modifier.tap { editing = !editing })
                }
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    CompletionField("task_name".localized) {
                        if (editing) {
                            PlainField(
                                name, { name = it }, placeholderKey.localized,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(theme.backgroundColor.copy(alpha = 0.6f))
                                    .border(1.dp, theme.borderColor.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                                    .padding(10.dp),
                            )
                        } else {
                            Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                task?.category?.let { Box(Modifier.size(10.dp).background(colorFromHex(it.color), CircleShape)) }
                                T(name, Fonts.body.medium)
                            }
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(0.5.dp).alpha(0.3f).background(theme.divider))
                    CompletionField("focus_time".localized) {
                        if (editing) {
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(theme.backgroundColor.copy(alpha = 0.5f)).padding(8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    T("hours".localized, Fonts.caption2, theme.secondaryTextColor)
                                    WheelPicker((0..23).toList(), hours, { hours = it }, { "$it" }, Modifier.width(80.dp), rowHeight = 36.dp, visibleRows = 3)
                                }
                                T(":", Fonts.title2.bold, modifier = Modifier.padding(top = 16.dp))
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    T("minutes".localized, Fonts.caption2, theme.secondaryTextColor)
                                    WheelPicker((0..59).toList(), minutes, { minutes = it }, { "%02d".format(it) }, Modifier.width(80.dp), rowHeight = 36.dp, visibleRows = 3)
                                }
                            }
                        } else {
                            Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                SF("clock", theme.accentColor, 15.dp)
                                T(formatFocusDuration(focusTime), Fonts.body.semibold)
                            }
                        }
                    }
                    if (mode != null) {
                        Box(Modifier.fillMaxWidth().height(0.5.dp).alpha(0.3f).background(theme.divider))
                        CompletionField("mode".localized) {
                            Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                SF(mode.icon, Color.SysOrange, 15.dp)
                                T(mode.displayName, Fonts.body.medium)
                            }
                        }
                    }
                    task?.category?.let { category ->
                        Box(Modifier.fillMaxWidth().height(0.5.dp).alpha(0.3f).background(theme.divider))
                        CompletionField((if (mode != null) "original_category" else "category").localized) {
                            Row(Modifier.padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(Modifier.size(10.dp).background(colorFromHex(category.color), CircleShape))
                                T(category.name, Fonts.body.medium)
                            }
                        }
                    }
                }
            }
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                T("track_time_in".localized, Fonts.headline.semibold)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TrackingOptionCard("this_task_only".localized, name, "target", task?.category?.color ?: "#6366F1", trackAsTask) {
                        trackAsTask = true
                        selectedCategory = null
                    }
                    task?.category?.let { category ->
                        TrackingOptionCard(category.name, "category".localized, "folder.fill", category.color, selectedCategory?.id == category.id && !trackAsTask) {
                            selectedCategory = category
                            trackAsTask = false
                        }
                    }
                    others.forEach { category ->
                        key(category.id) {
                            TrackingOptionCard(category.name, "category".localized, "folder.fill", category.color, selectedCategory?.id == category.id && !trackAsTask) {
                                selectedCategory = category
                                trackAsTask = false
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 20.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .alpha(if (canSave) 1f else 0.5f)
                    .shadow(8.dp, RoundedCornerShape(16.dp), clip = false, ambientColor = theme.accentColor, spotColor = theme.accentColor)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(theme.accentColor, theme.primaryColor)))
                    .pressable(enabled = canSave, onClick = ::save)
                    .padding(vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SF("checkmark.circle.fill", Color.White, 18.dp)
                T("save_and_finish".localized, Fonts.body.semibold, Color.White, maxLines = 1)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(theme.accentColor.copy(alpha = 0.12f))
                        .pressable {
                            Haptics.light()
                            onContinue()
                        }
                        .padding(vertical = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SF("play.circle.fill", theme.accentColor, 17.dp)
                    T("continue".localized, Fonts.subheadline.semibold, theme.accentColor, maxLines = 1)
                }
                Row(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(theme.surfaceColor)
                        .border(1.dp, theme.borderColor.copy(alpha = 0.3f), RoundedCornerShape(14.dp))
                        .pressable {
                            Haptics.medium()
                            onSkip()
                        }
                        .padding(vertical = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SF("xmark.circle", theme.secondaryTextColor, 17.dp)
                    T("skip".localized, Fonts.subheadline.medium, theme.secondaryTextColor, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun CompletionField(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        T(label, Fonts.caption2.medium, theme.secondaryTextColor)
        content()
    }
}

@Composable
private fun TrackingOptionCard(title: String, subtitle: String, icon: String, colorHex: String, selected: Boolean, onClick: () -> Unit) {
    val theme = theme
    val color = colorFromHex(colorHex)
    val shape = RoundedCornerShape(16.dp)
    val scale by animateFloatAsState(if (selected) 1.01f else 1f, spring(dampingRatio = 0.7f, stiffness = 500f), label = "option")
    Row(
        Modifier
            .scale(scale)
            .fillMaxWidth()
            .clip(shape)
            .background(if (selected) color.copy(alpha = 0.08f) else theme.surfaceColor)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) color.copy(alpha = 0.6f) else theme.borderColor.copy(alpha = 0.4f), shape)
            .tap {
                Haptics.light()
                onClick()
            }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(42.dp).background(color.copy(alpha = 0.18f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, color, 20.dp) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T(title, Fonts.body.semibold)
            T(subtitle, Fonts.caption, theme.secondaryTextColor)
        }
        Box(
            Modifier.size(22.dp).border(if (selected) 2.dp else 1.5.dp, if (selected) color else theme.borderColor.copy(alpha = 0.6f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { if (selected) Box(Modifier.size(12.dp).background(color, CircleShape)) }
    }
}
