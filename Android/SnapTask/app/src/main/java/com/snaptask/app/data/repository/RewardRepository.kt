package com.snaptask.app.data.repository

import com.snaptask.app.data.local.dao.RewardDao
import com.snaptask.app.data.local.entity.RewardEntity
import com.snaptask.app.data.model.Reward
import com.snaptask.app.data.model.RewardFrequency
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.Calendar
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for Reward operations.
 * Mirrors iOS RewardManager — manages rewards CRUD and points calculations.
 *
 * Points are tracked per-day in a local map (dailyPointsHistory),
 * with optional per-category tracking (categoryPointsHistory).
 */
@Singleton
class RewardRepository @Inject constructor(
    private val rewardDao: RewardDao,
) {
    // In-memory points history (mirroring iOS approach with UserDefaults)
    // In a production app, these would also be persisted via DataStore or Room
    private val dailyPointsHistory: MutableMap<Long, Int> = mutableMapOf()
    private val categoryPointsHistory: MutableMap<UUID, MutableMap<Long, Int>> = mutableMapOf()

    // ---- Rewards CRUD ----

    fun getAllRewards(): Flow<List<Reward>> =
        rewardDao.getAllRewards().map { entities -> entities.map { it.toModel() } }

    suspend fun getRewardById(id: UUID): Reward? =
        rewardDao.getRewardById(id)?.toModel()

    suspend fun addReward(reward: Reward) {
        rewardDao.insertReward(RewardEntity.fromModel(reward))
    }

    suspend fun updateReward(reward: Reward) {
        rewardDao.updateReward(RewardEntity.fromModel(reward))
    }

    suspend fun deleteReward(reward: Reward) {
        rewardDao.deleteReward(RewardEntity.fromModel(reward))
    }

    // ---- Redemption ----

    suspend fun redeemReward(reward: Reward, on: Date = Date()) {
        val availablePoints = if (reward.isGeneralReward) {
            availablePoints(reward.frequency, on)
        } else {
            availablePointsForCategory(reward.categoryId!!, reward.frequency, on)
        }

        if (reward.canRedeem(availablePoints)) {
            val points = -reward.pointsCost

            if (reward.isGeneralReward) {
                if (availablePoints >= reward.pointsCost) {
                    addPoints(points, on)
                }
            } else {
                if (availablePoints >= reward.pointsCost) {
                    addPointsToCategory(points, reward.categoryId!!, on)
                }
            }

            // Mark as redeemed
            val updatedReward = reward.copy(
                redemptions = reward.redemptions + on,
                lastModifiedDate = Date(),
            )
            updateReward(updatedReward)
        }
    }

    // ---- Points Management ----

    fun addPoints(points: Int, on: Date = Date()) {
        val startOfDay = startOfDayMillis(on)
        val current = dailyPointsHistory[startOfDay] ?: 0
        dailyPointsHistory[startOfDay] = maxOf(current + points, 0)
    }

    fun addPointsToCategory(points: Int, categoryId: UUID, on: Date = Date()) {
        val startOfDay = startOfDayMillis(on)
        val categoryHistory = categoryPointsHistory.getOrPut(categoryId) { mutableMapOf() }
        val current = categoryHistory[startOfDay] ?: 0
        categoryHistory[startOfDay] = maxOf(current + points, 0)
    }

    fun availablePoints(frequency: RewardFrequency, on: Date = Date()): Int {
        val calendar = Calendar.getInstance()

        return when (frequency) {
            RewardFrequency.DAILY -> {
                val startOfDay = startOfDayMillis(on)
                maxOf(dailyPointsHistory[startOfDay] ?: 0, 0)
            }
            RewardFrequency.WEEKLY -> {
                val weekStart = startOfWeek(on)
                var total = 0
                for (i in 0 until 7) {
                    calendar.time = weekStart
                    calendar.add(Calendar.DAY_OF_YEAR, i)
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(dailyPointsHistory[dayMillis] ?: 0, 0)
                }
                total
            }
            RewardFrequency.MONTHLY -> {
                val monthStart = startOfMonth(on)
                calendar.time = monthStart
                calendar.add(Calendar.MONTH, 1)
                calendar.add(Calendar.DAY_OF_MONTH, -1)
                val monthEnd = calendar.time

                var total = 0
                calendar.time = monthStart
                while (!calendar.time.after(monthEnd)) {
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(dailyPointsHistory[dayMillis] ?: 0, 0)
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }
                total
            }
            RewardFrequency.YEARLY -> {
                val yearStart = startOfYear(on)
                calendar.time = yearStart
                calendar.add(Calendar.YEAR, 1)
                calendar.add(Calendar.DAY_OF_YEAR, -1)
                val yearEnd = calendar.time

                var total = 0
                calendar.time = yearStart
                while (!calendar.time.after(yearEnd)) {
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(dailyPointsHistory[dayMillis] ?: 0, 0)
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }
                total
            }
            RewardFrequency.ONE_TIME -> {
                dailyPointsHistory.values.sumOf { maxOf(it, 0) }
            }
        }
    }

    fun availablePointsForCategory(
        categoryId: UUID,
        frequency: RewardFrequency,
        on: Date = Date(),
    ): Int {
        val categoryHistory = categoryPointsHistory[categoryId] ?: return 0
        val calendar = Calendar.getInstance()

        return when (frequency) {
            RewardFrequency.DAILY -> {
                val startOfDay = startOfDayMillis(on)
                maxOf(categoryHistory[startOfDay] ?: 0, 0)
            }
            RewardFrequency.WEEKLY -> {
                val weekStart = startOfWeek(on)
                var total = 0
                for (i in 0 until 7) {
                    calendar.time = weekStart
                    calendar.add(Calendar.DAY_OF_YEAR, i)
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(categoryHistory[dayMillis] ?: 0, 0)
                }
                total
            }
            RewardFrequency.MONTHLY -> {
                val monthStart = startOfMonth(on)
                calendar.time = monthStart
                calendar.add(Calendar.MONTH, 1)
                calendar.add(Calendar.DAY_OF_MONTH, -1)
                val monthEnd = calendar.time

                var total = 0
                calendar.time = monthStart
                while (!calendar.time.after(monthEnd)) {
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(categoryHistory[dayMillis] ?: 0, 0)
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }
                total
            }
            RewardFrequency.YEARLY -> {
                val yearStart = startOfYear(on)
                calendar.time = yearStart
                calendar.add(Calendar.YEAR, 1)
                calendar.add(Calendar.DAY_OF_YEAR, -1)
                val yearEnd = calendar.time

                var total = 0
                calendar.time = yearStart
                while (!calendar.time.after(yearEnd)) {
                    val dayMillis = startOfDayMillis(calendar.time)
                    total += maxOf(categoryHistory[dayMillis] ?: 0, 0)
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }
                total
            }
            RewardFrequency.ONE_TIME -> {
                categoryHistory.values.sumOf { maxOf(it, 0) }
            }
        }
    }

    fun totalPoints(): Int = dailyPointsHistory.values.sumOf { maxOf(it, 0) }

    fun totalPointsForCategory(categoryId: UUID): Int =
        categoryPointsHistory[categoryId]?.values?.sumOf { maxOf(it, 0) } ?: 0

    // ---- Helpers ----

    private fun startOfDayMillis(date: Date): Long {
        val c = Calendar.getInstance()
        c.time = date
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
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
