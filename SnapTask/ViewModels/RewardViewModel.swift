import Foundation
import Combine

@MainActor
class RewardViewModel: ObservableObject {
    @Published var dailyRewards: [Reward] = []
    @Published var weeklyRewards: [Reward] = []
    @Published var monthlyRewards: [Reward] = []
    @Published var dailyPoints: Int = 0
    @Published var weeklyPoints: Int = 0
    @Published var monthlyPoints: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for reward updates
        RewardManager.shared.$rewards
            .sink { [weak self] rewards in
                self?.updateRewards(rewards)
            }
            .store(in: &cancellables)
        
        RewardManager.shared.$dailyPointsHistory
            .sink { [weak self] _ in
                self?.updatePoints()
            }
            .store(in: &cancellables)
        
        // Initial load
        updateRewards(RewardManager.shared.rewards)
        updatePoints()
    }
    
    func updatePoints() {
        dailyPoints = RewardManager.shared.availablePoints(for: .daily, on: Date())
        weeklyPoints = RewardManager.shared.availablePoints(for: .weekly, on: Date())
        monthlyPoints = RewardManager.shared.availablePoints(for: .monthly, on: Date())
    }
    
    private func updateRewards(_ rewards: [Reward]) {
        dailyRewards = rewards.filter { $0.frequency == .daily }
        weeklyRewards = rewards.filter { $0.frequency == .weekly }
        monthlyRewards = rewards.filter { $0.frequency == .monthly }
    }
    
    func addReward(_ reward: Reward) {
        RewardManager.shared.addReward(reward)
        updatePoints()
    }
    
    func updateReward(_ reward: Reward) {
        RewardManager.shared.updateReward(reward)
        updatePoints()
    }
    
    func removeReward(_ reward: Reward) {
        RewardManager.shared.removeReward(reward)
        updatePoints()
    }
    
    func redeemReward(_ reward: Reward) {
        RewardManager.shared.redeemReward(reward, on: Date())
        updatePoints()
    }
    
    func canRedeemReward(_ reward: Reward) -> Bool {
        // Check if we have enough points (allow multiple redemptions)
        let availablePoints = reward.isGeneralReward ? 
            RewardManager.shared.availablePoints(for: reward.frequency) :
            RewardManager.shared.availablePointsForCategory(reward.categoryId!, frequency: reward.frequency)
        
        return reward.canRedeem(availablePoints: availablePoints)
    }
    
    func currentPoints(for frequency: RewardFrequency) -> Int {
        return RewardManager.shared.availablePoints(for: frequency, on: Date())
    }
}