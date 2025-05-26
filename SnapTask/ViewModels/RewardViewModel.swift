import Foundation
import Combine

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
        
        // Initial load
        updateRewards(RewardManager.shared.rewards)
        updatePoints()
    }
    
    func updatePoints() {
        dailyPoints = RewardManager.shared.availablePoints(for: .daily)
        weeklyPoints = RewardManager.shared.availablePoints(for: .weekly)
        monthlyPoints = RewardManager.shared.availablePoints(for: .monthly)
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
        case .yearly:
            return !reward.hasBeenRedeemed() && reward.canRedeem(availablePoints: RewardManager.shared.availablePoints(for: .yearly))
        case .oneTime:
            return !reward.hasBeenRedeemed() && reward.canRedeem(availablePoints: dailyPoints + weeklyPoints + monthlyPoints)
        }
    }
    
    func currentPoints(for frequency: RewardFrequency) -> Int {
        switch frequency {
        case .daily:
            return dailyPoints
        case .weekly:
            return weeklyPoints
        case .monthly:
            return monthlyPoints
        case .yearly:
            return RewardManager.shared.availablePoints(for: .yearly)
        case .oneTime:
            return dailyPoints + weeklyPoints + monthlyPoints
        }
    }
}
