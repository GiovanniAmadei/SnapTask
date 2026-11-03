package com.snaptask.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import java.util.UUID

/**
 * Debug builds only: opens one screen directly, to check them all without walking through the app.
 * adb shell am start -n com.snaptask.app/.GalleryActivity --es screen TaskFormView
 */
class GalleryActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val name = intent.getStringExtra("screen") ?: ""
        setContent {
            AppTheme {
                val presenter = remember { Presenter() }
                CompositionLocalProvider(LocalPresenter provides presenter) {
                    presenter.Host {
                        Box(Modifier.fillMaxSize().background(LocalTheme.current.backgroundColor).statusBarsPadding()) {
                            NavigationStack { GalleryScreens.all[name]?.invoke() }
                        }
                    }
                }
            }
        }
    }
}

object GalleryScreens {
    private val task get() = TaskManager.tasks.firstOrNull { it.recurrence != null } ?: TaskManager.tasks.firstOrNull()
    private val plainTask get() = TaskManager.tasks.firstOrNull { it.recurrence == null } ?: task
    private val category get() = CategoryManager.categories.firstOrNull()
    private val entry get() = FinanceManager.entries.firstOrNull()
    private val budget get() = FinanceManager.budgets.firstOrNull()
    private val reward get() = RewardManager.rewards.firstOrNull()
    private val sampleSession
        get() = TrackingSession(taskId = task?.id, taskName = task?.name, mode = TrackingMode.simple, startTime = now().addingMinutes(-30))
    private val sampleGoal
        get() = FinancialGoal(name = "New bike", targetAmount = 1000.0, currentAmount = 300.0, type = FinancialGoalType.savings)
    private val form get() = TaskFormViewModel(now())

    val all: Map<String, @Composable () -> Unit> = linkedMapOf(
        "ContentView" to { ContentView() },
        "TimelineView" to { TimelineView() },
        "FocusTabView" to { FocusTabView() },
        "RewardsView" to { RewardsView() },
        "FinanceDashboardView" to { FinanceDashboardView() },
        "StatisticsView" to { StatisticsView() },
        "SettingsView" to { SettingsView() },
        "WelcomeView" to { WelcomeView() },
        // Home
        "TimelineOrganizationView" to { TimelineOrganizationView() },
        "EisenhowerMatrixView" to { EisenhowerMatrixView() },
        "EisenhowerSettingsView" to { EisenhowerSettingsView(showDone = true) },
        "MediaHubCalendarView" to { MediaHubCalendarView {} },
        "TaskCreationOptionsView" to { TaskCreationOptionsView() },
        "TaskFormView.new" to { TaskFormView {} },
        "TaskFormView.edit" to { TaskFormView(initialTask = task) {} },
        "TaskFormView.week" to { TaskFormView(initialTimeScope = TaskTimeScope.week) {} },
        "TaskFormView.month" to { TaskFormView(initialTimeScope = TaskTimeScope.month) {} },
        "TaskFormView.year" to { TaskFormView(initialTimeScope = TaskTimeScope.year) {} },
        "TaskFormView.longTerm" to { TaskFormView(initialTimeScope = TaskTimeScope.longTerm) {} },
        "EnhancedRecurrenceSettingsView" to { EnhancedRecurrenceSettingsView(remember { form }) },
        "ContextualRecurrenceSettingsView" to { ContextualRecurrenceSettingsView(remember { form }) },
        "MonthlyDaysView" to { MonthlyDaysView(remember { form }) },
        "MonthlyPatternsView" to { MonthlyPatternsView(remember { form }) },
        "OrdinalPatternPickerView" to { OrdinalPatternPickerView(remember { form }) },
        "CategoryPickerView" to { CategoryPickerView(category) {} },
        "IconPickerView" to { IconPickerView("star.fill") {} },
        "DurationPickerView" to { DurationPickerView(1800.0) {} },
        "NotificationLeadTimePickerView" to { NotificationLeadTimePickerView(15) {} },
        "LocationPickerView" to { LocationPickerView(null) {} },
        "TaskDetailView.recurring" to { task?.let { TaskDetailView(it.id) } },
        "TaskDetailView.single" to { plainTask?.let { TaskDetailView(it.id) } },
        "TaskPerformanceChartView" to { task?.let { TaskPerformanceChartView(it) } },
        "PlanInboxItemSheet" to { plainTask?.let { PlanInboxItemSheet(it) {} } },
        "JournalView" to { JournalView(now()) },
        "MoodSelectionView" to { MoodSelectionView(now()) },
        // Focus
        "AllSessionsView" to { AllSessionsView() },
        "SessionEditView" to { SessionEditView(sampleSession) },
        "SessionConflictView" to { SessionConflictView("A", "B", {}, {}, {}, {}) },
        "TrackingModeSelectionView" to { task?.let { TrackingModeSelectionView(it) {} } },
        "PomodoroTabView" to { PomodoroTabView() },
        "ContextualPomodoroSettingsView.general" to { ContextualPomodoroSettingsView(PomodoroContext.general) },
        "ContextualPomodoroSettingsView.task" to { ContextualPomodoroSettingsView(PomodoroContext.task) },
        "PomodoroColorsView" to { PomodoroColorsView() },
        "TimeTrackerView.full" to { TimeTrackerView(task = task, presentationStyle = TimerPresentationStyle.entries.first(), allowExpand = true) },
        "TimeTrackerView.other" to { TimeTrackerView(task = task, presentationStyle = TimerPresentationStyle.entries.last(), allowExpand = false) },
        "PomodoroCompletionView" to { PomodoroCompletionView(task, 1500.0) },
        "TimeTrackingCompletionView" to { TimeTrackingCompletionView(task, sampleSession, {}, {}, {}) },
        // Rewards
        "RewardFormView.new" to { RewardFormView() },
        "RewardFormView.edit" to { RewardFormView(initialReward = reward) },
        "PointsHistoryView" to { PointsHistoryView() },
        "RedeemedRewardsView" to { RedeemedRewardsView() },
        "CategoryPointsBreakdownView" to { CategoryPointsBreakdownView() },
        // Finance
        "FinanceAllEntriesView" to { FinanceAllEntriesView() },
        "FinanceEntryFormView.new" to { FinanceEntryFormView(null) },
        "FinanceEntryFormView.edit" to { FinanceEntryFormView(entry) },
        "FinanceSettingsView" to { FinanceSettingsView() },
        "AddCategoryBudgetView" to { AddCategoryBudgetView() },
        "EditCategoryBudgetView" to { budget?.let { EditCategoryBudgetView(it) } },
        "CustomCategoryFormView" to { CustomCategoryFormView() },
        "BuiltInCategoryFormView" to { BuiltInCategoryFormView(FinanceCategory.food) },
        "FinancialGoalFormView.new" to { FinancialGoalFormView(null) },
        "FinancialGoalFormView.edit" to { FinancialGoalFormView(sampleGoal) },
        "FinanceCardLayoutView" to { FinanceCardLayoutView(true) },
        "CustomColorSheet" to { CustomColorSheet("#FF3B30") {} },
        // Settings
        "LanguageSelectionView" to { LanguageSelectionView() },
        "ThemesAndCustomizationView" to { ThemesAndCustomizationView() },
        "PrioritiesView" to { PrioritiesView() },
        "PriorityFormView" to { PriorityFormView() },
        "ThemeSelectionView" to { ThemeSelectionView() },
        "AppIconSelectionView" to { AppIconSelectionView() },
        "CategoriesView" to { CategoriesView() },
        "CategoryFormView.new" to { CategoryFormView {} },
        "CategoryFormView.edit" to { CategoryFormView(category) {} },
        "PremiumPaywallView" to { PremiumPaywallView() },
        "PremiumStatusView" to { PremiumStatusView() },
        "LegalDocumentView.terms" to { LegalDocumentView(LegalDocument.terms) },
        "LegalDocumentView.privacy" to { LegalDocumentView(LegalDocument.privacy) },
        "FeedbackView" to { FeedbackView() },
        "NewFeedbackView" to { NewFeedbackView() },
        "WhatsNewView" to { WhatsNewView() },
        "CalendarIntegrationView" to { CalendarIntegrationView() },
        "CalendarSelectionView" to { CalendarSelectionView() },
        "VisibleCalendarsView" to { VisibleCalendarsView() },
    )
}
