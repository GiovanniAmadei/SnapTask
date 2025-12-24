import Foundation
import Combine
import EventKit
import WidgetKit
import UIKit

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

    private static var lastWidgetReloadTime: Date = .distantPast

    private let appGroupUserDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")
    private let notificationManager = TaskNotificationManager.shared

    init() {
        loadTasks()
        loadTrackingSessions()
        setupCloudKitObservers()
        applyCarryOverIfNeeded(force: false)
        setupCarryOverObservers()
    }

    func refreshCarryOverIfNeeded() {
        applyCarryOverIfNeeded(force: false)
    }

    private func setupCarryOverObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyCarryOverIfNeeded(force: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyCarryOverIfNeeded(force: false)
            }
            .store(in: &cancellables)
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

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let oldWasAutoCarryOver = oldTask.autoCarryOver
            let newIsAutoCarryOver = task.autoCarryOver
            let taskIsInPast = calendar.startOfDay(for: task.startTime) < todayStart
            
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

            if !oldWasAutoCarryOver && newIsAutoCarryOver && taskIsInPast {
                applyCarryOverIfNeeded(force: true)
            }
            
            // Sync with CloudKit
            debouncedSaveTask(task)
            
            handleTaskCalendarSync(task, isNew: false)
            
            print("✅ Task updated: \(task.name)")
        }
    }

    /// Apply a task coming from a remote source (Watch/CloudKit) and trust its contents
    /// - If the task exists, replace it entirely (including completions)
    /// - If it does not exist, append it (create)
    func upsertTaskFromRemote(_ incoming: TodoTask) {
        isUpdatingFromSync = true
        defer { isUpdatingFromSync = false }

        print("📱 Upsert incoming task: \(incoming.name), category: \(incoming.category?.name ?? "none"), lastModified: \(incoming.lastModifiedDate ?? Date.distantPast)")

        if let index = tasks.firstIndex(where: { $0.id == incoming.id }) {
            tasks[index] = incoming
            print("🔁 Upsert remote: replaced task \(incoming.name)")
        } else {
            tasks.append(incoming)
            print("➕ Upsert remote: added new task \(incoming.name)")
        }

        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()

        applyCarryOverIfNeeded(force: false)
    }
    
    func updateAllTasks(_ newTasks: [TodoTask]) {
        isUpdatingFromSync = true
        
        tasks = newTasks
        
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        applyCarryOverIfNeeded(force: false)
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
        
        AttachmentService.deletePhoto(for: task.id)
        
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
        
        AttachmentService.deletePhoto(for: task.id)
        
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
            
            for (dateKey, completion) in task.completions {
                print(" [DEBUG] Existing completion: \(dateKey) -> isCompleted=\(completion.isCompleted), actualDuration=\(completion.actualDuration ?? -1), difficulty=\(completion.difficultyRating ?? -1), quality=\(completion.qualityRating ?? -1), notes=\(completion.notes ?? "nil")")
            }
            
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
            
            let oldActualDuration = completion.actualDuration
            
            if let actualDuration = actualDuration {
                if actualDuration > 0 {
                    completion.actualDuration = actualDuration
                    print(" [DEBUG] Set actualDuration to \(actualDuration)")
                } else {
                    completion.actualDuration = nil
                    print(" [DEBUG] Cleared actualDuration via 0")
                }
            }
            
            if let difficultyRating = difficultyRating {
                completion.difficultyRating = difficultyRating == 0 ? nil : difficultyRating
                print(" [DEBUG] Set difficultyRating to \(difficultyRating)")
            }
            
            if let qualityRating = qualityRating {
                completion.qualityRating = qualityRating == 0 ? nil : qualityRating
                print(" [DEBUG] Set qualityRating to \(qualityRating)")
            }
            
            if let notes = notes {
                completion.notes = notes.isEmpty ? nil : notes
                print(" [DEBUG] Set notes to \(notes)")
            }
            
            if completion.completionDate == nil && (completion.actualDuration != nil || completion.difficultyRating != nil || completion.qualityRating != nil || completion.notes != nil) {
                completion.completionDate = Date()
                print(" [DEBUG] Set completionDate to \(Date())")
            }
            
            print(" [DEBUG] Updated completion object: actualDuration=\(completion.actualDuration ?? -1), difficulty=\(completion.difficultyRating ?? -1), quality=\(completion.qualityRating ?? -1), notes=\(completion.notes ?? "nil")")
            
            task.completions[targetDate] = completion
            
            print(" [DEBUG] After assignment - task.completions[\(targetDate)]: actualDuration=\(task.completions[targetDate]?.actualDuration ?? -1), difficulty=\(task.completions[targetDate]?.difficultyRating ?? -1), quality=\(task.completions[targetDate]?.qualityRating ?? -1), notes=\(task.completions[targetDate]?.notes ?? "nil")")
            
            task.lastModifiedDate = Date()
            tasks[index] = task
            
            if oldActualDuration != completion.actualDuration {
                if completion.isCompleted, let newDuration = completion.actualDuration, newDuration > 0 {
                    syncActualDurationWithStatistics(
                        taskId: taskId,
                        taskName: task.name,
                        categoryId: task.category?.id,
                        categoryColor: task.category?.color,
                        oldDuration: oldActualDuration,
                        newDuration: newDuration,
                        for: targetDate
                    )
                } else {
                    syncActualDurationWithStatistics(
                        taskId: taskId,
                        taskName: task.name,
                        categoryId: task.category?.id,
                        categoryColor: task.category?.color,
                        oldDuration: oldActualDuration,
                        newDuration: nil,
                        for: targetDate
                    )
                }
            }
            
            print(" [DEBUG] Final task completions count: \(tasks[index].completions.count)")
            print(" [DEBUG] ==========================================")
            
            saveTasks()
            notifyTasksUpdated()
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
        
        // Usa la categoria invece del task per le statistiche
        let categoryKey: String
        let categoryName: String
        
        if let categoryId = categoryId {
            categoryKey = "category_\(categoryId.uuidString)"
            // Trova il nome della categoria attuale
            categoryName = CategoryManager.shared.categories.first(where: { $0.id == categoryId })?.name ?? "Unknown Category"
        } else {
            categoryKey = "uncategorized"
            categoryName = "Uncategorized"
        }
        
        // Initialize date entry if needed
        if timeTrackingData[dateKey] == nil {
            timeTrackingData[dateKey] = [:]
        }
        
        // Update the statistics entry
        if let newDuration = newDuration, newDuration > 0 {
            // Aggiungi o aggiorna l'entry per la categoria
            let newHours = newDuration / 3600.0
            let existingHours = timeTrackingData[dateKey]?[categoryKey] ?? 0.0
            timeTrackingData[dateKey]?[categoryKey] = existingHours + newHours
            print(" [STATS SYNC] Added to category '\(categoryName)': \(newHours) hours (total: \(existingHours + newHours))")
            
            // Se c'era una durata precedente, rimuovila
            if let oldDuration = oldDuration, oldDuration > 0 {
                let oldHours = oldDuration / 3600.0
                let updatedHours = max(0, (timeTrackingData[dateKey]?[categoryKey] ?? 0.0) - oldHours)
                if updatedHours > 0 {
                    timeTrackingData[dateKey]?[categoryKey] = updatedHours
                } else {
                    timeTrackingData[dateKey]?.removeValue(forKey: categoryKey)
                }
                print(" [STATS SYNC] Removed old duration: \(oldHours) hours")
            }
            
            // Store category metadata for display
            var categoryMetadata = UserDefaults.standard.dictionary(forKey: "categoryMetadata") as? [String: [String: String]] ?? [:]
            categoryMetadata[categoryKey] = [
                "name": categoryName,
                "color": categoryColor ?? "#6366F1"
            ]
            UserDefaults.standard.set(categoryMetadata, forKey: "categoryMetadata")
            
        } else {
            // Rimuovi la durata se è stata cancellata o settata a 0
            if let oldDuration = oldDuration, oldDuration > 0 {
                let oldHours = oldDuration / 3600.0
                let existingHours = timeTrackingData[dateKey]?[categoryKey] ?? 0.0
                let updatedHours = max(0, existingHours - oldHours)
                
                if updatedHours > 0 {
                    timeTrackingData[dateKey]?[categoryKey] = updatedHours
                } else {
                    timeTrackingData[dateKey]?.removeValue(forKey: categoryKey)
                }
                print(" [STATS SYNC] Removed from category '\(categoryName)': \(oldHours) hours")
            }
            
            // Clean up empty date entries
            if timeTrackingData[dateKey]?.isEmpty == true {
                timeTrackingData.removeValue(forKey: dateKey)
            }
        }
        
        // Pulisci i vecchi metadata dei task (per retrocompatibilità)
        let oldTaskKey = "task_\(taskId.uuidString)"
        for (dateKey, var dayData) in timeTrackingData {
            if dayData.keys.contains(oldTaskKey) {
                dayData.removeValue(forKey: oldTaskKey)
                if dayData.isEmpty {
                    timeTrackingData.removeValue(forKey: dateKey)
                } else {
                    timeTrackingData[dateKey] = dayData
                }
            }
        }
        
        var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
        taskMetadata.removeValue(forKey: oldTaskKey)
        UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
        
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
                completionDate: currentCompletion?.completionDate,
                notes: currentCompletion?.notes
            )
            
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
            
            let actualForDate = completion.actualDuration
            if isCompleting {
                if let ad = actualForDate, ad > 0 {
                    syncActualDurationWithStatistics(
                        taskId: taskId,
                        taskName: task.name,
                        categoryId: task.category?.id,
                        categoryColor: task.category?.color,
                        oldDuration: nil,
                        newDuration: ad,
                        for: completionDate
                    )
                }
            } else {
                if actualForDate != nil {
                    syncActualDurationWithStatistics(
                        taskId: taskId,
                        taskName: task.name,
                        categoryId: task.category?.id,
                        categoryColor: task.category?.color,
                        oldDuration: actualForDate,
                        newDuration: nil,
                        for: completionDate
                    )
                }
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
            print("🔄 Subtasks remained independent - not modified by main task toggle")
            
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
            
            print(" App: Saved \(tasks.count) tasks to both UserDefaults")
            NSLog(" APP DEBUG: Saved \(tasks.count) tasks to shared UserDefaults")
            
            // Ricarica i widget
            let now = Date()
            if now.timeIntervalSince(Self.lastWidgetReloadTime) >= 2.0 {
                Self.lastWidgetReloadTime = now
                WidgetCenter.shared.reloadAllTimelines()
            }
            
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
        // Preferisci i dati dal container condiviso (usato dal Widget)
        let sharedData = appGroupUserDefaults?.data(forKey: tasksKey)
        let standardData = UserDefaults.standard.data(forKey: tasksKey)
        if let data = sharedData ?? standardData {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
                migrateTaskDataIfNeeded()
                
                // Mantieni i due store allineati
                saveTasks()
            } catch {
                print("Error loading tasks: \(error)")
                tasks = []
            }
        }
    }

    /// Ricarica le task dall'App Group se diverse da quelle in memoria (es. modificate dal Widget)
    func reloadFromSharedIfAvailable() {
        guard let data = appGroupUserDefaults?.data(forKey: tasksKey) else { return }
        do {
            // Confronta con lo stato corrente per evitare reload inutili
            let current = try? JSONEncoder().encode(tasks)
            if current == data { return }
            let sharedTasks = try JSONDecoder().decode([TodoTask].self, from: data)
            tasks = sharedTasks
            // Allinea e notifica UI
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
            print("🔄 Reloaded tasks from shared App Group (widget changes applied)")
        } catch {
            print("Error reloading tasks from shared App Group: \(error)")
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
        // Remove persisted data
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: trackingSessionsKey)
        
        // Also clear in-memory state to ensure UI updates immediately
        tasks = []
        trackingSessions = []
        
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Trigger a sync to propagate deletions
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
            notificationManager.cancelAllNotificationsForTask(task.id)
            task.notificationId = nil
            print("🗑️ Notification(s) cancelled for task: \(task.name)")
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
           oldTask.name == newTask.name &&
           oldTask.notificationLeadTimeMinutes == newTask.notificationLeadTimeMinutes {
            return
        }
        
        notificationManager.cancelAllNotificationsForTask(oldTask.id)
        
        if newTask.hasNotification && newTask.hasSpecificTime {
            await handleTaskNotification(newTask, isNew: false)
        }
    }

    private func applyCarryOverIfNeeded(force: Bool) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let lastKey = "lastCarryOverCheckDate"
        
        if !force, let lastDate = UserDefaults.standard.object(forKey: lastKey) as? Date {
            if calendar.isDate(lastDate, inSameDayAs: todayStart) {
                return
            }
        }
        
        var changedTasks: [TodoTask] = []
        
        for i in tasks.indices {
            var task = tasks[i]
            guard task.autoCarryOver,
                  task.recurrence == nil,
                  task.timeScope == .today else { continue }
            
            let taskDay = calendar.startOfDay(for: task.startTime)
            if taskDay >= todayStart { continue }
            
            var newStart = task.startTime
            var moved = false
            
            while calendar.startOfDay(for: newStart) < todayStart {
                let dayKey = calendar.startOfDay(for: newStart)
                let wasCompleted = task.completions[dayKey]?.isCompleted ?? false
                if wasCompleted { break }
                if let plusOne = calendar.date(byAdding: .day, value: 1, to: newStart) {
                    newStart = plusOne
                    moved = true
                } else {
                    break
                }
            }
            
            if moved {
                task.startTime = newStart
                task.lastModifiedDate = Date()
                tasks[i] = task
                changedTasks.append(task)
                
                if task.hasNotification && task.hasSpecificTime {
                    Task { [oldTask = task] in
                        self.notificationManager.cancelAllNotificationsForTask(oldTask.id)
                        await self.handleTaskNotification(oldTask, isNew: false)
                    }
                }
            }
        }
        
        if !changedTasks.isEmpty {
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
            for t in changedTasks {
                debouncedSaveTask(t)
            }
        }
        
        UserDefaults.standard.set(todayStart, forKey: lastKey)
    }

}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
}