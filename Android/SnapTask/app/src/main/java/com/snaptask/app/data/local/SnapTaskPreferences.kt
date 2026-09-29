package com.snaptask.app.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.snaptask.app.data.model.FinanceSettingsState
import com.snaptask.app.data.model.TaskTimeScope
import com.snaptask.app.ui.theme.AppTheme
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * DataStore-based preferences for app settings.
 * Replaces iOS UserDefaults usage.
 */
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "snaptask_prefs")

object PreferencesKeys {
    val THEME = stringPreferencesKey("app_theme")
    val APPEARANCE_MODE = stringPreferencesKey("appearance_mode")
    val LANGUAGE = stringPreferencesKey("app_language")
    val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
    val POMODORO_WORK_DURATION = intPreferencesKey("pomodoro_work_duration")
    val POMODORO_BREAK_DURATION = intPreferencesKey("pomodoro_break_duration")
    val POMODORO_LONG_BREAK = intPreferencesKey("pomodoro_long_break")
    val POMODORO_SESSIONS = intPreferencesKey("pomodoro_sessions")
    val TOTAL_POINTS = intPreferencesKey("total_points")
    val FIRST_LAUNCH = booleanPreferencesKey("first_launch")
    val SELECTED_SCOPE = stringPreferencesKey("selected_scope")
    val LAST_SYNC_DATE = longPreferencesKey("last_sync_date")
    val CALENDAR_SYNC_ENABLED = booleanPreferencesKey("calendar_sync_enabled")
    val HAPTIC_FEEDBACK_ENABLED = booleanPreferencesKey("haptic_feedback_enabled")
    val FINANCE_SETTINGS = stringPreferencesKey("finance_settings")
}

class SnapTaskPreferences(private val context: Context) {
    private val gson = Gson()

    val appTheme: Flow<AppTheme> = context.dataStore.data.map { prefs ->
        AppTheme.fromStorage(prefs[PreferencesKeys.THEME])
    }

    val appearanceMode: Flow<String> = context.dataStore.data.map { prefs ->
        prefs[PreferencesKeys.APPEARANCE_MODE] ?: "system"
    }

    val notificationsEnabled: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[PreferencesKeys.NOTIFICATIONS_ENABLED] ?: true
    }

    val totalPoints: Flow<Int> = context.dataStore.data.map { prefs ->
        prefs[PreferencesKeys.TOTAL_POINTS] ?: 0
    }

    val isFirstLaunch: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[PreferencesKeys.FIRST_LAUNCH] ?: true
    }

    val selectedScope: Flow<TaskTimeScope> = context.dataStore.data.map { prefs ->
        val scopeStr = prefs[PreferencesKeys.SELECTED_SCOPE] ?: TaskTimeScope.TODAY.value
        TaskTimeScope.fromString(scopeStr)
    }

    val financeSettings: Flow<FinanceSettingsState> = context.dataStore.data.map { prefs ->
        prefs[PreferencesKeys.FINANCE_SETTINGS]
            ?.let { json -> runCatching { gson.fromJson(json, FinanceSettingsState::class.java) }.getOrNull() }
            ?: FinanceSettingsState()
    }

    suspend fun setTheme(theme: AppTheme) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.THEME] = theme.storageKey
        }
    }

    suspend fun setAppearanceMode(mode: String) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.APPEARANCE_MODE] = mode
        }
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.NOTIFICATIONS_ENABLED] = enabled
        }
    }

    suspend fun setTotalPoints(points: Int) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.TOTAL_POINTS] = points
        }
    }

    suspend fun addPoints(points: Int) {
        context.dataStore.edit { prefs ->
            val current = prefs[PreferencesKeys.TOTAL_POINTS] ?: 0
            prefs[PreferencesKeys.TOTAL_POINTS] = current + points
        }
    }

    suspend fun setFirstLaunchComplete() {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.FIRST_LAUNCH] = false
        }
    }

    suspend fun setSelectedScope(scope: TaskTimeScope) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.SELECTED_SCOPE] = scope.value
        }
    }

    suspend fun setFinanceSettings(settings: FinanceSettingsState) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.FINANCE_SETTINGS] = gson.toJson(settings)
        }
    }
}
