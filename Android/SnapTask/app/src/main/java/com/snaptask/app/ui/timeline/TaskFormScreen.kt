package com.snaptask.app.ui.timeline

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import com.snaptask.app.R
import com.snaptask.app.data.model.*
import com.snaptask.app.ui.components.LocationPickerScreen
import com.snaptask.app.ui.components.parseHexColor
import java.text.SimpleDateFormat
import java.util.*

/**
 * Faithful port of iOS TaskFormView.swift.
 * Uses ModernCard sections matching the iOS layout exactly.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskFormScreen(
    initialTask: TodoTask? = null,
    categories: List<Category> = emptyList(),
    selectedDate: Date = Date(),
    initialTimeScope: TaskTimeScope = TaskTimeScope.TODAY,
    onSave: (TodoTask) -> Unit,
    onDismiss: () -> Unit,
) {
    val isEditing = initialTask != null
    // --- Form State ---
    var name by remember { mutableStateOf(initialTask?.name ?: "") }
    var description by remember { mutableStateOf(initialTask?.description ?: "") }
    var priority by remember { mutableStateOf(initialTask?.priority ?: Priority.MEDIUM) }
    var selectedCategory by remember { mutableStateOf(initialTask?.category) }
    var selectedTimeScope by remember { mutableStateOf(initialTask?.timeScope ?: initialTimeScope) }
    var hasSpecificTime by remember { mutableStateOf(initialTask?.hasSpecificTime ?: false) }
    var hasSpecificDay by remember { mutableStateOf(initialTask?.hasSpecificDay ?: false) }
    var hasDuration by remember { mutableStateOf(initialTask?.hasDuration ?: false) }
    var durationSeconds by remember { mutableStateOf(initialTask?.duration ?: 1800.0) }
    var hasNotification by remember { mutableStateOf(initialTask?.hasNotification ?: false) }
    var notificationLeadTimeMinutes by remember { mutableIntStateOf(initialTask?.notificationLeadTimeMinutes ?: 0) }
    var autoCarryOver by remember { mutableStateOf(initialTask?.autoCarryOver ?: false) }
    var iconName by remember { mutableStateOf(initialTask?.icon ?: "circle") }
    // Location
    var location by remember { mutableStateOf(initialTask?.location) }
    var showLocationPicker by remember { mutableStateOf(false) }
    // Icon & Category pickers
    var showIconPicker by remember { mutableStateOf(false) }
    var showCategoryPicker by remember { mutableStateOf(false) }
    // Recurrence
    var isRecurring by remember { mutableStateOf(initialTask?.recurrence != null) }
    var recurrenceType by remember { mutableStateOf("daily") }
    var trackInStatistics by remember { mutableStateOf(initialTask?.recurrence?.trackInStatistics ?: true) }
    // Advanced recurrence state
    var selectedWeekdays by remember { mutableStateOf(setOf(Calendar.MONDAY, Calendar.WEDNESDAY, Calendar.FRIDAY)) }
    var monthlySelectionType by remember { mutableStateOf("days") } // "days" or "ordinal"
    var selectedMonthlyDays by remember { mutableStateOf(setOf(1)) }
    var selectedOrdinalPatterns by remember { mutableStateOf(setOf<OrdinalPattern>()) }
    var hasRecurrenceEndDate by remember { mutableStateOf(false) }
    var recurrenceEndDate by remember { mutableStateOf(Date().time + 86400000 * 30) } // 30 days from now
    // Subtasks
    var subtasks by remember { mutableStateOf(initialTask?.subtasks ?: emptyList()) }
    var newSubtaskName by remember { mutableStateOf("") }
    // Reward
    var hasRewardPoints by remember { mutableStateOf(initialTask?.hasRewardPoints ?: false) }
    var rewardPoints by remember { mutableIntStateOf(initialTask?.rewardPoints.takeIf { it != null && it > 0 } ?: 10) }
    var useCustomPoints by remember { mutableStateOf(false) }
    var customPointsText by remember { mutableStateOf((initialTask?.rewardPoints ?: 10).toString()) }
    // Time
    val cal = remember { Calendar.getInstance().apply { time = initialTask?.startTime ?: selectedDate } }
    var selectedHour by remember { mutableIntStateOf(cal.get(Calendar.HOUR_OF_DAY)) }
    var selectedMinute by remember { mutableIntStateOf(cal.get(Calendar.MINUTE)) }
    var startDateMillis by remember { mutableLongStateOf(cal.timeInMillis) }
    // Week/Month/Year scope state
    var selectedYear by remember { mutableIntStateOf(cal.get(Calendar.YEAR)) }
    var selectedMonth by remember { mutableIntStateOf(cal.get(Calendar.MONTH) + 1) }
    // Duration picker
    var showDurationPicker by remember { mutableStateOf(false) }
    // Lead time picker
    var showLeadTimePicker by remember { mutableStateOf(false) }
    // Date picker
    var showDatePicker by remember { mutableStateOf(false) }
    var showRecurrenceEndDatePicker by remember { mutableStateOf(false) }

    val isValid = name.isNotBlank()
    val surfaceColor = MaterialTheme.colorScheme.surface
    val cardColor = MaterialTheme.colorScheme.surfaceContainerLow

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(if (isEditing) R.string.task_edit else R.string.task_form_new_task), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.action_cancel), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            if (isValid) {
                                val taskCal = Calendar.getInstance().apply {
                                    timeInMillis = startDateMillis
                                    if (hasSpecificTime) {
                                        set(Calendar.HOUR_OF_DAY, selectedHour)
                                        set(Calendar.MINUTE, selectedMinute)
                                    }
                                }
                                val scopeStart = when (selectedTimeScope) {
                                    TaskTimeScope.WEEK -> Recurrence.startOfWeek(Date(startDateMillis))
                                    TaskTimeScope.MONTH -> {
                                        Calendar.getInstance().apply {
                                            set(Calendar.YEAR, selectedYear)
                                            set(Calendar.MONTH, selectedMonth - 1)
                                            set(Calendar.DAY_OF_MONTH, 1)
                                        }.time
                                    }
                                    TaskTimeScope.YEAR -> {
                                        Calendar.getInstance().apply {
                                            set(Calendar.YEAR, selectedYear)
                                            set(Calendar.MONTH, 0); set(Calendar.DAY_OF_MONTH, 1)
                                        }.time
                                    }
                                    else -> null
                                }
                                val task = (initialTask ?: TodoTask(name = name)).copy(
                                    name = name,
                                    description = description.ifBlank { null },
                                    startTime = taskCal.time,
                                    hasSpecificTime = hasSpecificTime,
                                    hasSpecificDay = hasSpecificDay,
                                    duration = durationSeconds,
                                    hasDuration = hasDuration,
                                    category = selectedCategory,
                                    priority = priority,
                                    icon = iconName,
                                    subtasks = subtasks,
                                    hasNotification = hasNotification,
                                    notificationLeadTimeMinutes = notificationLeadTimeMinutes,
                                    autoCarryOver = autoCarryOver,
                                    timeScope = selectedTimeScope,
                                    scopeStartDate = scopeStart,
                                    hasRewardPoints = hasRewardPoints,
                                    rewardPoints = rewardPoints,
                                    lastModifiedDate = Date(),
                                )
                                onSave(task)
                            }
                        },
                        enabled = isValid,
                    ) {
                        Text(
                            stringResource(R.string.action_save),
                            fontWeight = FontWeight.SemiBold,
                            color = if (isValid) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // ============ TASK DETAILS CARD ============
            ModernFormCard(title = stringResource(R.string.task_form_task_details), icon = Icons.Default.Description) {
                // Name
                FormFieldLabel(stringResource(R.string.task_name))
                OutlinedTextField(
                    value = name, onValueChange = { name = it },
                    placeholder = { Text(stringResource(R.string.task_form_enter_name)) },
                    modifier = Modifier.fillMaxWidth(), singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                )
                Spacer(Modifier.height(8.dp))
                // Description
                FormFieldLabel(stringResource(R.string.task_description))
                OutlinedTextField(
                    value = description, onValueChange = { description = it },
                    placeholder = { Text(stringResource(R.string.task_form_add_description)) },
                    modifier = Modifier.fillMaxWidth(), minLines = 2, maxLines = 4,
                    shape = RoundedCornerShape(10.dp),
                )
            }

            // ============ TIME CARD ============
            ModernFormCard(title = stringResource(R.string.task_form_time), icon = Icons.Default.Schedule) {
                // Time Scope
                FormRow(label = stringResource(R.string.task_detail_time_range)) {
                    var scopeExpanded by remember { mutableStateOf(false) }
                    Box {
                        Row(
                            Modifier.clickable { scopeExpanded = true }
                                .background(cardColor, RoundedCornerShape(8.dp))
                                .padding(horizontal = 12.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text(selectedTimeScope.displayName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                            Icon(Icons.Default.ArrowDropDown, null, Modifier.size(16.dp))
                        }
                        DropdownMenu(expanded = scopeExpanded, onDismissRequest = { scopeExpanded = false }) {
                            TaskTimeScope.entries.filter { it != TaskTimeScope.ALL }.forEach { scope ->
                                DropdownMenuItem(
                                    text = { Text(scope.displayName) },
                                    onClick = { selectedTimeScope = scope; scopeExpanded = false },
                                )
                            }
                        }
                    }
                }

                if (selectedTimeScope == TaskTimeScope.TODAY) {
                    // Date picker button
                    FormRow(label = stringResource(R.string.task_detail_date)) {
                        TextButton(onClick = { showDatePicker = true }) {
                            val df = remember { SimpleDateFormat("MMM d, yyyy", Locale.getDefault()) }
                            Text(df.format(Date(startDateMillis)))
                        }
                    }
                    // Specific time toggle
                    FormToggleRow(
                        label = stringResource(R.string.task_form_specific_time), subtitle = stringResource(R.string.task_form_set_exact_time),
                        checked = hasSpecificTime,
                        onCheckedChange = {
                            hasSpecificTime = it
                            if (!it) hasNotification = false
                        },
                    )
                    AnimatedVisibility(visible = hasSpecificTime) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            FormRow(label = stringResource(R.string.task_detail_start_time)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    NumberPickerSimple(selectedHour, 0..23, { selectedHour = it }, { String.format("%02d", it) })
                                    Text(":", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 4.dp))
                                    NumberPickerSimple(selectedMinute, 0..59, { selectedMinute = it }, { String.format("%02d", it) }, step = 5)
                                }
                            }
                            // Notification
                            FormToggleRow(
                                label = stringResource(R.string.task_form_notification), subtitle = stringResource(R.string.task_form_get_notified),
                                checked = hasNotification,
                                onCheckedChange = { hasNotification = it },
                            )
                            AnimatedVisibility(visible = hasNotification) {
                                LeadTimeSelector(
                                    leadTimeMinutes = notificationLeadTimeMinutes,
                                    onLeadTimeChange = { notificationLeadTimeMinutes = it },
                                )
                            }
                        }
                    }
                    // Auto carry-over (non-recurring only)
                    if (!isRecurring) {
                        FormToggleRow(
                            label = stringResource(R.string.task_form_auto_carry_over),
                            subtitle = stringResource(R.string.task_form_move_incomplete),
                            checked = autoCarryOver,
                            onCheckedChange = { autoCarryOver = it },
                        )
                    }
                } else {
                    // Period info for week/month/year/longTerm
                    when (selectedTimeScope) {
                        TaskTimeScope.WEEK -> {
                            FormFieldLabel(stringResource(R.string.task_form_select_week))
                            TextButton(onClick = { showDatePicker = true }) {
                                val df = remember { SimpleDateFormat("MMM d, yyyy", Locale.getDefault()) }
                                Text(stringResource(R.string.task_form_week_of, df.format(Date(startDateMillis))))
                            }
                        }
                        TaskTimeScope.MONTH -> {
                            FormFieldLabel(stringResource(R.string.task_form_select_month))
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                val months = remember { java.text.DateFormatSymbols().months.take(12) }
                                var monthExpanded by remember { mutableStateOf(false) }
                                Box {
                                    TextButton(onClick = { monthExpanded = true }) { Text(months[selectedMonth - 1]) }
                                    DropdownMenu(expanded = monthExpanded, onDismissRequest = { monthExpanded = false }) {
                                        months.forEachIndexed { i, m ->
                                            DropdownMenuItem(text = { Text(m) }, onClick = { selectedMonth = i + 1; monthExpanded = false })
                                        }
                                    }
                                }
                                var yearExpanded by remember { mutableStateOf(false) }
                                Box {
                                    TextButton(onClick = { yearExpanded = true }) { Text("$selectedYear") }
                                    DropdownMenu(expanded = yearExpanded, onDismissRequest = { yearExpanded = false }) {
                                        (2024..2030).forEach { y ->
                                            DropdownMenuItem(text = { Text("$y") }, onClick = { selectedYear = y; yearExpanded = false })
                                        }
                                    }
                                }
                            }
                        }
                        TaskTimeScope.YEAR -> {
                            FormFieldLabel(stringResource(R.string.task_form_select_year))
                            var yearExpanded by remember { mutableStateOf(false) }
                            Box {
                                TextButton(onClick = { yearExpanded = true }) { Text("$selectedYear") }
                                DropdownMenu(expanded = yearExpanded, onDismissRequest = { yearExpanded = false }) {
                                    (2024..2030).forEach { y ->
                                        DropdownMenuItem(text = { Text("$y") }, onClick = { selectedYear = y; yearExpanded = false })
                                    }
                                }
                            }
                        }
                        TaskTimeScope.LONG_TERM -> {
                            Text(stringResource(R.string.task_form_long_term_no_date), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        else -> {}
                    }
                    // Specific day/time for non-today scopes
                    FormToggleRow(
                        label = stringResource(R.string.task_form_specific_day), subtitle = stringResource(R.string.task_form_set_specific_day),
                        checked = hasSpecificDay,
                        onCheckedChange = {
                            hasSpecificDay = it
                            if (!it) { hasSpecificTime = false; hasNotification = false }
                        },
                    )
                    AnimatedVisibility(visible = hasSpecificDay) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            FormRow(label = stringResource(R.string.task_detail_date)) {
                                TextButton(onClick = { showDatePicker = true }) {
                                    val df = remember { SimpleDateFormat("MMM d, yyyy", Locale.getDefault()) }
                                    Text(df.format(Date(startDateMillis)))
                                }
                            }
                            FormToggleRow(
                                label = stringResource(R.string.task_form_specific_time), subtitle = stringResource(R.string.task_form_set_exact_time),
                                checked = hasSpecificTime,
                                onCheckedChange = { hasSpecificTime = it; if (!it) hasNotification = false },
                            )
                            AnimatedVisibility(visible = hasSpecificTime) {
                                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    FormRow(label = stringResource(R.string.task_detail_start_time)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            NumberPickerSimple(selectedHour, 0..23, { selectedHour = it }, { String.format("%02d", it) })
                                            Text(":", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 4.dp))
                                            NumberPickerSimple(selectedMinute, 0..59, { selectedMinute = it }, { String.format("%02d", it) }, step = 5)
                                        }
                                    }
                                    FormToggleRow(label = stringResource(R.string.task_form_notification), subtitle = stringResource(R.string.task_form_get_notified_short), checked = hasNotification, onCheckedChange = { hasNotification = it })
                                    AnimatedVisibility(visible = hasNotification) {
                                        LeadTimeSelector(notificationLeadTimeMinutes, { notificationLeadTimeMinutes = it })
                                    }
                                }
                            }
                        }
                    }
                }

                // Duration
                FormToggleRow(label = stringResource(R.string.task_form_duration), subtitle = stringResource(R.string.task_form_add_estimated_duration), checked = hasDuration, onCheckedChange = { hasDuration = it })
                AnimatedVisibility(visible = hasDuration) {
                    FormRow(label = stringResource(R.string.task_form_duration)) {
                        val hours = (durationSeconds / 3600).toInt()
                        val minutes = ((durationSeconds % 3600) / 60).toInt()
                        TextButton(onClick = { showDurationPicker = true }) {
                            Text(if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m")
                        }
                    }
                }
            }

            // ============ CATEGORY & PRIORITY CARD ============
            ModernFormCard(title = stringResource(R.string.task_form_category_priority), icon = Icons.Default.Folder) {
                // Icon picker row
                FormRow(label = stringResource(R.string.task_form_icon)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f))
                                .clickable { showIconPicker = true },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = Icons.Default.TaskAlt,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        }
                        Text(
                            iconName.replaceFirstChar { it.uppercase() },
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Icon(Icons.Default.ChevronRight, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }

                Spacer(Modifier.height(12.dp))

                // Category
                if (categories.isNotEmpty()) {
                    FormFieldLabel(stringResource(R.string.category))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        item {
                            FilterChip(selected = selectedCategory == null, onClick = { selectedCategory = null }, label = { Text(stringResource(R.string.task_form_none)) })
                        }
                        items(categories) { cat ->
                            FilterChip(
                                selected = selectedCategory?.id == cat.id,
                                onClick = { selectedCategory = cat },
                                label = { Text(cat.name) },
                                leadingIcon = { Box(Modifier.size(12.dp).clip(CircleShape).background(parseHexColor(cat.color))) },
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }
                // Priority
                FormRow(label = stringResource(R.string.priority_label)) {
                    var prioExpanded by remember { mutableStateOf(false) }
                    Box {
                        Row(
                            Modifier.clickable { prioExpanded = true }
                                .background(cardColor, RoundedCornerShape(8.dp))
                                .padding(horizontal = 12.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text(priority.displayName, style = MaterialTheme.typography.bodyMedium)
                            Icon(Icons.Default.ArrowDropDown, null, Modifier.size(16.dp))
                        }
                        DropdownMenu(expanded = prioExpanded, onDismissRequest = { prioExpanded = false }) {
                            Priority.entries.forEach { p ->
                                DropdownMenuItem(
                                    text = { Text(p.displayName) },
                                    onClick = { priority = p; prioExpanded = false },
                                )
                            }
                        }
                    }
                }
            }

            // ============ LOCATION CARD ============
            ModernFormCard(title = stringResource(R.string.location), icon = Icons.Default.LocationOn) {
                if (location != null) {
                    // Show selected location
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(24.dp),
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                location!!.shortDisplayName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                            location!!.address?.let {
                                Text(
                                    it,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                )
                            }
                        }
                        IconButton(onClick = { location = null }) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = stringResource(R.string.remove_location),
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                    }
                } else {
                    // Add location button
                    OutlinedButton(
                        onClick = { showLocationPicker = true },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.Default.AddLocation, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(stringResource(R.string.add_location))
                    }
                }
            }

            // ============ RECURRENCE CARD ============
            if (selectedTimeScope == TaskTimeScope.TODAY) {
                ModernFormCard(title = stringResource(R.string.task_form_recurrence), icon = Icons.Default.Repeat) {
                    FormToggleRow(label = stringResource(R.string.task_form_repeat_task), checked = isRecurring, onCheckedChange = { isRecurring = it })
                    AnimatedVisibility(visible = isRecurring) {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            // Recurrence type selector
                            FormRow(label = stringResource(R.string.task_form_frequency)) {
                                var recExpanded by remember { mutableStateOf(false) }
                                Box {
                                    Row(
                                        Modifier.clickable { recExpanded = true }
                                            .background(cardColor, RoundedCornerShape(8.dp))
                                            .padding(horizontal = 12.dp, vertical = 6.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    ) {
                                        Text(
                                            recurrenceType.replaceFirstChar { it.uppercase() },
                                            style = MaterialTheme.typography.bodyMedium,
                                        )
                                        Icon(Icons.Default.ChevronRight, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                    DropdownMenu(expanded = recExpanded, onDismissRequest = { recExpanded = false }) {
                                        listOf("daily", "weekly", "monthly", "yearly").forEach { t ->
                                            DropdownMenuItem(
                                                text = { Text(t.replaceFirstChar { it.uppercase() }) },
                                                onClick = { recurrenceType = t; recExpanded = false },
                                            )
                                        }
                                    }
                                }
                            }

                            // Weekly day selector
                            AnimatedVisibility(visible = recurrenceType == "weekly") {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text("Select days", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                                    Row(
                                        Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                    ) {
                                        val weekdays = listOf(
                                            Calendar.SUNDAY to "S",
                                            Calendar.MONDAY to "M",
                                            Calendar.TUESDAY to "T",
                                            Calendar.WEDNESDAY to "W",
                                            Calendar.THURSDAY to "T",
                                            Calendar.FRIDAY to "F",
                                            Calendar.SATURDAY to "S",
                                        )
                                        weekdays.forEach { (day, label) ->
                                            val isSelected = day in selectedWeekdays
                                            Box(
                                                modifier = Modifier
                                                    .size(36.dp)
                                                    .clip(CircleShape)
                                                    .background(
                                                        if (isSelected) MaterialTheme.colorScheme.primary
                                                        else MaterialTheme.colorScheme.surfaceContainer
                                                    )
                                                    .clickable {
                                                        selectedWeekdays = if (isSelected) {
                                                            selectedWeekdays - day
                                                        } else {
                                                            selectedWeekdays + day
                                                        }
                                                    },
                                                contentAlignment = Alignment.Center,
                                            ) {
                                                Text(
                                                    label,
                                                    style = MaterialTheme.typography.labelSmall,
                                                    fontWeight = FontWeight.Bold,
                                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                                                    else MaterialTheme.colorScheme.onSurfaceVariant,
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            // Monthly selector (days or ordinal)
                            AnimatedVisibility(visible = recurrenceType == "monthly") {
                                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    // Toggle between days and ordinal
                                    Row(
                                        Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        FilterChip(
                                            selected = monthlySelectionType == "days",
                                            onClick = { monthlySelectionType = "days" },
                                            label = { Text("Days of month") },
                                        )
                                        FilterChip(
                                            selected = monthlySelectionType == "ordinal",
                                            onClick = { monthlySelectionType = "ordinal" },
                                            label = { Text("Ordinal (e.g. 2nd Sunday)") },
                                        )
                                    }

                                    // Day numbers picker - using Row with wrap content instead of FlowRow
                                    AnimatedVisibility(visible = monthlySelectionType == "days") {
                                        Column(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalArrangement = Arrangement.spacedBy(4.dp),
                                        ) {
                                            // Days 1-16 in first row
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceEvenly,
                                            ) {
                                                (1..16).forEach { day ->
                                                    DayNumberChip(
                                                        day = day,
                                                        isSelected = day in selectedMonthlyDays,
                                                        onToggle = {
                                                            selectedMonthlyDays = if (day in selectedMonthlyDays) {
                                                                selectedMonthlyDays - day
                                                            } else {
                                                                selectedMonthlyDays + day
                                                            }
                                                        }
                                                    )
                                                }
                                            }
                                            // Days 17-31 in second row
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceEvenly,
                                            ) {
                                                (17..31).forEach { day ->
                                                    DayNumberChip(
                                                        day = day,
                                                        isSelected = day in selectedMonthlyDays,
                                                        onToggle = {
                                                            selectedMonthlyDays = if (day in selectedMonthlyDays) {
                                                                selectedMonthlyDays - day
                                                            } else {
                                                                selectedMonthlyDays + day
                                                            }
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // End date toggle
                            FormToggleRow(
                                label = "End date",
                                checked = hasRecurrenceEndDate,
                                onCheckedChange = { hasRecurrenceEndDate = it },
                            )

                            AnimatedVisibility(visible = hasRecurrenceEndDate) {
                                val endDateText = remember(recurrenceEndDate) {
                                    val fmt = java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault())
                                    fmt.format(java.util.Date(recurrenceEndDate))
                                }
                                FormRow(label = "Ends on") {
                                    TextButton(onClick = { showRecurrenceEndDatePicker = true }) {
                                        Text(endDateText)
                                    }
                                }
                            }

                            FormToggleRow(
                                label = stringResource(R.string.task_form_track_in_statistics),
                                checked = trackInStatistics,
                                onCheckedChange = { trackInStatistics = it },
                            )
                        }
                    }
                }
            }

            // ============ SUBTASKS CARD ============
            ModernFormCard(title = stringResource(R.string.task_form_subtasks), icon = Icons.Default.Checklist) {
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    OutlinedTextField(
                        value = newSubtaskName, onValueChange = { newSubtaskName = it },
                        placeholder = { Text(stringResource(R.string.task_form_add_subtask)) },
                        modifier = Modifier.weight(1f), singleLine = true,
                        shape = RoundedCornerShape(10.dp),
                    )
                    Button(
                        onClick = {
                            if (newSubtaskName.isNotBlank()) {
                                subtasks = subtasks + Subtask(name = newSubtaskName)
                                newSubtaskName = ""
                            }
                        },
                        enabled = newSubtaskName.isNotBlank(),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    ) { Text(stringResource(R.string.task_form_add)) }
                }

                if (subtasks.isNotEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    subtasks.forEach { subtask ->
                        Row(
                            Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Outlined.Circle, null, Modifier.size(12.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(8.dp))
                            Text(subtask.name, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                            IconButton(
                                onClick = { subtasks = subtasks.filter { it.id != subtask.id } },
                                modifier = Modifier.size(28.dp),
                            ) {
                                Icon(Icons.Default.RemoveCircle, "Remove", Modifier.size(16.dp), tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }

            // ============ REWARDS CARD ============
            ModernFormCard(title = stringResource(R.string.task_form_reward_points), icon = Icons.Default.Star) {
                FormToggleRow(label = stringResource(R.string.task_form_earn_reward_points), checked = hasRewardPoints, onCheckedChange = { hasRewardPoints = it })
                AnimatedVisibility(visible = hasRewardPoints) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        FormToggleRow(label = "Custom Points", checked = useCustomPoints, onCheckedChange = { useCustomPoints = it })
                        FormRow(label = "Points") {
                            if (useCustomPoints) {
                                OutlinedTextField(
                                    value = customPointsText,
                                    onValueChange = { v ->
                                        val filtered = v.filter { it.isDigit() }
                                        customPointsText = filtered
                                        filtered.toIntOrNull()?.let { if (it in 1..999) rewardPoints = it }
                                    },
                                    modifier = Modifier.width(80.dp), singleLine = true,
                                    shape = RoundedCornerShape(8.dp),
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                )
                                Spacer(Modifier.width(4.dp))
                                Text("(1-999)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            } else {
                                val presets = listOf(1,2,3,5,8,10,15,20,25,30,50,75,100)
                                var expanded by remember { mutableStateOf(false) }
                                Box {
                                    TextButton(onClick = { expanded = true }) { Text("$rewardPoints pts") }
                                    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                                        presets.forEach { p ->
                                            DropdownMenuItem(text = { Text("$p") }, onClick = { rewardPoints = p; customPointsText = "$p"; expanded = false })
                                        }
                                    }
                                }
                            }
                        }
                        // Guidelines
                        Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                            Text("Point Guidelines", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("• 1-10: Quick tasks (5-15 min)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("• 15-50: Regular tasks (30-90 min)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("• 75-200: Complex tasks (2-4 hours)", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }

            // ============ SAVE BUTTON ============
            Button(
                onClick = {
                    if (isValid) {
                        val taskCal = Calendar.getInstance().apply {
                            timeInMillis = startDateMillis
                            if (hasSpecificTime) { set(Calendar.HOUR_OF_DAY, selectedHour); set(Calendar.MINUTE, selectedMinute) }
                        }
                        val recurrence = if (isRecurring) {
                            val type = when (recurrenceType) {
                                "weekly" -> RecurrenceType.WEEKLY(selectedWeekdays)
                                "monthly" -> {
                                    if (monthlySelectionType == "ordinal" && selectedOrdinalPatterns.isNotEmpty()) {
                                        RecurrenceType.MONTHLY_ORDINAL(selectedOrdinalPatterns)
                                    } else {
                                        RecurrenceType.MONTHLY(selectedMonthlyDays)
                                    }
                                }
                                "yearly" -> RecurrenceType.YEARLY
                                else -> RecurrenceType.DAILY
                            }
                            val endDate = if (hasRecurrenceEndDate) Date(recurrenceEndDate) else null
                            Recurrence(
                                type = type,
                                startDate = taskCal.time,
                                endDate = endDate,
                                trackInStatistics = trackInStatistics,
                            )
                        } else null
                        val scopeStart = when (selectedTimeScope) {
                            TaskTimeScope.WEEK -> Recurrence.startOfWeek(Date(startDateMillis))
                            TaskTimeScope.MONTH -> Calendar.getInstance().apply { set(Calendar.YEAR, selectedYear); set(Calendar.MONTH, selectedMonth - 1); set(Calendar.DAY_OF_MONTH, 1) }.time
                            TaskTimeScope.YEAR -> Calendar.getInstance().apply { set(Calendar.YEAR, selectedYear); set(Calendar.MONTH, 0); set(Calendar.DAY_OF_MONTH, 1) }.time
                            else -> null
                        }
                        val task = (initialTask ?: TodoTask(name = name)).copy(
                            name = name, description = description.ifBlank { null },
                            location = location,
                            startTime = taskCal.time, hasSpecificTime = hasSpecificTime,
                            hasSpecificDay = hasSpecificDay, duration = durationSeconds,
                            hasDuration = hasDuration, category = selectedCategory,
                            priority = priority, icon = iconName, subtasks = subtasks,
                            hasNotification = hasNotification, notificationLeadTimeMinutes = notificationLeadTimeMinutes,
                            autoCarryOver = autoCarryOver, timeScope = selectedTimeScope,
                            scopeStartDate = scopeStart, recurrence = recurrence,
                            hasRewardPoints = hasRewardPoints, rewardPoints = rewardPoints,
                            lastModifiedDate = Date(),
                        )
                        onSave(task)
                    }
                },
                enabled = isValid,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(52.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    disabledContainerColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                ),
                elevation = ButtonDefaults.buttonElevation(defaultElevation = if (isValid) 6.dp else 0.dp),
            ) {
                Icon(Icons.Default.Check, null, Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.task_form_save_task), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            }
        }
    }

    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = startDateMillis)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { startDateMillis = it }
                    showDatePicker = false
                }) { Text(stringResource(R.string.task_form_ok)) }
            },
            dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text(stringResource(R.string.action_cancel)) } },
        ) { DatePicker(state = datePickerState) }
    }

    // Recurrence End Date picker dialog
    if (showRecurrenceEndDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = recurrenceEndDate)
        DatePickerDialog(
            onDismissRequest = { showRecurrenceEndDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { recurrenceEndDate = it }
                    showRecurrenceEndDatePicker = false
                }) { Text(stringResource(R.string.task_form_ok)) }
            },
            dismissButton = { TextButton(onClick = { showRecurrenceEndDatePicker = false }) { Text(stringResource(R.string.action_cancel)) } },
        ) { DatePicker(state = datePickerState) }
    }

    // Duration picker dialog
    if (showDurationPicker) {
        DurationPickerDialog(
            initialSeconds = durationSeconds,
            onDismiss = { showDurationPicker = false },
            onConfirm = { durationSeconds = it; showDurationPicker = false },
        )
    }

    // Location picker dialog
    if (showLocationPicker) {
        LocationPickerScreen(
            initialLocation = location,
            onLocationSelected = { selectedLocation ->
                location = selectedLocation
                showLocationPicker = false
            },
            onDismiss = { showLocationPicker = false },
        )
    }

    // Icon picker dialog
    if (showIconPicker) {
        IconPickerDialog(
            selectedIcon = iconName,
            onIconSelected = { selectedIcon ->
                iconName = selectedIcon
                showIconPicker = false
            },
            onDismiss = { showIconPicker = false },
        )
    }
}

// ======================== Helper Composables ========================

@Composable
private fun ModernFormCard(
    title: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        tonalElevation = 1.dp,
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(icon, null, Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(16.dp))
            content()
        }
    }
}

@Composable
private fun FormFieldLabel(label: String) {
    Text(label, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 4.dp))
}

@Composable
private fun FormRow(label: String, trailing: @Composable RowScope.() -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
        Spacer(Modifier.weight(1f))
        trailing()
    }
}

@Composable
private fun FormToggleRow(
    label: String,
    subtitle: String? = null,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun LeadTimeSelector(leadTimeMinutes: Int, onLeadTimeChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.task_form_when_to_notify), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            Text(
                leadTimeDescription(leadTimeMinutes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        var expanded by remember { mutableStateOf(false) }
        Box {
            TextButton(onClick = { expanded = true }) {
                Icon(Icons.Default.Notifications, null, Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(leadTimeShort(leadTimeMinutes), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(text = { Text(stringResource(R.string.notification_lead_exact)) }, onClick = { onLeadTimeChange(0); expanded = false })
                HorizontalDivider()
                listOf(5, 10, 15, 30, 60).forEach { m ->
                    DropdownMenuItem(
                        text = { Text("$m min before") },
                        onClick = { onLeadTimeChange(m); expanded = false },
                    )
                }
            }
        }
    }
}

private fun leadTimeDescription(minutes: Int): String {
    if (minutes == 0) return "At exact time"
    val h = minutes / 60; val m = minutes % 60
    return when {
        h > 0 && m > 0 -> "${h}h ${m}m before"
        h > 0 -> "${h}h before"
        else -> "${m}m before"
    }
}

private fun leadTimeShort(minutes: Int): String {
    if (minutes == 0) return "Exact"
    return if (minutes >= 60 && minutes % 60 == 0) "${minutes/60}h" else "${minutes}m"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DurationPickerDialog(initialSeconds: Double, onDismiss: () -> Unit, onConfirm: (Double) -> Unit) {
    var hours by remember { mutableIntStateOf((initialSeconds / 3600).toInt()) }
    var minutes by remember { mutableIntStateOf(((initialSeconds % 3600) / 60).toInt()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onConfirm((hours * 3600 + minutes * 60).toDouble()) }) { Text(stringResource(R.string.task_form_ok)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) } },
        title = { Text(stringResource(R.string.task_form_set_duration)) },
        text = {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                NumberPickerSimple(hours, 0..12, { hours = it })
                Text("h", Modifier.padding(horizontal = 8.dp), fontWeight = FontWeight.Bold)
                NumberPickerSimple(minutes, 0..55, { minutes = it }, step = 5)
                Text("m", Modifier.padding(start = 8.dp), fontWeight = FontWeight.Bold)
            }
        },
    )
}

@Composable
fun NumberPickerSimple(
    value: Int, range: IntRange, onValueChange: (Int) -> Unit,
    format: (Int) -> String = { it.toString() }, step: Int = 1,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        IconButton(onClick = { val n = value + step; onValueChange(if (n > range.last) range.first else n) }) {
            Icon(Icons.Default.KeyboardArrowUp, "Increase")
        }
        Text(format(value), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        IconButton(onClick = { val p = value - step; onValueChange(if (p < range.first) range.last else p) }) {
            Icon(Icons.Default.KeyboardArrowDown, "Decrease")
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun IconPickerDialog(
    selectedIcon: String,
    onIconSelected: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val availableIcons = listOf(
        "circle" to Icons.Default.Circle,
        "task" to Icons.Default.TaskAlt,
        "work" to Icons.Default.Work,
        "home" to Icons.Default.Home,
        "star" to Icons.Default.Star,
        "favorite" to Icons.Default.Favorite,
        "shopping" to Icons.Default.ShoppingCart,
        "health" to Icons.Default.FavoriteBorder,
        "book" to Icons.Default.Book,
        "school" to Icons.Default.School,
        "fitness" to Icons.Default.FitnessCenter,
        "money" to Icons.Default.AttachMoney,
        "phone" to Icons.Default.Phone,
        "email" to Icons.Default.Email,
        "calendar" to Icons.Default.CalendarMonth,
        "flag" to Icons.Default.Flag,
        "location" to Icons.Default.LocationOn,
        "flight" to Icons.Default.Flight,
        "car" to Icons.Default.DirectionsCar,
        "bus" to Icons.Default.DirectionsBus,
        "train" to Icons.Default.DirectionsRailway,
        "walk" to Icons.Default.DirectionsWalk,
        "bike" to Icons.Default.DirectionsBike,
        "run" to Icons.Default.DirectionsRun,
        "code" to Icons.Default.Code,
        "music" to Icons.Default.MusicNote,
        "movie" to Icons.Default.Movie,
        "game" to Icons.Default.SportsEsports,
        "camera" to Icons.Default.CameraAlt,
        "photo" to Icons.Default.Photo,
        "palette" to Icons.Default.Palette,
        "brush" to Icons.Default.Brush,
        "restaurant" to Icons.Default.Restaurant,
        "coffee" to Icons.Default.Coffee,
        "local_cafe" to Icons.Default.LocalCafe,
        "cake" to Icons.Default.Cake,
        "shopping_bag" to Icons.Default.ShoppingBag,
        "gift" to Icons.Default.CardGiftcard,
        "balloon" to Icons.Default.Celebration,
        "party" to Icons.Default.EmojiEmotions,
        "baby" to Icons.Default.ChildCare,
        "pet" to Icons.Default.Pets,
        "garden" to Icons.Default.Yard,
        "cleaning" to Icons.Default.CleaningServices,
        "repair" to Icons.Default.Build,
        "tool" to Icons.Default.Construction,
        "settings" to Icons.Default.Settings,
        "security" to Icons.Default.Security,
        "wifi" to Icons.Default.Wifi,
        "battery" to Icons.Default.BatteryFull,
        "alarm" to Icons.Default.Alarm,
        "timer" to Icons.Default.Timer,
        "watch" to Icons.Default.Watch,
        "sleep" to Icons.Default.Bedtime,
        "sunny" to Icons.Default.WbSunny,
        "cloud" to Icons.Default.Cloud,
        "rain" to Icons.Default.WaterDrop,
        "snow" to Icons.Default.AcUnit,
        "fire" to Icons.Default.LocalFireDepartment,
        "bolt" to Icons.Default.Bolt,
        "idea" to Icons.Default.Lightbulb,
        "target" to Icons.Default.TrackChanges,
        "chart" to Icons.Default.InsertChart,
        "trending" to Icons.Default.TrendingUp,
        "analytics" to Icons.Default.Analytics,
        "description" to Icons.Default.Description,
        "article" to Icons.Default.Article,
        "folder" to Icons.Default.Folder,
        "save" to Icons.Default.Save,
        "cloud_upload" to Icons.Default.CloudUpload,
        "download" to Icons.Default.Download,
        "share" to Icons.Default.Share,
        "send" to Icons.Default.Send,
        "draft" to Icons.Default.Drafts,
        "delete" to Icons.Default.Delete,
        "archive" to Icons.Default.Archive,
        "report" to Icons.Default.Report,
        "spam" to Icons.Default.ReportGmailerrorred,
        "block" to Icons.Default.Block,
        "warning" to Icons.Default.Warning,
        "error" to Icons.Default.Error,
        "check" to Icons.Default.Check,
        "close" to Icons.Default.Close,
        "add" to Icons.Default.Add,
        "remove" to Icons.Default.Remove,
        "edit" to Icons.Default.Edit,
        "create" to Icons.Default.Create,
        "content_copy" to Icons.Default.ContentCopy,
        "content_cut" to Icons.Default.ContentCut,
        "content_paste" to Icons.Default.ContentPaste,
        "select_all" to Icons.Default.SelectAll,
        "redo" to Icons.Default.Redo,
        "undo" to Icons.Default.Undo,
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) } },
        title = { Text("Select Icon") },
        text = {
            LazyVerticalGrid(
                columns = androidx.compose.foundation.lazy.grid.GridCells.Fixed(4),
                modifier = Modifier.height(300.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(
                    items = availableIcons,
                    key = { it.first }
                ) { iconPair ->
                    val name = iconPair.first
                    val icon = iconPair.second
                    val isSelected = name == selectedIcon
                    Box(
                        modifier = Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(
                                if (isSelected) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.surfaceContainer
                            )
                            .clickable { onIconSelected(name) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            icon,
                            contentDescription = name,
                            modifier = Modifier.size(28.dp),
                            tint = if (isSelected) MaterialTheme.colorScheme.onPrimary
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        },
    )
}

@Composable
private fun DayNumberChip(
    day: Int,
    isSelected: Boolean,
    onToggle: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(
                if (isSelected) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.surfaceContainer
            )
            .clickable { onToggle() },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "$day",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            color = if (isSelected) MaterialTheme.colorScheme.onPrimary
            else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
