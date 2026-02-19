package com.snaptask.app.data.model

import java.util.Calendar
import java.util.Date
import java.util.UUID

/**
 * Reward frequency, matching iOS RewardFrequency enum.
 */
enum class RewardFrequency(val displayName: String, val shortDisplayName: String, val iconName: String) {
    DAILY("Daily", "Day", "sun.max"),
    WEEKLY("Weekly", "Wk", "calendar.circle"),
    MONTHLY("Monthly", "Mo", "calendar"),
    YEARLY("Yearly", "Yr", "star.circle"),
    ONE_TIME("One Time", "1x", "infinity");

    companion object {
        fun fromString(value: String): RewardFrequency = entries.find {
            it.name.equals(value, ignoreCase = true)
        } ?: DAILY
    }
}

/**
 * Reward model, matching iOS Reward struct faithfully.
 * Supports both general rewards (no category) and category-specific rewards.
 */
data class Reward(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val description: String? = null,
    val pointsCost: Int,
    val frequency: RewardFrequency = RewardFrequency.DAILY,
    val icon: String = "gift",
    val redemptions: List<Date> = emptyList(),
    val creationDate: Date = Date(),
    val lastModifiedDate: Date = Date(),
    val categoryId: UUID? = null,
    val categoryName: String? = null,
) {
    /** True if this reward is not bound to a specific category. */
    val isGeneralReward: Boolean get() = categoryId == null

    /**
     * Check if the reward can be redeemed with available points.
     */
    fun canRedeem(availablePoints: Int): Boolean {
        return availablePoints >= pointsCost
    }

    /**
     * Check if this reward has been redeemed in the current period.
     */
    fun hasBeenRedeemed(on: Date = Date()): Boolean {
        val calendar = Calendar.getInstance()

        return when (frequency) {
            RewardFrequency.DAILY -> {
                calendar.time = on
                val today = startOfDay(calendar)
                redemptions.any { startOfDay(it) == today }
            }
            RewardFrequency.WEEKLY -> {
                val weekStart = startOfWeek(on)
                val weekEnd = Calendar.getInstance().apply {
                    time = weekStart
                    add(Calendar.DAY_OF_YEAR, 7)
                }.time
                redemptions.any { it >= weekStart && it < weekEnd }
            }
            RewardFrequency.MONTHLY -> {
                val monthStart = startOfMonth(on)
                val monthEnd = Calendar.getInstance().apply {
                    time = monthStart
                    add(Calendar.MONTH, 1)
                }.time
                redemptions.any { it >= monthStart && it < monthEnd }
            }
            RewardFrequency.YEARLY -> {
                val yearStart = startOfYear(on)
                val yearEnd = Calendar.getInstance().apply {
                    time = yearStart
                    add(Calendar.YEAR, 1)
                }.time
                redemptions.any { it >= yearStart && it < yearEnd }
            }
            RewardFrequency.ONE_TIME -> redemptions.isNotEmpty()
        }
    }

    /**
     * Get redemption info for the current period.
     */
    fun redemptionInfo(on: Date = Date()): Pair<Boolean, Int> {
        val calendar = Calendar.getInstance()
        val relevantRedemptions = redemptions.filter { redemptionDate ->
            when (frequency) {
                RewardFrequency.DAILY -> {
                    calendar.time = on
                    val today = startOfDay(calendar)
                    startOfDay(redemptionDate) == today
                }
                RewardFrequency.WEEKLY -> {
                    val weekStart = startOfWeek(on)
                    val weekEnd = Calendar.getInstance().apply {
                        time = weekStart
                        add(Calendar.DAY_OF_YEAR, 7)
                    }.time
                    redemptionDate >= weekStart && redemptionDate < weekEnd
                }
                RewardFrequency.MONTHLY -> {
                    val monthStart = startOfMonth(on)
                    val monthEnd = Calendar.getInstance().apply {
                        time = monthStart
                        add(Calendar.MONTH, 1)
                    }.time
                    redemptionDate >= monthStart && redemptionDate < monthEnd
                }
                RewardFrequency.YEARLY -> {
                    val yearStart = startOfYear(on)
                    val yearEnd = Calendar.getInstance().apply {
                        time = yearStart
                        add(Calendar.YEAR, 1)
                    }.time
                    redemptionDate >= yearStart && redemptionDate < yearEnd
                }
                RewardFrequency.ONE_TIME -> true
            }
        }
        return Pair(relevantRedemptions.isNotEmpty(), relevantRedemptions.size)
    }

    companion object {
        private fun startOfDay(calendar: Calendar): Long {
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            return calendar.timeInMillis
        }

        private fun startOfDay(date: Date): Long {
            val c = Calendar.getInstance()
            c.time = date
            return startOfDay(c)
        }

        private fun startOfWeek(date: Date): Date {
            val c = Calendar.getInstance()
            c.time = date
            c.set(Calendar.DAY_OF_WEEK, c.firstDayOfWeek)
            c.set(Calendar.HOUR_OF_DAY, 0)
            c.set(Calendar.MINUTE, 0)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            return c.time
        }

        private fun startOfMonth(date: Date): Date {
            val c = Calendar.getInstance()
            c.time = date
            c.set(Calendar.DAY_OF_MONTH, 1)
            c.set(Calendar.HOUR_OF_DAY, 0)
            c.set(Calendar.MINUTE, 0)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            return c.time
        }

        private fun startOfYear(date: Date): Date {
            val c = Calendar.getInstance()
            c.time = date
            c.set(Calendar.DAY_OF_YEAR, 1)
            c.set(Calendar.HOUR_OF_DAY, 0)
            c.set(Calendar.MINUTE, 0)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            return c.time
        }
    }
}

/**
 * Points history entry, for tracking point changes.
 */
data class PointsHistory(
    val id: UUID = UUID.randomUUID(),
    val points: Int,
    val reason: String,
    val taskId: UUID? = null,
    val rewardId: UUID? = null,
    val categoryId: UUID? = null,
    val frequency: RewardFrequency? = null,
    val date: Date = Date(),
)
