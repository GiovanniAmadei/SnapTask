package com.snaptask.app.ui.rewards

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.Reward
import com.snaptask.app.data.model.RewardFrequency
import com.snaptask.app.data.repository.RewardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

/**
 * ViewModel for the Rewards tab, mirroring iOS RewardViewModel.
 */
@HiltViewModel
class RewardViewModel @Inject constructor(
    private val rewardRepository: RewardRepository,
) : ViewModel() {

    val allRewards: StateFlow<List<Reward>> = rewardRepository.getAllRewards()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val dailyRewards: StateFlow<List<Reward>> = allRewards.map { rewards ->
        rewards.filter { it.frequency == RewardFrequency.DAILY }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val weeklyRewards: StateFlow<List<Reward>> = allRewards.map { rewards ->
        rewards.filter { it.frequency == RewardFrequency.WEEKLY }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val monthlyRewards: StateFlow<List<Reward>> = allRewards.map { rewards ->
        rewards.filter { it.frequency == RewardFrequency.MONTHLY }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _dailyPoints = MutableStateFlow(0)
    val dailyPoints: StateFlow<Int> = _dailyPoints.asStateFlow()

    private val _weeklyPoints = MutableStateFlow(0)
    val weeklyPoints: StateFlow<Int> = _weeklyPoints.asStateFlow()

    private val _monthlyPoints = MutableStateFlow(0)
    val monthlyPoints: StateFlow<Int> = _monthlyPoints.asStateFlow()

    private val _yearlyPoints = MutableStateFlow(0)
    val yearlyPoints: StateFlow<Int> = _yearlyPoints.asStateFlow()

    init {
        updatePoints()
    }

    fun updatePoints() {
        _dailyPoints.value = rewardRepository.availablePoints(RewardFrequency.DAILY, Date())
        _weeklyPoints.value = rewardRepository.availablePoints(RewardFrequency.WEEKLY, Date())
        _monthlyPoints.value = rewardRepository.availablePoints(RewardFrequency.MONTHLY, Date())
        _yearlyPoints.value = rewardRepository.availablePoints(RewardFrequency.YEARLY, Date())
    }

    fun currentPoints(frequency: RewardFrequency): Int {
        return rewardRepository.availablePoints(frequency, Date())
    }

    fun canRedeemReward(reward: Reward): Boolean {
        val available = if (reward.isGeneralReward) {
            rewardRepository.availablePoints(reward.frequency, Date())
        } else {
            rewardRepository.availablePointsForCategory(reward.categoryId!!, reward.frequency, Date())
        }
        return reward.canRedeem(available)
    }

    fun addReward(reward: Reward) {
        viewModelScope.launch {
            rewardRepository.addReward(reward)
            updatePoints()
        }
    }

    fun updateReward(reward: Reward) {
        viewModelScope.launch {
            rewardRepository.updateReward(reward)
            updatePoints()
        }
    }

    fun removeReward(reward: Reward) {
        viewModelScope.launch {
            rewardRepository.deleteReward(reward)
            updatePoints()
        }
    }

    fun redeemReward(reward: Reward) {
        viewModelScope.launch {
            rewardRepository.redeemReward(reward, Date())
            updatePoints()
        }
    }
}
