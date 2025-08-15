import Foundation
import Combine
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
    private let notificationManager = TaskNotificationManager.shared

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
                print("📡 CloudKit data changed notification received")
            }
            .store(in: &cancellables)
    }
    
    func addTask(_ task: TodoTask) async {
        guard !isUpdatingFromSync else { return }
        
        print("Adding task: \(task.name)")
        print("Has recurrence: \(task.recurrence != nil)")
        
        // Assicurati che la task abbia una data di modifica aggiornata
        var updatedTask = task
        updatedTask.lastModifiedDate = Date()
        
        // Handle notifications if enabled
        await handleTaskNotification(updatedTask, isNew: true)
        
        tasks.append(updatedTask)
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sync with CloudKit
        debouncedSaveTask(updatedTask)
        
        handleTaskCalendarSync(updatedTask, isNew: true)
        
        print("✅ Task added: \(updatedTask.name)")
    }
    
    func updateTask(_ updatedTask: TodoTask) async {
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
            
            // Handle notification changes
            await handleTaskNotificationUpdate(oldTask: oldTask, newTask: task)
            
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
        
        print(" Updated \(newTasks.count) tasks from sync")
    }
    
    func removeTask(_ task: TodoTask) async {
        guard !isUpdatingFromSync else { return }
        
        print("TaskManager iOS: Removing task with ID: \(task.id.uuidString)")
        
        // Rimuovi i punti reward associati alla task se presente
        if task.hasRewardPoints {
            RewardManager.shared.removePointsFromTask(task)
        }
        
        // Rimuovi tutte le durate tracked di questa task dalle statistiche
        removeTaskFromStatistics(task.id)
        
        // Rimuovi la task dall'array locale
        tasks.removeAll { $0.id == task.id }
        
        // Salva i cambiamenti nel database locale
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteTask(task)
        
        await calendarIntegrationManager.deleteTaskFromCalendar(task.id)
        
        print(" Task removed: \(task.name)")
    }
    
    func removeTaskFromRemoteSync(_ task: TodoTask) {
        print("TaskManager iOS: Removing task from remote sync with ID: \(task.id.uuidString)")
        
        // Rimuovi i punti reward associati alla task se presente
        if task.hasRewardPoints {
            RewardManager.shared.removePointsFromTask(task)
        }
        
        // Rimuovi tutte le durate tracked di questa task dalle statistiche
        removeTaskFromStatistics(task.id)
        
        // Rimuovi la task dall'array locale
        tasks.removeAll { $0.id == task.id }
        
        // Salva i cambiamenti nel database locale
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // NON chiamare CloudKitService.shared.deleteTask perché stiamo ricevendo la cancellazione da CloudKit
        
        // Rimuovi dal calendario se configurato
        Task {
            await calendarIntegrationManager.deleteTaskFromCalendar(task.id)
        }
        
        print("✅ Task removed from remote sync: \(task.name)")
    }
    
    func saveTrackingSession(_ session: TrackingSession) {
        guard !isUpdatingFromSync else { return }
        
        var updatedSession = session
        updatedSession.complete()
        
        trackingSessions.append(updatedSession)
        saveTrackingSessions()
        
        // Sync with CloudKit
        CloudKitService.shared.saveTrackingSession(updatedSession)
        
        CloudKitService.shared.syncNow()
        
        print(" Tracking session saved from \(updatedSession.deviceDisplayInfo): \(formatDuration(session.effectiveWorkTime))")
    }
    
    func updateAllTrackingSessions(_ newSessions: [TrackingSession]) {
        isUpdatingFromSync = true
        
        trackingSessions = newSessions
        
        saveTrackingSessions()
        objectWillChange.send()
        isUpdatingFromSync = false
        
        print(" Updated \(newSessions.count) tracking sessions from sync")
    }
    
    func deleteTrackingSession(_ session: TrackingSession) {
        guard !isUpdatingFromSync else { return }
        
        trackingSessions.removeAll { $0.id == session.id }
        saveTrackingSessions()
        
        // Delete from CloudKit
        CloudKitService.shared.deleteTrackingSession(session)
        
        print(" Tracking session deleted: \(session.deviceDisplayInfo)")
    }
    
    func getTrackingSessionsFromDevice(_ deviceType: DeviceType) -> [TrackingSession] {
        return trackingSessions.filter { $0.deviceType == deviceType }
    }
    
    func getAllDevicesUsed() -> [DeviceType] {
        let devices = Set(trackingSessions.map { $0.deviceType })
        return Array(devices).sorted { $0.rawValue < $1.rawValue }
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
            
            print(" Added \(formatDuration(duration)) to task: \(tasks[index].name)")
        }
    }
    
    func updateTaskRating(taskId: UUID, actualDuration: TimeInterval? = nil, difficultyRating: Int? = nil, qualityRating: Int? = nil, notes: String? = nil, for date: Date = Date()) {
        guard !isUpdatingFromSync else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[index]
            let targetDate = task.completionKey(for: date)
            
            print(" [DEBUG] ==========================================")
            print(" [DEBUG] Updating task rating for '\(task.name)' on \(targetDate)")
            print(" [DEBUG] Task ID: \(taskId.uuidString.prefix(8))")
            print(" [DEBUG] Task timeScope: \(task.timeScope.rawValue)")
            print(" [DEBUG] Total completions in task: \(task.completions.count)")
            
            // Log all existing completions
            for (dateKey, completion) in task.completions {
                print(" [DEBUG] Existing completion: \(dateKey) -> isCompleted=\(completion.isCompleted), actualDuration=\(completion.actualDuration ?? -1), difficulty=\(completion.difficultyRating ?? -1), quality=\(completion.qualityRating ?? -1), notes=\(completion.notes ?? "nil")")
            }
            
            // Get or create completion for this specific date - PRESERVE existing data, only update what's passed
            var completion = task.completions[targetDate] ?? TaskCompletion(
                isCompleted: false,
                completedSubtasks: [],
                actualDuration: nil,
                difficultyRating: nil,
                qualityRating: nil,
                completionDate: nil,
                notes: nil
            )
            
            print(" [DEBUG] Existing completion for \(targetDate): isCompleted=\(completion.isCompleted), actualDuration=\(completion.actualDuration ?? -1), difficulty=\(completion.difficultyRating ?? -1), quality=\(completion.qualityRating ?? -1), notes=\(completion.notes ?? "nil")")
            
            // Store old values for statistics sync
            let oldActualDuration = completion.actualDuration
            
            // Update ONLY the ratings that were passed in
            if let actualDuration = actualDuration {
                completion.actualDuration = actualDuration
                print(" [DEBUG] Set actualDuration to \(actualDuration)")
            }
            
            if let difficultyRating = difficultyRating {
                completion.difficultyRating = difficultyRating
                print(" [DEBUG] Set difficultyRating to \(difficultyRating)")
            }
            
            if let qualityRating = qualityRating {
                completion.qualityRating = qualityRating
                print(" [DEBUG] Set qualityRating to \(qualityRating)")
            }
            
            if let notes = notes {
                completion.notes = notes.isEmpty ? nil : notes
                print(" [DEBUG] Set notes to \(notes)")
            }
            
            // Set completion date if not already set and this completion has any data
            if completion.completionDate == nil && (completion.actualDuration != nil || completion.difficultyRating != nil || completion.qualityRating != nil || completion.notes != nil) {
                completion.completionDate = Date()
                print(" [DEBUG] Set completionDate to \(Date())")
            }
            
            print(" [DEBUG] Updated completion object: actualDuration=\(completion.actualDuration ?? -1), difficulty=\(completion.difficultyRating ?? -1), quality=\(completion.qualityRating ?? -1), notes=\(completion.notes ?? "nil")")
            
            // Update the completion in the task - this should NOT affect other dates
            task.completions[targetDate] = completion
            
            print(" [DEBUG] After assignment - task.completions[\(targetDate)]: actualDuration=\(task.completions[targetDate]?.actualDuration ?? -1), difficulty=\(task.completions[targetDate]?.difficultyRating ?? -1), quality=\(task.completions[targetDate]?.qualityRating ?? -1), notes=\(task.completions[targetDate]?.notes ?? "nil")")
            
            // Verify other dates are NOT affected
            for (dateKey, otherCompletion) in task.completions {
                if dateKey != targetDate {
                    print(" [DEBUG] Other completion \(dateKey): actualDuration=\(otherCompletion.actualDuration ?? -1), difficulty=\(otherCompletion.difficultyRating ?? -1), quality=\(otherCompletion.qualityRating ?? -1), notes=\(otherCompletion.notes ?? "nil")")
                }
            }
            
            task.lastModifiedDate = Date()
            tasks[index] = task
            
            // SYNC WITH STATISTICS: If actualDuration was updated, sync with time tracking data
            if actualDuration != nil && oldActualDuration != completion.actualDuration {
                syncActualDurationWithStatistics(
                    taskId: taskId,
                    taskName: task.name,
                    categoryId: task.category?.id,
                    categoryColor: task.category?.color,
                    oldDuration: oldActualDuration,
                    newDuration: completion.actualDuration,
                    for: targetDate
                )
            }
            
            print(" [DEBUG] Final task completions count: \(tasks[index].completions.count)")
            print(" [DEBUG] ==========================================")
            
            saveTasks()
            notifyTasksUpdated()
            
            // Sync with CloudKit
            debouncedSaveTask(task)
            
            print(" Updated ratings for task: \(task.name) on \(targetDate)")
        }
    }
    
    private func syncActualDurationWithStatistics(taskId: UUID, taskName: String, categoryId: UUID?, categoryColor: String?, oldDuration: TimeInterval?, newDuration: TimeInterval?, for date: Date) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        print(" [STATS SYNC] Syncing actualDuration change for task '\(taskName)' on \(targetDate)")
        print(" [STATS SYNC] Old duration: \(oldDuration ?? -1), New duration: \(newDuration ?? -1)")
        
        // Load existing time tracking data
        let trackingKey = "timeTracking"
        var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
        
        let dateKey = ISO8601DateFormatter().string(from: targetDate)
        let taskKey = "task_\(taskId.uuidString)"
        
        // Initialize date entry if needed
        if timeTrackingData[dateKey] == nil {
            timeTrackingData[dateKey] = [:]
        }
        
        // Update the statistics entry
        if let newDuration = newDuration, newDuration > 0 {
            // Set or update the time entry
            let newHours = newDuration / 3600.0
            timeTrackingData[dateKey]?[taskKey] = newHours
            print(" [STATS SYNC] Set statistics entry: \(newHours) hours")
            
            // Store task metadata for display
            var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
            taskMetadata[taskKey] = [
                "name": taskName,
                "color": categoryColor ?? "#6366F1"
            ]
            UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
            
        } else {
            // Clear the time entry if duration is 0 or nil
            timeTrackingData[dateKey]?.removeValue(forKey: taskKey)
            print(" [STATS SYNC] Removed statistics entry")
            
            // Clean up empty date entries
            if timeTrackingData[dateKey]?.isEmpty == true {
                timeTrackingData.removeValue(forKey: dateKey)
            }
        }
        
        // Save back to UserDefaults
        UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
        UserDefaults.standard.synchronize()
        
        // Notify statistics to refresh
        NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
        
        print(" [STATS SYNC] Statistics synchronized successfully")
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
            let completionDate = task.completionKey(for: date)
            
            print("🔄 Toggling task completion for '\(task.name)' on \(completionDate)")
            print("📍 Task ID: \(taskId.uuidString.prefix(8))")
            print("📅 Task timeScope: \(task.timeScope.rawValue)")
            
            let currentCompletion = task.completions[completionDate]
            let wasCompleted = currentCompletion?.isCompleted ?? false
            let isCompleting = !wasCompleted
            
            print("📊 Was completed: \(wasCompleted), Is completing: \(isCompleting)")
            
            let pointsAlreadyAwarded = task.completionDates.contains(completionDate)
            
            print("📊 Was completed: \(wasCompleted), Is completing: \(isCompleting)")
            print("🎯 Points already awarded: \(pointsAlreadyAwarded)")
            
            var completion = TaskCompletion(
                isCompleted: isCompleting,
                completedSubtasks: currentCompletion?.completedSubtasks ?? [],
                actualDuration: currentCompletion?.actualDuration,
                difficultyRating: currentCompletion?.difficultyRating,
                qualityRating: currentCompletion?.qualityRating,
                completionDate: currentCompletion?.completionDate
            )
            
            if isCompleting && !task.subtasks.isEmpty {
                completion.completedSubtasks = Set(task.subtasks.map { $0.id })
                for i in 0..<task.subtasks.count {
                    task.subtasks[i].isCompleted = true
                }
                print("✅ Marked all \(task.subtasks.count) subtasks as completed")
            } else if !isCompleting {
                completion.completedSubtasks.removeAll()
                for i in 0..<task.subtasks.count {
                    task.subtasks[i].isCompleted = false
                }
                print("❌ Unmarked all subtasks")
            }
            
            task.completions[completionDate] = completion
            
            if completion.isCompleted {
                if !task.completionDates.contains(completionDate) {
                    task.completionDates.append(completionDate)
                    print("📅 Added completion date: \(completionDate)")
                }
            } else {
                task.completionDates.removeAll { $0 == completionDate }
                print("📅 Removed completion date: \(completionDate)")
            }
            
            if task.hasRewardPoints && task.subtasks.isEmpty {
                if isCompleting && !pointsAlreadyAwarded {
                    RewardManager.shared.addPoints(task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Added \(task.rewardPoints) points for completing task without subtasks")
                } else if !isCompleting && pointsAlreadyAwarded {
                    RewardManager.shared.addPoints(-task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(-task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Removed \(task.rewardPoints) points for uncompleting task without subtasks")
                } else {
                    print("🎯 No points change needed (completing: \(isCompleting), already awarded: \(pointsAlreadyAwarded))")
                }
            }
            
            task.lastModifiedDate = Date()
            tasks[index] = task
            
            print("✅ New completion: \(completion.isCompleted)")
            print("📋 Completions count: \(task.completions.count)")
            print("📅 Completion dates: \(task.completionDates.count)")
            
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
            
            debouncedSaveTask(task)
            
            if calendarIntegrationManager.settings.autoSyncOnTaskComplete {
                Task {
                    await calendarIntegrationManager.updateTaskInCalendar(task)
                }
            }
            
            print("🔄 Task completion toggled: \(task.name)")
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        guard !isUpdatingFromSync else { return }
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[taskIndex]
        let completionDate = task.completionKey(for: date)
        
        print("🔄 Toggling subtask for \(task.name) on \(completionDate)")
        print("📅 Task timeScope: \(task.timeScope.rawValue)")
        
        var completion = task.completions[completionDate] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        let wasCompleted = completion.completedSubtasks.contains(subtaskId)
        
        print("📊 Subtask was completed: \(wasCompleted)")
        
        if wasCompleted {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        task.completions[completionDate] = completion
        
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
            
            let pointsAlreadyAwarded = task.completionDates.contains(completionDate)
            
            print("📊 All subtasks completed: \(allSubtasksCompleted), Was all completed: \(wasAllCompleted)")
            print("🎯 Points already awarded: \(pointsAlreadyAwarded)")
            
            if task.hasRewardPoints {
                if allSubtasksCompleted && !wasAllCompleted && !pointsAlreadyAwarded {
                    RewardManager.shared.addPoints(task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Added \(task.rewardPoints) points - all subtasks completed")
                } else if !allSubtasksCompleted && wasAllCompleted && pointsAlreadyAwarded {
                    RewardManager.shared.addPoints(-task.rewardPoints, on: date)
                    if let categoryId = task.category?.id {
                        RewardManager.shared.addPointsToCategory(-task.rewardPoints, categoryId: categoryId, categoryName: task.category?.name, on: date)
                    }
                    print("🎯 Removed \(task.rewardPoints) points - not all subtasks completed")
                } else {
                    print("🎯 No points change needed (all completed: \(allSubtasksCompleted), was all completed: \(wasAllCompleted), already awarded: \(pointsAlreadyAwarded))")
                }
            }
            
            if shouldAutoComplete {
                if allSubtasksCompleted && !wasAllCompleted {
                    completion.isCompleted = true
                    task.completions[completionDate] = completion
                    if !task.completionDates.contains(completionDate) {
                        task.completionDates.append(completionDate)
                    }
                    print("✅ Auto-completed task - all subtasks done")
                } else if !allSubtasksCompleted && wasAllCompleted {
                    completion.isCompleted = false
                    task.completions[completionDate] = completion
                    task.completionDates.removeAll { $0 == completionDate }
                    print("❌ Auto-uncompleted task - not all subtasks done")
                }
            }
        }
        
        task.lastModifiedDate = Date()
        tasks[taskIndex] = task
        
        print("✅ Subtask now completed: \(!wasCompleted)")
        print("📋 Completed subtasks: \(completion.completedSubtasks.count)")
        print("📅 Completion dates: \(task.completionDates.count)")
        
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        debouncedSaveTask(task)
        
        if calendarIntegrationManager.settings.autoSyncOnTaskComplete {
            Task {
                await calendarIntegrationManager.updateTaskInCalendar(task)
            }
        }
        
        print("🔄 Subtask toggled: \(task.name)")
    }

    private func debouncedSaveTask(_ task: TodoTask) {
        saveTaskDebounceTimers[task.id]?.invalidate()
        
        saveTaskDebounceTimers[task.id] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            CloudKitService.shared.saveTask(task)
            self?.saveTaskDebounceTimers.removeValue(forKey: task.id)
        }
    }
    
    func syncWithCloudKit() {
        CloudKitService.shared.syncNow()
    }
    
    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
            
            appGroupUserDefaults?.set(data, forKey: tasksKey)
            appGroupUserDefaults?.synchronize()
            
            WidgetCenter.shared.reloadAllTimelines()
            
            print(" App: Saved \(tasks.count) tasks to both UserDefaults")
            NSLog(" APP DEBUG: Saved \(tasks.count) tasks to shared UserDefaults")
            
        } catch {
            print("Error saving tasks: \(error)")
        }
    }
    
    private func saveTrackingSessions() {
        do {
            let data = try JSONEncoder().encode(trackingSessions)
            UserDefaults.standard.set(data, forKey: trackingSessionsKey)
            
            appGroupUserDefaults?.set(data, forKey: trackingSessionsKey)
            appGroupUserDefaults?.synchronize()
            
            print(" App: Saved \(trackingSessions.count) tracking sessions")
            
        } catch {
            print("Error saving tracking sessions: \(error)")
        }
    }
    
    private func loadTrackingSessions() {
        if let data = UserDefaults.standard.data(forKey: trackingSessionsKey) {
            do {
                trackingSessions = try JSONDecoder().decode([TrackingSession].self, from: data)
                print(" Loaded \(trackingSessions.count) tracking sessions")
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
                migrateTaskDataIfNeeded()
            } catch {
                print("Error loading tasks: \(error)")
                tasks = []
            }
        }
    }
    
    private func migrateTaskDataIfNeeded() {
        let migrationKey = "task_performance_data_migrated_v2"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        print(" Migrating task performance data to per-completion format...")
        
        var tasksMigrated = 0
        for i in 0..<tasks.count {
            var task = tasks[i]
            var wasModified = false
            
            for (date, completion) in task.completions {
                if completion.isCompleted && completion.actualDuration == nil && completion.difficultyRating == nil && completion.qualityRating == nil {
                    wasModified = true
                }
            }
            
            if wasModified {
                tasks[i] = task
                tasksMigrated += 1
            }
        }
        
        if tasksMigrated > 0 {
            saveTasks()
            print(" Migrated \(tasksMigrated) tasks to new performance data format")
        }
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        print(" Task performance data migration completed")
    }
    
    private func notifyTasksUpdated() {
        NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
    }
    
    func startRegularSync() {
        guard CloudKitService.shared.isCloudKitEnabled else { return }
        
        CloudKitService.shared.syncNow()
        
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if CloudKitService.shared.isCloudKitEnabled {
                CloudKitService.shared.syncNow()
            }
        }
    }
    
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
    
    func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: trackingSessionsKey)
        
        loadTasks()
        loadTrackingSessions()
        notifyTasksUpdated()
        objectWillChange.send()
        
        CloudKitService.shared.syncNow()
    }
    
    private func removeTaskFromStatistics(_ taskId: UUID) {
        print(" [STATS CLEANUP] Removing all time tracking data for task \(taskId.uuidString.prefix(8))")
        
        let trackingKey = "timeTracking"
        var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
        
        let taskKey = "task_\(taskId.uuidString)"
        var entriesRemoved = 0
        
        for (dateKey, var dayData) in timeTrackingData {
            if dayData.keys.contains(taskKey) {
                dayData.removeValue(forKey: taskKey)
                entriesRemoved += 1
                
                if dayData.isEmpty {
                    timeTrackingData.removeValue(forKey: dateKey)
                    print(" [STATS CLEANUP] Removed empty date entry: \(dateKey)")
                } else {
                    timeTrackingData[dateKey] = dayData
                }
            }
        }
        
        var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
        if taskMetadata.keys.contains(taskKey) {
            taskMetadata.removeValue(forKey: taskKey)
            UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
            print(" [STATS CLEANUP] Removed task metadata for \(taskKey)")
        }
        
        UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
        UserDefaults.standard.synchronize()
        
        print(" [STATS CLEANUP] Removed \(entriesRemoved) time tracking entries for deleted task")
        
        NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
    }

    func toggleTaskNotification(for taskId: UUID) async {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[index]
        task.hasNotification.toggle()
        
        if task.hasNotification {
            if task.recurrence != nil {
                let identifiers = await notificationManager.scheduleRecurringNotifications(for: task)
                task.notificationId = identifiers.isEmpty ? nil : identifiers.first
            } else {
                let identifier = await notificationManager.scheduleNotification(for: task)
                task.notificationId = identifier
            }
            
            if task.notificationId != nil {
                print("✅ Notification scheduled for task: \(task.name)")
            } else {
                task.hasNotification = false
                print("❌ Failed to schedule notification for task: \(task.name)")
            }
        } else {
            if let notificationId = task.notificationId {
                notificationManager.cancelNotification(withIdentifier: notificationId)
                task.notificationId = nil
                print("🗑️ Notification cancelled for task: \(task.name)")
            } else {
                notificationManager.cancelAllNotificationsForTask(task.id)
            }
        }
        
        task.lastModifiedDate = Date()
        tasks[index] = task
        
        saveTasks()
        notifyTasksUpdated()
        debouncedSaveTask(task)
        
        print(" Task notification toggled: \(task.name)")
    }

    private func handleTaskNotification(_ task: TodoTask, isNew: Bool) async {
        guard task.hasNotification && task.hasSpecificTime else { return }
        
        if task.recurrence != nil {
            let identifiers = await notificationManager.scheduleRecurringNotifications(for: task)
            if let firstId = identifiers.first, !identifiers.isEmpty {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index].notificationId = firstId
                }
            }
        } else {
            let identifier = await notificationManager.scheduleNotification(for: task)
            if let identifier = identifier {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index].notificationId = identifier
                }
            }
        }
    }
    
    private func handleTaskNotificationUpdate(oldTask: TodoTask, newTask: TodoTask) async {
        if oldTask.hasNotification == newTask.hasNotification &&
           oldTask.startTime == newTask.startTime &&
           oldTask.recurrence == newTask.recurrence &&
           oldTask.name == newTask.name {
            return
        }
        
        if let oldNotificationId = oldTask.notificationId {
            notificationManager.cancelNotification(withIdentifier: oldNotificationId)
        } else {
            notificationManager.cancelAllNotificationsForTask(oldTask.id)
        }
        
        if newTask.hasNotification && newTask.hasSpecificTime {
            await handleTaskNotification(newTask, isNew: false)
        }
    }

}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
}