package com.snaptask.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.composed
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.onLongClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState
import java.time.format.FormatStyle
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private val vm = TimelineViewModel

val TaskTimeScope.timelineMenuName: String get() = if (this == TaskTimeScope.today) "day".localized else displayName

/** Screen-level actions of the home, so cards deep in the lists can reach them. */
object TimelineActions {
    fun openDetail(presenter: Presenter, taskId: UUID, date: Date = vm.selectedDate) {
        presenter.sheet { NavigationStack { TaskDetailView(taskId = taskId, targetDate = date) } }
    }

    fun addFromCalendar(presenter: Presenter, event: CalendarFeedEvent) {
        presenter.sheet {
            TaskFormView(
                initialDate = event.startDate,
                initialTimeScope = TaskTimeScope.today,
                initialName = event.title,
                preserveTime = !event.isAllDay,
                onSave = { task ->
                    MainScope.launch { TaskManager.addTask(task) }
                    CalendarEventsFeed.markAdded(event, task.id)
                },
            )
        }
    }

    fun newTask(presenter: Presenter, initialDate: Date? = null) {
        presenter.sheet { TaskCreationOptionsView(initialDate = initialDate, hasSpecificTime = initialDate != null) }
    }
}

@Composable
fun TimelineView() {
    remember {
        vm.restore()
        true
    }
    val theme = theme
    val presenter = LocalPresenter.current
    var selectedDayOffset by remember { mutableStateOf(daysBetween(now(), vm.selectedDate).toInt()) }

    LaunchedEffect(vm.selectedDate) {
        val offset = daysBetween(now(), vm.selectedDate).toInt()
        if (offset != selectedDayOffset) selectedDayOffset = offset
    }
    LaunchedEffect(AppEvents.openQuickAdd) {
        if (AppEvents.openQuickAdd > 0) {
            TimelineActions.newTask(presenter)
            AppEvents.openQuickAdd = 0
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        Box(Modifier.fillMaxWidth().background(theme.surfaceColor).statusBarsPadding())
        Column(Modifier.alpha(vm.scopeTransitionProgress)) {
            TimelineHeaderView(selectedDayOffset, { selectedDayOffset = it })
            Box(Modifier.padding(horizontal = 16.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
            // The inbox is a quick list: no view mode, grouping or filter controls.
            if (vm.selectedTimeScope != TaskTimeScope.inbox) {
                ViewControlBarView()
                Box(Modifier.padding(horizontal = 16.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth()) {
            if (vm.viewMode == TimelineViewMode.timeline && vm.selectedTimeScope == TaskTimeScope.today) {
                TimelineContentView()
            } else {
                TaskListView()
            }
        }
    }
}

// MARK: - Header

@Composable
private fun SquareHeaderButton(icon: String, active: Boolean = false, onClick: () -> Unit, overlay: @Composable BoxScope.() -> Unit = {}) {
    val theme = theme
    Box(
        Modifier
            .size(34.dp)
            .pressable(onClick = onClick)
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .shadow(2.dp, RoundedCornerShape(8.dp), ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(RoundedCornerShape(8.dp))
                .background(if (active) theme.primaryColor else theme.primaryColor.copy(alpha = 0.12f))
                .background(theme.backgroundColor.copy(alpha = 0f))
                .border(1.dp, theme.primaryColor.copy(alpha = 0.35f), RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center,
        ) {
            SF(icon, if (active) Color.White else theme.primaryColor, 18.dp)
        }
        overlay()
    }
}

@Composable
private fun CircleHeaderButton(icon: String, enabled: Boolean = true, size: androidx.compose.ui.unit.Dp = 18.dp, onClick: () -> Unit) {
    val theme = theme
    Box(
        Modifier
            .size(32.dp)
            .clip(CircleShape)
            .background(theme.primaryColor.copy(alpha = 0.1f))
            .pressable(enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SF(icon, theme.primaryColor, size)
    }
}

@Composable
private fun TimelineHeaderView(selectedDayOffset: Int, setOffset: (Int) -> Unit) {
    val theme = theme
    val presenter = LocalPresenter.current
    val scope = vm.selectedTimeScope
    val hideDaysBar = AppSettings.hideDaysBar

    Column(Modifier.fillMaxWidth().background(theme.surfaceColor)) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(60.dp)
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
            // Title: the largest size that fits; week ranges fall back to the numeric form.
            Column(
                Modifier
                    .weight(1f, fill = false)
                    .pressable {
                        if (!vm.isCurrentPeriod) {
                            Haptics.selection()
                            setOffset(0)
                            vm.navigateToToday()
                        }
                    }
            ) {
                val texts = listOfNotNull(vm.currentPeriodString, vm.compactPeriodString)
                FitText(texts, listOf(22, 20, 18, 17), theme.textColor)
                AnimatedVisibility(!vm.isCurrentPeriod, enter = fadeIn(tween(200)), exit = fadeOut(tween(200))) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                        SF("arrow.uturn.backward", theme.primaryColor, 11.dp)
                        T("today".localized, systemFont(11, FontWeight.SemiBold), theme.primaryColor, maxLines = 1)
                    }
                }
            }

            if (scope == TaskTimeScope.today) {
                SquareHeaderButton("book.closed.fill", onClick = {
                    presenter.sheet { JournalView(date = vm.selectedDate) }
                }) {
                    if (!JournalManager.entry(vm.selectedDate).isEmpty) {
                        Box(
                            Modifier
                                .align(Alignment.TopEnd)
                                .offset(x = 1.dp, y = (-1).dp)
                                .size(8.dp)
                                .background(theme.accentColor, CircleShape)
                        )
                    }
                }
            }

            // Next to the journal in the day view; inside the inbox it leads back.
            if (scope == TaskTimeScope.today || scope == TaskTimeScope.inbox) InboxHeaderButton()
            }

            if ((scope != TaskTimeScope.today || hideDaysBar) && scope != TaskTimeScope.longTerm && scope != TaskTimeScope.inbox && scope != TaskTimeScope.all) {
                CircleHeaderButton("chevron.left", vm.canNavigatePrevious, 20.dp) {
                    vm.navigateToPrevious()
                    if (scope == TaskTimeScope.today) setOffset(daysBetween(now(), vm.selectedDate).toInt())
                }
                CircleHeaderButton("chevron.right", vm.canNavigateNext, 20.dp) {
                    vm.navigateToNext()
                    if (scope == TaskTimeScope.today) setOffset(daysBetween(now(), vm.selectedDate).toInt())
                }
            }

            IOSMenu(
                TaskTimeScope.entries.map { item ->
                    MenuItem(item.timelineMenuName, item.icon, checked = scope == item) { vm.changeScope(item) }
                }
            ) {
                Row(
                    Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(theme.surfaceColor)
                        .border(1.dp, theme.borderColor, RoundedCornerShape(10.dp))
                        .padding(start = 10.dp, end = 8.dp, top = 8.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    // Text only (the icons are in the menu): the scope name must never be cut.
                    T(scope.timelineMenuName, Fonts.subheadline.semibold, theme.textColor, maxLines = 1)
                    SF("chevron.down", theme.secondaryTextColor, 14.dp)
                }
            }

            if (scope == TaskTimeScope.today) {
                CircleHeaderButton("calendar") {
                    presenter.sheet {
                        MediaHubCalendarView(onSelect = { date ->
                            vm.selectedDate = date
                            setOffset(daysBetween(now(), date).toInt())
                        })
                    }
                }
            }

            SquareHeaderButton("gearshape.fill", onClick = { presenter.sheet { SettingsView() } })
        }

        if (scope == TaskTimeScope.today && !hideDaysBar) {
            DateSelectorView(selectedDayOffset, setOffset)
        }
    }
}

@Composable
private fun InboxHeaderButton() {
    val theme = theme
    val isActive = vm.selectedTimeScope == TaskTimeScope.inbox
    val openCount = vm.openInboxCount
    SquareHeaderButton("tray.fill", active = isActive, onClick = {
        Haptics.selection()
        vm.changeScope(if (isActive) TaskTimeScope.today else TaskTimeScope.inbox)
    }) {
        if (openCount > 0 && !isActive) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 6.dp, y = (-6).dp)
                    .defaultMinSize(16.dp, 16.dp)
                    .background(Color.SysRed, CircleShape)
                    .border(1.5.dp, Color.SystemBackground, CircleShape)
                    .padding(horizontal = 4.dp),
                contentAlignment = Alignment.Center,
            ) {
                T(if (openCount > 99) "99+" else "$openCount", systemFont(10, FontWeight.Bold), Color.White, maxLines = 1)
            }
        }
    }
}

@Composable
private fun DateSelectorView(selectedDayOffset: Int, setOffset: (Int) -> Unit) {
    val density = LocalDensity.current
    val widthPx = with(density) { LocalConfiguration.current.screenWidthDp.dp.toPx() }
    val cellPx = with(density) { 57.dp.toPx() }
    val centerOffset = -((widthPx - with(density) { 45.dp.toPx() }) / 2).toInt()
    val state = rememberLazyListState(initialFirstVisibleItemIndex = selectedDayOffset + 365, initialFirstVisibleItemScrollOffset = centerOffset)
    val scope = rememberCoroutineScope()

    LaunchedEffect(selectedDayOffset) {
        state.animateScrollToItem(selectedDayOffset + 365, centerOffset)
    }

    fun select(offset: Int) {
        val bounded = offset.coerceIn(-365, 365)
        Haptics.selection()
        setOffset(bounded)
        vm.selectedDate = now().addingDays(bounded)
    }

    var drag by remember { mutableStateOf(0f) }
    LazyRow(
        state = state,
        userScrollEnabled = false,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(76.dp)
            .pointerInput(selectedDayOffset) {
                val tracker = androidx.compose.ui.input.pointer.util.VelocityTracker()
                detectHorizontalDragGestures(
                    onDragStart = {
                        drag = 0f
                        tracker.resetTracking()
                    },
                    onDragEnd = {
                        val velocity = tracker.calculateVelocity().x
                        // A flick moves by one day; a slow drag by as many cells as it travelled.
                        if (abs(velocity) > 400f) {
                            select(selectedDayOffset + if (velocity > 0) -1 else 1)
                        } else {
                            val cells = (drag / cellPx).roundToInt()
                            if (cells != 0) select(selectedDayOffset - cells)
                            else scope.launch { state.animateScrollToItem(selectedDayOffset + 365, centerOffset) }
                        }
                    },
                    onHorizontalDrag = { change, amount ->
                        tracker.addPosition(change.uptimeMillis, change.position)
                        drag += amount
                        scope.launch { state.scrollBy(-amount) }
                    },
                )
            },
    ) {
        items((-365..365).toList(), key = { it }) { offset ->
            val date = remember(offset) { now().addingDays(offset) }
            DayCell(date, offset == selectedDayOffset) { select(offset) }
        }
    }
}

private suspend fun androidx.compose.foundation.lazy.LazyListState.scrollBy(value: Float) {
    scroll { scrollBy(value) }
}

@Composable
private fun DayCell(date: Date, isSelected: Boolean, onTap: () -> Unit) {
    val theme = theme
    val isToday = date.isToday()
    val dayName = when (date.weekday) {
        1 -> "sunday"
        2 -> "monday"
        3 -> "tuesday"
        4 -> "wednesday"
        5 -> "thursday"
        6 -> "friday"
        else -> "saturday"
    }.localized.take(3).lowercase(appLocale)
    val scale by animateFloatAsState(if (isSelected) 1.08f else 1f, tween(200), label = "day")
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .scale(scale)
            .size(width = 45.dp, height = 60.dp)
            .clip(shape)
            .then(
                when {
                    isSelected -> Modifier.background(theme.gradient)
                    isToday -> Modifier.background(theme.primaryColor.copy(alpha = 0.1f))
                    else -> Modifier.background(theme.surfaceColor)
                }
            )
            .border(1.dp, if (isSelected) Color.Transparent else if (isToday) theme.primaryColor.copy(alpha = 0.3f) else theme.borderColor, shape)
            .tap(onClick = onTap),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
    ) {
        T(dayName, Fonts.caption2.medium, if (isSelected) theme.backgroundColor else if (isToday) theme.primaryColor else theme.secondaryTextColor, maxLines = 1)
        T(date.dayOfMonth.toString(), Fonts.callout.bold, if (isSelected) theme.backgroundColor else if (isToday) theme.primaryColor else theme.textColor, maxLines = 1)
    }
}

// MARK: - Control bar

@Composable
private fun ViewControlBarView() {
    val theme = theme
    val presenter = LocalPresenter.current
    var allScopeShowHistory by appStorage("allScopeShowHistory", false)
    val modes = if (vm.selectedTimeScope == TaskTimeScope.today) TimelineViewMode.entries else listOf(TimelineViewMode.list)
    LaunchedEffect(vm.selectedTimeScope, allScopeShowHistory) {
        vm.showAllHistory = allScopeShowHistory
    }

    Row(
        Modifier
            .fillMaxWidth()
            .background(theme.surfaceColor)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(theme.primaryColor.copy(alpha = 0.08f))
                .border(1.dp, theme.primaryColor.copy(alpha = if (vm.viewMode == TimelineViewMode.list) 0.6f else 0.25f), RoundedCornerShape(8.dp)),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            modes.forEach { mode ->
                val selected = vm.viewMode == mode
                val color = if (selected) theme.backgroundColor else theme.primaryColor
                Row(
                    Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (selected) theme.primaryColor else Color.Transparent)
                        .tap { vm.viewMode = mode }
                        .padding(horizontal = 9.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    SF(mode.icon, color, 13.dp)
                    T(if (mode == TimelineViewMode.list) "list".localized else "time".localized, systemFont(11, FontWeight.SemiBold), color, maxLines = 1)
                }
            }
        }

        if (vm.selectedTimeScope == TaskTimeScope.all) {
            val on = vm.showAllHistory
            val color = if (on) theme.backgroundColor else theme.primaryColor
            Row(
                Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(if (on) theme.primaryColor else theme.primaryColor.copy(alpha = 0.08f))
                    .tap {
                        allScopeShowHistory = !allScopeShowHistory
                        vm.showAllHistory = allScopeShowHistory
                    }
                    .padding(horizontal = 9.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SF("clock.arrow.circlepath", color, 13.dp)
                T("all_scope_history".localized, systemFont(11, FontWeight.SemiBold), color, maxLines = 1)
            }
        }

        Spacer(Modifier.weight(1f))

        // Organization status. When grouped/sorted it doubles as the reset control.
        Row(
            Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(theme.surfaceColor)
                .tap(vm.organization != TimelineOrganization.none) { vm.organization = TimelineOrganization.none }
                .padding(horizontal = 7.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            SF(vm.organization.icon, theme.secondaryTextColor, 13.dp)
            T(vm.organizationStatusText, systemFont(11, FontWeight.Medium), theme.secondaryTextColor)
            if (vm.organization != TimelineOrganization.none) {
                SF("xmark.circle.fill", theme.secondaryTextColor.copy(alpha = 0.7f), 14.dp)
            }
        }

        Box(
            Modifier
                .size(36.dp)
                .pressable { presenter.sheet { TimelineOrganizationView() } },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.fillMaxSize().background(theme.primaryColor.copy(alpha = 0.08f), CircleShape))
            SF("line.3.horizontal.decrease.circle", theme.primaryColor, 22.dp)
            // A status filter hides tasks: keep it visible from the header.
            androidx.compose.animation.AnimatedVisibility(
                vm.isFilteringStatus,
                modifier = Modifier.align(Alignment.TopEnd).offset(x = (-2).dp, y = 2.dp),
                enter = fadeIn(tween(250)) + androidx.compose.animation.scaleIn(tween(250)),
                exit = fadeOut(tween(250)) + androidx.compose.animation.scaleOut(tween(250)),
            ) {
                Box(Modifier.size(9.dp).background(theme.primaryColor, CircleShape).border(1.5.dp, theme.backgroundColor, CircleShape))
            }
        }
    }
}

// MARK: - Task list

@Composable
private fun TaskListView() {
    val presenter = LocalPresenter.current
    val focus = LocalFocusManager.current
    val progress = vm.scopeTransitionProgress
    LaunchedEffect(vm.selectedDate) { CalendarEventsFeed.load(vm.selectedDate) }

    Box(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    alpha = progress
                    translationY = (1 - progress) * 8.dp.toPx()
                }
        ) {
            // Pinned above both the empty state and the list, so it keeps focus.
            if (vm.selectedTimeScope == TaskTimeScope.inbox) {
                Box(Modifier.padding(start = 10.dp, end = 10.dp, top = 8.dp, bottom = 2.dp)) { InboxQuickAddField() }
            }
            val tasks = vm.tasks
            Box(Modifier.weight(1f).fillMaxWidth()) {
                when {
                    tasks.isEmpty() && vm.selectedTimeScope == TaskTimeScope.inbox -> {
                        Column(
                            Modifier.fillMaxSize().tap { focus.clearFocus() },
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Spacer(Modifier.weight(1f))
                            InboxEmptyState()
                            Spacer(Modifier.weight(2f))
                        }
                    }
                    tasks.isEmpty() -> EmptyTimeline()
                    vm.effectiveOrganization == TimelineOrganization.eisenhower -> {
                        EisenhowerMatrixView(Modifier.fillMaxSize().padding(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 100.dp))
                    }
                    vm.canReorderTasks -> ReorderableTaskList()
                    else -> OrganizedTaskList()
                }
            }
        }
        BottomBarOverlay(Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarInset() + 12.dp))
    }
}

@Composable
private fun EmptyTimeline() {
    val theme = theme
    Column(
        Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        if (showsCalendarEvents()) CalendarEventsCard()
        SF("calendar.badge.plus", theme.secondaryTextColor.copy(alpha = 0.6f), 64.dp)
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            T(vm.progressText, Fonts.title2.semibold, align = TextAlign.Center)
            T("tap_plus_add_first_task".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
        }
    }
}

private fun showsCalendarEvents(): Boolean =
    vm.selectedTimeScope == TaskTimeScope.today && CalendarEventsFeed.isEnabled && CalendarEventsFeed.events.isNotEmpty()

@Composable
private fun CalendarEventsCard() {
    val presenter = LocalPresenter.current
    CalendarEventsSection { event -> TimelineActions.addFromCalendar(presenter, event) }
}

@Composable
private fun OrganizedTaskList() {
    val organized = vm.organizedTasksForSelectedDate()
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 10.dp, end = 10.dp, top = 11.dp, bottom = tabBarInset() + 84.dp),
        verticalArrangement = Arrangement.spacedBy(TimelineCardMetrics.listSpacing),
    ) {
        if (vm.selectedTimeScope == TaskTimeScope.today) item("tip") { InProgressTipView() }
        if (showsCalendarEvents()) item("calendar") { CalendarEventsCard() }
        when (organized) {
            is OrganizedTasks.Single -> items(organized.tasks, key = { it.id }) { task ->
                Box(Modifier.animateItem()) { TimelineTaskCard(task) }
            }
            is OrganizedTasks.Sections -> items(organized.sections, key = { it.id }) { section ->
                OrganizedTaskSection(section, Modifier.animateItem())
            }
        }
        if (vm.isFilteringStatus && vm.applyingStatusFilter(vm.tasks).isEmpty()) {
            item("filterEmpty") { StatusFilterEmptyState() }
        }
    }
}

@Composable
private fun StatusFilterEmptyState() {
    val theme = theme
    Column(
        Modifier.fillMaxWidth().padding(top = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SF("line.3.horizontal.decrease.circle", theme.secondaryTextColor.copy(alpha = 0.6f), 34.dp)
        T("status_filter_empty".localized, Fonts.headline, align = TextAlign.Center)
        T(
            "status_filter_show_all".localized,
            Fonts.subheadline.semibold,
            theme.primaryColor,
            modifier = Modifier
                .clip(CircleShape)
                .background(theme.primaryColor.copy(alpha = 0.12f))
                .pressable {
                    Haptics.light()
                    vm.showAllStatuses()
                }
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

/** Default view: long press and drag reorders, with auto-scroll, as the native List does on iOS. */
@Composable
private fun ReorderableTaskList() {
    val organized = vm.organizedTasksForSelectedDate() as? OrganizedTasks.Single ?: return
    var local by remember { mutableStateOf(organized.tasks) }
    var dragging by remember { mutableStateOf(false) }
    LaunchedEffect(organized.tasks) { if (!dragging) local = organized.tasks }

    val listState = rememberLazyListState()
    val reorder = rememberReorderableLazyListState(listState) { from, to ->
        val fromIndex = local.indexOfFirst { it.id == from.key }
        val toIndex = local.indexOfFirst { it.id == to.key }
        if (fromIndex >= 0 && toIndex >= 0) {
            local = local.toMutableList().apply { add(toIndex, removeAt(fromIndex)) }
            Haptics.selection()
        }
    }
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 6.dp, bottom = tabBarInset() + 84.dp),
    ) {
        if (vm.selectedTimeScope == TaskTimeScope.today) {
            item("tip") { Box(Modifier.padding(horizontal = 10.dp, vertical = 5.dp)) { InProgressTipView() } }
        }
        if (showsCalendarEvents()) {
            item("calendar") { Box(Modifier.padding(horizontal = 10.dp, vertical = 5.dp)) { CalendarEventsCard() } }
        }
        items(local, key = { it.id }) { task ->
            ReorderableItem(reorder, key = task.id) { isDragging ->
                val elevation by animateFloatAsState(if (isDragging) 1.03f else 1f, tween(160), label = "drag")
                // Holding the circle marks "In progress": it must not pick the card up.
                var statusPressed by remember { mutableStateOf(false) }
                Box(
                    Modifier
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                        .scale(elevation)
                ) {
                    TimelineTaskCard(
                        task,
                        onStatusPressed = { statusPressed = it },
                        dragModifier = Modifier.longPressDraggableHandle(
                            enabled = !statusPressed,
                            onDragStarted = {
                                dragging = true
                                Haptics.heavy()
                            },
                            onDragStopped = {
                                dragging = false
                                vm.moveTasks(local.map { it.id })
                            },
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun OrganizedTaskSection(section: TaskSection, modifier: Modifier = Modifier) {
    val theme = theme
    val sectionColor = section.color?.let { colorFromHex(it) }
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(theme.surfaceColor)
                .border(1.dp, sectionColor?.copy(alpha = 0.2f) ?: theme.borderColor, RoundedCornerShape(12.dp))
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            section.icon?.let { SF(it, sectionColor ?: theme.secondaryTextColor, 16.dp) }
            T(section.title, Fonts.headline, modifier = Modifier.weight(1f))
            T(
                section.tasks.size.toString(),
                Fonts.caption,
                theme.secondaryTextColor,
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(theme.surfaceColor)
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
        section.tasks.forEach { task -> key(task.id) { TimelineTaskCard(task) } }
    }
}

@Composable
private fun BottomBarOverlay(modifier: Modifier = Modifier) {
    val presenter = LocalPresenter.current
    val tracker = TimeTrackerViewModel
    val pomodoro = PomodoroViewModel
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (tracker.activeSessions.isNotEmpty() || pomodoro.hasActiveTask) {
            Row(
                Modifier.padding(start = 16.dp, end = 16.dp, bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                tracker.activeSessions.forEach { session ->
                    MiniTimerWidget(session.id) {
                        presenter.sheet(SheetDetent.fit) { TimeTrackerView(sessionId = session.id, presentationStyle = TimerPresentationStyle.sheet, allowExpand = true) }
                    }
                }
                if (pomodoro.hasActiveTask) {
                    MiniPomodoroWidget {
                        if (pomodoro.activeTask == null && pomodoro.state == PomodoroState.notStarted) pomodoro.initializeGeneralSession()
                        presenter.fullScreen { NavigationStack { PomodoroTabView() } }
                    }
                }
            }
        }
        AddTaskButton { TimelineActions.newTask(presenter) }
    }
}

@Composable
private fun AddTaskButton(onClick: () -> Unit) {
    val theme = theme
    var pressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (pressed) 0.95f else 1f, spring(dampingRatio = 0.6f, stiffness = 600f), label = "add")
    Box(
        Modifier
            .size(56.dp)
            .scale(scale)
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        pressed = true
                        tryAwaitRelease()
                        pressed = false
                    },
                    onTap = { onClick() },
                )
            }
            .semantics {
                onClick {
                    onClick()
                    true
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.requiredSize(84.dp).background(Brush.radialGradient(listOf(theme.primaryColor.copy(alpha = 0.3f), theme.primaryColor.copy(alpha = 0.3f), Color.Transparent)), CircleShape))
        Box(
            Modifier
                .fillMaxSize()
                .shadow(8.dp, CircleShape, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(CircleShape)
                .background(theme.gradient),
            contentAlignment = Alignment.Center,
        ) {
            SF("plus", theme.backgroundColor, 30.dp)
        }
    }
}

/** One-time hint: press and hold the task circle to switch "In corso" on and off. */
object InProgressTip {
    private const val KEY = "tip_in_progress_done"
    var isVisible by mutableStateOf(!runCatching { Defaults.bool(KEY) }.getOrDefault(false))
        private set
    fun markLearned() {
        if (isVisible) {
            isVisible = false
            Defaults.set(KEY, true)
        }
    }
}

@Composable
private fun InProgressTipView() {
    val theme = theme
    if (!InProgressTip.isVisible) return
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.SecondaryBackground)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SF("circle.lefthalf.filled", theme.accentColor, 30.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T("tip_in_progress_title".localized, Fonts.headline, Color.Primary)
            T("tip_in_progress_message".localized, Fonts.subheadline, Color.Secondary)
        }
        Box(Modifier.size(22.dp).clip(CircleShape).tap { InProgressTip.markLearned() }, contentAlignment = Alignment.Center) {
            SF("xmark", Color.Secondary, 16.dp)
        }
    }
}

// MARK: - Task card

object TimelineCardMetrics {
    val contentInset = 12.dp
    val cornerRadius = 22.dp
    val iconSize = 38.dp
    val iconRadius = 11.dp
    val statusRingSize = 32.dp
    val statusIconSize = 22.dp
    val statusHitSize = 44.dp
    val minHeight = 60.dp
    val listSpacing = 10.dp
    val titleMetaSpacing = 5.dp
}

fun displayIcon(task: TodoTask): String =
    if (task.icon == "circle" || task.icon.isEmpty()) task.category?.icon ?: "list.bullet" else task.icon

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TimelineTaskCard(task: TodoTask, dragModifier: Modifier = Modifier, onStatusPressed: (Boolean) -> Unit = {}) {
    val theme = theme
    val presenter = LocalPresenter.current
    val focus = LocalFocusManager.current
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val gradientEnabled = SettingsViewModel.showCategoryGradients
    var isExpanded by remember { mutableStateOf(false) }
    var showingDeleteSessionsDialog by remember { mutableStateOf(false) }
    val dragOffset = remember { Animatable(0f) }
    val deleteProgress = remember { Animatable(1f) }

    val targetDate: Date = run {
        when (vm.selectedTimeScope) {
            TaskTimeScope.today -> vm.selectedDate
            TaskTimeScope.week -> vm.currentWeek
            TaskTimeScope.month -> vm.currentMonth
            TaskTimeScope.year -> vm.currentYear
            TaskTimeScope.longTerm, TaskTimeScope.inbox -> task.startTime.startOfDay()
            TaskTimeScope.all -> when (task.timeScope) {
                TaskTimeScope.today -> vm.selectedDate
                TaskTimeScope.week -> vm.currentWeek
                TaskTimeScope.month -> vm.currentMonth
                TaskTimeScope.year -> vm.currentYear
                TaskTimeScope.longTerm, TaskTimeScope.inbox -> task.startTime.startOfDay()
                TaskTimeScope.all -> now().startOfDay()
            }
        }
    }
    val key = task.completionKey(targetDate)
    val completion = task.completions[key]
    val isCompleted = completion?.isCompleted == true
    val state = when {
        isCompleted -> TaskProgressState.completed
        completion?.isInProgress == true -> TaskProgressState.inProgress
        else -> TaskProgressState.todo
    }
    val isInProgress = state == TaskProgressState.inProgress
    val isInbox = task.timeScope == TaskTimeScope.inbox
    val completedSubtasks = completion?.completedSubtasks ?: emptySet()
    val completionProgress = if (task.subtasks.isEmpty()) (if (isCompleted) 1f else 0f) else completedSubtasks.size.toFloat() / task.subtasks.size
    val categoryTint = task.category?.let { colorFromHex(it.color) } ?: theme.accentColor

    val occurrenceForBadges = remember(task, vm.selectedTimeScope, vm.currentWeek, vm.currentMonth, vm.currentYear) { occurrenceDateForBadges(task) }
    val currentlyActive = run {
        if (!vm.isToday || !task.hasSpecificTime) return@run false
        val current = now()
        val start = if (task.recurrence != null) task.occurrenceDate(vm.selectedDate) else task.startTime
        val duration = if (task.hasDuration && task.duration > 0) task.duration else 1800.0
        current >= start && current <= start.plusSeconds(duration.toLong())
    }
    val dateBadge = when (vm.selectedTimeScope) {
        TaskTimeScope.week -> occurrenceForBadges.skeleton("EEEd").replaceFirstChar { it.titlecase(appLocale) }
        TaskTimeScope.month, TaskTimeScope.year -> occurrenceForBadges.skeleton("dMMM")
        TaskTimeScope.longTerm -> task.startTime.skeleton("dMMMyyyy")
        else -> null
    }
    val hasScheduleBadge = vm.selectedTimeScope == TaskTimeScope.today || ((task.hasSpecificTime || task.hasSpecificDay) && dateBadge != null)

    fun closeSwipe(then: () -> Unit = {}) {
        scope.launch {
            launch { dragOffset.animateTo(0f, spring(dampingRatio = 0.92f, stiffness = 300f)) }
            delay(250)
            if (vm.openSwipeTaskId == task.id) vm.openSwipeTaskId = null
            then()
        }
    }

    fun deleteWithAnimation(deletingSessions: Boolean = false) {
        Haptics.medium()
        scope.launch {
            // The card fades and shrinks slightly in place, then the list closes the gap.
            deleteProgress.animateTo(0f, tween(250))
            if (vm.openSwipeTaskId == task.id) vm.openSwipeTaskId = null
            TaskManager.removeTask(task, deletingSessions)
        }
    }

    fun requestDelete() {
        if (TaskManager.trackingSessionCount(task.id) > 0) showingDeleteSessionsDialog = true else deleteWithAnimation()
    }

    LaunchedEffect(vm.openSwipeTaskId) {
        if (vm.openSwipeTaskId != task.id && dragOffset.value != 0f) {
            dragOffset.animateTo(0f, spring(dampingRatio = 0.92f, stiffness = 300f))
        }
    }

    if (showingDeleteSessionsDialog) {
        ConfirmationDialog(
            title = null,
            message = "delete_task_sessions_message".localized(TaskManager.trackingSessionCount(task.id)),
            actions = listOf(
                AlertAction("delete_task_and_sessions".localized, AlertRole.destructive) { deleteWithAnimation(true) },
                AlertAction("delete_task_keep_sessions".localized) { deleteWithAnimation(false) },
                AlertAction("cancel".localized, AlertRole.cancel),
            ),
            onDismiss = { showingDeleteSessionsDialog = false },
        )
    }

    Box(
        Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = deleteProgress.value
                val s = 0.95f + 0.05f * deleteProgress.value
                scaleX = s
                scaleY = s
            }
            .then(dragModifier)
            .pointerInput(task.id) {
                val maxSwipe = -210.dp.toPx()
                val tracker = androidx.compose.ui.input.pointer.util.VelocityTracker()
                detectHorizontalDragGestures(
                    onDragStart = { tracker.resetTracking() },
                    onDragEnd = {
                        val velocity = tracker.calculateVelocity().x
                        val projected = dragOffset.value + velocity * 0.15f
                        val target = if (projected < -90.dp.toPx()) -180.dp.toPx() else 0f
                        scope.launch {
                            dragOffset.animateTo(target, spring(dampingRatio = 0.92f, stiffness = 300f), initialVelocity = velocity)
                            if (target < 0) vm.openSwipeTaskId = task.id
                            else if (vm.openSwipeTaskId == task.id) vm.openSwipeTaskId = null
                        }
                    },
                    onHorizontalDrag = { change, amount ->
                        change.consume()
                        tracker.addPosition(change.uptimeMillis, change.position)
                        val raw = dragOffset.value + amount
                        val banded = when {
                            raw > 0 -> dragOffset.value + amount * 0.15f
                            raw < maxSwipe -> dragOffset.value + amount * 0.25f
                            else -> raw
                        }
                        scope.launch { dragOffset.snapTo(banded) }
                    },
                )
            },
    ) {
        // Background actions layer
        val actionsAlpha = with(density) { ((abs(dragOffset.value) - 40.dp.toPx()) / 60.dp.toPx()).coerceIn(0f, 1f) }
        if (actionsAlpha > 0f) {
            Row(
                Modifier
                    .align(Alignment.CenterEnd)
                    .alpha(actionsAlpha),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (isInbox) {
                    SwipeAction("calendar.badge.plus", "inbox_plan".localized, Color.SysIndigo) {
                        focus.clearFocus()
                        closeSwipe { presentPlanSheet(presenter, task) }
                    }
                } else {
                    SwipeAction("play.fill", "track".localized, Color.SysYellow) {
                        closeSwipe { presentTrackingSelection(presenter, task) }
                    }
                }
                SwipeAction("pencil", "edit".localized, Color.SysOrange) {
                    focus.clearFocus()
                    closeSwipe {
                        presenter.sheet { TaskFormView(initialTask = task, onSave = { MainScope.launch { TaskManager.updateTask(it) } }) }
                    }
                }
                SwipeAction("trash", "delete".localized, Color.SysRed) { requestDelete() }
            }
        }

        // Main task card content
        val cardShape = RoundedCornerShape(TimelineCardMetrics.cornerRadius)
        val shadowColor = if (currentlyActive) theme.primaryColor.copy(alpha = 0.25f) else theme.shadowColor
        Box(
            Modifier
                .offset { IntOffset(dragOffset.value.roundToInt(), 0) }
                .fillMaxWidth()
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = TimelineCardMetrics.minHeight)
                    .shadow(5.dp, cardShape, clip = false, ambientColor = shadowColor, spotColor = shadowColor)
                    .clip(cardShape)
                    .background(theme.surfaceColor)
                    .then(
                        if (gradientEnabled && task.category != null) {
                            val base = colorFromHex(task.category.color)
                            Modifier.background(
                                Brush.horizontalGradient(
                                    0f to base.copy(alpha = 0.22f),
                                    0.35f to base.copy(alpha = 0.10f),
                                    0.7f to base.copy(alpha = 0.03f),
                                    1f to Color.Transparent,
                                )
                            )
                        } else Modifier
                    )
                    .then(
                        when {
                            currentlyActive -> Modifier.border(1.5.dp, theme.primaryColor.copy(alpha = 0.85f), cardShape)
                            gradientEnabled && task.category != null -> {
                                val base = colorFromHex(task.category.color)
                                Modifier.border(1.dp, Brush.horizontalGradient(listOf(base.copy(alpha = 0.35f), base.copy(alpha = 0.08f))), cardShape)
                            }
                            else -> Modifier.border(1.dp, theme.borderColor.copy(alpha = 0.4f), cardShape)
                        }
                    )
                    .pointerInput(task.id, isInbox) {
                        // Holding a card lifts it to reorder: letting go must not also open it.
                        detectTapGestures(onLongPress = {}) {
                            when {
                                dragOffset.value != 0f -> closeSwipe()
                                isInbox -> {
                                    if (isExpanded) focus.clearFocus()
                                    isExpanded = !isExpanded
                                }
                                else -> {
                                    focus.clearFocus()
                                    TimelineActions.openDetail(presenter, task.id, vm.selectedDate)
                                }
                            }
                        }
                    }
                    .semantics {
                        onClick {
                            if (isInbox) isExpanded = !isExpanded else TimelineActions.openDetail(presenter, task.id, vm.selectedDate)
                            true
                        }
                    }
            ) {
                Row(
                    Modifier.padding(TimelineCardMetrics.contentInset),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        TaskIcon(task, categoryTint, targetDate)
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TimelineCardMetrics.titleMetaSpacing)) {
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                T(task.name, Fonts.headline)
                                task.description?.takeIf { it.isNotEmpty() }?.let { T(it, Fonts.subheadline, theme.secondaryTextColor) }
                            }
                            if (hasScheduleBadge || task.subtasks.isNotEmpty() || isInProgress) {
                                // One line, never truncated: if it doesn't fit, "In corso" keeps only its icon.
                                ViewThatFits(
                                    { MetaItems(task, hasScheduleBadge, dateBadge, occurrenceForBadges, currentlyActive, isInProgress, completedSubtasks.size, isExpanded, true) { isExpanded = !isExpanded } },
                                    { MetaItems(task, hasScheduleBadge, dateBadge, occurrenceForBadges, currentlyActive, isInProgress, completedSubtasks.size, isExpanded, false) { isExpanded = !isExpanded } },
                                )
                            }
                        }
                    }

                    // Quick notes start at medium: show the mark only once a priority was chosen.
                    if (!isInbox || task.priority != Priority.medium) {
                        SF(task.priority.icon, colorFromHex(task.priority.colorHex), 14.dp)
                    }

                    if (task.pomodoroSettings != null) {
                        Box(
                            Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(theme.accentColor.copy(alpha = 0.15f))
                                .border(1.dp, theme.accentColor.copy(alpha = 0.5f), CircleShape)
                                .pressable {
                                    PomodoroViewModel.setActiveTask(task)
                                    presenter.fullScreen { NavigationStack { PomodoroTabView() } }
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            SF("timer", task.category?.let { colorFromHex(it.color) } ?: theme.accentColor, 18.dp)
                        }
                    }

                    // Tap completes (or un-completes); press and hold switches "In progress" on and off.
                    Box(
                        Modifier
                            .size(TimelineCardMetrics.statusHitSize)
                            .reportsPress(onStatusPressed)
                            .taskStatusGestures(
                                onTap = {
                                    if (isCompleted) Haptics.light() else Haptics.success()
                                    vm.toggleTaskCompletion(task.id)
                                },
                                onLongPress = {
                                    InProgressTip.markLearned()
                                    TaskManager.toggleInProgress(task.id, targetDate)
                                },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        val ring = theme.borderColor
                        val primary = theme.primaryColor
                        val animatedProgress by animateFloatAsState(completionProgress, tween(350), label = "ring")
                        Canvas(Modifier.size(TimelineCardMetrics.statusRingSize)) {
                            drawCircle(ring, style = Stroke(2.dp.toPx()))
                            if (task.subtasks.isNotEmpty()) {
                                drawArc(primary, -90f, 360f * animatedProgress, false, style = Stroke(3.dp.toPx()))
                            }
                        }
                        TaskStatusIcon(state, theme.secondaryTextColor, Color.SysGreen, TimelineCardMetrics.statusIconSize)
                    }
                }

                if (task.subtasks.isNotEmpty() || isInbox) {
                    AnimatedVisibility(
                        isExpanded,
                        enter = expandVertically(tween(300)) + fadeIn(tween(300)),
                        exit = shrinkVertically(tween(300)) + fadeOut(tween(200)),
                    ) {
                        Column(
                            Modifier.padding(top = 2.dp, bottom = TimelineCardMetrics.contentInset),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            task.subtasks.forEach { subtask ->
                                key(subtask.id) {
                                    TimelineSubtaskRow(subtask, subtask.id in completedSubtasks) { vm.toggleSubtask(task.id, subtask.id) }
                                }
                            }
                            if (isInbox) {
                                InboxSubtaskAddField(task.id)
                                InboxPriorityRow(task)
                            }
                        }
                    }
                }
            }
            // Names the accent border: this task is happening right now.
            if (currentlyActive) {
                T(
                    "task_in_progress_now".localized,
                    systemFont(10, FontWeight.Bold),
                    Color.White,
                    maxLines = 1,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = (-22).dp, y = (-8).dp)
                        .background(theme.primaryColor, CircleShape)
                        .padding(horizontal = 7.dp, vertical = 2.dp),
                )
            }
        }
    }
}

private fun occurrenceDateForBadges(task: TodoTask): Date {
    val recurrence = task.recurrence ?: return task.startTime
    val periodStart: Date
    val periodEnd: Date
    when (vm.selectedTimeScope) {
        TaskTimeScope.week -> {
            periodStart = vm.currentWeek.startOfWeek()
            periodEnd = periodStart.addingDays(6)
        }
        TaskTimeScope.month -> {
            periodStart = vm.currentMonth.startOfMonth()
            periodEnd = periodStart.endOfMonth()
        }
        TaskTimeScope.year -> {
            periodStart = vm.currentYear.startOfYear()
            periodEnd = periodStart.endOfYear()
        }
        else -> return task.startTime
    }
    var day = maxOf(periodStart.startOfDay(), recurrence.startDate.startOfDay())
    val end = periodEnd.startOfDay()
    while (day <= end) {
        if (recurrence.shouldOccurOn(day)) return task.occurrenceDate(day)
        day = day.addingDays(1)
    }
    return task.startTime
}

@Composable
private fun SwipeAction(icon: String, title: String, color: Color, onClick: () -> Unit) {
    Column(
        Modifier.width(50.dp).pressable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier.size(50.dp).clip(RoundedCornerShape(12.dp)).background(color),
            contentAlignment = Alignment.Center,
        ) {
            SF(icon, Color.White, 22.dp)
        }
        T(title, systemFont(10, FontWeight.Medium), color, align = TextAlign.Center)
    }
}

private fun presentPlanSheet(presenter: Presenter, task: TodoTask) {
    presenter.sheet(detent = SheetDetent.large) {
        PlanInboxItemSheet(task, onMoreOptions = {
            presenter.dismissTop()
            presenter.sheet {
                TaskFormView(initialTask = planFullFormDraft(task), onSave = { MainScope.launch { TaskManager.updateTask(it) } })
            }
        })
    }
}

fun presentTrackingSelection(presenter: Presenter, task: TodoTask) {
    presenter.sheet {
        TrackingModeSelectionView(task) { mode ->
            if (mode == TrackingMode.pomodoro) {
                PomodoroViewModel.setActiveTask(task)
                presenter.fullScreen { NavigationStack { PomodoroTabView() } }
            } else {
                presenter.sheet(SheetDetent.fit) {
                    TimeTrackerView(task = task, mode = mode, presentationStyle = TimerPresentationStyle.sheet, allowExpand = false)
                }
            }
        }
    }
}

@Composable
private fun TaskIcon(task: TodoTask, tint: Color, targetDate: Date) {
    val shape = RoundedCornerShape(TimelineCardMetrics.iconRadius)
    Box(contentAlignment = Alignment.BottomCenter) {
        Box(
            Modifier
                .size(TimelineCardMetrics.iconSize)
                .clip(shape)
                .background(tint.copy(alpha = 0.16f))
                .border(0.5.dp, tint.copy(alpha = 0.25f), shape),
            contentAlignment = Alignment.Center,
        ) {
            SF(displayIcon(task), tint, 20.dp)
        }
        val streak = remember(task.completions, targetDate) { streakFor(task, targetDate) }
        if (streak > 0) StreakBadge(streak, Modifier.offset(y = 9.dp))
    }
}

private fun streakFor(task: TodoTask, target: Date): Int {
    val recurrence = task.recurrence ?: return 0
    val scopeDate = target.startOfDay()
    var streak = 0
    var current = scopeDate
    if (task.completions[scopeDate]?.isCompleted == true) {
        streak = 1
        current = current.addingDays(-1)
    }
    var iterations = 0
    while (iterations < 1000) {
        if (!recurrence.shouldOccurOn(current)) {
            if (current < recurrence.startDate.startOfDay()) break
            current = current.addingDays(-1)
            iterations++
            continue
        }
        if (task.completions[current]?.isCompleted == true) {
            streak++
            current = current.addingDays(-1)
            iterations++
        } else break
    }
    return streak
}

@Composable
private fun StreakBadge(streak: Int, modifier: Modifier = Modifier) {
    Row(
        modifier
            .defaultMinSize(22.dp, 17.dp)
            .shadow(2.dp, CircleShape, clip = false, ambientColor = Color(0x59FF9500), spotColor = Color(0x59FF9500))
            .clip(CircleShape)
            .background(Brush.verticalGradient(listOf(Color(0xFFFF9F0A), Color(0xFFFF6B00))))
            .border(2.dp, Color.SystemBackground, CircleShape)
            .padding(horizontal = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterHorizontally),
    ) {
        SF("flame.fill", Color.White, 10.dp)
        T(streak.toString(), systemFont(11, FontWeight.Bold).monospacedDigit, Color.White, maxLines = 1)
    }
}

@Composable
private fun MetaItems(
    task: TodoTask,
    hasScheduleBadge: Boolean,
    dateBadge: String?,
    occurrence: Date,
    currentlyActive: Boolean,
    isInProgress: Boolean,
    completedSubtasks: Int,
    isExpanded: Boolean,
    showsProgressLabel: Boolean,
    onToggleExpanded: () -> Unit,
) {
    val theme = theme
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (hasScheduleBadge) ScheduleBadge(task, dateBadge, occurrence, currentlyActive)
        if (task.subtasks.isNotEmpty()) {
            val rotation by animateFloatAsState(if (isExpanded) 180f else 0f, spring(stiffness = 400f, dampingRatio = 0.65f), label = "chevron")
            Row(
                Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(theme.surfaceColor)
                    .pointerInput(onToggleExpanded) { detectTapGestures { onToggleExpanded() } }
                    .padding(horizontal = 6.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SF("checklist", theme.secondaryTextColor, 13.dp)
                T("$completedSubtasks/${task.subtasks.size}", Fonts.caption.semibold.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                SF("chevron.down", theme.secondaryTextColor, 13.dp, Modifier.rotate(rotation))
            }
        }
        if (isInProgress) {
            Row(
                Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.SysBlue.copy(alpha = 0.12f))
                    .padding(horizontal = 6.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                SF("play.fill", Color.SysBlue, 10.dp)
                if (showsProgressLabel) T("task_status_in_progress".localized, Fonts.caption.semibold, Color.SysBlue, maxLines = 1)
            }
        }
    }
}

@Composable
private fun ScheduleBadge(task: TodoTask, dateBadge: String?, occurrence: Date, currentlyActive: Boolean) {
    val theme = theme
    if (vm.selectedTimeScope == TaskTimeScope.today) {
        if (task.hasSpecificTime) {
            val start = if (task.recurrence != null) task.occurrenceDate(vm.selectedDate) else task.startTime
            val text = if (task.hasDuration && task.duration > 0) TimeFormatPreference.range(start, start.plusSeconds(task.duration.toLong())) else start.timeText()
            Row(
                Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (currentlyActive) theme.primaryColor.copy(alpha = 0.12f) else theme.surfaceColor)
                    .padding(horizontal = 6.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (currentlyActive) Box(Modifier.size(5.dp).background(theme.primaryColor, CircleShape))
                T(
                    text,
                    Fonts.caption.monospacedDigit.weight(if (currentlyActive) FontWeight.SemiBold else FontWeight.Medium),
                    if (currentlyActive) theme.primaryColor else theme.secondaryTextColor,
                    maxLines = 1,
                )
            }
        } else {
            T(
                "all_day".localized,
                Fonts.caption2,
                Color.SysBlue,
                maxLines = 1,
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.SysBlue.copy(alpha = 0.1f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    } else if ((task.hasSpecificTime || task.hasSpecificDay) && dateBadge != null) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            T(
                dateBadge, Fonts.caption, theme.secondaryTextColor, maxLines = 1,
                modifier = Modifier.clip(RoundedCornerShape(4.dp)).background(theme.surfaceColor).padding(horizontal = 6.dp, vertical = 2.dp),
            )
            if (task.hasSpecificTime) {
                T(
                    occurrence.timeText(), Fonts.caption.monospacedDigit.medium, theme.secondaryTextColor, maxLines = 1,
                    modifier = Modifier.clip(RoundedCornerShape(4.dp)).background(theme.surfaceColor).padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
    }
}

/** The task circle's gestures, the same everywhere: tap completes, press and hold switches "In progress". */
fun Modifier.taskStatusGestures(onTap: () -> Unit, onLongPress: () -> Unit): Modifier = composed {
    val tap by rememberUpdatedState(onTap)
    val long by rememberUpdatedState(onLongPress)
    pointerInput(Unit) {
        detectTapGestures(onTap = { tap() }, onLongPress = { long() })
    }.semantics {
        onClick {
            tap()
            true
        }
        onLongClick {
            long()
            true
        }
    }
}

/** Tells while a finger is down on this element, before anything inside or around it reacts. */
fun Modifier.reportsPress(onPressed: (Boolean) -> Unit): Modifier = composed {
    val report by rememberUpdatedState(onPressed)
    pointerInput(Unit) {
        awaitEachGesture {
            awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            report(true)
            try {
                do {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                } while (event.changes.any { it.pressed })
            } finally {
                report(false)
            }
        }
    }
}

/** A task's state mark with gradual transitions; completing sends out a soft ring. */
@Composable
fun TaskStatusIcon(state: TaskProgressState, idleColor: Color, completedColor: Color = Color.SysGreen, size: androidx.compose.ui.unit.Dp = 22.dp) {
    val symbol = when (state) {
        TaskProgressState.todo -> "circle"
        TaskProgressState.inProgress -> "circle.lefthalf.filled"
        TaskProgressState.completed -> "checkmark.circle.fill"
    }
    val color = when (state) {
        TaskProgressState.todo -> idleColor
        TaskProgressState.inProgress -> Color.SysBlue
        TaskProgressState.completed -> completedColor
    }
    val ring = remember { Animatable(0f) }
    val bounce = remember { Animatable(1f) }
    var previous by remember { mutableStateOf(state) }
    LaunchedEffect(state) {
        if (state == previous) return@LaunchedEffect
        previous = state
        launch {
            bounce.snapTo(0.8f)
            bounce.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = 500f))
        }
        if (state == TaskProgressState.completed) {
            ring.snapTo(0f)
            ring.animateTo(1f, tween(550))
        }
    }
    Box(contentAlignment = Alignment.Center) {
        if (ring.value in 0.001f..0.999f) {
            Canvas(Modifier.size(size)) {
                val scale = 1f + 0.7f * ring.value
                drawCircle(color.copy(alpha = 0.55f * (1 - ring.value)), radius = this.size.minDimension / 2 * scale, style = Stroke(2.dp.toPx()))
            }
        }
        androidx.compose.animation.Crossfade(symbol, animationSpec = tween(300), label = "status") { name ->
            SF(name, color, size, Modifier.scale(bounce.value))
        }
    }
}

@Composable
private fun TimelineSubtaskRow(subtask: Subtask, isCompleted: Boolean, onToggle: () -> Unit) {
    Row(Modifier.padding(start = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(32.dp).tap(onClick = onToggle), contentAlignment = Alignment.Center) {
            SubtaskCheckmark(isCompleted)
        }
        Spacer(Modifier.width(8.dp))
        T(subtask.name, Fonts.subheadline, Color.Primary, modifier = Modifier.weight(1f))
    }
}

@Composable
fun SubtaskCheckmark(isCompleted: Boolean) {
    val theme = theme
    Box(contentAlignment = Alignment.Center) {
        Box(Modifier.size(24.dp).border(1.5.dp, if (isCompleted) theme.accentColor else Color.SysGray, CircleShape))
        if (isCompleted) Box(Modifier.size(16.dp).background(theme.accentColor, CircleShape))
    }
}

// MARK: - Inbox

@Composable
private fun InboxQuickAddField() {
    val theme = theme
    var text by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    val requester = remember { FocusRequester() }
    val shape = RoundedCornerShape(TimelineCardMetrics.cornerRadius)
    fun add() {
        val name = text.trim()
        if (name.isEmpty()) return
        text = ""
        Haptics.light()
        MainScope.launch { TaskManager.addTask(TodoTask(name = name, startTime = now(), icon = "note.text", timeScope = TaskTimeScope.inbox)) }
    }
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(1.dp, theme.primaryColor.copy(alpha = if (focused) 0.6f else 0.25f), shape)
            .tap { requester.requestFocus() }
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SF("square.and.pencil", theme.primaryColor, 18.dp)
        BasicTextField(
            text, { text = it },
            singleLine = true,
            textStyle = Fonts.body.copy(color = theme.textColor),
            cursorBrush = SolidColor(theme.accentColor),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            // Return keeps the keyboard up for the next note.
            keyboardActions = KeyboardActions(onDone = { add() }),
            modifier = Modifier
                .weight(1f)
                .focusRequester(requester)
                .onFocusChanged { focused = it.isFocused },
            decorationBox = { inner ->
                Box {
                    if (text.isEmpty()) T("inbox_add_placeholder".localized, Fonts.body, Color.Tertiary)
                    inner()
                }
            },
        )
        AnimatedVisibility(text.trim().isNotEmpty(), enter = fadeIn(tween(150)), exit = fadeOut(tween(150))) {
            Box(Modifier.tap { add() }) { SF("arrow.up.circle.fill", theme.primaryColor, 28.dp) }
        }
    }
}

@Composable
private fun InboxSubtaskAddField(taskId: UUID) {
    val theme = theme
    var text by remember { mutableStateOf("") }
    fun add() {
        val name = text.trim()
        if (name.isEmpty()) return
        text = ""
        val task = TaskManager.task(taskId) ?: return
        Haptics.light()
        MainScope.launch { TaskManager.updateTask(task.copy(subtasks = task.subtasks + Subtask(name = name), lastModifiedDate = now())) }
    }
    Row(Modifier.padding(start = 16.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) { SF("plus", theme.primaryColor, 18.dp) }
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            text, { text = it },
            singleLine = true,
            textStyle = Fonts.subheadline.copy(color = theme.textColor),
            cursorBrush = SolidColor(theme.accentColor),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { add() }),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                Box {
                    if (text.isEmpty()) T("inbox_add_subitem".localized, Fonts.subheadline, Color.Tertiary)
                    inner()
                }
            },
        )
    }
}

@Composable
private fun InboxPriorityRow(task: TodoTask) {
    val theme = theme
    IOSMenu(
        Priority.entries.map { priority ->
            MenuItem(priority.displayName, priority.icon, checked = task.priority == priority) {
                if (priority != task.priority) {
                    TaskManager.task(task.id)?.let { current ->
                        Haptics.selection()
                        MainScope.launch { TaskManager.updateTask(current.copy(priority = priority, lastModifiedDate = now())) }
                    }
                }
            }
        },
        Modifier.padding(start = 16.dp, end = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(32.dp), contentAlignment = Alignment.Center) { SF("flag.fill", theme.primaryColor, 15.dp) }
            T("priority".localized, Fonts.subheadline, theme.secondaryTextColor, maxLines = 1)
            T(task.priority.displayName, Fonts.subheadline.semibold, colorFromHex(task.priority.colorHex), maxLines = 1)
            SF("chevron.up.chevron.down", theme.secondaryTextColor, 13.dp)
        }
    }
}

@Composable
private fun InboxEmptyState() {
    val theme = theme
    Column(
        Modifier.padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SF("tray.fill", theme.secondaryTextColor.copy(alpha = 0.6f), 52.dp, Modifier.padding(bottom = 4.dp))
        T("inbox_empty_title".localized, Fonts.title3.semibold, align = TextAlign.Center)
        T("inbox_empty_subtitle".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
    }
}

/** The item as a plain task for today, so the full form opens on the normal options. */
fun planFullFormDraft(task: TodoTask): TodoTask {
    val current = now()
    val next = if (current.minute < 30) current.withTime(current.hour, 30) else current.withTime(current.hour, 0).addingHours(1)
    return task.copy(
        timeScope = TaskTimeScope.today,
        scopeStartDate = null,
        scopeEndDate = null,
        startTime = next,
        hasSpecificDay = true,
        hasSpecificTime = false,
        completions = emptyMap(),
    )
}

/** Turns an inbox item into a dated task (today, tomorrow, this week or a chosen day). */
@Composable
internal fun PlanInboxItemSheet(task: TodoTask, onMoreOptions: () -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var choice by remember { mutableStateOf("today") }
    var date by remember { mutableStateOf(now()) }
    var hasTime by remember { mutableStateOf(false) }
    var time by remember { mutableStateOf(now().withTime(9, 0)) }

    fun plan() {
        val updated = if (choice == "thisWeek") {
            val weekStart = now().startOfWeek()
            task.copy(
                completions = emptyMap(), lastModifiedDate = now(), timeScope = TaskTimeScope.week,
                scopeStartDate = weekStart, scopeEndDate = weekStart.addingDays(6), startTime = weekStart,
                hasSpecificDay = false, hasSpecificTime = false,
            )
        } else {
            val day = when (choice) {
                "tomorrow" -> now().startOfDay().addingDays(1)
                "custom" -> date.startOfDay()
                else -> now().startOfDay()
            }
            task.copy(
                completions = emptyMap(), lastModifiedDate = now(), timeScope = TaskTimeScope.today,
                scopeStartDate = null, scopeEndDate = null, hasSpecificDay = true,
                startTime = if (hasTime) day.withTime(time.hour, time.minute) else day,
                hasSpecificTime = hasTime,
            )
        }
        Haptics.success()
        MainScope.launch { TaskManager.updateTask(updated) }
        dismiss()
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("inbox_plan".localized, leading = { BarButton("cancel".localized, onClick = dismiss) }, trailing = { BarButton("done".localized, bold = true) { plan() } })
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(androidx.compose.foundation.rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            T(task.name, Fonts.headline)
            val options = listOf(
                Triple("today", "today".localized, "star.fill"),
                Triple("tomorrow", "tomorrow".localized, "sunrise.fill"),
                Triple("thisWeek", "this_week".localized, "target"),
                Triple("custom", "select_date".localized, "calendar"),
            )
            options.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { (id, title, icon) ->
                        val selected = choice == id
                        val color = if (selected) Color.White else theme.primaryColor
                        Row(
                            Modifier
                                .weight(1f)
                                .defaultMinSize(minHeight = 44.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (selected) theme.primaryColor else theme.primaryColor.copy(alpha = 0.1f))
                                .tap {
                                    Haptics.selection()
                                    choice = id
                                }
                                .padding(horizontal = 6.dp, vertical = 6.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            SF(icon, color, 16.dp)
                            T(title, Fonts.subheadline.semibold, color)
                        }
                    }
                }
            }
            AnimatedVisibility(choice == "custom", enter = fadeIn(tween(200)) + expandVertically(tween(200)), exit = fadeOut(tween(200)) + shrinkVertically(tween(200))) {
                GraphicalDatePicker(
                    date, { date = it },
                    Modifier.clip(RoundedCornerShape(16.dp)).background(theme.surfaceColor).padding(8.dp),
                    tint = theme.primaryColor,
                    minDate = now().startOfDay(),
                )
            }
            if (choice != "thisWeek") {
                Column(Modifier.clip(RoundedCornerShape(16.dp)).background(theme.surfaceColor).padding(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        SF("clock", theme.accentColor, 20.dp)
                        T("specific_time".localized, Fonts.body, modifier = Modifier.weight(1f))
                        IOSToggle(hasTime, { hasTime = it }, theme.primaryColor)
                    }
                    AnimatedVisibility(hasTime, enter = fadeIn(tween(200)) + expandVertically(tween(200)), exit = fadeOut(tween(200)) + shrinkVertically(tween(200))) {
                        TimeWheel(time, { time = it }, Modifier.padding(top = 8.dp))
                    }
                }
            }
            // Everything a normal task has (period, recurrence, reminders, category...).
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(theme.surfaceColor)
                    .pressable(onClick = onMoreOptions)
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                SF("slider.horizontal.3", theme.primaryColor, 18.dp)
                T("inbox_plan_more_options".localized, Fonts.body, modifier = Modifier.weight(1f))
                SF("chevron.right", theme.secondaryTextColor, 18.dp)
            }
        }
    }
}

// MARK: - Calendar events

@Composable
fun CalendarEventsSection(onAdd: (CalendarFeedEvent) -> Unit) {
    val theme = theme
    val added = CalendarEventsFeed.addedEventIds
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(theme.surfaceColor)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SF("calendar", theme.secondaryTextColor, 15.dp)
            T("calendar_events_section_title".localized, Fonts.subheadline.bold, theme.secondaryTextColor)
        }
        CalendarEventsFeed.events.forEach { event ->
            key(event.id) { CalendarEventRow(event, event.id in added, onAdd = { onAdd(event) }) }
        }
    }
}

@Composable
fun CalendarEventRow(event: CalendarFeedEvent, isAdded: Boolean, compact: Boolean = false, onAdd: () -> Unit) {
    val theme = theme
    val subtitle = (if (event.isAllDay) "all_day".localized else "${event.startDate.timeText()} – ${event.endDate.timeText()}") + " · ${event.calendarTitle}"
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 12.dp)) {
        val circle = if (compact) 26.dp else 34.dp
        Box(Modifier.size(circle).background(event.color.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
            SF(if (event.isBirthday) "gift.fill" else "calendar", event.color, if (compact) 13.dp else 16.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(event.title, if (compact) systemFont(14, FontWeight.Medium) else Fonts.subheadline.semibold)
            T(subtitle, Fonts.caption, theme.secondaryTextColor)
        }
        if (isAdded) {
            SF("checkmark.circle.fill", theme.primaryColor, if (compact) 24.dp else 26.dp)
        } else {
            Box(
                Modifier.pressable {
                    Haptics.light()
                    onAdd()
                }
            ) { SF("plus.circle.fill", theme.primaryColor, if (compact) 24.dp else 26.dp) }
        }
    }
}

// MARK: - Time view (Structured-style day line)

private sealed class DayRow {
    abstract val id: String
    data class Item(val item: DayItem, val isFirst: Boolean, val isLast: Boolean) : DayRow() {
        override val id get() = item.id
    }
    data class Free(val from: Date, val to: Date, val isPast: Boolean) : DayRow() {
        override val id get() = "free-${from.epochSecond}"
    }
    data class Now(val date: Date) : DayRow() {
        override val id get() = "now"
    }
    data object EmptyDay : DayRow() {
        override val id get() = "emptyDay"
    }
}

private data class DayItem(val task: TodoTask?, val event: CalendarFeedEvent?, val start: Date, val end: Date) {
    val id: String get() = task?.let { "task-${it.id.uuidString}" } ?: "event-${event?.id}"
}

private const val MIN_FREE_GAP = 15 * 60.0

@Composable
private fun TimelineContentView() {
    val theme = theme
    val presenter = LocalPresenter.current
    var isAllDayExpanded by remember { mutableStateOf(true) }
    var currentTime by remember { mutableStateOf(now()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            currentTime = now()
        }
    }
    LaunchedEffect(vm.selectedDate) { CalendarEventsFeed.load(vm.selectedDate) }

    val added = CalendarEventsFeed.addedEventIds
    val pendingEvents = if (CalendarEventsFeed.isEnabled) CalendarEventsFeed.events.filter { it.id !in added } else emptyList()
    val forDay = vm.tasksForSelectedDate()
    val allDayTasks = forDay.filter { !it.hasSpecificTime }
    val allDayEvents = pendingEvents.filter { it.isAllDay }

    val dayStart = vm.selectedDate.startOfDay()
    val dayEnd = dayStart.addingDays(1)
    val items = (forDay.filter { it.hasSpecificTime }.map { task ->
        val start = if (task.recurrence != null) task.occurrenceDate(vm.selectedDate) else task.startTime
        DayItem(task, null, start, start.plusSeconds((if (task.hasDuration) max(0.0, task.duration) else 0.0).toLong()))
    } + pendingEvents.filter { !it.isAllDay }.map { event ->
        DayItem(null, event, maxOf(event.startDate, dayStart), minOf(event.endDate, dayEnd))
    }).sortedWith(compareBy<DayItem> { it.start }.thenBy { it.end })

    val rows = remember(items, currentTime, vm.isToday) { buildDayRows(items, currentTime, vm.isToday) }

    val listState = rememberLazyListState()
    val headerCount = if (allDayTasks.isNotEmpty() || allDayEvents.isNotEmpty()) 1 else 0
    val nowIndex = run {
        val index = rows.indexOfFirst { it is DayRow.Now }
        if (index >= 0) index else {
            val current = items.lastOrNull { it.start <= currentTime }
            rows.indexOfFirst { it is DayRow.Item && it.item == current }.coerceAtLeast(0)
        }
    }
    val scope = rememberCoroutineScope()
    LaunchedEffect(vm.selectedDate) {
        delay(250)
        when {
            allDayEvents.isNotEmpty() -> listState.animateScrollToItem(0)
            vm.isToday -> listState.animateScrollToItem(headerCount + nowIndex, -300)
            else -> listState.animateScrollToItem(0)
        }
    }

    fun schedule(at: Date) {
        // Round up to the next 5 minutes, so free time "from 10:47" proposes 10:50.
        val minutes = at.minute
        val rounded = at.plusSeconds(((5 - minutes % 5) % 5) * 60L).withTime(at.plusSeconds(((5 - minutes % 5) % 5) * 60L).hour, at.plusSeconds(((5 - minutes % 5) % 5) * 60L).minute)
        Haptics.selection()
        TimelineActions.newTask(presenter, rounded)
    }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            DailyStatsBar(forDay) { scope.launch { listState.animateScrollToItem(headerCount + nowIndex, -300) } }
            Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.borderColor.copy(alpha = 0.4f)))
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 8.dp, end = 8.dp, top = 10.dp, bottom = tabBarInset() + 84.dp),
            ) {
                if (headerCount > 0) {
                    item("allDay") {
                        AllDaySection(allDayTasks, allDayEvents, isAllDayExpanded, { isAllDayExpanded = !isAllDayExpanded })
                        Spacer(Modifier.height(10.dp))
                    }
                }
                items(rows, key = { it.id }) { row ->
                    when (row) {
                        is DayRow.Item -> {
                            val item = row.item
                            val accent = item.task?.let { it.category?.let { c -> colorFromHex(c.color) } ?: theme.primaryColor } ?: item.event!!.color
                            val isDone = item.task?.let { it.completions[it.completionKey(vm.selectedDate)]?.isCompleted == true } == true
                            TimelineItemRow(
                                item.start, item.end, accent, isDone,
                                isNow = vm.isToday && currentTime >= item.start && currentTime < maxOf(item.end, item.start.plusSeconds(1800)),
                                hidesLineAbove = row.isFirst,
                                hidesLineBelow = row.isLast && !(vm.isToday && currentTime >= item.end),
                            ) {
                                if (item.task != null) TimelineTaskCard(item.task)
                                else TimelineCalendarEventCard(item.event!!) { TimelineActions.addFromCalendar(presenter, item.event) }
                            }
                        }
                        is DayRow.Free -> TimelineFreeTimeRow(row.from, row.to, row.isPast) { schedule(row.from) }
                        is DayRow.Now -> TimelineNowRow(row.date)
                        DayRow.EmptyDay -> TimelineFreeTimeRow(null, null, false) {
                            schedule(
                                if (vm.isToday) vm.selectedDate.withTime(min(23, currentTime.hour + 1), 0)
                                else vm.selectedDate.withTime(9, 0)
                            )
                        }
                    }
                }
            }
        }
        Box(Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarInset() + 12.dp)) {
            AddTaskButton { TimelineActions.newTask(presenter) }
        }
    }
}

private fun buildDayRows(items: List<DayItem>, current: Date, showsNow: Boolean): List<DayRow> {
    val rows = ArrayList<DayRow>()
    var nowPlaced = !showsNow
    if (items.isEmpty()) {
        if (showsNow) rows += DayRow.Now(current)
        rows += DayRow.EmptyDay
        return rows
    }
    fun addFree(from: Date, to: Date) {
        if (!nowPlaced && current >= from && current < to) {
            if (current.timeIntervalSince(from) >= MIN_FREE_GAP) rows += DayRow.Free(from, current, true)
            rows += DayRow.Now(current)
            nowPlaced = true
            if (to.timeIntervalSince(current) >= MIN_FREE_GAP) rows += DayRow.Free(current, to, false)
        } else if (to.timeIntervalSince(from) >= MIN_FREE_GAP) {
            rows += DayRow.Free(from, to, showsNow && to <= current)
        }
    }
    if (!nowPlaced && current < items[0].start) {
        rows += DayRow.Now(current)
        nowPlaced = true
        if (items[0].start.timeIntervalSince(current) >= MIN_FREE_GAP) rows += DayRow.Free(current, items[0].start, false)
    }
    var cursor = items[0].start
    items.forEachIndexed { index, item ->
        if (index > 0 && item.start > cursor) addFree(cursor, item.start)
        rows += DayRow.Item(item, index == 0, index == items.lastIndex)
        cursor = maxOf(cursor, item.end)
    }
    if (!nowPlaced && current >= cursor) rows += DayRow.Now(current)
    return rows
}

@Composable
private fun AllDaySection(tasks: List<TodoTask>, events: List<CalendarFeedEvent>, expanded: Boolean, onToggle: () -> Unit) {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(theme.surfaceColor.copy(alpha = 0.5f))
            .animateContentSize(tween(300)),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .tap(onClick = onToggle)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SF("sun.max.fill", Color.SysOrange, 15.dp)
            T("all_day".localized, systemFont(13, FontWeight.Bold))
            T(
                "${tasks.size + events.size}",
                systemFont(11, FontWeight.Bold),
                theme.primaryColor,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(theme.primaryColor.copy(alpha = 0.12f))
                    .padding(horizontal = 7.dp, vertical = 2.dp),
            )
            Spacer(Modifier.weight(1f))
            SF(if (expanded) "chevron.up" else "chevron.down", theme.secondaryTextColor, 16.dp)
        }
        if (expanded) {
            Column(
                Modifier.padding(start = 12.dp, end = 12.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                events.forEach { event ->
                    key(event.id) { TimelineCalendarEventCard(event) { TimelineActions.addFromCalendar(presenter, event) } }
                }
                tasks.forEach { task -> key(task.id) { CompactTimelineTaskView(task) } }
            }
        }
    }
}

@Composable
private fun TimelineCalendarEventCard(event: CalendarFeedEvent, onAdd: () -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(10.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .shadow(1.dp, shape, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(1.dp, event.color.copy(alpha = 0.35f), shape)
            .padding(horizontal = 12.dp, vertical = 9.dp)
    ) {
        CalendarEventRow(event, event.id in CalendarEventsFeed.addedEventIds, compact = true, onAdd = onAdd)
    }
}

@Composable
private fun DailyStatsBar(tasks: List<TodoTask>, onJumpToNow: () -> Unit) {
    val theme = theme
    val completed = tasks.count { it.completions[it.completionKey(vm.selectedDate)]?.isCompleted == true }
    val total = tasks.size
    val percent = if (total > 0) completed * 100 / total else 0
    val seconds = tasks.sumOf { if (it.hasDuration) it.duration else 0.0 }
    val hours = seconds.toInt() / 3600
    val minutes = seconds.toInt() % 3600 / 60
    Row(
        Modifier
            .fillMaxWidth()
            .background(theme.backgroundColor)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            Modifier
                .clip(CircleShape)
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor.copy(alpha = 0.6f), CircleShape)
                .padding(horizontal = 9.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            SF(if (completed == total && total > 0) "checkmark.circle.fill" else "circle.dashed", theme.primaryColor, 14.dp)
            T("$completed/$total", systemFont(12, FontWeight.Bold), maxLines = 1)
            if (total > 0) T("• $percent%", systemFont(11, FontWeight.SemiBold), theme.secondaryTextColor, maxLines = 1)
        }
        if (seconds > 0) {
            Row(
                Modifier
                    .clip(CircleShape)
                    .background(theme.surfaceColor)
                    .border(1.dp, theme.borderColor.copy(alpha = 0.6f), CircleShape)
                    .padding(horizontal = 8.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SF("hourglass", theme.secondaryTextColor, 12.dp)
                T(if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m", systemFont(11, FontWeight.SemiBold), theme.secondaryTextColor, maxLines = 1)
            }
        }
        Spacer(Modifier.weight(1f))
        if (vm.isToday) {
            Row(
                Modifier
                    .shadow(3.dp, CircleShape, ambientColor = theme.primaryColor.copy(alpha = 0.35f), spotColor = theme.primaryColor.copy(alpha = 0.35f))
                    .clip(CircleShape)
                    .background(theme.primaryColor)
                    .pressable {
                        Haptics.selection()
                        onJumpToNow()
                    }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Box(Modifier.size(6.dp).background(Color.White, CircleShape))
                T("task_in_progress_now".localized, systemFont(11, FontWeight.Bold), Color.White, maxLines = 1)
            }
        }
    }
}

private val timeColumnWidth get() = if (TimeFormatPreference.uses12HourClock) 62.dp else 42.dp
private val railWidth = 14.dp
private val railSpacing = 4.dp
private val dotSize = 14.dp
private val dotCenterY = 26.dp

@Composable
private fun TimelineItemRow(
    start: Date,
    end: Date,
    accent: Color,
    isDone: Boolean,
    isNow: Boolean,
    hidesLineAbove: Boolean,
    hidesLineBelow: Boolean,
    content: @Composable () -> Unit,
) {
    val theme = theme
    val line = theme.secondaryTextColor.copy(alpha = 0.35f)
    Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(railSpacing)) {
        Column(
            Modifier.width(timeColumnWidth).padding(top = dotCenterY - 8.dp),
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            T(start.timeText(), systemFont(12, FontWeight.SemiBold), if (isNow) theme.primaryColor else theme.textColor, maxLines = 1)
            if (end > start) T(end.timeText(), systemFont(11, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
        }
        Column(Modifier.width(railWidth).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.width(2.dp).height(dotCenterY - dotSize / 2).background(if (hidesLineAbove) Color.Transparent else line))
            Box(
                Modifier
                    .size(dotSize)
                    .background(if (isDone) accent else if (isNow) accent.copy(alpha = 0.25f) else theme.backgroundColor, CircleShape)
                    .border(2.5.dp, accent, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                if (isDone) SF("checkmark", Color.White, 9.dp)
            }
            Box(Modifier.width(2.dp).weight(1f).background(if (hidesLineBelow) Color.Transparent else line))
        }
        Box(Modifier.weight(1f).padding(vertical = 5.dp)) { content() }
    }
}

@Composable
private fun TimelineFreeTimeRow(from: Date?, to: Date?, isPast: Boolean, onAdd: () -> Unit) {
    val theme = theme
    val minutes = if (from != null && to != null) max(0, (to.timeIntervalSince(from) / 60).toInt()) else 0
    val label = if (from == null) "timeline_day_free".localized else {
        val hours = minutes / 60
        val mins = minutes % 60
        val duration = when {
            hours > 0 && mins > 0 -> "${hours}h ${mins}m"
            hours > 0 -> "${hours}h"
            else -> "${mins}m"
        }
        "timeline_free_time".localized(duration)
    }
    val padding = if (from == null) 10.dp else min(28f, max(4f, minutes / 8f)).dp
    val line = theme.secondaryTextColor.copy(alpha = 0.35f)
    Row(Modifier.height(IntrinsicSize.Min), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(railSpacing)) {
        Spacer(Modifier.width(timeColumnWidth))
        Canvas(Modifier.width(railWidth).fillMaxHeight()) {
            drawLine(
                line, Offset(size.width / 2, 0f), Offset(size.width / 2, size.height),
                strokeWidth = 2.dp.toPx(), cap = StrokeCap.Round,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 5.dp.toPx())),
            )
        }
        Row(
            Modifier
                .weight(1f)
                .padding(vertical = padding)
                .clip(RoundedCornerShape(10.dp))
                .background(theme.surfaceColor.copy(alpha = if (isPast) 0.3f else 0.6f))
                .alpha(if (isPast) 0.8f else 1f)
                .tap(!isPast, onAdd)
                .padding(horizontal = 12.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            SF(if (isPast) "hourglass.bottomhalf.filled" else "hourglass", theme.secondaryTextColor, 13.dp)
            T(label, systemFont(12, FontWeight.SemiBold), theme.secondaryTextColor, modifier = Modifier.weight(1f))
            if (!isPast) SF("plus.circle.fill", theme.primaryColor, 20.dp)
        }
    }
}

@Composable
private fun TimelineNowRow(date: Date) {
    val theme = theme
    Row(
        Modifier.padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(railSpacing),
    ) {
        T(date.timeText(), systemFont(12, FontWeight.Bold), theme.primaryColor, TextAlign.End, Modifier.width(timeColumnWidth), maxLines = 1)
        Box(Modifier.width(railWidth), contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(10.dp)
                    .shadow(3.dp, CircleShape, ambientColor = theme.primaryColor.copy(alpha = 0.4f), spotColor = theme.primaryColor.copy(alpha = 0.4f))
                    .background(theme.primaryColor, CircleShape)
            )
        }
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            T(
                "task_in_progress_now".localized,
                systemFont(11, FontWeight.Bold),
                Color.White,
                maxLines = 1,
                modifier = Modifier.clip(CircleShape).background(theme.primaryColor).padding(horizontal = 8.dp, vertical = 3.dp),
            )
            Box(Modifier.weight(1f).height(1.5.dp).background(theme.primaryColor))
        }
    }
}

@Composable
fun CompactTimelineTaskView(task: TodoTask) {
    val theme = theme
    val presenter = LocalPresenter.current
    val date = vm.selectedDate
    val state = TaskManager.progressState(task, date)
    val isCompleted = state == TaskProgressState.completed
    var menuOpen by remember { mutableStateOf(false) }
    var showingDeleteSessionsDialog by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(10.dp)

    if (showingDeleteSessionsDialog) {
        ConfirmationDialog(
            message = "delete_task_sessions_message".localized(TaskManager.trackingSessionCount(task.id)),
            actions = listOf(
                AlertAction("delete_task_and_sessions".localized, AlertRole.destructive) { MainScope.launch { TaskManager.removeTask(task, true) } },
                AlertAction("delete_task_keep_sessions".localized) { MainScope.launch { TaskManager.removeTask(task, false) } },
                AlertAction("cancel".localized, AlertRole.cancel),
            ),
            onDismiss = { showingDeleteSessionsDialog = false },
        )
    }

    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .shadow(1.dp, shape, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(shape)
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor.copy(alpha = 0.6f), shape)
                .pointerInput(task.id) {
                    detectTapGestures(
                        onTap = { TimelineActions.openDetail(presenter, task.id, vm.selectedDate) },
                        onLongPress = { menuOpen = true },
                    )
                }
                .padding(horizontal = 12.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                Modifier
                    .size(26.dp)
                    .background(if (isCompleted) theme.primaryColor.copy(alpha = 0.2f) else theme.surfaceColor, CircleShape)
                    .taskStatusGestures(
                        onTap = {
                            if (!isCompleted) Haptics.success() else Haptics.selection()
                            vm.toggleTaskCompletion(task.id)
                        },
                        onLongPress = {
                            InProgressTip.markLearned()
                            TaskManager.toggleInProgress(task.id, date)
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                TaskStatusIcon(state, theme.secondaryTextColor, theme.primaryColor, 19.dp)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    task.category?.let { Box(Modifier.size(7.dp).background(colorFromHex(it.color), CircleShape)) }
                    T(task.name, systemFont(14, FontWeight.Medium))
                }
                task.description?.takeIf { it.isNotEmpty() }?.let { T(it, Fonts.caption, theme.secondaryTextColor) }
            }
            if (task.subtasks.isNotEmpty()) {
                Row(
                    Modifier
                        .clip(CircleShape)
                        .background(theme.surfaceColor)
                        .padding(horizontal = 5.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    SF("checklist", theme.secondaryTextColor, 11.dp)
                    T("${task.subtasks.count { it.isCompleted }}/${task.subtasks.size}", systemFont(10, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
                }
            }
            if (task.priority == Priority.high) SF(task.priority.icon, colorFromHex(task.priority.colorHex), 13.dp)
        }
        if (menuOpen) {
            MenuPopup(
                listOf(
                    MenuItem("task_status_todo".localized, "circle", checked = state == TaskProgressState.todo) { TaskManager.setProgressState(TaskProgressState.todo, task.id, date) },
                    MenuItem("task_status_in_progress".localized, "circle.lefthalf.filled", checked = state == TaskProgressState.inProgress) {
                        InProgressTip.markLearned()
                        TaskManager.setProgressState(TaskProgressState.inProgress, task.id, date)
                    },
                    MenuItem("task_status_completed".localized, "checkmark.circle.fill", checked = isCompleted) { TaskManager.setProgressState(TaskProgressState.completed, task.id, date) },
                    MenuItem("move_to_tomorrow".localized, "arrow.right.circle") { vm.moveTaskToTomorrow(task) },
                    MenuItem("duplicate".localized, "plus.square.on.square") { vm.duplicateTask(task) },
                    MenuItem("delete".localized, "trash", destructive = true) {
                        Haptics.medium()
                        if (TaskManager.trackingSessionCount(task.id) > 0) showingDeleteSessionsDialog = true else vm.deleteTask(task)
                    },
                )
            ) { menuOpen = false }
        }
    }
}
