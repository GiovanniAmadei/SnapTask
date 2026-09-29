import Foundation
import ActivityKit
import os.log

/// Manages the lifecycle of the Pomodoro & Timer Live Activity
/// (Lock Screen + Dynamic Island).
///
/// Only available on iOS 16.2+. On older OS versions all calls are
/// safe no-ops, so callers don't need to guard availability.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let log = OSLog(subsystem: "com.snaptask.liveactivity", category: "pomodoro")

    private init() {
        reattachExistingActivity()
    }

    // MARK: - State

    /// Whether Live Activities are supported by the OS and enabled
    /// by the user in the system settings.
    var isSupported: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    // Kept as Any? so the property can exist on older iOS without
    // breaking compilation of this source file.
    private var activityHolder: Any?

    @available(iOS 16.2, *)
    private var activity: Activity<PomodoroActivityAttributes>? {
        get { activityHolder as? Activity<PomodoroActivityAttributes> }
        set { activityHolder = newValue }
    }

    // MARK: - Public API
 
    /// Start a new Live Activity for Pomodoro. Any existing activities are ended first.
    func start(
        taskName: String,
        categoryColorHex: String?,
        categoryName: String?,
        phase: PomodoroActivityAttributes.ContentState.Phase,
        timeRemaining: TimeInterval,
        phaseTotalDuration: TimeInterval,
        currentSession: Int,
        totalSessions: Int
    ) {
        guard #available(iOS 16.2, *), isSupported else { return }

        let previousActivities = Activity<PomodoroActivityAttributes>.activities

        let attrs = PomodoroActivityAttributes(
            taskName: taskName,
            categoryColorHex: categoryColorHex,
            categoryName: categoryName
        )

        let clampedRemaining = max(1, timeRemaining)
        let endDate = Date().addingTimeInterval(clampedRemaining)

        let state = PomodoroActivityAttributes.ContentState(
            phase: phase,
            endDate: endDate,
            phaseTotalDuration: max(1, phaseTotalDuration),
            pausedTimeRemaining: phase == .paused ? clampedRemaining : nil,
            currentSession: currentSession,
            totalSessions: totalSessions
        )

        do {
            let content = ActivityContent(
                state: state,
                staleDate: endDate.addingTimeInterval(5 * 60)
            )
            let new = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
            self.activity = new
            os_log("✅ Started Pomodoro Live Activity (id=%{public}@, phase=%{public}@)", log: log, type: .info, new.id, phase.rawValue)
            
            // Clean up previous activities without killing the new one
            Task {
                for old in previousActivities where old.id != new.id {
                    await old.end(nil, dismissalPolicy: .immediate)
                }
            }
        } catch {
            os_log("❌ Failed to start Live Activity: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }

    /// Update the current activity's state. Call this whenever the
    /// Pomodoro transitions (work→break, pause, resume, skip…).
    func update(
        phase: PomodoroActivityAttributes.ContentState.Phase,
        timeRemaining: TimeInterval,
        phaseTotalDuration: TimeInterval,
        currentSession: Int,
        totalSessions: Int
    ) {
        guard #available(iOS 16.2, *) else { return }
        
        let targetActivity = activity ?? Activity<PomodoroActivityAttributes>.activities.first
        guard let targetActivity else {
            os_log("update called but no active activity", log: log, type: .debug)
            return
        }
        self.activity = targetActivity

        let clampedRemaining = max(1, timeRemaining)
        let endDate = Date().addingTimeInterval(clampedRemaining)
        let state = PomodoroActivityAttributes.ContentState(
            phase: phase,
            endDate: endDate,
            phaseTotalDuration: max(1, phaseTotalDuration),
            pausedTimeRemaining: phase == .paused ? clampedRemaining : nil,
            currentSession: currentSession,
            totalSessions: totalSessions
        )

        Task {
            await targetActivity.update(
                ActivityContent(
                    state: state,
                    staleDate: endDate.addingTimeInterval(5 * 60)
                )
            )
        }
        os_log("Updated Live Activity (phase=%{public}@)", log: log, type: .debug, phase.rawValue)
    }

    /// Start a Live Activity for Simple Timer (stopwatch).
    func startSimpleTimer(
        taskName: String,
        categoryColorHex: String?,
        categoryName: String?,
        startDate: Date,
        isPaused: Bool = false,
        elapsedTime: TimeInterval = 0
    ) {
        guard #available(iOS 16.2, *), isSupported else { return }

        let previousActivities = Activity<PomodoroActivityAttributes>.activities

        let attrs = PomodoroActivityAttributes(
            taskName: taskName,
            categoryColorHex: categoryColorHex,
            categoryName: categoryName
        )

        let state = PomodoroActivityAttributes.ContentState(
            phase: .simpleTimer,
            endDate: startDate,
            phaseTotalDuration: 0,
            pausedTimeRemaining: isPaused ? elapsedTime : nil,
            currentSession: 1,
            totalSessions: 1
        )

        do {
            let content = ActivityContent(
                state: state,
                staleDate: Date().addingTimeInterval(24 * 60 * 60)
            )
            let new = try Activity.request(
                attributes: attrs,
                content: content,
                pushType: nil
            )
            self.activity = new
            os_log("✅ Started Simple Timer Live Activity (id=%{public}@)", log: log, type: .info, new.id)
            
            // Clean up previous activities without killing the new one
            Task {
                for old in previousActivities where old.id != new.id {
                    await old.end(nil, dismissalPolicy: .immediate)
                }
            }
        } catch {
            os_log("❌ Failed to start Simple Timer Live Activity: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }

    /// Update Simple Timer Live Activity state.
    func updateSimpleTimer(
        startDate: Date,
        isPaused: Bool,
        elapsedTime: TimeInterval
    ) {
        guard #available(iOS 16.2, *) else { return }
        
        let targetActivity = activity ?? Activity<PomodoroActivityAttributes>.activities.first
        guard let targetActivity else { return }
        self.activity = targetActivity

        let state = PomodoroActivityAttributes.ContentState(
            phase: .simpleTimer,
            endDate: startDate,
            phaseTotalDuration: 0,
            pausedTimeRemaining: isPaused ? elapsedTime : nil,
            currentSession: 1,
            totalSessions: 1
        )

        Task {
            await targetActivity.update(
                ActivityContent(
                    state: state,
                    staleDate: Date().addingTimeInterval(24 * 60 * 60)
                )
            )
        }
    }

    /// Gracefully terminate the current Live Activity.
    func end(dismissImmediately: Bool = true) {
        guard #available(iOS 16.2, *) else { return }
        let policy: ActivityUIDismissalPolicy = dismissImmediately ? .immediate : .default
        Task {
            for act in Activity<PomodoroActivityAttributes>.activities {
                await act.end(nil, dismissalPolicy: policy)
            }
            self.activity = nil
            os_log("🛑 Ended all Pomodoro/Timer Live Activities", log: self.log, type: .info)
        }
    }

    // MARK: - Private

    /// After an app relaunch ActivityKit may still hold a running
    /// activity. Reattach so we can continue updating it instead of
    /// orphaning a zombie on the Lock Screen.
    func reattachExistingActivity() {
        guard #available(iOS 16.2, *) else { return }
        if let existing = Activity<PomodoroActivityAttributes>.activities.first {
            self.activity = existing
            os_log("🔄 Reattached to existing Pomodoro/Timer Live Activity", log: log, type: .info)
        }
    }
}
