package com.snaptask.app.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/**
 * Enum of available app themes, matching the iOS ThemeManager themes.
 */
enum class AppTheme(val displayName: String) {
    DEFAULT("Default"),
    DARK("Dark"),
    MIDNIGHT("Midnight"),
    OCEAN("Ocean"),
    FOREST("Forest"),
    SUNSET("Sunset"),
    SYSTEM("System");

    val isDark: Boolean
        get() = this != DEFAULT

    fun toColorScheme(): ColorScheme = when (this) {
        DEFAULT -> lightColorScheme(
            primary = DefaultPrimary,
            onPrimary = DefaultOnPrimary,
            primaryContainer = DefaultPrimaryContainer,
            onPrimaryContainer = DefaultOnPrimaryContainer,
            secondary = DefaultSecondary,
            onSecondary = DefaultOnSecondary,
            secondaryContainer = DefaultSecondaryContainer,
            onSecondaryContainer = DefaultOnSecondaryContainer,
            tertiary = DefaultTertiary,
            onTertiary = DefaultOnTertiary,
            tertiaryContainer = DefaultTertiaryContainer,
            onTertiaryContainer = DefaultOnTertiaryContainer,
            background = DefaultBackground,
            onBackground = DefaultOnBackground,
            surface = DefaultSurface,
            onSurface = DefaultOnSurface,
            surfaceVariant = DefaultSurfaceVariant,
            onSurfaceVariant = DefaultOnSurfaceVariant,
            outline = DefaultOutline,
            error = DefaultError,
            onError = DefaultOnError,
        )
        DARK -> darkColorScheme(
            primary = DarkPrimary,
            onPrimary = DarkOnPrimary,
            primaryContainer = DarkPrimaryContainer,
            onPrimaryContainer = DarkOnPrimaryContainer,
            secondary = DarkSecondary,
            onSecondary = DarkOnSecondary,
            secondaryContainer = DarkSecondaryContainer,
            onSecondaryContainer = DarkOnSecondaryContainer,
            tertiary = DarkTertiary,
            onTertiary = DarkOnTertiary,
            tertiaryContainer = DarkTertiaryContainer,
            onTertiaryContainer = DarkOnTertiaryContainer,
            background = DarkBackground,
            onBackground = DarkOnBackground,
            surface = DarkSurface,
            onSurface = DarkOnSurface,
            surfaceVariant = DarkSurfaceVariant,
            onSurfaceVariant = DarkOnSurfaceVariant,
            outline = DarkOutline,
            error = DarkError,
            onError = DarkOnError,
        )
        MIDNIGHT -> darkColorScheme(
            primary = MidnightPrimary,
            onPrimary = Color.White,
            primaryContainer = MidnightPrimary.copy(alpha = 0.3f),
            onPrimaryContainer = Color.White,
            secondary = DarkSecondary,
            onSecondary = Color.White,
            background = MidnightBackground,
            onBackground = MidnightOnBackground,
            surface = MidnightSurface,
            onSurface = MidnightOnSurface,
            surfaceVariant = MidnightSurfaceVariant,
            onSurfaceVariant = DarkOnSurfaceVariant,
            outline = DarkOutline,
        )
        OCEAN -> darkColorScheme(
            primary = OceanPrimary,
            onPrimary = Color.Black,
            primaryContainer = OceanPrimary.copy(alpha = 0.3f),
            onPrimaryContainer = OceanOnSurface,
            secondary = OceanSecondary,
            onSecondary = Color.Black,
            background = OceanBackground,
            onBackground = OceanOnBackground,
            surface = OceanSurface,
            onSurface = OceanOnSurface,
            surfaceVariant = OceanSurfaceVariant,
            onSurfaceVariant = DarkOnSurfaceVariant,
            outline = DarkOutline,
        )
        FOREST -> darkColorScheme(
            primary = ForestPrimary,
            onPrimary = Color.Black,
            primaryContainer = ForestPrimary.copy(alpha = 0.3f),
            onPrimaryContainer = ForestOnSurface,
            secondary = ForestSecondary,
            onSecondary = Color.Black,
            background = ForestBackground,
            onBackground = ForestOnBackground,
            surface = ForestSurface,
            onSurface = ForestOnSurface,
            surfaceVariant = ForestSurfaceVariant,
            onSurfaceVariant = DarkOnSurfaceVariant,
            outline = DarkOutline,
        )
        SUNSET -> darkColorScheme(
            primary = SunsetPrimary,
            onPrimary = Color.Black,
            primaryContainer = SunsetPrimary.copy(alpha = 0.3f),
            onPrimaryContainer = SunsetOnSurface,
            secondary = SunsetSecondary,
            onSecondary = Color.Black,
            background = SunsetBackground,
            onBackground = SunsetOnBackground,
            surface = SunsetSurface,
            onSurface = SunsetOnSurface,
            surfaceVariant = SunsetSurfaceVariant,
            onSurfaceVariant = DarkOnSurfaceVariant,
            outline = DarkOutline,
        )
        SYSTEM -> lightColorScheme() // Handled dynamically in Theme.kt
    }
}
