@file:UseSerializers(DateSerializer::class, UUIDSerializer::class)

package com.snaptask.app

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.util.UUID

// MARK: - Tracking

@Serializable
enum class TrackingMode(val icon: String) {
    @SerialName("simple") simple("timer"),
    @SerialName("pomodoro") pomodoro("clock.fill");

    val displayName: String
        get() = when (this) {
            simple -> "simple_timer".localized
            pomodoro -> "pomodoro_mode".localized
        }
    val description: String
        get() = when (this) {
            simple -> "simple_timer_description".localized
            pomodoro -> "pomodoro_mode_description".localized
        }
}

@Serializable
enum class DeviceType(val displayName: String, val icon: String) {
    @SerialName("iPhone") iPhone("iPhone", "iphone"),
    @SerialName("iPad") iPad("iPad", "ipad"),
    @SerialName("Mac") mac("Mac", "desktopcomputer"),
    @SerialName("Apple Watch") appleWatch("Apple Watch", "applewatch"),
    @SerialName("Android") android("Android", "iphone"),
    @SerialName("Unknown") unknown("Unknown Device", "questionmark.circle");

    companion object {
        val current: DeviceType get() = android
    }
}

@Serializable
data class TrackingSession(
    val id: UUID = UUID.randomUUID(),
    val taskId: UUID? = null,
    val taskName: String? = null,
    val mode: TrackingMode,
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    val startTime: Date = now(),
    val deviceType: DeviceType = DeviceType.current,
    val deviceName: String = currentDeviceName(),
    val creationDate: Date = now(),
    val lastModifiedDate: Date = now(),
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val elapsedTime: Double = 0.0,
    val totalDuration: Double = 0.0,
    val pausedDuration: Double = 0.0,
    val isCompleted: Boolean = false,
    val endTime: Date? = null,
    val notes: String? = null,
) {
    val effectiveWorkTime: Double get() = totalDuration - pausedDuration
    val isForSpecificTask: Boolean get() = taskId != null
    val deviceDisplayInfo: String get() = "${deviceType.displayName} · $deviceName"

    fun completed(): TrackingSession = copy(
        isCompleted = true,
        isRunning = false,
        isPaused = false,
        endTime = now(),
        totalDuration = elapsedTime,
        lastModifiedDate = now(),
    )
}

fun currentDeviceName(): String = android.os.Build.MODEL ?: "Android"

// MARK: - Rewards

@Serializable
enum class RewardFrequency(val iconName: String) {
    daily("sun.max"),
    weekly("calendar.circle"),
    monthly("calendar"),
    yearly("star.circle"),
    oneTime("infinity");

    val displayName: String
        get() = when (this) {
            daily -> "daily".localized
            weekly -> "weekly".localized
            monthly -> "monthly".localized
            yearly -> "yearly".localized
            oneTime -> "onetime_rewards_once".localized
        }
    val shortDisplayName: String
        get() = when (this) {
            daily -> "day".localized
            weekly -> "week_short".localized
            monthly -> "month_short".localized
            yearly -> "year_short".localized
            oneTime -> "1x"
        }
    /** Short label for segmented pickers (displayName of `oneTime` is a whole sentence). */
    val pickerLabel: String get() = if (this == oneTime) "reward_frequency_once".localized else displayName
}

@Serializable
data class Reward(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val description: String? = null,
    val pointsCost: Int,
    val frequency: RewardFrequency = RewardFrequency.daily,
    val icon: String = "gift",
    val redemptions: List<Date> = emptyList(),
    val creationDate: Date = now(),
    val lastModifiedDate: Date = now(),
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    /** Removed, but its points stay spent: hidden from the list, still counted and shown in the history. */
    val archivedDate: Date? = null,
) {
    val isArchived: Boolean get() = archivedDate != null
    val isGeneralReward: Boolean get() = categoryId == null

    fun canRedeem(availablePoints: Int): Boolean = availablePoints >= pointsCost

    fun hasBeenRedeemed(date: Date = now()): Boolean = when (frequency) {
        RewardFrequency.daily -> redemptions.any { it.isSameDay(date) }
        RewardFrequency.weekly -> {
            val start = date.startOfWeek()
            val end = start.addingDays(7)
            redemptions.any { it >= start && it < end }
        }
        RewardFrequency.monthly -> redemptions.any { it.isSameMonth(date) }
        RewardFrequency.yearly -> redemptions.any { it.isSameYear(date) }
        RewardFrequency.oneTime -> redemptions.isNotEmpty()
    }

    companion object {
        /** Redemptions rounded down to the second, each one counted once, oldest first. */
        fun normalizedRedemptions(dates: List<Date>): List<Date> {
            val result = ArrayList<Date>()
            for (date in dates.sorted()) {
                val second = date.wholeSecond()
                val last = result.lastOrNull()
                if (last != null && second.timeIntervalSince(last) < 2) continue
                result += second
            }
            return result
        }
    }
}

@Serializable
data class PointsHistory(
    val id: UUID = UUID.randomUUID(),
    val date: Date,
    val points: Int,
    val frequency: RewardFrequency,
    val categoryId: UUID? = null,
    val categoryName: String? = null,
) {
    val isGeneralPoints: Boolean get() = categoryId == null
}

@Serializable
data class RedeemedReward(
    val id: UUID = UUID.randomUUID(),
    val rewardId: UUID,
    val rewardName: String,
    val pointsCost: Int,
    val redeemedDate: Date,
)

// MARK: - Journal

@Serializable
enum class MoodType(val emoji: String, val colorHex: String, val score: Int) {
    awful("😫", "#991B1B", 1),
    bad("😕", "#DC2626", 2),
    poor("🙁", "#F97316", 3),
    neutral("😐", "#9CA3AF", 4),
    good("🙂", "#22C55E", 5),
    great("😄", "#16A34A", 6),
    excellent("🤩", "#0EA5E9", 7);

    val localizedName: String get() = "mood_$name".localized
}

@Serializable
data class MoodEntry(
    val id: UUID = UUID.randomUUID(),
    val date: Date,
    val type: MoodType,
    val notes: String? = null,
)

@Serializable
data class JournalPhoto(
    val id: UUID = UUID.randomUUID(),
    val photoPath: String,
    val thumbnailPath: String,
    val createdAt: Date = now(),
)

@Serializable
data class JournalVoiceMemo(
    val id: UUID = UUID.randomUUID(),
    val audioPath: String,
    val duration: Double,
    val createdAt: Date = now(),
    val name: String? = null,
) {
    val displayName: String get() = name ?: "voice_memo".localized
}

@Serializable
data class JournalEntry(
    val id: UUID = UUID.randomUUID(),
    val date: Date,
    val title: String = "",
    val text: String = "",
    val worthItText: String = "",
    val isWorthItHidden: Boolean = false,
    val mood: MoodType? = null,
    val tags: List<String> = emptyList(),
    val voiceMemos: List<JournalVoiceMemo> = emptyList(),
    val photos: List<JournalPhoto> = emptyList(),
    val createdAt: Date = now(),
    val updatedAt: Date = distantPast,
) {
    val isEmpty: Boolean
        get() = title.isBlank() && text.isBlank() && worthItText.isBlank() && mood == null &&
            tags.isEmpty() && voiceMemos.isEmpty() && photos.isEmpty()
    val hasAttachments: Boolean get() = voiceMemos.isNotEmpty() || photos.isNotEmpty()
}

// MARK: - Quotes and news

@Serializable
data class Quote(
    val id: UUID = UUID.randomUUID(),
    val text: String,
    val author: String,
    val lastUpdated: Date = now(),
) {
    companion object {
        val placeholder = Quote(text = "The journey of a thousand miles begins with a single step.", author = "Lao Tzu")
    }
}

@Serializable
enum class NewsType(val icon: String, val color: String) {
    @SerialName("recent") recentUpdate("checkmark.circle.fill", "#34C759"),
    @SerialName("coming_soon") comingSoon("clock.fill", "#FF9500"),
    @SerialName("roadmap") roadmap("map.fill", "#007AFF");

    val rawValue: String
        get() = when (this) {
            recentUpdate -> "recent"
            comingSoon -> "coming_soon"
            roadmap -> "roadmap"
        }

    val displayName: String
        get() = when (this) {
            recentUpdate -> "Recent Update"
            comingSoon -> "Coming Soon"
            roadmap -> "Roadmap"
        }
}

@Serializable
data class UpdateNews(
    val id: String,
    val title: String,
    val description: String,
    val version: String? = null,
    val date: Date? = null,
    val type: NewsType,
    val isHighlighted: Boolean = false,
)

object MediaLimits {
    const val maxPhotosPerTask = 3
    const val maxVoiceMemosPerTask = 3
    const val maxPhotosPerJournal = 5
    const val maxVoiceMemosPerJournal = 3
    const val maxVoiceMemoDuration = 5.0 * 60
    const val maxCompletionNoteCharacters = 10_000
    fun canAddPhoto(currentCount: Int) = currentCount < maxPhotosPerTask
    fun canAddVoiceMemo(currentCount: Int) = currentCount < maxVoiceMemosPerTask
    fun remainingPhotos(currentCount: Int) = maxOf(0, maxPhotosPerTask - currentCount)
    fun remainingVoiceMemos(currentCount: Int) = maxOf(0, maxVoiceMemosPerTask - currentCount)
    fun canAddJournalPhoto(currentCount: Int) = currentCount < maxPhotosPerJournal
    fun canAddJournalVoiceMemo(currentCount: Int) = currentCount < maxVoiceMemosPerJournal
    fun remainingJournalPhotos(currentCount: Int) = maxOf(0, maxPhotosPerJournal - currentCount)
    fun remainingJournalVoiceMemos(currentCount: Int) = maxOf(0, maxVoiceMemosPerJournal - currentCount)
    fun formattedMaxDuration() = "${(maxVoiceMemoDuration / 60).toInt()} min"
}

/** The icons a task can have, by group. */
object TaskIconCatalog {
    data class Group(val titleKey: String, val icons: List<String>)

    val groups = listOf(
        Group("icon_category_general", listOf("circle.fill", "circle", "checkmark.circle.fill", "flag.fill", "bookmark.fill", "tag.fill", "star.fill", "sparkles", "crown.fill")),
        Group("icon_category_time_planning", listOf("bell.fill", "alarm", "calendar", "clock.fill")),
        Group("icon_category_study_work", listOf("book.fill", "text.book.closed.fill", "graduationcap.fill", "briefcase.fill", "building.2.fill", "pencil", "pencil.and.list.clipboard", "list.bullet", "checklist", "note.text")),
        Group("icon_category_energy_nature", listOf("bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "lightbulb.fill")),
        Group("icon_category_sport_wellbeing", listOf("dumbbell.fill", "figure.run", "bicycle", "sportscourt.fill", "heart.fill", "stethoscope", "cross.case.fill", "pills.fill")),
        Group("icon_category_food_drink", listOf("cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill")),
        Group("icon_category_home_security", listOf("house.fill", "bed.double.fill", "moon.fill", "zzz", "key.fill", "lock.fill")),
        Group("icon_category_travel_places", listOf("car.fill", "bus.fill", "tram.fill", "airplane", "ferry.fill", "globe", "map.fill", "mappin.and.ellipse")),
        Group("icon_category_shopping_money", listOf("cart.fill", "bag.fill", "creditcard.fill", "banknote.fill", "receipt.fill", "gift.fill", "party.popper.fill")),
        Group("icon_category_creativity_media", listOf("brain.head.profile", "paintbrush.fill", "music.note", "headphones", "tv.fill", "camera.fill", "gamecontroller.fill", "dice.fill")),
        Group("icon_category_communication", listOf("phone.fill", "video.fill", "message.fill", "bubble.left.and.bubble.right.fill", "envelope.fill", "paperplane.fill")),
        Group("icon_category_weather", listOf("sun.max.fill", "cloud.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.snow.fill", "wind", "umbrella.fill")),
        Group("icon_category_animals", listOf("pawprint.fill", "ladybug.fill", "tortoise.fill", "hare.fill", "bird.fill", "fish.fill")),
    )
    val allIcons: List<String> get() = groups.flatMap { it.icons }
}

// MARK: - Feedback

@Serializable
enum class FeedbackCategory(val icon: String, val color: String) {
    @SerialName("bug_report") bugReport("ladybug.fill", "#FF3B30"),
    @SerialName("feature_request") featureRequest("lightbulb.fill", "#007AFF"),
    @SerialName("general_feedback") general("message.fill", "#34C759");

    val rawValue: String
        get() = when (this) {
            bugReport -> "bug_report"
            featureRequest -> "feature_request"
            general -> "general_feedback"
        }
    val displayName: String
        get() = when (this) {
            bugReport -> "bug_report_category".localized
            featureRequest -> "feature_request_category".localized
            general -> "general_category".localized
        }
}

@Serializable
enum class FeedbackStatus(val color: String) {
    @SerialName("pending") pending("#FF9500"),
    @SerialName("in_progress") inProgress("#007AFF"),
    @SerialName("completed") completed("#34C759"),
    @SerialName("rejected") rejected("#FF3B30");

    val rawValue: String
        get() = when (this) {
            pending -> "pending"
            inProgress -> "in_progress"
            completed -> "completed"
            rejected -> "rejected"
        }
    val displayName: String
        get() = when (this) {
            pending -> "feedback_status_pending".localized
            inProgress -> "feedback_status_in_progress".localized
            completed -> "feedback_status_completed".localized
            rejected -> "feedback_status_rejected".localized
        }
}

private fun isCurrentAuthor(authorId: String?): Boolean {
    if (authorId == null) return false
    return authorId == Defaults.string("firebase_user_id") || authorId == Defaults.string("anonymous_user_id")
}

@Serializable
data class FeedbackReply(
    val id: UUID = UUID.randomUUID(),
    val feedbackId: UUID,
    val content: String,
    val authorId: String? = null,
    val authorName: String? = null,
    val creationDate: Date = now(),
    val isFromDeveloper: Boolean = false,
    val likes: Int = 0,
    val hasLiked: Boolean = false,
) {
    val isAuthoredByCurrentUser: Boolean get() = isCurrentAuthor(authorId)
}

@Serializable
data class FeedbackItem(
    val id: UUID = UUID.randomUUID(),
    val title: String,
    val description: String,
    val category: FeedbackCategory,
    val status: FeedbackStatus = FeedbackStatus.pending,
    val creationDate: Date = now(),
    val authorId: String? = null,
    val authorName: String? = null,
    val votes: Int = 0,
    val hasVoted: Boolean = false,
    val replies: List<FeedbackReply> = emptyList(),
    val likes: Int = 0,
    val hasLiked: Boolean = false,
) {
    val isAuthoredByCurrentUser: Boolean get() = isCurrentAuthor(authorId)
}

// MARK: - Calendar

@Serializable
data class CalendarIntegrationSettings(
    val isEnabled: Boolean = false,
    val provider: CalendarProvider = CalendarProvider.apple,
    val selectedCalendarId: String? = null,
    val selectedCalendarName: String? = null,
    val autoSyncOnTaskCreate: Boolean = true,
    val autoSyncOnTaskUpdate: Boolean = true,
    val autoSyncOnTaskComplete: Boolean = false,
    val syncRecurringTasks: Boolean = true,
)

/** `apple` is the device calendar on Android (it holds Google's calendars as well). */
@Serializable
enum class CalendarProvider(val iconName: String) {
    apple("calendar"),
    google("calendar.badge.clock");

    val displayName: String
        get() = when (this) {
            apple -> "device_calendar".localized
            google -> "google_calendar".localized
        }
}
