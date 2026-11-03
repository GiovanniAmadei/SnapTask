package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

object RewardManager {
    private const val rewardsKey = "savedRewards"
    private const val dailyPointsHistoryKey = "savedDailyPointsHistory"
    private const val categoryPointsHistoryKey = "savedCategoryPointsHistory"
    private val rewardsSerializer = ListSerializer(Reward.serializer())
    private val dailySerializer = DateKeyedMapSerializer(Int.serializer())
    private val categorySerializer = MapSerializer(String.serializer(), dailySerializer)

    var rewards by mutableStateOf<List<Reward>>(emptyList())
        private set
    var dailyPointsHistory by mutableStateOf<Map<Date, Int>>(emptyMap())
        private set
    var categoryPointsHistory by mutableStateOf<Map<UUID, Map<Date, Int>>>(emptyMap())
        private set

    /** Points are always worked out again from tasks and redemptions at launch, as iOS does from 1.8. */
    fun load() {
        rewards = (Store.load(rewardsKey, rewardsSerializer) ?: emptyList()).map {
            it.copy(redemptions = Reward.normalizedRedemptions(it.redemptions))
        }
        dailyPointsHistory = Store.load(dailyPointsHistoryKey, dailySerializer)?.mapValues { max(it.value, 0) } ?: emptyMap()
        categoryPointsHistory = Store.load(categoryPointsHistoryKey, categorySerializer)
            ?.mapKeys { UUID.fromString(it.key) }
            ?.mapValues { (_, days) -> days.mapValues { max(it.value, 0) } } ?: emptyMap()
        if (!Defaults.bool("points_from_sources_v1_8")) {
            recalculateDailyPointsFromSources()
            Defaults.set("points_from_sources_v1_8", true)
        }
    }

    // MARK: - Rewards

    val activeRewards: List<Reward> get() = rewards.filter { !it.isArchived }

    fun addReward(reward: Reward) {
        rewards = rewards + reward
        saveRewards()
    }

    fun updateReward(updated: Reward) {
        if (rewards.none { it.id == updated.id }) return
        val stamped = updated.copy(lastModifiedDate = now())
        rewards = rewards.map { if (it.id == updated.id) stamped else it }
        saveRewards()
    }

    /** Removes the reward but keeps its redemptions, so the points already spent stay spent. */
    fun archiveReward(reward: Reward) {
        val archived = rewards.firstOrNull { it.id == reward.id } ?: return
        updateReward(archived.copy(archivedDate = now()))
    }

    fun removeReward(reward: Reward) {
        val wasRedeemed = rewards.firstOrNull { it.id == reward.id }?.redemptions?.isNotEmpty() == true
        rewards = rewards.filter { it.id != reward.id }
        saveRewards()
        // Its redemptions are gone: rebuild the balances so the spent points come back everywhere.
        if (wasRedeemed) recalculateDailyPointsFromSources()
    }

    fun importRewards(newRewards: List<Reward>) {
        val updated = rewards.toMutableList()
        for (reward in newRewards) {
            val index = updated.indexOfFirst { it.id == reward.id }
            if (index >= 0) updated[index] = reward else updated += reward
        }
        if (updated == rewards) return
        rewards = updated
        saveRewards()
    }

    fun eligibleDaysForDeduction(date: Date, frequency: RewardFrequency): List<Date> {
        val startOfRedemptionDay = date.startOfDay()
        val periodStart = when (frequency) {
            RewardFrequency.daily -> return listOf(startOfRedemptionDay)
            RewardFrequency.weekly -> date.startOfWeek()
            RewardFrequency.monthly -> date.startOfMonth()
            RewardFrequency.yearly -> date.startOfYear()
            RewardFrequency.oneTime -> return emptyList()
        }
        val days = ArrayList<Date>()
        var current = periodStart
        while (current <= startOfRedemptionDay) {
            days += current
            current = current.addingDays(1)
        }
        return days.sortedDescending()
    }

    fun deductPoints(cost: Int, frequency: RewardFrequency, categoryId: UUID?, date: Date = now()) {
        if (cost <= 0) return
        val startOfDate = date.startOfDay()
        val candidateDays = if (frequency == RewardFrequency.oneTime) {
            dailyPointsHistory.keys.filter { it <= startOfDate }.sortedDescending()
        } else eligibleDaysForDeduction(date, frequency)

        if (categoryId != null) {
            val history = (categoryPointsHistory[categoryId] ?: emptyMap()).toMutableMap()
            val days = if (frequency == RewardFrequency.oneTime) history.keys.filter { it <= startOfDate }.sortedDescending() else candidateDays
            deduct(history, days, cost)
            categoryPointsHistory = categoryPointsHistory + (categoryId to history)
            saveCategoryPointsHistory()
        }
        val daily = dailyPointsHistory.toMutableMap()
        deduct(daily, candidateDays, cost)
        dailyPointsHistory = daily
        saveDailyPointsHistory()
    }

    private fun deduct(history: MutableMap<Date, Int>, days: List<Date>, cost: Int) {
        var remaining = cost
        for (day in days) {
            if (remaining <= 0) break
            val current = history[day] ?: 0
            if (current <= 0) continue
            val amount = min(current, remaining)
            history[day] = current - amount
            remaining -= amount
        }
    }

    fun redeemReward(reward: Reward, date: Date = now()) {
        val available = if (reward.isGeneralReward) availablePoints(reward.frequency, date)
        else availablePointsForCategory(reward.categoryId!!, reward.frequency, date)
        if (reward.canRedeem(available)) {
            deductPoints(reward.pointsCost, reward.frequency, reward.categoryId, date)
            updateReward(reward.copy(redemptions = Reward.normalizedRedemptions(reward.redemptions + date)))
        }
    }

    // MARK: - Points

    fun addPoints(points: Int, date: Date = now()) {
        val day = date.startOfDay()
        dailyPointsHistory = dailyPointsHistory + (day to max((dailyPointsHistory[day] ?: 0) + points, 0))
        saveDailyPointsHistory()
    }

    fun addPointsToCategory(points: Int, categoryId: UUID, categoryName: String?, date: Date = now()) {
        val day = date.startOfDay()
        val history = categoryPointsHistory[categoryId] ?: emptyMap()
        categoryPointsHistory = categoryPointsHistory + (categoryId to (history + (day to max((history[day] ?: 0) + points, 0))))
        saveCategoryPointsHistory()
    }

    fun resetAllPoints() {
        dailyPointsHistory = emptyMap()
        categoryPointsHistory = emptyMap()
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
    }

    fun performCompleteReset() {
        rewards = emptyList()
        dailyPointsHistory = emptyMap()
        categoryPointsHistory = emptyMap()
        Store.remove(rewardsKey)
        Store.remove(dailyPointsHistoryKey)
        Store.remove(categoryPointsHistoryKey)
    }

    fun removePointsFromTask(task: TodoTask) {
        if (!task.hasRewardPoints || task.rewardPoints <= 0) return
        val pointsToRemove = task.rewardPoints
        for (date in task.completionDates) {
            val day = date.startOfDay()
            val current = dailyPointsHistory[day] ?: 0
            if (current >= pointsToRemove) addPoints(-pointsToRemove, date)
            else if (current > 0) addPoints(-current, date)
            val categoryId = task.category?.id ?: continue
            val history = categoryPointsHistory[categoryId] ?: continue
            val currentCategory = history[day] ?: 0
            if (currentCategory > 0) {
                categoryPointsHistory = categoryPointsHistory + (categoryId to (history + (day to max(currentCategory - pointsToRemove, 0))))
            }
        }
        saveCategoryPointsHistory()
    }

    private fun sumDays(history: Map<Date, Int>, from: Date, until: Date): Int {
        var total = 0
        var current = from
        while (current < until) {
            total += max(history[current] ?: 0, 0)
            current = current.addingDays(1)
        }
        return total
    }

    fun availablePoints(frequency: RewardFrequency, date: Date = now()): Int = when (frequency) {
        RewardFrequency.daily -> max(dailyPointsHistory[date.startOfDay()] ?: 0, 0)
        RewardFrequency.weekly -> sumDays(dailyPointsHistory, date.startOfWeek(), date.startOfWeek().addingDays(7))
        RewardFrequency.monthly -> sumDays(dailyPointsHistory, date.startOfMonth(), date.startOfMonth().addingMonths(1))
        RewardFrequency.yearly -> sumDays(dailyPointsHistory, date.startOfYear(), date.startOfYear().addingYears(1))
        // All time: worked out from the source data.
        RewardFrequency.oneTime -> expectedAllTimePointsFromSources()
    }

    fun availablePointsForCategory(categoryId: UUID, frequency: RewardFrequency, date: Date = now()): Int {
        val history = categoryPointsHistory[categoryId] ?: return 0
        return when (frequency) {
            RewardFrequency.daily -> max(history[date.startOfDay()] ?: 0, 0)
            RewardFrequency.weekly -> sumDays(history, date.startOfWeek(), date.startOfWeek().addingDays(7))
            RewardFrequency.monthly -> sumDays(history, date.startOfMonth(), date.startOfMonth().addingMonths(1))
            RewardFrequency.yearly -> sumDays(history, date.startOfYear(), date.startOfYear().addingYears(1))
            RewardFrequency.oneTime -> history.values.sumOf { max(it, 0) }
        }
    }

    private fun expectedAllTimePointsFromSources(): Int {
        val current = now()
        var earned = 0
        for (task in TaskManager.tasks) {
            if (!task.hasRewardPoints || task.rewardPoints <= 0) continue
            earned += task.completionDates.filter { it <= current }.map { it.epochSecond }.toSet().size * task.rewardPoints
        }
        val spent = rewards.filter { it.isGeneralReward }.sumOf { it.redemptions.size * it.pointsCost }
        return max(earned - spent, 0)
    }

    fun totalPoints(): Int = dailyPointsHistory.values.sumOf { max(it, 0) }
    fun totalPointsForCategory(categoryId: UUID): Int = categoryPointsHistory[categoryId]?.values?.sumOf { max(it, 0) } ?: 0
    fun rewardsFor(frequency: RewardFrequency): List<Reward> = activeRewards.filter { it.frequency == frequency }
    fun rewardsForCategory(categoryId: UUID?): List<Reward> = activeRewards.filter { it.categoryId == categoryId }
    fun generalRewards(): List<Reward> = activeRewards.filter { it.isGeneralReward }
    fun categorySpecificRewards(): List<Reward> = activeRewards.filter { !it.isGeneralReward }

    // MARK: - Persistence

    private fun saveRewards() = Store.save(rewardsKey, rewardsSerializer, rewards)
    private fun saveDailyPointsHistory() = Store.save(dailyPointsHistoryKey, dailySerializer, dailyPointsHistory)
    private fun saveCategoryPointsHistory() =
        Store.save(categoryPointsHistoryKey, categorySerializer, categoryPointsHistory.mapKeys { it.key.uuidString })

    fun recalculateDailyPointsFromSources() {
        val newDaily = HashMap<Date, Int>()
        val newCategory = HashMap<UUID, MutableMap<Date, Int>>()
        for (task in TaskManager.tasks) {
            if (!task.hasRewardPoints || task.rewardPoints <= 0) continue
            for (completionDate in task.completionDates.toSet()) {
                val day = completionDate.startOfDay()
                newDaily[day] = (newDaily[day] ?: 0) + task.rewardPoints
                task.category?.id?.let { categoryId ->
                    val history = newCategory.getOrPut(categoryId) { HashMap() }
                    history[day] = (history[day] ?: 0) + task.rewardPoints
                }
            }
        }

        val redemptions = rewards.flatMap { reward -> reward.redemptions.map { reward to it } }.sortedBy { it.second }
        for ((reward, date) in redemptions) {
            val startOfRedemption = date.startOfDay()
            reward.categoryId?.let { categoryId ->
                val history = newCategory[categoryId]
                if (history != null) {
                    val days = if (reward.frequency == RewardFrequency.oneTime) history.keys.filter { it <= startOfRedemption }.sortedDescending()
                    else eligibleDaysForDeduction(date, reward.frequency)
                    deduct(history, days, reward.pointsCost)
                }
            }
            val days = if (reward.frequency == RewardFrequency.oneTime) newDaily.keys.filter { it <= startOfRedemption }.sortedDescending()
            else eligibleDaysForDeduction(date, reward.frequency)
            deduct(newDaily, days, reward.pointsCost)
        }

        dailyPointsHistory = newDaily
        categoryPointsHistory = newCategory
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
    }
}
