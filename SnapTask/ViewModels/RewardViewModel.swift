import Foundation
import Combine

class RewardViewModel: ObservableObject {
    @Published var rewards: [Reward] = []
    @Published var dailyRewards: [Reward] = []
    @Published var weeklyRewards: [Reward] = []
    @Published var monthlyRewards: [Reward] = []
    
    @Published var dailyPoints: Int = 0
    @Published var weeklyPoints: Int = 0
    @Published var monthlyPoints: Int = 0
    @Published var totalPoints: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        RewardManager.shared.$rewards
            .sink { [weak self] rewards in
                self?.updateRewardLists(rewards)
            }
            .store(in: &cancellables)
        
        // Initial load
        updateRewardLists(RewardManager.shared.rewards)
        updatePoints()
    }
    
    func updateRewardLists(_ rewards: [Reward]) {
        self.rewards = rewards
        self.dailyRewards = rewards.filter { $0.frequency == .daily }
        self.weeklyRewards = rewards.filter { $0.frequency == .weekly }
        self.monthlyRewards = rewards.filter { $0.frequency == .monthly }
    }
    
    func updatePoints() {
        let today = Date()
        self.dailyPoints = RewardManager.shared.availablePoints(for: .daily, on: today)
        self.weeklyPoints = RewardManager.shared.availablePoints(for: .weekly, on: today)
        self.monthlyPoints = RewardManager.shared.availablePoints(for: .monthly, on: today)
        self.totalPoints = RewardManager.shared.totalPoints()
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
        RewardManager.shared.redeemReward(reward)
        updatePoints()
    }
    
    func canRedeemReward(_ reward: Reward) -> Bool {
        switch reward.frequency {
        case .daily:
            return !reward.hasBeenRedeemed() && reward.canRedeem(availablePoints: dailyPoints)
        case .weekly:
            return !reward.hasBeenRedeemed() && reward.canRedeem(availablePoints: weeklyPoints)
        case .monthly:
            return !reward.hasBeenRedeemed() && reward.canRedeem(availablePoints: monthlyPoints)
        }
    }
}
