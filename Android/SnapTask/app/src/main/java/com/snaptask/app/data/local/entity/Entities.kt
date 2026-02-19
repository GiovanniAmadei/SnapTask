package com.snaptask.app.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import com.snaptask.app.data.model.*
import java.util.Date
import java.util.UUID

/**
 * Room entity for TodoTask.
 * Complex types (Category, Location, Recurrence, completions, subtasks, photos, voiceMemos)
 * are stored as JSON strings via TypeConverters.
 */
@Entity(tableName = "tasks")
data class TaskEntity(
    @PrimaryKey
    val id: UUID,
    val name: String,
    val description: String?,
    val location: TaskLocation?,
    @ColumnInfo(name = "start_time") val startTime: Date,
    @ColumnInfo(name = "has_specific_day") val hasSpecificDay: Boolean,
    @ColumnInfo(name = "has_specific_time") val hasSpecificTime: Boolean,
    val duration: Double,
    @ColumnInfo(name = "has_duration") val hasDuration: Boolean,
    val category: Category?,
    val priority: Priority,
    val icon: String,
    val recurrence: Recurrence?,
    @ColumnInfo(name = "pomodoro_settings") val pomodoroSettings: PomodoroSettings?,
    val completions: Map<Long, TaskCompletion>,
    val subtasks: List<Subtask>,
    @ColumnInfo(name = "completion_dates") val completionDates: List<Date>,
    @ColumnInfo(name = "creation_date") val creationDate: Date,
    @ColumnInfo(name = "last_modified_date") val lastModifiedDate: Date,
    @ColumnInfo(name = "has_reward_points") val hasRewardPoints: Boolean,
    @ColumnInfo(name = "reward_points") val rewardPoints: Int,
    @ColumnInfo(name = "total_tracked_time") val totalTrackedTime: Double,
    @ColumnInfo(name = "last_tracked_date") val lastTrackedDate: Date?,
    @ColumnInfo(name = "has_notification") val hasNotification: Boolean,
    @ColumnInfo(name = "notification_id") val notificationId: String?,
    @ColumnInfo(name = "photo_path") val photoPath: String?,
    @ColumnInfo(name = "photo_thumbnail_path") val photoThumbnailPath: String?,
    val photos: List<TaskPhoto>,
    @ColumnInfo(name = "voice_memos") val voiceMemos: List<TaskVoiceMemo>,
    @ColumnInfo(name = "time_scope") val timeScope: TaskTimeScope,
    @ColumnInfo(name = "scope_start_date") val scopeStartDate: Date?,
    @ColumnInfo(name = "scope_end_date") val scopeEndDate: Date?,
    @ColumnInfo(name = "notification_lead_time_minutes") val notificationLeadTimeMinutes: Int,
    @ColumnInfo(name = "auto_carry_over") val autoCarryOver: Boolean,
    @ColumnInfo(name = "domain_id") val domainId: UUID?,
    @ColumnInfo(name = "goal_id") val goalId: UUID?,
) {
    fun toModel(): TodoTask = TodoTask(
        id = id, name = name, description = description, location = location,
        startTime = startTime, hasSpecificDay = hasSpecificDay, hasSpecificTime = hasSpecificTime,
        duration = duration, hasDuration = hasDuration, category = category, priority = priority,
        icon = icon, recurrence = recurrence, pomodoroSettings = pomodoroSettings,
        completions = completions, subtasks = subtasks, completionDates = completionDates,
        creationDate = creationDate, lastModifiedDate = lastModifiedDate,
        hasRewardPoints = hasRewardPoints, rewardPoints = rewardPoints,
        totalTrackedTime = totalTrackedTime, lastTrackedDate = lastTrackedDate,
        hasNotification = hasNotification, notificationId = notificationId,
        photoPath = photoPath, photoThumbnailPath = photoThumbnailPath,
        photos = photos, voiceMemos = voiceMemos, timeScope = timeScope,
        scopeStartDate = scopeStartDate, scopeEndDate = scopeEndDate,
        notificationLeadTimeMinutes = notificationLeadTimeMinutes,
        autoCarryOver = autoCarryOver, domainId = domainId, goalId = goalId,
    )

    companion object {
        fun fromModel(task: TodoTask): TaskEntity = TaskEntity(
            id = task.id, name = task.name, description = task.description,
            location = task.location, startTime = task.startTime,
            hasSpecificDay = task.hasSpecificDay, hasSpecificTime = task.hasSpecificTime,
            duration = task.duration, hasDuration = task.hasDuration,
            category = task.category, priority = task.priority, icon = task.icon,
            recurrence = task.recurrence, pomodoroSettings = task.pomodoroSettings,
            completions = task.completions, subtasks = task.subtasks,
            completionDates = task.completionDates, creationDate = task.creationDate,
            lastModifiedDate = task.lastModifiedDate, hasRewardPoints = task.hasRewardPoints,
            rewardPoints = task.rewardPoints, totalTrackedTime = task.totalTrackedTime,
            lastTrackedDate = task.lastTrackedDate, hasNotification = task.hasNotification,
            notificationId = task.notificationId, photoPath = task.photoPath,
            photoThumbnailPath = task.photoThumbnailPath, photos = task.photos,
            voiceMemos = task.voiceMemos, timeScope = task.timeScope,
            scopeStartDate = task.scopeStartDate, scopeEndDate = task.scopeEndDate,
            notificationLeadTimeMinutes = task.notificationLeadTimeMinutes,
            autoCarryOver = task.autoCarryOver, domainId = task.domainId,
            goalId = task.goalId,
        )
    }
}

/**
 * Room entity for Category (standalone management).
 */
@Entity(tableName = "categories")
data class CategoryEntity(
    @PrimaryKey val id: UUID,
    val name: String,
    val color: String,
) {
    fun toModel(): Category = Category(id = id, name = name, color = color)

    companion object {
        fun fromModel(category: Category): CategoryEntity =
            CategoryEntity(id = category.id, name = category.name, color = category.color)
    }
}

/**
 * Room entity for Reward, matching iOS Reward struct.
 */
@Entity(tableName = "rewards")
data class RewardEntity(
    @PrimaryKey val id: UUID,
    val name: String,
    val description: String?,
    @ColumnInfo(name = "points_cost") val pointsCost: Int,
    val icon: String,
    val frequency: RewardFrequency,
    val redemptions: List<Date>,
    @ColumnInfo(name = "category_id") val categoryId: UUID?,
    @ColumnInfo(name = "category_name") val categoryName: String?,
    @ColumnInfo(name = "creation_date") val creationDate: Date,
    @ColumnInfo(name = "last_modified_date") val lastModifiedDate: Date,
) {
    fun toModel(): Reward = Reward(
        id = id, name = name, description = description,
        pointsCost = pointsCost, icon = icon, frequency = frequency,
        redemptions = redemptions, creationDate = creationDate,
        lastModifiedDate = lastModifiedDate,
        categoryId = categoryId, categoryName = categoryName,
    )

    companion object {
        fun fromModel(reward: Reward): RewardEntity = RewardEntity(
            id = reward.id, name = reward.name, description = reward.description,
            pointsCost = reward.pointsCost, icon = reward.icon,
            frequency = reward.frequency, redemptions = reward.redemptions,
            categoryId = reward.categoryId, categoryName = reward.categoryName,
            creationDate = reward.creationDate, lastModifiedDate = reward.lastModifiedDate,
        )
    }
}

/**
 * Room entity for FinanceEntry.
 * Matches iOS FinanceEntry struct 1:1.
 */
@Entity(tableName = "finance_entries")
data class FinanceEntryEntity(
    @PrimaryKey val id: UUID,
    val name: String,
    val amount: Double,
    val type: FinanceEntryType,
    val category: FinanceCategory,
    @ColumnInfo(name = "custom_category_id") val customCategoryId: UUID?,
    val date: Date,
    val notes: String?,
    @ColumnInfo(name = "is_recurring") val isRecurring: Boolean,
    @ColumnInfo(name = "recurring_frequency") val recurringFrequency: SubscriptionFrequency?,
    @ColumnInfo(name = "recurring_end_date") val recurringEndDate: Date?,
    val tags: List<String>,
    @ColumnInfo(name = "creation_date") val creationDate: Date,
    @ColumnInfo(name = "last_modified_date") val lastModifiedDate: Date,
) {
    fun toModel(): FinanceEntry = FinanceEntry(
        id = id, name = name, amount = amount, type = type,
        category = category, customCategoryId = customCategoryId,
        date = date, notes = notes, isRecurring = isRecurring,
        recurringFrequency = recurringFrequency,
        recurringEndDate = recurringEndDate,
        tags = tags,
        creationDate = creationDate, lastModifiedDate = lastModifiedDate,
    )

    companion object {
        fun fromModel(entry: FinanceEntry): FinanceEntryEntity = FinanceEntryEntity(
            id = entry.id, name = entry.name, amount = entry.amount,
            type = entry.type, category = entry.category,
            customCategoryId = entry.customCategoryId, date = entry.date,
            notes = entry.notes, isRecurring = entry.isRecurring,
            recurringFrequency = entry.recurringFrequency,
            recurringEndDate = entry.recurringEndDate,
            tags = entry.tags,
            creationDate = entry.creationDate,
            lastModifiedDate = entry.lastModifiedDate,
        )
    }
}

/**
 * Room entity for JournalEntry.
 */
@Entity(tableName = "journal_entries")
data class JournalEntryEntity(
    @PrimaryKey val id: UUID,
    val date: Date,
    val mood: Mood?,
    val title: String?,
    val content: String?,
    val photos: List<TaskPhoto>,
    @ColumnInfo(name = "voice_memos") val voiceMemos: List<TaskVoiceMemo>,
    val tags: List<String>,
    val gratitude: List<String>,
    @ColumnInfo(name = "creation_date") val creationDate: Date,
    @ColumnInfo(name = "last_modified_date") val lastModifiedDate: Date,
) {
    fun toModel(): JournalEntry = JournalEntry(
        id = id, date = date, mood = mood, title = title,
        content = content, photos = photos, voiceMemos = voiceMemos,
        tags = tags, gratitude = gratitude,
        creationDate = creationDate, lastModifiedDate = lastModifiedDate,
    )

    companion object {
        fun fromModel(entry: JournalEntry): JournalEntryEntity = JournalEntryEntity(
            id = entry.id, date = entry.date, mood = entry.mood,
            title = entry.title, content = entry.content,
            photos = entry.photos, voiceMemos = entry.voiceMemos,
            tags = entry.tags, gratitude = entry.gratitude,
            creationDate = entry.creationDate,
            lastModifiedDate = entry.lastModifiedDate,
        )
    }
}

/**
 * Room entity for TrackingSession.
 */
@Entity(tableName = "tracking_sessions")
data class TrackingSessionEntity(
    @PrimaryKey val id: UUID,
    @ColumnInfo(name = "task_id") val taskId: UUID?,
    @ColumnInfo(name = "task_name") val taskName: String?,
    val mode: TrackingMode,
    @ColumnInfo(name = "category_id") val categoryId: UUID?,
    @ColumnInfo(name = "category_name") val categoryName: String?,
    @ColumnInfo(name = "start_time") val startTime: Date,
    @ColumnInfo(name = "device_type") val deviceType: DeviceType,
    @ColumnInfo(name = "device_name") val deviceName: String,
    @ColumnInfo(name = "creation_date") val creationDate: Date,
    @ColumnInfo(name = "last_modified_date") val lastModifiedDate: Date,
    @ColumnInfo(name = "is_running") val isRunning: Boolean,
    @ColumnInfo(name = "is_paused") val isPaused: Boolean,
    @ColumnInfo(name = "elapsed_time") val elapsedTime: Double,
    @ColumnInfo(name = "total_duration") val totalDuration: Double,
    @ColumnInfo(name = "paused_duration") val pausedDuration: Double,
    @ColumnInfo(name = "is_completed") val isCompleted: Boolean,
    @ColumnInfo(name = "end_time") val endTime: Date?,
    val notes: String?,
) {
    fun toModel(): TrackingSession = TrackingSession(
        id = id, taskId = taskId, taskName = taskName, mode = mode,
        categoryId = categoryId, categoryName = categoryName,
        startTime = startTime, deviceType = deviceType, deviceName = deviceName,
        creationDate = creationDate, lastModifiedDate = lastModifiedDate,
        isRunning = isRunning, isPaused = isPaused, elapsedTime = elapsedTime,
        totalDuration = totalDuration, pausedDuration = pausedDuration,
        isCompleted = isCompleted, endTime = endTime, notes = notes,
    )

    companion object {
        fun fromModel(session: TrackingSession): TrackingSessionEntity = TrackingSessionEntity(
            id = session.id, taskId = session.taskId, taskName = session.taskName,
            mode = session.mode, categoryId = session.categoryId,
            categoryName = session.categoryName, startTime = session.startTime,
            deviceType = session.deviceType, deviceName = session.deviceName,
            creationDate = session.creationDate, lastModifiedDate = session.lastModifiedDate,
            isRunning = session.isRunning, isPaused = session.isPaused,
            elapsedTime = session.elapsedTime, totalDuration = session.totalDuration,
            pausedDuration = session.pausedDuration, isCompleted = session.isCompleted,
            endTime = session.endTime, notes = session.notes,
        )
    }
}
