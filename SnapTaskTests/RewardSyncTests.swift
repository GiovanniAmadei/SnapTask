//
//  RewardSyncTests.swift
//  SnapTaskTests
//

import Foundation
import Testing
@testable import SnapTask_Pro

/// How two devices' copies of a reward are combined during iCloud sync.
struct RewardSyncTests {

    /// iCloud stores redemption dates to the whole second (ISO 8601); devices kept fractions.
    private func iCloudCopy(_ date: Date) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: formatter.string(from: date))!
    }

    private func reward(redemptions: [Date], modified: Date = Date(timeIntervalSinceReferenceDate: 0)) -> Reward {
        var reward = Reward(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                            name: "Coffee", pointsCost: 10, frequency: .daily)
        reward.redemptions = redemptions
        reward.lastModifiedDate = modified
        return reward
    }

    @Test func oneRedemptionStaysOneAfterARoundTripThroughICloud() {
        let redeemed = Date(timeIntervalSinceReferenceDate: 812_800_000.734)
        let local = reward(redemptions: [redeemed])
        let remote = reward(redemptions: [iCloudCopy(redeemed)])

        let merged = Reward.merged(local: local, remote: remote)
        #expect(merged.redemptions.count == 1)

        // The other device merges the result again (what produced 3x before).
        let again = Reward.merged(local: reward(redemptions: [iCloudCopy(redeemed)]), remote: merged)
        #expect(again.redemptions.count == 1)
        #expect(again.redemptions == merged.redemptions)
    }

    @Test func existingDuplicatesAreCleaned() {
        let redeemed = Date(timeIntervalSinceReferenceDate: 812_800_000.734)
        let dates = [redeemed, iCloudCopy(redeemed), iCloudCopy(redeemed), redeemed.addingTimeInterval(0.5)]
        #expect(Reward.normalizedRedemptions(dates).count == 1)
    }

    @Test func realRedemptionsAreKept() {
        let morning = Date(timeIntervalSinceReferenceDate: 812_800_000)
        let afternoon = morning.addingTimeInterval(5 * 3600)
        let nextDay = morning.addingTimeInterval(24 * 3600)
        let merged = Reward.merged(local: reward(redemptions: [morning, afternoon]),
                                   remote: reward(redemptions: [morning, nextDay]))
        #expect(merged.redemptions == [morning, afternoon, nextDay])
    }

    @Test func latestEditWinsForTheOtherFields() {
        var older = reward(redemptions: [], modified: Date(timeIntervalSinceReferenceDate: 100))
        older.name = "Old name"
        var newer = reward(redemptions: [], modified: Date(timeIntervalSinceReferenceDate: 200))
        newer.name = "New name"
        newer.archivedDate = Date(timeIntervalSinceReferenceDate: 200)

        #expect(Reward.merged(local: older, remote: newer).name == "New name")
        #expect(Reward.merged(local: newer, remote: older).name == "New name")
        // An archive made on one device is not undone by the other device's older copy.
        #expect(Reward.merged(local: newer, remote: older).isArchived)
    }
}
