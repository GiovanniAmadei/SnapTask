package com.snaptask.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import kotlin.math.abs

/** `ModernCard` */
@Composable
fun ModernCard(title: String, icon: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    Column(
        modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .themedCard()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF(icon, theme.primaryColor, 18.dp)
            T(title, Fonts.headline)
        }
        content()
    }
}

/** `ModernToggle`: a slightly smaller switch. */
@Composable
fun ModernToggle(isOn: Boolean, onChange: (Boolean) -> Unit) {
    IOSToggle(isOn, onChange, theme.primaryColor)
}

/** A rounded field with the focused border of the app's forms. */
@Composable
fun ThemedField(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    minHeight: androidx.compose.ui.unit.Dp = 0.dp,
    keyboard: KeyboardType = KeyboardType.Text,
    align: TextAlign = TextAlign.Start,
    style: TextStyle = Fonts.body,
) {
    val theme = theme
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(10.dp)
    BasicTextField(
        value, onChange,
        singleLine = singleLine,
        textStyle = style.copy(color = theme.textColor, textAlign = align),
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        cursorBrush = SolidColor(theme.primaryColor),
        modifier = modifier
            .defaultMinSize(minHeight = minHeight)
            .clip(shape)
            .background(theme.backgroundColor)
            .border(if (focused) 2.dp else 1.dp, if (focused) theme.primaryColor else theme.borderColor, shape)
            .onFocusChanged { focused = it.isFocused }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) T(placeholder, style, theme.secondaryTextColor, align, Modifier.fillMaxWidth())
                inner()
            }
        },
    )
}

@Composable
private fun LabelRow(title: String, subtitle: String? = null, trailing: @Composable () -> Unit) {
    val theme = theme
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(title, Fonts.subheadline.medium)
            if (subtitle != null) T(subtitle, Fonts.caption, theme.secondaryTextColor)
        }
        Spacer(Modifier.width(8.dp))
        trailing()
    }
}

@Composable
private fun CompactDate(date: Date, onChange: (Date) -> Unit, minDate: Date? = null, maxDate: Date? = null) {
    var open by remember { mutableStateOf(false) }
    val presenter = LocalPresenter.current
    T(
        date.dateStyle(java.time.format.FormatStyle.MEDIUM),
        Fonts.subheadline,
        if (open) theme.accentColor else Color.Primary,
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(Color.TertiaryFill)
            .tap {
                open = true
                presenter.sheet(detent = SheetDetent.fit, onDismiss = { open = false }) {
                    val dismiss = LocalDismiss.current
                    var current by remember { mutableStateOf(date) }
                    Column(Modifier.background(theme.backgroundColor).navigationBarsPadding().padding(16.dp)) {
                        GraphicalDatePicker(current, {
                            current = it
                            onChange(it)
                        }, minDate = minDate, maxDate = maxDate)
                        Spacer(Modifier.height(8.dp))
                        FilledButton("done".localized, onClick = dismiss)
                    }
                }
            }
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

@Composable
fun CompactTime(date: Date, onChange: (Date) -> Unit) {
    val presenter = LocalPresenter.current
    val theme = theme
    T(
        date.timeText(),
        Fonts.subheadline,
        Color.Primary,
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(Color.TertiaryFill)
            .tap {
                presenter.sheet(detent = SheetDetent.fit) {
                    val dismiss = LocalDismiss.current
                    var current by remember { mutableStateOf(date) }
                    Column(Modifier.background(theme.backgroundColor).navigationBarsPadding().padding(16.dp)) {
                        TimeWheel(current, {
                            current = it
                            onChange(it)
                        })
                        Spacer(Modifier.height(8.dp))
                        FilledButton("done".localized, onClick = dismiss)
                    }
                }
            }
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

private fun clipboard(): ClipboardManager = App.context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

/** Picks the initial state once, as `@StateObject` does. */
@Composable
fun TaskFormView(
    initialDate: Date = now(),
    initialTimeScope: TaskTimeScope? = null,
    initialName: String? = null,
    scopeStartDate: Date? = null,
    preserveTime: Boolean = false,
    initialTask: TodoTask? = null,
    editScope: EditScopeMode = EditScopeMode.entireSeries,
    onSave: (TodoTask) -> Unit,
) {
    val viewModel = remember {
        if (initialTask != null) TaskFormViewModel.from(initialTask, editScope, preserveTime)
        else TaskFormViewModel(initialDate, preserveTime).apply {
            initialTimeScope?.let { selectedTimeScope = it }
            if (preserveTime) {
                hasSpecificTime = true
                startDate = initialDate
            }
            initialName?.let { name = it }
            if (scopeStartDate != null) {
                when (initialTimeScope) {
                    TaskTimeScope.week -> selectedWeekDate = scopeStartDate
                    TaskTimeScope.month -> {
                        selectedMonth = scopeStartDate.month
                        selectedYear = scopeStartDate.yearNumber
                        selectedMonthDate = scopeStartDate
                    }
                    TaskTimeScope.year -> {
                        selectedYear = scopeStartDate.yearNumber
                        selectedYearDate = scopeStartDate
                    }
                    else -> Unit
                }
            }
        }
    }
    NavigationStack { TaskFormContent(viewModel, onSave) }
}

@Composable
private fun TaskFormContent(viewModel: TaskFormViewModel, onSave: (TodoTask) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val navigator = LocalNavigator.current
    val focus = LocalFocusManager.current
    var newSubtaskName by remember { mutableStateOf("") }

    LaunchedEffect(viewModel.startDate, viewModel.hasSpecificTime, viewModel.selectedTimeScope) { viewModel.syncPeriodWithStartDate() }

    fun save() {
        if (!viewModel.isValid) return
        onSave(viewModel.createTask())
        dismiss()
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            if (viewModel.taskId == null) "new_task".localized else "edit_task".localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = { BarButton("save".localized, enabled = viewModel.isValid, bold = true, color = theme.primaryColor) { save() } },
        )
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Edit scope: shown at top when editing a recurring task
            if (viewModel.isEditing && (viewModel.isRecurring || viewModel.initialTask?.recurrence != null)) {
                ModernCard("edit_scope_title".localized, "arrow.triangle.branch") {
                    T("edit_scope_description".localized, Fonts.caption, theme.secondaryTextColor)
                    SegmentedControl(EditScopeMode.entries, viewModel.editScopeMode, { viewModel.editScopeMode = it }, {
                        if (it == EditScopeMode.entireSeries) "edit_scope_entire_series".localized else "edit_scope_single_instance".localized
                    })
                }
            }

            // Task details
            ModernCard("task_details".localized, "doc.text") {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("task_name".localized, Fonts.subheadline.medium)
                    ThemedField(viewModel.name, { viewModel.name = it }, "enter_task_name".localized, Modifier.fillMaxWidth())
                }
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("task_description".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                        val hasText = viewModel.description.isNotEmpty()
                        IOSMenu(
                            listOf(
                                MenuItem("copy".localized, enabled = hasText) {
                                    clipboard().setPrimaryClip(ClipData.newPlainText("", viewModel.description))
                                },
                                MenuItem("cut".localized, enabled = hasText) {
                                    clipboard().setPrimaryClip(ClipData.newPlainText("", viewModel.description))
                                    viewModel.description = ""
                                },
                                MenuItem("paste".localized, enabled = clipboard().hasPrimaryClip()) {
                                    val text = clipboard().primaryClip?.getItemAt(0)?.text?.toString().orEmpty()
                                    if (text.isNotEmpty()) viewModel.description = if (viewModel.description.isEmpty()) text else viewModel.description + "\n" + text
                                },
                            )
                        ) { SF("ellipsis.circle", theme.secondaryTextColor, 18.dp) }
                    }
                    ThemedField(viewModel.description, { viewModel.description = it }, "add_description".localized, Modifier.fillMaxWidth(), singleLine = false, minHeight = 110.dp)
                }
                Row(
                    Modifier.fillMaxWidth().tap { navigator?.push { LocationPickerView(viewModel.location) { viewModel.location = it } } },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    T("location".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                    T(viewModel.location?.shortDisplayName ?: "add_location".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.End)
                    SF("chevron.right", theme.secondaryTextColor, 16.dp)
                }
                Row(
                    Modifier.fillMaxWidth().tap { navigator?.push { IconPickerView(viewModel.icon) { viewModel.icon = it } } },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    T("icon".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                    SF(viewModel.icon, theme.secondaryTextColor, 20.dp)
                    SF("chevron.right", theme.secondaryTextColor, 16.dp)
                }
            }

            // Time
            ModernCard("time".localized, "clock") { TimeSection(viewModel) }

            // Category & priority
            ModernCard("category_priority".localized, "folder.fill") {
                Row(
                    Modifier.fillMaxWidth().tap { navigator?.push { CategoryPickerView(viewModel.selectedCategory) { viewModel.selectedCategory = it } } },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    T("category".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                    val category = viewModel.selectedCategory
                    if (category != null) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.size(12.dp).background(colorFromHex(category.color), CircleShape))
                            T(category.name, Fonts.subheadline, theme.secondaryTextColor)
                        }
                    } else T("select_category".localized, Fonts.subheadline, theme.secondaryTextColor)
                    SF("chevron.right", theme.secondaryTextColor, 16.dp)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("priority".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                    IOSMenu(Priority.entries.map { p -> MenuItem(p.displayName, p.icon, checked = viewModel.selectedPriority == p) { viewModel.selectedPriority = p } }) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SF(viewModel.selectedPriority.icon, colorFromHex(viewModel.selectedPriority.colorHex), 14.dp)
                            T(viewModel.selectedPriority.displayName, Fonts.subheadline, theme.secondaryTextColor)
                            SF("chevron.down", theme.secondaryTextColor, 14.dp)
                        }
                    }
                }
            }

            // Recurrence
            if (viewModel.shouldShowRecurrenceOption) {
                ModernCard("recurrence".localized, "repeat") {
                    LabelRow("repeat_task".localized) { ModernToggle(viewModel.isRecurring) { viewModel.isRecurring = it } }
                    AnimatedVisibility(viewModel.isRecurring, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(250)) + shrinkVertically(tween(250))) {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            if (viewModel.selectedTimeScope == TaskTimeScope.today) {
                                Row(
                                    Modifier.fillMaxWidth().tap { navigator?.push { EnhancedRecurrenceSettingsView(viewModel) } },
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    T("frequency".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                                    T(viewModel.recurrenceType.localizedString, Fonts.subheadline, theme.secondaryTextColor)
                                    SF("chevron.right", theme.secondaryTextColor, 16.dp)
                                }
                            } else {
                                Row(
                                    Modifier.fillMaxWidth().tap { navigator?.push { ContextualRecurrenceSettingsView(viewModel) } },
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    T("frequency".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                                    Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1.4f)) {
                                        T(viewModel.recurrenceDisplayText, Fonts.subheadline, theme.secondaryTextColor, TextAlign.End)
                                        T("contextual_to_scope".localized, Fonts.caption, theme.secondaryTextColor.copy(alpha = 0.7f), TextAlign.End)
                                    }
                                    SF("chevron.right", theme.secondaryTextColor, 16.dp)
                                }
                            }
                            LabelRow("track_in_consistency".localized) { ModernToggle(viewModel.trackInStatistics) { viewModel.trackInStatistics = it } }
                        }
                    }
                }
            }

            // Subtasks
            ModernCard("subtasks".localized, "checklist") {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    ThemedField(newSubtaskName, { newSubtaskName = it }, "add_subtask".localized, Modifier.weight(1f))
                    val enabled = newSubtaskName.isNotEmpty()
                    T(
                        "add".localized,
                        Fonts.subheadline.medium,
                        theme.backgroundColor,
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (enabled) theme.primaryColor else theme.primaryColor.copy(alpha = 0.4f))
                            .pressable(enabled) {
                                viewModel.addSubtask(newSubtaskName)
                                newSubtaskName = ""
                            }
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                    )
                }
                viewModel.subtasks.forEach { subtask ->
                    key(subtask.id) {
                        Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SF("circle", theme.secondaryTextColor, 14.dp)
                            T(subtask.name, Fonts.subheadline, modifier = Modifier.weight(1f))
                            Box(Modifier.tap { viewModel.removeSubtask(subtask.id) }) { SF("minus.circle.fill", Color.SysRed, 18.dp) }
                        }
                    }
                }
            }

            // Rewards
            ModernCard("reward_points".localized, "star") {
                LabelRow("earn_reward_points".localized) { ModernToggle(viewModel.hasRewardPoints) { viewModel.hasRewardPoints = it } }
                AnimatedVisibility(viewModel.hasRewardPoints, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(250)) + shrinkVertically(tween(250))) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        LabelRow("custom_points".localized) { ModernToggle(viewModel.useCustomPoints) { viewModel.useCustomPoints = it } }
                        Row(Modifier.height(100.dp), verticalAlignment = Alignment.CenterVertically) {
                            T("points".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                            if (viewModel.useCustomPoints) {
                                ThemedField(
                                    viewModel.customPointsText,
                                    { value ->
                                        val filtered = value.filter { it.isDigit() }
                                        viewModel.customPointsText = filtered
                                        filtered.toIntOrNull()?.takeIf { it in 1..999 }?.let { viewModel.rewardPoints = it }
                                    },
                                    "points".localized,
                                    Modifier.width(84.dp),
                                    keyboard = KeyboardType.Number,
                                    align = TextAlign.Center,
                                )
                                Spacer(Modifier.width(6.dp))
                                T("(1-999)", Fonts.caption, theme.secondaryTextColor)
                            } else {
                                val options = listOf(1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200)
                                WheelPicker(options, viewModel.rewardPoints.takeIf { it in options } ?: 5, {
                                    viewModel.rewardPoints = it
                                    viewModel.customPointsText = "$it"
                                }, { "$it" }, Modifier.width(80.dp), rowHeight = 30.dp, visibleRows = 3)
                            }
                        }
                        Column(Modifier.fillMaxWidth().padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            T("point_guidelines".localized, Fonts.caption.medium, theme.secondaryTextColor)
                            T("• 1-10: " + "quick_tasks_5_15_min".localized, Fonts.caption, theme.secondaryTextColor)
                            T("• 15-50: " + "regular_tasks_30_90_min".localized, Fonts.caption, theme.secondaryTextColor)
                            T("• 75-200: " + "complex_tasks_2_4_hours".localized, Fonts.caption, theme.secondaryTextColor)
                        }
                    }
                }
            }

            // Save
            val enabled = viewModel.isValid
            Row(
                Modifier
                    .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 32.dp)
                    .fillMaxWidth()
                    .shadow(if (enabled) 8.dp else 0.dp, RoundedCornerShape(16.dp), ambientColor = theme.primaryColor.copy(alpha = 0.3f), spotColor = theme.primaryColor.copy(alpha = 0.3f))
                    .clip(RoundedCornerShape(16.dp))
                    .background(if (enabled) theme.gradient else Brush.verticalGradient(listOf(theme.secondaryTextColor, theme.secondaryTextColor.copy(alpha = 0.8f))))
                    .pressable(enabled) { save() }
                    .padding(vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SF("checkmark", theme.backgroundColor, 18.dp)
                T("save_task".localized, Fonts.headline, theme.backgroundColor)
            }
            Spacer(Modifier.navigationBarsPadding())
        }
    }
}

@Composable
private fun LeadTimeSelector(viewModel: TaskFormViewModel) {
    val theme = theme
    val presenter = LocalPresenter.current
    val choices = listOf(5 to "notify_5_min_before", 10 to "notify_10_min_before", 15 to "notify_15_min_before", 30 to "notify_30_min_before", 60 to "notify_60_min_before")
    LabelRow("when_to_notify".localized, leadTimeDescription(viewModel.notificationLeadTimeMinutes)) {
        IOSMenu(
            listOf(MenuItem("at_exact_time".localized, "alarm") { viewModel.notificationLeadTimeMinutes = 0 }) +
                choices.map { (minutes, key) -> MenuItem(key.localized, "bell.and.waveform") { viewModel.notificationLeadTimeMinutes = minutes } } +
                MenuItem("notify_custom".localized, "slider.horizontal.3") {
                    presenter.sheet { NotificationLeadTimePickerView(viewModel.notificationLeadTimeMinutes) { viewModel.notificationLeadTimeMinutes = it } }
                }
        ) {
            Row(
                Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(theme.surfaceColor)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SF("bell.badge", Color.SysBlue, 14.dp)
                T(leadTimeShort(viewModel.notificationLeadTimeMinutes), Fonts.subheadline.semibold, maxLines = 1)
                SF("chevron.down", theme.secondaryTextColor, 14.dp)
            }
        }
    }
}

fun leadTimeDescription(minutes: Int): String {
    if (minutes == 0) return "at_exact_time".localized
    val after = minutes < 0
    val total = abs(minutes)
    val h = total / 60
    val m = total % 60
    return if (after) {
        when {
            h > 0 && m > 0 -> "lead_time_hours_minutes_after_format".localized(h, m)
            h > 0 -> "lead_time_hours_after_format".localized(h)
            else -> "lead_time_minutes_after_format".localized(m)
        }
    } else {
        when {
            h > 0 && m > 0 -> "lead_time_hours_minutes_before_format".localized(h, m)
            h > 0 -> "lead_time_hours_before_format".localized(h)
            else -> "lead_time_minutes_before_format".localized(m)
        }
    }
}

fun leadTimeShort(minutes: Int): String = if (minutes == 0) "lead_time_short_exact".localized else leadTimeDescription(minutes)

@Composable
private fun NotificationRows(viewModel: TaskFormViewModel) {
    val theme = theme
    val manager = TaskNotificationManager
    val requestPermission = rememberNotificationPermission()
    if (manager.areTaskNotificationsEnabled) {
        LabelRow("enable_notification".localized, "notification_scheduled".localized) {
            ModernToggle(viewModel.hasNotification) { on ->
                viewModel.hasNotification = on
                if (on) requestPermission()
            }
        }
        AnimatedVisibility(viewModel.hasNotification, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(250)) + shrinkVertically(tween(250))) {
            LeadTimeSelector(viewModel)
        }
    } else if (viewModel.hasNotification) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(Color.SysOrange.copy(alpha = 0.1f))
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SF("exclamationmark.triangle.fill", Color.SysOrange, 16.dp)
            T("notifications_not_available".localized, Fonts.caption, theme.secondaryTextColor)
        }
        LaunchedEffect(Unit) { viewModel.hasNotification = false }
    }
}

@Composable
private fun TimeSection(viewModel: TaskFormViewModel) {
    val theme = theme
    val scope = viewModel.selectedTimeScope
    val tint = namedColor(scope.colorName)
    LabelRow("time_scope".localized) {
        IOSMenu(TaskTimeScope.entries.filter { it != TaskTimeScope.all }.map { item ->
            MenuItem(item.displayName, item.icon, checked = scope == item) { viewModel.selectedTimeScope = item }
        }) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SF(scope.icon, tint, 14.dp)
                T(viewModel.timeScopeTitle, Fonts.subheadline.semibold, maxLines = 1)
                SF("chevron.down", theme.secondaryTextColor, 14.dp)
            }
        }
    }

    if (scope == TaskTimeScope.today) {
        LabelRow("date".localized) {
            CompactDate(viewModel.startDate, { new -> viewModel.startDate = new.withTime(viewModel.startDate.hour, viewModel.startDate.minute) })
        }
        LabelRow("specific_time".localized, "set_exact_time".localized) {
            ModernToggle(viewModel.hasSpecificTime) {
                viewModel.hasSpecificTime = it
                if (!it) viewModel.hasNotification = false
            }
        }
        AnimatedVisibility(viewModel.hasSpecificTime, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(300)) + shrinkVertically(tween(300))) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                LabelRow("start_time".localized) { CompactTime(viewModel.startDate, { viewModel.startDate = viewModel.startDate.withTime(it.hour, it.minute) }) }
                NotificationRows(viewModel)
            }
        }
        if (!viewModel.isRecurring) {
            LabelRow("auto_carry_over".localized, "auto_carry_over_description".localized) { ModernToggle(viewModel.autoCarryOver) { viewModel.autoCarryOver = it } }
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            val (rangeStart, rangeEnd) = when (scope) {
                TaskTimeScope.week -> viewModel.selectedWeekDate.startOfWeek().let { it to it.addingDays(7).minusSeconds(1) }
                TaskTimeScope.month -> LocalDate.of(viewModel.selectedYear, viewModel.selectedMonth, 1).instant().let { it to it.addingMonths(1).minusSeconds(1) }
                TaskTimeScope.year -> LocalDate.of(viewModel.selectedYear, 1, 1).instant().let { it to it.addingYears(1).minusSeconds(1) }
                TaskTimeScope.longTerm -> now() to now().addingYears(100)
                else -> distantPast to now().addingYears(100)
            }
            fun clamp(date: Date) = maxOf(rangeStart, minOf(rangeEnd, date))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    T("selected_period".localized, Fonts.subheadline.medium)
                    T(viewModel.selectedPeriodDisplayText, Fonts.caption, theme.secondaryTextColor)
                }
                SF(scope.icon, tint, 18.dp)
            }

            when (scope) {
                TaskTimeScope.week -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("select_week".localized, Fonts.caption.medium, theme.secondaryTextColor)
                    CompactDate(viewModel.selectedWeekDate, { viewModel.selectedWeekDate = it }, minDate = now())
                    T("week_range".localized + ": " + viewModel.selectedWeekRangeText, Fonts.caption2, theme.secondaryTextColor, modifier = Modifier.padding(top = 4.dp))
                }
                TaskTimeScope.month -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("select_month".localized, Fonts.caption.medium, theme.secondaryTextColor)
                    Row {
                        WheelPicker((1..12).toList(), viewModel.selectedMonth, { viewModel.selectedMonth = it }, { monthSymbol(it) }, Modifier.weight(1f), rowHeight = 30.dp, visibleRows = 3)
                        WheelPicker(viewModel.availableYears, viewModel.selectedYear, { viewModel.selectedYear = it }, { "$it" }, Modifier.weight(1f), rowHeight = 30.dp, visibleRows = 3)
                    }
                }
                TaskTimeScope.year -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("select_year".localized, Fonts.caption.medium, theme.secondaryTextColor)
                    WheelPicker(viewModel.availableYears, viewModel.selectedYear, { viewModel.selectedYear = it }, { "$it" }, Modifier.fillMaxWidth(), rowHeight = 30.dp, visibleRows = 3)
                }
                TaskTimeScope.longTerm -> T("long_term_info".localized, Fonts.caption, theme.secondaryTextColor)
                else -> Unit
            }

            if (scope != TaskTimeScope.inbox) {
                LabelRow("specific_day".localized, "optional_specific_day".localized) {
                    ModernToggle(viewModel.hasSpecificDay) {
                        viewModel.hasSpecificDay = it
                        if (!it) {
                            viewModel.hasSpecificTime = false
                            viewModel.hasNotification = false
                        }
                    }
                }
                AnimatedVisibility(viewModel.hasSpecificDay, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(300)) + shrinkVertically(tween(300))) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        LabelRow("date".localized) {
                            CompactDate(clamp(viewModel.startDate), { new ->
                                viewModel.startDate = clamp(clamp(new).withTime(viewModel.startDate.hour, viewModel.startDate.minute))
                            }, rangeStart, rangeEnd)
                        }
                        LabelRow("specific_time".localized, "optional_specific_time".localized) {
                            ModernToggle(viewModel.hasSpecificTime) {
                                viewModel.hasSpecificTime = it
                                if (!it) viewModel.hasNotification = false
                            }
                        }
                        AnimatedVisibility(viewModel.hasSpecificTime, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(300)) + shrinkVertically(tween(300))) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                LabelRow("start_time".localized) { CompactTime(viewModel.startDate, { viewModel.startDate = clamp(viewModel.startDate.withTime(it.hour, it.minute)) }) }
                                NotificationRows(viewModel)
                            }
                        }
                    }
                }
            }

            if (!viewModel.isRecurring && scope in listOf(TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year)) {
                val key = when (scope) {
                    TaskTimeScope.week -> "auto_carry_over_description_week"
                    TaskTimeScope.month -> "auto_carry_over_description_month"
                    else -> "auto_carry_over_description_year"
                }
                LabelRow("auto_carry_over".localized, key.localized) { ModernToggle(viewModel.autoCarryOver) { viewModel.autoCarryOver = it } }
            }
        }
    }

    LabelRow("duration".localized, "add_duration".localized) { ModernToggle(viewModel.hasDuration) { viewModel.hasDuration = it } }
    AnimatedVisibility(viewModel.hasDuration, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(300)) + shrinkVertically(tween(300))) {
        val presenter = LocalPresenter.current
        LabelRow("duration_value".localized) {
            T(
                formatHoursMinutes(viewModel.duration),
                Fonts.subheadline,
                theme.secondaryTextColor,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(theme.surfaceColor)
                    .tap { presenter.sheet { DurationPickerView(viewModel.duration) { viewModel.duration = it } } }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }
    }
}

/** Asks for the notifications permission where Android requires it. */
@Composable
fun rememberNotificationPermission(): () -> Unit {
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) {}
    return {
        if (android.os.Build.VERSION.SDK_INT >= 33 && !TaskNotificationManager.isAuthorized) {
            launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

// MARK: - Recurrence settings

@Composable
private fun RecurrencePage(content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("recurrence_settings".localized, trailing = { BarButton("done".localized, color = theme.primaryColor, onClick = dismiss) })
        Column(Modifier.weight(1f), content = content)
    }
}

@Composable
private fun RecurrenceCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    Column(
        modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(theme.surfaceColor)
            .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
            .padding(vertical = 16.dp),
        content = content,
    )
}

@Composable
private fun PillBar(fill: Float, stroke: Float, corner: Int = 10, content: @Composable RowScope.() -> Unit) {
    val theme = theme
    Row(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(corner.dp))
            .background(theme.primaryColor.copy(alpha = fill))
            .border(1.dp, theme.primaryColor.copy(alpha = stroke), RoundedCornerShape(corner.dp))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        content = content,
    )
}

@Composable
private fun RowScope.Pill(title: String, selected: Boolean, size: Int = 12, onClick: () -> Unit) {
    val theme = theme
    Box(
        Modifier
            .weight(1f)
            .fillMaxHeight()
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) theme.primaryColor else Color.Transparent)
            .tap(onClick = onClick)
            .padding(horizontal = 6.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        T(title, systemFont(size, FontWeight.Medium), if (selected) theme.backgroundColor else theme.primaryColor, TextAlign.Center)
    }
}

@Composable
private fun StepperRow(title: String, valueText: String, onMinus: () -> Unit, onPlus: () -> Unit, minusEnabled: Boolean, plusEnabled: Boolean) {
    val theme = theme
    Row(Modifier.padding(horizontal = 16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        T(title, Fonts.body, modifier = Modifier.weight(1f))
        T(valueText, Fonts.body, theme.primaryColor)
        IOSStepper(onMinus, onPlus, minusEnabled, plusEnabled)
    }
}

@Composable
fun EnhancedRecurrenceSettingsView(viewModel: TaskFormViewModel) {
    val theme = theme
    val presenter = LocalPresenter.current
    RecurrencePage {
        Column(Modifier.padding(top = 16.dp, bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("recurrence_type".localized, Fonts.headline, modifier = Modifier.padding(horizontal = 16.dp))
            PillBar(0.1f, 0.2f) {
                FormRecurrenceType.entries.forEach { type ->
                    Pill(type.localizedString, viewModel.recurrenceType == type) { viewModel.recurrenceType = type }
                }
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).imePadding(), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            when (viewModel.recurrenceType) {
                FormRecurrenceType.daily -> RecurrenceCard {
                    T("daily_recurrence".localized, Fonts.headline, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
                    val unit = if (viewModel.dayInterval == 1) "day_unit".localized else "days_unit".localized
                    StepperRow("repeat_every".localized, "${viewModel.dayInterval} $unit", { viewModel.dayInterval-- }, { viewModel.dayInterval++ }, viewModel.dayInterval > 1, viewModel.dayInterval < 60)
                    Spacer(Modifier.height(12.dp))
                    T("anchored_to_task_start_date".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
                    Spacer(Modifier.height(12.dp))
                    T(
                        if (viewModel.dayInterval == 1) "repeats_every_day".localized else "repeats_every_n_days".localized(viewModel.dayInterval),
                        Fonts.caption, theme.primaryColor, modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
                FormRecurrenceType.weekly -> RecurrenceCard {
                    T("weekly_recurrence".localized, Fonts.headline, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        listOf(2 to "monday", 3 to "tuesday", 4 to "wednesday", 5 to "thursday", 6 to "friday", 7 to "saturday", 1 to "sunday").forEach { (weekday, key) ->
                            Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                T(key.localized, Fonts.subheadline, modifier = Modifier.weight(1f))
                                val selected = weekday in viewModel.selectedDays
                                if (selected) {
                                    CompactTime(viewModel.weeklyTimes[weekday] ?: viewModel.startDate, { viewModel.weeklyTimes = viewModel.weeklyTimes + (weekday to it) })
                                }
                                IOSToggle(selected, { on ->
                                    viewModel.selectedDays = if (on) viewModel.selectedDays + weekday else viewModel.selectedDays - weekday
                                }, theme.primaryColor)
                            }
                        }
                    }
                }
                FormRecurrenceType.monthly -> RecurrenceCard {
                    T("monthly_recurrence".localized, Fonts.headline, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp))
                    PillBar(0.1f, 0.2f, 8) {
                        MonthlySelectionType.entries.forEach { type ->
                            Pill(type.localizedString, viewModel.monthlySelectionType == type, 14) { viewModel.monthlySelectionType = type }
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    if (viewModel.monthlySelectionType == MonthlySelectionType.days) MonthlyDaysView(viewModel) else MonthlyPatternsView(viewModel)
                }
                FormRecurrenceType.yearly -> RecurrenceCard {
                    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        T("yearly_recurrence".localized, Fonts.headline)
                        T("select_day_of_year".localized, Fonts.subheadline, theme.secondaryTextColor)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("repeat_on".localized, Fonts.subheadline, modifier = Modifier.weight(1f))
                            CompactDate(viewModel.yearlyDate, { viewModel.yearlyDate = it })
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("time".localized, Fonts.subheadline, modifier = Modifier.weight(1f))
                            CompactTime(viewModel.yearlyTime, { viewModel.yearlyTime = it })
                        }
                        T("task_repeat_yearly_on".localized + " " + viewModel.yearlyDate.skeleton("MMMMd"), Fonts.caption, theme.primaryColor)
                    }
                }
            }
            EndDateSection(viewModel)
            Spacer(Modifier.height(50.dp))
        }
    }
}

@Composable
internal fun MonthlyDaysView(viewModel: TaskFormViewModel) {
    val theme = theme
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        T("select_days_of_month".localized, Fonts.subheadline, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (1..31).chunked(7).forEach { row ->
                Row(Modifier.fillMaxWidth()) {
                    for (index in 0 until 7) {
                        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                            val day = row.getOrNull(index) ?: return@Box
                            val selected = day in viewModel.selectedMonthlyDays
                            Box(
                                Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(if (selected) theme.primaryColor else theme.surfaceColor)
                                    .then(if (selected) Modifier else Modifier.border(1.dp, theme.borderColor, CircleShape))
                                    .tap {
                                        if (selected) {
                                            viewModel.selectedMonthlyDays = viewModel.selectedMonthlyDays - day
                                            viewModel.monthlyTimes = viewModel.monthlyTimes - day
                                        } else {
                                            viewModel.selectedMonthlyDays = viewModel.selectedMonthlyDays + day
                                            if (day !in viewModel.monthlyTimes) viewModel.monthlyTimes = viewModel.monthlyTimes + (day to viewModel.startDate)
                                        }
                                    },
                                contentAlignment = Alignment.Center,
                            ) {
                                T("$day", systemFont(14, FontWeight.Medium), if (selected) theme.backgroundColor else theme.textColor)
                            }
                        }
                    }
                }
            }
        }
        if (viewModel.selectedMonthlyDays.isNotEmpty()) {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T("task_time".localized, Fonts.subheadline, theme.secondaryTextColor)
                viewModel.selectedMonthlyDays.sorted().forEach { day ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("${"day".localized} $day", Fonts.subheadline, modifier = Modifier.weight(1f))
                        CompactTime(viewModel.monthlyTimes[day] ?: viewModel.startDate, { viewModel.monthlyTimes = viewModel.monthlyTimes + (day to it) })
                    }
                }
            }
        }
    }
}

@Composable
internal fun MonthlyPatternsView(viewModel: TaskFormViewModel) {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        T("select_patterns_ordinal".localized, Fonts.subheadline, theme.secondaryTextColor)
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(theme.backgroundColor)
                .border(1.dp, theme.borderColor, RoundedCornerShape(8.dp))
                .tap { presenter.sheet { NavigationStack { OrdinalPatternPickerView(viewModel) } } }
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                T("monthly_patterns".localized, Fonts.subheadline)
                if (viewModel.selectedOrdinalPatterns.isEmpty()) T("none_selected".localized, Fonts.caption, theme.secondaryTextColor)
                else T(viewModel.selectedOrdinalPatterns.joinToString(", ") { it.displayText }, Fonts.caption, theme.primaryColor)
            }
            SF("chevron.right", theme.secondaryTextColor, 16.dp)
        }
        if (viewModel.selectedOrdinalPatterns.isNotEmpty()) {
            T("task_time".localized, Fonts.subheadline, theme.secondaryTextColor)
            viewModel.selectedOrdinalPatterns.sortedBy { it.displayText }.forEach { pattern ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(pattern.displayText, Fonts.subheadline, modifier = Modifier.weight(1f))
                    CompactTime(viewModel.monthlyOrdinalTimes[pattern] ?: viewModel.startDate, { viewModel.monthlyOrdinalTimes = viewModel.monthlyOrdinalTimes + (pattern to it) })
                }
            }
        }
    }
}

@Composable
internal fun OrdinalPatternPickerView(viewModel: TaskFormViewModel) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val ordinals = listOf(1 to "first", 2 to "second", 3 to "third", 4 to "fourth", -1 to "last")
    val weekdays = listOf(1 to "sunday", 2 to "monday", 3 to "tuesday", 4 to "wednesday", 5 to "thursday", 6 to "friday", 7 to "saturday")
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "monthly_patterns".localized,
            leading = {
                BarButton("clear_all".localized, enabled = viewModel.selectedOrdinalPatterns.isNotEmpty(), color = Color.SysRed) {
                    viewModel.selectedOrdinalPatterns = emptySet()
                    viewModel.monthlyOrdinalTimes = emptyMap()
                }
            },
            trailing = { BarButton("done".localized, color = theme.primaryColor, onClick = dismiss) },
        )
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("select_patterns_description".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center, Modifier.fillMaxWidth().padding(16.dp, 8.dp))
            ordinals.forEach { (ordinal, title) ->
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(theme.backgroundColor)
                        .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                        .padding(vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    T(title.localized, Fonts.headline, modifier = Modifier.padding(horizontal = 16.dp))
                    weekdays.chunked(2).forEach { row ->
                        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { (weekday, key) ->
                                val pattern = OrdinalPattern(ordinal, weekday)
                                val selected = pattern in viewModel.selectedOrdinalPatterns
                                Row(
                                    Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(if (selected) theme.primaryColor.copy(alpha = 0.1f) else theme.surfaceColor)
                                        .border(if (selected) 2.dp else 1.dp, if (selected) theme.primaryColor.copy(alpha = 0.3f) else theme.borderColor, RoundedCornerShape(8.dp))
                                        .tap {
                                            if (selected) {
                                                viewModel.selectedOrdinalPatterns = viewModel.selectedOrdinalPatterns - pattern
                                                viewModel.monthlyOrdinalTimes = viewModel.monthlyOrdinalTimes - pattern
                                            } else {
                                                viewModel.selectedOrdinalPatterns = viewModel.selectedOrdinalPatterns + pattern
                                                if (pattern !in viewModel.monthlyOrdinalTimes) viewModel.monthlyOrdinalTimes = viewModel.monthlyOrdinalTimes + (pattern to viewModel.startDate)
                                            }
                                        }
                                        .padding(horizontal = 12.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    SF(if (selected) "checkmark.circle.fill" else "circle", if (selected) theme.primaryColor else theme.secondaryTextColor, 18.dp)
                                    T(key.localized, Fonts.subheadline)
                                }
                            }
                            if (row.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EndDateSection(viewModel: TaskFormViewModel) {
    RecurrenceCard {
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("end_date".localized, Fonts.headline)
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("set_end_date".localized, Fonts.subheadline, modifier = Modifier.weight(1f))
                IOSToggle(viewModel.hasRecurrenceEndDate, { viewModel.hasRecurrenceEndDate = it }, theme.primaryColor)
            }
            if (viewModel.hasRecurrenceEndDate) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("end_date".localized, Fonts.subheadline, modifier = Modifier.weight(1f))
                    CompactDate(viewModel.recurrenceEndDate, { viewModel.recurrenceEndDate = it })
                }
            }
        }
    }
}

@Composable
fun ContextualRecurrenceSettingsView(viewModel: TaskFormViewModel) {
    val theme = theme
    val scope = viewModel.selectedTimeScope
    val description = when (scope) {
        TaskTimeScope.week -> "recurrence_desc_week"
        TaskTimeScope.month -> "recurrence_desc_month"
        TaskTimeScope.year -> "recurrence_desc_year"
        TaskTimeScope.longTerm, TaskTimeScope.inbox -> "long_term_goals_no_recurrence"
        else -> "choose_how_often_daily_task"
    }.localized
    RecurrencePage {
        Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SF(scope.icon, namedColor(scope.colorName), 18.dp)
                T("recurrence_for".localized + " " + scope.displayName, Fonts.headline)
            }
            T(description, Fonts.subheadline, theme.secondaryTextColor)
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            RecurrenceCard {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("repeats".localized, Fonts.headline)
                    T(viewModel.contextualRecurrenceSummary, Fonts.subheadline, theme.primaryColor)
                }
            }
            when (scope) {
                TaskTimeScope.week -> WeekRecurrenceSettingsCard(viewModel)
                TaskTimeScope.month -> MonthRecurrenceSettingsCard(viewModel)
                TaskTimeScope.year -> YearRecurrenceSettingsCard(viewModel)
                TaskTimeScope.longTerm, TaskTimeScope.inbox -> RecurrenceCard {
                    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("long_term_goals".localized, Fonts.headline)
                        T("long_term_tasks_no_recurrence".localized, Fonts.subheadline, theme.secondaryTextColor)
                    }
                }
                else -> Unit
            }
            if (scope != TaskTimeScope.longTerm && scope != TaskTimeScope.inbox) EndDateSection(viewModel)
            Spacer(Modifier.height(50.dp))
        }
    }
}

@Composable
private fun WeekRecurrenceSettingsCard(viewModel: TaskFormViewModel) {
    val theme = theme
    RecurrenceCard {
        T("weekly_recurrence".localized, Fonts.headline, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp))
        PillBar(0.08f, 0.18f) {
            Pill("every_n_weeks".localized, viewModel.weekRecurrenceMode == WeekRecurrenceMode.everyNWeeks) { viewModel.weekRecurrenceMode = WeekRecurrenceMode.everyNWeeks }
            Pill("weeks_of_month".localized, viewModel.weekRecurrenceMode == WeekRecurrenceMode.specificWeeksOfMonth) { viewModel.weekRecurrenceMode = WeekRecurrenceMode.specificWeeksOfMonth }
            Pill("pattern_modulo".localized, viewModel.weekRecurrenceMode == WeekRecurrenceMode.moduloPattern) { viewModel.weekRecurrenceMode = WeekRecurrenceMode.moduloPattern }
        }
        Spacer(Modifier.height(16.dp))
        when (viewModel.weekRecurrenceMode) {
            WeekRecurrenceMode.everyNWeeks -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                StepperRow(
                    "repeat_every".localized,
                    "${viewModel.weekInterval} ${if (viewModel.weekInterval == 1) "week_unit".localized else "weeks_unit".localized}",
                    { viewModel.weekInterval-- }, { viewModel.weekInterval++ }, viewModel.weekInterval > 1, viewModel.weekInterval < 12,
                )
                T("anchored_start_week".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
            }
            WeekRecurrenceMode.specificWeeksOfMonth -> Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("select_weeks_of_month".localized, Fonts.subheadline, theme.secondaryTextColor)
                listOf(1, 2, 3, 4, 5, -1).chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { value ->
                            SelectableTile(if (value == -1) "last_ordinal".localized else ordinalText(value), value in viewModel.weekSelectedOrdinals, Modifier.weight(1f)) {
                                viewModel.weekSelectedOrdinals = if (value in viewModel.weekSelectedOrdinals) viewModel.weekSelectedOrdinals - value else viewModel.weekSelectedOrdinals + value
                            }
                        }
                    }
                }
            }
            WeekRecurrenceMode.moduloPattern -> ModuloRows(
                "every_kth_week".localized, viewModel.weekModuloK, 12, viewModel.weekModuloOffset,
                { k ->
                    viewModel.weekModuloK = k
                    if (viewModel.weekModuloOffset >= k) viewModel.weekModuloOffset = maxOf(0, k - 1)
                },
                { viewModel.weekModuloOffset = it },
                if (viewModel.weekModuloK == 2) (if (viewModel.weekModuloOffset == 0) "even_weeks".localized else "odd_weeks".localized) else "modulo_weeks_formula_desc".localized,
            )
        }
    }
}

@Composable
private fun ModuloRows(title: String, k: Int, maxK: Int, offset: Int, setK: (Int) -> Unit, setOffset: (Int) -> Unit, note: String) {
    val theme = theme
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        StepperRow(title, "k = $k", { setK(k - 1) }, { setK(k + 1) }, k > 2, k < maxK)
        StepperRow("offset".localized, "${offset + 1}", { setOffset(offset - 1) }, { setOffset(offset + 1) }, offset > 0, offset < k - 1)
        T(note, Fonts.caption, if (k == 2) theme.primaryColor else theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
    }
}

@Composable
private fun SelectableTile(title: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val theme = theme
    Box(
        modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) theme.primaryColor else theme.backgroundColor)
            .border(if (selected) 2.dp else 1.dp, if (selected) theme.primaryColor.copy(alpha = 0.3f) else theme.borderColor, RoundedCornerShape(8.dp))
            .tap(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        T(title, Fonts.subheadline, if (selected) theme.backgroundColor else theme.textColor)
    }
}

@Composable
private fun MonthRecurrenceSettingsCard(viewModel: TaskFormViewModel) {
    val theme = theme
    RecurrenceCard {
        T("monthly_recurrence".localized, Fonts.headline, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp))
        PillBar(0.08f, 0.18f) {
            Pill("every_n_months".localized, viewModel.monthRecurrenceMode == MonthRecurrenceMode.everyNMonths) { viewModel.monthRecurrenceMode = MonthRecurrenceMode.everyNMonths }
            Pill("specific_months".localized, viewModel.monthRecurrenceMode == MonthRecurrenceMode.specificMonths) { viewModel.monthRecurrenceMode = MonthRecurrenceMode.specificMonths }
        }
        Spacer(Modifier.height(16.dp))
        when (viewModel.monthRecurrenceMode) {
            MonthRecurrenceMode.everyNMonths -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                StepperRow(
                    "repeat_every".localized,
                    "${viewModel.monthInterval} ${if (viewModel.monthInterval == 1) "month_unit".localized else "months_unit".localized}",
                    { viewModel.monthInterval-- }, { viewModel.monthInterval++ }, viewModel.monthInterval > 1, viewModel.monthInterval < 12,
                )
                T("anchored_start_month".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
            }
            MonthRecurrenceMode.specificMonths -> Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T("select_months".localized, Fonts.subheadline, theme.secondaryTextColor)
                (1..12).chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { month ->
                            SelectableTile(monthSymbol(month), month in viewModel.monthSelectedMonths, Modifier.weight(1f)) {
                                viewModel.monthSelectedMonths = if (month in viewModel.monthSelectedMonths) viewModel.monthSelectedMonths - month else viewModel.monthSelectedMonths + month
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun YearRecurrenceSettingsCard(viewModel: TaskFormViewModel) {
    val theme = theme
    RecurrenceCard {
        T("yearly_recurrence".localized, Fonts.headline, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 16.dp))
        PillBar(0.08f, 0.18f) {
            Pill("every_n_years".localized, viewModel.yearRecurrenceMode == YearRecurrenceMode.everyNYears) { viewModel.yearRecurrenceMode = YearRecurrenceMode.everyNYears }
            Pill("pattern_modulo".localized, viewModel.yearRecurrenceMode == YearRecurrenceMode.moduloPattern) { viewModel.yearRecurrenceMode = YearRecurrenceMode.moduloPattern }
        }
        Spacer(Modifier.height(16.dp))
        when (viewModel.yearRecurrenceMode) {
            YearRecurrenceMode.everyNYears -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                StepperRow(
                    "repeat_every".localized,
                    "${viewModel.yearInterval} ${if (viewModel.yearInterval == 1) "year_unit".localized else "years_unit".localized}",
                    { viewModel.yearInterval-- }, { viewModel.yearInterval++ }, viewModel.yearInterval > 1, viewModel.yearInterval < 10,
                )
                T("anchored_start_year".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 16.dp))
            }
            YearRecurrenceMode.moduloPattern -> ModuloRows(
                "every_k_years".localized, viewModel.yearModuloK, 10, viewModel.yearModuloOffset,
                { k ->
                    viewModel.yearModuloK = k
                    if (viewModel.yearModuloOffset >= k) viewModel.yearModuloOffset = maxOf(0, k - 1)
                },
                { viewModel.yearModuloOffset = it },
                if (viewModel.yearModuloK == 2) (if (viewModel.yearModuloOffset == 0) "even_years".localized else "odd_years".localized) else "modulo_years_formula_desc".localized,
            )
        }
    }
}

// MARK: - Pickers

@Composable
fun CategoryIconTile(icon: String, color: Color, size: androidx.compose.ui.unit.Dp) {
    Box(
        Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.28f))
            .background(color.copy(alpha = 0.16f)),
        contentAlignment = Alignment.Center,
    ) {
        SF(icon, color, size * 0.55f)
    }
}

val Category.displayIcon: String get() = icon ?: "folder.fill"

@Composable
fun CategoryPickerView(selected: Category?, onSelect: (Category?) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val canAddMore = SubscriptionManager.hasAccess(PremiumFeature.unlimitedCategories) || CategoryManager.categories.size < SubscriptionManager.maxCategoriesForFree
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("select_category".localized, trailing = {
            BarButton("edit".localized, color = theme.primaryColor) { presenter.sheet { NavigationStack { CategoryEditorView() } } }
        })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CategoryManager.categories.forEach { category ->
                key(category.id) {
                    val isSelected = selected?.id == category.id
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isSelected) theme.primaryColor.copy(alpha = 0.1f) else theme.surfaceColor)
                            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) theme.primaryColor else theme.borderColor, RoundedCornerShape(12.dp))
                            .tap {
                                onSelect(if (isSelected) null else category)
                                dismiss()
                            }
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CategoryIconTile(category.displayIcon, colorFromHex(category.color), 32.dp)
                        T(category.name, Fonts.body.medium, modifier = Modifier.weight(1f))
                        if (isSelected) SF("checkmark", theme.primaryColor, 20.dp)
                    }
                }
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(theme.surfaceColor)
                    .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                    .tap {
                        if (canAddMore) {
                            presenter.sheet {
                                NavigationStack {
                                    CategoryFormView { new ->
                                        SettingsViewModel.addCategory(new)
                                        onSelect(new)
                                    }
                                }
                            }
                        } else presenter.sheet { PremiumPaywallView() }
                    }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                val color = if (canAddMore) theme.primaryColor else theme.secondaryTextColor
                SF("plus", color, 20.dp)
                T("add_new_category".localized, Fonts.body, color, modifier = Modifier.weight(1f))
                if (!canAddMore) PremiumBadge(small = true)
            }
        }
    }
}

@Composable
fun IconPickerView(selected: String, onSelect: (String) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("choose_icon".localized)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            TaskIconCatalog.groups.forEach { group ->
                T(group.titleKey.localized, Fonts.headline, modifier = Modifier.padding(horizontal = 16.dp))
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    group.icons.chunked(4).forEach { row ->
                        Row(Modifier.fillMaxWidth()) {
                            for (index in 0 until 4) {
                                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                                    val icon = row.getOrNull(index) ?: return@Box
                                    val isSelected = icon == selected
                                    Box(
                                        Modifier
                                            .size(60.dp)
                                            .clip(RoundedCornerShape(12.dp))
                                            .background(if (isSelected) theme.primaryColor.copy(alpha = 0.1f) else theme.surfaceColor)
                                            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) theme.primaryColor else theme.borderColor, RoundedCornerShape(12.dp))
                                            .tap {
                                                onSelect(icon)
                                                dismiss()
                                            },
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        SF(icon, theme.textColor, 26.dp)
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
fun DurationPickerView(duration: Double, onSave: (Double) -> Unit) {
    val dismiss = LocalDismiss.current
    val theme = theme
    var hours by remember { mutableStateOf((duration / 60).toInt() / 60) }
    var minutes by remember { mutableStateOf((duration / 60).toInt() % 60) }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "actual_duration".localized,
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, bold = true) {
                    onSave(hours * 3600.0 + minutes * 60.0)
                    dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(30.dp)) {
            T("how_long_did_it_take".localized, Fonts.title2.bold, align = TextAlign.Center)
            HourMinuteWheels(hours, minutes, { hours = it }, { minutes = it })
            Row(
                Modifier
                    .padding(top = 10.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.SysRed.copy(alpha = 0.1f))
                    .border(1.dp, Color.SysRed.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
                    .pressable {
                        onSave(0.0)
                        dismiss()
                    }
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                SF("trash", Color.SysRed, 18.dp)
                T("clear_duration".localized, Fonts.subheadline.medium, Color.SysRed)
            }
        }
    }
}

@Composable
fun HourMinuteWheels(hours: Int, minutes: Int, setHours: (Int) -> Unit, setMinutes: (Int) -> Unit) {
    Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            T("hours".localized.replaceFirstChar { it.titlecase(appLocale) }, Fonts.subheadline, Color.Secondary)
            WheelPicker((0..23).toList(), hours, setHours, { "$it" }, Modifier.width(90.dp), rowHeight = 40.dp, visibleRows = 3)
        }
        T(":", Fonts.title.bold, Color.Secondary, modifier = Modifier.padding(top = 20.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            T("minutes".localized.replaceFirstChar { it.titlecase(appLocale) }, Fonts.subheadline, Color.Secondary)
            WheelPicker((0..59).toList(), minutes, setMinutes, { it.toString().padStart(2, '0') }, Modifier.width(90.dp), rowHeight = 40.dp, visibleRows = 3)
        }
    }
}

@Composable
internal fun NotificationLeadTimePickerView(leadMinutes: Int, onSave: (Int) -> Unit) {
    val dismiss = LocalDismiss.current
    val theme = theme
    var isAfter by remember { mutableStateOf(leadMinutes < 0) }
    var hours by remember { mutableStateOf(abs(leadMinutes) / 60) }
    var minutes by remember { mutableStateOf(abs(leadMinutes) % 60) }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "custom_notification_title".localized,
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, bold = true) {
                    val total = hours * 60 + minutes
                    onSave(if (total == 0) 0 else if (isAfter) -total else total)
                    dismiss()
                }
            },
        )
        Column(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            T("custom_notification_title".localized, Fonts.title2.bold, align = TextAlign.Center)
            SegmentedControl(listOf(false, true), isAfter, { isAfter = it }, { if (it) "custom_notify_after".localized else "custom_notify_before".localized }, Modifier.padding(horizontal = 16.dp))
            HourMinuteWheels(hours, minutes, { hours = it }, { minutes = it })
            Row(
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.SysBlue.copy(alpha = 0.08f))
                    .pressable {
                        hours = 0
                        minutes = 0
                    }
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                SF("bell", Color.SysBlue, 18.dp)
                T("at_exact_time".localized, Fonts.subheadline.medium, Color.SysBlue)
            }
        }
    }
}

// MARK: - Task creation

@Composable
fun TaskCreationOptionsView(initialDate: Date? = null, hasSpecificTime: Boolean = false) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val vm = TimelineViewModel
    var taskName by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    val requester = remember { FocusRequester() }
    val preserve = hasSpecificTime || initialDate != null

    val base = initialDate ?: when (vm.selectedTimeScope) {
        TaskTimeScope.today -> vm.selectedDate
        TaskTimeScope.week -> vm.currentWeek
        TaskTimeScope.month -> vm.currentMonth
        TaskTimeScope.year -> vm.currentYear
        else -> now()
    }
    LaunchedEffect(Unit) {
        delay(500)
        runCatching { requester.requestFocus() }
    }

    val templates = remember(TaskManager.tasks, taskName) {
        val byName = HashMap<String, TodoTask>()
        for (task in TaskManager.tasks) {
            val existing = byName[task.name]
            if (existing == null || task.lastModifiedDate > existing.lastModifiedDate) byName[task.name] = task
        }
        byName.values
            .filter { taskName.isEmpty() || it.name.contains(taskName, ignoreCase = true) }
            .sortedByDescending { it.lastModifiedDate }
    }

    fun scopeDates(): Pair<Date?, Date?> = when (vm.selectedTimeScope) {
        TaskTimeScope.week -> base.startOfWeek().let { it to it.addingDays(6) }
        TaskTimeScope.month -> base.startOfMonth().let { it to it.endOfMonth() }
        TaskTimeScope.year -> base.startOfYear().let { it to it.endOfYear() }
        else -> null to null
    }

    fun createQuickTask() {
        if (taskName.isEmpty()) return
        val (start, end) = scopeDates()
        val task = TodoTask(
            name = taskName, startTime = base, hasSpecificDay = true, hasSpecificTime = preserve,
            timeScope = vm.selectedTimeScope, scopeStartDate = start, scopeEndDate = end,
        )
        MainScope.launch { TaskManager.addTask(task) }
        dismiss()
    }

    fun openFullForm() {
        val (start, _) = scopeDates()
        val scope = vm.selectedTimeScope
        presenter.sheet {
            TaskFormView(
                initialDate = base, initialTimeScope = scope, initialName = taskName, scopeStartDate = start, preserveTime = preserve,
                onSave = { task ->
                    MainScope.launch { TaskManager.addTask(task) }
                    dismiss()
                },
            )
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("${"add".localized} ${"task".localized}", leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) })
        Column(Modifier.padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                T("how_create_task".localized, Fonts.title3.bold, modifier = Modifier.weight(1f))
                if (preserve) {
                    Row(
                        Modifier
                            .clip(CircleShape)
                            .background(theme.primaryColor.copy(alpha = 0.12f))
                            .padding(horizontal = 9.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                    ) {
                        SF("clock.fill", theme.primaryColor, 13.dp)
                        T(base.timeText(), systemFont(12, FontWeight.Bold), theme.primaryColor, maxLines = 1)
                    }
                }
            }
            Row(
                Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(theme.surfaceColor)
                    .border(if (focused) 2.dp else 1.dp, if (focused) theme.primaryColor else theme.borderColor, RoundedCornerShape(14.dp))
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SF("plus.circle.fill", if (taskName.isNotEmpty()) theme.primaryColor else theme.secondaryTextColor, 26.dp)
                BasicTextField(
                    taskName, { taskName = it },
                    singleLine = true,
                    textStyle = Fonts.body.copy(color = theme.textColor),
                    cursorBrush = SolidColor(theme.primaryColor),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { createQuickTask() }),
                    modifier = Modifier.weight(1f).focusRequester(requester).onFocusChanged { focused = it.isFocused },
                    decorationBox = { inner ->
                        Box {
                            if (taskName.isEmpty()) T("enter_task_name".localized, Fonts.body, Color.Tertiary)
                            inner()
                        }
                    },
                )
                if (taskName.isNotEmpty()) {
                    Box(Modifier.tap { taskName = "" }) { SF("xmark.circle.fill", theme.secondaryTextColor, 20.dp) }
                }
            }
            AnimatedVisibility(taskName.isNotEmpty() && focused, enter = fadeIn(tween(250)) + expandVertically(tween(250)), exit = fadeOut(tween(200)) + shrinkVertically(tween(200))) {
                Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(theme.primaryColor)
                            .pressable { createQuickTask() }
                            .padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SF("checkmark.circle.fill", Color.White, 18.dp)
                        T("create".localized, Fonts.subheadline.semibold, Color.White)
                    }
                    Row(
                        Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(theme.primaryColor.copy(alpha = 0.15f))
                            .pressable { openFullForm() }
                            .padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SF("slider.horizontal.3", theme.primaryColor, 18.dp)
                        T("customize".localized, Fonts.subheadline.semibold, theme.primaryColor)
                    }
                }
            }
        }
        Box(Modifier.padding(horizontal = 16.dp).fillMaxWidth().height(0.5.dp).background(theme.divider))
        if (templates.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
            ) {
                SF("tray.fill", theme.secondaryTextColor, 40.dp)
                T("no_past_tasks".localized, Fonts.subheadline, theme.secondaryTextColor)
            }
        } else {
            T(
                if (taskName.isNotEmpty()) "matching_templates".localized else "choose_from_previous_tasks".localized,
                Fonts.headline,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 12.dp),
            )
            androidx.compose.foundation.lazy.LazyColumn(
                Modifier.fillMaxSize().imePadding(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 20.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(templates.size, key = { templates[it].id }) { index ->
                    val template = templates[index]
                    TaskTemplateCard(template) {
                        val anchored = anchoredTask(template, vm.selectedTimeScope, base, preserve)
                        presenter.sheet {
                            TaskFormView(initialTask = anchored, preserveTime = preserve || anchored.hasSpecificTime, onSave = { task ->
                                MainScope.launch { TaskManager.addTask(task) }
                                dismiss()
                            })
                        }
                    }
                }
            }
        }
    }
}

private fun anchoredTask(template: TodoTask, scope: TaskTimeScope, base: Date, preserve: Boolean): TodoTask {
    val hour = template.startTime.hour
    val minute = template.startTime.minute
    var scopeStart: Date? = null
    var scopeEnd: Date? = null
    val start = when (scope) {
        TaskTimeScope.today -> when {
            preserve -> base
            template.hasSpecificTime -> base.withTime(hour, minute)
            else -> base.startOfDay()
        }
        TaskTimeScope.week -> base.startOfWeek().let {
            scopeStart = it
            scopeEnd = it.addingDays(6)
            if (template.hasSpecificTime) it.withTime(hour, minute) else it
        }
        TaskTimeScope.month -> base.startOfMonth().let {
            scopeStart = it
            scopeEnd = it.endOfMonth()
            if (template.hasSpecificTime) it.withTime(hour, minute) else it
        }
        TaskTimeScope.year -> base.startOfYear().let {
            scopeStart = it
            scopeEnd = it.endOfYear()
            if (template.hasSpecificTime) it.withTime(hour, minute) else it
        }
        TaskTimeScope.inbox -> now()
        else -> if (template.hasSpecificTime) now().withTime(hour, minute) else now().startOfDay()
    }
    return template.copy(
        id = java.util.UUID.randomUUID(),
        startTime = start,
        hasSpecificDay = if (scope == TaskTimeScope.today) true else template.hasSpecificDay,
        hasSpecificTime = preserve || template.hasSpecificTime,
        notificationId = null,
        timeScope = scope,
        scopeStartDate = scopeStart,
        scopeEndDate = scopeEnd,
        photoPath = null,
        photoThumbnailPath = null,
        photos = emptyList(),
        voiceMemos = emptyList(),
        completions = emptyMap(),
        completionDates = emptyList(),
        creationDate = now(),
        lastModifiedDate = now(),
        totalTrackedTime = 0.0,
        lastTrackedDate = null,
    )
}

@Composable
private fun TaskTemplateCard(task: TodoTask, onSelect: () -> Unit) {
    val theme = theme
    val categoryColor = task.category?.let { colorFromHex(it.color) } ?: theme.secondaryTextColor
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(theme.surfaceColor)
            .then(if (task.category != null) Modifier.background(Brush.linearGradient(listOf(categoryColor.copy(alpha = 0.12f), categoryColor.copy(alpha = 0.06f), categoryColor.copy(alpha = 0.02f), Color.Transparent))) else Modifier)
            .then(
                if (task.category != null) Modifier.border(1.5.dp, Brush.linearGradient(listOf(categoryColor.copy(alpha = 0.3f), categoryColor.copy(alpha = 0.1f))), shape)
                else Modifier.border(1.dp, theme.borderColor, shape)
            )
            .pressable(onClick = onSelect)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(categoryColor.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            SF(displayIcon(task), categoryColor, 22.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(task.name, Fonts.headline)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                task.category?.let { category ->
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(8.dp).background(colorFromHex(category.color), CircleShape))
                        T(category.name, Fonts.caption, theme.secondaryTextColor)
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                    SF(task.priority.icon, colorFromHex(task.priority.colorHex), 12.dp)
                    T(task.priority.displayName, Fonts.caption, theme.secondaryTextColor)
                }
            }
        }
        SF("chevron.right", theme.secondaryTextColor, 16.dp)
    }
}
