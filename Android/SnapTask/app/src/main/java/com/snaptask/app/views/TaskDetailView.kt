package com.snaptask.app

import android.Manifest
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.io.File
import java.time.format.FormatStyle
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private val LocalDetailCategoryColor = compositionLocalOf<Color?> { null }

@Composable
private fun DetailCard(icon: String, title: String, color: Color, content: @Composable ColumnScope.() -> Unit) {
    val theme = theme
    val category = LocalDetailCategoryColor.current
    val shape = RoundedCornerShape(12.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(5.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.cardBackground)
            .border(1.dp, category?.copy(alpha = 0.4f) ?: theme.borderColor, shape)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SF(icon, color, 18.dp)
            T(title, Fonts.headline)
        }
        content()
    }
}

@Composable
private fun InfoRow(title: String, value: String, valueColor: Color = theme.textColor) {
    Row(verticalAlignment = Alignment.Top) {
        T(title, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(8.dp))
        T(value, Fonts.subheadline, valueColor, TextAlign.End)
    }
}

/** A photo from a file, cropped to fill. */
@Composable
fun FileImage(path: String, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Crop) {
    AsyncImage(model = File(path), contentDescription = null, contentScale = contentScale, modifier = modifier)
}

fun formatMemoDuration(duration: Double): String {
    val h = duration.toInt() / 3600
    val m = duration.toInt() % 3600 / 60
    val s = duration.toInt() % 60
    return if (h > 0) "%dh %02dm %02ds".format(h, m, s) else "%02dm %02ds".format(m, s)
}

fun formatClock(seconds: Double): String = "%d:%02d".format(seconds.toInt() / 60, seconds.toInt() % 60)

/** Where a camera photo is written, shared with the camera app. */
fun newCameraUri(): Pair<File, Uri> {
    val file = File(App.context.cacheDir, "camera_${UUID.randomUUID()}.jpg")
    return file to FileProvider.getUriForFile(App.context, "${App.context.packageName}.fileprovider", file)
}

@Composable
fun TaskDetailView(taskId: UUID, targetDate: Date? = null) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val fixedDate = remember { targetDate ?: now() }
    val task = TaskManager.task(taskId)
    val accent = task?.category?.let { colorFromHex(it.color) } ?: theme.primaryColor

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("task_details".localized, leading = { BarButton("close".localized, color = accent, onClick = dismiss) })
        if (task == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                T("task_not_found".localized, Fonts.body, theme.secondaryTextColor)
            }
            return@Column
        }
        val key = task.completionKey(fixedDate)
        val completion = task.completions[key]
        val isCompleted = completion?.isCompleted == true
        var isEditingVoiceMemo by remember { mutableStateOf(false) }

        Box(Modifier.weight(1f).fillMaxWidth()) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding()) {
                HeaderSection(task, isCompleted, completion, accent)
                CompositionLocalProvider(LocalDetailCategoryColor provides task.category?.let { colorFromHex(it.color) }) {
                    Column(
                        Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 120.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        task.description?.takeIf { it.isNotEmpty() }?.let { description ->
                            DetailCard("doc.text", "description".localized, Color.SysBlue) {
                                T(description, Fonts.body, modifier = Modifier.fillMaxWidth())
                            }
                        }
                        task.location?.let { LocationCard(it) }
                        ScheduleCard(task, key, fixedDate)
                        task.recurrence?.let { RecurrenceDetailCard(task, it) }
                        PhotoCard(task)
                        VoiceMemosCard(task) { isEditingVoiceMemo = it }
                        DetailCard("note.text", "notes".localized, Color.SysPurple) {
                            TaskNotesSection(completion?.notes ?: "") { value ->
                                TaskManager.updateTaskRating(task.id, notes = value, date = fixedDate)
                            }
                        }
                        InsightsCard(task, completion, isCompleted, fixedDate)
                        if (task.subtasks.isNotEmpty()) {
                            DetailCard("checklist", "subtasks".localized, Color.SysIndigo) {
                                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    task.subtasks.forEach { subtask ->
                                        key(subtask.id) {
                                            val done = completion?.completedSubtasks?.contains(subtask.id) == true
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                                Box(Modifier.tap { TaskManager.toggleSubtask(task.id, subtask.id, fixedDate) }) {
                                                    SF(if (done) "checkmark.circle.fill" else "circle", if (done) Color.SysGreen else theme.secondaryTextColor, 20.dp)
                                                }
                                                T(subtask.name, Fonts.body, modifier = Modifier.weight(1f))
                                                Box(
                                                    Modifier.tap {
                                                        val updated = task.copy(
                                                            subtasks = task.subtasks.filter { it.id != subtask.id },
                                                            completions = task.completions.mapValues { (_, c) -> c.copy(completedSubtasks = c.completedSubtasks - subtask.id) },
                                                            lastModifiedDate = now(),
                                                        )
                                                        MainScope.launch { TaskManager.updateTask(updated) }
                                                    }
                                                ) { SF("minus.circle.fill", Color.SysRed, 20.dp) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        task.pomodoroSettings?.let { settings ->
                            DetailCard("timer", "pomodoro".localized, Color.SysRed) {
                                InfoRow("work_duration".localized, "${(settings.workDuration / 60).toInt()} min")
                                InfoRow("break_time".localized, "${(settings.breakDuration / 60).toInt()} min")
                                Row(
                                    Modifier
                                        .fillMaxWidth()
                                        .padding(top = 8.dp)
                                        .shadow(6.dp, RoundedCornerShape(10.dp), ambientColor = Color.SysRed.copy(alpha = 0.3f), spotColor = Color.SysRed.copy(alpha = 0.3f))
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(Brush.verticalGradient(listOf(Color.SysRed, Color.SysRed.copy(alpha = 0.8f))))
                                        .pressable {
                                            PomodoroViewModel.setActiveTask(task)
                                            presenter.fullScreen { NavigationStack { PomodoroTabView() } }
                                        }
                                        .padding(vertical = 12.dp),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    SF("play.fill", theme.backgroundColor, 18.dp)
                                    T("start_pomodoro".localized, Fonts.subheadline.medium, theme.backgroundColor)
                                }
                            }
                        }
                        if (task.hasRewardPoints) {
                            DetailCard("star", "rewards".localized, Color.SysYellow) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                        T("available_points".localized, Fonts.subheadline.medium, theme.secondaryTextColor)
                                        T("${task.rewardPoints} ${"points".localized}", Fonts.title3.bold, Color.SysYellow)
                                    }
                                    SF("star.fill", Color.SysYellow, 26.dp)
                                }
                            }
                        }
                    }
                }
            }

            if (!isEditingVoiceMemo) {
                Column(Modifier.align(Alignment.BottomCenter)) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(30.dp)
                            .background(Brush.verticalGradient(listOf(theme.backgroundColor.copy(alpha = 0f), theme.backgroundColor.copy(alpha = 0.8f), theme.backgroundColor)))
                    )
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .background(theme.backgroundColor)
                            .navigationBarsPadding()
                            .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        DetailAction(
                            "play.fill", "track".localized, Brush.verticalGradient(listOf(Color.SysYellow, Color.SysYellow.copy(alpha = 0.8f))),
                            theme.buttonTextColor, Color.SysYellow, Modifier.weight(1f),
                        ) { presentTrackingSelection(presenter, task) }
                        val editBrush = if (task.category != null) Brush.verticalGradient(listOf(accent, accent.copy(alpha = 0.8f))) else theme.gradient
                        val editText = if (task.category != null) {
                            if (0.2126f * accent.red + 0.7152f * accent.green + 0.0722f * accent.blue < 0.5f) Color.White else Color.Black
                        } else theme.buttonTextColor
                        DetailAction("pencil", "edit".localized, editBrush, editText, accent, Modifier.weight(1f)) {
                            presenter.sheet { TaskFormView(initialTask = task, onSave = { MainScope.launch { TaskManager.updateTask(it) } }) }
                        }
                        val tint = if (isCompleted) Color.SysOrange else Color.SysGreen
                        DetailAction(
                            if (isCompleted) "arrow.uturn.backward.circle.fill" else "circle",
                            if (isCompleted) "mark_incomplete".localized else "done".localized,
                            Brush.verticalGradient(listOf(tint, tint.copy(alpha = 0.8f))),
                            theme.buttonTextColor, tint, Modifier.weight(1f),
                        ) { TaskManager.toggleTaskCompletion(task.id, fixedDate) }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailAction(icon: String, text: String, background: Brush, textColor: Color, shadow: Color, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier
            .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = shadow.copy(alpha = 0.3f), spotColor = shadow.copy(alpha = 0.3f))
            .clip(RoundedCornerShape(16.dp))
            .background(background)
            .pressable(onClick = onClick)
            .padding(vertical = 16.dp, horizontal = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Icon and text when they fit; otherwise the text alone, as a last resort the icon: never cut.
        ViewThatFits(
            {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SF(icon, textColor, 18.dp)
                    T(text, Fonts.headline, textColor, maxLines = 1)
                }
            },
            { T(text, Fonts.headline, textColor, maxLines = 1) },
            { SF(icon, textColor, 20.dp) },
        )
    }
}

@Composable
private fun HeaderSection(task: TodoTask, isCompleted: Boolean, completion: TaskCompletion?, accent: Color) {
    val theme = theme
    val shape = RoundedCornerShape(20.dp)
    val categoryColor = if (SettingsViewModel.showCategoryGradients) task.category?.let { colorFromHex(it.color) } else null
    Row(
        Modifier
            .padding(start = 16.dp, end = 16.dp, top = 4.dp)
            .fillMaxWidth()
            .shadow(if (theme.systemDark) 1.dp else 8.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .then(
                if (categoryColor != null) Modifier
                    .background(Brush.horizontalGradient(0f to categoryColor.copy(alpha = 0.22f), 0.35f to categoryColor.copy(alpha = 0.10f), 0.7f to categoryColor.copy(alpha = 0.03f), 1f to Color.Transparent))
                    .border(1.dp, Brush.horizontalGradient(listOf(categoryColor.copy(alpha = 0.35f), categoryColor.copy(alpha = 0.08f))), shape)
                else if (theme.systemDark) Modifier.border(1.dp, theme.borderColor, shape) else Modifier
            )
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.size(60.dp).background(accent.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) {
            SF(task.icon, accent, 32.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(task.name, Fonts.title2.bold)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                task.category?.let { category ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(Modifier.size(8.dp).background(colorFromHex(category.color), CircleShape))
                        T(category.name, Fonts.caption, theme.secondaryTextColor)
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    SF(task.priority.icon, colorFromHex(task.priority.colorHex), 12.dp)
                    T(task.priority.displayName, Fonts.caption, theme.secondaryTextColor)
                }
            }
        }
        val state = when {
            isCompleted -> TaskProgressState.completed
            completion?.isInProgress == true -> TaskProgressState.inProgress
            else -> TaskProgressState.todo
        }
        TaskStatusIcon(state, theme.secondaryTextColor, size = 24.dp)
    }
}

@Composable
private fun ScheduleCard(task: TodoTask, key: Date, fixedDate: Date) {
    val theme = theme
    val presenter = LocalPresenter.current
    DetailCard("clock", "time".localized, Color.SysOrange) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            InfoRow("time_range".localized, task.displayPeriod)
            if (task.hasSpecificDay) InfoRow("date".localized, task.startTime.dateStyle(FormatStyle.MEDIUM))
            if (task.hasSpecificTime) InfoRow("start_time".localized, task.startTime.timeText())
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("notifications".localized, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                if (task.hasNotification) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        SF("bell.fill", Color.SysBlue, 14.dp)
                        T("enabled".localized, Fonts.subheadline, Color.SysBlue)
                    }
                } else T("disabled".localized, Fonts.subheadline, theme.secondaryTextColor)
            }
            if (task.hasNotification && task.hasSpecificTime) {
                InfoRow("notification_advance_notice".localized, leadTimeLabel(task.notificationLeadTimeMinutes))
            }

            val actual = task.completions[key]?.actualDuration
            fun showPicker() {
                presenter.sheet {
                    DurationPickerView(task.completions[key]?.actualDuration ?: 0.0) { value ->
                        TaskManager.updateTaskRating(task.id, actualDuration = max(0.0, value), date = fixedDate)
                    }
                }
            }
            if (actual != null && actual > 0) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("actual_duration".localized, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                        T("edit".localized, Fonts.caption, Color.SysBlue, modifier = Modifier.tap { showPicker() })
                        T("clear".localized, Fonts.caption, Color.SysRed, modifier = Modifier.tap { TaskManager.updateTaskRating(task.id, actualDuration = 0.0, date = fixedDate) })
                    }
                    T(formatHoursMinutes(actual), Fonts.subheadline.semibold, Color.SysGreen)
                    if (task.hasDuration) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("estimation_accuracy".localized, Fonts.caption, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                            val difference = actual - task.duration
                            val percentage = (abs(difference) / task.duration * 100).toInt()
                            // The estimate that was beaten, not a completed task: a strikethrough is right here.
                            T(formatHoursMinutes(task.duration), Fonts.caption.copy(textDecoration = TextDecoration.LineThrough), theme.secondaryTextColor)
                            Spacer(Modifier.width(4.dp))
                            T(if (difference < 0) "(-$percentage%)" else "(+$percentage%)", Fonts.caption.medium, if (difference < 0) Color.SysGreen else Color.SysOrange)
                        }
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (task.hasDuration) InfoRow("duration".localized, formatHoursMinutes(task.duration), Color.SysBlue)
                    else InfoRow("duration".localized, "none".localized, theme.secondaryTextColor)
                    Row(
                        Modifier.padding(top = 2.dp).tap { showPicker() },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        SF("plus.circle", Color.SysBlue, 14.dp)
                        T("add_duration".localized, Fonts.caption, Color.SysBlue)
                    }
                }
            }
        }
    }
}

private fun leadTimeLabel(minutes: Int): String {
    if (minutes == 0) return "notification_lead_exact".localized
    val after = minutes < 0
    val total = abs(minutes)
    val h = total / 60
    val m = total % 60
    return if (after) when {
        h > 0 && m > 0 -> "notification_lead_h_m_after".localized(h, m)
        h > 0 -> "notification_lead_h_after".localized(h)
        else -> "notification_lead_m_after".localized(m)
    } else when {
        h > 0 && m > 0 -> "notification_lead_h_m_before".localized(h, m)
        h > 0 -> "notification_lead_h_before".localized(h)
        else -> "notification_lead_m_before".localized(m)
    }
}

@Composable
private fun LocationCard(location: TaskLocation) {
    val context = LocalContext.current
    DetailCard("location.fill", "location".localized, Color.SysGreen) {
        LocationMapView(location, 120.dp)
        Row(
            Modifier
                .fillMaxWidth()
                .tap {
                    val query = location.coordinate?.let { "geo:${it.latitude},${it.longitude}?q=${it.latitude},${it.longitude}(${Uri.encode(location.name)})" }
                        ?: "geo:0,0?q=${Uri.encode(location.displayName)}"
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(query))) }
                }
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SF("map.fill", Color.SysBlue, 18.dp)
            T("open_in_maps".localized, Fonts.body.medium, Color.SysBlue, modifier = Modifier.weight(1f))
            SF("arrow.up.right", Color.SysBlue, 14.dp)
        }
    }
}

@Composable
private fun RecurrenceDetailCard(task: TodoTask, recurrence: Recurrence) {
    DetailCard("repeat", "recurrence".localized, Color.SysPurple) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            val description = when (val type = recurrence.type) {
                RecurrenceType.Daily -> "daily".localized
                is RecurrenceType.Weekly -> if (type.days.size == 7) "daily".localized else "days_per_week_format".localized(type.days.size)
                is RecurrenceType.Monthly -> "days_per_month_format".localized(type.days.size)
                is RecurrenceType.MonthlyOrdinal -> if (type.patterns.isEmpty()) "monthly".localized else type.patterns.joinToString(", ") { it.displayText }
                RecurrenceType.Yearly -> "yearly".localized
            }
            InfoRow("patterns_enum".localized, description)
            recurrence.endDate?.let { InfoRow("end_date".localized, it.dateStyle(FormatStyle.MEDIUM)) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                T("current_streak".localized, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                SF("flame.fill", Color.SysOrange, 14.dp)
                Spacer(Modifier.width(4.dp))
                T("${task.currentStreak}", Fonts.subheadline.bold, Color.SysOrange)
            }
        }
    }
}

@Composable
private fun PhotoCard(task: TodoTask) {
    val theme = theme
    val presenter = LocalPresenter.current
    var showSourceDialog by remember { mutableStateOf(false) }
    var showLimitAlert by remember { mutableStateOf(false) }
    var cameraFile by remember { mutableStateOf<File?>(null) }
    val canAddMore = MediaLimits.canAddPhoto(task.photos.size)
    val remaining = MediaLimits.remainingPhotos(task.photos.size)

    fun addAll(datas: List<ByteArray>, skipped: Boolean) {
        MainScope.launch {
            val current = TaskManager.task(task.id) ?: return@launch
            val added = withContext(Dispatchers.IO) { datas.mapNotNull { AttachmentService.addPhoto(task.id, it) } }
            TaskManager.updateTask(current.copy(photos = current.photos + added, lastModifiedDate = now()))
            if (skipped) showLimitAlert = true
        }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val file = cameraFile
        if (ok && file != null) {
            if (MediaLimits.canAddPhoto(task.photos.size)) addAll(listOf(file.readBytes()), false) else showLimitAlert = true
            file.delete()
        }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val (file, uri) = newCameraUri()
            cameraFile = file
            camera.launch(uri)
        }
    }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(MediaLimits.maxPhotosPerTask)) { uris ->
        if (uris.isNotEmpty()) {
            val allowed = uris.take(remaining)
            addAll(allowed.mapNotNull { AttachmentService.readUri(it) }, uris.size > allowed.size)
        }
    }

    if (showSourceDialog) {
        ConfirmationDialog(
            title = "add_photos".localized,
            actions = listOf(
                AlertAction("take_photo".localized) { cameraPermission.launch(Manifest.permission.CAMERA) },
                AlertAction("add_photos".localized) { library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                AlertAction("cancel".localized, AlertRole.cancel),
            ),
            onDismiss = { showSourceDialog = false },
        )
    }
    if (showLimitAlert) {
        IOSAlert(
            "photo_limit_reached_title".localized,
            "photo_limit_reached_message".localized(MediaLimits.maxPhotosPerTask),
            listOf(AlertAction("ok".localized, AlertRole.cancel)),
            { showLimitAlert = false },
        )
    }

    DetailCard("photo", "photos".localized, Color.SysBlue) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (task.photos.isNotEmpty()) {
                T("${task.photos.size}/${MediaLimits.maxPhotosPerTask}", Fonts.caption, if (canAddMore) Color.Secondary else Color.SysOrange)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    task.photos.forEach { photo ->
                        key(photo.id) {
                            Box(Modifier.weight(1f).height(90.dp)) {
                                FileImage(
                                    photo.thumbnailPath,
                                    Modifier
                                        .fillMaxSize()
                                        .clip(RoundedCornerShape(10.dp))
                                        .tap { presenter.sheet { NavigationStack { FullScreenPhoto(photo.photoPath) } } },
                                )
                                Box(
                                    Modifier
                                        .align(Alignment.TopEnd)
                                        .padding(6.dp)
                                        .background(Color.White.copy(alpha = 0.85f), CircleShape)
                                        .tap {
                                            AttachmentService.deletePhoto(task.id, photo)
                                            MainScope.launch { TaskManager.updateTask(task.copy(photos = task.photos.filter { it.id != photo.id }, lastModifiedDate = now())) }
                                        }
                                        .padding(2.dp)
                                ) { SF("trash.circle.fill", Color.SysRed, 18.dp) }
                            }
                        }
                    }
                    repeat(3 - task.photos.size) { Spacer(Modifier.weight(1f)) }
                }
                if (canAddMore) AddMediaButton("add_photos_remaining".localized(remaining), Modifier.padding(top = 4.dp)) { showSourceDialog = true }
            } else {
                AddMediaButton("add_photos".localized) { showSourceDialog = true }
            }
        }
    }
}

@Composable
fun FullScreenPhoto(path: String) {
    val dismiss = LocalDismiss.current
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("", trailing = { BarButton("close".localized, onClick = dismiss) })
        FileImage(path, Modifier.weight(1f).fillMaxWidth(), ContentScale.Fit)
    }
}

@Composable
fun AddMediaButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.SysBlue.copy(alpha = 0.05f))
            .border(1.dp, Color.SysBlue.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
            .tap(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SF("plus.circle", Color.SysBlue, 18.dp)
        T(title, Fonts.subheadline, Color.SysBlue)
    }
}

@Composable
private fun VoiceMemosCard(task: TodoTask, onEditing: (Boolean) -> Unit) {
    val theme = theme
    val service = remember { VoiceMemoService() }
    var micDenied by remember { mutableStateOf(false) }
    var showMaxReached by remember { mutableStateOf(false) }
    val canAddMore = MediaLimits.canAddVoiceMemo(task.voiceMemos.size)

    fun finish() {
        val (path, duration) = service.stop() ?: return
        val current = TaskManager.task(task.id) ?: return
        MainScope.launch {
            TaskManager.updateTask(current.copy(voiceMemos = listOf(TaskVoiceMemo(audioPath = path, duration = duration)) + current.voiceMemos, lastModifiedDate = now()))
        }
    }
    fun start() {
        runCatching {
            service.start(VoiceMemoService.taskFolder(task.id)) {
                finish()
                showMaxReached = true
            }
        }
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) start() else micDenied = true
    }
    DisposableEffect(Unit) { onDispose { if (service.isRecording) finish() } }

    if (micDenied) IOSAlert("microphone_access_denied_title".localized, "microphone_access_denied_message".localized, listOf(AlertAction("ok".localized, AlertRole.cancel)), { micDenied = false })
    if (showMaxReached) IOSAlert("max_duration_reached_title".localized, "max_duration_reached_message".localized((MediaLimits.maxVoiceMemoDuration / 60).toInt()), listOf(AlertAction("ok".localized, AlertRole.cancel)), { showMaxReached = false })

    DetailCard("waveform", "voice_memos".localized, Color.SysPink) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (task.voiceMemos.isNotEmpty()) {
                Row {
                    T("${task.voiceMemos.size}/${MediaLimits.maxVoiceMemosPerTask}", Fonts.caption, if (canAddMore) Color.Secondary else Color.SysOrange, modifier = Modifier.weight(1f))
                    T("max_duration_info".localized((MediaLimits.maxVoiceMemoDuration / 60).toInt()), Fonts.caption, Color.Secondary)
                }
            }
            if (canAddMore || service.isRecording) {
                Row(
                    Modifier
                        .defaultMinSize(minWidth = 110.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (service.isRecording) Color.SysOrange else Color.SysRed)
                        .pressable {
                            if (service.isRecording) finish() else permission.launch(Manifest.permission.RECORD_AUDIO)
                        }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SF(if (service.isRecording) "stop.circle.fill" else "record.circle.fill", Color.White, 18.dp)
                    T(if (service.isRecording) "stop".localized else "record".localized, Fonts.subheadline.medium, Color.White, maxLines = 1)
                }
            } else {
                T("voice_memo_limit_info".localized, Fonts.caption, Color.SysOrange)
            }
            AnimatedVisibility(service.isRecording, enter = fadeIn(tween(200)), exit = fadeOut(tween(200))) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    WaveformView(service.meterLevels, Color.SysPink, Modifier.fillMaxWidth().height(40.dp))
                    Row {
                        T("recording".localized, Fonts.caption, Color.SysOrange, modifier = Modifier.weight(1f))
                        T(formatClock(service.currentRecordingDuration), Fonts.caption.monospacedDigit, if (service.currentRecordingDuration > MediaLimits.maxVoiceMemoDuration * 0.8) Color.SysRed else Color.Secondary)
                        T(" / ${formatClock(MediaLimits.maxVoiceMemoDuration)}", Fonts.caption.monospacedDigit, Color.Secondary)
                    }
                }
            }
            if (task.voiceMemos.isEmpty() && !service.isRecording) {
                if (canAddMore) T("no_voice_memos_yet".localized, Fonts.subheadline, theme.secondaryTextColor)
            } else {
                task.voiceMemos.forEach { memo ->
                    key(memo.id) {
                        VoiceMemoRow(
                            memo.displayName, memo.name, memo.audioPath, memo.duration, memo.createdAt,
                            onDelete = {
                                File(memo.audioPath).delete()
                                MainScope.launch { TaskManager.updateTask(task.copy(voiceMemos = task.voiceMemos.filter { it.id != memo.id }, lastModifiedDate = now())) }
                            },
                            onRename = { name ->
                                MainScope.launch { TaskManager.updateTask(task.copy(voiceMemos = task.voiceMemos.map { if (it.id == memo.id) it.copy(name = name.ifEmpty { null }) else it }, lastModifiedDate = now())) }
                            },
                            onEditing = onEditing,
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun WaveformView(levels: List<Float>, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val count = levels.size.coerceAtLeast(1)
        val gap = 2.dp.toPx()
        val width = ((size.width - gap * (count - 1)) / count).coerceAtLeast(1f)
        levels.forEachIndexed { index, level ->
            val h = (level.coerceIn(0f, 1f) * size.height).coerceAtLeast(2.dp.toPx())
            drawRoundRect(color, Offset(index * (width + gap), (size.height - h) / 2), Size(width, h), CornerRadius(width / 2))
        }
    }
}

/** A memo row, shared by tasks and the journal. */
@Composable
fun VoiceMemoRow(
    displayName: String,
    name: String?,
    path: String,
    duration: Double,
    createdAt: Date,
    onDelete: () -> Unit,
    onRename: (String) -> Unit,
    onEditing: (Boolean) -> Unit = {},
) {
    val player = remember { AudioPlayerObject() }
    var waveform by remember { mutableStateOf<List<Float>>(emptyList()) }
    var isEditing by remember { mutableStateOf(false) }
    var editingText by remember { mutableStateOf("") }
    LaunchedEffect(path) {
        player.prepare(path)
        val samples = WaveformGenerator.generate(path, 60)
        waveform = samples.ifEmpty { List(60) { 0.2f } }
    }
    DisposableEffect(path) { onDispose { player.release() } }
    fun stopEditing() {
        isEditing = false
        onEditing(false)
    }

    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.SysBlue.copy(alpha = 0.05f))
            .border(1.dp, Color.SysBlue.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.tap(!isEditing) { if (player.isPlaying) player.pause() else player.play(path) }) {
            SF(if (player.isPlaying) "pause.circle.fill" else "play.circle.fill", Color.SysBlue, 32.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (isEditing) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PlainField(
                        editingText, { editingText = it }, "voice_memo_name_placeholder".localized, Fonts.subheadline.medium,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(6.dp))
                            .background(Color.TertiaryFill)
                            .padding(6.dp),
                    )
                    T("save".localized, Fonts.caption, Color.SysBlue, modifier = Modifier.tap {
                        onRename(editingText)
                        stopEditing()
                    })
                    T("cancel".localized, Fonts.caption, Color.SysRed, modifier = Modifier.tap { stopEditing() })
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(displayName, Fonts.subheadline.medium, Color.Primary, modifier = Modifier.weight(1f, false))
                    Spacer(Modifier.width(4.dp))
                    Box(Modifier.tap {
                        editingText = name ?: ""
                        isEditing = true
                        onEditing(true)
                    }) { SF("pencil.circle.fill", Color.SysBlue, 18.dp) }
                    Spacer(Modifier.weight(1f))
                    if (player.isPlaying || player.currentTime > 0) {
                        T("${formatClock(player.currentTime)} / ${formatClock(duration)}", Fonts.caption.monospacedDigit, Color.SysBlue, maxLines = 1)
                    }
                }
                T(formatMemoDuration(duration) + " • " + createdAt.dateStyle(FormatStyle.MEDIUM) + " " + createdAt.timeText(), Fonts.caption, Color.Secondary)
                WaveformWithProgress(waveform, Color.SysBlue, if (duration > 0) (player.currentTime / duration).toFloat() else 0f, Modifier.fillMaxWidth().height(28.dp)) { p ->
                    player.seek(p * duration)
                }
            }
        }
        Box(Modifier.tap {
            player.release()
            onDelete()
        }) { SF("trash", Color.SysRed, 20.dp) }
    }
}

@Composable
private fun WaveformWithProgress(levels: List<Float>, color: Color, progress: Float, modifier: Modifier, onScrub: (Double) -> Unit) {
    Canvas(
        modifier
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { onScrub((it.x / size.width).coerceIn(0f, 1f).toDouble()) },
                    onDrag = { change, _ -> onScrub((change.position.x / size.width).coerceIn(0f, 1f).toDouble()) },
                )
            }
            .pointerInput(Unit) { detectTapGestures { onScrub((it.x / size.width).coerceIn(0f, 1f).toDouble()) } }
    ) {
        val count = levels.size.coerceAtLeast(1)
        val gap = 2.dp.toPx()
        val width = ((size.width - gap * (count - 1)) / count).coerceAtLeast(1f)
        val index = (count * progress).toInt()
        levels.forEachIndexed { i, level ->
            val h = (level.coerceIn(0f, 1f) * size.height).coerceAtLeast(2.dp.toPx())
            drawRoundRect(if (i <= index) color else color.copy(alpha = 0.3f), Offset(i * (width + gap), (size.height - h) / 2), Size(width, h), CornerRadius(width / 2))
        }
        drawRect(color, Offset(progress * size.width - 1.dp.toPx(), 0f), Size(2.dp.toPx(), size.height))
    }
}

@Composable
fun TaskNotesSection(notes: String, onChange: (String) -> Unit) {
    var isEditing by remember { mutableStateOf(false) }
    var temp by remember { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T("notes".localized, Fonts.subheadline.medium, Color.Secondary, modifier = Modifier.weight(1f))
            if (!isEditing && notes.isNotEmpty()) {
                T("edit".localized, Fonts.caption, Color.SysBlue, modifier = Modifier.tap {
                    temp = notes
                    isEditing = true
                })
            }
        }
        if (isEditing) {
            PlainField(
                temp, { temp = it }, "", singleLine = false, minLines = 3,
                color = Color.Primary,
                modifier = Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 80.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.Gray6)
                    .border(1.dp, Color.SysBlue.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
            Row {
                T(
                    "cancel".localized, Fonts.subheadline.medium, Color.Secondary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.Gray5)
                        .tap {
                            temp = ""
                            isEditing = false
                        }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
                Spacer(Modifier.weight(1f))
                T(
                    "save".localized, Fonts.subheadline.medium, Color.White,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.SysBlue)
                        .tap {
                            onChange(temp.trim())
                            isEditing = false
                        }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        } else if (notes.isEmpty()) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.SysBlue.copy(alpha = 0.05f))
                    .border(1.dp, Color.SysBlue.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
                    .tap {
                        temp = notes
                        isEditing = true
                    }
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SF("plus.circle", Color.SysBlue, 18.dp)
                T("add_your_thoughts_completion".localized, Fonts.subheadline, Color.SysBlue)
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T(notes, Fonts.body, Color.Primary, modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp))
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                    T("clear".localized, Fonts.caption, Color.SysRed, modifier = Modifier.tap { onChange("") })
                }
            }
        }
    }
}

@Composable
private fun RatingRow(
    rating: Int,
    filled: String,
    empty: String,
    color: @Composable (Int) -> Color,
    description: String,
    hint: String,
    onChange: (Int) -> Unit,
) {
    val presenter = LocalPresenter.current
    val canUse = SubscriptionManager.hasAccess(PremiumFeature.taskEvaluation)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (level in 1..10) {
                val tint = if (canUse) (if (level <= rating) color(level) else Color.SysGray.copy(alpha = 0.3f)) else Color.SysGray.copy(alpha = 0.2f)
                Box(
                    Modifier
                        .size(22.dp)
                        .tap {
                            if (canUse) onChange(if (rating == level) 0 else level)
                            else presenter.sheet { PremiumPaywallView() }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    SF(if (level <= rating) filled else empty, tint, 15.dp)
                }
            }
            Spacer(Modifier.weight(1f))
            if (canUse && rating > 0) T("$rating/10", Fonts.caption.bold, color(rating), maxLines = 1)
            else if (!canUse) PremiumBadge(small = true)
        }
        when {
            canUse && rating > 0 -> T(description, Fonts.caption2, Color.Secondary)
            canUse -> T(hint, Fonts.caption2, Color.SysBlue)
            else -> T("premium_feature_locked".localized, Fonts.caption2, Color.SysPurple, modifier = Modifier.tap { presenter.sheet { PremiumPaywallView() } })
        }
    }
}

@Composable
fun DifficultyRatingView(rating: Int, onChange: (Int) -> Unit) {
    RatingRow(
        rating, "bolt.fill", "bolt.fill",
        { level ->
            when (level) {
                in 1..3 -> Color.SysGreen
                in 4..6 -> Color.SysYellow
                in 7..8 -> Color.SysOrange
                in 9..10 -> Color.SysRed
                else -> Color.SysGray
            }
        },
        when (rating) {
            1 -> "very_easy"
            2, 3 -> "easy"
            4, 5 -> "moderate"
            6, 7 -> "challenging"
            8, 9 -> "hard"
            10 -> "extremely_hard"
            else -> ""
        }.let { if (it.isEmpty()) "" else it.localized },
        "tap_to_rate_difficulty".localized,
        onChange,
    )
}

@Composable
fun QualityRatingView(rating: Int, onChange: (Int) -> Unit) {
    RatingRow(
        rating, "star.fill", "star",
        { level ->
            when (level) {
                in 1..3 -> Color.SysRed
                in 4..5 -> Color.SysOrange
                in 6..7 -> Color.SysYellow
                in 8..9 -> Color.SysGreen
                10 -> Color.SysBlue
                else -> Color.SysGray
            }
        },
        when (rating) {
            1 -> "poor_quality"
            2, 3 -> "below_average"
            4, 5 -> "average"
            6, 7 -> "good"
            8, 9 -> "excellent"
            10 -> "perfect"
            else -> ""
        }.let { if (it.isEmpty()) "" else it.localized },
        "tap_to_rate_quality".localized,
        onChange,
    )
}

@Composable
private fun InsightsCard(task: TodoTask, completion: TaskCompletion?, isCompleted: Boolean, fixedDate: Date) {
    val theme = theme
    val presenter = LocalPresenter.current
    val hasHistory = task.completions.values.any { it.difficultyRating != null || it.qualityRating != null || it.actualDuration != null }
    DetailCard("chart.line.uptrend.xyaxis", "performance_analytics".localized, Color.SysCyan) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("difficulty_rating".localized, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                    if ((completion?.difficultyRating ?: 0) > 0) {
                        T("clear".localized, Fonts.caption, Color.SysRed, modifier = Modifier.tap { TaskManager.updateTaskRating(task.id, difficultyRating = 0, date = fixedDate) })
                    } else if (!isCompleted) {
                        T("complete_this_task_start_tracking".localized, Fonts.caption.copy(fontStyle = FontStyle.Italic), theme.secondaryTextColor, TextAlign.End, Modifier.weight(1f))
                    }
                }
                DifficultyRatingView(completion?.difficultyRating ?: 0) { TaskManager.updateTaskRating(task.id, difficultyRating = it, date = fixedDate) }
            }
            RowDivider(0.dp)
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("quality_rating".localized, Fonts.subheadline.medium, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                    if ((completion?.qualityRating ?: 0) > 0) {
                        T("clear".localized, Fonts.caption, Color.SysRed, modifier = Modifier.tap { TaskManager.updateTaskRating(task.id, qualityRating = 0, date = fixedDate) })
                    } else if (!isCompleted) {
                        T("complete_this_task_start_tracking".localized, Fonts.caption.copy(fontStyle = FontStyle.Italic), theme.secondaryTextColor, TextAlign.End, Modifier.weight(1f))
                    }
                }
                QualityRatingView(completion?.qualityRating ?: 0) { TaskManager.updateTaskRating(task.id, qualityRating = it, date = fixedDate) }
            }
            if (hasHistory) {
                RowDivider(0.dp)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.SysCyan.copy(alpha = 0.1f))
                        .pressable { presenter.sheet { TaskPerformanceChartView(task) } }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SF("chart.xyaxis.line", Color.SysCyan, 18.dp)
                    T("performance_charts".localized, Fonts.subheadline.medium, Color.SysCyan, modifier = Modifier.weight(1f))
                    SF("arrow.up.right", Color.SysCyan, 14.dp)
                }
            }
        }
    }
}

// MARK: - Performance charts

private enum class TaskPerformanceTimeRange {
    week, month, year, all;

    val displayName: String
        get() = when (this) {
            week -> "week".localized
            month -> "month".localized
            year -> "year".localized
            all -> "all_time".localized
        }

    fun includes(date: Date): Boolean = when (this) {
        week -> date >= now().addingWeeks(-1)
        month -> date >= now().addingMonths(-1)
        year -> date >= now().addingYears(-1)
        all -> true
    }
}

private data class CompletionPoint(val date: Date, val actualDuration: Double?, val difficulty: Int?, val quality: Int?)

@Composable
internal fun TaskPerformanceChartView(task: TodoTask) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var range by remember { mutableStateOf(TaskPerformanceTimeRange.month) }
    val all = remember(task) {
        task.completions.mapNotNull { (date, completion) ->
            if (!completion.isCompleted && completion.difficultyRating == null && completion.qualityRating == null && completion.actualDuration == null) null
            else CompletionPoint(date, completion.actualDuration, completion.difficultyRating, completion.qualityRating)
        }.sortedBy { it.date }
    }
    val filtered = all.filter { range.includes(it.date) }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("performance_charts".localized, trailing = { BarButton("done".localized, color = theme.primaryColor, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Column(Modifier.fillMaxWidth().themedCard().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T("time_range".localized, Fonts.headline)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TaskPerformanceTimeRange.entries.forEach { item ->
                        val selected = range == item
                        Box(
                            Modifier
                                .weight(1f)
                                .defaultMinSize(minHeight = 28.dp)
                                .clip(RoundedCornerShape(6.dp))
                                .background(if (selected) theme.primaryColor.copy(alpha = 0.15f) else theme.surfaceColor)
                                .border(1.dp, if (selected) theme.primaryColor else Color.Transparent, RoundedCornerShape(6.dp))
                                .tap { range = item }
                                .padding(horizontal = 4.dp, vertical = 6.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            T(item.displayName, Fonts.caption.weight(if (selected) FontWeight.SemiBold else FontWeight.Medium), if (selected) theme.primaryColor else theme.textColor, TextAlign.Center)
                        }
                    }
                }
            }
            if (all.isEmpty()) {
                PerformanceCard(Modifier.padding(0.dp)) {
                    Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        SF("chart.line.uptrend.xyaxis", Color.Secondary, 64.dp)
                        T("no_completion_data".localized, Fonts.title2.bold)
                        T("complete_recurring_tasks_performance".localized, Fonts.subheadline, Color.Secondary, TextAlign.Center)
                    }
                }
            } else if (filtered.isEmpty()) {
                PerformanceCard {
                    Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        SF("calendar.badge.exclamationmark", Color.SysOrange, 48.dp)
                        T("no_data".localized, Fonts.title3.bold)
                        T("task_no_performance_data_period".localized, Fonts.subheadline, Color.Secondary, TextAlign.Center)
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            T("available_data".localized, Fonts.caption, Color.Secondary)
                            T("completions_since_format".localized(all.size, all.first().date.skeleton("MMMdyyyy")), Fonts.caption.bold, Color.SysBlue)
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            T(
                                "try_all_time".localized, Fonts.subheadline.medium, Color.White,
                                modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color.SysBlue).tap { range = TaskPerformanceTimeRange.all }.padding(horizontal = 16.dp, vertical = 10.dp),
                            )
                            T(
                                "try_year".localized, Fonts.subheadline.medium, Color.SysBlue,
                                modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color.SysBlue.copy(alpha = 0.1f)).border(1.dp, Color.SysBlue, RoundedCornerShape(8.dp)).tap { range = TaskPerformanceTimeRange.year }.padding(horizontal = 16.dp, vertical = 10.dp),
                            )
                        }
                    }
                }
            } else {
                // Task header with averages
                PerformanceCard {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            task.category?.let { Box(Modifier.size(width = 6.dp, height = 50.dp).clip(RoundedCornerShape(6.dp)).background(colorFromHex(it.color))) }
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                T(task.name, Fonts.title2.bold)
                                task.category?.let { T(it.name, Fonts.subheadline, theme.secondaryTextColor) }
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            MetricCard("Completions", "${filtered.size}", Color.SysBlue, "checkmark.circle.fill", Modifier.weight(1f))
                            val quality = filtered.mapNotNull { it.quality }
                            if (quality.isNotEmpty()) MetricCard("Quality", "%.1f".format(quality.average()), Color.SysYellow, "star.fill", Modifier.weight(1f))
                            val difficulty = filtered.mapNotNull { it.difficulty }
                            if (difficulty.isNotEmpty()) MetricCard("Difficulty", "%.1f".format(difficulty.average()), Color.SysOrange, "bolt.fill", Modifier.weight(1f))
                            val durations = filtered.mapNotNull { it.actualDuration }
                            if (durations.isNotEmpty()) MetricCard("Time", formatMemoDuration(durations.average()), Color.SysGreen, "clock.fill", Modifier.weight(1f))
                        }
                    }
                }
                val lineColor = task.category?.let { colorFromHex(it.color) } ?: Color(0xFF6366F1)
                val qualityPoints = filtered.filter { it.quality != null }
                if (qualityPoints.isNotEmpty()) RatingChart("star.fill", Color.SysYellow, "quality_trend".localized, "quality_rating".localized, qualityPoints.map { it.date to it.quality!! }, lineColor, range)
                val difficultyPoints = filtered.filter { it.difficulty != null }
                if (difficultyPoints.isNotEmpty()) RatingChart("bolt.fill", Color.SysOrange, "difficulty_trend".localized, "difficulty_rating".localized, difficultyPoints.map { it.date to it.difficulty!! }, lineColor, range)

                PerformanceCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SF("list.bullet", Color.SysBlue, 18.dp)
                            T("completions_period".localized(range.displayName), Fonts.headline)
                        }
                        filtered.sortedByDescending { it.date }.forEach { point ->
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(theme.surfaceColor)
                                    .border(1.dp, theme.borderColor.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                SF("checkmark.circle.fill", Color.SysGreen, 20.dp)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    T(point.date.skeleton("dMMMyyyy"), Fonts.subheadline.medium)
                                    T(point.date.timeText(), Fonts.caption, theme.secondaryTextColor)
                                }
                                point.quality?.let {
                                    SF("star.fill", Color.SysYellow, 14.dp)
                                    T("$it", Fonts.subheadline.semibold, Color.SysYellow)
                                }
                                point.difficulty?.let {
                                    SF("bolt.fill", Color.SysOrange, 14.dp)
                                    T("$it", Fonts.subheadline.semibold, Color.SysOrange)
                                }
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.navigationBarsPadding())
        }
    }
}

@Composable
private fun PerformanceCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val theme = theme
    Box(
        modifier
            .fillMaxWidth()
            .shadow(8.dp, RoundedCornerShape(16.dp), clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(RoundedCornerShape(16.dp))
            .background(theme.surfaceColor)
            .padding(20.dp)
    ) { content() }
}

@Composable
private fun MetricCard(title: String, value: String, color: Color, icon: String, modifier: Modifier) {
    val theme = theme
    Column(
        modifier
            .height(90.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(theme.backgroundColor)
            .border(1.dp, color.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
            .padding(horizontal = 4.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        SF(icon, color, 22.dp)
        FitText(listOf(value), listOf(20, 17, 14, 12), theme.textColor)
        T(title, Fonts.caption2, theme.secondaryTextColor, TextAlign.Center, maxLines = 1)
    }
}

@Composable
private fun RatingChart(icon: String, tint: Color, title: String, axisTitle: String, values: List<Pair<Date, Int>>, line: Color, range: TaskPerformanceTimeRange) {
    fun label(date: Date) = when (range) {
        TaskPerformanceTimeRange.week -> date.format("E dd")
        TaskPerformanceTimeRange.month -> date.format("dd MMM")
        TaskPerformanceTimeRange.year -> date.format("MMM yyyy")
        TaskPerformanceTimeRange.all -> {
            val days = daysBetween(date, now())
            when {
                days <= 30 -> date.format("dd MMM")
                days <= 365 -> date.format("MMM yyyy")
                else -> date.format("yyyy")
            }
        }
    }
    PerformanceCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SF(icon, tint, 18.dp)
                T(title, Fonts.headline)
            }
            T(axisTitle, Fonts.caption2, Color.Secondary)
            val points = values.map { ChartPoint(it.first.epochSeconds.toFloat(), it.second.toFloat()) }
            val labels = values.map { it.first }.let { dates ->
                val step = (dates.size / 4).coerceAtLeast(1)
                dates.filterIndexed { index, _ -> index % step == 0 }.map { it.epochSeconds.toFloat() to label(it) }
            }
            LineChart(listOf(points to line), Modifier.fillMaxWidth().height(200.dp), yMin = 0f, yMax = 10f, showPoints = points.size == 1, xLabels = labels)
            T("date".localized, Fonts.caption2, Color.Secondary, TextAlign.Center, Modifier.fillMaxWidth())
        }
    }
}

// MARK: - Location

object MapSupport {
    private var configured = false
    fun configure() {
        if (configured) return
        configured = true
        Configuration.getInstance().userAgentValue = App.context.packageName
        Configuration.getInstance().osmdroidBasePath = File(App.context.cacheDir, "osmdroid")
        Configuration.getInstance().osmdroidTileCache = File(App.context.cacheDir, "osmdroid/tiles")
    }
}

/** The map of a location, with its pin. */
@Composable
fun LocationMapView(location: TaskLocation, height: Dp = 150.dp, allowsInteraction: Boolean = true) {
    var geocoded by remember(location.id, location.name) { mutableStateOf<Coordinate?>(null) }
    var isGeocoding by remember(location.id, location.name) { mutableStateOf(false) }
    val coordinate = location.coordinate ?: geocoded
    LaunchedEffect(location.id, location.name, location.address) {
        if (location.coordinate == null) {
            isGeocoding = true
            geocoded = LocationSearch.search(if (!location.address.isNullOrEmpty()) "${location.name}, ${location.address}" else location.name).firstOrNull()?.coordinate
            isGeocoding = false
        }
    }
    val pin = Color.SysPink
    Column {
        if (coordinate != null) {
            AndroidView(
                factory = { context ->
                    MapSupport.configure()
                    MapView(context).apply {
                        setTileSource(TileSourceFactory.MAPNIK)
                        setMultiTouchControls(allowsInteraction)
                        setOnTouchListener { view, _ ->
                            view.parent?.requestDisallowInterceptTouchEvent(allowsInteraction)
                            !allowsInteraction
                        }
                        zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
                    }
                },
                update = { map ->
                    val point = GeoPoint(coordinate.latitude, coordinate.longitude)
                    map.controller.setZoom(16.0)
                    map.controller.setCenter(point)
                    map.overlays.clear()
                    map.overlays.add(Marker(map).apply {
                        position = point
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                        setOnMarkerClickListener { _, _ -> true }
                    })
                    map.invalidate()
                },
                modifier = Modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(12.dp)),
            )
        } else {
            Box(
                Modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(12.dp)).background(Color.SysGray.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (isGeocoding) {
                        androidx.compose.material3.CircularProgressIndicator(Modifier.size(20.dp), Color.Secondary, 2.dp)
                        T("loading_map".localized, Fonts.caption, Color.Secondary)
                    } else {
                        SF("location.slash", Color.Secondary, 26.dp)
                        T("no_coordinates_available".localized, Fonts.caption, Color.Secondary)
                    }
                }
            }
        }
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(location.name, Fonts.subheadline.medium, Color.Primary)
            if (!location.address.isNullOrEmpty()) T(location.address, Fonts.caption, Color.Secondary)
        }
    }
}

object LocationSearch {
    /** The system's geocoder in place of `MKLocalSearch`. */
    suspend fun search(query: String): List<TaskLocation> = withContext(Dispatchers.IO) {
        runCatching {
            @Suppress("DEPRECATION")
            android.location.Geocoder(App.context, appLocale).getFromLocationName(query, 15).orEmpty().map { address ->
                val parts = listOfNotNull(address.thoroughfare, address.locality, address.adminArea, address.countryName)
                TaskLocation(
                    name = address.featureName?.takeIf { it.isNotBlank() && it != address.subThoroughfare } ?: address.getAddressLine(0) ?: query,
                    address = parts.joinToString(", ").ifEmpty { address.getAddressLine(0) },
                    coordinate = Coordinate(address.latitude, address.longitude),
                    placemark = TaskPlacemark(address.featureName, address.thoroughfare, address.locality, address.adminArea, address.countryName, address.postalCode),
                )
            }
        }.getOrDefault(emptyList())
    }
}

@Composable
fun LocationPickerView(selected: TaskLocation?, onSelect: (TaskLocation?) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var searchText by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<TaskLocation>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    var current by remember { mutableStateOf(selected) }
    LaunchedEffect(searchText) {
        if (searchText.isEmpty()) {
            results = emptyList()
            isSearching = false
            return@LaunchedEffect
        }
        isSearching = true
        kotlinx.coroutines.delay(500)
        results = LocationSearch.search(searchText)
        isSearching = false
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("select_location".localized, trailing = { BarButton("cancel".localized, color = Color.SysRed, onClick = dismiss) })
        Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("search_location".localized, Fonts.headline, modifier = Modifier.padding(horizontal = 16.dp))
            Row(
                Modifier
                    .padding(horizontal = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(theme.backgroundColor)
                    .border(1.dp, theme.borderColor, RoundedCornerShape(10.dp))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SF("magnifyingglass", theme.secondaryTextColor, 20.dp)
                PlainField(searchText, { searchText = it }, "search_for_a_place".localized, modifier = Modifier.weight(1f))
                if (searchText.isNotEmpty()) Box(Modifier.tap { searchText = "" }) { SF("xmark.circle.fill", theme.secondaryTextColor, 20.dp) }
            }
        }
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                isSearching -> Row(Modifier.padding(start = 16.dp, top = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    androidx.compose.material3.CircularProgressIndicator(Modifier.size(16.dp), theme.primaryColor, 2.dp)
                    T("searching".localized, Fonts.subheadline, theme.secondaryTextColor)
                }
                results.isNotEmpty() -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    results.forEach { location ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .shadow(2.dp, RoundedCornerShape(12.dp), clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                                .clip(RoundedCornerShape(12.dp))
                                .background(theme.surfaceColor)
                                .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                                .tap {
                                    current = location
                                    onSelect(location)
                                    searchText = ""
                                }
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                T(location.name, Fonts.headline)
                                location.address?.let { T(it, Fonts.subheadline, theme.secondaryTextColor) }
                            }
                            SF("chevron.right", theme.secondaryTextColor, 16.dp)
                        }
                    }
                }
                searchText.isNotEmpty() -> T("no_results_found".localized, Fonts.subheadline, theme.secondaryTextColor, modifier = Modifier.padding(start = 16.dp, top = 12.dp))
                current != null -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    T("selected_location".localized, Fonts.headline)
                    LocationMapView(current!!, 180.dp, allowsInteraction = false)
                }
            }
        }
        if (current != null) {
            Row(
                Modifier
                    .navigationBarsPadding()
                    .padding(16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.SysRed.copy(alpha = 0.1f))
                    .pressable {
                        current = null
                        onSelect(null)
                    }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SF("trash", Color.SysRed, 20.dp)
                T("remove_location".localized, Fonts.headline, Color.SysRed)
            }
        }
    }
}
