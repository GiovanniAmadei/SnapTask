package com.snaptask.app.ui.timeline

import android.Manifest
import android.content.Context
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.ui.window.Dialog
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.snaptask.app.R
import com.snaptask.app.data.model.*
import com.snaptask.app.data.repository.AttachmentService
import com.snaptask.app.ui.components.parseHexColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.io.File
import java.util.*
import kotlin.math.abs

/**
 * Faithful port of iOS TaskDetailView.swift.
 * Shows header (icon, name, category, priority, completion status)
 * plus detail cards and action buttons.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskDetailScreen(
    task: TodoTask,
    isCompleted: Boolean,
    onToggleCompletion: () -> Unit,
    onUpdateTask: (TodoTask) -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onStartPomodoro: (() -> Unit)? = null,
    onShowTrackingMode: (() -> Unit)? = null,
    onOpenPerformance: ((TodoTask) -> Unit)? = null,
    onDismiss: () -> Unit,
) {
    val dateFormat = remember { SimpleDateFormat("MMM d, yyyy", Locale.getDefault()) }
    val timeFormat = remember { SimpleDateFormat("h:mm a", Locale.getDefault()) }
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val attachmentService = remember { AttachmentService(ctx) }
    val voiceRecorder = remember { VoiceMemoRecorder(ctx) }

    var fullScreenPhoto by remember { mutableStateOf<TaskPhoto?>(null) }
    var showPhotoSourceDialog by remember { mutableStateOf(false) }
    var showPhotoLimitAlert by remember { mutableStateOf(false) }
    var showVoiceMemoLimitAlert by remember { mutableStateOf(false) }
    var showMicDeniedAlert by remember { mutableStateOf(false) }
    var showMaxDurationReachedAlert by remember { mutableStateOf(false) }

    var isRecordingVoice by remember { mutableStateOf(false) }
    var recordingSeconds by remember { mutableDoubleStateOf(0.0) }
    var isRenamingMemo by remember { mutableStateOf<TaskVoiceMemo?>(null) }
    var renameText by remember { mutableStateOf("") }

    // ---- Photo pickers ----
    val pickPhotosLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = MediaLimits.maxPhotosPerTask),
    ) { uris: List<Uri> ->
        if (uris.isEmpty()) return@rememberLauncherForActivityResult
        val remaining = MediaLimits.remainingPhotos(task.photos.size)
        val toProcess = uris.take(remaining)
        if (uris.size > toProcess.size) showPhotoLimitAlert = true

        scope.launch(Dispatchers.IO) {
            var updated = task
            toProcess.forEach { uri ->
                if (!MediaLimits.canAddPhoto(updated.photos.size)) return@forEach
                val bytes = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                if (bytes != null) {
                    val added = attachmentService.addPhoto(updated.id, bytes)
                    if (added != null) {
                        updated = updated.copy(
                            photos = updated.photos + added,
                            lastModifiedDate = Date(),
                            photoPath = updated.photoPath,
                            photoThumbnailPath = updated.photoThumbnailPath,
                        )
                        if (updated.photoPath == null) {
                            val legacy = attachmentService.savePhoto(updated.id, bytes)
                            if (legacy != null) {
                                updated = updated.copy(photoPath = legacy.first, photoThumbnailPath = legacy.second)
                            }
                        }
                    }
                }
            }
            launch(Dispatchers.Main) { onUpdateTask(updated) }
        }
    }

    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }
    val takePictureLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val uri = pendingCameraUri
        pendingCameraUri = null
        if (!ok || uri == null) return@rememberLauncherForActivityResult

        scope.launch(Dispatchers.IO) {
            val bytes = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes != null) {
                if (!MediaLimits.canAddPhoto(task.photos.size)) {
                    launch(Dispatchers.Main) { showPhotoLimitAlert = true }
                    return@launch
                }
                val added = attachmentService.addPhoto(task.id, bytes)
                if (added != null) {
                    var updated = task.copy(photos = task.photos + added, lastModifiedDate = Date())
                    if (updated.photoPath == null) {
                        val legacy = attachmentService.savePhoto(updated.id, bytes)
                        if (legacy != null) updated = updated.copy(photoPath = legacy.first, photoThumbnailPath = legacy.second)
                    }
                    launch(Dispatchers.Main) { onUpdateTask(updated) }
                }
            }
        }
    }

    // ---- Permissions ----
    val requestMicPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted) showMicDeniedAlert = true
    }
    val requestCameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            startCameraCapture(ctx) { uri ->
                pendingCameraUri = uri
                takePictureLauncher.launch(uri)
            }
        }
    }

    LaunchedEffect(isRecordingVoice) {
        if (!isRecordingVoice) return@LaunchedEffect
        while (isRecordingVoice) {
            recordingSeconds = voiceRecorder.currentDurationSeconds()
            if (recordingSeconds >= MediaLimits.maxVoiceMemoDurationSeconds) {
                val memo = voiceRecorder.stop()
                isRecordingVoice = false
                if (memo != null) {
                    val updated = task.copy(
                        voiceMemos = listOf(memo) + task.voiceMemos,
                        lastModifiedDate = Date(),
                    )
                    onUpdateTask(updated)
                    showMaxDurationReachedAlert = true
                }
                break
            }
            delay(250)
        }
    }

    val leadTimeExact = stringResource(R.string.notification_lead_exact)
    val recurrenceDaily = stringResource(R.string.recurrence_daily)
    val recurrenceYearly = stringResource(R.string.recurrence_yearly)
    val recurrenceMonthlyPatterns = stringResource(R.string.recurrence_monthly_patterns)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.task_details)) },
                navigationIcon = {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.action_close), color = MaterialTheme.colorScheme.primary)
                    }
                },
            )
        },
    ) { padding ->
        Box(
            Modifier.fillMaxSize().padding(padding)
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 120.dp),
            ) {
                // ============ HEADER SECTION ============
                HeaderSection(task, isCompleted)

                Spacer(Modifier.height(16.dp))

                // ============ DETAILS SECTION ============
                Column(
                    Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    // Description card
                    if (!task.description.isNullOrBlank()) {
                        DetailCard(icon = Icons.Default.Description, title = stringResource(R.string.task_detail_description), color = Color(0xFF2196F3)) {
                            Text(
                                task.description!!,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }

                    // Schedule card
                    DetailCard(icon = Icons.Default.Schedule, title = stringResource(R.string.task_detail_time), color = Color(0xFFFF9800)) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            DetailRow(label = stringResource(R.string.task_detail_time_range), value = task.timeScope.displayName)

                            if (task.hasSpecificDay) {
                                DetailRow(label = stringResource(R.string.task_detail_date), value = dateFormat.format(task.startTime))
                            }

                            if (task.hasSpecificTime) {
                                DetailRow(label = stringResource(R.string.task_detail_start_time), value = timeFormat.format(task.startTime))
                            }

                            DetailRow(
                                label = stringResource(R.string.task_detail_notifications),
                                value = if (task.hasNotification) stringResource(R.string.task_detail_notifications_enabled) else stringResource(R.string.task_detail_notifications_disabled),
                                valueColor = if (task.hasNotification) Color(0xFF2196F3) else null,
                            )

                            if (task.hasNotification && task.hasSpecificTime) {
                                DetailRow(
                                    label = stringResource(R.string.task_detail_lead_time),
                                    value = leadTimeLabel(task.notificationLeadTimeMinutes, leadTimeExact, ctx.getString(R.string.notification_lead_min_before)),
                                )
                            }

                            // Duration
                            if (task.hasDuration) {
                                DetailRow(
                                    label = stringResource(R.string.task_detail_duration),
                                    value = formatDuration(task.duration),
                                    valueColor = Color(0xFF2196F3),
                                )
                            } else {
                                DetailRow(label = stringResource(R.string.task_detail_duration), value = stringResource(R.string.task_detail_duration_none))
                            }
                        }
                    }

                    // Recurrence card
                    task.recurrence?.let { recurrence ->
                        DetailCard(icon = Icons.Default.Repeat, title = stringResource(R.string.task_detail_recurrence), color = Color(0xFF9C27B0)) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                DetailRow(label = stringResource(R.string.task_detail_pattern), value = recurrenceDescription(recurrence, recurrenceDaily, ctx.getString(R.string.recurrence_weekly), recurrenceMonthlyPatterns, recurrenceYearly))

                                recurrence.endDate?.let { endDate ->
                                    DetailRow(label = stringResource(R.string.task_detail_end_date), value = dateFormat.format(endDate))
                                }

                                Row(
                                    Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(stringResource(R.string.task_detail_current_streak), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Spacer(Modifier.weight(1f))
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                        Icon(Icons.Default.LocalFireDepartment, null, Modifier.size(14.dp), tint = Color(0xFFFF9800))
                                        Text("${task.currentStreak}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = Color(0xFFFF9800))
                                    }
                                }
                            }
                        }
                    }

                    // Subtasks card
                    if (task.subtasks.isNotEmpty()) {
                        val completionKey = Recurrence.startOfDay(Date()).time
                        val completedSubtasks = task.completions[completionKey]?.completedSubtasks ?: emptySet()
                        DetailCard(icon = Icons.Default.Checklist, title = stringResource(R.string.task_detail_subtasks), color = Color(0xFF3F51B5)) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                task.subtasks.forEach { subtask ->
                                    val subCompleted = subtask.id in completedSubtasks
                                    Row(
                                        Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Icon(
                                            if (subCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                                            null, Modifier.size(18.dp),
                                            tint = if (subCompleted) Color(0xFF4CAF50) else MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                        Spacer(Modifier.width(8.dp))
                                        Text(
                                            subtask.name,
                                            style = MaterialTheme.typography.bodyMedium,
                                            textDecoration = if (subCompleted) TextDecoration.LineThrough else TextDecoration.None,
                                            color = if (subCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Pomodoro card
                    task.pomodoroSettings?.let { pomo ->
                        val minUnit = stringResource(R.string.min_unit)
                        DetailCard(icon = Icons.Default.Timer, title = stringResource(R.string.task_detail_pomodoro), color = Color(0xFFF44336)) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                DetailRow(label = stringResource(R.string.task_detail_work_duration), value = "${(pomo.workDuration / 60).toInt()} $minUnit")
                                DetailRow(label = stringResource(R.string.task_detail_break_time), value = "${(pomo.breakDuration / 60).toInt()} $minUnit")
                                // Start Pomodoro button
                                Button(
                                    onClick = { onStartPomodoro?.invoke() ?: Unit },
                                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                                    shape = RoundedCornerShape(10.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF44336)),
                                ) {
                                    Icon(Icons.Default.PlayArrow, null, Modifier.size(16.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text(stringResource(R.string.task_detail_start_pomodoro), fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }

                    // Rewards card
                    if (task.hasRewardPoints) {
                        DetailCard(icon = Icons.Default.Star, title = stringResource(R.string.task_detail_rewards), color = Color(0xFFFFEB3B)) {
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column {
                                    Text(stringResource(R.string.task_detail_available_points), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Text("${task.rewardPoints} ${stringResource(R.string.task_detail_points)}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Color(0xFFFFEB3B))
                                }
                                Spacer(Modifier.weight(1f))
                                Icon(Icons.Default.Star, null, Modifier.size(28.dp), tint = Color(0xFFFFEB3B))
                            }
                        }
                    }

                    // Performance Analytics card (iOS postCompletionInsightsCard parity)
                    PostCompletionInsightsCard(
                        task = task,
                        isCompleted = isCompleted,
                        onUpdateTask = onUpdateTask,
                        onOpenPerformance = onOpenPerformance,
                    )

                    // Notes card (iOS notesCard parity)
                    NotesCard(task = task, onUpdateTask = onUpdateTask)

                    // Photos card (iOS parity)
                    DetailCard(
                        icon = Icons.Default.Photo,
                        title = stringResource(R.string.task_detail_photos),
                        color = Color(0xFF2196F3),
                    ) {
                        PhotoCardContent(
                            task = task,
                            attachmentService = attachmentService,
                            onUpdateTask = onUpdateTask,
                            onOpenSourceDialog = { showPhotoSourceDialog = true },
                            onOpenFullScreen = { fullScreenPhoto = it },
                        )
                    }

                    // Voice memos card (iOS parity)
                    DetailCard(
                        icon = Icons.Default.GraphicEq,
                        title = stringResource(R.string.task_detail_voice_memos),
                        color = Color(0xFFE91E63),
                    ) {
                        VoiceMemosCardContent(
                            task = task,
                            voiceRecorder = voiceRecorder,
                            isRecording = isRecordingVoice,
                            recordingSeconds = recordingSeconds,
                            onToggleRecording = {
                                if (!MediaLimits.canAddVoiceMemo(task.voiceMemos.size) && !isRecordingVoice) {
                                    showVoiceMemoLimitAlert = true
                                    return@VoiceMemosCardContent
                                }
                                if (isRecordingVoice) {
                                    val memo = voiceRecorder.stop()
                                    isRecordingVoice = false
                                    recordingSeconds = 0.0
                                    if (memo != null) {
                                        onUpdateTask(task.copy(voiceMemos = listOf(memo) + task.voiceMemos, lastModifiedDate = Date()))
                                    }
                                } else {
                                    if (!voiceRecorder.hasMicPermission()) {
                                        requestMicPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                        return@VoiceMemosCardContent
                                    }
                                    val started = try {
                                        voiceRecorder.start(task.id)
                                    } catch (_: Exception) {
                                        false
                                    }
                                    if (started) {
                                        isRecordingVoice = true
                                    }
                                }
                            },
                            onDeleteMemo = { memo ->
                                voiceRecorder.deleteMemo(memo)
                                onUpdateTask(task.copy(voiceMemos = task.voiceMemos.filterNot { it.id == memo.id }, lastModifiedDate = Date()))
                            },
                            onRenameMemo = { memo ->
                                isRenamingMemo = memo
                                renameText = memo.name ?: ""
                            },
                        )
                    }
                }
            }

            // ============ ACTION BUTTONS ============
            Column(
                Modifier.align(Alignment.BottomCenter),
            ) {
                // Gradient fade
                Box(
                    Modifier.fillMaxWidth().height(30.dp)
                        .background(Brush.verticalGradient(
                            listOf(Color.Transparent, MaterialTheme.colorScheme.background),
                        ))
                )
                Row(
                    Modifier.fillMaxWidth()
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 16.dp, top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    // Track button
                    Button(
                        onClick = { onShowTrackingMode?.invoke() ?: Unit },
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFEB3B)),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp),
                    ) {
                        Icon(Icons.Default.PlayArrow, null, Modifier.size(16.dp), tint = Color.Black)
                        Spacer(Modifier.width(4.dp))
                        Text(stringResource(R.string.task_detail_track), color = Color.Black, fontWeight = FontWeight.SemiBold)
                    }
                    // Edit button
                    Button(
                        onClick = onEdit,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp),
                    ) {
                        Icon(Icons.Default.Edit, null, Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(stringResource(R.string.action_edit), fontWeight = FontWeight.SemiBold)
                    }
                    // Complete/Incomplete button
                    Button(
                        onClick = onToggleCompletion,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isCompleted) Color(0xFFFF9800) else Color(0xFF4CAF50),
                        ),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 4.dp),
                    ) {
                        Icon(
                            if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                            null, Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(4.dp))
                        Text(
                            if (isCompleted) stringResource(R.string.task_detail_undo) else stringResource(R.string.task_detail_done),
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }

    if (showPhotoSourceDialog) {
        val canAddMore = MediaLimits.canAddPhoto(task.photos.size)
        if (!canAddMore) {
            showPhotoSourceDialog = false
            showPhotoLimitAlert = true
        } else {
            AlertDialog(
                onDismissRequest = { showPhotoSourceDialog = false },
                title = { Text(stringResource(R.string.task_detail_add_photos)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        TextButton(
                            onClick = {
                                showPhotoSourceDialog = false
                                val granted = androidx.core.content.ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == android.content.pm.PackageManager.PERMISSION_GRANTED
                                if (granted) {
                                    startCameraCapture(ctx) { uri ->
                                        pendingCameraUri = uri
                                        takePictureLauncher.launch(uri)
                                    }
                                } else {
                                    requestCameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                                }
                            },
                        ) { Text(stringResource(R.string.task_detail_take_photo)) }
                        TextButton(
                            onClick = {
                                showPhotoSourceDialog = false
                                pickPhotosLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                            },
                        ) { Text(stringResource(R.string.task_detail_choose_photos)) }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showPhotoSourceDialog = false }) {
                        Text(stringResource(R.string.action_cancel))
                    }
                },
            )
        }
    }

    fullScreenPhoto?.let { photo ->
        Dialog(onDismissRequest = { fullScreenPhoto = null }) {
            Surface(shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surface) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        IconButton(onClick = { fullScreenPhoto = null }) {
                            Icon(Icons.Default.Close, contentDescription = stringResource(R.string.action_close))
                        }
                    }
                    val bmp = remember(photo.photoPath) { attachmentService.loadImage(photo.photoPath) }
                    if (bmp != null) {
                        androidx.compose.foundation.Image(
                            bitmap = bmp.asImageBitmap(),
                            contentDescription = null,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 240.dp, max = 520.dp),
                        )
                    }
                }
            }
        }
    }

    if (showPhotoLimitAlert) {
        AlertDialog(
            onDismissRequest = { showPhotoLimitAlert = false },
            title = { Text(stringResource(R.string.task_detail_photo_limit_title)) },
            text = { Text(stringResource(R.string.task_detail_photo_limit_message, MediaLimits.maxPhotosPerTask)) },
            confirmButton = {
                TextButton(onClick = { showPhotoLimitAlert = false }) { Text(stringResource(R.string.action_close)) }
            },
        )
    }

    if (showVoiceMemoLimitAlert) {
        AlertDialog(
            onDismissRequest = { showVoiceMemoLimitAlert = false },
            title = { Text(stringResource(R.string.task_detail_voice_memo_limit_title)) },
            text = { Text(stringResource(R.string.task_detail_voice_memo_limit_message, MediaLimits.maxVoiceMemosPerTask)) },
            confirmButton = {
                TextButton(onClick = { showVoiceMemoLimitAlert = false }) { Text(stringResource(R.string.action_close)) }
            },
        )
    }

    if (showMicDeniedAlert) {
        AlertDialog(
            onDismissRequest = { showMicDeniedAlert = false },
            title = { Text(stringResource(R.string.task_detail_microphone_denied_title)) },
            text = { Text(stringResource(R.string.task_detail_microphone_denied_message)) },
            confirmButton = {
                TextButton(onClick = { showMicDeniedAlert = false }) { Text(stringResource(R.string.action_close)) }
            },
        )
    }

    if (showMaxDurationReachedAlert) {
        AlertDialog(
            onDismissRequest = { showMaxDurationReachedAlert = false },
            title = { Text(stringResource(R.string.task_detail_max_duration_title)) },
            text = {
                Text(stringResource(R.string.task_detail_max_duration_message, (MediaLimits.maxVoiceMemoDurationSeconds / 60.0).toInt()))
            },
            confirmButton = {
                TextButton(onClick = { showMaxDurationReachedAlert = false }) { Text(stringResource(R.string.action_close)) }
            },
        )
    }

    isRenamingMemo?.let { memo ->
        AlertDialog(
            onDismissRequest = { isRenamingMemo = null },
            title = { Text(stringResource(R.string.task_detail_rename)) },
            text = {
                OutlinedTextField(
                    value = renameText,
                    onValueChange = { renameText = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val renamed = memo.copy(name = renameText.ifBlank { null })
                        val updatedMemos = task.voiceMemos.map { if (it.id == memo.id) renamed else it }
                        onUpdateTask(task.copy(voiceMemos = updatedMemos, lastModifiedDate = Date()))
                        isRenamingMemo = null
                    },
                ) { Text(stringResource(R.string.action_save)) }
            },
            dismissButton = {
                TextButton(onClick = { isRenamingMemo = null }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }
}

@Composable
private fun PhotoCardContent(
    task: TodoTask,
    attachmentService: AttachmentService,
    onUpdateTask: (TodoTask) -> Unit,
    onOpenSourceDialog: () -> Unit,
    onOpenFullScreen: (TaskPhoto) -> Unit,
) {
    val canAddMore = MediaLimits.canAddPhoto(task.photos.size)
    val remaining = MediaLimits.remainingPhotos(task.photos.size)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (task.photos.isNotEmpty()) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "${task.photos.size}/${MediaLimits.maxPhotosPerTask}",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (canAddMore) MaterialTheme.colorScheme.onSurfaceVariant else Color(0xFFF97316),
                )
                Spacer(Modifier.weight(1f))
            }
        }

        if (task.photos.isNotEmpty()) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.heightIn(min = 90.dp, max = 220.dp),
            ) {
                items(task.photos, key = { it.id }) { photo ->
                    Box(
                        modifier = Modifier
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
                            .clickable { onOpenFullScreen(photo) },
                    ) {
                        val bmp = remember(photo.thumbnailPath) { attachmentService.loadImage(photo.thumbnailPath) }
                        if (bmp != null) {
                            androidx.compose.foundation.Image(
                                bitmap = bmp.asImageBitmap(),
                                contentDescription = null,
                                modifier = Modifier.fillMaxSize(),
                            )
                        }
                        IconButton(
                            onClick = {
                                attachmentService.deletePhoto(task.id, photo)
                                val updated = task.copy(
                                    photos = task.photos.filterNot { it.id == photo.id },
                                    lastModifiedDate = Date(),
                                )
                                onUpdateTask(updated)
                            },
                            modifier = Modifier.align(Alignment.TopEnd).size(32.dp),
                        ) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = stringResource(R.string.action_delete),
                                tint = Color(0xFFEF4444),
                            )
                        }
                    }
                }
            }

            if (canAddMore) {
                TextButton(onClick = onOpenSourceDialog) {
                    Icon(Icons.Default.AddCircle, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.task_detail_add_photos_remaining, remaining))
                }
            }
        } else if (task.photoThumbnailPath != null) {
            val bmp = remember(task.photoThumbnailPath) { attachmentService.loadImage(task.photoThumbnailPath) }
            if (bmp != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.foundation.Image(
                        bitmap = bmp.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier.size(90.dp).clip(RoundedCornerShape(10.dp)),
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = onOpenSourceDialog) {
                            Icon(Icons.Default.Edit, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.task_detail_change_photo))
                        }
                        TextButton(
                            onClick = {
                                attachmentService.deleteAllPhotos(task.id)
                                onUpdateTask(task.copy(photoPath = null, photoThumbnailPath = null, photos = emptyList(), lastModifiedDate = Date()))
                            },
                        ) {
                            Icon(Icons.Default.Delete, contentDescription = null, tint = Color(0xFFEF4444))
                            Spacer(Modifier.width(8.dp))
                            Text(stringResource(R.string.task_detail_remove_photo), color = Color(0xFFEF4444))
                        }
                    }
                }
            } else {
                TextButton(onClick = onOpenSourceDialog) {
                    Icon(Icons.Default.AddCircle, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.task_detail_add_photos))
                }
            }
        } else {
            TextButton(onClick = onOpenSourceDialog) {
                Icon(Icons.Default.AddCircle, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.task_detail_add_photos))
            }
        }
    }
}

@Composable
private fun VoiceMemosCardContent(
    task: TodoTask,
    voiceRecorder: VoiceMemoRecorder,
    isRecording: Boolean,
    recordingSeconds: Double,
    onToggleRecording: () -> Unit,
    onDeleteMemo: (TaskVoiceMemo) -> Unit,
    onRenameMemo: (TaskVoiceMemo) -> Unit,
) {
    val canAddMore = MediaLimits.canAddVoiceMemo(task.voiceMemos.size)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (task.voiceMemos.isNotEmpty()) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "${task.voiceMemos.size}/${MediaLimits.maxVoiceMemosPerTask}",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (canAddMore) MaterialTheme.colorScheme.onSurfaceVariant else Color(0xFFF97316),
                )
                Spacer(Modifier.weight(1f))
                Text(
                    text = stringResource(
                        R.string.task_detail_max_duration_info,
                        (MediaLimits.maxVoiceMemoDurationSeconds / 60.0).toInt(),
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            if (canAddMore || isRecording) {
                Button(
                    onClick = onToggleRecording,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isRecording) Color(0xFFF97316) else Color(0xFFEF4444),
                    ),
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Icon(
                        if (isRecording) Icons.Default.StopCircle else Icons.Default.FiberManualRecord,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = stringResource(if (isRecording) R.string.task_detail_stop else R.string.task_detail_record),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            } else {
                Text(
                    text = stringResource(R.string.task_detail_voice_memo_limit_message, MediaLimits.maxVoiceMemosPerTask),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFFF97316),
                )
            }
            Spacer(Modifier.weight(1f))
        }

        AnimatedVisibility(visible = isRecording) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = stringResource(R.string.task_detail_recording),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFFF97316),
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        text = formatRecordingDuration(recordingSeconds),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (recordingSeconds > MediaLimits.maxVoiceMemoDurationSeconds * 0.8) Color(0xFFEF4444)
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "/ ${formatRecordingDuration(MediaLimits.maxVoiceMemoDurationSeconds)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        if (task.voiceMemos.isEmpty() && !isRecording) {
            if (canAddMore) {
                Text(
                    text = stringResource(R.string.task_detail_no_voice_memos),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else if (task.voiceMemos.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                task.voiceMemos.forEach { memo ->
                    VoiceMemoRow(
                        memo = memo,
                        isPlaying = voiceRecorder.isPlaying(memo.audioPath),
                        onPlay = {
                            if (voiceRecorder.isPlaying(memo.audioPath)) {
                                voiceRecorder.stopPlayback()
                            } else {
                                voiceRecorder.play(memo.audioPath) {}
                            }
                        },
                        onDelete = { onDeleteMemo(memo) },
                        onRename = { onRenameMemo(memo) },
                    )
                }
            }
        }
    }
}

@Composable
private fun VoiceMemoRow(
    memo: TaskVoiceMemo,
    isPlaying: Boolean,
    onPlay: () -> Unit,
    onDelete: () -> Unit,
    onRename: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            IconButton(onClick = onPlay, modifier = Modifier.size(36.dp)) {
                Icon(
                    if (isPlaying) Icons.Default.StopCircle else Icons.Default.PlayCircle,
                    contentDescription = null,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = memo.displayName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                )
                Text(
                    text = formatRecordingDuration(memo.duration),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            IconButton(onClick = onRename, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.task_detail_rename))
            }
            IconButton(onClick = onDelete, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.action_delete), tint = Color(0xFFEF4444))
            }
        }
    }
}

private fun formatRecordingDuration(seconds: Double): String {
    val s = seconds.toInt().coerceAtLeast(0)
    val minutes = s / 60
    val secs = s % 60
    return String.format("%d:%02d", minutes, secs)
}

private fun startCameraCapture(context: Context, onReady: (Uri) -> Unit) {
    val file = File.createTempFile("snaptask_camera_", ".jpg", context.cacheDir)
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    onReady(uri)
}

// ======================== Post-Completion Insights (iOS parity) ========================

@Composable
private fun PostCompletionInsightsCard(
    task: TodoTask,
    isCompleted: Boolean,
    onUpdateTask: (TodoTask) -> Unit,
    onOpenPerformance: ((TodoTask) -> Unit)?,
) {
    val completionKey = Recurrence.startOfDay(Date()).time
    val completion = task.completions[completionKey]
    val hasRatingsHistory = task.completions.values.any {
        it.difficultyRating != null || it.qualityRating != null || it.actualDuration != null
    }

    var showDurationPicker by remember { mutableStateOf(false) }

    DetailCard(
        icon = Icons.Default.BarChart,
        title = stringResource(R.string.task_detail_performance_analytics),
        color = Color(0xFF00BCD4),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            // ---- Difficulty Rating Section ----
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.task_detail_difficulty_rating),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.weight(1f))
                    val diffRating = completion?.difficultyRating
                    if (diffRating != null && diffRating > 0) {
                        TextButton(
                            onClick = {
                                val updated = updateTaskCompletion(task, completionKey) {
                                    it.copy(difficultyRating = null)
                                }
                                onUpdateTask(updated)
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                            modifier = Modifier.height(28.dp),
                        ) {
                            Text(
                                stringResource(R.string.action_clear),
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFFEF4444),
                            )
                        }
                    } else if (!isCompleted) {
                        Text(
                            stringResource(R.string.task_detail_complete_to_track),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                        )
                    }
                }
                DifficultyRatingView(
                    rating = completion?.difficultyRating ?: 0,
                    onRatingChange = { newRating ->
                        val updated = updateTaskCompletion(task, completionKey) {
                            it.copy(difficultyRating = if (newRating == 0) null else newRating)
                        }
                        onUpdateTask(updated)
                    },
                )
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            // ---- Quality Rating Section ----
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.task_detail_quality_rating),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.weight(1f))
                    val qualRating = completion?.qualityRating
                    if (qualRating != null && qualRating > 0) {
                        TextButton(
                            onClick = {
                                val updated = updateTaskCompletion(task, completionKey) {
                                    it.copy(qualityRating = null)
                                }
                                onUpdateTask(updated)
                            },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                            modifier = Modifier.height(28.dp),
                        ) {
                            Text(
                                stringResource(R.string.action_clear),
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFFEF4444),
                            )
                        }
                    } else if (!isCompleted) {
                        Text(
                            stringResource(R.string.task_detail_complete_to_track),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                        )
                    }
                }
                QualityRatingView(
                    rating = completion?.qualityRating ?: 0,
                    onRatingChange = { newRating ->
                        val updated = updateTaskCompletion(task, completionKey) {
                            it.copy(qualityRating = if (newRating == 0) null else newRating)
                        }
                        onUpdateTask(updated)
                    },
                )
            }

            // ---- Actual Duration Section ----
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            ActualDurationSection(
                task = task,
                completionKey = completionKey,
                onUpdateTask = onUpdateTask,
                onShowDurationPicker = { showDurationPicker = true },
            )

            // ---- Performance Charts Link ----
            if (hasRatingsHistory && onOpenPerformance != null) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

                Surface(
                    onClick = { onOpenPerformance(task) },
                    shape = RoundedCornerShape(10.dp),
                    color = Color(0xFF00BCD4).copy(alpha = 0.1f),
                ) {
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp, horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.ShowChart, null, Modifier.size(16.dp), tint = Color(0xFF00BCD4))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            stringResource(R.string.task_detail_performance_charts),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            color = Color(0xFF00BCD4),
                        )
                        Spacer(Modifier.weight(1f))
                        Icon(Icons.Default.ArrowForward, null, Modifier.size(14.dp), tint = Color(0xFF00BCD4))
                    }
                }
            }
        }
    }

    // Duration picker dialog
    if (showDurationPicker) {
        DurationPickerDialog(
            currentDuration = task.completions[completionKey]?.actualDuration ?: 0.0,
            onDismiss = { showDurationPicker = false },
            onConfirm = { newDuration ->
                val updated = updateTaskCompletion(task, completionKey) {
                    it.copy(actualDuration = if (newDuration > 0) newDuration else null)
                }
                onUpdateTask(updated)
                showDurationPicker = false
            },
        )
    }
}

@Composable
private fun ActualDurationSection(
    task: TodoTask,
    completionKey: Long,
    onUpdateTask: (TodoTask) -> Unit,
    onShowDurationPicker: () -> Unit,
) {
    val completion = task.completions[completionKey]
    val actualDuration = completion?.actualDuration
    val hasActualDuration = (actualDuration ?: 0.0) > 0
    val hasEstimatedDuration = task.hasDuration
    val estimatedDuration = task.duration

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (hasActualDuration) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.task_detail_actual_duration),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                TextButton(
                    onClick = onShowDurationPicker,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                    modifier = Modifier.height(28.dp),
                ) {
                    Text(stringResource(R.string.action_edit), style = MaterialTheme.typography.labelSmall)
                }
                TextButton(
                    onClick = {
                        val updated = updateTaskCompletion(task, completionKey) {
                            it.copy(actualDuration = null)
                        }
                        onUpdateTask(updated)
                    },
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                    modifier = Modifier.height(28.dp),
                ) {
                    Text(
                        stringResource(R.string.action_clear),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFFEF4444),
                    )
                }
            }
            Text(
                formatDuration(actualDuration!!),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF4CAF50),
            )
            if (hasEstimatedDuration) {
                val difference = actualDuration - estimatedDuration
                val isUnder = difference < 0
                val percentage = if (estimatedDuration > 0) abs(difference) / estimatedDuration * 100 else 0.0
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.task_detail_estimation_accuracy),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        formatDuration(estimatedDuration),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textDecoration = TextDecoration.LineThrough,
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        if (isUnder) "(-${percentage.toInt()}%)" else "(+${percentage.toInt()}%)",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = if (isUnder) Color(0xFF4CAF50) else Color(0xFFFF9800),
                    )
                }
            }
        } else {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.task_detail_actual_duration),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                if (hasEstimatedDuration) {
                    Text(
                        formatDuration(estimatedDuration),
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF2196F3),
                    )
                } else {
                    Text(
                        stringResource(R.string.task_detail_duration_none),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            TextButton(
                onClick = onShowDurationPicker,
                contentPadding = PaddingValues(0.dp),
            ) {
                Icon(Icons.Default.AddCircle, null, Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    stringResource(R.string.task_detail_add_duration),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

@Composable
private fun NotesCard(task: TodoTask, onUpdateTask: (TodoTask) -> Unit) {
    val completionKey = Recurrence.startOfDay(Date()).time
    val currentNotes = task.completions[completionKey]?.notes ?: ""
    var notesText by remember(completionKey, task.id) { mutableStateOf(currentNotes) }

    DetailCard(
        icon = Icons.Default.Notes,
        title = stringResource(R.string.task_detail_notes),
        color = Color(0xFF9C27B0),
    ) {
        OutlinedTextField(
            value = notesText,
            onValueChange = { newValue ->
                notesText = newValue
                val updated = updateTaskCompletion(task, completionKey) {
                    it.copy(notes = newValue.ifEmpty { null })
                }
                onUpdateTask(updated)
            },
            placeholder = { Text(stringResource(R.string.task_detail_add_notes)) },
            modifier = Modifier.fillMaxWidth().heightIn(min = 80.dp),
            textStyle = MaterialTheme.typography.bodyMedium,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF9C27B0),
                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
            ),
            shape = RoundedCornerShape(10.dp),
        )
    }
}

// ======================== Rating Views (iOS parity) ========================

@Composable
private fun DifficultyRatingView(rating: Int, onRatingChange: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            for (level in 1..10) {
                IconButton(
                    onClick = { onRatingChange(if (rating == level) 0 else level) },
                    modifier = Modifier.size(24.dp),
                ) {
                    Icon(
                        if (level <= rating) Icons.Default.Bolt else Icons.Default.Bolt,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = if (level <= rating) difficultyColorForLevel(level) else Color.Gray.copy(alpha = 0.3f),
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            if (rating > 0) {
                Text(
                    "$rating/10",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = difficultyColorForLevel(rating),
                )
            }
        }
        if (rating > 0) {
            Text(
                difficultyDescription(rating),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text(
                stringResource(R.string.task_detail_tap_to_rate_difficulty),
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF2196F3),
            )
        }
    }
}

@Composable
private fun QualityRatingView(rating: Int, onRatingChange: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            for (level in 1..10) {
                IconButton(
                    onClick = { onRatingChange(if (rating == level) 0 else level) },
                    modifier = Modifier.size(24.dp),
                ) {
                    Icon(
                        if (level <= rating) Icons.Default.Star else Icons.Default.StarOutline,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = if (level <= rating) qualityColorForLevel(level) else Color.Gray.copy(alpha = 0.3f),
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            if (rating > 0) {
                Text(
                    "$rating/10",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = qualityColorForLevel(rating),
                )
            }
        }
        if (rating > 0) {
            Text(
                qualityDescription(rating),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text(
                stringResource(R.string.task_detail_tap_to_rate_quality),
                style = MaterialTheme.typography.labelSmall,
                color = Color(0xFF2196F3),
            )
        }
    }
}

// ======================== Duration Picker Dialog ========================

@Composable
private fun DurationPickerDialog(
    currentDuration: Double,
    onDismiss: () -> Unit,
    onConfirm: (Double) -> Unit,
) {
    val initialHours = (currentDuration / 3600).toInt()
    val initialMinutes = ((currentDuration % 3600) / 60).toInt()
    var hours by remember { mutableStateOf(initialHours) }
    var minutes by remember { mutableStateOf(initialMinutes) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.task_detail_set_actual_duration)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(
                    "${hours}h ${minutes}m",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.task_detail_hours), style = MaterialTheme.typography.labelSmall)
                        Slider(
                            value = hours.toFloat(),
                            onValueChange = { hours = it.toInt().coerceIn(0, 23) },
                            valueRange = 0f..23f,
                            steps = 22,
                        )
                        Text("$hours", style = MaterialTheme.typography.bodySmall)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.task_detail_minutes), style = MaterialTheme.typography.labelSmall)
                        Slider(
                            value = minutes.toFloat(),
                            onValueChange = { minutes = it.toInt().coerceIn(0, 59) },
                            valueRange = 0f..59f,
                            steps = 58,
                        )
                        Text("$minutes", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val totalSeconds = (hours * 3600 + minutes * 60).toDouble()
                onConfirm(totalSeconds)
            }) { Text(stringResource(R.string.action_save)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
        },
    )
}

// ======================== Header Section ========================

@Composable
private fun HeaderSection(task: TodoTask, isCompleted: Boolean) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 4.dp),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        tonalElevation = 2.dp,
        shadowElevation = 4.dp,
    ) {
        Row(
            Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Icon
            Box(
                Modifier.size(60.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Default.TaskAlt, null,
                    Modifier.size(32.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }

            // Name and metadata
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    task.name,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    task.category?.let { cat ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(parseHexColor(cat.color)))
                            Text(cat.name, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(task.priority.displayName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            // Completion status
            Icon(
                if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                null, Modifier.size(28.dp),
                tint = if (isCompleted) Color(0xFF4CAF50) else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// ======================== Detail Card ========================

@Composable
private fun DetailCard(
    icon: ImageVector,
    title: String,
    color: Color,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        tonalElevation = 1.dp,
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(icon, null, Modifier.size(16.dp), tint = color)
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(12.dp))
            content()
        }
    }
}

// ======================== Detail Row ========================

@Composable
private fun DetailRow(
    label: String,
    value: String,
    valueColor: Color? = null,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        Text(
            value, style = MaterialTheme.typography.bodyMedium,
            color = valueColor ?: MaterialTheme.colorScheme.onSurface,
        )
    }
}

// ======================== Helper Functions ========================

private fun leadTimeLabel(minutes: Int, exactStr: String, minBeforeFormat: String): String {
    if (minutes == 0) return exactStr
    val h = minutes / 60; val m = minutes % 60
    return when {
        h > 0 && m > 0 -> "${h}h ${m}m before"
        h > 0 -> "${h}h before"
        else -> minBeforeFormat.replace("%d", m.toString())
    }
}

private fun formatDuration(seconds: Double): String {
    val hours = (seconds / 3600).toInt()
    val minutes = ((seconds % 3600) / 60).toInt()
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

private fun recurrenceDescription(
    recurrence: Recurrence,
    dailyStr: String,
    weeklyFormat: String,
    monthlyPatternsStr: String,
    yearlyStr: String,
): String {
    return when (val type = recurrence.type) {
        is RecurrenceType.DAILY -> dailyStr
        is RecurrenceType.WEEKLY -> if (type.days.size == 7) dailyStr else weeklyFormat.replace("%d", type.days.size.toString())
        is RecurrenceType.MONTHLY -> "${type.days.size} days/month"
        is RecurrenceType.MONTHLY_ORDINAL -> monthlyPatternsStr
        is RecurrenceType.YEARLY -> yearlyStr
    }
}

// ======================== Completion Helpers ========================

/**
 * Creates or updates a TaskCompletion for the given key within the task's completions map.
 */
private fun updateTaskCompletion(
    task: TodoTask,
    completionKey: Long,
    transform: (TaskCompletion) -> TaskCompletion,
): TodoTask {
    val existingCompletion = task.completions[completionKey] ?: TaskCompletion()
    val updatedCompletion = transform(existingCompletion)
    val updatedCompletions = task.completions.toMutableMap()
    updatedCompletions[completionKey] = updatedCompletion
    return task.copy(completions = updatedCompletions, lastModifiedDate = Date())
}

// ======================== Rating Color & Description Helpers (iOS parity) ========================

/**
 * Difficulty color progression matching iOS DifficultyRatingView:
 * Green (easy/1-2) → Yellow-Green (3-4) → Yellow (5-6) → Orange (7-8) → Red (hard/9-10)
 */
private fun difficultyColorForLevel(level: Int): Color {
    return when {
        level <= 2 -> Color(0xFF4CAF50)  // Green
        level <= 4 -> Color(0xFF8BC34A)  // Light Green
        level <= 6 -> Color(0xFFFFC107)  // Amber
        level <= 8 -> Color(0xFFFF9800)  // Orange
        else -> Color(0xFFF44336)        // Red
    }
}

/**
 * Quality color progression matching iOS QualityRatingView:
 * Red (poor/1-2) → Orange (3-4) → Yellow (5-6) → Green (7-8) → Blue (perfect/9-10)
 */
private fun qualityColorForLevel(level: Int): Color {
    return when {
        level <= 2 -> Color(0xFFF44336)  // Red
        level <= 4 -> Color(0xFFFF9800)  // Orange
        level <= 6 -> Color(0xFFFFC107)  // Amber
        level <= 8 -> Color(0xFF4CAF50)  // Green
        else -> Color(0xFF2196F3)        // Blue
    }
}

@Composable
private fun difficultyDescription(rating: Int): String {
    return when {
        rating <= 2 -> stringResource(R.string.difficulty_very_easy)
        rating <= 4 -> stringResource(R.string.difficulty_easy)
        rating <= 5 -> stringResource(R.string.difficulty_moderate)
        rating <= 7 -> stringResource(R.string.difficulty_challenging)
        rating <= 9 -> stringResource(R.string.difficulty_hard)
        else -> stringResource(R.string.difficulty_extremely_hard)
    }
}

@Composable
private fun qualityDescription(rating: Int): String {
    return when {
        rating <= 2 -> stringResource(R.string.quality_poor)
        rating <= 4 -> stringResource(R.string.quality_below_average)
        rating <= 5 -> stringResource(R.string.quality_average)
        rating <= 7 -> stringResource(R.string.quality_good)
        rating <= 9 -> stringResource(R.string.quality_excellent)
        else -> stringResource(R.string.quality_perfect)
    }
}

