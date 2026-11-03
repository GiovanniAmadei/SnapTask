package com.snaptask.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import java.time.format.FormatStyle
import java.util.UUID

private const val supportEmail = "giovannisebastianoamadei@gmail.com"

private fun open(uri: String) {
    runCatching {
        App.context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}

private fun openAppSettings() {
    runCatching {
        App.context.startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, App.context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

// MARK: - Settings

private enum class TimeTarget { quote, diary }

@Composable
fun SettingsView() {
    val theme = theme
    val presenter = LocalPresenter.current
    NavigationStack {
        val navigator = LocalNavigator.current
        var appearanceMode by appStorage("appearanceMode", "system")
        var timeFormat by appStorage(TimeFormatPreference.storageKey, TimeFormatPreference.system.rawValue)
        var quoteEnabled by appStorage("dailyQuoteNotificationsEnabled", false)
        var quoteTime by appStorage("dailyQuoteNotificationTime", "09:00")
        var diaryEnabled by appStorage("diaryNotificationsEnabled", false)
        var diaryTime by appStorage("diaryNotificationTime", "20:00")
        var alert by remember { mutableStateOf<SettingsAlert?>(null) }
        val requestPermission = rememberNotificationPermission()
        val sub = SubscriptionManager
        val task = TaskNotificationManager
        var authorized by remember { mutableStateOf(task.isAuthorized) }
        LaunchedEffect(Unit) {
            QuoteManager.checkAndUpdateQuote()
            sub.loadProducts()
            authorized = task.isAuthorized
        }

        fun toggleQuote(value: Boolean) {
            quoteEnabled = value
            if (value) requestPermission()
            QuoteManager.rescheduleDailyQuote()
        }
        fun toggleDiary(value: Boolean) {
            diaryEnabled = value
            if (value) requestPermission()
            QuoteManager.rescheduleDiary()
        }
        fun pickTime(target: TimeTarget) {
            val current = if (target == TimeTarget.quote) quoteTime else diaryTime
            val parts = current.split(":").mapNotNull { it.toIntOrNull() }
            val start = now().withTime(parts.getOrElse(0) { 9 }, parts.getOrElse(1) { 0 }, 0)
            presenter.sheet(SheetDetent.medium) {
                var picked by remember { mutableStateOf(start) }
                val dismiss = LocalDismiss.current
                Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
                    NavBar(
                        "notification_time".localized,
                        leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
                        trailing = {
                            BarButton("save".localized, bold = true, color = theme.primaryColor) {
                                val text = "%02d:%02d".format(picked.hour, picked.minute)
                                if (target == TimeTarget.quote) {
                                    quoteTime = text
                                    QuoteManager.rescheduleDailyQuote()
                                } else {
                                    diaryTime = text
                                    QuoteManager.rescheduleDiary()
                                }
                                dismiss()
                            }
                        },
                    )
                    TimeWheel(picked, { picked = it }, Modifier.padding(16.dp))
                }
            }
        }
        fun deleteAll() {
            Haptics.heavy()
            MainScope.launch {
                TaskManager.resetUserDefaults()
                RewardManager.performCompleteReset()
                CategoryManager.performCompleteReset()
                JournalManager.resetAll()
                FinanceManager.resetAll()
                TimeTrackerViewModel.activeSessions.forEach { TimeTrackerViewModel.removeSession(it.id) }
                PomodoroViewModel.stop()
                TimeTrackingStore.clear()
                TaskNotificationManager.cancelAllNotifications()
                WidgetRefresher.request()
                Haptics.success()
                delay(400)
                alert = SettingsAlert.deleteSuccess
            }
        }

        alert?.let { item ->
            val actions = when (item) {
                SettingsAlert.deleteConfirmation -> listOf(
                    AlertAction("delete_all_data_button".localized, AlertRole.destructive) { deleteAll() },
                    AlertAction("cancel".localized, AlertRole.cancel),
                )
                SettingsAlert.deleteSuccess -> listOf(AlertAction("ok".localized, AlertRole.cancel))
                SettingsAlert.permission -> listOf(AlertAction("settings".localized) { openAppSettings() }, AlertAction("cancel".localized, AlertRole.cancel))
                SettingsAlert.taskPermission -> listOf(AlertAction("open_settings".localized) { openAppSettings() }, AlertAction("cancel".localized, AlertRole.cancel))
                SettingsAlert.emailNotAvailable -> listOf(AlertAction("ok".localized, AlertRole.cancel))
                SettingsAlert.themeWarning -> listOf(
                    AlertAction("switch_to_simple_theme".localized) { ThemeManager.setTheme(ThemeManager.defaultTheme) },
                    AlertAction("keep_current_theme".localized, AlertRole.cancel) { appearanceMode = "system" },
                )
            }
            IOSAlert(item.titleKey.localized, item.messageKey.localized, actions, { alert = null })
        }

        Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
            NavBar("settings".localized)
            FormPage(Modifier.weight(1f)) {
                // Premium
                FormSection("premium_plan".localized) {
                    val status = sub.subscriptionStatus
                    val expiration = (status as? SubscriptionStatus.Subscribed)?.expirationDate ?: (status as? SubscriptionStatus.InTrial)?.expirationDate
                    FormRow(
                        (if (sub.isSubscribed) "premium_plan_active" else "upgrade_to_pro").localized,
                        icon = if (sub.isSubscribed) "crown.fill" else "crown",
                        iconTint = Color.SysPurple,
                        subtitle = if (sub.isSubscribed) {
                            if (expiration != null) "subscription_expires".localized + " " + expiration.dateStyle(FormatStyle.MEDIUM) else "lifetime_access".localized
                        } else "premium_features".localized,
                        chevron = true,
                        onClick = { presenter.sheet { if (sub.isSubscribed) PremiumStatusView() else PremiumPaywallView() } },
                        trailing = {
                            if (sub.isSubscribed) SF("checkmark.seal.fill", Color.SysGreen, 22.dp) else PremiumBadge(small = true)
                        },
                    )
                    FormRow("redeem_offer_code".localized, icon = "ticket", iconTint = Color.SysPurple, chevron = true, divider = false, onClick = { open("https://play.google.com/redeem") })
                }
                // Quote
                FormSection("quote_of_the_day".localized) {
                    Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        T(
                            QuoteManager.currentQuote.text,
                            Fonts.body.copy(fontStyle = FontStyle.Italic),
                        )
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("— ${QuoteManager.currentQuote.author}", Fonts.caption, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                            Box(Modifier.tap { QuoteManager.forceUpdateQuote() }) { SF("arrow.clockwise", theme.primaryColor, 15.dp) }
                        }
                    }
                }
                // Notifications
                FormSection("notifications".localized) {
                    ToggleRow("daily_quote_reminder".localized, quoteEnabled, ::toggleQuote, icon = "bell.fill", iconTint = Color.SysOrange)
                    if (quoteEnabled) {
                        FormRow("notification_time".localized, icon = "clock", iconTint = Color.SysBlue, value = quoteTime, chevron = true, onClick = { pickTime(TimeTarget.quote) })
                        if (!authorized) EnableInSettingsRow { alert = SettingsAlert.permission }
                    }
                    ToggleRow("diary_reminder".localized, diaryEnabled, ::toggleDiary, icon = "book.closed.fill", iconTint = Color.SysOrange)
                    if (diaryEnabled) {
                        FormRow("notification_time".localized, icon = "clock", iconTint = Color.SysBlue, value = diaryTime, chevron = true, onClick = { pickTime(TimeTarget.diary) })
                        if (!authorized) EnableInSettingsRow { alert = SettingsAlert.permission }
                    }
                    ToggleRow(
                        "task_notifications_master".localized,
                        task.areTaskNotificationsEnabled,
                        { value ->
                            if (value) requestPermission()
                            task.setTaskNotificationsEnabled(value)
                        },
                        icon = "bell.slash.fill",
                        iconTint = Color.SysOrange,
                        subtitle = "task_notifications_master_description".localized,
                        divider = task.areTaskNotificationsEnabled && !authorized,
                    )
                    if (task.areTaskNotificationsEnabled && !authorized) {
                        FormRow("notification_permission_required".localized, icon = "exclamationmark.triangle.fill", iconTint = Color.SysRed, titleColor = Color.SysRed, divider = false, onClick = { alert = SettingsAlert.taskPermission }, trailing = { SF("arrow.up.right", Color.SysRed, 13.dp) })
                    }
                }
                // Appearance
                FormSection("appearance".localized) {
                    MenuRow(
                        "appearance".localized, "circle.lefthalf.filled", Color.SysIndigo,
                        when (appearanceMode) {
                            "light" -> "light"
                            "dark" -> "dark"
                            else -> "system"
                        }.localized,
                        listOf("system", "light", "dark").map { mode ->
                            MenuItem(mode.localized, checked = appearanceMode == mode) {
                                appearanceMode = mode
                                if (mode != "system" && ThemeManager.currentTheme.overridesSystemColors) alert = SettingsAlert.themeWarning
                            }
                        },
                    )
                    MenuRow(
                        "time_format".localized, "clock", Color.SysOrange,
                        TimeFormatPreference.entries.firstOrNull { it.rawValue == timeFormat }?.localizedName ?: "",
                        TimeFormatPreference.entries.map { option -> MenuItem(option.localizedName, checked = timeFormat == option.rawValue) { timeFormat = option.rawValue } },
                    )
                    FormRow("language".localized, icon = "globe", iconTint = Color.SysBlue, value = LanguageManager.currentLanguage.name, chevron = true, onClick = { navigator?.push { LanguageSelectionView() } })
                    FormRow("themes_and_customization".localized, icon = "paintbrush.fill", iconTint = Color.SysPurple, chevron = true, divider = false, onClick = { navigator?.push { ThemesAndCustomizationView() } })
                }
                // Finance
                FormSection("finance".localized) {
                    FormRow("finance_dashboard".localized, icon = "banknote.fill", iconTint = Color.SysGreen, chevron = true, divider = false, onClick = { navigator?.push { FinanceSettingsView() } })
                }
                // Calendar
                FormSection("synchronization".localized, "manage_data_sync".localized) {
                    FormRow("calendar_integration".localized, icon = "calendar", iconTint = Color.SysGreen, chevron = true, divider = false, onClick = { navigator?.push { CalendarIntegrationView() } })
                }
                // Community
                FormSection("community".localized) {
                    FormRow("feedback_suggestions".localized, icon = "bubble.left.and.bubble.right.fill", iconTint = Color.SysGreen, chevron = true, onClick = { navigator?.push { FeedbackView() } })
                    FormRow(
                        "whats_cooking".localized, icon = "sparkles", iconTint = Color.SysPurple, chevron = true, divider = false,
                        onClick = { navigator?.push { WhatsNewView() } },
                        trailing = { if (UpdateNewsService.hasUnreadHighlightedItems()) Box(Modifier.size(8.dp).background(Color.SysRed, CircleShape)) },
                    )
                }
                // Support
                FormSection("support".localized) {
                    FormRow("contact_support".localized, icon = "envelope.fill", iconTint = Color.SysBlue, chevron = true, onClick = {
                        val subject = Uri.encode("SnapTask - " + "contact_support".localized)
                        runCatching {
                            App.context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$supportEmail?subject=$subject")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }.onFailure { alert = SettingsAlert.emailNotAvailable }
                    })
                    FormRow("review_welcome_message".localized, icon = "heart", iconTint = Color.SysPink, chevron = true, onClick = { presenter.fullScreen { WelcomeView() } })
                    FormRow("rate_app".localized, icon = "star.fill", iconTint = Color.SysYellow, subtitle = "rate_app_subtitle".localized, chevron = true, onClick = {
                        val id = App.context.packageName
                        runCatching {
                            App.context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }.onFailure { open("https://play.google.com/store/apps/details?id=$id") }
                    })
                    FormRow("terms_of_service".localized, icon = "doc.text.fill", iconTint = Color.SysGray, chevron = true, onClick = { presenter.sheet { LegalDocumentView(LegalDocument.terms) } })
                    FormRow("privacy_policy".localized, icon = "lock.shield.fill", iconTint = Color.SysGray, chevron = true, divider = false, onClick = { presenter.sheet { LegalDocumentView(LegalDocument.privacy) } })
                }
                // Data
                FormSection("data_management".localized, "delete_all_data_footer".localized) {
                    FormRow(
                        "delete_all_data".localized, icon = "trash.fill", iconTint = Color.SysRed, titleColor = Color.SysRed,
                        subtitle = "delete_all_data_description".localized, divider = false,
                        onClick = { alert = SettingsAlert.deleteConfirmation },
                    )
                }
            }
        }
    }
}

private enum class SettingsAlert(val titleKey: String, val messageKey: String) {
    deleteConfirmation("delete_all_data_confirmation_title", "delete_all_data_confirmation_message"),
    deleteSuccess("delete_all_data_success_title", "delete_all_data_success_message"),
    permission("enable_notifications", "notification_permission_message"),
    taskPermission("notification_permission_required", "notification_permission_denied_message"),
    emailNotAvailable("email_client_not_available", "email_client_not_available_message"),
    themeWarning("dark_mode_theme_warning_title", "dark_mode_theme_warning_message"),
}

@Composable
private fun EnableInSettingsRow(onClick: () -> Unit) {
    FormRow("enable_in_settings".localized, icon = "exclamationmark.triangle.fill", iconTint = Color.SysOrange, titleColor = Color.SysOrange, onClick = onClick, trailing = { SF("arrow.up.right", Color.SysOrange, 13.dp) })
}

@Composable
private fun MenuRow(title: String, icon: String, tint: Color, value: String, items: List<MenuItem>) {
    IOSMenu(items, Modifier.fillMaxWidth()) {
        FormRow(title, icon = icon, iconTint = tint, trailing = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                T(value, Fonts.body, theme.accentColor, maxLines = 1)
                SF("chevron.up.chevron.down", theme.accentColor, 14.dp)
            }
        })
    }
}

// MARK: - Language

@Composable
internal fun LanguageSelectionView() {
    val theme = theme
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("language".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection {
                val languages = LanguageManager.localizedLanguages
                languages.forEachIndexed { index, language ->
                    FormRow(
                        language.name, divider = index < languages.lastIndex,
                        onClick = { LanguageManager.setLanguage(language.code) },
                        trailing = { if (LanguageManager.currentLanguage.code == language.code) SF("checkmark", theme.primaryColor, 20.dp) },
                    )
                }
            }
        }
    }
}

// MARK: - Themes and customization

@Composable
fun ThemesAndCustomizationView() {
    val theme = theme
    val navigator = LocalNavigator.current
    val settings = SettingsViewModel
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("themes_and_customization".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection("customization".localized) {
                FormRow("themes".localized, icon = "paintbrush.fill", iconTint = Color.SysPurple, chevron = true, onClick = { navigator?.push { ThemeSelectionView() } })
                FormRow(
                    "app_icon".localized, icon = "app.fill", iconTint = Color.SysIndigo, chevron = true,
                    onClick = { navigator?.push { AppIconSelectionView() } },
                    trailing = {
                        Image(
                            painterResource(AppIconManager.current.resource),
                            null,
                            Modifier.size(28.dp).clip(RoundedCornerShape(6.dp)).border(1.dp, theme.borderColor.copy(alpha = 0.2f), RoundedCornerShape(6.dp)),
                        )
                    },
                )
                FormRow("timer_colors".localized, icon = "timer.circle.fill", iconTint = Color.SysOrange, chevron = true, onClick = { navigator?.push { PomodoroColorsView() } })
                ToggleRow("category_gradients".localized, settings.showCategoryGradients, { settings.showCategoryGradients = it }, icon = "paintpalette.fill", iconTint = Color.SysCyan)
                ToggleRow("confetti_celebrations".localized, AppSettings.enableConfettiCelebration, { AppSettings.enableConfettiCelebration = it }, icon = "sparkles", iconTint = Color.SysYellow, subtitle = "confetti_celebrations_description".localized)
                ToggleRow("hide_days_bar".localized, AppSettings.hideDaysBar, { AppSettings.hideDaysBar = it }, icon = "calendar.badge.minus", iconTint = Color.SysBlue, subtitle = "hide_days_bar_description".localized, divider = false)
            }
            FormSection("categories".localized) {
                FormRow("manage_categories".localized, icon = "folder.fill", iconTint = Color.SysBlue, chevron = true, divider = false, onClick = { navigator?.push { CategoriesView() } })
            }
            FormSection("priorities".localized, "customize_task_priorities".localized) {
                FormRow("manage_priorities".localized, icon = "flag.fill", iconTint = Color.SysOrange, chevron = true, divider = false, onClick = { navigator?.push { PrioritiesView() } })
            }
            FormSection("app_behavior".localized, "auto_complete_tasks_footer".localized) {
                FormRow("eisenhower_settings_title".localized, icon = "square.grid.2x2", iconTint = Color.SysRed, subtitle = "eisenhower_threshold_desc".localized, chevron = true, onClick = { navigator?.push { EisenhowerSettingsView() } })
                ToggleRow("auto_complete_tasks".localized, settings.autoCompleteTaskWithSubtasks, { settings.autoCompleteTaskWithSubtasks = it }, icon = "checklist", iconTint = Color.SysGreen, subtitle = "auto_complete_tasks_description".localized)
                ToggleRow("auto_in_progress".localized, settings.autoMarkInProgress, { settings.autoMarkInProgress = it }, icon = "circle.lefthalf.filled", iconTint = Color.SysBlue, subtitle = "auto_in_progress_description".localized, divider = false)
            }
        }
    }
}

/** The list of `SettingsViewModel.priorities`. */
private object PrioritiesStore {
    private val serializer = ListSerializer(Priority.serializer())
    var priorities by mutableStateOf(runCatching { Store.load("savedPriorities", serializer) }.getOrNull() ?: Priority.entries.toList())
        private set

    fun set(list: List<Priority>) {
        priorities = list
        Store.save("savedPriorities", serializer, list)
    }
}

@Composable
internal fun PrioritiesView() {
    val theme = theme
    val presenter = LocalPresenter.current
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("priorities".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection {
                PrioritiesStore.priorities.forEach { priority ->
                    key(priority) {
                        SwipeRow(trailing = listOf(SwipeAction2("trash", "delete".localized, Color.SysRed) { PrioritiesStore.set(PrioritiesStore.priorities - priority) })) {
                            Box(Modifier.background(theme.surfaceColor)) {
                                FormRow(priority.displayName, icon = priority.icon, iconTint = colorFromHex(priority.colorHex))
                            }
                        }
                    }
                }
                FormRow("add_priority".localized, icon = "plus", iconTint = theme.accentColor, titleColor = theme.accentColor, divider = false, onClick = {
                    presenter.sheet { PriorityFormView() }
                })
            }
        }
    }
}

@Composable
internal fun PriorityFormView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    var name by remember { mutableStateOf("") }
    val priority = Priority.entries.firstOrNull { it.name == name.lowercase() }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "new_priority".localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = priority != null, bold = true, color = theme.primaryColor) {
                    if (priority != null && priority !in PrioritiesStore.priorities) PrioritiesStore.set(PrioritiesStore.priorities + priority)
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("priority_details".localized) { FieldRow(name, { name = it }, "priority_name".localized, divider = false) }
            if (priority != null) {
                FormSection("preview".localized) {
                    FormRow(priority.displayName, icon = priority.icon, iconTint = colorFromHex(priority.colorHex), value = "preview".localized, divider = false)
                }
            }
        }
    }
}

// MARK: - Themes

@Composable
internal fun ThemeSelectionView() {
    val current = theme
    val presenter = LocalPresenter.current
    var appearanceMode by appStorage("appearanceMode", "system")
    var justSelected by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<AppThemeSpec?>(null) }
    val scope = rememberCoroutineScope()
    val isSubscribed = SubscriptionManager.isSubscribed

    fun apply(spec: AppThemeSpec) {
        justSelected = spec.id
        ThemeManager.setTheme(spec)
        Haptics.medium()
        scope.launch {
            delay(600)
            justSelected = null
        }
    }
    fun select(spec: AppThemeSpec) {
        if (!ThemeManager.canUseTheme(spec)) {
            presenter.sheet { PremiumPaywallView() }
            return
        }
        if (ThemeManager.currentTheme.id == spec.id) return
        if (spec.overridesSystemColors && appearanceMode != "system") {
            pending = spec
            return
        }
        apply(spec)
    }

    pending?.let { spec ->
        IOSAlert(
            "dark_mode_theme_warning_title".localized,
            "theme_dark_mode_warning_message".localized,
            listOf(
                AlertAction("keep_dark_mode".localized) {
                    appearanceMode = "system"
                    apply(spec)
                },
                AlertAction("keep_simple_theme".localized, AlertRole.cancel),
            ),
            { pending = null },
        )
    }

    @Composable
    fun grid(themes: List<AppThemeSpec>) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            themes.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    row.forEach { spec ->
                        key(spec.id) {
                            ThemeCard(spec, ThemeManager.currentTheme.id == spec.id, justSelected == spec.id, ThemeManager.canUseTheme(spec), Modifier.weight(1f)) { select(spec) }
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }

    Column(Modifier.fillMaxSize().background(current.backgroundColor)) {
        NavBar("themes".localized)
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                T("current_theme".localized, Fonts.headline.semibold)
                val spec = ThemeManager.currentTheme
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(current.surfaceColor)
                        .border(1.5.dp, current.accentColor.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                        .padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    ThemePreviewCard(spec, Modifier.width(150.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        T(spec.name, Fonts.title3.semibold)
                        T("current_theme".localized, Fonts.subheadline, current.secondaryTextColor)
                        if (spec.isPremium) {
                            Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                SF("crown.fill", Color.SysPurple, 13.dp)
                                T("premium".localized, Fonts.caption.medium, Color.SysPurple, maxLines = 1)
                            }
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                T("free_themes".localized, Fonts.headline.semibold)
                grid(ThemeManager.freeThemes)
            }
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("premium_themes".localized, Fonts.headline.semibold, modifier = Modifier.weight(1f))
                    if (!isSubscribed) PremiumBadge(small = true)
                }
                grid(ThemeManager.premiumThemes)
                if (!isSubscribed) T("unlock_premium_themes".localized, Fonts.caption, current.secondaryTextColor, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

@Composable
private fun ThemeCard(spec: AppThemeSpec, selected: Boolean, justSelected: Boolean, canUse: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val current = theme
    val scale by animateFloatAsState(if (justSelected) 1.08f else if (selected) 1.02f else 1f, spring(dampingRatio = 0.7f, stiffness = 300f), label = "themeCard")
    val shape = RoundedCornerShape(12.dp)
    Box(modifier.scale(scale)) {
        Column(
            Modifier
                .fillMaxWidth()
                .alpha(if (canUse) 1f else 0.6f)
                .clip(shape)
                .background(current.surfaceColor)
                .border(if (selected) 2.dp else 1.dp, if (selected) current.accentColor else current.borderColor.copy(alpha = 0.3f), shape)
                .pressable(onClick = onClick)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            ThemePreviewCard(spec, Modifier.fillMaxWidth())
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (spec.isPremium) SF("crown.fill", Color.SysPurple, 12.dp)
                    ShrinkText(spec.name, Fonts.subheadline.medium, current.textColor)
                }
                if (spec.isPremium && !canUse) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        SF("crown.fill", Color.SysPurple, 12.dp)
                        T("premium".localized, Fonts.caption2.medium, Color.SysPurple, maxLines = 1)
                    }
                }
            }
        }
        if (justSelected) {
            Box(Modifier.align(Alignment.TopEnd).size(24.dp).background(current.accentColor, CircleShape), contentAlignment = Alignment.Center) { SF("checkmark", Color.White, 14.dp) }
        }
    }
}

@Composable
private fun ThemePreviewCard(spec: AppThemeSpec, modifier: Modifier) {
    val dark = theme.systemDark
    fun c(dyn: Dyn) = if (dark) dyn.dark else dyn.light
    val border = c(spec.secondaryText)
    Column(
        modifier
            .height(90.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(c(spec.background))
            .border(1.dp, border.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf(spec.primary, spec.secondary, spec.accent).forEach { Box(Modifier.size(14.dp).background(c(it), CircleShape)) }
        }
        Box(Modifier.fillMaxWidth().weight(1f).clip(RoundedCornerShape(6.dp)).background(c(spec.surface)).border(1.dp, border.copy(alpha = 0.3f), RoundedCornerShape(6.dp)))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp, 8.dp).clip(RoundedCornerShape(3.dp)).background(c(spec.text).copy(alpha = 0.8f)))
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(8.dp).background(c(spec.accent), CircleShape))
        }
    }
}

// MARK: - App icon

/** Alternate launcher icons: on Android each one is an `activity-alias` of the main activity. */
object AppIconManager {
    data class Option(val id: String, val displayName: String, val alias: String, val resource: Int)

    val availableIcons: List<Option>
        get() = listOf(
            Option("primary", "SnapTask", "IconDefault", R.drawable.icon_default_preview),
            Option("Inverted", "Inverted", "IconInverted", R.drawable.icon_inverted_preview),
            Option("Neon", "Neon", "IconNeon", R.drawable.icon_neon_preview),
            Option("OGDark", "Og Dark", "IconOGDark", R.drawable.icon_ogdark_preview),
            Option("OGIcon", "Og Icon", "IconOGIcon", R.drawable.icon_ogicon_preview),
            Option("OGNeon", "Og Neon", "IconOGNeon", R.drawable.icon_ogneon_preview),
            Option("OGWhite", "Og White", "IconOGWhite", R.drawable.icon_ogwhite_preview),
        )

    private var currentId by mutableStateOf<String?>(null)

    val current: Option
        get() {
            val id = currentId ?: Defaults.string("appIconId") ?: "primary"
            return availableIcons.firstOrNull { it.id == id } ?: availableIcons.first()
        }

    fun setIcon(option: Option) {
        val context = App.context
        val manager = context.packageManager
        availableIcons.forEach { other ->
            manager.setComponentEnabledSetting(
                ComponentName(context, "com.snaptask.app.${other.alias}"),
                if (other.id == option.id) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        Defaults.set("appIconId", option.id)
        currentId = option.id
    }
}

@Composable
internal fun AppIconSelectionView() {
    val theme = theme
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("app_icon".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection {
                val options = AppIconManager.availableIcons
                options.forEachIndexed { index, option ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .tap {
                                Haptics.light()
                                AppIconManager.setIcon(option)
                            }
                            .padding(horizontal = 16.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Image(painterResource(option.resource), null, Modifier.size(40.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, theme.borderColor.copy(alpha = 0.2f), RoundedCornerShape(8.dp)))
                        T(option.displayName, Fonts.body, modifier = Modifier.weight(1f))
                        if (AppIconManager.current.id == option.id) SF("checkmark.circle.fill", theme.accentColor, 22.dp)
                    }
                    if (index < options.lastIndex) RowDivider(68.dp)
                }
            }
        }
    }
}

// MARK: - Categories

@Composable
fun CategoryEditorView() = CategoriesView()

@Composable
fun CategoriesView() {
    val theme = theme
    val presenter = LocalPresenter.current
    val manager = CategoryManager
    val categories = manager.categories
    var toDelete by remember { mutableStateOf<Category?>(null) }
    val hasUnlimited = SubscriptionManager.hasAccess(PremiumFeature.unlimitedCategories)
    val canAdd = hasUnlimited || categories.size < SubscriptionManager.maxCategoriesForFree

    toDelete?.let { category ->
        IOSAlert(
            "delete_category".localized,
            "delete_category_message".localized + " '${category.name}'?",
            listOf(AlertAction("cancel".localized, AlertRole.cancel), AlertAction("delete".localized, AlertRole.destructive) { manager.removeCategory(category) }),
            { toDelete = null },
        )
    }
    manager.deletionWarning?.let { (category, count) ->
        IOSAlert(
            "warning".localized,
            "delete_category_with_tasks_warning".localized.replace("%@", category.name).replace("%d", "$count"),
            listOf(
                AlertAction("cancel".localized, AlertRole.cancel),
                AlertAction("delete_anyway".localized, AlertRole.destructive) { MainScope.launch { manager.forceRemoveCategory(category) } },
            ),
            { manager.deletionWarning = null },
        )
    }
    fun edit(category: Category) = presenter.sheet { NavigationStack { CategoryFormView(category) { manager.updateCategory(it) } } }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("categories".localized)
        FormPage(Modifier.weight(1f)) {
            if (categories.isEmpty()) {
                FormSection {
                    Column(Modifier.fillMaxWidth().padding(vertical = 24.dp, horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        SF("square.grid.2x2", theme.secondaryTextColor.copy(alpha = 0.6f), 36.dp)
                        T("no_categories_yet".localized, Fonts.headline, align = TextAlign.Center)
                        T("no_categories_hint".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
                    }
                }
            } else {
                FormSection {
                    categories.forEachIndexed { index, category ->
                        key(category.id) {
                            var menuOpen by remember { mutableStateOf(false) }
                            SwipeRow(trailing = listOf(SwipeAction2("trash", "delete".localized, Color.SysRed) { toDelete = category })) {
                                Box {
                                    Row(
                                        Modifier
                                            .fillMaxWidth()
                                            .background(theme.surfaceColor)
                                            .pressable(onLongPress = { menuOpen = true }) { edit(category) }
                                            .padding(horizontal = 16.dp, vertical = 9.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        CategoryIconTile(category.displayIcon, colorFromHex(category.color), 36.dp)
                                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                            T(category.name, Fonts.body.medium)
                                            val count = TaskManager.tasks.count { it.category?.id == category.id }
                                            T((if (count == 1) "category_tasks_count_one" else "category_tasks_count").localized.replace("%d", "$count"), Fonts.caption, theme.secondaryTextColor)
                                        }
                                        SF("chevron.right", theme.secondaryTextColor.copy(alpha = 0.6f), 15.dp)
                                    }
                                    if (menuOpen) {
                                        MenuPopup(
                                            listOf(
                                                MenuItem("edit".localized, "pencil") { edit(category) },
                                                MenuItem("delete".localized, "trash", destructive = true) { toDelete = category },
                                            ),
                                        ) { menuOpen = false }
                                    }
                                }
                            }
                        }
                        if (index < categories.lastIndex) RowDivider(64.dp)
                    }
                }
            }
            FormSection {
                val tint = if (canAdd) theme.primaryColor else theme.secondaryTextColor
                Row(
                    Modifier
                        .fillMaxWidth()
                        .tap {
                            if (canAdd) presenter.sheet { NavigationStack { CategoryFormView { manager.addCategory(it) } } }
                            else presenter.sheet { PremiumPaywallView() }
                        }
                        .padding(horizontal = 16.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.size(36.dp), contentAlignment = Alignment.Center) {
                        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
                            drawRoundRect(
                                tint.copy(alpha = 0.6f),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(10.dp.toPx()),
                                style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))),
                            )
                        }
                        SF("plus", tint, 18.dp)
                    }
                    T("add_category".localized, Fonts.body.medium, tint, modifier = Modifier.weight(1f))
                    if (!canAdd) PremiumBadge(small = true)
                }
            }
            if (!hasUnlimited) {
                FormSection {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SF("info.circle", Color.SysOrange, 20.dp)
                            T("free_plan_limits".localized, Fonts.headline, Color.SysOrange)
                        }
                        T("categories_limit_message".localized, Fonts.subheadline, Color.Secondary)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("${categories.size}/${SubscriptionManager.maxCategoriesForFree}", Fonts.caption, Color.Secondary, modifier = Modifier.weight(1f))
                            T("upgrade_to_pro".localized, Fonts.caption, Color.SysPurple, maxLines = 1, modifier = Modifier.tap { presenter.sheet { PremiumPaywallView() } })
                        }
                    }
                }
            }
        }
    }
}

private val categoryPalette = listOf(
    "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#30B0C7", "#32ADE6",
    "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93",
)
private val categorySuggestedIcons = listOf(
    "briefcase.fill", "house.fill", "heart.fill", "figure.run", "book.fill", "graduationcap.fill",
    "cart.fill", "banknote.fill", "person.2.fill", "paintbrush.fill", "music.note", "gamecontroller.fill",
    "airplane", "leaf.fill", "fork.knife", "bed.double.fill", "laptopcomputer", "brain.head.profile",
    "pawprint.fill", "star.fill", "sparkles", "target", "lightbulb.fill", "tag.fill",
)

@Composable
fun CategoryFormView(editing: Category? = null, onSave: (Category) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    var name by remember { mutableStateOf(editing?.name ?: "") }
    var colorHex by remember { mutableStateOf(editing?.color ?: categoryPalette[7]) }
    var icon by remember { mutableStateOf(editing?.displayIcon ?: "tag.fill") }
    val tint = colorFromHex(colorHex)
    val trimmed = name.trim()
    val duplicate = CategoryManager.categories.any { it.id != editing?.id && it.name.equals(trimmed, ignoreCase = true) }
    val isCustomColor = categoryPalette.none { it.equals(colorHex, ignoreCase = true) }

    @Composable
    fun section(title: String, content: @Composable ColumnScope.() -> Unit) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            T(title.uppercase(appLocale), Fonts.footnote.medium, theme.secondaryTextColor, modifier = Modifier.padding(horizontal = 4.dp))
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(theme.surfaceColor).padding(14.dp), content = content)
        }
    }
    @Composable
    fun iconCell(symbol: String, selected: Boolean, modifier: Modifier) {
        val background by animateColorAsState(if (selected) tint else theme.textColor.copy(alpha = 0.06f), tween(150), label = "iconCell")
        Box(modifier.height(44.dp).clip(RoundedCornerShape(12.dp)).background(background).tap { icon = symbol }, contentAlignment = Alignment.Center) {
            SF(symbol, if (selected) Color.White else theme.textColor.copy(alpha = 0.75f), 20.dp)
        }
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            (if (editing == null) "new_category" else "edit_category").localized,
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = trimmed.isNotEmpty() && !duplicate, bold = true) {
                    onSave(Category(editing?.id ?: UUID.randomUUID(), trimmed, colorHex, icon))
                    dismiss()
                }
            },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 20.dp).navigationBarsPadding().imePadding(),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                CategoryIconTile(icon, tint, 72.dp)
                T(trimmed.ifEmpty { "category_name".localized }, Fonts.title3.semibold, if (trimmed.isEmpty()) theme.secondaryTextColor else theme.textColor, TextAlign.Center)
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                PlainField(
                    name, { name = it }, "category_name".localized,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(theme.surfaceColor).padding(horizontal = 14.dp, vertical = 12.dp),
                )
                if (duplicate) {
                    Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        SF("exclamationmark.circle.fill", Color.SysRed, 15.dp)
                        T("category_name_exists".localized, Fonts.footnote, Color.SysRed)
                    }
                }
            }
            section("color".localized) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    (categoryPalette + "custom").chunked(7).forEach { row ->
                        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            row.forEach { hex ->
                                val custom = hex == "custom"
                                val selected = if (custom) isCustomColor else colorHex.equals(hex, ignoreCase = true)
                                val color = if (custom) tint else colorFromHex(hex)
                                Box(Modifier.size(42.dp), contentAlignment = Alignment.Center) {
                                    if (selected) Box(Modifier.size(42.dp).border(2.5.dp, color, CircleShape))
                                    Box(
                                        Modifier
                                            .size(32.dp)
                                            .clip(CircleShape)
                                            .then(
                                                if (custom) Modifier.background(Brush.sweepGradient(listOf(Color.Red, Color.Yellow, Color.Green, Color.Cyan, Color.Blue, Color.Magenta, Color.Red)))
                                                else Modifier.background(color),
                                            )
                                            .tap {
                                                if (custom) presenter.sheet(SheetDetent.fit) { CustomColorSheet(colorHex) { colorHex = it } }
                                                else colorHex = hex
                                            },
                                    )
                                }
                            }
                            repeat(7 - row.size) { Spacer(Modifier.size(42.dp)) }
                        }
                    }
                }
            }
            section("icon".localized) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    categorySuggestedIcons.chunked(6).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            row.forEach { symbol -> iconCell(symbol, symbol == icon, Modifier.weight(1f)) }
                        }
                    }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .tap { presenter.sheet { IconPickerView(icon) { icon = it } } }
                            .padding(horizontal = 4.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        if (icon !in categorySuggestedIcons) iconCell(icon, true, Modifier.size(40.dp))
                        T("all_icons".localized, Fonts.subheadline.medium, theme.primaryColor, modifier = Modifier.weight(1f))
                        SF("chevron.right", theme.primaryColor, 15.dp)
                    }
                }
            }
        }
    }
}

// MARK: - Premium

@Composable
fun PremiumBadge(small: Boolean = false) {
    val shape = RoundedCornerShape(if (small) 4.dp else 6.dp)
    T(
        "PRO",
        (if (small) Fonts.caption2 else Fonts.caption).bold,
        Color.White,
        maxLines = 1,
        modifier = Modifier
            .clip(shape)
            .background(Brush.horizontalGradient(listOf(Color.SysPurple, Color.SysPink)))
            .padding(horizontal = if (small) 4.dp else 6.dp, vertical = if (small) 2.dp else 3.dp),
    )
}

@Composable
fun PremiumPaywallView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val sub = SubscriptionManager
    var plan by remember { mutableStateOf("yearly") }
    var processing by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { sub.loadProducts() }
    val selected = when (plan) {
        "lifetime" -> sub.lifetimeProduct
        "yearly" -> sub.yearlyProduct
        else -> sub.monthlyProduct
    }

    fun purchase() {
        val product = selected ?: return
        val activity = CurrentActivity.activity ?: return
        processing = true
        scope.launch {
            val success = sub.purchase(activity, product)
            processing = false
            message = if (success) {
                when {
                    plan == "lifetime" -> "welcome_snaptask_pro_lifetime".localized
                    plan == "yearly" && sub.subscriptionStatus.isInTrial -> "free_trial_activated".localized
                    else -> "welcome_snaptask_pro".localized
                }
            } else "purchase_not_completed".localized
            if (success) {
                delay(2000)
                dismiss()
            }
        }
    }
    fun restore() {
        processing = true
        scope.launch {
            val success = sub.restorePurchases()
            processing = false
            message = (if (success) "purchases_restored_successfully" else "no_purchases_to_restore").localized
            if (success) {
                delay(1500)
                dismiss()
            }
        }
    }

    message?.let {
        IOSAlert("subscription".localized, it, listOf(AlertAction("ok".localized)), { message = null })
    }

    Column(Modifier.fillMaxSize().background(Color.GroupedBackground)) {
        NavBar("snaptask_pro".localized, background = Color.GroupedBackground, trailing = { BarButton("close".localized, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 10.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    Modifier
                        .size(44.dp)
                        .shadow(8.dp, CircleShape, clip = false, ambientColor = Color.SysPurple, spotColor = Color.SysPurple)
                        .background(Brush.linearGradient(listOf(Color.SysPurple.copy(alpha = 0.8f), Color.SysPink.copy(alpha = 0.8f))), CircleShape),
                    contentAlignment = Alignment.Center,
                ) { SF("crown.fill", Color.White, 20.dp) }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    T("unlock_snaptask_pro".localized, Fonts.title3.bold, Color.Primary, TextAlign.Center)
                    T("maximize_your_productivity".localized, Fonts.subheadline, Color.Secondary, TextAlign.Center)
                }
            }
            Column(Modifier.padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("everything_you_get".localized, Fonts.headline.medium, Color.Primary)
                val features = listOf(
                    Triple("folder.fill", "unlimited_categories", Color.SysBlue),
                    Triple("star.fill", "task_evaluation", Color.SysYellow),
                    Triple("gift.fill", "unlimited_rewards", Color.SysPurple),
                    Triple("chart.line.uptrend.xyaxis", "advanced_statistics", Color.SysGreen),
                    Triple("paintbrush.fill", "custom_themes", Color.SysPink),
                )
                features.chunked(3).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { (icon, key, color) ->
                            Column(
                                Modifier
                                    .weight(1f)
                                    .height(66.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(Color.SystemBackground)
                                    .border(1.dp, color.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
                                    .padding(vertical = 6.dp, horizontal = 4.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
                            ) {
                                Box(Modifier.size(28.dp).background(color.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, color, 14.dp) }
                                T(key.localized, systemFont(9, FontWeight.Medium), Color.Primary, TextAlign.Center, maxLines = 2)
                            }
                        }
                        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
            Column(Modifier.padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                T("choose_your_plan".localized, Fonts.headline.medium, Color.Primary)
                PlanCard("lifetime_access".localized, sub.lifetimeProduct?.displayPrice ?: "---", "one_time_no_subscription".localized, "best_value".localized, plan == "lifetime", Color.SysOrange, true, null, 120.dp, Modifier.fillMaxWidth()) { plan = "lifetime" }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PlanCard("yearly".localized, sub.yearlyProduct?.displayPrice ?: "---", "days_free_then".localized(sub.yearlyProduct?.displayPrice ?: "---"), "free_trial".localized, plan == "yearly", Color.SysGreen, false, sub.yearlySavingsAmount.takeIf { sub.yearlyProduct != null }, 140.dp, Modifier.weight(1f)) { plan = "yearly" }
                    PlanCard("monthly".localized, sub.monthlyProduct?.displayPrice ?: "---", "total_flexibility".localized, null, plan == "monthly", Color.SysPurple, false, null, 140.dp, Modifier.weight(1f)) { plan = "monthly" }
                }
            }
        }
        Column(Modifier.fillMaxWidth().background(theme.surfaceColor).navigationBarsPadding().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            val colors = if (plan == "lifetime") listOf(Color.SysOrange, Color.SysRed) else listOf(Color.SysPurple, Color.SysPink)
            val enabled = !processing && selected != null
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(50.dp)
                    .alpha(if (enabled || processing) 1f else 0.6f)
                    .shadow(6.dp, RoundedCornerShape(14.dp), clip = false, ambientColor = colors[0], spotColor = colors[0])
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brush.horizontalGradient(colors))
                    .pressable(enabled = enabled, onClick = ::purchase),
                contentAlignment = Alignment.Center,
            ) {
                if (processing) {
                    androidx.compose.material3.CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                } else Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    when (plan) {
                        "yearly" -> {
                            T("start_free_trial".localized, Fonts.headline.semibold, Color.White, maxLines = 1)
                            ShrinkText("days_free_then".localized(selected?.displayPrice ?: "---"), Fonts.caption, Color.White.copy(alpha = 0.8f), minScale = 0.8f)
                        }
                        "lifetime" -> {
                            T("purchase_lifetime_access".localized, Fonts.headline.semibold, Color.White, maxLines = 1)
                            T("one_time_payment".localized, Fonts.caption, Color.White.copy(alpha = 0.8f), maxLines = 1)
                        }
                        else -> ShrinkText("subscribe_monthly_plan".localized, Fonts.headline.semibold, Color.White, minScale = 0.9f)
                    }
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally)) {
                Box(Modifier.tap(enabled = !processing, onClick = ::restore)) { ShrinkText("restore_purchases".localized, Fonts.footnote.medium, Color.SysPurple, minScale = 0.8f) }
                Box(Modifier.tap { sub.manageSubscriptions() }) { ShrinkText("manage_subscriptions".localized, Fonts.footnote.medium, Color.SysPurple, minScale = 0.8f) }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally)) {
                T("terms_of_service".localized, Fonts.caption2, Color.Secondary, maxLines = 1, modifier = Modifier.tap { presenter.sheet { LegalDocumentView(LegalDocument.terms) } })
                T("privacy_policy".localized, Fonts.caption2, Color.Secondary, maxLines = 1, modifier = Modifier.tap { presenter.sheet { LegalDocumentView(LegalDocument.privacy) } })
            }
        }
    }
}

@Composable
private fun PlanCard(title: String, price: String, subtitle: String, badge: String?, selected: Boolean, badgeColor: Color, isLifetime: Boolean, savings: String?, height: androidx.compose.ui.unit.Dp, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    val scale by animateFloatAsState(if (selected) 1.02f else 1f, spring(dampingRatio = 0.8f, stiffness = 400f), label = "plan")
    val accent = if (isLifetime) Color.SysOrange else Color.SysPurple
    val border = if (selected) Brush.horizontalGradient(if (isLifetime) listOf(Color.SysOrange, Color.SysRed) else listOf(Color.SysPurple, Color.SysPink)) else Brush.horizontalGradient(listOf(Color.SysGray.copy(alpha = 0.3f), Color.SysGray.copy(alpha = 0.3f)))
    Column(
        modifier
            .scale(scale)
            .height(height)
            .shadow(if (selected) 8.dp else 3.dp, shape, clip = false, ambientColor = if (selected) accent else Color.Black, spotColor = if (selected) accent else Color.Black)
            .clip(shape)
            .background(Color.SystemBackground)
            .border(if (selected) 2.dp else 1.dp, border, shape)
            .tap(onClick = onClick)
            .padding(vertical = 8.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.height(20.dp)) {
            if (badge != null) {
                T(badge, systemFont(9, FontWeight.Bold), Color.White, maxLines = 1, modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(badgeColor).padding(horizontal = 8.dp, vertical = 3.dp))
            }
        }
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(title, Fonts.subheadline.semibold, Color.Primary, maxLines = 1)
            T(price, Fonts.title3.bold, accent, maxLines = 1)
            T(subtitle, Fonts.caption, Color.Secondary, TextAlign.Center, maxLines = 2)
        }
        Spacer(Modifier.weight(1f))
        if (savings != null) ShrinkText("savings_amount".localized(savings), systemFont(11, FontWeight.SemiBold), Color.SysGreen, minScale = 0.8f)
    }
}

@Composable
internal fun PremiumStatusView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    val sub = SubscriptionManager
    val status = sub.subscriptionStatus
    val expiration = (status as? SubscriptionStatus.Subscribed)?.expirationDate ?: (status as? SubscriptionStatus.InTrial)?.expirationDate
    val expirationText = if (status is SubscriptionStatus.Subscribed && expiration == null) "lifetime_access".localized else status.displayStatus
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("snaptask_pro".localized, trailing = { BarButton("close".localized, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(theme.surfaceColor).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.size(48.dp).background(Brush.linearGradient(listOf(Color.SysPurple.copy(alpha = 0.9f), Color.SysPink.copy(alpha = 0.9f))), CircleShape), contentAlignment = Alignment.Center) { SF("crown.fill", Color.White, 22.dp) }
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    T("premium_plan_active".localized, Fonts.headline)
                    T(expirationText, Fonts.subheadline, theme.secondaryTextColor)
                }
            }
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(theme.surfaceColor).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T("everything_you_get".localized, Fonts.headline)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    val features = PremiumFeature.entries
                    features.forEachIndexed { index, feature ->
                        val (icon, color) = when (feature) {
                            PremiumFeature.unlimitedCategories -> "folder.fill" to Color.SysBlue
                            PremiumFeature.taskEvaluation -> "star.fill" to Color.SysYellow
                            PremiumFeature.unlimitedRewards -> "gift.fill" to Color.SysPurple
                            PremiumFeature.advancedStatistics -> "chart.line.uptrend.xyaxis" to Color.SysGreen
                            PremiumFeature.customThemes -> "paintbrush.fill" to Color.SysPink
                        }
                        Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            Box(Modifier.size(40.dp).background(color.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) { SF(icon, color, 20.dp) }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                T(feature.localizedName, Fonts.subheadline.semibold)
                                T(feature.localizedDescription, Fonts.caption, theme.secondaryTextColor)
                            }
                            if (sub.hasAccess(feature)) SF("checkmark.seal.fill", Color.SysGreen, 22.dp) else SF("xmark.seal", Color.Secondary, 20.dp)
                        }
                        if (index < features.lastIndex) Box(Modifier.fillMaxWidth().height(0.5.dp).background(theme.borderColor.copy(alpha = 0.2f)))
                    }
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T(
                    "manage_subscriptions".localized, Fonts.body.semibold, Color.White, TextAlign.Center,
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Brush.horizontalGradient(listOf(Color.SysPurple, Color.SysPink))).pressable { sub.manageSubscriptions() }.padding(vertical = 12.dp),
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(theme.surfaceColor)
                        .border(1.dp, Color.Secondary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                        .pressable { scope.launch { sub.restorePurchases() } }
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SF("arrow.clockwise", theme.primaryColor, 18.dp)
                    T("restore_purchases".localized, Fonts.body.semibold, theme.primaryColor, maxLines = 1)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    T("terms_of_service".localized, Fonts.caption, Color.Secondary, maxLines = 1, modifier = Modifier.tap { presenter.sheet { LegalDocumentView(LegalDocument.terms) } })
                    T("privacy_policy".localized, Fonts.caption, Color.Secondary, maxLines = 1, modifier = Modifier.tap { presenter.sheet { LegalDocumentView(LegalDocument.privacy) } })
                }
            }
        }
    }
}

// MARK: - Legal

enum class LegalDocument(val fileName: String, val titleKey: String) {
    terms("TermsOfService", "terms_of_service"),
    privacy("PrivacyPolicy", "privacy_policy"),
}

private fun loadLegal(document: LegalDocument): String {
    val code = LanguageManager.actualLanguageCode.lowercase().take(2)
    return listOf(code, "en").firstNotNullOfOrNull { candidate ->
        runCatching { App.context.assets.open("legal/${document.fileName}.$candidate.md").bufferedReader().use { it.readText() } }.getOrNull()
    } ?: ""
}

@Composable
fun LegalDocumentView(document: LegalDocument) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val text = remember(document, LanguageManager.actualLanguageCode) { loadLegal(document) }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(document.titleKey.localized, trailing = { BarButton("close".localized, onClick = dismiss) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            T(document.titleKey.localized, Fonts.title.bold)
            MarkdownView(text)
        }
    }
}

@Composable
fun MarkdownView(text: String) {
    val blocks = remember(text) { parseMarkdown(text) }
    val paragraph = Fonts.body.copy(lineHeight = (Fonts.body.fontSize.value + 8).sp)
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        blocks.forEach { block ->
            when (block) {
                is MdBlock.Heading -> T(block.text, if (block.level == 1) Fonts.title.bold else if (block.level == 2) Fonts.headline.bold else Fonts.subheadline.bold)
                is MdBlock.Paragraph -> T(block.text, paragraph)
                is MdBlock.Items -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    block.items.forEachIndexed { index, item ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            T(if (block.numbered) "${index + 1}." else "•", Fonts.body)
                            T(item, paragraph)
                        }
                    }
                }
            }
        }
    }
}

private sealed class MdBlock {
    data class Heading(val level: Int, val text: String) : MdBlock()
    data class Paragraph(val text: String) : MdBlock()
    data class Items(val items: List<String>, val numbered: Boolean) : MdBlock()
}

private fun parseMarkdown(text: String): List<MdBlock> {
    val blocks = ArrayList<MdBlock>()
    val paragraph = ArrayList<String>()
    val bullets = ArrayList<String>()
    val numbers = ArrayList<String>()
    fun flushParagraph() {
        paragraph.joinToString(" ").trim().takeIf { it.isNotEmpty() }?.let { blocks += MdBlock.Paragraph(it) }
        paragraph.clear()
    }
    fun flushBullets() {
        if (bullets.isNotEmpty()) blocks += MdBlock.Items(bullets.toList(), false)
        bullets.clear()
    }
    fun flushNumbers() {
        if (numbers.isNotEmpty()) blocks += MdBlock.Items(numbers.toList(), true)
        numbers.clear()
    }
    val number = Regex("^\\d+\\.\\s")
    text.replace("\r\n", "\n").replace("\r", "\n").split("\n").forEach { raw ->
        val line = raw.trim()
        val heading = when {
            line.startsWith("### ") -> 3 to line.drop(4)
            line.startsWith("## ") -> 2 to line.drop(3)
            line.startsWith("# ") -> 1 to line.drop(2)
            else -> null
        }
        when {
            line.isEmpty() -> {
                flushParagraph()
                flushBullets()
                flushNumbers()
            }
            heading != null -> {
                flushParagraph()
                flushBullets()
                flushNumbers()
                blocks += MdBlock.Heading(heading.first, heading.second)
            }
            line.startsWith("- ") || line.startsWith("• ") -> {
                flushParagraph()
                flushNumbers()
                bullets += line.drop(2).trim()
            }
            number.find(line) != null -> {
                flushParagraph()
                flushBullets()
                numbers += line.substring(number.find(line)!!.range.last + 1).trim()
            }
            else -> paragraph += line
        }
    }
    flushParagraph()
    flushBullets()
    flushNumbers()
    return blocks
}

// MARK: - Welcome

private data class OnboardingStep(val icon: String, val number: Int, val color: @Composable () -> Color)

@Composable
fun WelcomeView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val presenter = LocalPresenter.current
    // iOS has a sixth step about iCloud: there is no sync on Android, so it isn't promised.
    val steps = listOf(
        OnboardingStep("checkmark.circle.fill", 1) { Color.SysBlue },
        OnboardingStep("timer", 2) { Color.SysRed },
        OnboardingStep("gift.fill", 3) { Color.SysPurple },
        OnboardingStep("chart.line.uptrend.xyaxis", 4) { Color.SysGreen },
        OnboardingStep("bubble.left.and.bubble.right.fill", 6) { Color.SysTeal },
    )
    var current by remember { mutableStateOf(0) }
    var showingContent by remember { mutableStateOf(false) }
    val step = steps[current]
    val color = step.color()
    val animated by animateColorAsState(color, tween(800), label = "welcome")

    fun complete() {
        Defaults.set("hasShownWelcome", true)
        WelcomeContentSeeder.seedIfNeeded()
        dismiss()
    }
    fun showPaywall() {
        // Nothing to sell in a tester build: everything is already unlocked.
        if (BuildConfig.UNLOCK_PRO) complete() else presenter.sheet(onDismiss = { complete() }) { PremiumPaywallView() }
    }

    LaunchedEffect(Unit) {
        SubscriptionManager.loadProducts()
    }
    LaunchedEffect(Unit) {
        delay(300)
        showingContent = true
    }
    LaunchedEffect(current) {
        if (current == steps.lastIndex && !BuildConfig.UNLOCK_PRO) {
            delay(2000)
            showPaywall()
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(theme.backgroundColor)
            .background(Brush.linearGradient(listOf(theme.backgroundColor.copy(alpha = 0.05f), animated.copy(alpha = 0.1f), theme.backgroundColor.copy(alpha = 0.05f)))),
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(top = 40.dp), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                steps.indices.forEach { index ->
                    val scale by animateFloatAsState(if (index == current) 1.3f else 1f, spring(dampingRatio = 0.8f, stiffness = 200f), label = "dot")
                    Box(Modifier.scale(scale).size(8.dp).background(if (index <= current) animated else theme.borderColor, CircleShape))
                }
            }
            Box(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()), contentAlignment = Alignment.Center) {
                AnimatedContent(
                    current,
                    Modifier.alpha(if (showingContent) 1f else 0f).padding(vertical = 16.dp),
                    transitionSpec = { (fadeIn(tween(400)) + slideInHorizontally(tween(400)) { it / 6 }) togetherWith fadeOut(tween(250)) },
                    label = "welcomeStep",
                ) { index ->
                    val item = steps[index]
                    val itemColor = item.color()
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(40.dp)) {
                        Box(
                            Modifier.size(120.dp).background(Brush.radialGradient(listOf(itemColor.copy(alpha = 0.15f), itemColor.copy(alpha = 0.05f))), CircleShape),
                            contentAlignment = Alignment.Center,
                        ) { SF(item.icon, itemColor, 56.dp) }
                        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
                            T("onboarding_title_${item.number}".localized, Fonts.title.bold, align = TextAlign.Center)
                            T("onboarding_subtitle_${item.number}".localized, Fonts.title2.semibold, itemColor, TextAlign.Center)
                            T("onboarding_description_${item.number}".localized, Fonts.body, theme.secondaryTextColor, TextAlign.Center)
                        }
                    }
                }
            }
            Column(Modifier.padding(start = 24.dp, end = 24.dp, bottom = 30.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                val last = current == steps.lastIndex
                val colors = if (last) listOf(Color.SysPurple, Color.SysPink) else listOf(animated, animated.copy(alpha = 0.8f))
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(56.dp)
                        .shadow(8.dp, RoundedCornerShape(16.dp), clip = false, ambientColor = colors[0], spotColor = colors[0])
                        .clip(RoundedCornerShape(16.dp))
                        .background(Brush.horizontalGradient(colors))
                        .pressable { if (last) showPaywall() else current += 1 },
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (last) SF("crown.fill", Color.White, 20.dp)
                    ShrinkText((if (last) "onboarding_unlock_potential" else "onboarding_continue").localized, Fonts.headline.semibold, Color.White, minScale = 0.8f)
                    if (!last) SF("arrow.right", Color.White, 20.dp)
                }
                Row(Modifier.padding(horizontal = 8.dp).alpha(if (showingContent) 1f else 0f), verticalAlignment = Alignment.CenterVertically) {
                    if (current > 0) {
                        Row(Modifier.tap { current -= 1 }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            SF("chevron.left", theme.secondaryTextColor, 16.dp)
                            T("back".localized, Fonts.subheadline.medium, theme.secondaryTextColor, maxLines = 1)
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    if (!last) T("onboarding_skip".localized, Fonts.subheadline.medium, theme.secondaryTextColor, maxLines = 1, modifier = Modifier.tap { current = steps.lastIndex })
                }
            }
        }
    }
}

/** First-launch content: three starter categories and two "learn by doing" tasks. */
private object WelcomeContentSeeder {
    private const val seededKey = "welcomeContentSeeded"
    private val workId = UUID.fromString("5E1C0A7E-0001-4A11-9C0D-57A27E0C0001")
    private val personalId = UUID.fromString("5E1C0A7E-0002-4A11-9C0D-57A27E0C0002")
    private val healthId = UUID.fromString("5E1C0A7E-0003-4A11-9C0D-57A27E0C0003")
    private val firstTaskId = UUID.fromString("5E1C0A7E-1001-4A11-9C0D-57A27E0C1001")
    private val secondTaskId = UUID.fromString("5E1C0A7E-1002-4A11-9C0D-57A27E0C1002")

    fun seedIfNeeded() {
        if (Defaults.bool(seededKey)) return
        Defaults.set(seededKey, true)
        MainScope.launch {
            if (TaskManager.tasks.isNotEmpty() || CategoryManager.categories.isNotEmpty()) return@launch
            val personal = Category(personalId, "starter_category_personal".localized, "#F97316", "person.fill")
            CategoryManager.addCategory(Category(workId, "starter_category_work".localized, "#3B82F6", "briefcase.fill"))
            CategoryManager.addCategory(personal)
            CategoryManager.addCategory(Category(healthId, "starter_category_health".localized, "#10B981", "heart.fill"))

            val time = now()
            val minute = time.minute
            val start = time.addingMinutes(if (minute < 30) 30 - minute else 60 - minute).withTime(time.addingMinutes(if (minute < 30) 30 - minute else 60 - minute).hour, time.addingMinutes(if (minute < 30) 30 - minute else 60 - minute).minute, 0)
            val first = TodoTask(
                id = firstTaskId,
                name = "welcome_task1_title".localized,
                description = "welcome_task1_description".localized,
                startTime = start,
                hasSpecificDay = true,
                hasSpecificTime = true,
                duration = 15.0 * 60,
                hasDuration = true,
                category = personal,
                priority = Priority.high,
                icon = "hand.wave.fill",
                subtasks = (1..6).map { Subtask(name = "welcome_task1_step$it".localized) },
                hasRewardPoints = true,
                rewardPoints = 10,
                timeScope = TaskTimeScope.today,
            )
            val second = TodoTask(
                id = secondTaskId,
                name = "welcome_task2_title".localized,
                description = "welcome_task2_description".localized,
                startTime = time.startOfDay(),
                hasSpecificDay = true,
                hasSpecificTime = false,
                priority = Priority.medium,
                icon = "map.fill",
                subtasks = (1..7).map { Subtask(name = "welcome_task2_step$it".localized) },
                timeScope = TaskTimeScope.today,
            )
            TaskManager.addTask(first)
            TaskManager.addTask(second)
            TaskListOrder.listKey(TaskTimeScope.today, time)?.let { TaskOrderManager.setOrder(listOf(first.id, second.id), it) }
        }
    }
}

