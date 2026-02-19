package com.snaptask.app

import android.app.Application
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class SnapTaskApp : Application() {
    override fun onCreate() {
        super.onCreate()
        applySavedLanguage()
    }

    private fun applySavedLanguage() {
        val prefs = getSharedPreferences("snaptask_settings", MODE_PRIVATE)
        val code = prefs.getString("selectedLanguageCode", "system") ?: "system"
        val localeTag = if (code == "system") "" else code
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(localeTag))
    }
}
