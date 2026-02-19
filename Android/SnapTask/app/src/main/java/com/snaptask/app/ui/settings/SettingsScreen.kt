package com.snaptask.app.ui.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Label
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R
import com.snaptask.app.ui.components.MotivationalQuoteCard
import com.snaptask.app.ui.settings.EisenhowerSettingsScreen
import com.snaptask.app.ui.settings.BackupRestoreScreen
import java.util.Calendar

/**
 * Settings screen matching iOS SettingsView.
 * Sections: Appearance, Notifications, Categories, Behaviour, Data Management, About.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel(),
    onDismiss: () -> Unit,
) {
    val appearanceMode by viewModel.appearanceMode.collectAsState()
    val showCategoryGradients by viewModel.showCategoryGradients.collectAsState()
    val autoComplete by viewModel.autoCompleteWithSubtasks.collectAsState()
    val dailyQuoteNotif by viewModel.dailyQuoteNotificationsEnabled.collectAsState()
    val dailyQuoteTime by viewModel.dailyQuoteNotificationTime.collectAsState()
    val diaryNotif by viewModel.diaryNotificationsEnabled.collectAsState()
    val diaryTime by viewModel.diaryNotificationTime.collectAsState()
    val taskNotif by viewModel.taskNotificationsEnabled.collectAsState()
    val isDeleting by viewModel.isDeleting.collectAsState()
    val categories by viewModel.categories.collectAsState()
    val selectedLanguageCode by viewModel.selectedLanguageCode.collectAsState()
    val quoteViewModel: QuoteViewModel = hiltViewModel()
    val quote by quoteViewModel.currentQuote.collectAsState()
    val quoteLoading by quoteViewModel.isLoading.collectAsState()

    var showCategories by remember { mutableStateOf(false) }
    var showThemes by remember { mutableStateOf(false) }
    var showDeleteConfirmation by remember { mutableStateOf(false) }
    var showFeedback by remember { mutableStateOf(false) }
    var showDonation by remember { mutableStateOf(false) }
    var showQuoteTimePicker by remember { mutableStateOf(false) }
    var showDiaryTimePicker by remember { mutableStateOf(false) }
    var showLanguage by remember { mutableStateOf(false) }
    var showEisenhower by remember { mutableStateOf(false) }
    var showBackupRestore by remember { mutableStateOf(false) }
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_title), fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back))
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            // ---- Appearance Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_appearance))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.DarkMode,
                    iconTint = Color(0xFF5C6BC0),
                    title = stringResource(R.string.settings_appearance),
                    trailing = {
                        var expanded by remember { mutableStateOf(false) }
                        Box {
                            TextButton(onClick = { expanded = true }) {
                                Text(
                                    when (appearanceMode) {
                                        "light" -> stringResource(R.string.settings_appearance_light)
                                        "dark" -> stringResource(R.string.settings_appearance_dark)
                                        else -> stringResource(R.string.settings_appearance_system)
                                    },
                                )
                            }
                            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                                DropdownMenuItem(text = { Text(stringResource(R.string.settings_appearance_system)) }, onClick = { viewModel.setAppearanceMode("system"); expanded = false })
                                DropdownMenuItem(text = { Text(stringResource(R.string.settings_appearance_light)) }, onClick = { viewModel.setAppearanceMode("light"); expanded = false })
                                DropdownMenuItem(text = { Text(stringResource(R.string.settings_appearance_dark)) }, onClick = { viewModel.setAppearanceMode("dark"); expanded = false })
                            }
                        }
                    },
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))

                SettingsRow(
                    icon = Icons.Filled.Palette,
                    iconTint = Color(0xFF9C27B0),
                    title = stringResource(R.string.settings_themes_customization),
                    onClick = { showThemes = true },
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))

                SettingsRow(
                    icon = Icons.Filled.Language,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_language),
                    trailing = {
                        Text(
                            when (selectedLanguageCode) {
                                "system" -> stringResource(R.string.settings_appearance_system)
                                "en" -> stringResource(R.string.language_english)
                                "it" -> stringResource(R.string.language_italian)
                                "es" -> stringResource(R.string.language_spanish)
                                "fr" -> stringResource(R.string.language_french)
                                "pt" -> stringResource(R.string.language_portuguese)
                                "de" -> stringResource(R.string.language_german)
                                "ja" -> stringResource(R.string.language_japanese)
                                else -> selectedLanguageCode
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    },
                    onClick = { showLanguage = true },
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))

                SettingsRow(
                    icon = Icons.Filled.Gradient,
                    iconTint = Color(0xFFE91E63),
                    title = stringResource(R.string.settings_category_gradients),
                    trailing = {
                        Switch(
                            checked = showCategoryGradients,
                            onCheckedChange = { viewModel.setShowCategoryGradients(it) },
                        )
                    },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Quote of the Day (matches iOS) ----
            SettingsSectionHeader(stringResource(R.string.quote_of_the_day))
            MotivationalQuoteCard(
                quote = quote.text,
                author = quote.author,
                isLoading = quoteLoading,
                onRefresh = { quoteViewModel.refreshQuote() },
                modifier = Modifier.padding(vertical = 4.dp),
            )

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Notifications Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_notifications))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.Notifications,
                    iconTint = Color(0xFFFF9800),
                    title = stringResource(R.string.settings_daily_quote_reminder),
                    trailing = {
                        Switch(
                            checked = dailyQuoteNotif,
                            onCheckedChange = { viewModel.setDailyQuoteNotifications(it) },
                        )
                    },
                )
                if (dailyQuoteNotif) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    SettingsRow(
                        icon = Icons.Filled.AccessTime,
                        iconTint = Color(0xFF2196F3),
                        title = stringResource(R.string.settings_notification_time),
                        trailing = { Text(dailyQuoteTime, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) },
                        onClick = { showQuoteTimePicker = true },
                    )
                }

                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))

                SettingsRow(
                    icon = Icons.AutoMirrored.Filled.MenuBook,
                    iconTint = Color(0xFFFF9800),
                    title = stringResource(R.string.settings_diary_reminder),
                    trailing = {
                        Switch(
                            checked = diaryNotif,
                            onCheckedChange = { viewModel.setDiaryNotifications(it) },
                        )
                    },
                )
                if (diaryNotif) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    SettingsRow(
                        icon = Icons.Filled.AccessTime,
                        iconTint = Color(0xFF2196F3),
                        title = stringResource(R.string.settings_notification_time),
                        trailing = { Text(diaryTime, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) },
                        onClick = { showDiaryTimePicker = true },
                    )
                }

                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))

                SettingsRow(
                    icon = Icons.Filled.Notifications,
                    iconTint = Color(0xFFFF9800),
                    title = stringResource(R.string.settings_task_notifications),
                    subtitle = stringResource(R.string.settings_task_notifications_subtitle),
                    trailing = {
                        Switch(
                            checked = taskNotif,
                            onCheckedChange = { viewModel.setTaskNotifications(it) },
                        )
                    },
                )
                if (taskNotif && Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    SettingsRow(
                        icon = Icons.Filled.Info,
                        iconTint = Color(0xFFFF9800),
                        title = stringResource(R.string.settings_notifications_disabled_message),
                        subtitle = stringResource(R.string.settings_open_settings),
                        onClick = {
                            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            }
                            context.startActivity(intent)
                        },
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Categories Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_categories))

            SettingsCard {
                SettingsRow(
                    icon = Icons.AutoMirrored.Filled.Label,
                    iconTint = Color(0xFF4CAF50),
                    title = stringResource(R.string.settings_manage_categories),
                    subtitle = stringResource(R.string.settings_categories_count, categories.size),
                    onClick = { showCategories = true },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Behaviour Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_behavior))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.CheckCircle,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_auto_complete_subtasks),
                    subtitle = stringResource(R.string.settings_auto_complete_subtasks_subtitle),
                    trailing = {
                        Switch(
                            checked = autoComplete,
                            onCheckedChange = { viewModel.setAutoCompleteWithSubtasks(it) },
                        )
                    },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Star,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_show_welcome_again),
                    subtitle = stringResource(R.string.settings_show_welcome_again_subtitle),
                    onClick = { viewModel.clearHasShownWelcome() },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.GridOn,
                    iconTint = Color(0xFF795548),
                    title = stringResource(R.string.settings_eisenhower),
                    subtitle = stringResource(R.string.settings_eisenhower_subtitle),
                    onClick = { showEisenhower = true },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Support Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_support))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.Feedback,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_feedback),
                    onClick = { showFeedback = true },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Favorite,
                    iconTint = Color(0xFFE91E63),
                    title = stringResource(R.string.settings_donation),
                    onClick = { showDonation = true },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Email,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_contact_support),
                    onClick = {
                        val intent = Intent(Intent.ACTION_SENDTO).apply {
                            data = Uri.parse("mailto:support@snaptask.app")
                            putExtra(Intent.EXTRA_SUBJECT, "SnapTask Android - Support")
                        }
                        if (intent.resolveActivity(context.packageManager) != null) {
                            context.startActivity(Intent.createChooser(intent, context.getString(R.string.settings_contact_support)))
                        }
                    },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Star,
                    iconTint = Color(0xFFFFC107),
                    title = stringResource(R.string.settings_rate_app),
                    subtitle = stringResource(R.string.settings_rate_app_subtitle),
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("market://details?id=com.snaptask.app")
                        }
                        try {
                            context.startActivity(intent)
                        } catch (_: Exception) {
                            context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse("https://play.google.com/store/apps/details?id=com.snaptask.app")
                            })
                        }
                    },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Description,
                    iconTint = Color(0xFF9E9E9E),
                    title = stringResource(R.string.settings_terms),
                    onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("https://snaptask.app/terms")
                        })
                    },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Lock,
                    iconTint = Color(0xFF9E9E9E),
                    title = stringResource(R.string.settings_privacy),
                    onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.parse("https://snaptask.app/privacy")
                        })
                    },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- Data Management Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_data))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.Backup,
                    iconTint = Color(0xFF2196F3),
                    title = stringResource(R.string.settings_backup_restore),
                    subtitle = stringResource(R.string.settings_backup_restore_subtitle),
                    onClick = { showBackupRestore = true },
                )
                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                SettingsRow(
                    icon = Icons.Filled.Delete,
                    iconTint = Color(0xFFF44336),
                    title = stringResource(R.string.settings_delete_all_data),
                    titleColor = Color(0xFFF44336),
                    subtitle = stringResource(R.string.settings_delete_all_data_subtitle),
                    onClick = { showDeleteConfirmation = true },
                    trailing = {
                        if (isDeleting) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        }
                    },
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ---- About Section ----
            SettingsSectionHeader(stringResource(R.string.settings_section_about))

            SettingsCard {
                SettingsRow(
                    icon = Icons.Filled.Info,
                    iconTint = Color(0xFF607D8B),
                    title = stringResource(R.string.settings_app_version),
                    trailing = {
                        Text(
                            viewModel.appVersion,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    },
                )
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    // Categories Sheet
    if (showCategories) {
        ModalBottomSheet(
            onDismissRequest = { showCategories = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            CategoriesScreen(
                viewModel = viewModel,
                onDismiss = { showCategories = false },
            )
        }
    }

    // Themes Sheet
    if (showThemes) {
        ModalBottomSheet(
            onDismissRequest = { showThemes = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            ThemeSelectionScreen(onDismiss = { showThemes = false })
        }
    }

    // Delete confirmation
    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.settings_delete_confirm_title)) },
            text = { Text(stringResource(R.string.settings_delete_confirm_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteAllData()
                        showDeleteConfirmation = false
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color(0xFFF44336)),
                ) { Text(stringResource(R.string.settings_delete_everything)) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }

    // Feedback sheet
    if (showFeedback) {
        ModalBottomSheet(
            onDismissRequest = { showFeedback = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            FeedbackScreen(
                onSubmit = { type, message, email ->
                    val subject = "SnapTask Android - ${type.displayName}"
                    val body = "Type: ${type.displayName}\n\n$message${if (email.isNotBlank()) "\n\nReply to: $email" else ""}"
                    val mailto = "mailto:support@snaptask.app?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}"
                    val intent = Intent(Intent.ACTION_SENDTO).apply { data = Uri.parse(mailto) }
                    if (intent.resolveActivity(context.packageManager) != null) {
                        context.startActivity(Intent.createChooser(intent, "Send feedback"))
                    }
                },
                onDismiss = { showFeedback = false },
            )
        }
    }

    // Donation sheet
    if (showDonation) {
        ModalBottomSheet(
            onDismissRequest = { showDonation = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            DonationScreen(
                onDonate = { _ -> showDonation = false },
                onDismiss = { showDonation = false },
            )
        }
    }

    // Language selection sheet
    if (showLanguage) {
        ModalBottomSheet(
            onDismissRequest = { showLanguage = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            LanguageSelectionScreen(
                viewModel = viewModel,
                onDismiss = { showLanguage = false },
            )
        }
    }

    // Eisenhower settings sheet
    if (showEisenhower) {
        ModalBottomSheet(
            onDismissRequest = { showEisenhower = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            EisenhowerSettingsScreen(
                viewModel = viewModel,
                onDismiss = { showEisenhower = false },
            )
        }
    }

    // Backup & Restore sheet
    if (showBackupRestore) {
        ModalBottomSheet(
            onDismissRequest = {
                showBackupRestore = false
                viewModel.clearBackupRestoreResult()
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            BackupRestoreScreen(
                viewModel = viewModel,
                onDismiss = { showBackupRestore = false },
            )
        }
    }

    // Time picker for Daily Quote notification (simple dialog: hour/minute)
    if (showQuoteTimePicker) {
        val (initHour, initMinute) = parseTimeString(dailyQuoteTime)
        var hour by remember { mutableStateOf(initHour) }
        var minute by remember { mutableStateOf(initMinute) }
        AlertDialog(
            onDismissRequest = { showQuoteTimePicker = false },
            title = { Text(stringResource(R.string.settings_notification_time)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(R.string.settings_daily_quote_reminder) + ": ${formatTime(hour, minute)}", style = MaterialTheme.typography.bodyMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column {
                            Text("Hour", style = MaterialTheme.typography.labelSmall)
                            Slider(value = hour.toFloat(), onValueChange = { hour = it.toInt().coerceIn(0, 23) }, valueRange = 0f..23f, steps = 22)
                            Text("$hour", style = MaterialTheme.typography.bodySmall)
                        }
                        Column {
                            Text("Minute", style = MaterialTheme.typography.labelSmall)
                            Slider(value = minute.toFloat(), onValueChange = { minute = it.toInt().coerceIn(0, 59) }, valueRange = 0f..59f, steps = 58)
                            Text("$minute", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.setDailyQuoteNotificationTime(formatTime(hour, minute))
                    showQuoteTimePicker = false
                }) { Text(stringResource(R.string.action_save)) }
            },
            dismissButton = {
                TextButton(onClick = { showQuoteTimePicker = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }

    // Time picker for Diary notification
    if (showDiaryTimePicker) {
        val (initHour, initMinute) = parseTimeString(diaryTime)
        var hour by remember { mutableStateOf(initHour) }
        var minute by remember { mutableStateOf(initMinute) }
        AlertDialog(
            onDismissRequest = { showDiaryTimePicker = false },
            title = { Text(stringResource(R.string.settings_notification_time)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(stringResource(R.string.settings_diary_reminder) + ": ${formatTime(hour, minute)}", style = MaterialTheme.typography.bodyMedium)
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column {
                            Text("Hour", style = MaterialTheme.typography.labelSmall)
                            Slider(value = hour.toFloat(), onValueChange = { hour = it.toInt().coerceIn(0, 23) }, valueRange = 0f..23f, steps = 22)
                            Text("$hour", style = MaterialTheme.typography.bodySmall)
                        }
                        Column {
                            Text("Minute", style = MaterialTheme.typography.labelSmall)
                            Slider(value = minute.toFloat(), onValueChange = { minute = it.toInt().coerceIn(0, 59) }, valueRange = 0f..59f, steps = 58)
                            Text("$minute", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.setDiaryNotificationTime(formatTime(hour, minute))
                    showDiaryTimePicker = false
                }) { Text(stringResource(R.string.action_save)) }
            },
            dismissButton = {
                TextButton(onClick = { showDiaryTimePicker = false }) { Text(stringResource(R.string.action_cancel)) }
            },
        )
    }
}

private fun parseTimeString(timeStr: String): Pair<Int, Int> {
    val parts = timeStr.split(":")
    val hour = parts.getOrNull(0)?.toIntOrNull() ?: 9
    val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
    return Pair(hour.coerceIn(0, 23), minute.coerceIn(0, 59))
}

private fun formatTime(hour: Int, minute: Int): String {
    return "%02d:%02d".format(hour.coerceIn(0, 23), minute.coerceIn(0, 59))
}

// ---- Reusable Components ----

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        title.uppercase(),
        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, bottom = 8.dp),
    )
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(vertical = 4.dp)) {
            content()
        }
    }
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    titleColor: Color = MaterialTheme.colorScheme.onSurface,
    subtitle: String? = null,
    onClick: (() -> Unit)? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(24.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                style = MaterialTheme.typography.bodyMedium,
                color = titleColor,
            )
            if (subtitle != null) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (trailing != null) {
            Spacer(modifier = Modifier.width(8.dp))
            trailing()
        } else if (onClick != null) {
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
