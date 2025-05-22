import Foundation
import Combine

class RewardManager: ObservableObject {
    static let shared = RewardManager()
    
    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var pointsHistory: [Date: Int] = [:]
    private let rewardsKey = "savedRewards"
    private let pointsHistoryKey = "savedPointsHistory"
    
    init() {
        loadRewards()
        loadPointsHistory()
    }
    
    // MARK: - Rewards Management
    
    func addReward(_ reward: Reward) {
        rewards.append(reward)
        saveRewards()
        objectWillChange.send()
    }
    
    func updateReward(_ updatedReward: Reward) {
        if let index = rewards.firstIndex(where: { $0.id == updatedReward.id }) {
            rewards[index] = updatedReward
            saveRewards()
            objectWillChange.send()
        }
    }
    
    func removeReward(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
        saveRewards()
        objectWillChange.send()
    }
    
    func redeemReward(_ reward: Reward, on date: Date = Date()) {
        if reward.canRedeem(availablePoints: availablePoints(for: reward.frequency, on: date)) {
            // Deduct points
            let points = -reward.pointsCost
            addPoints(points, on: date)
            
            // Mark as redeemed
            var updatedReward = reward
            updatedReward.redemptions.append(date)
            updateReward(updatedReward)
            
            objectWillChange.send()
        }
    }
    
    // MARK: - Points Management
    
    func addPoints(_ points: Int, on date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let currentPoints = pointsHistory[startOfDay] ?? 0
        pointsHistory[startOfDay] = currentPoints + points
        savePointsHistory()
        objectWillChange.send()
    }
    
    func availablePoints(for frequency: RewardFrequency, on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            let startOfDay = calendar.startOfDay(for: date)
            return pointsHistory[startOfDay] ?? 0
            
        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            
            return pointsHistory.filter { 
                let pointDate = $0.key
                return pointDate >= weekStart && pointDate < weekEnd
            }
            .map { $0.value }
            .reduce(0, +)
            
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            
            return pointsHistory.filter { 
                let pointDate = $0.key
                return pointDate >= monthStart && pointDate < monthEnd
            }
            .map { $0.value }
            .reduce(0, +)
        }
    }
    
    func totalPoints() -> Int {
        return pointsHistory.values.reduce(0, +)
    }
    
    func rewardsFor(frequency: RewardFrequency) -> [Reward] {
        return rewards.filter { $0.frequency == frequency }
    }
    
    // MARK: - Persistence
    
    private func saveRewards() {
        do {
            let data = try JSONEncoder().encode(rewards)
            UserDefaults.standard.set(data, forKey: rewardsKey)
        } catch {
            print("Error saving rewards: \(error)")
        }
    }
    
    private func loadRewards() {
        if let data = UserDefaults.standard.data(forKey: rewardsKey) {
            do {
                rewards = try JSONDecoder().decode([Reward].self, from: data)
            } catch {
                print("Error loading rewards: \(error)")
            }
        }
    }
    
    private func savePointsHistory() {
        do {
            let data = try JSONEncoder().encode(pointsHistory)
            UserDefaults.standard.set(data, forKey: pointsHistoryKey)
        } catch {
            print("Error saving points history: \(error)")
        }
    }
    
    private func loadPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: pointsHistoryKey) {
            do {
                pointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading points history: \(error)")
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let rewardsDidUpdate = Notification.Name("rewardsDidUpdate")
}

// MARK: - Date Extensions
// Moved to a shared extension to avoid duplication
