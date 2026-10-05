//
//  SyncSupportTests.swift
//  SnapTaskTests
//

import CloudKit
import Foundation
import Testing
@testable import SnapTask_Pro

@MainActor
struct SyncSupportTests {

    /// Statistics add up this device's tracked time and the copies received from other devices.
    @Test func trackedTimeAddsUpAllDevices() {
        let defaults = UserDefaults.standard
        let keys = ["timeTracking", "taskMetadata", "timeTracking_otherDevices", "taskMetadata_otherDevices"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        keys.forEach { defaults.removeObject(forKey: $0) }

        let day = "2026-10-05T00:00:00Z"
        defaults.set([day: ["category_A": 1.0]], forKey: "timeTracking")
        TimeTrackingStats.applyRemote(deviceId: "mac", hours: [day: ["category_A": 0.5, "category_B": 2]],
                                      metadata: ["task_X": ["name": "Run"]])
        // The own copy coming back from iCloud is not counted twice.
        TimeTrackingStats.applyRemote(deviceId: TimeTrackingStats.deviceId, hours: [day: ["category_A": 1.0]], metadata: [:])

        let combined = TimeTrackingStats.combined()
        #expect(combined[day]?["category_A"] == 1.5)
        #expect(combined[day]?["category_B"] == 2)
        #expect(TimeTrackingStats.combinedMetadata()["task_X"]?["name"] == "Run")

        // A newer copy from the same device replaces the older one.
        TimeTrackingStats.applyRemote(deviceId: "mac", hours: [day: ["category_A": 0.75]], metadata: [:])
        #expect(TimeTrackingStats.combined()[day]?["category_A"] == 1.75)
        #expect(TimeTrackingStats.combined()[day]?["category_B"] == nil)
    }

    /// Offline and busy errors are retried; schema and permission errors are not.
    @Test func outboxRetriesOnlyTemporaryErrors() {
        #expect(CloudKitService.isRetryable(CKError(.networkUnavailable)))
        #expect(CloudKitService.isRetryable(CKError(.networkFailure)))
        #expect(CloudKitService.isRetryable(CKError(.notAuthenticated)))
        #expect(CloudKitService.isRetryable(CKError(.requestRateLimited)))
        #expect(!CloudKitService.isRetryable(CKError(.invalidArguments)))
        #expect(!CloudKitService.isRetryable(CKError(.serverRejectedRequest)))
        #expect(!CloudKitService.isRetryable(CKError(.permissionFailure)))
    }
}
