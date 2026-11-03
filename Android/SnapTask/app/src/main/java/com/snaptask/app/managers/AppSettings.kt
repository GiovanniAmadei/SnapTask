package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** The settings `CloudKitSettingsManager` holds on iOS, on this device only until sync exists. */
object AppSettings {
    private fun boolState(key: String, default: Boolean) = lazy { mutableStateOf(if (Defaults.contains(key)) Defaults.bool(key) else default) }
    private val hideDaysBarState by boolState("hideDaysBar", false)
    private val confettiState by boolState("enableConfettiCelebration", false)
    private val hapticState by boolState("enableHapticFeedback", true)
    private val showCompletedState by boolState("showCompletedTasks", true)

    var hideDaysBar: Boolean
        get() = hideDaysBarState.value
        set(value) { hideDaysBarState.value = value; Defaults.set("hideDaysBar", value) }
    var enableConfettiCelebration: Boolean
        get() = confettiState.value
        set(value) { confettiState.value = value; Defaults.set("enableConfettiCelebration", value) }
    var enableHapticFeedback: Boolean
        get() = hapticState.value
        set(value) { hapticState.value = value; Defaults.set("enableHapticFeedback", value) }
    var showCompletedTasks: Boolean
        get() = showCompletedState.value
        set(value) { showCompletedState.value = value; Defaults.set("showCompletedTasks", value) }
}
