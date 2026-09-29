//
//  SnapTaskTests.swift
//  SnapTaskTests
//
//  Created by giovanni on 15/01/25.
//

import Testing
import CloudKit
@testable import SnapTask_Pro

struct SnapTaskTests {

    @Test func testTaskNotificationFieldPreservation() async throws {
        let task = TodoTask(
            id: UUID(),
            name: "Recurring Notification Task",
            startTime: Date(),
            hasSpecificTime: true,
            recurrence: Recurrence(type: .daily, startDate: Date(), endDate: nil),
            hasNotification: true,
            notificationLeadTimeMinutes: 15
        )

        let repo = CloudKitRepository()
        let record = repo.taskToRecord(task)

        #expect(record["hasNotification"] as? Bool == true)
        #expect(record["notificationLeadTimeMinutes"] as? Int == 15)

        let decoded = repo.recordToTask(record)
        #expect(decoded != nil)
        #expect(decoded?.hasNotification == true)
        #expect(decoded?.notificationLeadTimeMinutes == 15)
        #expect(decoded?.hasSpecificTime == true)
    }

    @Test @MainActor func testWeeklyRewardRedemptionDeductsFromPriorDays() async throws {
        let rm = RewardManager.shared
        let calendar = Calendar.current
        let today = Date()
        
        // Ensure weekStart
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let day1 = calendar.date(byAdding: .day, value: 0, to: weekStart),
              let day2 = calendar.date(byAdding: .day, value: 1, to: weekStart) else {
            return
        }
        
        // Add 100 points to day 1, 105 points to day 2
        rm.addPoints(100, on: day1)
        rm.addPoints(105, on: day2)
        
        let availableBefore = rm.availablePoints(for: .weekly, on: day2)
        #expect(availableBefore >= 205)
        
        // Create a 100 point weekly reward
        let weeklyReward = Reward(
            name: "Test Weekly Reward",
            pointsCost: 100,
            frequency: .weekly
        )
        rm.addReward(weeklyReward)
        
        // Redeem on day 2 (or today)
        rm.redeemReward(weeklyReward, on: day2)
        
        // Check that points decreased by 100
        let availableAfter = rm.availablePoints(for: .weekly, on: day2)
        #expect(availableAfter == availableBefore - 100)
        
        // Clean up
        rm.removeReward(weeklyReward)
    }

    @Test @MainActor func testDailyRewardRequiresTodayPoints() async throws {
        let rm = RewardManager.shared
        let calendar = Calendar.current
        let today = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        
        // Clear today by ensuring 0 points today
        let startOfToday = calendar.startOfDay(for: today)
        let currentToday = rm.dailyPointsHistory[startOfToday] ?? 0
        if currentToday > 0 {
            rm.addPoints(-currentToday, on: today)
        }
        
        // Add points yesterday
        rm.addPoints(200, on: yesterday)
        
        // Daily available today must be 0
        #expect(rm.availablePoints(for: .daily, on: today) == 0)
        
        let dailyReward = Reward(
            name: "Test Daily Reward",
            pointsCost: 50,
            frequency: .daily
        )
        
        #expect(!dailyReward.canRedeem(availablePoints: rm.availablePoints(for: .daily, on: today)))
        
        // Now add 60 points today
        rm.addPoints(60, on: today)
        #expect(rm.availablePoints(for: .daily, on: today) == 60)
        #expect(dailyReward.canRedeem(availablePoints: rm.availablePoints(for: .daily, on: today)))
        
        // Redeem
        rm.redeemReward(dailyReward, on: today)
        #expect(rm.availablePoints(for: .daily, on: today) == 10)
    }

}
