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
    
    // MARK: - Rewards Management
    
    func addReward(_ reward: Reward) {
        rewards.append(reward)
        saveRewards()
        
        // CloudKitService.shared.saveReward(reward)
    }
    
    func updateReward(_ updatedReward: Reward) {
        if let index = rewards.firstIndex(where: { $0.id == updatedReward.id }) {
            rewards[index] = updatedReward
            saveRewards()
            objectWillChange.send()
            
            // CloudKitService.shared.saveReward(updatedReward)
        }
    }
    
    func removeReward(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
        saveRewards()
        
        // CloudKitService.shared.deleteReward(reward)
    }
    
    func importRewards(_ newRewards: [Reward]) {
        // Create a dictionary of existing rewards by ID for quick lookup
        let existingRewardsDict = Dictionary(uniqueKeysWithValues: rewards.map { ($0.id, $0) })
        
        // Merge new rewards with existing ones, prioritizing new ones in case of conflict
        var updatedRewards = existingRewardsDict
        
        for reward in newRewards {
            updatedRewards[reward.id] = reward
        }
        
        // Convert back to array
        rewards = Array(updatedRewards.values)
        
        // Save the updated rewards
        saveRewards()
    }
    
    func redeemReward(_ reward: Reward, on date: Date = Date()) {
        if reward.canRedeem(availablePoints: availablePoints(for: reward.frequency, on: date)) {
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
        
        // Se non è specificata una frequenza, aggiungi i punti a tutte le frequenze
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
    
    func importPointsHistory(_ pointsHistory: [PointsHistory]) {
        // Clear existing data
        dailyPointsHistory.removeAll()
        weeklyPointsHistory.removeAll()
        monthlyPointsHistory.removeAll()
        yearlyPointsHistory.removeAll()
        oneTimePointsHistory.removeAll()
        
        // Import new data
        for points in pointsHistory {
            switch points.frequency {
            case .daily:
                dailyPointsHistory[points.date] = points.points
            case .weekly:
                weeklyPointsHistory[points.date] = points.points
            case .monthly:
                monthlyPointsHistory[points.date] = points.points
            case .yearly:
                yearlyPointsHistory[points.date] = points.points
            case .oneTime:
                oneTimePointsHistory[points.date] = points.points
            }
        }
        
        // Save all changes
        saveDailyPointsHistory()
        saveWeeklyPointsHistory()
        saveMonthlyPointsHistory()
        saveYearlyPointsHistory()
        saveOneTimePointsHistory()
        
        objectWillChange.send()
    }
    
    func resetAllPoints() {
        dailyPointsHistory.removeAll()
        weeklyPointsHistory.removeAll()
        monthlyPointsHistory.removeAll()
        yearlyPointsHistory.removeAll()
        oneTimePointsHistory.removeAll()
        
        saveDailyPointsHistory()
        saveWeeklyPointsHistory()
        saveMonthlyPointsHistory()
        saveYearlyPointsHistory()
        saveOneTimePointsHistory()
        
        objectWillChange.send()
    }
    
    func removePointsFromTask(_ task: TodoTask) {
        let pointsToRemove = task.rewardPoints
        
        // Remove points from each completion date
        for date in task.completionDates {
            addPoints(-pointsToRemove, on: date)
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
    
    func totalPoints() -> Int {
        let dailyTotal = dailyPointsHistory.values.reduce(0, +)
        let weeklyTotal = weeklyPointsHistory.values.reduce(0, +)
        let monthlyTotal = monthlyPointsHistory.values.reduce(0, +)
        let yearlyTotal = yearlyPointsHistory.values.reduce(0, +)
        let oneTimeTotal = oneTimePointsHistory.values.reduce(0, +)
        return dailyTotal + weeklyTotal + monthlyTotal + yearlyTotal + oneTimeTotal
    }
    
    func rewardsFor(frequency: RewardFrequency) -> [Reward] {
        return rewards.filter { $0.frequency == frequency }
    }
    
    // MARK: - Persistence
    
    private func saveRewards() {
        do {
            let data = try JSONEncoder().encode(rewards)
            UserDefaults.standard.set(data, forKey: rewardsKey)
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
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
            UserDefaults.standard.synchronize()
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

// MARK: - Notification Extensions
extension Notification.Name {
    static let rewardsDidUpdate = Notification.Name("rewardsDidUpdate")
}

// MARK: - Date Extensions
// Moved to a shared extension to avoid duplication
