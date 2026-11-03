package com.snaptask.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import kotlinx.serialization.builtins.serializer
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import kotlin.math.max

object AttachmentService {
    private val attachmentsRoot: File get() = File(App.filesDir, "Attachments")
    private fun taskFolder(taskId: UUID) = File(attachmentsRoot, taskId.uuidString)
    private fun journalFolder(entryId: UUID) = File(File(attachmentsRoot, "Journal"), entryId.uuidString)

    fun readUri(uri: Uri): ByteArray? = runCatching {
        App.context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
    }.getOrNull()

    private fun decode(data: ByteArray): Bitmap? {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return null
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(data)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(degrees) }, true)
    }

    private fun downscale(image: Bitmap, maxDimension: Int): Bitmap {
        val largest = max(image.width, image.height)
        if (largest <= maxDimension) return image
        val scale = maxDimension.toFloat() / largest
        return Bitmap.createScaledBitmap(image, (image.width * scale).toInt(), (image.height * scale).toInt(), true)
    }

    private fun write(bitmap: Bitmap, file: File, quality: Int) {
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, quality, it) }
    }

    private fun savePair(folder: File, id: UUID, imageData: ByteArray): Pair<String, String>? = runCatching {
        val original = decode(imageData) ?: return null
        val scaled = downscale(original, 1600)
        val thumb = downscale(scaled, 200)
        folder.mkdirs()
        val photo = File(folder, "photo_${id.uuidString}.jpg")
        val thumbnail = File(folder, "thumb_${id.uuidString}.jpg")
        write(scaled, photo, 85)
        write(thumb, thumbnail, 80)
        photo.path to thumbnail.path
    }.getOrNull()

    fun addPhoto(taskId: UUID, imageData: ByteArray): TaskPhoto? {
        val id = UUID.randomUUID()
        val (photo, thumb) = savePair(taskFolder(taskId), id, imageData) ?: return null
        return TaskPhoto(id = id, photoPath = photo, thumbnailPath = thumb)
    }

    fun deletePhoto(taskId: UUID, photo: TaskPhoto) {
        File(photo.photoPath).delete()
        File(photo.thumbnailPath).delete()
        taskFolder(taskId).takeIf { it.list()?.isEmpty() == true }?.delete()
    }

    fun deleteTaskFolder(taskId: UUID) {
        taskFolder(taskId).deleteRecursively()
    }

    fun deleteAllMedia(task: TodoTask) {
        deleteTaskFolder(task.id)
        task.voiceMemos.forEach { File(it.audioPath).delete() }
    }

    fun addJournalPhoto(entryId: UUID, imageData: ByteArray, id: UUID = UUID.randomUUID(), createdAt: Date = now()): JournalPhoto? {
        val (photo, thumb) = savePair(journalFolder(entryId), id, imageData) ?: return null
        return JournalPhoto(id = id, photoPath = photo, thumbnailPath = thumb, createdAt = createdAt)
    }

    fun deleteJournalPhoto(entryId: UUID, photo: JournalPhoto) {
        File(photo.photoPath).delete()
        File(photo.thumbnailPath).delete()
        journalFolder(entryId).takeIf { it.list()?.isEmpty() == true }?.delete()
    }

    fun resolveFilePath(path: String): String? = path.takeIf { File(it).exists() }
}

/** The events of the device's calendars and writing tasks to them, through Android's calendar provider. */
data class DeviceCalendar(val id: String, val title: String, val color: Int, val accountName: String, val canWrite: Boolean, val accountType: String = "")

data class CalendarOccurrence(
    val eventId: String,
    val title: String,
    val start: Date,
    val end: Date,
    val allDay: Boolean,
    val calendarId: String,
    val calendarTitle: String,
    val color: Int,
)

object AppleCalendarService {
    private val resolver get() = App.context.contentResolver

    val hasReadAccess: Boolean
        get() = androidx.core.content.ContextCompat.checkSelfPermission(App.context, android.Manifest.permission.READ_CALENDAR) == android.content.pm.PackageManager.PERMISSION_GRANTED
    val hasWriteAccess: Boolean
        get() = androidx.core.content.ContextCompat.checkSelfPermission(App.context, android.Manifest.permission.WRITE_CALENDAR) == android.content.pm.PackageManager.PERMISSION_GRANTED

    fun allEventCalendars(): List<DeviceCalendar> {
        if (!hasReadAccess) return emptyList()
        val uri = android.provider.CalendarContract.Calendars.CONTENT_URI
        val projection = arrayOf(
            android.provider.CalendarContract.Calendars._ID,
            android.provider.CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            android.provider.CalendarContract.Calendars.CALENDAR_COLOR,
            android.provider.CalendarContract.Calendars.ACCOUNT_NAME,
            android.provider.CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            android.provider.CalendarContract.Calendars.ACCOUNT_TYPE,
        )
        val result = ArrayList<DeviceCalendar>()
        runCatching {
            resolver.query(uri, projection, null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    result += DeviceCalendar(
                        cursor.getLong(0).toString(),
                        cursor.getString(1) ?: "",
                        cursor.getInt(2),
                        cursor.getString(3) ?: "",
                        cursor.getInt(4) >= android.provider.CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR,
                        cursor.getString(5) ?: "",
                    )
                }
            }
        }
        return result
    }

    fun writableCalendars(): List<DeviceCalendar> = allEventCalendars().filter { it.canWrite }

    fun events(day: Date, calendars: List<DeviceCalendar>): List<CalendarOccurrence> {
        if (!hasReadAccess || calendars.isEmpty()) return emptyList()
        val start = day.startOfDay()
        val end = start.addingDays(1)
        val builder = android.provider.CalendarContract.Instances.CONTENT_URI.buildUpon()
        android.content.ContentUris.appendId(builder, start.toEpochMilli())
        android.content.ContentUris.appendId(builder, end.toEpochMilli())
        val projection = arrayOf(
            android.provider.CalendarContract.Instances.EVENT_ID,
            android.provider.CalendarContract.Instances.TITLE,
            android.provider.CalendarContract.Instances.BEGIN,
            android.provider.CalendarContract.Instances.END,
            android.provider.CalendarContract.Instances.ALL_DAY,
            android.provider.CalendarContract.Instances.CALENDAR_ID,
            android.provider.CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            android.provider.CalendarContract.Instances.DISPLAY_COLOR,
        )
        val ids = calendars.map { it.id }.toSet()
        val result = ArrayList<CalendarOccurrence>()
        runCatching {
            resolver.query(builder.build(), projection, null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    val calendarId = cursor.getLong(5).toString()
                    if (calendarId !in ids) continue
                    result += CalendarOccurrence(
                        cursor.getLong(0).toString(),
                        cursor.getString(1) ?: "",
                        Date.ofEpochMilli(cursor.getLong(2)),
                        Date.ofEpochMilli(cursor.getLong(3)),
                        cursor.getInt(4) == 1,
                        calendarId,
                        cursor.getString(6) ?: "",
                        cursor.getInt(7),
                    )
                }
            }
        }
        return result
    }

    private fun values(task: TodoTask, calendarId: String?): android.content.ContentValues = android.content.ContentValues().apply {
        calendarId?.let { put(android.provider.CalendarContract.Events.CALENDAR_ID, it.toLong()) }
        put(android.provider.CalendarContract.Events.TITLE, task.name)
        put(android.provider.CalendarContract.Events.DESCRIPTION, task.description ?: "")
        val start = task.startTime
        if (task.hasSpecificTime) {
            val duration = if (task.hasDuration && task.duration > 0) task.duration else 3600.0
            put(android.provider.CalendarContract.Events.DTSTART, start.toEpochMilli())
            put(android.provider.CalendarContract.Events.DTEND, start.plusSeconds(duration.toLong()).toEpochMilli())
            put(android.provider.CalendarContract.Events.EVENT_TIMEZONE, zone.id)
            put(android.provider.CalendarContract.Events.ALL_DAY, 0)
        } else {
            val utc = start.z().toLocalDate().atStartOfDay(java.time.ZoneOffset.UTC).toInstant()
            put(android.provider.CalendarContract.Events.DTSTART, utc.toEpochMilli())
            put(android.provider.CalendarContract.Events.DTEND, utc.plusSeconds(86400).toEpochMilli())
            put(android.provider.CalendarContract.Events.EVENT_TIMEZONE, "UTC")
            put(android.provider.CalendarContract.Events.ALL_DAY, 1)
        }
        val rule = task.recurrence?.let { rrule(it) }
        if (rule != null) {
            put(android.provider.CalendarContract.Events.RRULE, rule)
            putNull(android.provider.CalendarContract.Events.DTEND)
            put(android.provider.CalendarContract.Events.DURATION, if (task.hasSpecificTime) "PT${(if (task.hasDuration && task.duration > 0) task.duration else 3600.0).toLong()}S" else "P1D")
        }
    }

    private fun rrule(recurrence: Recurrence): String {
        val byDay = listOf("SU", "MO", "TU", "WE", "TH", "FR", "SA")
        val parts = ArrayList<String>()
        when (val type = recurrence.type) {
            RecurrenceType.Daily -> {
                parts += "FREQ=DAILY"
                recurrence.dayInterval?.takeIf { it > 1 }?.let { parts += "INTERVAL=$it" }
            }
            is RecurrenceType.Weekly -> {
                parts += "FREQ=WEEKLY"
                recurrence.weekInterval?.takeIf { it > 1 }?.let { parts += "INTERVAL=$it" }
                parts += "BYDAY=" + type.days.sorted().joinToString(",") { byDay[it - 1] }
            }
            is RecurrenceType.Monthly -> {
                parts += "FREQ=MONTHLY"
                recurrence.monthInterval?.takeIf { it > 1 }?.let { parts += "INTERVAL=$it" }
                parts += "BYMONTHDAY=" + type.days.sorted().joinToString(",")
            }
            is RecurrenceType.MonthlyOrdinal -> {
                parts += "FREQ=MONTHLY"
                parts += "BYDAY=" + type.patterns.joinToString(",") { "${it.ordinal}${byDay[it.weekday - 1]}" }
            }
            RecurrenceType.Yearly -> {
                parts += "FREQ=YEARLY"
                recurrence.yearInterval?.takeIf { it > 1 }?.let { parts += "INTERVAL=$it" }
            }
        }
        recurrence.endDate?.let { parts += "UNTIL=" + it.atZone(java.time.ZoneOffset.UTC).format(java.time.format.DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'")) }
        return parts.joinToString(";")
    }

    fun createEvent(task: TodoTask, calendarId: String): String? = runCatching {
        resolver.insert(android.provider.CalendarContract.Events.CONTENT_URI, values(task, calendarId))?.lastPathSegment
    }.getOrNull()

    fun updateEvent(eventId: String, task: TodoTask): Boolean = runCatching {
        val uri = android.content.ContentUris.withAppendedId(android.provider.CalendarContract.Events.CONTENT_URI, eventId.toLong())
        resolver.update(uri, values(task, null), null, null) > 0
    }.getOrDefault(false)

    fun deleteEvent(eventId: String): Boolean = runCatching {
        val uri = android.content.ContentUris.withAppendedId(android.provider.CalendarContract.Events.CONTENT_URI, eventId.toLong())
        resolver.delete(uri, null, null) > 0
    }.getOrDefault(false)
}

/** Writing tasks to the device calendar. Google calendars on the phone are device calendars on Android. */
object CalendarIntegrationManager {
    private const val settingsKey = "calendar_integration_settings"
    private val eventMapSerializer = kotlinx.serialization.builtins.MapSerializer(String.serializer(), String.serializer())

    var settings by androidx.compose.runtime.mutableStateOf(CalendarIntegrationSettings())
        private set
    var syncStatus by androidx.compose.runtime.mutableStateOf<SyncStatus>(SyncStatus.Idle)
        private set

    sealed class SyncStatus {
        data object Idle : SyncStatus()
        data object Syncing : SyncStatus()
        data object Success : SyncStatus()
        data class Failure(val message: String) : SyncStatus()

        val displayText: String
            get() = when (this) {
                Idle -> "sync_ready".localized
                Syncing -> "sync_syncing".localized
                Success -> "sync_success".localized
                is Failure -> "${"sync_error_prefix".localized}: $message"
            }
    }

    fun load() {
        Store.load(settingsKey, CalendarIntegrationSettings.serializer())?.let { settings = it }
    }

    fun updateSettings(newSettings: CalendarIntegrationSettings) {
        settings = newSettings
        Store.save(settingsKey, CalendarIntegrationSettings.serializer(), newSettings)
    }

    private fun eventMap(): MutableMap<String, String> = (Store.load("calendar_events", eventMapSerializer) ?: emptyMap()).toMutableMap()
    private fun saveEventMap(map: Map<String, String>) = Store.save("calendar_events", eventMapSerializer, map)

    suspend fun syncTaskToCalendar(task: TodoTask) {
        val calendarId = settings.selectedCalendarId
        if (!settings.isEnabled || calendarId == null) return
        syncStatus = SyncStatus.Syncing
        val id = AppleCalendarService.createEvent(task, calendarId)
        if (id != null) {
            val map = eventMap()
            map[task.id.uuidString] = id
            saveEventMap(map)
            syncStatus = SyncStatus.Success
        } else {
            syncStatus = SyncStatus.Failure("Failed to create calendar event")
        }
    }

    suspend fun updateTaskInCalendar(task: TodoTask) {
        if (!settings.isEnabled || !settings.autoSyncOnTaskUpdate) return
        val eventId = eventMap()[task.id.uuidString] ?: return
        syncStatus = SyncStatus.Syncing
        syncStatus = if (AppleCalendarService.updateEvent(eventId, task)) SyncStatus.Success else SyncStatus.Failure("Failed to update calendar event")
    }

    suspend fun deleteTaskFromCalendar(taskId: UUID, isRecurring: Boolean = false) {
        if (!settings.isEnabled) return
        val map = eventMap()
        val eventId = map[taskId.uuidString] ?: return
        syncStatus = SyncStatus.Syncing
        AppleCalendarService.deleteEvent(eventId)
        map.remove(taskId.uuidString)
        saveEventMap(map)
        syncStatus = SyncStatus.Success
    }

    suspend fun syncAllTasksToCalendar(tasks: List<TodoTask>) {
        val calendarId = settings.selectedCalendarId
        if (!settings.isEnabled || calendarId == null) {
            syncStatus = SyncStatus.Failure("Calendar integration not properly configured")
            return
        }
        syncStatus = SyncStatus.Syncing
        val map = eventMap()
        var success = 0
        var failed = 0
        for (task in tasks) {
            if (task.recurrence != null && !settings.syncRecurringTasks) continue
            if (task.id.uuidString in map) continue
            val id = AppleCalendarService.createEvent(task, calendarId)
            if (id != null) {
                map[task.id.uuidString] = id
                success++
            } else failed++
        }
        saveEventMap(map)
        syncStatus = if (failed == 0) SyncStatus.Success else SyncStatus.Failure("Synced $success tasks, $failed failed")
    }

    suspend fun deleteAllSyncedTasksFromCalendar() {
        if (!settings.isEnabled) {
            syncStatus = SyncStatus.Failure("Calendar integration is disabled")
            return
        }
        syncStatus = SyncStatus.Syncing
        eventMap().values.forEach { AppleCalendarService.deleteEvent(it) }
        saveEventMap(emptyMap())
        syncStatus = SyncStatus.Success
    }

    fun getSyncedTasksCount(): Int = eventMap().size
}

/** A calendar event shown in the day list. */
data class CalendarFeedEvent(
    val id: String,
    val title: String,
    val startDate: Date,
    val endDate: Date,
    val isAllDay: Boolean,
    val calendarTitle: String,
    val color: androidx.compose.ui.graphics.Color,
    val isBirthday: Boolean,
)

/** Shows the events of the user's calendars in the day list, so they can be added as tasks. Read only. */
object CalendarEventsFeed {
    private const val enabledKey = "calendar_events_feed_enabled"
    private const val hiddenKey = "calendar_events_feed_hidden_calendars"
    private const val addedKey = "calendar_events_feed_added_tasks"
    private val addedSerializer = kotlinx.serialization.builtins.MapSerializer(String.serializer(), String.serializer())
    private val hiddenSerializer = kotlinx.serialization.builtins.ListSerializer(String.serializer())
    private var day: Date = now()

    var isEnabled by androidx.compose.runtime.mutableStateOf(false)
        private set
    var hiddenCalendarIds by androidx.compose.runtime.mutableStateOf<Set<String>>(emptySet())
        private set
    var events by androidx.compose.runtime.mutableStateOf<List<CalendarFeedEvent>>(emptyList())
        private set

    private var addedTaskIds by androidx.compose.runtime.mutableStateOf<Map<String, String>>(emptyMap())

    fun load() {
        isEnabled = Defaults.bool(enabledKey)
        hiddenCalendarIds = (Store.load(hiddenKey, hiddenSerializer) ?: emptyList()).toSet()
        addedTaskIds = Store.load(addedKey, addedSerializer) ?: emptyMap()
    }

    fun updateEnabled(enabled: Boolean) {
        isEnabled = enabled
        Defaults.set(enabledKey, enabled)
        reload()
    }

    fun setHidden(ids: Set<String>) {
        hiddenCalendarIds = ids
        Store.save(hiddenKey, hiddenSerializer, ids.toList())
        reload()
    }

    fun load(day: Date) {
        this.day = day
        reload()
    }

    /** Events whose task still exists: their row shows a checkmark instead of "+". */
    val addedEventIds: Set<String>
        get() {
            val ids = TaskManager.tasks.map { it.id.uuidString }.toSet()
            return addedTaskIds.filter { it.value in ids }.keys
        }

    fun markAdded(event: CalendarFeedEvent, taskId: UUID) {
        addedTaskIds = addedTaskIds + (event.id to taskId.uuidString)
        Store.save(addedKey, addedSerializer, addedTaskIds)
    }

    fun reload() {
        if (!isEnabled) {
            if (events.isNotEmpty()) events = emptyList()
            return
        }
        val calendars = AppleCalendarService.allEventCalendars().filter { it.id !in hiddenCalendarIds }
        events = AppleCalendarService.events(day, calendars).map { event ->
            CalendarFeedEvent(
                id = "${event.eventId}_${event.start.epochSecond}",
                title = event.title,
                startDate = event.start,
                endDate = event.end,
                isAllDay = event.allDay,
                calendarTitle = event.calendarTitle,
                color = androidx.compose.ui.graphics.Color(event.color),
                isBirthday = event.calendarTitle.contains("birthday", ignoreCase = true) || event.calendarTitle.contains("compleanni", ignoreCase = true),
            )
        }.sortedWith(compareBy<CalendarFeedEvent> { !it.isAllDay }.thenBy { it.startDate }.thenBy { it.title.lowercase() })
    }
}
