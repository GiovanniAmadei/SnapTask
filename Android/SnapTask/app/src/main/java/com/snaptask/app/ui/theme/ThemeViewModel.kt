package com.snaptask.app.ui.theme

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.local.SnapTaskPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** A single source of truth for the app-wide theme and appearance setting. */
@HiltViewModel
class ThemeViewModel @Inject constructor(
    private val preferences: SnapTaskPreferences,
) : ViewModel() {
    val appTheme: StateFlow<AppTheme> = preferences.appTheme.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        AppTheme.defaultTheme,
    )
    val appearanceMode: StateFlow<String> = preferences.appearanceMode.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        "system",
    )

    fun selectTheme(theme: AppTheme) {
        viewModelScope.launch { preferences.setTheme(theme) }
    }
}
