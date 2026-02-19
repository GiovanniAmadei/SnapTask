package com.snaptask.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.snaptask.app.ui.SnapTaskMainScreen
import com.snaptask.app.ui.onboarding.WelcomeScreen
import com.snaptask.app.ui.theme.SnapTaskTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val prefs = getSharedPreferences("snaptask_settings", Context.MODE_PRIVATE)
        setContent {
            SnapTaskTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    var showWelcome by remember {
                        mutableStateOf(!prefs.getBoolean("hasShownWelcome", false))
                    }
                    if (showWelcome) {
                        WelcomeScreen(
                            onComplete = {
                                prefs.edit().putBoolean("hasShownWelcome", true).apply()
                                showWelcome = false
                            },
                        )
                    } else {
                        SnapTaskMainScreen()
                    }
                }
            }
        }
    }
}
