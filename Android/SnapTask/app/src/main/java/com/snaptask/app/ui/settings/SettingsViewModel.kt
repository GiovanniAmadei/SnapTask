package com.snaptask.app.ui.settings

import android.content.Context
import android.content.SharedPreferences
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.snaptask.app.data.model.Category
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.data.repository.TaskRepository
import com.snaptask.app.data.local.SnapTaskPreferences
import com.snaptask.app.notifications.TaskNotificationScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.launch
import java.lang.reflect.Type
import java.util.Date
import java.util.UUID
import javax.inject.Inject

/**
 * SettingsViewModel matching iOS SettingsViewModel.
 * Manages categories, appearance preferences, and app settings
 * using SharedPreferences for simple values and Room for categories.
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
    private val taskNotificationScheduler: TaskNotificationScheduler,
    private val snapTaskPreferences: SnapTaskPreferences,
    @ApplicationContext private val context: Context,
) : ViewModel() {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("snaptask_settings", Context.MODE_PRIVATE)

    // ---- Categories ----
    val categories: StateFlow<List<Category>> = taskRepository.allCategories
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun addCategory(category: Category) {
        viewModelScope.launch { taskRepository.addCategory(category) }
    }

    fun updateCategory(category: Category) {
        viewModelScope.launch { taskRepository.updateCategory(category) }
    }

    fun deleteCategory(categoryId: UUID) {
        viewModelScope.launch { taskRepository.deleteCategory(categoryId) }
    }

    // ---- Appearance ----

    /** "system", "light", or "dark" */
    val appearanceMode: StateFlow<String> = snapTaskPreferences.appearanceMode.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        "system",
    )

    fun setAppearanceMode(mode: String) {
        viewModelScope.launch { snapTaskPreferences.setAppearanceMode(mode) }
    }

    // ---- Language ----
    private val _selectedLanguageCode = MutableStateFlow(prefs.getString("selectedLanguageCode", "system") ?: "system")
    val selectedLanguageCode: StateFlow<String> = _selectedLanguageCode.asStateFlow()

    fun setLanguage(code: String) {
        _selectedLanguageCode.value = code
        prefs.edit().putString("selectedLanguageCode", code).apply()
        val localeTag = if (code == "system") "" else code
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(localeTag))
    }

    // ---- Show Category Gradients ----
    private val _showCategoryGradients = MutableStateFlow(prefs.getBoolean("showCategoryGradients", true))
    val showCategoryGradients: StateFlow<Boolean> = _showCategoryGradients.asStateFlow()

    fun setShowCategoryGradients(enabled: Boolean) {
        _showCategoryGradients.value = enabled
        prefs.edit().putBoolean("showCategoryGradients", enabled).apply()
    }

    // ---- Auto-Complete Task With Subtasks ----
    private val _autoCompleteWithSubtasks = MutableStateFlow(prefs.getBoolean("autoCompleteTaskWithSubtasks", true))
    val autoCompleteWithSubtasks: StateFlow<Boolean> = _autoCompleteWithSubtasks.asStateFlow()

    fun setAutoCompleteWithSubtasks(enabled: Boolean) {
        _autoCompleteWithSubtasks.value = enabled
        prefs.edit().putBoolean("autoCompleteTaskWithSubtasks", enabled).apply()
    }

    // ---- Notifications ----
    private val _dailyQuoteNotificationsEnabled = MutableStateFlow(prefs.getBoolean("dailyQuoteNotificationsEnabled", false))
    val dailyQuoteNotificationsEnabled: StateFlow<Boolean> = _dailyQuoteNotificationsEnabled.asStateFlow()

    fun setDailyQuoteNotifications(enabled: Boolean) {
        _dailyQuoteNotificationsEnabled.value = enabled
        prefs.edit().putBoolean("dailyQuoteNotificationsEnabled", enabled).apply()
    }

    private val _dailyQuoteNotificationTime = MutableStateFlow(prefs.getString("dailyQuoteNotificationTime", "09:00") ?: "09:00")
    val dailyQuoteNotificationTime: StateFlow<String> = _dailyQuoteNotificationTime.asStateFlow()

    fun setDailyQuoteNotificationTime(time: String) {
        _dailyQuoteNotificationTime.value = time
        prefs.edit().putString("dailyQuoteNotificationTime", time).apply()
    }

    private val _diaryNotificationsEnabled = MutableStateFlow(prefs.getBoolean("diaryNotificationsEnabled", false))
    val diaryNotificationsEnabled: StateFlow<Boolean> = _diaryNotificationsEnabled.asStateFlow()

    fun setDiaryNotifications(enabled: Boolean) {
        _diaryNotificationsEnabled.value = enabled
        prefs.edit().putBoolean("diaryNotificationsEnabled", enabled).apply()
    }

    private val _diaryNotificationTime = MutableStateFlow(prefs.getString("diaryNotificationTime", "20:00") ?: "20:00")
    val diaryNotificationTime: StateFlow<String> = _diaryNotificationTime.asStateFlow()

    fun setDiaryNotificationTime(time: String) {
        _diaryNotificationTime.value = time
        prefs.edit().putString("diaryNotificationTime", time).apply()
    }

    private val _taskNotificationsEnabled = MutableStateFlow(prefs.getBoolean("taskNotificationsEnabled", true))
    val taskNotificationsEnabled: StateFlow<Boolean> = _taskNotificationsEnabled.asStateFlow()

    fun setTaskNotifications(enabled: Boolean) {
        _taskNotificationsEnabled.value = enabled
        prefs.edit().putBoolean("taskNotificationsEnabled", enabled).apply()
    }

    // ---- Eisenhower Settings ----
    private val _eisenhowerTodayUrgentHours = MutableStateFlow(prefs.getInt("eisenhowerTodayUrgentHours", 4))
    val eisenhowerTodayUrgentHours: StateFlow<Int> = _eisenhowerTodayUrgentHours.asStateFlow()

    fun setEisenhowerTodayUrgentHours(hours: Int) {
        _eisenhowerTodayUrgentHours.value = hours
        prefs.edit().putInt("eisenhowerTodayUrgentHours", hours).apply()
    }

    // ---- Data Management ----
    private val _isDeleting = MutableStateFlow(false)
    val isDeleting: StateFlow<Boolean> = _isDeleting.asStateFlow()

    fun deleteAllData() {
        viewModelScope.launch {
            _isDeleting.value = true
            taskRepository.deleteAllTasks()
            categories.value.forEach { category ->
                taskRepository.deleteCategory(category.id)
            }
            _isDeleting.value = false
        }
    }

    // ---- Welcome (Show welcome again) ----
    fun setHasShownWelcome(value: Boolean) {
        prefs.edit().putBoolean("hasShownWelcome", value).apply()
    }

    fun clearHasShownWelcome() {
        prefs.edit().putBoolean("hasShownWelcome", false).apply()
    }

    // ---- App Version ----
    val appVersion: String
        get() {
            return try {
                val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                "${pInfo.versionName} (${pInfo.longVersionCode})"
            } catch (e: Exception) {
                "Unknown"
            }
        }

    // ---- Backup & Restore ----
    private val _backupExportJson = MutableStateFlow<String?>(null)
    val backupExportJson: StateFlow<String?> = _backupExportJson.asStateFlow()

    private val _backupRestoreResult = MutableStateFlow<Result<Unit>?>(null)
    val backupRestoreResult: StateFlow<Result<Unit>?> = _backupRestoreResult.asStateFlow()

    private val backupGson by lazy {
        GsonBuilder()
            .registerTypeAdapter(Date::class.java, object : JsonSerializer<Date>, JsonDeserializer<Date> {
                override fun serialize(src: Date?, typeOfSrc: Type?, context: JsonSerializationContext?) =
                    JsonPrimitive(src?.time)
                override fun deserialize(json: JsonElement?, typeOfT: Type?, context: JsonDeserializationContext?) =
                    json?.takeIf { it.isJsonPrimitive }?.asLong?.let { Date(it) }
            })
            .registerTypeAdapter(UUID::class.java, object : JsonSerializer<UUID>, JsonDeserializer<UUID> {
                override fun serialize(src: UUID?, typeOfSrc: Type?, context: JsonSerializationContext?) =
                    JsonPrimitive(src?.toString())
                override fun deserialize(json: JsonElement?, typeOfT: Type?, context: JsonDeserializationContext?) =
                    json?.takeIf { it.isJsonPrimitive }?.asString?.let { UUID.fromString(it) }
            })
            .create()
    }

    fun exportBackup() {
        viewModelScope.launch {
            try {
                val tasks = taskRepository.allTasks.first()
                val categoriesList = taskRepository.allCategories.first()
                val backup = BackupData(version = 1, tasks = tasks, categories = categoriesList)
                _backupExportJson.value = backupGson.toJson(backup)
            } catch (e: Exception) {
                _backupExportJson.value = null
            }
        }
    }

    fun clearBackupExport() {
        _backupExportJson.value = null
    }

    fun restoreFromBackup(json: String) {
        viewModelScope.launch {
            _backupRestoreResult.value = runCatching {
                val backup = backupGson.fromJson(json, BackupData::class.java)
                    ?: throw IllegalArgumentException("Invalid backup format")
                val existingCategories = taskRepository.allCategories.first()
                taskRepository.deleteAllTasks()
                existingCategories.forEach { taskRepository.deleteCategory(it.id) }
                backup.categories.forEach { taskRepository.addCategory(it) }
                backup.tasks.forEach { task ->
                    taskRepository.addTask(task)
                    taskNotificationScheduler.scheduleReminder(task)
                }
            }
        }
    }

    fun clearBackupRestoreResult() {
        _backupRestoreResult.value = null
    }
}
