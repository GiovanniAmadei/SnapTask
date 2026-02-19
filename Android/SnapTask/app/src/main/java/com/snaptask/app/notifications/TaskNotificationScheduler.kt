package com.snaptask.app.notifications

import android.content.Context
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.snaptask.app.data.model.TodoTask
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Calendar
import java.util.concurrent.TimeUnit
import javax.inject.Inject

/**
 * Schedules and cancels task reminder notifications via WorkManager.
 */
class TaskNotificationScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun scheduleReminder(task: TodoTask) {
        if (!task.hasNotification || !task.hasSpecificTime) return
        val triggerAt = reminderTime(task)
        if (triggerAt <= System.currentTimeMillis()) return
        val delay = triggerAt - System.currentTimeMillis()
        val data = Data.Builder()
            .putString(TaskNotificationWorker.KEY_TASK_ID, task.id.toString())
            .putString(TaskNotificationWorker.KEY_TASK_NAME, task.name)
            .build()
        val request = OneTimeWorkRequestBuilder<TaskNotificationWorker>()
            .setInputData(data)
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .addTag("${TaskNotificationWorker.WORK_TAG_PREFIX}${task.id}")
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            "task_reminder_${task.id}",
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun cancelReminder(taskId: java.util.UUID) {
        WorkManager.getInstance(context).cancelUniqueWork("task_reminder_$taskId")
    }

    private fun reminderTime(task: TodoTask): Long {
        val cal = Calendar.getInstance()
        cal.time = task.startTime
        cal.add(Calendar.MINUTE, -task.notificationLeadTimeMinutes)
        return cal.timeInMillis
    }
}
