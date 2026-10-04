import Foundation
import Combine

@MainActor
class RewardManager: ObservableObject {
    static let shared = RewardManager()
    
    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var dailyPointsHistory: [Date: Int] = [:]
    @Published private(set) var categoryPointsHistory: [UUID: [Date: Int]] = [:]
    private let rewardsKey = "savedRewards"
    private let dailyPointsHistoryKey = "savedDailyPointsHistory"
    private let categoryPointsHistoryKey = "savedCategoryPointsHistory"
    private let autoFixPointsHistoryKey = "auto_fix_points_history_v3"
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        loadRewards()
        loadDailyPointsHistory()
        loadCategoryPointsHistory()
        
        if !UserDefaults.standard.bool(forKey: "fixed_double_count_points_v1") {
            recalculatePointsFromTasks()
            UserDefaults.standard.set(true, forKey: "fixed_double_count_points_v1")
        }
        
        if !UserDefaults.standard.bool(forKey: "points_history_migration_v2") {
            recalculateDailyPointsFromSources()
            UserDefaults.standard.set(true, forKey: "points_history_migration_v2")
        }

        if !UserDefaults.standard.bool(forKey: "points_redemption_deduction_fix_v1") {
            recalculateDailyPointsFromSources()
            UserDefaults.standard.set(true, forKey: "points_redemption_deduction_fix_v1")
        }

        if !UserDefaults.standard.bool(forKey: autoFixPointsHistoryKey) {
            autoFixPointsHistoryIfNeeded()
            UserDefaults.standard.set(true, forKey: autoFixPointsHistoryKey)
        }
        
        // 1.8: points are derived from tasks and redemptions on every device (no longer synced).
        if !UserDefaults.standard.bool(forKey: "points_from_sources_v1_8")
            || UserDefaults.standard.bool(forKey: Self.recalculatePointsOnLaunchKey) {
            recalculateDailyPointsFromSources()
            UserDefaults.standard.set(true, forKey: "points_from_sources_v1_8")
            UserDefaults.standard.set(false, forKey: Self.recalculatePointsOnLaunchKey)
        }
        
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

    private func autoFixPointsHistoryIfNeeded() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        let expectedYearly = expectedYearlyPointsFromSources(year: year)
        let storedYearly = availablePoints(for: .yearly, on: Date())

        let diff = abs(storedYearly - expectedYearly)
        let shouldFix = diff > 500

        if shouldFix {
            print("🧯 Points history mismatch detected (year \(year)). Stored: \(storedYearly), Expected: \(expectedYearly). Recalculating...")
            recalculateDailyPointsFromSources()
        }
    }

    private func expectedYearlyPointsFromSources(year: Int) -> Int {
        let calendar = Calendar.current

        var yearlyEarned = 0
        for task in TaskManager.shared.tasks {
            guard task.hasRewardPoints, task.rewardPoints > 0 else { continue }
            for completionDate in task.completionDates {
                guard calendar.component(.year, from: completionDate) == year else { continue }
                yearlyEarned += task.rewardPoints
            }
        }

        var yearlySpent = 0
        for reward in rewards where reward.isGeneralReward {
            for redemptionDate in reward.redemptions {
                guard calendar.component(.year, from: redemptionDate) == year else { continue }
                yearlySpent += reward.pointsCost
            }
        }

        return max(yearlyEarned - yearlySpent, 0)
    }

    private func expectedAllTimePointsFromSources() -> Int {
        let now = Date()

        var totalEarned = 0
        for task in TaskManager.shared.tasks {
            guard task.hasRewardPoints, task.rewardPoints > 0 else { continue }
            var seenCompletions: Set<Int64> = []
            for completionDate in task.completionDates {
                guard completionDate <= now else { continue }
                let completionKey = Int64(completionDate.timeIntervalSince1970.rounded())
                guard seenCompletions.insert(completionKey).inserted else { continue }
                totalEarned += task.rewardPoints
            }
        }

        var totalSpent = 0
        for reward in rewards where reward.isGeneralReward {
            totalSpent += reward.redemptions.count * reward.pointsCost
        }

        return max(totalEarned - totalSpent, 0)
    }
    
    // MARK: - Rewards Management
    
    func addReward(_ reward: Reward) {
        rewards.append(reward)
        saveRewards()
        
        CloudKitService.shared.saveReward(reward)
    }
    
    func updateReward(_ updatedReward: Reward) {
        if let index = rewards.firstIndex(where: { $0.id == updatedReward.id }) {
            var updatedReward = updatedReward
            // Lets sync keep the latest edit when two devices changed the same reward.
            updatedReward.lastModifiedDate = Date()
            rewards[index] = updatedReward
            saveRewards()
            objectWillChange.send()
            
            // Sync with CloudKit
            CloudKitService.shared.saveReward(updatedReward)
        }
    }
    
    /// Removes the reward but keeps its redemptions, so the points already spent stay spent.
    func archiveReward(_ reward: Reward) {
        guard var archived = rewards.first(where: { $0.id == reward.id }) else { return }
        archived.archivedDate = Date()
        archived.lastModifiedDate = Date()
        updateReward(archived)
    }
    
    /// Rewards shown in the list (archived ones only live in the redemption history).
    var activeRewards: [Reward] { rewards.filter { !$0.isArchived } }
    
    func removeReward(_ reward: Reward) {
        let wasRedeemed = rewards.first { $0.id == reward.id }?.redemptions.isEmpty == false
        rewards.removeAll { $0.id == reward.id }
        saveRewards()
        
        CloudKitService.shared.deleteReward(reward)
        
        // Its redemptions are gone: rebuild the period balances so the spent points come back everywhere.
        if wasRedeemed {
            recalculateDailyPointsFromSources()
        }
    }
    
    /// Applies rewards coming from sync: replaces the ones already here (keeping their place in
    /// the list) and adds the new ones at the end.
    func importRewards(_ newRewards: [Reward]) {
        var updated = rewards
        for reward in newRewards {
            if let index = updated.firstIndex(where: { $0.id == reward.id }) {
                updated[index] = reward
            } else {
                updated.append(reward)
            }
        }
        guard updated != rewards else { return }
        rewards = updated
        saveRewards()
    }
    
    func eligibleDaysForDeduction(from date: Date, frequency: RewardFrequency, in calendar: Calendar = .current) -> [Date] {
        let startOfRedemptionDay = calendar.startOfDay(for: date)
        switch frequency {
        case .daily:
            return [startOfRedemptionDay]
            
        case .weekly:
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
                return [startOfRedemptionDay]
            }
            return (0..<7).compactMap { i in
                calendar.date(byAdding: .day, value: i, to: weekStart).map { calendar.startOfDay(for: $0) }
            }.filter { $0 <= startOfRedemptionDay }.sorted(by: >)
            
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                return [startOfRedemptionDay]
            }
            var days: [Date] = []
            var curr = monthStart
            while curr <= monthEnd && curr <= startOfRedemptionDay {
                days.append(calendar.startOfDay(for: curr))
                guard let next = calendar.date(byAdding: .day, value: 1, to: curr) else { break }
                curr = next
            }
            return days.sorted(by: >)
            
        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            guard let yearStart = calendar.date(from: components),
                  let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart) else {
                return [startOfRedemptionDay]
            }
            var days: [Date] = []
            var curr = yearStart
            while curr <= yearEnd && curr <= startOfRedemptionDay {
                days.append(calendar.startOfDay(for: curr))
                guard let next = calendar.date(byAdding: .day, value: 1, to: curr) else { break }
                curr = next
            }
            return days.sorted(by: >)
            
        case .oneTime:
            return []
        }
    }

    func deductPoints(cost: Int, for frequency: RewardFrequency, categoryId: UUID?, on date: Date = Date()) {
        guard cost > 0 else { return }
        let calendar = Calendar.current
        let startOfDate = calendar.startOfDay(for: date)
        
        let candidateDays: [Date]
        if frequency == .oneTime {
            candidateDays = dailyPointsHistory.keys.filter { $0 <= startOfDate }.sorted(by: >)
        } else {
            candidateDays = eligibleDaysForDeduction(from: date, frequency: frequency, in: calendar)
        }
        
        // 1. If category-specific reward, deduct from category points first
        if let categoryId = categoryId {
            let catCandidateDays: [Date]
            if frequency == .oneTime {
                catCandidateDays = (categoryPointsHistory[categoryId]?.keys.filter { $0 <= startOfDate }.sorted(by: >)) ?? []
            } else {
                catCandidateDays = candidateDays
            }
            
            var remainingCategoryCost = cost
            for day in catCandidateDays {
                guard remainingCategoryCost > 0 else { break }
                let current = categoryPointsHistory[categoryId]?[day] ?? 0
                guard current > 0 else { continue }
                let deduct = min(current, remainingCategoryCost)
                categoryPointsHistory[categoryId]?[day] = current - deduct
                remainingCategoryCost -= deduct
            }
            saveCategoryPointsHistory()
        }
        
        // 2. Deduct from general dailyPointsHistory
        var remainingCost = cost
        for day in candidateDays {
            guard remainingCost > 0 else { break }
            let current = dailyPointsHistory[day] ?? 0
            guard current > 0 else { continue }
            let deduct = min(current, remainingCost)
            dailyPointsHistory[day] = current - deduct
            remainingCost -= deduct
        }
        
        saveDailyPointsHistory()
        syncDailyPointsToCloudKit()
        objectWillChange.send()
        
        print("🎯 Deducted \(cost) points for \(frequency.rawValue) reward on \(startOfDate). Remaining unallocated: \(remainingCost)")
    }

    func redeemReward(_ reward: Reward, on date: Date = Date()) {
        let availablePoints = reward.isGeneralReward ?
            availablePoints(for: reward.frequency, on: date) :
            availablePointsForCategory(reward.categoryId!, frequency: reward.frequency, on: date)
            
        if reward.canRedeem(availablePoints: availablePoints) {
            deductPoints(cost: reward.pointsCost, for: reward.frequency, categoryId: reward.categoryId, on: date)
            
            // Mark as redeemed (to the second, as iCloud stores it)
            var updatedReward = reward
            updatedReward.redemptions = Reward.normalizedRedemptions(updatedReward.redemptions + [date])
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
        
        let finalTotal = max(newTotal, 0)
        
        dailyPointsHistory[startOfDay] = finalTotal
        saveDailyPointsHistory()
        syncDailyPointsToCloudKit()
        
        print("🎯 Points updated for \(startOfDay): \(currentDailyPoints) + \(points) = \(finalTotal)")
        
        objectWillChange.send()
    }
    
    func addPointsToCategory(_ points: Int, categoryId: UUID, categoryName: String?, on date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Initialize category history if needed
        if categoryPointsHistory[categoryId] == nil {
            categoryPointsHistory[categoryId] = [:]
        }
        
        let currentCategoryPoints = categoryPointsHistory[categoryId]![startOfDay] ?? 0
        let newTotal = currentCategoryPoints + points
        
        let finalTotal = max(newTotal, 0)
        
        categoryPointsHistory[categoryId]![startOfDay] = finalTotal
        
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
        syncDailyPointsToCloudKit()
        
        print("🏷️ Category points updated for \(categoryName ?? "Unknown") on \(startOfDay): \(currentCategoryPoints) + \(points) = \(finalTotal)")
        
        objectWillChange.send()
    }
    
    func importPointsHistory(_ pointsHistory: [PointsHistory]) {
        // This method is used for CloudKit sync - merge rather than replace
        for points in pointsHistory {
            let startOfDay = Calendar.current.startOfDay(for: points.date)
            
            if let categoryId = points.categoryId {
                // Category-specific points
                if categoryPointsHistory[categoryId] == nil {
                    categoryPointsHistory[categoryId] = [:]
                }
                
                if categoryPointsHistory[categoryId]![startOfDay] == nil {
                    categoryPointsHistory[categoryId]![startOfDay] = points.points
                }
            } else {
                // General points (existing logic)
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
        }
        
        // Save changes locally (without triggering CloudKit sync to avoid loops)
        do {
            let data = try JSONEncoder().encode(dailyPointsHistory)
            UserDefaults.standard.set(data, forKey: dailyPointsHistoryKey)
            
            let categoryData = try JSONEncoder().encode(categoryPointsHistory)
            UserDefaults.standard.set(categoryData, forKey: categoryPointsHistoryKey)
            
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving points history: \(error)")
        }
        
        objectWillChange.send()
    }
    
    func resetAllPoints() {
        print("🎯 Resetting all points - current total: \(totalPoints())")
        dailyPointsHistory.removeAll()
        categoryPointsHistory.removeAll()
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
        
        Task {
            await CloudKitService.shared.clearAllPointsHistory()
        }
        
        objectWillChange.send()
        print("🎯 All points reset - new total: \(totalPoints())")
    }
    
    func performCompleteReset() async {
        print("🎯 RewardManager: Performing complete reset")
        
        // Clear all rewards except essentials
        rewards.removeAll()
        
        // Clear all points history
        dailyPointsHistory.removeAll()
        categoryPointsHistory.removeAll()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: rewardsKey)
        UserDefaults.standard.removeObject(forKey: dailyPointsHistoryKey)
        UserDefaults.standard.removeObject(forKey: categoryPointsHistoryKey)
        UserDefaults.standard.synchronize()
        
        // Clear CloudKit deletion markers for rewards and points
        var deletionTracker = CloudKitService.DeletionTracker()
        deletionTracker.rewards.removeAll()
        deletionTracker.pointsHistory.removeAll()
        if let data = try? JSONEncoder().encode(deletionTracker) {
            UserDefaults.standard.set(data, forKey: "cloudkit_deleted_items")
        }
        
        await CloudKitService.shared.clearAllPointsHistory()
        
        // Wait a moment for cleanup
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Notify observers
        objectWillChange.send()
        
        print("🎯 RewardManager: Complete reset finished")
    }
    
    func removePointsFromTask(_ task: TodoTask) {
        guard task.hasRewardPoints && task.rewardPoints > 0 else { return }
        
        let pointsToRemove = task.rewardPoints
        
        for date in task.completionDates {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let currentPoints = dailyPointsHistory[startOfDay] ?? 0
            
            // Remove from general points
            if currentPoints >= pointsToRemove {
                addPoints(-pointsToRemove, on: date)
                print("🎯 Removed \(pointsToRemove) points from \(date) (had \(currentPoints))")
            } else if currentPoints > 0 {
                addPoints(-currentPoints, on: date)
                print("🎯 Removed \(currentPoints) points from \(date) (partial removal)")
            }
            
            // Remove from category points if task has category
            if let categoryId = task.category?.id {
                let currentCategoryPoints = categoryPointsHistory[categoryId]?[startOfDay] ?? 0
                if currentCategoryPoints >= pointsToRemove {
                    let adjustedPoints = currentCategoryPoints - pointsToRemove
                    categoryPointsHistory[categoryId]![startOfDay] = max(adjustedPoints, 0)
                    print("🏷️ Removed \(pointsToRemove) category points from \(date)")
                } else if currentCategoryPoints > 0 {
                    categoryPointsHistory[categoryId]![startOfDay] = 0
                    print("🏷️ Removed \(currentCategoryPoints) category points from \(date) (partial)")
                }
            }
        }
        
        saveCategoryPointsHistory()
        objectWillChange.send()
    }
    
    func availablePoints(for frequency: RewardFrequency, on date: Date = Date()) -> Int {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            let startOfDay = calendar.startOfDay(for: date)
            return max(dailyPointsHistory[startOfDay] ?? 0, 0)
            
        case .weekly:
            // Per le reward settimanali, calcola la somma dei punti giornalieri della settimana corrente
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            var weeklyTotal = 0
            
            for i in 0..<7 {
                if let dayInWeek = calendar.date(byAdding: .day, value: i, to: weekStart) {
                    let startOfDay = calendar.startOfDay(for: dayInWeek)
                    weeklyTotal += max(dailyPointsHistory[startOfDay] ?? 0, 0)
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
                monthlyTotal += max(dailyPointsHistory[startOfDay] ?? 0, 0)
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
                yearlyTotal += max(dailyPointsHistory[startOfDay] ?? 0, 0)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return yearlyTotal
            
        case .oneTime:
            // Per le reward one-time (all time), calcola dai dati sorgente per evitare errori dovuti a storicizzazione/sync
            return expectedAllTimePointsFromSources()
        }
    }
    
    func availablePointsForCategory(_ categoryId: UUID, frequency: RewardFrequency, on date: Date = Date()) -> Int {
        guard let categoryHistory = categoryPointsHistory[categoryId] else { return 0 }
        
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            let startOfDay = calendar.startOfDay(for: date)
            return max(categoryHistory[startOfDay] ?? 0, 0)
            
        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            var weeklyTotal = 0
            
            for i in 0..<7 {
                if let dayInWeek = calendar.date(byAdding: .day, value: i, to: weekStart) {
                    let startOfDay = calendar.startOfDay(for: dayInWeek)
                    weeklyTotal += max(categoryHistory[startOfDay] ?? 0, 0)
                }
            }
            return weeklyTotal
            
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            
            var monthlyTotal = 0
            var currentDate = monthStart
            
            while currentDate <= monthEnd {
                let startOfDay = calendar.startOfDay(for: currentDate)
                monthlyTotal += max(categoryHistory[startOfDay] ?? 0, 0)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return monthlyTotal
            
        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components)!
            let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart)!
            
            var yearlyTotal = 0
            var currentDate = yearStart
            
            while currentDate <= yearEnd {
                let startOfDay = calendar.startOfDay(for: currentDate)
                yearlyTotal += max(categoryHistory[startOfDay] ?? 0, 0)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return yearlyTotal
            
        case .oneTime:
            return categoryHistory.values.reduce(0) { total, points in
                total + max(points, 0)
            }
        }
    }
    
    func totalPoints() -> Int {
        return dailyPointsHistory.values.reduce(0) { total, points in
            total + max(points, 0)
        }
    }
    
    func totalPointsForCategory(_ categoryId: UUID) -> Int {
        guard let categoryHistory = categoryPointsHistory[categoryId] else { return 0 }
        return categoryHistory.values.reduce(0) { total, points in
            total + max(points, 0)
        }
    }
    
    func rewardsFor(frequency: RewardFrequency) -> [Reward] {
        return activeRewards.filter { $0.frequency == frequency }
    }
    
    func rewardsForCategory(_ categoryId: UUID?) -> [Reward] {
        return activeRewards.filter { $0.categoryId == categoryId }
    }
    
    func generalRewards() -> [Reward] {
        return activeRewards.filter { $0.isGeneralReward }
    }
    
    func categorySpecificRewards() -> [Reward] {
        return activeRewards.filter { !$0.isGeneralReward }
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
        removeDuplicateRedemptions()
    }
    
    static let recalculatePointsOnLaunchKey = "recalculate_points_after_dedupe"
    
    /// Cleans redemptions that sync had counted more than once, here and on iCloud.
    private func removeDuplicateRedemptions() {
        var cleaned: [Reward] = []
        rewards = rewards.map { reward in
            let normalized = Reward.normalizedRedemptions(reward.redemptions)
            guard normalized != reward.redemptions else { return reward }
            var fixed = reward
            fixed.redemptions = normalized
            cleaned.append(fixed)
            return fixed
        }
        guard !cleaned.isEmpty else { return }
        saveRewards()
        print("🧹 Removed duplicate redemptions from \(cleaned.count) rewards")
        // Balances were reduced once per duplicate: work them out again.
        UserDefaults.standard.set(true, forKey: Self.recalculatePointsOnLaunchKey)
        Task { @MainActor in
            for reward in cleaned { CloudKitService.shared.saveReward(reward) }
        }
    }
    
    private func saveDailyPointsHistory() {
        do {
            let data = try JSONEncoder().encode(dailyPointsHistory)
            UserDefaults.standard.set(data, forKey: dailyPointsHistoryKey)
            UserDefaults.standard.synchronize()
            // NOTE: CloudKit sync is NOT triggered here to avoid upload loops on init.
            // Call syncDailyPointsToCloudKit() explicitly after user-driven changes.
        } catch {
            print("Error saving daily points history: \(error)")
        }
    }
    
    /// Points are no longer uploaded: every device works them out from the completed tasks and
    /// the redemptions, which sync on their own (`recalculateDailyPointsFromSources`). Uploading
    /// the whole history on every change was slow and made devices disagree.
    private func syncDailyPointsToCloudKit() {}
    
    private func loadDailyPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: dailyPointsHistoryKey) {
            do {
                dailyPointsHistory = try JSONDecoder().decode([Date: Int].self, from: data)
                
                dailyPointsHistory = dailyPointsHistory.compactMapValues { points in
                    return max(points, 0)
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
    
    private func saveCategoryPointsHistory() {
        do {
            let data = try JSONEncoder().encode(categoryPointsHistory)
            UserDefaults.standard.set(data, forKey: categoryPointsHistoryKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving category points history: \(error)")
        }
    }
    
    private func loadCategoryPointsHistory() {
        if let data = UserDefaults.standard.data(forKey: categoryPointsHistoryKey) {
            do {
                categoryPointsHistory = try JSONDecoder().decode([UUID: [Date: Int]].self, from: data)
                
                for (categoryId, history) in categoryPointsHistory {
                    let cleanedHistory = history.compactMapValues { points in
                        return max(points, 0)
                    }
                    categoryPointsHistory[categoryId] = cleanedHistory
                }
                
                saveCategoryPointsHistory()
            } catch {
                print("Error loading category points history: \(error)")
                categoryPointsHistory = [:]
                saveCategoryPointsHistory()
            }
        }
    }
    
    func recalculatePointsFromTasks() {
        print("🧮 Recalculating points history from tasks...")
        var newDaily: [Date: Int] = [:]
        var newCategory: [UUID: [Date: Int]] = [:]
        let calendar = Calendar.current
        
        for task in TaskManager.shared.tasks {
            guard task.hasRewardPoints, task.rewardPoints > 0 else { continue }
            for completionDate in task.completionDates {
                let day = calendar.startOfDay(for: completionDate)
                newDaily[day, default: 0] += task.rewardPoints
                if let categoryId = task.category?.id {
                    var hist = newCategory[categoryId] ?? [:]
                    hist[day, default: 0] += task.rewardPoints
                    newCategory[categoryId] = hist
                }
            }
        }
        
        dailyPointsHistory = newDaily
        categoryPointsHistory = newCategory
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
        objectWillChange.send()
        
        print("✅ Points history recalculated. Days: \(dailyPointsHistory.count), Categories: \(categoryPointsHistory.count)")
    }

    func recalculateDailyPointsFromSources() {
        print("🧮 Recalculating daily points from tasks and redemptions...")
        let calendar = Calendar.current
        
        // Base: punti guadagnati dai task (ogni completamento conta una volta)
        var newDaily: [Date: Int] = [:]
        for task in TaskManager.shared.tasks {
            guard task.hasRewardPoints, task.rewardPoints > 0 else { continue }
            for completionDate in Set(task.completionDates) {
                let day = calendar.startOfDay(for: completionDate)
                newDaily[day, default: 0] += task.rewardPoints
            }
        }
        
        // Base: punti per categoria dai task
        var newCategory: [UUID: [Date: Int]] = [:]
        for task in TaskManager.shared.tasks {
            guard task.hasRewardPoints, task.rewardPoints > 0, let categoryId = task.category?.id else { continue }
            for completionDate in Set(task.completionDates) {
                let day = calendar.startOfDay(for: completionDate)
                var hist = newCategory[categoryId] ?? [:]
                hist[day, default: 0] += task.rewardPoints
                newCategory[categoryId] = hist
            }
        }
        
        // Raccogli tutte le redenzioni con la relativa reward, ordinate cronologicamente
        var allRedemptions: [(reward: Reward, date: Date)] = []
        for reward in rewards {
            for redemptionDate in reward.redemptions {
                allRedemptions.append((reward, redemptionDate))
            }
        }
        allRedemptions.sort { $0.date < $1.date }
        
        // Sottrai riscatti applicando la logica di deduzione per periodo
        for (reward, redemptionDate) in allRedemptions {
            let startOfRedemption = calendar.startOfDay(for: redemptionDate)
            
            // 1. Se di categoria, scala anche da newCategory
            if let categoryId = reward.categoryId {
                let catDays: [Date]
                if reward.frequency == .oneTime {
                    catDays = (newCategory[categoryId]?.keys.filter { $0 <= startOfRedemption }.sorted(by: >)) ?? []
                } else {
                    catDays = eligibleDaysForDeduction(from: redemptionDate, frequency: reward.frequency, in: calendar)
                }
                var remCat = reward.pointsCost
                for day in catDays {
                    guard remCat > 0 else { break }
                    let current = newCategory[categoryId]?[day] ?? 0
                    guard current > 0 else { continue }
                    let deduct = min(current, remCat)
                    newCategory[categoryId]?[day] = current - deduct
                    remCat -= deduct
                }
            }
            
            // 2. Scala da newDaily
            let candidateDays: [Date]
            if reward.frequency == .oneTime {
                candidateDays = newDaily.keys.filter { $0 <= startOfRedemption }.sorted(by: >)
            } else {
                candidateDays = eligibleDaysForDeduction(from: redemptionDate, frequency: reward.frequency, in: calendar)
            }
            
            var remaining = reward.pointsCost
            for day in candidateDays {
                guard remaining > 0 else { break }
                let current = newDaily[day] ?? 0
                guard current > 0 else { continue }
                let deduct = min(current, remaining)
                newDaily[day] = current - deduct
                remaining -= deduct
            }
        }
        
        dailyPointsHistory = newDaily
        categoryPointsHistory = newCategory
        saveDailyPointsHistory()
        saveCategoryPointsHistory()
        objectWillChange.send()
        
        print("✅ Daily points normalized. Days: \(dailyPointsHistory.count), Categories: \(categoryPointsHistory.count)")
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let rewardsDidUpdate = Notification.Name("rewardsDidUpdate")
}

// MARK: - Date Extensions
// Moved to a shared extension to avoid duplication