package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.Locale

data class Language(val code: String, val name: String)

object LanguageManager {
    private val supported = setOf("en", "it", "es", "fr", "pt", "de", "ja")
    private val baseLanguages = listOf(
        Language("system", "System"),
        Language("en", "English"),
        Language("it", "Italiano"),
        Language("es", "Español"),
        Language("fr", "Français"),
        Language("pt", "Português (Brasil)"),
        Language("de", "Deutsch"),
        Language("ja", "日本語"),
    )

    private var useSystemLanguage by mutableStateOf(true)
    private var selectedLanguageCode by mutableStateOf("")
    private var loaded = false

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        useSystemLanguage = Defaults.bool("useSystemLanguage", true)
        selectedLanguageCode = Defaults.string("selectedLanguage") ?: ""
    }

    val localizedLanguages: List<Language>
        get() = baseLanguages.map { language ->
            val name = when (language.code) {
                "system" -> "system".localized
                "en" -> "english".localized
                "it" -> "italiano".localized
                "es" -> "español".localized
                "fr" -> "français".localized
                "pt" -> "Português".localized
                "de" -> "deutsch".localized
                "ja" -> "日本語".localized
                else -> language.name
            }
            Language(language.code, name)
        }

    val currentLanguage: Language
        get() {
            ensureLoaded()
            val languages = localizedLanguages
            return if (useSystemLanguage) languages.first { it.code == "system" }
            else languages.firstOrNull { it.code == selectedLanguageCode } ?: languages[0]
        }

    val actualLanguageCode: String
        get() {
            ensureLoaded()
            if (!useSystemLanguage) return selectedLanguageCode.ifEmpty { "en" }
            val system = Locale.getDefault().language
            return if (system in supported) system else "en"
        }

    fun setLanguage(code: String) {
        ensureLoaded()
        if (code == "system") {
            useSystemLanguage = true
            selectedLanguageCode = ""
        } else {
            if (baseLanguages.none { it.code == code }) return
            useSystemLanguage = false
            selectedLanguageCode = code
        }
        Defaults.set("useSystemLanguage", useSystemLanguage)
        Defaults.set("selectedLanguage", selectedLanguageCode)
        AppShortcuts.publish(App.context)
        WidgetRefresher.request()
    }
}

/** How clock times are displayed (12h / 24h / follow the system). */
enum class TimeFormatPreference(val rawValue: String) {
    system("system"),
    twelveHour("12h"),
    twentyFourHour("24h");

    val localizedName: String
        get() = when (this) {
            system -> "system".localized
            twelveHour -> "time_format_12h".localized
            twentyFourHour -> "time_format_24h".localized
        }

    companion object {
        const val storageKey = "timeFormatPreference"
        val current: TimeFormatPreference
            get() = entries.firstOrNull { it.rawValue == Defaults.string(storageKey) } ?: system

        val uses12HourClock: Boolean
            get() = when (current) {
                twelveHour -> true
                twentyFourHour -> false
                system -> !android.text.format.DateFormat.is24HourFormat(App.context)
            }

        /** Hours and minutes, e.g. "14:30" or "2:30 PM". */
        fun format(date: Instant): String =
            DateTimeFormatter.ofPattern(if (uses12HourClock) "h:mm a" else "HH:mm", appLocale).format(date.z())

        /** Hour only, e.g. "14" or "2 PM". */
        fun hour(date: Instant): String =
            DateTimeFormatter.ofPattern(if (uses12HourClock) "h a" else "HH", appLocale).format(date.z())

        fun range(start: Instant, end: Instant): String = "${format(start)} – ${format(end)}"

        /** "14:00" on a 24h clock, "2 PM" on a 12h clock. */
        fun hourLabel(hour: Int): String {
            val date = now().withTime(hour, 0)
            return if (uses12HourClock) hour(date) else format(date)
        }
    }
}
