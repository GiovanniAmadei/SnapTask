import Foundation
import Combine
import WatchKit

@MainActor
final class WatchTimerEngine: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    static let shared = WatchTimerEngine()

    struct TimerContextSnapshot: Codable, Equatable {
        let taskId: UUID?
        let taskName: String?
        let categoryId: UUID?
        let categoryName: String?

        init(taskId: UUID?, taskName: String?, categoryId: UUID?, categoryName: String?) {
            self.taskId = taskId
            self.taskName = taskName
            self.categoryId = categoryId
            self.categoryName = categoryName
        }

        init(task: TodoTask?) {
            self.init(
                taskId: task?.id,
                taskName: task?.name,
                categoryId: task?.category?.id,
                categoryName: task?.category?.name
            )
        }
    }

    struct SimpleTimerState: Codable {
        var context: TimerContextSnapshot?
        var trackingSession: TrackingSession
        var accumulatedElapsed: TimeInterval
        var startedAt: Date?
        var isRunning: Bool
        var isPaused: Bool

        var currentElapsed: TimeInterval {
            let runningAddition = isRunning ? max(0, Date().timeIntervalSince(startedAt ?? Date())) : 0
            return accumulatedElapsed + runningAddition
        }
    }

    struct PomodoroTimerState: Codable {
        var context: TimerContextSnapshot?
        var trackingSession: TrackingSession
        var settings: PomodoroSettings
        var currentSession: Int
        var isWorkPhase: Bool
        var phaseRemaining: TimeInterval
        var totalWorkTime: TimeInterval
        var startedAt: Date?
        var isRunning: Bool
        var isPaused: Bool

        var currentPhaseDuration: TimeInterval {
            if isWorkPhase {
                return settings.workDuration
            }
            if currentSession % settings.sessionsUntilLongBreak == 0 {
                return settings.longBreakDuration
            }
            return settings.breakDuration
        }

        var currentRemaining: TimeInterval {
            let runningAddition = isRunning ? max(0, Date().timeIntervalSince(startedAt ?? Date())) : 0
            return max(0, phaseRemaining - runningAddition)
        }
    }

    enum Mode: String, Codable {
        case simple
        case pomodoro
    }

    struct PersistedState: Codable {
        var mode: Mode
        var simple: SimpleTimerState?
        var pomodoro: PomodoroTimerState?
    }

    @Published private(set) var persistedState: PersistedState?
    @Published private(set) var now: Date = Date()
    @Published private(set) var completedSimpleSession: TrackingSession?
    @Published private(set) var completedPomodoroSession: TrackingSession?

    private var tickTimer: Timer?
    private var runtimeSession: WKExtendedRuntimeSession?
    private var runtimeSessionIsActive = false

    private let stateKey = "activeTimerState"
    private let tickInterval: TimeInterval = 1

    private override init() {
        super.init()
        restorePersistedStateIfNeeded()
    }

    // MARK: - Public derived state
    var simpleTaskName: String? {
        persistedSimpleState?.context?.taskName
    }

    var simpleElapsedTime: TimeInterval {
        persistedSimpleState?.currentElapsed ?? 0
    }

    var simpleIsRunning: Bool {
        persistedSimpleState?.isRunning ?? false
    }

    var simpleIsPaused: Bool {
        persistedSimpleState?.isPaused ?? false
    }

    var simpleTrackingSession: TrackingSession? {
        persistedSimpleState?.trackingSession
    }

    var pomodoroTrackingSession: TrackingSession? {
        persistedPomodoroState?.trackingSession
    }

    var pomodoroTaskName: String? {
        persistedPomodoroState?.context?.taskName
    }

    var pomodoroCurrentSession: Int {
        persistedPomodoroState?.currentSession ?? 1
    }

    var pomodoroIsWorkPhase: Bool {
        persistedPomodoroState?.isWorkPhase ?? true
    }

    var pomodoroTimeRemaining: TimeInterval {
        persistedPomodoroState?.currentRemaining ?? 0
    }

    var pomodoroTotalWorkTime: TimeInterval {
        persistedPomodoroState?.totalWorkTime ?? 0
    }

    var pomodoroIsRunning: Bool {
        persistedPomodoroState?.isRunning ?? false
    }

    var pomodoroIsPaused: Bool {
        persistedPomodoroState?.isPaused ?? false
    }

    var pomodoroSettings: PomodoroSettings {
        persistedPomodoroState?.settings ?? .defaultSettings
    }

    // MARK: - Simple timer API
    func startSimpleTimer(task: TodoTask?) {
        let context = TimerContextSnapshot(task: task)
        let session = TrackingSession(
            taskId: task?.id,
            taskName: task?.name,
            mode: .simple,
            categoryId: task?.category?.id,
            categoryName: task?.category?.name
        )

        persistedState = PersistedState(
            mode: .simple,
            simple: SimpleTimerState(
                context: context,
                trackingSession: session,
                accumulatedElapsed: 0,
                startedAt: Date(),
                isRunning: true,
                isPaused: false
            ),
            pomodoro: nil
        )
        persist()
        beginTickingIfNeeded()
        beginRuntimeSupport()
    }

    func pauseSimpleTimer() {
        guard var simple = persistedSimpleState, simple.isRunning, let startedAt = simple.startedAt else { return }
        simple.accumulatedElapsed += max(0, Date().timeIntervalSince(startedAt))
        simple.startedAt = nil
        simple.isRunning = false
        simple.isPaused = true
        updateSimpleState(simple)
        stopTickingIfNeeded()
        endRuntimeSupportIfNeeded()
    }

    func resumeSimpleTimer() {
        guard var simple = persistedSimpleState, simple.isPaused else { return }
        simple.startedAt = Date()
        simple.isRunning = true
        simple.isPaused = false
        updateSimpleState(simple)
        beginTickingIfNeeded()
        beginRuntimeSupport()
    }

    func completeSimpleTimer() -> (session: TrackingSession?, elapsed: TimeInterval) {
        guard var simple = persistedSimpleState else { return (nil, 0) }
        let elapsed = simple.currentElapsed
        var completedSession = simple.trackingSession
        completedSession.elapsedTime = elapsed
        completedSession.totalDuration = elapsed
        completedSession.isCompleted = true
        completedSession.endTime = Date()
        completedSession.isRunning = false
        completedSession.isPaused = false

        completedSimpleSession = completedSession
        clearState()
        endRuntimeSupportIfNeeded()

        return (completedSession, elapsed)
    }

    func resetSimpleTimer() {
        clearState()
        endRuntimeSupportIfNeeded()
    }

    // MARK: - Pomodoro API
    func startPomodoro(task: TodoTask?, settings: PomodoroSettings) {
        let context = TimerContextSnapshot(task: task)
        let session = TrackingSession(
            taskId: task?.id,
            taskName: task?.name,
            mode: .pomodoro,
            categoryId: task?.category?.id,
            categoryName: task?.category?.name
        )

        persistedState = PersistedState(
            mode: .pomodoro,
            simple: nil,
            pomodoro: PomodoroTimerState(
                context: context,
                trackingSession: session,
                settings: settings,
                currentSession: 1,
                isWorkPhase: true,
                phaseRemaining: settings.workDuration,
                totalWorkTime: 0,
                startedAt: Date(),
                isRunning: true,
                isPaused: false
            )
        )
        persist()
        beginTickingIfNeeded()
        beginRuntimeSupport()
    }

    func pausePomodoro() {
        guard var pomodoro = persistedPomodoroState, pomodoro.isRunning, let startedAt = pomodoro.startedAt else { return }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        pomodoro.phaseRemaining = max(0, pomodoro.phaseRemaining - elapsed)
        pomodoro.startedAt = nil
        pomodoro.isRunning = false
        pomodoro.isPaused = true
        updatePomodoroState(pomodoro)
        stopTickingIfNeeded()
        endRuntimeSupportIfNeeded()
    }

    func resumePomodoro() {
        guard var pomodoro = persistedPomodoroState, pomodoro.isPaused else { return }
        pomodoro.startedAt = Date()
        pomodoro.isRunning = true
        pomodoro.isPaused = false
        updatePomodoroState(pomodoro)
        beginTickingIfNeeded()
        beginRuntimeSupport()
    }

    func skipBreak() {
        guard var pomodoro = persistedPomodoroState, !pomodoro.isWorkPhase else { return }
        pomodoro.currentSession += 1
        pomodoro.isWorkPhase = true
        pomodoro.phaseRemaining = pomodoro.settings.workDuration
        pomodoro.startedAt = Date()
        pomodoro.isRunning = true
        pomodoro.isPaused = false
        updatePomodoroState(pomodoro)
        beginTickingIfNeeded()
        beginRuntimeSupport()
    }

    func endPomodoro() -> (session: TrackingSession?, totalWorkTime: TimeInterval) {
        guard let pomodoro = persistedPomodoroState else { return (nil, 0) }
        var completedSession = pomodoro.trackingSession
        completedSession.elapsedTime = pomodoro.totalWorkTime
        completedSession.totalDuration = pomodoro.totalWorkTime
        completedSession.isCompleted = true
        completedSession.endTime = Date()
        completedSession.isRunning = false
        completedSession.isPaused = false

        completedPomodoroSession = completedSession
        clearState()
        endRuntimeSupportIfNeeded()

        return (completedSession, pomodoro.totalWorkTime)
    }

    func stopPomodoro() {
        clearState()
        endRuntimeSupportIfNeeded()
    }

    // MARK: - Restore and reconcile
    func restorePersistedStateIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let saved = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            persistedState = nil
            stopTickingIfNeeded()
            endRuntimeSupportIfNeeded()
            return
        }

        persistedState = saved
        now = Date()
        reconcileActiveTimer()

        if isAnyTimerActive {
            beginTickingIfNeeded()
            beginRuntimeSupport()
        } else {
            stopTickingIfNeeded()
            endRuntimeSupportIfNeeded()
        }
    }

    func updateCurrentTime() {
        now = Date()
        reconcileActiveTimer()
    }

    // MARK: - Internals
    private var persistedSimpleState: SimpleTimerState? {
        persistedState?.simple
    }

    private var persistedPomodoroState: PomodoroTimerState? {
        persistedState?.pomodoro
    }

    private var isAnyTimerActive: Bool {
        switch persistedState?.mode {
        case .simple:
            return persistedSimpleState?.isRunning == true || persistedSimpleState?.isPaused == true
        case .pomodoro:
            return persistedPomodoroState?.isRunning == true || persistedPomodoroState?.isPaused == true
        case .none:
            return false
        }
    }

    private func beginTickingIfNeeded() {
        guard tickTimer == nil else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }

    private func stopTickingIfNeeded() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func beginRuntimeSupport() {
        guard runtimeSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        runtimeSession = session
        session.start()
    }

    private func endRuntimeSupportIfNeeded() {
        runtimeSession?.invalidate()
        runtimeSession = nil
        runtimeSessionIsActive = false
    }

    private func reconcileActiveTimer() {
        switch persistedState?.mode {
        case .simple:
            reconcileSimpleTimer()
        case .pomodoro:
            reconcilePomodoroTimer()
        case .none:
            break
        }
    }

    private func reconcileSimpleTimer() {
        guard var simple = persistedSimpleState, simple.isRunning, let startedAt = simple.startedAt else { return }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        simple.accumulatedElapsed += elapsed
        simple.startedAt = Date()
        updateSimpleState(simple)
    }

    private func reconcilePomodoroTimer() {
        guard var pomodoro = persistedPomodoroState, pomodoro.isRunning, let startedAt = pomodoro.startedAt else { return }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        pomodoro.startedAt = Date()
        pomodoro.phaseRemaining = max(0, pomodoro.phaseRemaining - elapsed)
        if pomodoro.isWorkPhase {
            pomodoro.totalWorkTime += min(elapsed, pomodoro.settings.workDuration)
        }

        while pomodoro.phaseRemaining <= 0, pomodoro.isRunning {
            if pomodoro.isWorkPhase {
                if pomodoro.currentSession >= pomodoro.settings.totalSessions {
                    var completed = pomodoro.trackingSession
                    completed.elapsedTime = pomodoro.totalWorkTime + pomodoro.settings.workDuration
                    completed.totalDuration = completed.elapsedTime
                    completed.isCompleted = true
                    completed.endTime = Date()
                    completedPomodoroSession = completed
                    WatchSyncManager.shared.saveTrackingSession(completed)
                    clearState()
                    endRuntimeSupportIfNeeded()
                    return
                } else {
                    pomodoro.isWorkPhase = false
                    pomodoro.phaseRemaining = pomodoro.currentSession % pomodoro.settings.sessionsUntilLongBreak == 0
                        ? pomodoro.settings.longBreakDuration
                        : pomodoro.settings.breakDuration
                    pomodoro.startedAt = Date()
                }
            } else {
                pomodoro.currentSession += 1
                pomodoro.isWorkPhase = true
                pomodoro.phaseRemaining = pomodoro.settings.workDuration
                pomodoro.startedAt = Date()
            }
        }

        updatePomodoroState(pomodoro)
    }

    private func updateSimpleState(_ simple: SimpleTimerState) {
        persistedState = PersistedState(mode: .simple, simple: simple, pomodoro: nil)
        persist()
    }

    private func updatePomodoroState(_ pomodoro: PomodoroTimerState) {
        persistedState = PersistedState(mode: .pomodoro, simple: nil, pomodoro: pomodoro)
        persist()
    }

    private func clearState() {
        persistedState = nil
        UserDefaults.standard.removeObject(forKey: stateKey)
        stopTickingIfNeeded()
    }

    private func persist() {
        guard let persistedState else {
            clearState()
            return
        }

        do {
            let data = try JSONEncoder().encode(persistedState)
            UserDefaults.standard.set(data, forKey: stateKey)
        } catch {
            print("⌚️ Failed to persist timer state: \(error)")
        }
    }

    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        beginTickingIfNeeded()
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⌚️ Extended runtime session will expire")
        updateCurrentTime()
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        runtimeSession = nil
        if let error {
            print("⌚️ Extended runtime session invalidated: \(reason.rawValue) error=\(error)")
        } else {
            print("⌚️ Extended runtime session invalidated: \(reason.rawValue)")
        }
    }

    func consumeCompletedSimpleSession() {
        completedSimpleSession = nil
    }

    func consumeCompletedPomodoroSession() {
        completedPomodoroSession = nil
    }
}
