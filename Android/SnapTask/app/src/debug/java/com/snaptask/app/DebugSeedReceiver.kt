package com.snaptask.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.launch

/**
 * Debug builds only: fills the app to check the screens, like `DemoDataSeeder` on iOS.
 * adb shell am broadcast -n com.snaptask.app/.DebugSeedReceiver
 * adb shell am broadcast -n com.snaptask.app/.DebugSeedReceiver --es lang de
 */
class DebugSeedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val result = goAsync()
        MainScope.launch {
            val language = intent.getStringExtra("lang")
            if (language != null) LanguageManager.setLanguage(language) else seed()
            result.finish()
        }
    }

    private suspend fun seed() {
        Defaults.set("hasShownWelcome", true)
        Defaults.set("welcomeContentSeeded", true)
        Defaults.set("subscriptionStatusType", "subscribed")
        val work = Category(id = java.util.UUID.randomUUID(), name = "Work", color = "#3B82F6", icon = "briefcase.fill")
        val health = Category(id = java.util.UUID.randomUUID(), name = "Health", color = "#10B981", icon = "heart.fill")
        val home = Category(id = java.util.UUID.randomUUID(), name = "Personal", color = "#F97316", icon = "person.fill")
        listOf(work, health, home).forEach { CategoryManager.addCategory(it) }
        val today = now().startOfDay()
        fun at(hour: Int, minute: Int = 0) = today.withTime(hour, minute, 0)
        val tasks = listOf(
            TodoTask(name = "Morning run", startTime = at(7).addingDays(-40), hasSpecificDay = true, hasSpecificTime = true, duration = 1800.0, hasDuration = true, category = health, priority = Priority.high, icon = "figure.run", recurrence = Recurrence(type = RecurrenceType.Daily, startDate = today.addingDays(-40)), hasRewardPoints = true, rewardPoints = 10, timeScope = TaskTimeScope.today),
            TodoTask(name = "Plan the Android release", startTime = at(9, 30), hasSpecificDay = true, hasSpecificTime = true, duration = 3600.0, hasDuration = true, category = work, priority = Priority.high, icon = "briefcase.fill", subtasks = listOf(Subtask(name = "Screenshots"), Subtask(name = "Store listing")), timeScope = TaskTimeScope.today),
            TodoTask(name = "Reply to feedback", startTime = at(11), hasSpecificDay = true, hasSpecificTime = true, category = work, priority = Priority.medium, icon = "envelope.fill", timeScope = TaskTimeScope.today),
            TodoTask(name = "Groceries", startTime = at(17), hasSpecificDay = true, hasSpecificTime = true, category = home, priority = Priority.low, icon = "cart.fill", timeScope = TaskTimeScope.today),
            TodoTask(name = "Read 15 minutes", startTime = at(21).addingDays(-40), hasSpecificDay = true, hasSpecificTime = true, category = home, priority = Priority.low, icon = "book.fill", recurrence = Recurrence(type = RecurrenceType.Daily, startDate = today.addingDays(-40)), timeScope = TaskTimeScope.today),
            TodoTask(name = "Call the dentist", startTime = today, hasSpecificDay = true, hasSpecificTime = false, category = health, priority = Priority.medium, icon = "phone.fill", timeScope = TaskTimeScope.today),
            TodoTask(name = "Team meeting", startTime = at(15), hasSpecificDay = true, hasSpecificTime = true, category = work, priority = Priority.medium, icon = "person.2.fill", timeScope = TaskTimeScope.today),
            TodoTask(name = "Review the budget", startTime = today, hasSpecificDay = true, hasSpecificTime = false, category = home, priority = Priority.low, icon = "banknote.fill", timeScope = TaskTimeScope.week, scopeStartDate = today.startOfWeek(), scopeEndDate = today.startOfWeek().addingDays(6)),
        )
        tasks.forEach { TaskManager.addTask(it) }
        // History of the two daily tasks.
        val run = tasks[0].id
        val read = tasks[4].id
        for (daysAgo in 1..30) {
            val date = today.addingDays(-daysAgo)
            if (daysAgo % 4 != 0) TaskManager.toggleTaskCompletion(run, date)
            if (daysAgo % 3 == 0) TaskManager.toggleTaskCompletion(read, date)
        }
        TaskManager.toggleTaskCompletion(run, today)
        TaskManager.addTrackedTime(5400.0, tasks[1].id)
        TaskManager.addTrackedTime(1800.0, tasks[0].id)
        TaskManager.addTrackedTime(2400.0, tasks[3].id)
        RewardManager.addReward(Reward(name = "Movie night", pointsCost = 50, frequency = RewardFrequency.weekly, icon = "film.fill"))
        RewardManager.addReward(Reward(name = "Coffee out", pointsCost = 20, icon = "cup.and.saucer.fill"))
        FinanceManager.addEntry(FinanceEntry(name = "Salary", amount = 2800.0, type = FinanceEntryType.income, date = today.startOfMonth()))
        FinanceManager.addEntry(FinanceEntry(name = "Rent", amount = 850.0, type = FinanceEntryType.expense, category = FinanceCategory.housing, date = today.startOfMonth()))
        FinanceManager.addEntry(FinanceEntry(name = "Supermarket", amount = 310.0, type = FinanceEntryType.expense, category = FinanceCategory.food, date = today))
        FinanceManager.addEntry(FinanceEntry(name = "Train pass", amount = 96.0, type = FinanceEntryType.expense, category = FinanceCategory.transport, date = today))
        FinanceManager.addBudget(FinanceBudget(category = FinanceCategory.food, monthlyLimit = 400.0))
        FinanceManager.addBudget(FinanceBudget(category = FinanceCategory.transport, monthlyLimit = 120.0))
        FinanceManager.updateMonthlyBudgetTarget(1600.0)
    }
}
