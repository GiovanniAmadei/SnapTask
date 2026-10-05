//
//  TaskSyncMergeTests.swift
//  SnapTaskTests
//

import Foundation
import Testing
@testable import SnapTask_Pro

/// How two devices' copies of the same task are combined during iCloud sync.
struct TaskSyncMergeTests {

    private let monday = Date(timeIntervalSinceReferenceDate: 812_700_000)
    private var tuesday: Date { monday.addingTimeInterval(86_400) }

    private func habit(_ completions: [Date: TaskCompletion]) -> TodoTask {
        var task = TodoTask(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Run", startTime: monday)
        task.completions = completions
        task.completionDates = completions.filter { $0.value.isCompleted }.map(\.key)
        return task
    }

    private func done(at time: TimeInterval) -> TaskCompletion {
        var completion = TaskCompletion(isCompleted: true)
        completion.modifiedAt = Date(timeIntervalSinceReferenceDate: time)
        return completion
    }

    @Test func daysCompletedOnDifferentDevicesAreBothKept() {
        let iPhone = habit([monday: done(at: 100)])            // Monday, done offline
        let mac = habit([tuesday: done(at: 200)])              // Tuesday, edited later
        let merged = TodoTask.mergedCompletions(local: iPhone, remote: mac, preferRemote: true)
        #expect(Set(merged.completionDates) == [monday, tuesday])
    }

    @Test func reopeningADayOnAnotherDeviceWins() {
        let completedEarlier = habit([monday: done(at: 100)])
        var reopened = TaskCompletion(isCompleted: false)
        reopened.modifiedAt = Date(timeIntervalSinceReferenceDate: 200)
        let reopenedLater = habit([monday: reopened])
        let merged = TodoTask.mergedCompletions(local: completedEarlier, remote: reopenedLater, preferRemote: false)
        #expect(merged.completionDates.isEmpty)
        #expect(merged.completions[monday]?.isCompleted == false)
    }

    @Test func oldCompletionsWithoutTimesFollowTheNewerCopy() {
        let local = habit([monday: TaskCompletion(isCompleted: true)])
        let remote = habit([monday: TaskCompletion(isCompleted: false)])
        #expect(TodoTask.mergedCompletions(local: local, remote: remote, preferRemote: true).completionDates.isEmpty)
        #expect(TodoTask.mergedCompletions(local: local, remote: remote, preferRemote: false).completionDates == [monday])
    }

    @Test func modificationTimeSurvivesTheTripThroughICloud() throws {
        // Completions go to iCloud as JSON with ISO 8601 dates.
        var completion = TaskCompletion(isCompleted: true)
        completion.modifiedAt = Date(timeIntervalSinceReferenceDate: 812_700_123)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(TaskCompletion.self, from: encoder.encode(completion))
        #expect(back == completion)
    }
}
