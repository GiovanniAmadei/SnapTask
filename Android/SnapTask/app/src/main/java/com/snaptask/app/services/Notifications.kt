package com.snaptask.app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.util.UUID

/**
 * Android has no list of pending notifications, so this one is kept in a file: id → time.
 * Same rules as `TaskNotificationManager`: reminders are never cancelled and rescheduled all
 * together, only what changed is touched.
 */
object TaskNotificationManager {
    const val channelId = "task_reminders"
    const val quoteChannelId = "daily_quote"
    const val timerChannelId = "focus_timer"
    private const val pendingKey = "pendingTaskReminders"
    private const val maxPendingNotificationsBudget = 400
    private const val recurringWindowDays = 30
    private const val maxRecurringNotificationsPerTask = 30
    private val serializer = MapSerializer(String.serializer(), PendingReminder.serializer())

    const val actionMarkCompleted = "com.snaptask.app.TASK_ACTION_MARK_COMPLETED"
    const val actionSnooze1H = "com.snaptask.app.TASK_ACTION_SNOOZE_1H"
    const val actionSnoozeTomorrow = "com.snaptask.app.TASK_ACTION_SNOOZE_TOMORROW"
    const val actionFire = "com.snaptask.app.TASK_REMINDER_FIRE"

    var areTaskNotificationsEnabled by mutableStateOf(true)
        private set

    private val context get() = App.context

    fun load() {
        areTaskNotificationsEnabled = if (Defaults.contains("masterTaskNotificationsEnabled")) Defaults.bool("masterTaskNotificationsEnabled") else true
        createChannels()
    }

    private fun createChannels() {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(channelId, "task_notifications".localized.let { if (it == "task_notifications") "Task" else it }, NotificationManager.IMPORTANCE_HIGH))
        manager.createNotificationChannel(NotificationChannel(quoteChannelId, "daily_quote".localized, NotificationManager.IMPORTANCE_DEFAULT))
        manager.createNotificationChannel(NotificationChannel(timerChannelId, "focus".localized, NotificationManager.IMPORTANCE_LOW))
    }

    val isAuthorized: Boolean
        get() = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun setTaskNotificationsEnabled(enabled: Boolean) {
        areTaskNotificationsEnabled = enabled
        Defaults.set("masterTaskNotificationsEnabled", enabled)
        if (!enabled) {
            cancelAllTaskNotifications()
        } else {
            MainScope.launch { syncTaskReminders(TaskManager.tasks) }
        }
    }

    private fun pending(): MutableMap<String, PendingReminder> = (Store.load(pendingKey, serializer) ?: emptyMap()).toMutableMap()
    private fun savePending(map: Map<String, PendingReminder>) = Store.save(pendingKey, serializer, map)

    private fun fireIntent(identifier: String, flags: Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE): PendingIntent? {
        val intent = Intent(context, ReminderReceiver::class.java).setAction(actionFire).putExtra("identifier", identifier)
        return PendingIntent.getBroadcast(context, identifier.hashCode(), intent, flags)
    }

    private fun schedule(identifier: String, date: Date) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val operation = fireIntent(identifier) ?: return
        val canExact = Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()
        if (canExact) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, date.toEpochMilli(), operation)
        else alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, date.toEpochMilli(), operation)
    }

    private fun unschedule(identifier: String) {
        val operation = fireIntent(identifier, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(operation)
        operation.cancel()
    }

    private fun taskIdFrom(identifier: String): UUID? = runCatching {
        UUID.fromString(identifier.removePrefix("task_").take(36))
    }.getOrNull()

    private fun isSnooze(identifier: String): Boolean {
        val parts = identifier.split("_")
        return parts.size == 3 && !parts[2].contains(".")
    }

    fun computeRecurringNotificationDates(
        task: TodoTask,
        current: Date,
        windowDays: Int = recurringWindowDays,
        maxCount: Int = maxRecurringNotificationsPerTask,
    ): List<Date> {
        val recurrence = task.recurrence ?: return emptyList()
        if (!task.hasSpecificTime || !task.hasNotification) return emptyList()
        val dates = ArrayList<Date>()
        val defaultEnd = current.addingDays(windowDays)
        val end = recurrence.endDate?.let { minOf(it, defaultEnd) } ?: defaultEnd
        var date = current
        while (date <= end && dates.size < maxCount) {
            if (recurrence.shouldOccurOn(date)) {
                val notification = task.occurrenceDate(date).minusSeconds(task.notificationLeadTimeMinutes * 60L)
                if (notification > current) dates += notification
            }
            date = date.addingDays(1)
        }
        return dates.sorted()
    }

    suspend fun scheduleNotification(task: TodoTask): String? {
        if (!areTaskNotificationsEnabled || !isAuthorized || !task.hasSpecificTime || !task.hasNotification) return null
        val fireDate = task.startTime.minusSeconds(task.notificationLeadTimeMinutes * 60L)
        if (fireDate <= now()) return null
        val identifier = "task_${task.id.uuidString}"
        val map = pending()
        map[identifier] = PendingReminder(fireDate.toEpochMilli())
        savePending(map)
        schedule(identifier, fireDate)
        return identifier
    }

    suspend fun scheduleRecurringNotifications(task: TodoTask): List<String> {
        if (!areTaskNotificationsEnabled || !isAuthorized || !task.hasSpecificTime || !task.hasNotification || task.recurrence == null) return emptyList()
        val map = pending()
        val ids = computeRecurringNotificationDates(task, now()).map { date ->
            val identifier = "task_${task.id.uuidString}_${date.epochSeconds}"
            map[identifier] = PendingReminder(date.toEpochMilli())
            schedule(identifier, date)
            identifier
        }
        savePending(map)
        return ids
    }

    /** Makes the pending task reminders match `tasks`: only what changed is touched. */
    suspend fun syncTaskReminders(tasks: List<TodoTask>) {
        if (!areTaskNotificationsEnabled || !isAuthorized) return
        val current = now()
        val wanted = LinkedHashMap<String, Date>()
        for (task in tasks.filter { it.hasNotification && it.hasSpecificTime }) {
            if (task.recurrence != null) {
                computeRecurringNotificationDates(task, current).forEach { wanted["task_${task.id.uuidString}_${it.epochSeconds}"] = it }
            } else {
                val date = task.startTime.minusSeconds(task.notificationLeadTimeMinutes * 60L)
                if (date > current) wanted["task_${task.id.uuidString}"] = date
            }
        }
        val map = pending()
        val kept = wanted.entries.sortedBy { it.value }.take(maxPendingNotificationsBudget).associate { it.key to it.value }
        // Snoozes stay as they are; past entries go.
        for (identifier in map.keys.toList()) {
            if (isSnooze(identifier) && map[identifier]!!.time > current.toEpochMilli()) continue
            if (identifier !in kept) {
                unschedule(identifier)
                map.remove(identifier)
            }
        }
        for ((identifier, date) in kept) {
            if (map[identifier]?.time != date.toEpochMilli()) {
                map[identifier] = PendingReminder(date.toEpochMilli())
                schedule(identifier, date)
            }
        }
        savePending(map)
    }

    /** After a reboot alarms are gone: they're put back. */
    fun rescheduleAfterBoot() {
        val map = pending()
        val current = now().toEpochMilli()
        for ((identifier, reminder) in map.toMap()) {
            if (reminder.time > current) schedule(identifier, Date.ofEpochMilli(reminder.time)) else map.remove(identifier)
        }
        savePending(map)
        MainScope.launch { syncTaskReminders(TaskManager.tasks) }
    }

    private fun cancelAllTaskNotifications() {
        val map = pending()
        map.keys.filter { it.startsWith("task_") }.forEach {
            unschedule(it)
            NotificationManagerCompat.from(context).cancel(it.hashCode())
            map.remove(it)
        }
        savePending(map)
    }

    fun cancelAllNotifications() {
        cancelAllTaskNotifications()
        NotificationManagerCompat.from(context).cancelAll()
    }

    suspend fun cancelAllNotificationsForTask(taskId: UUID) {
        val prefix = "task_${taskId.uuidString}"
        val map = pending()
        map.keys.filter { it.startsWith(prefix) }.forEach {
            unschedule(it)
            NotificationManagerCompat.from(context).cancel(it.hashCode())
            map.remove(it)
        }
        savePending(map)
    }

    fun getPendingNotificationsCount(): Int = pending().count { it.key.startsWith("task_") }

    fun scheduleCustomSnoozeNotification(task: TodoTask, fireDate: Date) {
        val identifier = "task_${task.id.uuidString}_${fireDate.epochSecond}"
        val map = pending()
        map[identifier] = PendingReminder(fireDate.toEpochMilli())
        savePending(map)
        schedule(identifier, fireDate)
    }

    /** The alarm rang: shows the reminder. Same content as on iOS: the task name is the title. */
    fun deliver(identifier: String) {
        val map = pending()
        map.remove(identifier)
        savePending(map)
        if (!areTaskNotificationsEnabled || !isAuthorized) return
        val taskId = taskIdFrom(identifier) ?: return
        val task = TaskManager.task(taskId) ?: return

        fun action(name: String, requestOffset: Int) = PendingIntent.getBroadcast(
            context, identifier.hashCode() + requestOffset,
            Intent(context, ReminderReceiver::class.java).setAction(name).putExtra("identifier", identifier),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val open = PendingIntent.getActivity(
            context, identifier.hashCode() + 10,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra("openTaskId", task.id.uuidString),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val body = listOfNotNull(task.category?.name, "task_notification_title".localized).joinToString(" · ")
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(task.name)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(open)
            .addAction(0, "mark_as_completed".localized, action(actionMarkCompleted, 1))
            .addAction(0, "remind_me_in_1_hour".localized, action(actionSnooze1H, 2))
            .addAction(0, "tomorrow_morning_9am".localized, action(actionSnoozeTomorrow, 3))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(identifier.hashCode(), notification) }
    }

    fun handleAction(action: String, identifier: String) {
        NotificationManagerCompat.from(context).cancel(identifier.hashCode())
        val taskId = taskIdFrom(identifier) ?: return
        val task = TaskManager.task(taskId) ?: return
        when (action) {
            actionMarkCompleted -> TaskManager.toggleTaskCompletion(taskId, now())
            actionSnooze1H -> snooze(task, now().plusSeconds(3600))
            actionSnoozeTomorrow -> snooze(task, now().addingDays(1).withTime(9, 0))
        }
    }

    private fun snooze(task: TodoTask, date: Date) {
        scheduleCustomSnoozeNotification(task, date)
        val moved = task.recurrence?.let { task.copy(recurrence = it.postponingOccurrence(now(), date)) } ?: task.copy(startTime = date)
        MainScope.launch { TaskManager.updateTask(moved) }
    }
}

@kotlinx.serialization.Serializable
data class PendingReminder(val time: Long)

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SnapTaskApp.ensureStarted(context)
        val identifier = intent.getStringExtra("identifier") ?: ""
        when (intent.action) {
            TaskNotificationManager.actionFire -> TaskNotificationManager.deliver(identifier)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                TaskNotificationManager.rescheduleAfterBoot()
                QuoteManager.rescheduleAll()
            }
            QuoteManager.actionDailyQuote -> QuoteManager.deliverDailyQuote()
            QuoteManager.actionDiaryReminder -> QuoteManager.deliverDiary()
            PomodoroViewModel.actionPhaseEnd -> PomodoroViewModel.onPhaseAlarm()
            null -> Unit
            else -> TaskNotificationManager.handleAction(intent.action!!, identifier)
        }
    }
}
