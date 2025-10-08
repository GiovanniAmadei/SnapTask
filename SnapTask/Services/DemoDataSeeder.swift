import Foundation

@MainActor
final class DemoDataSeeder {
    static let shared = DemoDataSeeder()
    private init() {}

    struct SeededRefs {
        var categories: [String: Category] = [:]
        var tasks: [String: UUID] = [:]
        var taskSubtasks: [UUID: [UUID]] = [:]
        var rewardsByName: [String: Reward] = [:]
    }

    func seedDemoContent(replace: Bool) async {
        let cloudWasEnabled = CloudKitService.shared.isCloudKitEnabled
        CloudKitService.shared.disableCloudKitSync()

        SettingsViewModel.shared.autoCompleteTaskWithSubtasks = true

        if replace {
            await clearAllData()
        }

        var refs = SeededRefs()
        refs.categories = await seedCategories()
        refs.rewardsByName = await seedRewards(refs.categories)
        refs.tasks = await seedTasksAndSubtasks(refs.categories, &refs.taskSubtasks)

        let scopedIds = await seedScopedObjectives(refs.categories)
        for (k,v) in scopedIds { refs.tasks[k] = v }

        await seedOneYearOfCompletions(refs.tasks, taskSubtasks: refs.taskSubtasks)
        await seedScopedCompletions(scopedIds)

        await seedTrackingSessionsForYear(refs.tasks, categories: refs.categories)
        await seedRewardRedemptions(refs.rewardsByName)

        RewardManager.shared.recalculateDailyPointsFromSources()

        activatePro()

        if cloudWasEnabled {
            CloudKitService.shared.enableCloudKitSync()
        }
    }

    // MARK: - Clear
    private func clearAllData() async {
        let tm = TaskManager.shared
        let all = tm.tasks
        for t in all {
            await tm.removeTask(t)
        }
        tm.resetUserDefaults()

        let rm = RewardManager.shared
        await rm.performCompleteReset()

        CategoryManager.shared.performCompleteReset()

        let ud = UserDefaults.standard
        ud.removeObject(forKey: "timeTracking")
        ud.removeObject(forKey: "taskMetadata")
        ud.synchronize()
        NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
    }

    // MARK: - Categories
    private func seedCategories() async -> [String: Category] {
        // De-duplica per nome
        var existingByName = Dictionary(uniqueKeysWithValues: CategoryManager.shared.categories.map { ($0.name.lowercased(), $0) })

        let desired: [(String, String)] = [
            ("Work", "#3B82F6"),         // Blue - Professional tasks
            ("Health & Fitness", "#10B981"), // Green - Wellness activities  
            ("Personal", "#F59E0B"),     // Orange - Personal development
            ("Home & Family", "#EC4899"), // Pink - Domestic and family tasks
            ("Learning", "#8B5CF6"),     // Purple - Educational activities
            ("Finance", "#059669")       // Teal - Money management
        ]

        var map: [String: Category] = [:]
        for (name, color) in desired {
            if let found = existingByName[name.lowercased()] {
                map[name] = found
            } else {
                let cat = Category(id: UUID(), name: name, color: color)
                CategoryManager.shared.addCategory(cat)
                map[name] = cat
                existingByName[name.lowercased()] = cat
            }
        }
        return map
    }

    // MARK: - Rewards
    private func seedRewards(_ categories: [String: Category]) async -> [String: Reward] {
        let rm = RewardManager.shared

        func ensureReward(_ r: Reward) {
            if !rm.rewards.contains(where: { $0.name.caseInsensitiveCompare(r.name) == .orderedSame }) {
                rm.addReward(r)
            }
        }

        let general: [Reward] = [
            Reward(name: "Coffee Break", description: "Enjoy your favorite coffee", pointsCost: 50, frequency: .daily, icon: "cup.and.saucer"),
            Reward(name: "Movie Night", description: "Watch a movie with friends", pointsCost: 200, frequency: .weekly, icon: "tv"),
            Reward(name: "Favorite Meal", description: "Order from your favorite restaurant", pointsCost: 150, frequency: .weekly, icon: "fork.knife"),
            Reward(name: "Social Media Time", description: "30 minutes of guilt-free scrolling", pointsCost: 30, frequency: .daily, icon: "iphone"),
            Reward(name: "Weekend Trip", description: "Plan a short getaway", pointsCost: 1000, frequency: .monthly, icon: "car.fill")
        ]

        for r in general { ensureReward(r) }

        if let health = categories["Health & Fitness"] {
            ensureReward(Reward(name: "New Workout Gear", description: "Treat yourself to fitness equipment", pointsCost: 400, frequency: .monthly, icon: "dumbbell.fill", categoryId: health.id, categoryName: health.name))
            ensureReward(Reward(name: "Protein Smoothie", description: "Post-workout nutrition treat", pointsCost: 80, frequency: .weekly, icon: "drop.fill", categoryId: health.id, categoryName: health.name))
        }
        if let learning = categories["Learning"] {
            ensureReward(Reward(name: "New Book", description: "Buy a book you've been wanting", pointsCost: 250, frequency: .monthly, icon: "book.fill", categoryId: learning.id, categoryName: learning.name))
            ensureReward(Reward(name: "Online Course", description: "Enroll in a new course", pointsCost: 500, frequency: .monthly, icon: "graduationcap.fill", categoryId: learning.id, categoryName: learning.name))
        }
        if let work = categories["Work"] {
            ensureReward(Reward(name: "Desk Upgrade", description: "Improve your workspace", pointsCost: 300, frequency: .monthly, icon: "desktopcomputer", categoryId: work.id, categoryName: work.name))
        }

        // Build map by name
        return Dictionary(uniqueKeysWithValues: RewardManager.shared.rewards.map { ($0.name, $0) })
    }

    // MARK: - Tasks (+ subtasks)
    private func seedTasksAndSubtasks(_ categories: [String: Category], _ taskSubtasksOut: inout [UUID: [UUID]]) async -> [String: UUID] {
        let tm = TaskManager.shared
        var ids: [String: UUID] = [:]
        let cal = Calendar.current
        let today = Date()
        let todayStart = cal.startOfDay(for: today)

        let dailyStart = cal.date(byAdding: .year, value: -1, to: todayStart) ?? todayStart

        func makeTask(name: String,
                      icon: String,
                      categoryName: String?,
                      priority: Priority,
                      minutes: Int,
                      points: Int,
                      recurrence: Recurrence,
                      startAt: Date,
                      subtasks: [String] = []) async -> UUID {
            let cat: Category? = {
                if let cname = categoryName {
                    return categories[cname] ?? CategoryManager.shared.categories.first(where: { $0.name == cname })
                }
                return nil
            }()

            let task = TodoTask(
                name: name,
                description: nil,
                location: nil,
                startTime: startAt,
                hasSpecificTime: true,
                duration: TimeInterval(minutes * 60),
                hasDuration: minutes > 0,
                category: cat,
                priority: priority,
                icon: icon,
                recurrence: recurrence,
                pomodoroSettings: nil,
                subtasks: subtasks.map { Subtask(name: $0) },
                hasRewardPoints: points > 0,
                rewardPoints: points,
                hasNotification: false,
                notificationId: nil,
                timeScope: .today,
                scopeStartDate: nil,
                scopeEndDate: nil
            )
            await tm.addTask(task)
            if !subtasks.isEmpty {
                taskSubtasksOut[task.id] = task.subtasks.map { $0.id }
            }
            return task.id
        }

        // Daily recurrences - 7:00 AM
        let dailyMorning = Recurrence(type: .daily, startDate: dailyStart, endDate: nil, trackInStatistics: true)
        
        // Weekly recurrences - Monday, Wednesday, Friday
        let weeklyMWF: Recurrence = {
            let days: Set<Int> = [2, 4, 6] // Mon, Wed, Fri
            return Recurrence(type: .weekly(days: days), startDate: dailyStart, endDate: nil, trackInStatistics: true)
        }()
        
        // Weekly recurrences - Tuesday, Thursday  
        let weeklyTuTh: Recurrence = {
            let days: Set<Int> = [3, 5] // Tue, Thu
            return Recurrence(type: .weekly(days: days), startDate: dailyStart, endDate: nil, trackInStatistics: true)
        }()

        // Weekend tasks - Saturday, Sunday
        let weekendRec: Recurrence = {
            let days: Set<Int> = [1, 7] // Sun, Sat
            return Recurrence(type: .weekly(days: days), startDate: dailyStart, endDate: nil, trackInStatistics: true)
        }()

        // Monthly recurrences (1st of month)
        let monthlyRec = Recurrence(type: .monthly(days: [1]), startDate: dailyStart, endDate: nil, trackInStatistics: true)

        // Quarterly recurrences (1st of quarter)
        let quarterlyRec = Recurrence(type: .monthly(days: [1]), startDate: dailyStart, endDate: nil, trackInStatistics: true)

        // =================
        // DAILY TASKS (7:00 AM - 8:30 AM)
        // =================
        
        ids["Morning Workout"] = await makeTask(
            name: "Morning Workout",
            icon: "figure.run",
            categoryName: "Health & Fitness",
            priority: .high,
            minutes: 45,
            points: 20,
            recurrence: dailyMorning,
            startAt: cal.date(bySettingHour: 7, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["5min warm-up", "30min main workout", "10min cool-down"]
        )

        ids["Review Daily Goals"] = await makeTask(
            name: "Review Daily Goals",
            icon: "target",
            categoryName: "Personal",
            priority: .medium,
            minutes: 15,
            points: 10,
            recurrence: dailyMorning,
            startAt: cal.date(bySettingHour: 8, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Check calendar", "Set 3 priorities", "Quick meditation"]
        )

        ids["Check Emails"] = await makeTask(
            name: "Check Emails",
            icon: "envelope.fill",
            categoryName: "Work",
            priority: .medium,
            minutes: 20,
            points: 10,
            recurrence: dailyMorning,
            startAt: cal.date(bySettingHour: 9, minute: 0, second: 0, of: dailyStart) ?? dailyStart
        )

        ids["Read 15 Minutes"] = await makeTask(
            name: "Read 15 Minutes",
            icon: "book.fill",
            categoryName: "Learning",
            priority: .low,
            minutes: 15,
            points: 15,
            recurrence: dailyMorning,
            startAt: cal.date(bySettingHour: 21, minute: 30, second: 0, of: dailyStart) ?? dailyStart
        )

        ids["Evening Reflection"] = await makeTask(
            name: "Evening Reflection",
            icon: "moon.stars.fill",
            categoryName: "Personal",
            priority: .low,
            minutes: 10,
            points: 10,
            recurrence: dailyMorning,
            startAt: cal.date(bySettingHour: 22, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["What went well?", "What to improve?", "Tomorrow's focus"]
        )

        // =================
        // WORK TASKS (MWF)
        // =================
        
        ids["Team Standup"] = await makeTask(
            name: "Team Standup",
            icon: "person.3.fill",
            categoryName: "Work",
            priority: .high,
            minutes: 30,
            points: 15,
            recurrence: weeklyMWF,
            startAt: cal.date(bySettingHour: 9, minute: 30, second: 0, of: dailyStart) ?? dailyStart
        )

        ids["Deep Work Session"] = await makeTask(
            name: "Deep Work Session",
            icon: "brain.head.profile",
            categoryName: "Work",
            priority: .high,
            minutes: 90,
            points: 25,
            recurrence: weeklyMWF,
            startAt: cal.date(bySettingHour: 10, minute: 30, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Turn off notifications", "Pick 1 complex task", "Work for 90 minutes"]
        )

        // =================
        // FITNESS TASKS (Tue/Thu)
        // =================
        
        ids["Strength Training"] = await makeTask(
            name: "Strength Training",
            icon: "dumbbell.fill",
            categoryName: "Health & Fitness",
            priority: .medium,
            minutes: 60,
            points: 20,
            recurrence: weeklyTuTh,
            startAt: cal.date(bySettingHour: 18, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Upper body", "Core exercises", "Stretching"]
        )

        ids["Prepare Healthy Meals"] = await makeTask(
            name: "Prepare Healthy Meals",
            icon: "leaf.fill",
            categoryName: "Health & Fitness",
            priority: .medium,
            minutes: 45,
            points: 15,
            recurrence: weeklyTuTh,
            startAt: cal.date(bySettingHour: 19, minute: 30, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Plan 3 meals", "Prep ingredients", "Cook and store"]
        )

        // =================
        // WEEKEND TASKS
        // =================
        
        ids["House Cleaning"] = await makeTask(
            name: "House Cleaning",
            icon: "house.fill",
            categoryName: "Home & Family",
            priority: .medium,
            minutes: 90,
            points: 25,
            recurrence: weekendRec,
            startAt: cal.date(bySettingHour: 10, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Kitchen deep clean", "Vacuum all rooms", "Bathroom cleaning", "Laundry"]
        )

        ids["Family Time"] = await makeTask(
            name: "Family Time",
            icon: "heart.fill",
            categoryName: "Home & Family",
            priority: .high,
            minutes: 120,
            points: 30,
            recurrence: weekendRec,
            startAt: cal.date(bySettingHour: 14, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Quality conversation", "Shared activity", "Plan next week together"]
        )

        ids["Hobby Time"] = await makeTask(
            name: "Hobby Time",
            icon: "paintbrush.fill",
            categoryName: "Personal",
            priority: .low,
            minutes: 60,
            points: 20,
            recurrence: weekendRec,
            startAt: cal.date(bySettingHour: 16, minute: 30, second: 0, of: dailyStart) ?? dailyStart
        )

        // =================
        // MONTHLY TASKS
        // =================
        
        ids["Budget Review"] = await makeTask(
            name: "Budget Review",
            icon: "chart.pie.fill",
            categoryName: "Finance",
            priority: .high,
            minutes: 60,
            points: 40,
            recurrence: monthlyRec,
            startAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Review expenses", "Check savings goal", "Plan next month", "Update investments"]
        )

        ids["Skill Learning"] = await makeTask(
            name: "Skill Learning",
            icon: "graduationcap.fill",
            categoryName: "Learning",
            priority: .medium,
            minutes: 90,
            points: 35,
            recurrence: monthlyRec,
            startAt: cal.date(bySettingHour: 20, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Choose new skill", "Find resources", "Practice 1 hour", "Set learning goals"]
        )

        ids["Digital Declutter"] = await makeTask(
            name: "Digital Declutter",
            icon: "trash.fill",
            categoryName: "Personal",
            priority: .low,
            minutes: 45,
            points: 20,
            recurrence: monthlyRec,
            startAt: cal.date(bySettingHour: 18, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Clean photo library", "Organize files", "Unsubscribe from emails", "Clear downloads"]
        )

        // =================
        // QUARTERLY GOALS (Long-term objectives)
        // =================
        
        ids["Career Development"] = await makeTask(
            name: "Career Development",
            icon: "arrow.up.circle.fill",
            categoryName: "Work",
            priority: .high,
            minutes: 0,
            points: 100,
            recurrence: quarterlyRec,
            startAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Update resume", "Network with peers", "Learn new technology", "Set career goals", "Seek feedback"]
        )

        ids["Health Goals"] = await makeTask(
            name: "Health Goals",
            icon: "heart.text.square.fill",
            categoryName: "Health & Fitness",
            priority: .high,
            minutes: 0,
            points: 80,
            recurrence: quarterlyRec,
            startAt: cal.date(bySettingHour: 8, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Schedule health checkup", "Review fitness progress", "Update nutrition plan", "Set new fitness goals"]
        )

        ids["Financial Independence"] = await makeTask(
            name: "Financial Independence",
            icon: "banknote.fill",
            categoryName: "Finance",
            priority: .medium,
            minutes: 0,
            points: 120,
            recurrence: quarterlyRec,
            startAt: cal.date(bySettingHour: 20, minute: 0, second: 0, of: dailyStart) ?? dailyStart,
            subtasks: ["Review investment portfolio", "Increase emergency fund", "Research new opportunities", "Optimize tax strategy", "Track net worth"]
        )

        return ids
    }

    // MARK: - Year-long completions
    private func seedOneYearOfCompletions(_ tasks: [String: UUID], taskSubtasks: [UUID: [UUID]]) async {
        let tm = TaskManager.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -365, to: today) else { return }

        func rand(_ min: Int, _ max: Int) -> Int { Int.random(in: min...max) }

        // Completion rates based on task type and human nature
        let dailyRates: [String: Double] = [
            "Morning Workout": 0.75,      // High motivation but some skip days
            "Review Daily Goals": 0.85,   // Quick and easy, high completion
            "Check Emails": 0.95,         // Work necessity, very high completion
            "Read 15 Minutes": 0.60,      // Good intention but often skipped
            "Evening Reflection": 0.45    // Often forgotten at end of day
        ]
        
        let weeklyRates: [String: Double] = [
            "Team Standup": 0.90,         // Work requirement
            "Deep Work Session": 0.70,    // Challenging but valuable
            "Strength Training": 0.65,    // Requires motivation
            "Prepare Healthy Meals": 0.80, // Practical necessity
            "House Cleaning": 0.85,       // Necessary for living
            "Family Time": 0.95,          // High priority for relationships
            "Hobby Time": 0.55           // Often deprioritized
        ]
        
        let monthlyRates: [String: Double] = [
            "Budget Review": 0.90,        // Important financial habit
            "Skill Learning": 0.60,       // Good intentions, harder execution
            "Digital Declutter": 0.70     // Satisfying when done
        ]

        func variedRating(base: Int, variance: Int = 2) -> Int {
            let noise = rand(-variance, variance)
            return min(10, max(1, base + noise))
        }

        func shouldComplete(taskName: String, date: Date, baseRate: Double) -> Bool {
            let weekday = cal.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            
            // Slight adjustment for weekends
            var adjustedRate = baseRate
            if ["Morning Workout", "Read 15 Minutes"].contains(taskName) && isWeekend {
                adjustedRate *= 1.1 // Slightly better on weekends
            } else if ["Check Emails", "Review Daily Goals"].contains(taskName) && isWeekend {
                adjustedRate *= 0.8 // Less likely on weekends
            }
            
            return Double.random(in: 0...1) < adjustedRate
        }

        func completeTaskForDay(taskId: UUID, on date: Date, estimatedMinutes: Int, baseDifficulty: Int, baseQuality: Int) {
            let startOfDay = cal.startOfDay(for: date)
            if let subIds = taskSubtasks[taskId], !subIds.isEmpty {
                for sid in subIds { TaskManager.shared.toggleSubtask(taskId: taskId, subtaskId: sid, on: startOfDay) }
            } else {
                TaskManager.shared.toggleTaskCompletion(taskId, on: startOfDay)
            }
            
            let diff = variedRating(base: baseDifficulty)
            let qual = variedRating(base: baseQuality)
            let actualMinutes = max(5, estimatedMinutes + rand(-10, 15))
            let actual = Double(actualMinutes) * 60.0
            tm.updateTaskRating(taskId: taskId, actualDuration: actual, difficultyRating: diff, qualityRating: qual, notes: nil, for: startOfDay)
        }

        var day = start
        while day <= today {
            let weekday = cal.component(.weekday, from: day)

            // Daily tasks
            for (name, estimatedMinutes, baseDiff, baseQual) in [
                ("Morning Workout", 45, 6, 8),
                ("Review Daily Goals", 15, 3, 7),
                ("Check Emails", 20, 4, 6),
                ("Read 15 Minutes", 15, 2, 8),
                ("Evening Reflection", 10, 2, 7)
            ] {
                if let rate = dailyRates[name],
                   shouldComplete(taskName: name, date: day, baseRate: rate),
                   let id = tasks[name] {
                    completeTaskForDay(taskId: id, on: day, estimatedMinutes: estimatedMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                }
            }

            // Weekly tasks - MWF
            if [2, 4, 6].contains(weekday) {
                for (name, estimatedMinutes, baseDiff, baseQual) in [
                    ("Team Standup", 30, 3, 7),
                    ("Deep Work Session", 90, 7, 8)
                ] {
                    if let rate = weeklyRates[name],
                       shouldComplete(taskName: name, date: day, baseRate: rate),
                       let id = tasks[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: estimatedMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }
            
            // Weekly tasks - Tue/Thu
            if [3, 5].contains(weekday) {
                for (name, estimatedMinutes, baseDiff, baseQual) in [
                    ("Strength Training", 60, 6, 7),
                    ("Prepare Healthy Meals", 45, 4, 8)
                ] {
                    if let rate = weeklyRates[name],
                       shouldComplete(taskName: name, date: day, baseRate: rate),
                       let id = tasks[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: estimatedMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }

            // Weekend tasks
            if [1, 7].contains(weekday) {
                for (name, estimatedMinutes, baseDiff, baseQual) in [
                    ("House Cleaning", 90, 5, 6),
                    ("Family Time", 120, 2, 9),
                    ("Hobby Time", 60, 3, 8)
                ] {
                    if let rate = weeklyRates[name],
                       shouldComplete(taskName: name, date: day, baseRate: rate),
                       let id = tasks[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: estimatedMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }

            // Monthly tasks (1st of month)
            let dom = cal.component(.day, from: day)
            if dom == 1 {
                for (name, estimatedMinutes, baseDiff, baseQual) in [
                    ("Budget Review", 60, 5, 8),
                    ("Skill Learning", 90, 6, 7),
                    ("Digital Declutter", 45, 3, 6)
                ] {
                    if let rate = monthlyRates[name],
                       shouldComplete(taskName: name, date: day, baseRate: rate),
                       let id = tasks[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: estimatedMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }

            // Quarterly tasks (1st of quarter: Jan 1, Apr 1, Jul 1, Oct 1)
            let month = cal.component(.month, from: day)
            if dom == 1 && [1, 4, 7, 10].contains(month) {
                for (name, estimatedMinutes, baseDiff, baseQual) in [
                    ("Career Development", 0, 6, 8),      // No set duration - project-based
                    ("Health Goals", 0, 5, 8),
                    ("Financial Independence", 0, 7, 9)
                ] {
                    if Double.random(in: 0...1) < 0.75,   // 75% completion rate for quarterly goals
                       let id = tasks[name] {
                        if let subIds = taskSubtasks[id], !subIds.isEmpty {
                            // Complete some subtasks (not necessarily all)
                            let numToComplete = rand(2, subIds.count)
                            for sid in subIds.prefix(numToComplete) {
                                TaskManager.shared.toggleSubtask(taskId: id, subtaskId: sid, on: cal.startOfDay(for: day))
                            }
                        }
                        tm.updateTaskRating(taskId: id, actualDuration: Double(estimatedMinutes) * 60.0, difficultyRating: baseDiff, qualityRating: baseQual, notes: nil, for: day)
                    }
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Ensure today has some completions for demo purposes
        let todayTasks = [
            ("Morning Workout", 45, 6, 8),
            ("Review Daily Goals", 15, 3, 7), 
            ("Check Emails", 25, 4, 6)
        ]
        
        for (name, est, diff, qual) in todayTasks {
            if let id = tasks[name] {
                completeTaskForDay(taskId: id, on: today, estimatedMinutes: est, baseDifficulty: diff, baseQuality: qual)
            }
        }
    }

    // MARK: - Tracking Sessions (realistic distribution across year)
    private func seedTrackingSessionsForYear(_ tasks: [String: UUID], categories: [String: Category]) async {
        let tm = TaskManager.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -180, to: today) else { return }

        func sessionDate(_ base: Date, hour: Int, minute: Int = 0) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: base)
            comps.hour = hour
            comps.minute = minute
            return cal.date(from: comps) ?? base
        }

        func createSession(taskName: String, taskId: UUID, categoryName: String?, date: Date, hour: Int, durationMinutes: Int) {
            let categoryId = categories[categoryName ?? ""]?.id
            let sess = TrackingSession(
                id: UUID(),
                taskId: taskId,
                taskName: taskName,
                mode: .simple,
                categoryId: categoryId,
                categoryName: categoryName,
                startTime: sessionDate(date, hour: hour),
                elapsedTime: TimeInterval(durationMinutes * 60),
                isRunning: false,
                isPaused: false
            )
            tm.saveTrackingSession(sess)
        }

        var day = start
        while day <= today {
            let weekday = cal.component(.weekday, from: day)
            
            // Work sessions (Mon-Fri, 2-3 times per week)
            if (2...6).contains(weekday) && Double.random(in: 0...1) < 0.4 {
                if let deepWorkId = tasks["Deep Work Session"] {
                    createSession(
                        taskName: "Deep Work Session",
                        taskId: deepWorkId,
                        categoryName: "Work",
                        date: day,
                        hour: 10,
                        durationMinutes: Int.random(in: 75...105)
                    )
                }
            }
            
            // Morning workout tracking (3-4 times per week)
            if Double.random(in: 0...1) < 0.5 {
                if let workoutId = tasks["Morning Workout"] {
                    createSession(
                        taskName: "Morning Workout",
                        taskId: workoutId,
                        categoryName: "Health & Fitness",
                        date: day,
                        hour: 7,
                        durationMinutes: Int.random(in: 35...50)
                    )
                }
            }
            
            // Strength training (Tue/Thu)
            if [3, 5].contains(weekday) && Double.random(in: 0...1) < 0.7 {
                if let strengthId = tasks["Strength Training"] {
                    createSession(
                        taskName: "Strength Training",
                        taskId: strengthId,
                        categoryName: "Health & Fitness",
                        date: day,
                        hour: 18,
                        durationMinutes: Int.random(in: 50...70)
                    )
                }
            }
            
            // Learning sessions (weekends mostly)
            if [1, 7].contains(weekday) && Double.random(in: 0...1) < 0.3 {
                if let readId = tasks["Read 15 Minutes"] {
                    createSession(
                        taskName: "Read 15 Minutes",
                        taskId: readId,
                        categoryName: "Learning",
                        date: day,
                        hour: 20,
                        durationMinutes: Int.random(in: 15...45)
                    )
                }
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Add some sessions for today
        if let workoutId = tasks["Morning Workout"] {
            createSession(
                taskName: "Morning Workout",
                taskId: workoutId,
                categoryName: "Health & Fitness",
                date: today,
                hour: 7,
                durationMinutes: 42
            )
        }
        
        if let deepWorkId = tasks["Deep Work Session"] {
            createSession(
                taskName: "Deep Work Session",
                taskId: deepWorkId,
                categoryName: "Work",
                date: today,
                hour: 10,
                durationMinutes: 87
            )
        }
    }

    // MARK: - Reward Redemptions (realistic spending patterns)
    private func seedRewardRedemptions(_ rewardsByName: [String: Reward]) async {
        let rm = RewardManager.shared
        let cal = Calendar.current
        let today = Date()

        func daysAgo(_ n: Int) -> Date {
            return cal.date(byAdding: .day, value: -n, to: today) ?? today
        }

        func monthsAgo(_ n: Int) -> Date {
            return cal.date(byAdding: .month, value: -n, to: today) ?? today
        }

        // Daily rewards - realistic coffee habits (not every day)
        if let coffee = rewardsByName["Coffee Break"] {
            for d in [1, 3, 5, 7, 10, 12, 15, 18, 22, 25] {
                rm.redeemReward(coffee, on: daysAgo(d))
            }
        }
        
        // Social media time (very frequent, modern habit)
        if let social = rewardsByName["Social Media Time"] {
            for d in Array(1...30).filter({ _ in Double.random(in: 0...1) < 0.6 }) {
                rm.redeemReward(social, on: daysAgo(d))
            }
        }

        // Weekly rewards - realistic entertainment spending
        if let movie = rewardsByName["Movie Night"] {
            for w in [1, 3, 6, 8] { // About once per week
                rm.redeemReward(movie, on: daysAgo(w * 7))
            }
        }
        
        if let meal = rewardsByName["Favorite Meal"] {
            for w in [2, 4, 7, 9, 11] { // Bit more frequent
                rm.redeemReward(meal, on: daysAgo(w * 7 - 2))
            }
        }
        
        if let smoothie = rewardsByName["Protein Smoothie"] {
            for w in [1, 2, 4, 6, 8, 10] { // Post-workout treats
                rm.redeemReward(smoothie, on: daysAgo(w * 7 + 1))
            }
        }

        // Monthly rewards - bigger purchases
        if let book = rewardsByName["New Book"] {
            rm.redeemReward(book, on: monthsAgo(1))
            rm.redeemReward(book, on: monthsAgo(3))
            rm.redeemReward(book, on: monthsAgo(5))
        }
        
        if let gear = rewardsByName["New Workout Gear"] {
            rm.redeemReward(gear, on: monthsAgo(2))
            rm.redeemReward(gear, on: monthsAgo(6))
        }
        
        if let course = rewardsByName["Online Course"] {
            rm.redeemReward(course, on: monthsAgo(4))
        }
        
        if let desk = rewardsByName["Desk Upgrade"] {
            rm.redeemReward(desk, on: monthsAgo(3))
        }

        // Bigger rewards - less frequent
        if let trip = rewardsByName["Weekend Trip"] {
            rm.redeemReward(trip, on: monthsAgo(2))
            rm.redeemReward(trip, on: monthsAgo(8))
        }
    }

    // MARK: - Force Pro Active
    private func activatePro() {
        let exp = Date().addingTimeInterval(60*60*24*365*10)
        SubscriptionManager.shared.subscriptionStatus = .subscribed(expirationDate: exp)
        UserDefaults.standard.set(exp, forKey: "subscriptionExpirationDate")
        UserDefaults.standard.set("subscribed", forKey: "subscriptionStatusType")
        UserDefaults.standard.synchronize()
    }

    private func seedScopedObjectives(_ categories: [String: Category]) async -> [String: UUID] {
        var ids: [String: UUID] = [:]
        let cal = Calendar.current
        let today = Date()
        let weekAnchor = cal.startOfWeek(for: today)
        let monthAnchor = cal.startOfMonth(for: today)
        let yearAnchor = cal.startOfYear(for: today)

        func cat(_ name: String) -> Category? {
            categories[name] ?? CategoryManager.shared.categories.first(where: { $0.name == name })
        }

        // Weekly objectives (recurring weekly, no specific day-of-week, interval=1)
        let weeklyRec: Recurrence = {
            var r = Recurrence(type: .weekly(days: []), startDate: weekAnchor, endDate: nil, trackInStatistics: true)
            r.weekInterval = 1
            return r
        }()
        if let c = cat("Personal") {
            ids["Weekly Planning"] = await makeScopedTask(
                name: "Weekly Planning",
                icon: "calendar.badge.clock",
                category: c,
                priority: .medium,
                minutes: 30,
                points: 20,
                timeScope: .week,
                scopeAnchor: weekAnchor,
                recurrence: weeklyRec,
                hour: 18,
                minute: 0,
                subtasks: ["Review last week", "Set top 3 goals", "Schedule key tasks"]
            )
        }
        if let c = cat("Home & Family") {
            ids["Grocery Planning"] = await makeScopedTask(
                name: "Grocery Planning",
                icon: "cart.fill",
                category: c,
                priority: .low,
                minutes: 20,
                points: 10,
                timeScope: .week,
                scopeAnchor: weekAnchor,
                recurrence: weeklyRec,
                hour: 17,
                minute: 0,
                subtasks: ["Check pantry", "Create grocery list", "Plan 5 meals"]
            )
        }

        // Monthly objectives (recurring monthly on day 1)
        let monthlyRec: Recurrence = {
            var r = Recurrence(type: .monthly(days: [1]), startDate: monthAnchor, endDate: nil, trackInStatistics: true)
            r.monthInterval = 1
            return r
        }()
        if let c = cat("Finance") {
            ids["Monthly Budget Review"] = await makeScopedTask(
                name: "Monthly Budget Review",
                icon: "chart.line.uptrend.xyaxis",
                category: c,
                priority: .high,
                minutes: 60,
                points: 40,
                timeScope: .month,
                scopeAnchor: monthAnchor,
                recurrence: monthlyRec,
                hour: 19,
                minute: 0,
                subtasks: ["Review expenses", "Update savings", "Adjust allocations"]
            )
        }
        if let c = cat("Learning") {
            ids["Monthly Skill Focus"] = await makeScopedTask(
                name: "Monthly Skill Focus",
                icon: "lightbulb.fill",
                category: c,
                priority: .medium,
                minutes: 90,
                points: 35,
                timeScope: .month,
                scopeAnchor: monthAnchor,
                recurrence: monthlyRec,
                hour: 20,
                minute: 0,
                subtasks: ["Choose topic", "Collect resources", "Plan practice sessions"]
            )
        }

        // Yearly objectives (recurring yearly, anchored to start)
        let yearlyRec = Recurrence(type: .yearly, startDate: yearAnchor, endDate: nil, trackInStatistics: true)
        if let c = cat("Personal") {
            ids["Yearly Vision Review"] = await makeScopedTask(
                name: "Yearly Vision Review",
                icon: "trophy.fill",
                category: c,
                priority: .high,
                minutes: 120,
                points: 80,
                timeScope: .year,
                scopeAnchor: yearAnchor,
                recurrence: yearlyRec,
                hour: 10,
                minute: 0,
                subtasks: ["Review goals", "Assess progress", "Set new yearly themes"]
            )
        }

        // Long-term objectives (no recurrence)
        if let c = cat("Work") {
            ids["Long-term Career Project"] = await makeScopedTask(
                name: "Long-term Career Project",
                icon: "briefcase.fill",
                category: c,
                priority: .high,
                minutes: 0,
                points: 100,
                timeScope: .longTerm,
                scopeAnchor: today,
                recurrence: nil,
                hour: nil,
                minute: nil,
                subtasks: ["Define milestones", "Research opportunities", "Deliver first milestone"]
            )
        }

        return ids
    }

    private func makeScopedTask(
        name: String,
        icon: String,
        category: Category?,
        priority: Priority,
        minutes: Int,
        points: Int,
        timeScope: TaskTimeScope,
        scopeAnchor: Date,
        recurrence: Recurrence?,
        hour: Int?,
        minute: Int?,
        subtasks: [String]
    ) async -> UUID {
        let cal = Calendar.current
        let startTime: Date
        var scopeStartDate: Date? = nil
        var scopeEndDate: Date? = nil

        switch timeScope {
        case .week:
            let weekStart = cal.startOfWeek(for: scopeAnchor)
            scopeStartDate = weekStart
            scopeEndDate = cal.date(byAdding: .day, value: 6, to: weekStart)
            if let h = hour, let m = minute {
                startTime = cal.date(bySettingHour: h, minute: m, second: 0, of: weekStart) ?? weekStart
            } else {
                startTime = weekStart
            }
        case .month:
            let monthStart = cal.startOfMonth(for: scopeAnchor)
            scopeStartDate = monthStart
            if let next = cal.date(byAdding: .month, value: 1, to: monthStart) {
                scopeEndDate = cal.date(byAdding: .day, value: -1, to: next)
            }
            if let h = hour, let m = minute {
                startTime = cal.date(bySettingHour: h, minute: m, second: 0, of: monthStart) ?? monthStart
            } else {
                startTime = monthStart
            }
        case .year:
            let yearStart = cal.startOfYear(for: scopeAnchor)
            scopeStartDate = yearStart
            var comps = DateComponents()
            comps.year = cal.component(.year, from: yearStart)
            comps.month = 12
            comps.day = 31
            scopeEndDate = cal.date(from: comps)
            if let h = hour, let m = minute {
                startTime = cal.date(bySettingHour: h, minute: m, second: 0, of: yearStart) ?? yearStart
            } else {
                startTime = yearStart
            }
        case .longTerm:
            if let h = hour, let m = minute {
                startTime = cal.date(bySettingHour: h, minute: m, second: 0, of: scopeAnchor) ?? scopeAnchor
            } else {
                startTime = scopeAnchor
            }
        case .today, .all:
            if let h = hour, let m = minute {
                startTime = cal.date(bySettingHour: h, minute: m, second: 0, of: scopeAnchor) ?? scopeAnchor
            } else {
                startTime = scopeAnchor
            }
        }

        let task = TodoTask(
            name: name,
            description: nil,
            location: nil,
            startTime: startTime,
            hasSpecificTime: hour != nil,
            duration: TimeInterval(minutes * 60),
            hasDuration: minutes > 0,
            category: category,
            priority: priority,
            icon: icon,
            recurrence: recurrence,
            pomodoroSettings: nil,
            subtasks: subtasks.map { Subtask(name: $0) },
            hasRewardPoints: points > 0,
            rewardPoints: points,
            hasNotification: false,
            notificationId: nil,
            timeScope: timeScope,
            scopeStartDate: scopeStartDate,
            scopeEndDate: scopeEndDate
        )
        await TaskManager.shared.addTask(task)
        return task.id
    }

    private func seedScopedCompletions(_ scoped: [String: UUID]) async {
        let tm = TaskManager.shared
        let cal = Calendar.current
        let today = Date()

        func weekStart(_ date: Date) -> Date { cal.startOfWeek(for: date) }
        func monthStart(_ date: Date) -> Date { cal.startOfMonth(for: date) }
        func yearStart(_ date: Date) -> Date { cal.startOfYear(for: date) }

        // Weekly: last 26 weeks ~ 6 mesi
        if let weeklyPlanning = scoped["Weekly Planning"] {
            var w = weekStart(today)
            for i in 0..<26 {
                if let past = cal.date(byAdding: .weekOfYear, value: -i, to: w) {
                    if Double.random(in: 0...1) < 0.8 {
                        TaskManager.shared.toggleTaskCompletion(weeklyPlanning, on: past)
                        tm.updateTaskRating(taskId: weeklyPlanning, actualDuration: 30*60, difficultyRating: 3, qualityRating: 8, notes: nil, for: past)
                    }
                }
            }
        }
        if let grocery = scoped["Grocery Planning"] {
            var w = weekStart(today)
            for i in 0..<20 {
                if let past = cal.date(byAdding: .weekOfYear, value: -i, to: w) {
                    if Double.random(in: 0...1) < 0.7 {
                        TaskManager.shared.toggleTaskCompletion(grocery, on: past)
                        tm.updateTaskRating(taskId: grocery, actualDuration: 20*60, difficultyRating: 2, qualityRating: 7, notes: nil, for: past)
                    }
                }
            }
        }

        // Monthly: last 12 months
        if let budget = scoped["Monthly Budget Review"] {
            var m = monthStart(today)
            for i in 0..<12 {
                if let past = cal.date(byAdding: .month, value: -i, to: m) {
                    if Double.random(in: 0...1) < 0.9 {
                        TaskManager.shared.toggleTaskCompletion(budget, on: past)
                        tm.updateTaskRating(taskId: budget, actualDuration: 60*60, difficultyRating: 5, qualityRating: 8, notes: nil, for: past)
                    }
                }
            }
        }
        if let skill = scoped["Monthly Skill Focus"] {
            var m = monthStart(today)
            for i in 0..<12 {
                if let past = cal.date(byAdding: .month, value: -i, to: m) {
                    if Double.random(in: 0...1) < 0.6 {
                        TaskManager.shared.toggleTaskCompletion(skill, on: past)
                        tm.updateTaskRating(taskId: skill, actualDuration: 90*60, difficultyRating: 6, qualityRating: 7, notes: nil, for: past)
                    }
                }
            }
        }

        // Yearly: last 3 years
        if let vision = scoped["Yearly Vision Review"] {
            var y = yearStart(today)
            for i in 0..<3 {
                if let past = cal.date(byAdding: .year, value: -i, to: y) {
                    if Double.random(in: 0...1) < 0.95 {
                        TaskManager.shared.toggleTaskCompletion(vision, on: past)
                        tm.updateTaskRating(taskId: vision, actualDuration: 120*60, difficultyRating: 6, qualityRating: 9, notes: nil, for: past)
                    }
                }
            }
        }

        // Long term: mark a couple of milestones (subtasks help completion metrics)
        if let career = scoped["Long-term Career Project"] {
            let anchor = cal.startOfDay(for: today)
            if Double.random(in: 0...1) < 0.7 {
                TaskManager.shared.toggleTaskCompletion(career, on: anchor)
                tm.updateTaskRating(taskId: career, actualDuration: 3*60*60, difficultyRating: 7, qualityRating: 8, notes: "Milestone achieved", for: anchor)
            }
        }
    }
}