package com.snaptask.app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.snaptask.app.R

/**
 * Shows a notification for a task reminder at the scheduled time.
 */
class TaskNotificationWorker(
    private val context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val taskId = inputData.getString(KEY_TASK_ID) ?: return Result.failure()
        val taskName = inputData.getString(KEY_TASK_NAME) ?: context.getString(R.string.task_name)
        val channelId = CHANNEL_ID
        ensureChannel(context, channelId)
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(context.getString(R.string.notification_task_reminder_title))
            .setContentText(taskName)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notificationId = taskId.hashCode().and(0x7FFF_FFFF)
        manager.notify(notificationId, notification)
        return Result.success()
    }

    companion object {
        const val KEY_TASK_ID = "task_id"
        const val KEY_TASK_NAME = "task_name"
        const val CHANNEL_ID = "snaptask_task_reminders"
        const val WORK_TAG_PREFIX = "task_reminder_"

        private fun ensureChannel(context: Context, channelId: String) {
            val channel = NotificationChannel(
                channelId,
                context.getString(R.string.notification_channel_task_reminders),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
