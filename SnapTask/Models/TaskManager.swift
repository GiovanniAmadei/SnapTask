import Foundation
import Combine
import WatchConnectivity
import EventKit
import WidgetKit

@MainActor
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [TodoTask] = []
    @Published var calendarIntegrationManager = CalendarIntegrationManager.shared
    @Published private(set) var trackingSessions: [TrackingSession] = []
    
    private let tasksKey = "savedTasks"
    private let trackingSessionsKey = "trackingSessions"
    
    private var isUpdatingFromSync = false
    private var cancellables: Set<AnyCancellable> = []
    private var saveTaskDebounceTimers: [UUID: Timer] = [:]

    private let appGroupUserDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")

    init() {
        loadTasks()
        loadTrackingSessions()
        setupCloudKitObservers()
    }
    
    private func setupCloudKitObservers() {
        // Listen for CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // CloudKit data changed, but we'll let the sync process handle it
                // to avoid infinite loops
                print("📥 CloudKit data changed notification received")
            }
            .store(in: &cancellables)
    }
    
    func addTask(_ task: TodoTask) {
        guard !isUpdatingFromSync else { return }
        
        print("Adding task: \(task.name)")
        print("Has recurrence: \(task.recurrence != nil)")
        
        // Assicurati che la task abbia una data di modifica aggiornata
        var updatedTask = task
        updatedTask.lastModifiedDate = Date()
        
        tasks.append(updatedTask)
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sync with CloudKit
        debouncedSaveTask(updatedTask)
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
        
        handleTaskCalendarSync(updatedTask, isNew: true)
        
        print("✅ Task added: \(updatedTask.name)")
    }
    
    func updateTask(_ updatedTask: TodoTask) {
        guard !isUpdatingFromSync else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            let oldTask = tasks[index]
            
            // Preserva i dati di completamento esistenti
            let existingCompletions = tasks[index].completions
            var task = updatedTask
            task.completions = existingCompletions
            
            // Aggiorna la data di modifica solo se non stiamo sincronizzando
            if !isUpdatingFromSync {
                task.lastModifiedDate = Date()
            }
            
            if task.hasRewardPoints && oldTask.rewardPoints != task.rewardPoints {
                // Per ogni data di completamento, aggiorna i punti
                for completionDate in task.completionDates {
                    // Rimuovi i vecchi punti
                    if oldTask.hasRewardPoints {
                        RewardManager.shared.addPoints(-oldTask.rewardPoints, on: completionDate)
                        if let categoryId = oldTask.category?.id {
                            RewardManager.shared.addPointsToCategory(-oldTask.rewardPoints, categoryId: categoryId, categoryName: oldTask.category?.name, on: completionDate)
                        }
                    }
                    // Aggiungi i nuovi punti
                    RewardManager.shared.addPoints(task.rewardPoints, on: completionDate)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: completionDate)
                    }
                }
            }
            
            tasks[index] = task
            
            saveTasks()
            notifyTasksUpdated()
            
            // Sync with CloudKit
            debouncedSaveTask(task)
            
            // Sincronizza con Apple Watch
            synchronizeWithWatch()
            
            handleTaskCalendarSync(task, isNew: false)
            
            print("✅ Task updated: \(task.name)")
        }
    }
    
    func updateAllTasks(_ newTasks: [TodoTask]) {
        isUpdatingFromSync = true
        
        tasks = newTasks
        
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        isUpdatingFromSync = false
        
        // Sync with Apple Watch
        synchronizeWithWatch()
        
        print("✅ Updated \(newTasks.count) tasks from sync")
    }
    
    func removeTask(_ task: TodoTask) {
        guard !isUpdatingFromSync else { return }
        
        print("TaskManager iOS: Removing task with ID: \(task.id.uuidString)")
        
        // Rimuovi i punti reward associati alla task se presente
        if task.hasRewardPoints {
            RewardManager.shared.removePointsFromTask(task)
        }
        
        // Rimuovi la task dall'array locale
        tasks.removeAll { $0.id == task.id }
        
        // Salva i cambiamenti nel database locale
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteTask(task)
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
        
        Task {
            await calendarIntegrationManager.deleteTaskFromCalendar(task.id)
        }
        
        print("✅ Task removed: \(task.name)")
    }
    
    func saveTrackingSession(_ session: TrackingSession) {
        guard !isUpdatingFromSync else { return }
        
        var updatedSession = session
        updatedSession.complete()
        
        trackingSessions.append(updatedSession)
        saveTrackingSessions()
        
        print("✅ Tracking session saved: \(formatDuration(session.effectiveWorkTime))")
    }
    
    func addTrackedTime(_ duration: TimeInterval, to taskId: UUID) {
        guard !isUpdatingFromSync else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].totalTrackedTime += duration
            tasks[index].lastTrackedDate = Date()
            tasks[index].lastModifiedDate = Date()
            
            saveTasks()
            notifyTasksUpdated()
            
            // Sync with CloudKit
            debouncedSaveTask(tasks[index])
            
            print("✅ Added \(formatDuration(duration)) to task: \(tasks[index].name)")
        }
    }
    
    func getTrackingSessions(for taskId: UUID? = nil) -> [TrackingSession] {
        if let taskId = taskId {
            return trackingSessions.filter { $0.taskId == taskId }
        } else {
            return trackingSessions
        }
    }
    
    func getTotalTrackedTime(for taskId: UUID) -> TimeInterval {
        return getTrackingSessions(for: taskId).reduce(0) { $0 + $1.effectiveWorkTime }
    }
    
    func getTodaysTrackedTime() -> TimeInterval {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return trackingSessions
            .filter { session in
                session.startTime >= today && session.startTime < tomorrow
            }
            .reduce(0) { $0 + $1.effectiveWorkTime }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func toggleTaskCompletion(_ taskId: UUID, on date: Date = Date()) {
        guard !isUpdatingFromSync else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[index]
            let startOfDay = Calendar.current.startOfDay(for: date)
            
            // DEBUG: Log current state
            print("🔄 Toggling task completion for \(task.name) on \(startOfDay)")
            print("🔄 Current completion: \(task.completions[startOfDay]?.isCompleted ?? false)")
            
            // Get current completion status
            let currentCompletion = task.completions[startOfDay]
            let wasCompleted = currentCompletion?.isCompleted ?? false
            let isCompleting = !wasCompleted
            
            // Update completion
            var completion = currentCompletion ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
            completion.isCompleted = isCompleting
            
            // If completing the main task, mark all subtasks as completed
            if isCompleting && !task.subtasks.isEmpty {
                completion.completedSubtasks = Set(task.subtasks.map { $0.id })
                // Update subtask models
                for i in 0..<task.subtasks.count {
                    task.subtasks[i].isCompleted = true
                }
            } else if !isCompleting {
                // If uncompleting, clear all subtask completions
                completion.completedSubtasks.removeAll()
                // Update subtask models
                for i in 0..<task.subtasks.count {
                    task.subtasks[i].isCompleted = false
                }
            }
            
            task.completions[startOfDay] = completion
            
            // Update completionDates
            if completion.isCompleted {
                if !task.completionDates.contains(startOfDay) {
                    task.completionDates.append(startOfDay)
                }
            } else {
                task.completionDates.removeAll { $0 == startOfDay }
            }
            
            // Tasks with subtasks get points handled in toggleSubtask
            if task.hasRewardPoints && task.subtasks.isEmpty {
                if isCompleting {
                    RewardManager.shared.addPoints(task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Added \(task.rewardPoints) points for completing task without subtasks")
                } else if wasCompleted {
                    RewardManager.shared.addPoints(-task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(-task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Removed \(task.rewardPoints) points for uncompleting task without subtasks")
                }
            }
            
            // Update modification date
            task.lastModifiedDate = Date()
            tasks[index] = task
            
            // DEBUG: Log new state
            print("🔄 New completion: \(completion.isCompleted)")
            print("🔄 Completions count: \(task.completions.count)")
            
            // Save and sync immediately
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
            
            // Debounced CloudKit sync
            debouncedSaveTask(task)
            
            // Sync with Apple Watch
            synchronizeWithWatch()
            
            if calendarIntegrationManager.settings.autoSyncOnTaskComplete {
                Task {
                    await calendarIntegrationManager.updateTaskInCalendar(task)
                }
            }
            
            print("✅ Task completion toggled: \(task.name)")
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        guard !isUpdatingFromSync else { return }
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[taskIndex]
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // DEBUG: Log current state
        print("🔄 Toggling subtask for \(task.name) on \(startOfDay)")
        
        var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        // Determine if we're completing or uncompleting the subtask
        let wasCompleted = completion.completedSubtasks.contains(subtaskId)
        
        print("🔄 Subtask was completed: \(wasCompleted)")
        
        if wasCompleted {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        task.completions[startOfDay] = completion
        
        // Update subtask completion state in the task model
        if let subtaskIndex = task.subtasks.firstIndex(where: { $0.id == subtaskId }) {
            task.subtasks[subtaskIndex].isCompleted = !wasCompleted
        }
        
        let shouldAutoComplete = SettingsViewModel.shared.autoCompleteTaskWithSubtasks
        
        if !task.subtasks.isEmpty {
            let allSubtasksCompleted = task.subtasks.allSatisfy { subtask in
                completion.completedSubtasks.contains(subtask.id)
            }
            
            let wasAllCompleted = task.subtasks.allSatisfy { subtask in
                subtask.id == subtaskId ? wasCompleted : completion.completedSubtasks.contains(subtask.id)
            }
            
            // Handle reward points
            if task.hasRewardPoints {
                if allSubtasksCompleted && !wasAllCompleted {
                    RewardManager.shared.addPoints(task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Added \(task.rewardPoints) points - all subtasks completed")
                } else if !allSubtasksCompleted && wasAllCompleted {
                    RewardManager.shared.addPoints(-task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(-task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Removed \(task.rewardPoints) points - not all subtasks completed")
                }
            }
            
            if shouldAutoComplete {
                if allSubtasksCompleted && !wasAllCompleted {
                    // All subtasks completed -> mark task as completed
                    completion.isCompleted = true
                    task.completions[startOfDay] = completion
                    if !task.completionDates.contains(startOfDay) {
                        task.completionDates.append(startOfDay)
                    }
                    print("✅ Auto-completed task - all subtasks done")
                } else if !allSubtasksCompleted && wasAllCompleted {
                    // Not all subtasks completed -> mark task as uncompleted
                    completion.isCompleted = false
                    task.completions[startOfDay] = completion
                    task.completionDates.removeAll { $0 == startOfDay }
                    print("❌ Auto-uncompleted task - not all subtasks done")
                }
            }
        }
        
        // Update modification date
        task.lastModifiedDate = Date()
        tasks[taskIndex] = task
        
        print("🔄 Subtask now completed: \(!wasCompleted)")
        print("🔄 Completed subtasks: \(completion.completedSubtasks.count)")
        
        // Save and sync immediately
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Debounced CloudKit sync
        debouncedSaveTask(task)
        
        // Sync with Apple Watch
        synchronizeWithWatch()
        
        if calendarIntegrationManager.settings.autoSyncOnTaskComplete {
            Task {
                await calendarIntegrationManager.updateTaskInCalendar(task)
            }
        }
        
        print("✅ Subtask toggled: \(task.name)")
    }
    
    private func debouncedSaveTask(_ task: TodoTask) {
        // Cancel existing timer for this task
        saveTaskDebounceTimers[task.id]?.invalidate()
        
        // Start new timer
        saveTaskDebounceTimers[task.id] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            CloudKitService.shared.saveTask(task)
            self?.saveTaskDebounceTimers.removeValue(forKey: task.id)
        }
    }
    
    func syncWithCloudKit() {
        // Trigger CloudKit sync
        CloudKitService.shared.syncNow()
    }
    
    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
            
            // Force immediate save to shared UserDefaults
            appGroupUserDefaults?.set(data, forKey: tasksKey)
            appGroupUserDefaults?.synchronize() // Force sync
            
            // UPDATE: Force widget refresh
            WidgetCenter.shared.reloadAllTimelines()
            
            print("📱 App: Saved \(tasks.count) tasks to both UserDefaults")
            NSLog("📱 APP DEBUG: Saved \(tasks.count) tasks to shared UserDefaults")
            
        } catch {
            print("Error saving tasks: \(error)")
        }
    }
    
    private func saveTrackingSessions() {
        do {
            let data = try JSONEncoder().encode(trackingSessions)
            UserDefaults.standard.set(data, forKey: trackingSessionsKey)
            
            // Also save to shared UserDefaults
            appGroupUserDefaults?.set(data, forKey: trackingSessionsKey)
            appGroupUserDefaults?.synchronize()
            
            print("📱 App: Saved \(trackingSessions.count) tracking sessions")
            
        } catch {
            print("Error saving tracking sessions: \(error)")
        }
    }
    
    private func loadTrackingSessions() {
        if let data = UserDefaults.standard.data(forKey: trackingSessionsKey) {
            do {
                trackingSessions = try JSONDecoder().decode([TrackingSession].self, from: data)
                print("✅ Loaded \(trackingSessions.count) tracking sessions")
            } catch {
                print("Error loading tracking sessions: \(error)")
                trackingSessions = []
            }
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            } catch {
                print("Error loading tasks: \(error)")
                tasks = []
            }
        }
    }
    
    private func notifyTasksUpdated() {
        NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)
    }
    
    // Function to synchronize tasks with Apple Watch
    private func synchronizeWithWatch() {
        let connectivityManager = WatchConnectivityManager.shared
        connectivityManager.updateWatchContext()
    }
    
    func startRegularSync() {
        guard CloudKitService.shared.isCloudKitEnabled else { return }
        
        // Initial sync
        CloudKitService.shared.syncNow()
        
        // Setup periodic sync every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if CloudKitService.shared.isCloudKitEnabled {
                CloudKitService.shared.syncNow()
            }
        }
    }
    
    // MARK: - Calendar Integration
    func syncTaskToCalendar(_ task: TodoTask) {
        guard calendarIntegrationManager.settings.isEnabled else { return }
        
        Task {
            await calendarIntegrationManager.syncTaskToCalendar(task)
        }
    }
    
    private func handleTaskCalendarSync(_ task: TodoTask, isNew: Bool) {
        let settings = calendarIntegrationManager.settings
        
        if isNew && settings.autoSyncOnTaskCreate {
            syncTaskToCalendar(task)
        } else if !isNew && settings.autoSyncOnTaskUpdate {
            Task {
                await calendarIntegrationManager.updateTaskInCalendar(task)
            }
        }
    }
    
    // For debugging purposes only
    func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: trackingSessionsKey)
        
        loadTasks()
        loadTrackingSessions()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizza con CloudKit in modo sicuro
        CloudKitService.shared.syncNow()
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
}
