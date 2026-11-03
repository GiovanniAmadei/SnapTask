package com.snaptask.app

import android.app.Application
import android.content.Context
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.launch

class SnapTaskApp : Application() {
    override fun onCreate() {
        super.onCreate()
        ensureStarted(this)
        FeedbackReplyNotifier.scheduleBackgroundRefresh(this)
        AppShortcuts.publish(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            // `scenePhase == .active`
            override fun onStart(owner: LifecycleOwner) {
                MainScope.launch {
                    TaskManager.refreshCarryOverIfNeeded()
                    QuoteManager.checkAndUpdateQuote()
                    TaskNotificationManager.syncTaskReminders(TaskManager.tasks)
                    CalendarEventsFeed.reload()
                    FeedbackManager.checkForNewReplies()
                }
            }

            override fun onStop(owner: LifecycleOwner) {
                TimeTrackerViewModel.persist()
            }
        })
    }

    companion object {
        private var started = false

        /** The singletons of the iOS app, loaded in order. Also runs when only a receiver woke the app. */
        fun ensureStarted(context: Context) {
            if (started) return
            started = true
            App.context = context.applicationContext
            ThemeManager.load()
            TaskNotificationManager.load()
            CategoryManager.load()
            TaskManager.load()
            RewardManager.load()
            CalendarIntegrationManager.load()
            CalendarEventsFeed.load()
            QuoteManager.load()
            MoodManager.load()
            JournalManager.load()
            FinanceManager.load()
            SubscriptionManager.load()
            PomodoroViewModel.load()
            TimeTrackerViewModel.load()
        }
    }
}
