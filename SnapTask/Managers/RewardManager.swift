import Foundation
import Combine

@MainActor
class RewardManager: ObservableObject {
    static let shared = RewardManager()
    
    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var dailyPointsHistory: [Date: Int] = [:]
    private let rewardsKey = "savedRewards"
    private let dailyPointsHistoryKey = "savedDailyPointsHistory"
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        loadRewards()
        loadDailyPointsHistory()
        
        // Listen for CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // CloudKit data changed, but we'll let the sync process handle it
                // to avoid infinite loops
                print("📥 CloudKit rewards data changed")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Rewards Management
    
    func addReward(_ reward: Reward) {
        rewards.append(reward)
        saveRewards()
        
        CloudKitService.shared.saveReward(reward)
    }
    
    func updateReward(_ updatedReward: Reward) {
        if let index = rewards.firstIndex(where: { $0.id == updatedReward.id }) {
            rewards[index] = updatedReward
            saveRewards()
            objectWillChange.send()
            
            // Sync with CloudKit
            CloudKitService.shared.saveReward(updatedReward)
        }
    }
    
    func removeReward(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
        saveRewards()
        
        CloudKitService.shared.deleteReward(reward)
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
            // Deduct points from daily history
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
        
        let currentDailyPoints = dailyPointsHistory[startOfDay] ?? 0
        let newTotal = currentDailyPoints + points
        
        // Prevent extremely negative values that indicate corruption
        let finalTotal = max(newTotal, -200) // Allow some negative for legitimate corrections
        
        dailyPointsHistory[startOfDay] = finalTotal
        saveDailyPointsHistory()
        
        print("🎯 Points updated for \(startOfDay): \(currentDailyPoints) + \(points) = \(finalTotal)")
        
        // Sync with CloudKit
        let pointsEntry = PointsHistory(date: startOfDay, points: points, frequency: .daily)
        CloudKitService.shared.savePointsEntry(pointsEntry)
        
        objectWillChange.send()
    }
    
    func importPointsHistory(_ pointsHistory: [PointsHistory]) {
        // This method is used for CloudKit sync - merge rather than replace
        for points in pointsHistory {
            let startOfDay = Calendar.current.startOfDay(for: points.date)
            
            switch points.frequency {
            case .daily, .oneTime:
                // Only add if we don't already have data for this date
                if dailyPointsHistory[startOfDay] == nil {
                    dailyPointsHistory[startOfDay] = points.points
                }
            case .weekly:
                // Distribute weekly points across the week
                let calendar = Calendar.current
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: points.date))!
                let dailyPoints = points.points / 7
                
                for i in 0..<7 {
                    if let dayInWeek = calendar.date(byAdding: .day, value: i, to: weekStart) {
                        let dayStartOfDay = calendar.startOfDay(for: dayInWeek)
                        if dailyPointsHistory[dayStartOfDay] == nil {
                            dailyPointsHistory[dayStartOfDay] = dailyPoints
                        }
                    }
                }
            case .monthly:
                // Distribute monthly points across the month
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month], from: points.date)
                let monthStart = calendar.date(from: components)!
                let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
                let dailyPoints = points.points / daysInMonth
                
                for i in 0..<daysInMonth {
                    if let dayInMonth = calendar.date(byAdding: .day, value: i, to: monthStart) {
                        let dayStartOfDay = calendar.startOfDay(for: dayInMonth)
                        if dailyPointsHistory[dayStartOfDay] == nil {
                            dailyPointsHistory[dayStartOfDay] = dailyPoints
                        }
                    }
                }
            case .yearly:
                // Distribute yearly points across the year
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year], from: points.date)
                let yearStart = calendar.date(from: components)!
                let daysInYear = calendar.range(of: .day, in: .year, for: yearStart)?.count ?? 365
                let dailyPoints = points.points / daysInYear
                
                for i in 0..<daysInYear {
                    if let dayInYear = calendar.date(byAdding: .day, value: i, to: yearStart) {
                        let dayStartOfDay = calendar.startOfDay(for: dayInYear)
                        if dailyPointsHistory[dayStartOfDay] == nil {
                            dailyPointsHistory[dayStartOfDay] = dailyPoints
                        }
                    }
                }
            }
        }
        
        // Save changes locally (without triggering CloudKit sync to avoid loops)
        do {
            let data = try JSONEncoder().encode(dailyPointsHistory)
            UserDefaults.standard.set(data, forKey: dailyPointsHistoryKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving daily points history: \(error)")
        }
        
        objectWillChange.send()
    }
    
    func resetAllPoints() {
        print("🎯 Resetting all points - current total: \(totalPoints())")
        dailyPointsHistory.removeAll()
        saveDailyPointsHistory()
        
        // Note: CloudKit data will be handled by the sync process
        // We don't delete individual records here to avoid conflicts
        
        objectWillChange.send()
        print("🎯 All points reset - new total: \(totalPoints())")
    }
    
    func removePointsFromTask(_ task: TodoTask) {
        guard task.hasRewardPoints && task.rewardPoints > 0 else { return }
        
        let pointsToRemove = task.rewardPoints
        
        for date in task.completionDates {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let currentPoints = dailyPointsHistory[startOfDay] ?? 0
            
            // Only subtract if we have positive points to subtract from
            if currentPoints >= pointsToRemove {
                addPoints(-pointsToRemove, on: date)
                print("🎯 Removed \(pointsToRemove) points from \(date) (had \(currentPoints))")
            } else if currentPoints > 0 {
                // If we have some points but not enough, remove what we can
                addPoints(-currentPoints, on: date)
                print("🎯 Removed \(currentPoints) points from \(date) (partial removal)")
            } else {
                print("🎯 Skipped removing points from \(date) - no points to remove")
            }
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
            // Per le reward settimanali, calcola la somma dei punti giornalieri della settimana corrente
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            var weeklyTotal = 0
            
            for i in 0..<7 {
                if let dayInWeek = calendar.date(byAdding: .day, value: i, to: weekStart) {
                    let startOfDay = calendar.startOfDay(for: dayInWeek)
                    weeklyTotal += dailyPointsHistory[startOfDay] ?? 0
                }
            }
            return weeklyTotal
            
        case .monthly:
            // Per le reward mensili, calcola la somma dei punti giornalieri del mese corrente
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            
            var monthlyTotal = 0
            var currentDate = monthStart
            
            while currentDate <= monthEnd {
                let startOfDay = calendar.startOfDay(for: currentDate)
                monthlyTotal += dailyPointsHistory[startOfDay] ?? 0
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return monthlyTotal
            
        case .yearly:
            // Per le reward annuali, calcola la somma dei punti giornalieri dell'anno corrente
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components)!
            let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart)!
            
            var yearlyTotal = 0
            var currentDate = yearStart
            
            while currentDate <= yearEnd {
                let startOfDay = calendar.startOfDay(for: currentDate)
                yearlyTotal += dailyPointsHistory[startOfDay] ?? 0
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return yearlyTotal
            
        case .oneTime:
            // Per le reward one-time, usa tutti i punti giornalieri accumulati
            return dailyPointsHistory.values.reduce(0, +)
        }
    }
    
    func totalPoints() -> Int {
        return dailyPointsHistory.values.reduce(0, +)
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
            
            // Sync with CloudKit if enabled
            CloudKitService.shared.syncPointsHistory(dailyPointsHistory)
        } catch {
            print("Error saving daily points history: \(error)")
        }
    }
    
    private func loadDailyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: dailyPointsHistoryKey) {
            do {
                dailyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
                
                // Remove any entries with extremely negative values that indicate corruption
                dailyPointsHistory = dailyPointsHistory.compactMapValues { points in
                    // Allow reasonable negative values (up to -1000) but remove extreme corruption
                    return points > -1000 ? points : 0
                }
                
                // Save the cleaned data
                saveDailyPointsHistory()
            } catch {
                print("Error loading daily points history: \(error)")
                // Reset to empty if corrupted
                dailyPointsHistory = [:]
                saveDailyPointsHistory()
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
