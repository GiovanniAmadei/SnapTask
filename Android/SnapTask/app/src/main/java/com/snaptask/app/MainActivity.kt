package com.snaptask.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import java.util.UUID

/** What other parts of the app ask the main screen to do (the `NotificationCenter` posts of iOS). */
object AppEvents {
    var openTaskId by mutableStateOf<UUID?>(null)
    var openJournalDate by mutableStateOf<Date?>(null)
    var openFeedbackId by mutableStateOf<UUID?>(null)
    var openQuickAdd by mutableStateOf(0)
    var selectTab by mutableStateOf<Int?>(null)
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CurrentActivity.activity = this
        handle(intent)
        setContent {
            AppTheme {
                val theme = LocalTheme.current
                val view = LocalView.current
                LaunchedEffect(view) { Haptics.view = view }
                // Premium themes decide light or dark; the others follow the system or the setting.
                LaunchedEffect(theme.isDark) {
                    val transparent = android.graphics.Color.TRANSPARENT
                    val style = if (theme.isDark) SystemBarStyle.dark(transparent) else SystemBarStyle.light(transparent, transparent)
                    enableEdgeToEdge(style, style)
                }
                val presenter = remember { Presenter() }
                CompositionLocalProvider(LocalPresenter provides presenter) {
                    presenter.Host {
                        Box(Modifier.fillMaxSize()) {
                            ContentView()
                            ConfettiOverlay()
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
    }

    override fun onDestroy() {
        if (CurrentActivity.activity === this) CurrentActivity.activity = null
        super.onDestroy()
    }

    private fun handle(intent: Intent?) {
        intent ?: return
        intent.getStringExtra("openTaskId")?.let { id ->
            runCatching { AppEvents.openTaskId = UUID.fromString(id) }
        }
        intent.getStringExtra("openJournalDate")?.let { day ->
            runCatching { AppEvents.openJournalDate = java.time.LocalDate.parse(day).instant() }
        }
        intent.getStringExtra("openFeedbackId")?.let { id ->
            runCatching { AppEvents.openFeedbackId = UUID.fromString(id) }
        }
        if (intent.getIntExtra("openTab", -1) >= 0) AppEvents.selectTab = intent.getIntExtra("openTab", 0)
        if (intent.data?.scheme == "snaptask" && intent.data?.host == "quickadd" || intent.getBooleanExtra("quickAdd", false)) {
            AppEvents.selectTab = 0
            AppEvents.openQuickAdd++
        }
    }
}

object CurrentActivity {
    var activity: ComponentActivity? = null
}
