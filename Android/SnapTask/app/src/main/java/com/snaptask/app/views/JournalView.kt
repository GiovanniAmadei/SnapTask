package com.snaptask.app

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.expandVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.format.FormatStyle

@Composable
fun JournalView(date: Date) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val manager = JournalManager
    var currentDate by remember { mutableStateOf(date.startOfDay()) }
    var titleText by remember { mutableStateOf("") }
    var text by remember { mutableStateOf("") }
    var worthItText by remember { mutableStateOf("") }
    var isWorthItHidden by remember { mutableStateOf(false) }
    var selectedMood by remember { mutableStateOf<MoodType?>(null) }
    var newTagText by remember { mutableStateOf("") }
    var tags by remember { mutableStateOf<List<String>>(emptyList()) }

    LaunchedEffect(currentDate) {
        val entry = manager.entry(currentDate)
        titleText = entry.title
        text = entry.text
        worthItText = entry.worthItText
        isWorthItHidden = entry.isWorthItHidden
        selectedMood = entry.mood
        tags = entry.tags
    }

    fun commitTag() {
        val tag = newTagText.trim()
        if (tag.isEmpty()) return
        manager.addTag(tag, currentDate)
        if (tag !in tags) tags = tags + tag
        newTagText = ""
    }

    val entry = manager.entriesByDay[currentDate] ?: JournalEntry(date = currentDate)

    @Composable
    fun card(content: @Composable ColumnScope.() -> Unit) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor, RoundedCornerShape(16.dp))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "journal".localized,
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = { BarButton("done".localized, bold = true, onClick = dismiss) },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 24.dp).navigationBarsPadding().imePadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            card {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    DayArrow("chevron.left") { currentDate = currentDate.addingDays(-1) }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        T(currentDate.dateStyle(FormatStyle.MEDIUM), Fonts.subheadline.semibold)
                        T(currentDate.format("EEEE").replaceFirstChar { it.titlecase(appLocale) }, Fonts.caption, theme.secondaryTextColor)
                    }
                    DayArrow("chevron.right") { currentDate = currentDate.addingDays(1) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    PlainField(
                        titleText,
                        {
                            titleText = it
                            manager.updateTitle(currentDate, it)
                        },
                        "journal_page_title".localized,
                        style = Fonts.headline,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .border(1.dp, theme.borderColor, RoundedCornerShape(10.dp))
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                    IOSMenu(
                        listOf(MenuItem("remove_mood".localized, "slash.circle") {
                            selectedMood = null
                            manager.setMood(currentDate, null)
                        }) + MoodType.entries.map { mood ->
                            MenuItem("${mood.emoji}  ${mood.localizedName.replaceFirstChar { it.titlecase(appLocale) }}", checked = selectedMood == mood) {
                                selectedMood = mood
                                manager.setMood(currentDate, mood)
                            }
                        },
                    ) {
                        Box(
                            Modifier
                                .size(width = 52.dp, height = 40.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .background(theme.primaryColor.copy(alpha = 0.1f))
                                .border(1.dp, theme.primaryColor.copy(alpha = 0.35f), RoundedCornerShape(10.dp)),
                            contentAlignment = Alignment.Center,
                        ) {
                            val mood = selectedMood
                            if (mood != null) T(mood.emoji, Fonts.title2) else SF("face.smiling", theme.primaryColor, 20.dp)
                        }
                    }
                }
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.borderColor))
                JournalEditor(text, "journal_placeholder".localized, 300) {
                    text = it
                    manager.updateText(currentDate, it)
                }
            }
            card {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("worth_it_title".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
                    IOSToggle(!isWorthItHidden, {
                        isWorthItHidden = !it
                        manager.setWorthItHidden(currentDate, !it)
                    })
                }
                AnimatedVisibility(!isWorthItHidden, enter = fadeIn(tween(220)) + expandVertically(tween(220)), exit = fadeOut(tween(220)) + shrinkVertically(tween(220))) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.borderColor))
                        JournalEditor(worthItText, "worth_it_subtitle".localized, 120) {
                            worthItText = it
                            manager.updateWorthItText(currentDate, it)
                        }
                    }
                }
            }
            card { JournalPhotos(entry, currentDate) }
            card { JournalVoiceMemos(entry, currentDate) }
            card {
                T("tags".localized, Fonts.subheadline.semibold)
                if (tags.isEmpty()) T("tags_description".localized, Fonts.caption, theme.secondaryTextColor)
                if (tags.isNotEmpty()) {
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        tags.forEach { tag ->
                            Row(
                                Modifier
                                    .clip(CircleShape)
                                    .background(theme.surfaceColor)
                                    .border(1.dp, theme.primaryColor.copy(alpha = 0.25f), CircleShape)
                                    .padding(horizontal = 12.dp, vertical = 7.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                T(tag, Fonts.caption.semibold, maxLines = 1)
                                Box(Modifier.tap {
                                    manager.removeTag(tag, currentDate)
                                    tags = tags.filterNot { it.equals(tag, ignoreCase = true) }
                                }) { SF("xmark.circle.fill", theme.textColor, 14.dp) }
                            }
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    BasicTextField(
                        newTagText,
                        { newTagText = it },
                        singleLine = true,
                        textStyle = Fonts.body.copy(color = theme.textColor),
                        cursorBrush = SolidColor(theme.accentColor),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { commitTag() }),
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(6.dp))
                            .border(0.5.dp, theme.borderColor, RoundedCornerShape(6.dp))
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        decorationBox = { inner ->
                            if (newTagText.isEmpty()) T("add_tag".localized, Fonts.body, theme.secondaryTextColor.copy(alpha = 0.7f), maxLines = 1)
                            inner()
                        },
                    )
                    Box(Modifier.tap { commitTag() }) { SF("plus.circle.fill", theme.accentColor, 22.dp) }
                }
            }
        }
    }
}

@Composable
private fun DayArrow(icon: String, onClick: () -> Unit) {
    val theme = theme
    Box(
        Modifier
            .size(28.dp)
            .background(theme.primaryColor.copy(alpha = 0.1f), CircleShape)
            .tap {
                Haptics.light()
                onClick()
            },
        contentAlignment = Alignment.Center,
    ) { SF(icon, theme.primaryColor, 14.dp) }
}

@Composable
private fun JournalEditor(value: String, placeholder: String, minHeight: Int, onChange: (String) -> Unit) {
    val theme = theme
    BasicTextField(
        value,
        onChange,
        textStyle = Fonts.body.copy(color = theme.textColor),
        cursorBrush = SolidColor(theme.accentColor),
        modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = minHeight.dp).padding(6.dp),
        decorationBox = { inner ->
            Box {
                if (value.isBlank()) T(placeholder, Fonts.body, theme.secondaryTextColor)
                inner()
            }
        },
    )
}

@Composable
private fun JournalPhotos(entry: JournalEntry, date: Date) {
    val theme = theme
    val presenter = LocalPresenter.current
    var showSourceDialog by remember { mutableStateOf(false) }
    var cameraFile by remember { mutableStateOf<File?>(null) }
    val canAddMore = MediaLimits.canAddJournalPhoto(entry.photos.size)

    fun add(datas: List<ByteArray>) {
        MainScope.launch {
            val photos = withContext(Dispatchers.IO) { datas.mapNotNull { AttachmentService.addJournalPhoto(entry.id, it) } }
            photos.forEach { JournalManager.addPhoto(it, date) }
        }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        val file = cameraFile
        if (ok && file != null) {
            add(listOf(file.readBytes()))
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
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(MediaLimits.maxPhotosPerJournal)) { uris ->
        add(uris.take(MediaLimits.remainingJournalPhotos(JournalManager.entry(date).photos.size)).mapNotNull { AttachmentService.readUri(it) })
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

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SF("photo", Color.SysBlue, 18.dp)
        T("photos".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
        T("${entry.photos.size}/${MediaLimits.maxPhotosPerJournal}", Fonts.caption, theme.secondaryTextColor)
    }
    if (entry.photos.isNotEmpty()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            entry.photos.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { photo ->
                        key(photo.id) {
                            Box(Modifier.weight(1f).height(90.dp)) {
                                FileImage(
                                    photo.thumbnailPath,
                                    Modifier.fillMaxSize().clip(RoundedCornerShape(10.dp)).tap {
                                        presenter.sheet { NavigationStack { FullScreenPhoto(photo.photoPath) } }
                                    },
                                )
                                Box(
                                    Modifier
                                        .align(Alignment.TopEnd)
                                        .padding(6.dp)
                                        .tap {
                                            AttachmentService.deleteJournalPhoto(entry.id, photo)
                                            JournalManager.removePhoto(photo.id, date)
                                        },
                                ) { SF("trash.circle.fill", Color.SysRed, 20.dp) }
                            }
                        }
                    }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        if (canAddMore) AddMediaButton("add_photos".localized, Modifier.padding(top = 4.dp)) { showSourceDialog = true }
    } else {
        AddMediaButton("add_photos".localized) { showSourceDialog = true }
    }
}

@Composable
private fun JournalVoiceMemos(entry: JournalEntry, date: Date) {
    val theme = theme
    val service = remember { VoiceMemoService() }
    var micDenied by remember { mutableStateOf(false) }
    val canAddMore = MediaLimits.canAddJournalVoiceMemo(entry.voiceMemos.size)

    fun finish() {
        val (path, duration) = service.stop() ?: return
        JournalManager.addVoiceMemo(JournalVoiceMemo(audioPath = path, duration = duration), date)
    }
    fun start() {
        runCatching { service.start(VoiceMemoService.journalFolder(entry.id)) { finish() } }
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) start() else micDenied = true
    }
    DisposableEffect(date) { onDispose { if (service.isRecording) finish() } }

    if (micDenied) {
        IOSAlert(
            "microphone_access_denied_title".localized,
            "microphone_access_denied_message".localized,
            listOf(AlertAction("ok".localized, AlertRole.cancel)),
            { micDenied = false },
        )
    }

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SF("waveform", Color.SysPink, 18.dp)
        T("voice_memos".localized, Fonts.subheadline.semibold, modifier = Modifier.weight(1f))
        T("${entry.voiceMemos.size}/${MediaLimits.maxVoiceMemosPerJournal}", Fonts.caption, theme.secondaryTextColor)
    }
    if (canAddMore || service.isRecording) {
        Row {
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
        }
    }
    AnimatedVisibility(service.isRecording, enter = fadeIn(tween(200)), exit = fadeOut(tween(200))) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            WaveformView(service.meterLevels, Color.SysPink, Modifier.fillMaxWidth().height(40.dp))
            T("recording".localized, Fonts.caption, Color.SysOrange)
        }
    }
    if (entry.voiceMemos.isEmpty()) {
        T("no_voice_memos_yet".localized, Fonts.subheadline, theme.secondaryTextColor)
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            entry.voiceMemos.forEach { memo ->
                key(memo.id) {
                    VoiceMemoRow(
                        displayName = memo.displayName,
                        name = memo.name,
                        path = memo.audioPath,
                        duration = memo.duration,
                        createdAt = memo.createdAt,
                        onDelete = {
                            runCatching { File(memo.audioPath).delete() }
                            JournalManager.removeVoiceMemo(memo.id, date)
                        },
                        onRename = { JournalManager.updateVoiceMemoName(it, memo.id, date) },
                        onEditing = {},
                    )
                }
            }
        }
    }
}

// MARK: - Mood

@Composable
fun MoodSelectionView(date: Date) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var selected by remember { mutableStateOf(MoodManager.mood(date)) }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "",
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (MoodManager.mood(date) != null) {
                        BarButton("remove".localized, color = Color.SysRed) {
                            MoodManager.removeMood(date)
                            selected = null
                            Haptics.light()
                            dismiss()
                        }
                    }
                    BarButton("done".localized, bold = true, onClick = dismiss)
                }
            },
        )
        Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                T((if (date.isToday()) "how_do_you_feel_today" else "how_did_you_feel_that_day").localized, Fonts.title3.bold)
                T(
                    selected?.let { "selected_mood_format".localized(it.localizedName.replaceFirstChar { c -> c.titlecase(appLocale) }) } ?: "tap_icon_to_select".localized,
                    Fonts.caption,
                    theme.secondaryTextColor,
                )
            }
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                MoodType.entries.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { mood ->
                            val color = colorFromHex(mood.colorHex)
                            val isSelected = selected == mood
                            Column(
                                Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(color.copy(alpha = if (isSelected) 0.12f else 0.06f))
                                    .pressable {
                                        selected = mood
                                        MoodManager.setMood(date, mood)
                                        Haptics.light()
                                        dismiss()
                                    }
                                    .padding(8.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Box(
                                    Modifier
                                        .size(66.dp)
                                        .background(color.copy(alpha = 0.12f), CircleShape)
                                        .border(if (isSelected) 2.dp else 1.dp, if (isSelected) color else theme.borderColor, CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) { T(mood.emoji, systemFont(30)) }
                                T(mood.localizedName.replaceFirstChar { it.titlecase(appLocale) }, Fonts.caption.semibold, maxLines = 1)
                            }
                        }
                        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

// MARK: - Quote

/** The quote card of the settings (`IOSQuoteCard`). */
@Composable
fun MotivationalQuoteCard(modifier: Modifier = Modifier) {
    val theme = theme
    val quote = QuoteManager.currentQuote
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        T(
            "\"${quote.text}\"",
            TextStyle(fontFamily = androidx.compose.ui.text.font.FontFamily.Serif, fontStyle = FontStyle.Italic, fontWeight = FontWeight.Normal, fontSize = Fonts.body.fontSize, lineHeight = Fonts.body.lineHeight),
        )
        T("— ${quote.author}", Fonts.caption, theme.secondaryTextColor, modifier = Modifier.align(Alignment.End))
    }
}
