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

        await seedOneYearOfCompletions(refs.tasks, taskSubtasks: refs.taskSubtasks)
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
            ("Work", "#6366F1"),
            ("Personal", "#F59E0B"),
            ("Health", "#10B981"),
            ("Home", "#EC4899"),
            ("Learning", "#3B82F6"),
            ("Finance", "#22C55E")
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
            Reward(name: "Coffee Break", description: "Enjoy a nice coffee", pointsCost: 50, frequency: .daily, icon: "cup.and.saucer"),
            Reward(name: "Movie Night", description: "Watch your favorite movie", pointsCost: 200, frequency: .monthly, icon: "film"),
            Reward(name: "Takeout Dinner", description: "Order your favorite food", pointsCost: 150, frequency: .weekly, icon: "takeoutbag.and.cup.and.straw"),
            Reward(name: "Weekend Treat", description: "Small gift or dessert", pointsCost: 80, frequency: .weekly, icon: "gift"),
            Reward(name: "Yearly Getaway", description: "Plan a short weekend trip", pointsCost: 1200, frequency: .yearly, icon: "airplane")
        ]

        for r in general { ensureReward(r) }

        if let health = categories["Health"] {
            ensureReward(Reward(name: "New Running Socks", description: "Treat yourself to new gear", pointsCost: 300, frequency: .monthly, icon: "figure.run", categoryId: health.id, categoryName: health.name))
        }
        if let learning = categories["Learning"] {
            ensureReward(Reward(name: "Buy a Book", description: "Get a new book to study", pointsCost: 250, frequency: .monthly, icon: "book.fill", categoryId: learning.id, categoryName: learning.name))
        }
        if let work = categories["Work"] {
            ensureReward(Reward(name: "Desk Accessory", description: "Upgrade your workspace", pointsCost: 400, frequency: .monthly, icon: "tray.fill", categoryId: work.id, categoryName: work.name))
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

        // Daily recurrences (timeScope .today per chiave giornaliera coerente con stats)
        let dailyRec = Recurrence(type: .daily, startDate: dailyStart, endDate: nil, trackInStatistics: true)

        // Weekly recurrences (usa weekly in Recurrence ma timeScope .today)
        let weeklyRec: Recurrence = {
            let days: Set<Int> = [2, 4, 7] // Mon, Wed, Sat
            return Recurrence(type: .weekly(days: days), startDate: dailyStart, endDate: nil, trackInStatistics: true)
        }()

        // Monthly recurrences (1° del mese)
        let monthlyRec = Recurrence(type: .monthly(days: [1]), startDate: dailyStart, endDate: nil, trackInStatistics: true)

        // Yearly recurrence (una volta l'anno, giorno di oggi)
        let yearlyRec = Recurrence(type: .yearly, startDate: dailyStart, endDate: nil, trackInStatistics: true)

        // Daily tasks (con subtasks su alcuni)
        ids["Morning Workout"] = await makeTask(
            name: "Morning Workout",
            icon: "figure.run",
            categoryName: "Health",
            priority: .high,
            minutes: 45,
            points: 15,
            recurrence: dailyRec,
            startAt: dailyStart,
            subtasks: ["Warm-up", "Workout", "Stretching"]
        )

        ids["Plan the Day"] = await makeTask(
            name: "Plan the Day",
            icon: "list.bullet",
            categoryName: "Personal",
            priority: .medium,
            minutes: 15,
            points: 5,
            recurrence: dailyRec,
            startAt: dailyStart
        )

        ids["Inbox Zero"] = await makeTask(
            name: "Inbox Zero",
            icon: "envelope.badge.fill",
            categoryName: "Work",
            priority: .medium,
            minutes: 20,
            points: 10,
            recurrence: dailyRec,
            startAt: dailyStart
        )

        ids["Read 20 Pages"] = await makeTask(
            name: "Read 20 Pages",
            icon: "book.fill",
            categoryName: "Learning",
            priority: .low,
            minutes: 30,
            points: 10,
            recurrence: dailyRec,
            startAt: dailyStart
        )

        // Weekly tasks (con subtasks)
        ids["Weekly Meal Prep"] = await makeTask(
            name: "Weekly Meal Prep",
            icon: "cart.fill",
            categoryName: "Home",
            priority: .medium,
            minutes: 90,
            points: 20,
            recurrence: weeklyRec,
            startAt: dailyStart,
            subtasks: ["Plan menu", "Buy groceries", "Cook 3 meals"]
        )

        ids["Family Call"] = await makeTask(
            name: "Family Call",
            icon: "phone.fill",
            categoryName: "Personal",
            priority: .low,
            minutes: 30,
            points: 10,
            recurrence: weeklyRec,
            startAt: dailyStart
        )

        ids["House Cleaning"] = await makeTask(
            name: "House Cleaning",
            icon: "homekit",
            categoryName: "Home",
            priority: .medium,
            minutes: 60,
            points: 15,
            recurrence: weeklyRec,
            startAt: dailyStart,
            subtasks: ["Tidy living room", "Clean kitchen", "Vacuum"]
        )

        // Monthly tasks (con subtasks)
        ids["Monthly Budget Review"] = await makeTask(
            name: "Monthly Budget Review",
            icon: "creditcard.fill",
            categoryName: "Finance",
            priority: .medium,
            minutes: 45,
            points: 30,
            recurrence: monthlyRec,
            startAt: dailyStart,
            subtasks: ["Check expenses", "Update spreadsheet", "Plan savings"]
        )

        ids["Digital Photo Cleanup"] = await makeTask(
            name: "Digital Photo Cleanup",
            icon: "photo.fill.on.rectangle.fill",
            categoryName: "Personal",
            priority: .low,
            minutes: 30,
            points: 10,
            recurrence: monthlyRec,
            startAt: dailyStart
        )

        // Yearly task
        ids["Annual Medical Check-up"] = await makeTask(
            name: "Annual Medical Check-up",
            icon: "stethoscope",
            categoryName: "Health",
            priority: .medium,
            minutes: 60,
            points: 50,
            recurrence: yearlyRec,
            startAt: dailyStart
        )

        // Long-term objective (con subtasks)
        ids["Declutter Home"] = await makeTask(
            name: "Declutter Home",
            icon: "tray.full.fill",
            categoryName: "Home",
            priority: .medium,
            minutes: 0,
            points: 40,
            recurrence: Recurrence(type: .daily, startDate: dailyStart, endDate: nil, trackInStatistics: true),
            startAt: dailyStart,
            subtasks: ["Sort clothes", "Clean drawers", "Donate items", "Organize cables"]
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

        let dailyProb = 0.85
        let weeklyProb = 0.75
        let monthlyProb = 0.85

        let nameToId = tasks

        func variedRating(base: Int, weekday: Int, weekendBoost: Int = 0) -> Int {
            let noise = rand(-2, 2)
            let weekend = (weekday == 1 || weekday == 7) ? weekendBoost : 0
            return min(10, max(1, base + noise + weekend))
        }

        func completeTaskForDay(taskId: UUID, on date: Date, estimatedMinutes: Int, baseDifficulty: Int, baseQuality: Int) {
            let startOfDay = cal.startOfDay(for: date)
            if let subIds = taskSubtasks[taskId], !subIds.isEmpty {
                for sid in subIds { TaskManager.shared.toggleSubtask(taskId: taskId, subtaskId: sid, on: startOfDay) }
            } else {
                TaskManager.shared.toggleTaskCompletion(taskId, on: startOfDay)
            }
            let weekday = cal.component(.weekday, from: date)
            let diff = variedRating(base: baseDifficulty, weekday: weekday)
            let qual = variedRating(base: baseQuality, weekday: weekday, weekendBoost: 1)
            let actual = Double(max(5, estimatedMinutes + rand(-6, 12))) * 60.0
            tm.updateTaskRating(taskId: taskId, actualDuration: actual, difficultyRating: diff, qualityRating: qual, notes: nil, for: startOfDay)
        }

        var day = start
        while day <= today {
            let weekday = cal.component(.weekday, from: day)

            for (name, baseMinutes, baseDiff, baseQual) in [
                ("Morning Workout", 45, 5, 7),
                ("Plan the Day", 15, 2, 7),
                ("Inbox Zero", 20, 4, 6),
                ("Read 20 Pages", 30, 3, 7)
            ] {
                if Double.random(in: 0...1) < dailyProb, let id = nameToId[name] {
                    completeTaskForDay(taskId: id, on: day, estimatedMinutes: baseMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                }
            }

            if [2,4,7].contains(weekday) {
                for (name, baseMinutes, baseDiff, baseQual) in [
                    ("Weekly Meal Prep", 90, 4, 7),
                    ("Family Call", 30, 2, 8),
                    ("House Cleaning", 60, 4, 7)
                ] {
                    if Double.random(in: 0...1) < weeklyProb, let id = nameToId[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: baseMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }

            let dom = cal.component(.day, from: day)
            if dom == 1 {
                for (name, baseMinutes, baseDiff, baseQual) in [
                    ("Monthly Budget Review", 45, 5, 7),
                    ("Digital Photo Cleanup", 30, 2, 6)
                ] {
                    if Double.random(in: 0...1) < monthlyProb, let id = nameToId[name] {
                        completeTaskForDay(taskId: id, on: day, estimatedMinutes: baseMinutes, baseDifficulty: baseDiff, baseQuality: baseQual)
                    }
                }
            }

            if cal.component(.month, from: day) == cal.component(.month, from: today),
               cal.component(.day, from: day) == cal.component(.day, from: today),
               let id = nameToId["Annual Medical Check-up"] {
                completeTaskForDay(taskId: id, on: day, estimatedMinutes: 60, baseDifficulty: 6, baseQuality: 8)
            }

            if dom == 15, let id = nameToId["Declutter Home"] {
                if let subIds = taskSubtasks[id], !subIds.isEmpty {
                    for sid in subIds { TaskManager.shared.toggleSubtask(taskId: id, subtaskId: sid, on: day) }
                }
                tm.updateTaskRating(taskId: id, actualDuration: 45*60, difficultyRating: 5, qualityRating: 7, notes: nil, for: day)
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let todayNames = ["Morning Workout", "Plan the Day", "Inbox Zero", "Read 20 Pages"]
        for (name, est) in zip(todayNames, [45, 15, 25, 30]) {
            if let id = nameToId[name] {
                completeTaskForDay(taskId: id, on: today, estimatedMinutes: est, baseDifficulty: 4, baseQuality: 8)
            }
        }
    }

    // MARK: - Tracking Sessions (sparse across the year)
    private func seedTrackingSessionsForYear(_ tasks: [String: UUID], categories: [String: Category]) async {
        let tm = TaskManager.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -180, to: today) else { return }

        func sessionDate(_ base: Date, hour: Int) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: base)
            comps.hour = hour
            comps.minute = 0
            return cal.date(from: comps) ?? base
        }

        var day = start
        while day <= today {
            // Un paio di volte a settimana Work, un paio Health
            let weekday = cal.component(.weekday, from: day)
            if [2,4].contains(weekday), let workId = tasks["Inbox Zero"] {
                var sess = TrackingSession(
                    id: UUID(),
                    taskId: workId,
                    taskName: "Inbox Zero",
                    mode: .simple,
                    categoryId: categories["Work"]?.id,
                    categoryName: categories["Work"]?.name,
                    startTime: sessionDate(day, hour: 10),
                    elapsedTime: TimeInterval(Int.random(in: 30...70) * 60),
                    isRunning: false,
                    isPaused: false
                )
                tm.saveTrackingSession(sess)
            }
            if [3,6].contains(weekday), let healthId = tasks["Morning Workout"] {
                var sess = TrackingSession(
                    id: UUID(),
                    taskId: healthId,
                    taskName: "Morning Workout",
                    mode: .simple,
                    categoryId: categories["Health"]?.id,
                    categoryName: categories["Health"]?.name,
                    startTime: sessionDate(day, hour: 7),
                    elapsedTime: TimeInterval(Int.random(in: 30...55) * 60),
                    isRunning: false,
                    isPaused: false
                )
                tm.saveTrackingSession(sess)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        if let workId = tasks["Inbox Zero"] {
            var sess = TrackingSession(
                id: UUID(),
                taskId: workId,
                taskName: "Inbox Zero",
                mode: .simple,
                categoryId: categories["Work"]?.id,
                categoryName: categories["Work"]?.name,
                startTime: sessionDate(today, hour: 11),
                elapsedTime: TimeInterval(35 * 60),
                isRunning: false,
                isPaused: false
            )
            tm.saveTrackingSession(sess)
        }
        if let healthId = tasks["Morning Workout"] {
            var sess = TrackingSession(
                id: UUID(),
                taskId: healthId,
                taskName: "Morning Workout",
                mode: .simple,
                categoryId: categories["Health"]?.id,
                categoryName: categories["Health"]?.name,
                startTime: sessionDate(today, hour: 7),
                elapsedTime: TimeInterval(40 * 60),
                isRunning: false,
                isPaused: false
            )
            tm.saveTrackingSession(sess)
        }
    }

    // MARK: - Reward Redemptions across months
    private func seedRewardRedemptions(_ rewardsByName: [String: Reward]) async {
        let rm = RewardManager.shared
        let cal = Calendar.current
        let today = Date()

        func monthsAgo(_ n: Int) -> Date {
            return cal.date(byAdding: .month, value: -n, to: today) ?? today
        }

        // Settimanali (2-3 settimane fa e 6-7 settimane fa)
        if let weekend = rewardsByName["Weekend Treat"] {
            for w in [2, 3, 6, 7] {
                if let day = cal.date(byAdding: .day, value: -(w*7) + 6, to: today) {
                    rm.redeemReward(weekend, on: day)
                }
            }
        }

        // Mensili (ultimi 2-3 mesi)
        if let movie = rewardsByName["Movie Night"] {
            rm.redeemReward(movie, on: monthsAgo(1))
            rm.redeemReward(movie, on: monthsAgo(3))
        }
        if let socks = rewardsByName["New Running Socks"] {
            rm.redeemReward(socks, on: monthsAgo(2))
        }
        if let book = rewardsByName["Buy a Book"] {
            rm.redeemReward(book, on: monthsAgo(4))
        }
        if let desk = rewardsByName["Desk Accessory"] {
            rm.redeemReward(desk, on: monthsAgo(5))
        }

        // Giornalieri (ultimi 7-10 giorni)
        if let coffee = rewardsByName["Coffee Break"] {
            for d in [1,2,3,5,7,10] {
                if let day = cal.date(byAdding: .day, value: -d, to: today) {
                    rm.redeemReward(coffee, on: day)
                }
            }
        }

        // Annuale (lo scorso anno)
        if let getaway = rewardsByName["Yearly Getaway"] {
            if let lastYear = cal.date(byAdding: .year, value: -1, to: today) {
                rm.redeemReward(getaway, on: lastYear)
            }
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
}