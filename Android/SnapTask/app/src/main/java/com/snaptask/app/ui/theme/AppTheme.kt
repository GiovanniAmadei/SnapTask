package com.snaptask.app.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/**
 * The same theme catalogue exposed by ThemeManager on iOS.
 *
 * iOS keeps Default, Forest and Sunset tied to the system appearance.  The
 * other themes provide their own light or dark surfaces, so we do the same
 * here instead of treating every accent colour as a dark Material theme.
 */
enum class AppTheme(
    val storageKey: String,
    val displayName: String,
    val isPremium: Boolean,
    private val primary: Color,
    private val secondary: Color,
    private val forcedSurface: ThemeSurface? = null,
) {
    DEFAULT("default", "Default", false, Color(0xFF007AFF), Color(0xFF32ADE6)),
    FOREST("forest", "Forest", false, Color(0xFF34C759), Color(0xFF00C7BE)),
    SUNSET("sunset", "Sunset", false, Color(0xFFFF9F0A), Color(0xFFFF375F)),
    MIDNIGHT(
        "midnight", "Midnight", true, Color(0xFF8033CC), Color(0xFF4D3380),
        ThemeSurface(Color(0xFF0D0D1A), Color(0xFF262633), Color.White, Color(0xFFE6E6F2)),
    ),
    ROSE_GOLD(
        "rose_gold", "Rose Gold", true, Color(0xFFFF2D55), Color(0xFFE6B380),
        ThemeSurface(Color(0xFFFAF2EB), Color(0xFFF2EBE0), Color.Black, Color(0xFF666666)),
    ),
    OCEAN(
        "ocean", "Ocean", true, Color(0xFF007AFF), Color(0xFF00A6A6),
        ThemeSurface(Color(0xFFE6F2FA), Color(0xFFD9EBF5), Color.Black, Color(0xFF336699)),
    ),
    EMERALD(
        "emerald", "Emerald", true, Color(0xFF34C759), Color(0xFF33CC99),
        ThemeSurface(Color(0xFFEBFAF2), Color(0xFFE0F2EB), Color.Black, Color(0xFF1A804D)),
    ),
    VOLCANIC(
        "volcanic", "Volcanic", true, Color(0xFFFF3B30), Color(0xFFFF9F0A),
        ThemeSurface(Color(0xFF261A1A), Color(0xFF332626), Color.White, Color(0xFFE6B3B3)),
    ),
    LAVENDER(
        "lavender", "Lavender", true, Color(0xFFAF52DE), Color(0xFFCCB3E6),
        ThemeSurface(Color(0xFFF5F0FA), Color(0xFFEBE0F5), Color.Black, Color(0xFF664D99)),
    );

    val accent: Color get() = primary
    val gradientColors: List<Color> get() = listOf(primary, secondary)
    val followsSystemAppearance: Boolean get() = forcedSurface == null

    fun colorScheme(systemIsDark: Boolean): ColorScheme {
        val surface = forcedSurface ?: if (systemIsDark) IOSDarkSurface else IOSLightSurface
        return if (surface.isDark) {
            darkColorScheme(
                primary = primary,
                onPrimary = if (primary.luminance() < 0.5f) Color.White else Color.Black,
                primaryContainer = primary.copy(alpha = 0.30f),
                onPrimaryContainer = surface.onSurface,
                secondary = secondary,
                onSecondary = if (secondary.luminance() < 0.5f) Color.White else Color.Black,
                secondaryContainer = secondary.copy(alpha = 0.28f),
                onSecondaryContainer = surface.onSurface,
                tertiary = secondary,
                onTertiary = if (secondary.luminance() < 0.5f) Color.White else Color.Black,
                background = surface.background,
                onBackground = surface.onSurface,
                surface = surface.surface,
                onSurface = surface.onSurface,
                surfaceVariant = surface.surface,
                onSurfaceVariant = surface.secondaryText,
                outline = primary.copy(alpha = 0.35f),
                outlineVariant = primary.copy(alpha = 0.18f),
                error = Color(0xFFFF453A),
                onError = Color.Black,
            )
        } else {
            lightColorScheme(
                primary = primary,
                onPrimary = if (primary.luminance() < 0.5f) Color.White else Color.Black,
                primaryContainer = primary.copy(alpha = 0.16f),
                onPrimaryContainer = primary,
                secondary = secondary,
                onSecondary = if (secondary.luminance() < 0.5f) Color.White else Color.Black,
                secondaryContainer = secondary.copy(alpha = 0.16f),
                onSecondaryContainer = secondary,
                tertiary = secondary,
                onTertiary = if (secondary.luminance() < 0.5f) Color.White else Color.Black,
                background = surface.background,
                onBackground = surface.onSurface,
                surface = surface.surface,
                onSurface = surface.onSurface,
                surfaceVariant = surface.surface,
                onSurfaceVariant = surface.secondaryText,
                outline = primary.copy(alpha = 0.30f),
                outlineVariant = primary.copy(alpha = 0.16f),
                error = Color(0xFFFF3B30),
                onError = Color.White,
            )
        }
    }

    companion object {
        val defaultTheme = SUNSET
        val freeThemes = entries.filterNot { it.isPremium }
        val premiumThemes = entries.filter { it.isPremium }

        fun fromStorage(value: String?): AppTheme = entries.firstOrNull {
            it.name == value || it.storageKey == value
        } ?: defaultTheme
    }
}

private data class ThemeSurface(
    val background: Color,
    val surface: Color,
    val onSurface: Color,
    val secondaryText: Color,
) {
    val isDark: Boolean get() = background.luminance() < 0.5f
}

private val IOSLightSurface = ThemeSurface(
    background = Color(0xFFFFFFFF),
    surface = Color(0xFFF2F2F7),
    onSurface = Color(0xFF000000),
    secondaryText = Color(0xFF6C6C70),
)

private val IOSDarkSurface = ThemeSurface(
    background = Color(0xFF000000),
    surface = Color(0xFF1C1C1E),
    onSurface = Color(0xFFF2F2F7),
    secondaryText = Color(0xFF98989D),
)

private fun Color.luminance(): Float =
    0.2126f * red + 0.7152f * green + 0.0722f * blue
