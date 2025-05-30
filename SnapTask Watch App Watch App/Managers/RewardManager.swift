import Foundation
import Combine

class RewardManager: ObservableObject {
    static let shared = RewardManager()
    
    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var dailyPointsHistory: [Date: Int] = [:]
    @Published private(set) var weeklyPointsHistory: [Date: Int] = [:]
    @Published private(set) var monthlyPointsHistory: [Date: Int] = [:]
    @Published private(set) var yearlyPointsHistory: [Date: Int] = [:]
    @Published private(set) var oneTimePointsHistory: [Date: Int] = [:]
    
    private let rewardsKey = "savedRewards"
    private let dailyPointsHistoryKey = "savedDailyPointsHistory"
    private let weeklyPointsHistoryKey = "savedWeeklyPointsHistory"
    private let monthlyPointsHistoryKey = "savedMonthlyPointsHistory"
    private let yearlyPointsHistoryKey = "savedYearlyPointsHistory"
    private let oneTimePointsHistoryKey = "savedOneTimePointsHistory"
    
    init() {
        loadRewards()
        loadDailyPointsHistory()
        loadWeeklyPointsHistory()
        loadMonthlyPointsHistory()
        loadYearlyPointsHistory()
        loadOneTimePointsHistory()
    }
    
    // MARK: - Computed Properties
    
    var todayPoints: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyPointsHistory[today] ?? 0
    }
    
    var weekPoints: Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return weeklyPointsHistory[weekStart] ?? 0
    }
    
    var monthPoints: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: components)!
        return monthlyPointsHistory[monthStart] ?? 0
    }
    
    var totalPoints: Int {
        return oneTimePointsHistory.values.reduce(0, +)
    }
    
    // MARK: - Rewards Management
    
    func addReward(_ reward: Reward) {
        rewards.append(reward)
        saveRewards()
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
    }
    
    func canRedeemReward(_ reward: Reward) -> Bool {
        let availablePoints = availablePoints(for: reward.frequency)
        return reward.canRedeem(availablePoints: availablePoints) && !reward.hasBeenRedeemed()
    }
    
    func redeemReward(_ reward: Reward, on date: Date = Date()) {
        if canRedeemReward(reward) {
            // Deduct points
            let points = -reward.pointsCost
            addPoints(points, for: reward.frequency, on: date)
            
            // Mark as redeemed
            var updatedReward = reward
            updatedReward.redemptions.append(date)
            updateReward(updatedReward)
            
            objectWillChange.send()
        }
    }
    
    // MARK: - Points Management
    
    func addPoints(_ points: Int, for frequency: RewardFrequency? = nil, on date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        if frequency == nil || frequency == .daily {
            let currentDailyPoints = dailyPointsHistory[startOfDay] ?? 0
            dailyPointsHistory[startOfDay] = currentDailyPoints + points
            saveDailyPointsHistory()
        }
        
        if frequency == nil || frequency == .weekly {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let currentWeeklyPoints = weeklyPointsHistory[weekStart] ?? 0
            weeklyPointsHistory[weekStart] = currentWeeklyPoints + points
            saveWeeklyPointsHistory()
        }
        
        if frequency == nil || frequency == .monthly {
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            let currentMonthlyPoints = monthlyPointsHistory[monthStart] ?? 0
            monthlyPointsHistory[monthStart] = currentMonthlyPoints + points
            saveMonthlyPointsHistory()
        }
        
        if frequency == nil || frequency == .yearly {
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components)!
            let currentYearlyPoints = yearlyPointsHistory[yearStart] ?? 0
            yearlyPointsHistory[yearStart] = currentYearlyPoints + points
            saveYearlyPointsHistory()
        }
        
        if frequency == nil || frequency == .oneTime {
            let currentOneTimePoints = oneTimePointsHistory[startOfDay] ?? 0
            oneTimePointsHistory[startOfDay] = currentOneTimePoints + points
            saveOneTimePointsHistory()
        }
        
        objectWillChange.send()
    }
    
    func availablePoints(for frequency: RewardFrequency, on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            let startOfDay = calendar.startOfDay(for: date)
            return dailyPointsHistory[startOfDay] ?? 0
            
        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            return weeklyPointsHistory[weekStart] ?? 0
            
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            return monthlyPointsHistory[monthStart] ?? 0
            
        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components)!
            return yearlyPointsHistory[yearStart] ?? 0
            
        case .oneTime:
            return oneTimePointsHistory.values.reduce(0, +)
        }
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
    
    private func saveDailyPointsHistory() {
        do {
            let data = try JSONEncoder().encode(dailyPointsHistory)
            UserDefaults.standard.set(data, forKey: dailyPointsHistoryKey)
        } catch {
            print("Error saving daily points history: \(error)")
        }
    }
    
    private func loadDailyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: dailyPointsHistoryKey) {
            do {
                dailyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading daily points history: \(error)")
            }
        }
    }
    
    private func saveWeeklyPointsHistory() {
        do {
            let data = try JSONEncoder().encode(weeklyPointsHistory)
            UserDefaults.standard.set(data, forKey: weeklyPointsHistoryKey)
        } catch {
            print("Error saving weekly points history: \(error)")
        }
    }
    
    private func loadWeeklyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: weeklyPointsHistoryKey) {
            do {
                weeklyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading weekly points history: \(error)")
            }
        }
    }
    
    private func saveMonthlyPointsHistory() {
        do {
            let data = try JSONEncoder().encode(monthlyPointsHistory)
            UserDefaults.standard.set(data, forKey: monthlyPointsHistoryKey)
        } catch {
            print("Error saving monthly points history: \(error)")
        }
    }
    
    private func loadMonthlyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: monthlyPointsHistoryKey) {
            do {
                monthlyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading monthly points history: \(error)")
            }
        }
    }
    
    private func saveYearlyPointsHistory() {
        do {
            let data = try JSONEncoder().encode(yearlyPointsHistory)
            UserDefaults.standard.set(data, forKey: yearlyPointsHistoryKey)
        } catch {
            print("Error saving yearly points history: \(error)")
        }
    }
    
    private func loadYearlyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: yearlyPointsHistoryKey) {
            do {
                yearlyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading yearly points history: \(error)")
            }
        }
    }
    
    private func saveOneTimePointsHistory() {
        do {
            let data = try JSONEncoder().encode(oneTimePointsHistory)
            UserDefaults.standard.set(data, forKey: oneTimePointsHistoryKey)
        } catch {
            print("Error saving one-time points history: \(error)")
        }
    }
    
    private func loadOneTimePointsHistory() {
        if let data = UserDefaults.standard.data(forKey: oneTimePointsHistoryKey) {
            do {
                oneTimePointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
            } catch {
                print("Error loading one-time points history: \(error)")
            }
        }
    }
}