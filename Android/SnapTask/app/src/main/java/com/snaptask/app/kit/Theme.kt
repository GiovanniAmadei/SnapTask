package com.snaptask.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.State
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** iOS system colors: same values as UIKit, light and dark. */
data class Dyn(val light: Color, val dark: Color)

object IOS {
    val blue = Dyn(Color(0xFF007AFF), Color(0xFF0A84FF))
    val green = Dyn(Color(0xFF34C759), Color(0xFF30D158))
    val orange = Dyn(Color(0xFFFF9500), Color(0xFFFF9F0A))
    val red = Dyn(Color(0xFFFF3B30), Color(0xFFFF453A))
    val pink = Dyn(Color(0xFFFF2D55), Color(0xFFFF375F))
    val purple = Dyn(Color(0xFFAF52DE), Color(0xFFBF5AF2))
    val teal = Dyn(Color(0xFF30B0C7), Color(0xFF40C8E0))
    val mint = Dyn(Color(0xFF00C7BE), Color(0xFF63E6E2))
    val cyan = Dyn(Color(0xFF32ADE6), Color(0xFF64D2FF))
    val indigo = Dyn(Color(0xFF5856D6), Color(0xFF5E5CE6))
    val yellow = Dyn(Color(0xFFFFCC00), Color(0xFFFFD60A))
    val brown = Dyn(Color(0xFFA2845E), Color(0xFFAC8E68))
    val gray = Dyn(Color(0xFF8E8E93), Color(0xFF8E8E93))
    val gray2 = Dyn(Color(0xFFAEAEB2), Color(0xFF636366))
    val gray3 = Dyn(Color(0xFFC7C7CC), Color(0xFF48484A))
    val gray4 = Dyn(Color(0xFFD1D1D6), Color(0xFF3A3A3C))
    val gray5 = Dyn(Color(0xFFE5E5EA), Color(0xFF2C2C2E))
    val gray6 = Dyn(Color(0xFFF2F2F7), Color(0xFF1C1C1E))
    val systemBackground = Dyn(Color.White, Color.Black)
    val secondarySystemBackground = Dyn(Color(0xFFF2F2F7), Color(0xFF1C1C1E))
    val tertiarySystemBackground = Dyn(Color.White, Color(0xFF2C2C2E))
    val systemGroupedBackground = Dyn(Color(0xFFF2F2F7), Color.Black)
    val secondarySystemGroupedBackground = Dyn(Color.White, Color(0xFF1C1C1E))
    val tertiarySystemGroupedBackground = Dyn(Color(0xFFF2F2F7), Color(0xFF2C2C2E))
    val label = Dyn(Color.Black, Color.White)
    val secondaryLabel = Dyn(Color(0x993C3C43), Color(0x99EBEBF5))
    val tertiaryLabel = Dyn(Color(0x4D3C3C43), Color(0x4DEBEBF5))
    val quaternaryLabel = Dyn(Color(0x2E3C3C43), Color(0x2EEBEBF5))
    val separator = Dyn(Color(0x4A3C3C43), Color(0x99545458))
    val fill = Dyn(Color(0x33787880), Color(0x5C787880))
    val secondaryFill = Dyn(Color(0x29787880), Color(0x52787880))
    val tertiaryFill = Dyn(Color(0x1F767680), Color(0x3D767680))
    val quaternaryFill = Dyn(Color(0x14747480), Color(0x2E767680))
}

/** A theme of the app: same ids and colors as `ThemeManager.allThemes` on iOS. */
data class AppThemeSpec(
    val id: String,
    val nameKey: String,
    val isPremium: Boolean,
    val primary: Dyn,
    val secondary: Dyn,
    val accent: Dyn,
    val background: Dyn,
    val surface: Dyn,
    val text: Dyn,
    val secondaryText: Dyn,
) {
    val name: String get() = nameKey.localized
    val overridesSystemColors: Boolean
        get() = id == "midnight" || id == "volcanic" || id == "rose_gold" || id == "ocean" || id == "emerald" || id == "lavender"
}

private fun fixed(color: Color) = Dyn(color, color)
private fun rgb(r: Double, g: Double, b: Double) = fixed(Color(r.toFloat(), g.toFloat(), b.toFloat()))

object ThemeManager {
    val allThemes = listOf(
        AppThemeSpec("default", "theme_default", false, IOS.blue, IOS.cyan, IOS.blue, IOS.systemBackground, IOS.secondarySystemBackground, IOS.label, IOS.secondaryLabel),
        AppThemeSpec("forest", "theme_forest", false, IOS.green, IOS.mint, IOS.green, IOS.systemBackground, IOS.secondarySystemBackground, IOS.label, IOS.secondaryLabel),
        AppThemeSpec("sunset", "theme_sunset", false, IOS.orange, IOS.pink, IOS.orange, IOS.systemBackground, IOS.secondarySystemBackground, IOS.label, IOS.secondaryLabel),
        AppThemeSpec("midnight", "theme_midnight", true, rgb(0.5, 0.2, 0.8), rgb(0.3, 0.2, 0.5), rgb(0.8, 0.4, 1.0), rgb(0.05, 0.05, 0.1), rgb(0.15, 0.15, 0.2), fixed(Color.White), rgb(0.9, 0.9, 0.95)),
        AppThemeSpec("rose_gold", "theme_rose_gold", true, IOS.pink, rgb(0.9, 0.7, 0.5), IOS.pink, rgb(0.98, 0.95, 0.92), rgb(0.95, 0.92, 0.88), fixed(Color.Black), rgb(0.4, 0.4, 0.4)),
        AppThemeSpec("ocean", "theme_ocean", true, IOS.blue, IOS.teal, IOS.blue, rgb(0.9, 0.95, 0.98), rgb(0.85, 0.92, 0.96), fixed(Color.Black), rgb(0.2, 0.4, 0.6)),
        AppThemeSpec("emerald", "theme_emerald", true, IOS.green, rgb(0.2, 0.8, 0.6), IOS.green, rgb(0.92, 0.98, 0.95), rgb(0.88, 0.95, 0.92), fixed(Color.Black), rgb(0.1, 0.5, 0.3)),
        AppThemeSpec("volcanic", "theme_volcanic", true, IOS.red, IOS.orange, IOS.red, rgb(0.15, 0.1, 0.1), rgb(0.2, 0.15, 0.15), fixed(Color.White), rgb(0.9, 0.7, 0.7)),
        AppThemeSpec("lavender", "theme_lavender", true, IOS.purple, rgb(0.8, 0.7, 0.9), IOS.purple, rgb(0.96, 0.94, 0.98), rgb(0.92, 0.88, 0.96), fixed(Color.Black), rgb(0.4, 0.3, 0.6)),
    )

    val defaultTheme: AppThemeSpec = allThemes.first { it.id == "sunset" }
    val freeThemes get() = allThemes.filter { !it.isPremium }
    val premiumThemes get() = allThemes.filter { it.isPremium }

    private const val KEY = "currentThemeId"
    var currentTheme by mutableStateOf(allThemes.firstOrNull { it.id == runCatching { Defaults.string(KEY) }.getOrNull() } ?: defaultTheme)
        private set

    fun setTheme(theme: AppThemeSpec) {
        if (theme.isPremium && !SubscriptionManager.hasAccess(PremiumFeature.customThemes)) return
        currentTheme = theme
        Defaults.set(KEY, theme.id)
    }

    fun canUseTheme(theme: AppThemeSpec): Boolean =
        !theme.isPremium || SubscriptionManager.hasAccess(PremiumFeature.customThemes)

    /** After the store says premium ended: back to a free theme, as iOS does when checking access. */
    fun load() {
        currentTheme = allThemes.firstOrNull { it.id == Defaults.string(KEY) } ?: defaultTheme
    }
}

/** A theme with its light or dark values chosen: what `@Environment(\.theme)` gives on iOS. */
data class Theme(
    val spec: AppThemeSpec,
    val isDark: Boolean,
    val primaryColor: Color,
    val secondaryColor: Color,
    val accentColor: Color,
    val backgroundColor: Color,
    val surfaceColor: Color,
    val textColor: Color,
    val secondaryTextColor: Color,
    /** The system light/dark mode, which plain system colors follow. */
    val systemDark: Boolean,
) {
    val id: String get() = spec.id
    val name: String get() = spec.name
    val gradient: Brush get() = Brush.linearGradient(listOf(primaryColor, secondaryColor), Offset.Zero, Offset.Infinite)
    val cardBackground: Color get() = surfaceColor.copy(alpha = 0.9f)
    val borderColor: Color get() = primaryColor.copy(alpha = 0.2f)
    val shadowColor: Color get() = if (isDarkBackground) Color.Black.copy(alpha = 0.3f) else textColor.copy(alpha = 0.1f)
    val buttonTextColor: Color get() = if (lum(primaryColor) < 0.5) Color.White else Color.Black
    val onSurfaceTextColor: Color get() = if (lum(surfaceColor) < 0.5) Color.White else Color.Black
    val isDarkTheme: Boolean get() = isDarkBackground
    private val isDarkBackground: Boolean get() = lum(backgroundColor) < 0.5
    val warningColor: Color get() = resolve(IOS.orange)
    val errorColor: Color get() = resolve(IOS.red)
    val successColor: Color get() = resolve(IOS.green)
    val infoColor: Color get() = resolve(IOS.blue)
    val overridesSystemColors: Boolean get() = spec.overridesSystemColors

    /** A system color for the current mode. */
    fun resolve(color: Dyn): Color = if (systemDark) color.dark else color.light
    val divider: Color get() = resolve(IOS.separator)

    private fun lum(color: Color): Double = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
}

fun AppThemeSpec.resolved(systemDark: Boolean): Theme {
    fun pick(color: Dyn) = if (systemDark) color.dark else color.light
    return Theme(
        spec = this,
        isDark = if (overridesSystemColors) pick(background).luminance() < 0.3f else systemDark,
        primaryColor = pick(primary),
        secondaryColor = pick(secondary),
        accentColor = pick(accent),
        backgroundColor = pick(background),
        surfaceColor = pick(surface),
        textColor = pick(text),
        secondaryTextColor = pick(secondaryText),
        systemDark = systemDark,
    )
}

val LocalTheme = compositionLocalOf { ThemeManager.defaultTheme.resolved(false) }

val theme: Theme @Composable get() = LocalTheme.current

/** Shorthands for plain SwiftUI colors, which follow light and dark mode. */
val Color.Companion.Primary: Color @Composable get() = LocalTheme.current.resolve(IOS.label)
val Color.Companion.Secondary: Color @Composable get() = LocalTheme.current.resolve(IOS.secondaryLabel)
val Color.Companion.Tertiary: Color @Composable get() = LocalTheme.current.resolve(IOS.tertiaryLabel)
val Color.Companion.SysBlue: Color @Composable get() = LocalTheme.current.resolve(IOS.blue)
val Color.Companion.SysGreen: Color @Composable get() = LocalTheme.current.resolve(IOS.green)
val Color.Companion.SysOrange: Color @Composable get() = LocalTheme.current.resolve(IOS.orange)
val Color.Companion.SysRed: Color @Composable get() = LocalTheme.current.resolve(IOS.red)
val Color.Companion.SysPink: Color @Composable get() = LocalTheme.current.resolve(IOS.pink)
val Color.Companion.SysPurple: Color @Composable get() = LocalTheme.current.resolve(IOS.purple)
val Color.Companion.SysTeal: Color @Composable get() = LocalTheme.current.resolve(IOS.teal)
val Color.Companion.SysMint: Color @Composable get() = LocalTheme.current.resolve(IOS.mint)
val Color.Companion.SysCyan: Color @Composable get() = LocalTheme.current.resolve(IOS.cyan)
val Color.Companion.SysIndigo: Color @Composable get() = LocalTheme.current.resolve(IOS.indigo)
val Color.Companion.SysYellow: Color @Composable get() = LocalTheme.current.resolve(IOS.yellow)
val Color.Companion.SysGray: Color @Composable get() = LocalTheme.current.resolve(IOS.gray)
val Color.Companion.SysBrown: Color @Composable get() = LocalTheme.current.resolve(IOS.brown)
val Color.Companion.Gray2: Color @Composable get() = LocalTheme.current.resolve(IOS.gray2)
val Color.Companion.Gray3: Color @Composable get() = LocalTheme.current.resolve(IOS.gray3)
val Color.Companion.Gray4: Color @Composable get() = LocalTheme.current.resolve(IOS.gray4)
val Color.Companion.Gray5: Color @Composable get() = LocalTheme.current.resolve(IOS.gray5)
val Color.Companion.Gray6: Color @Composable get() = LocalTheme.current.resolve(IOS.gray6)
val Color.Companion.SystemBackground: Color @Composable get() = LocalTheme.current.resolve(IOS.systemBackground)
val Color.Companion.SecondaryBackground: Color @Composable get() = LocalTheme.current.resolve(IOS.secondarySystemBackground)
val Color.Companion.TertiaryBackground: Color @Composable get() = LocalTheme.current.resolve(IOS.tertiarySystemBackground)
val Color.Companion.GroupedBackground: Color @Composable get() = LocalTheme.current.resolve(IOS.systemGroupedBackground)
val Color.Companion.SecondaryGroupedBackground: Color @Composable get() = LocalTheme.current.resolve(IOS.secondarySystemGroupedBackground)
val Color.Companion.TertiaryFill: Color @Composable get() = LocalTheme.current.resolve(IOS.tertiaryFill)
val Color.Companion.QuaternaryFill: Color @Composable get() = LocalTheme.current.resolve(IOS.quaternaryFill)

/** A SwiftUI color by name (`"blue"`, `"green"`, …): how the scopes store their color. */
@Composable
fun namedColor(name: String): Color = when (name) {
    "blue" -> Color.SysBlue
    "green" -> Color.SysGreen
    "orange" -> Color.SysOrange
    "purple" -> Color.SysPurple
    "pink" -> Color.SysPink
    "indigo" -> Color.SysIndigo
    "teal" -> Color.SysTeal
    "red" -> Color.SysRed
    "yellow" -> Color.SysYellow
    "mint" -> Color.SysMint
    "cyan" -> Color.SysCyan
    else -> Color.SysGray
}

/** `Color(hex:)` */
fun colorFromHex(hex: String?): Color {
    val clean = hex?.filter { it.isLetterOrDigit() } ?: return Color.Black
    val value = clean.toLongOrNull(16) ?: return Color.Black
    return when (clean.length) {
        3 -> Color(
            ((value shr 8) and 0xF).toInt() * 17,
            ((value shr 4) and 0xF).toInt() * 17,
            (value and 0xF).toInt() * 17,
        )
        6 -> Color(((value shr 16) and 0xFF).toInt(), ((value shr 8) and 0xFF).toInt(), (value and 0xFF).toInt())
        8 -> Color(
            ((value shr 16) and 0xFF).toInt(),
            ((value shr 8) and 0xFF).toInt(),
            (value and 0xFF).toInt(),
            ((value shr 24) and 0xFF).toInt(),
        )
        else -> Color.Black
    }
}

fun Color.toHex(): String {
    fun part(value: Float) = (value * 255).toInt().coerceIn(0, 255).toString(16).padStart(2, '0').uppercase()
    return "#${part(red)}${part(green)}${part(blue)}"
}

// MARK: - Fonts (SwiftUI's text styles; Inter stands in for SF Pro, which only Apple platforms may use)

@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
private fun interWeight(weight: Int) = Font(
    R.font.inter,
    FontWeight(weight),
    variationSettings = androidx.compose.ui.text.font.FontVariation.Settings(androidx.compose.ui.text.font.FontVariation.weight(weight)),
)

/** One variable font file, one entry per weight. */
val Inter = FontFamily((100..900 step 100).map { interWeight(it) })

private fun style(size: Int, weight: FontWeight = FontWeight.Normal, tracking: Double = 0.0) = TextStyle(
    fontFamily = Inter,
    fontSize = size.sp,
    fontWeight = weight,
    letterSpacing = (tracking - size * 0.012).sp,
    lineHeight = (size * 1.22).sp,
)

object Fonts {
    val largeTitle = style(34, tracking = 0.2)
    val title = style(28, tracking = 0.2)
    val title2 = style(22, tracking = 0.1)
    val title3 = style(20)
    val headline = style(17, FontWeight.SemiBold, -0.25)
    val body = style(17, tracking = -0.25)
    val callout = style(16, tracking = -0.2)
    val subheadline = style(15, tracking = -0.15)
    val footnote = style(13, tracking = -0.05)
    val caption = style(12)
    val caption2 = style(11, tracking = 0.05)
}

fun TextStyle.weight(weight: FontWeight): TextStyle = copy(fontWeight = weight)
val TextStyle.bold: TextStyle get() = copy(fontWeight = FontWeight.Bold)
val TextStyle.semibold: TextStyle get() = copy(fontWeight = FontWeight.SemiBold)
val TextStyle.medium: TextStyle get() = copy(fontWeight = FontWeight.Medium)
val TextStyle.monospacedDigit: TextStyle get() = copy(fontFeatureSettings = "tnum")
fun systemFont(size: Int, weight: FontWeight = FontWeight.Normal): TextStyle = style(size, weight)

// MARK: - themed modifiers (`View+Theme.swift`)

/** `.themedCard()` */
@Composable
fun Modifier.themedCard(): Modifier {
    val theme = theme
    val shape = RoundedCornerShape(12.dp)
    return this
        .shadow(4.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
        .clip(shape)
        .background(theme.cardBackground)
        .border(1.dp, theme.borderColor, shape)
}

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val systemSetting = isSystemInDarkTheme()
    val appearance by appStorage("appearanceMode", "system")
    val current = ThemeManager.currentTheme
    // Only premium themes override dark mode; the others follow the setting (`appearanceMode`).
    val systemDark = when {
        current.overridesSystemColors -> current.id == "midnight" || current.id == "volcanic"
        appearance == "light" -> false
        appearance == "dark" -> true
        else -> systemSetting
    }
    val resolved = current.resolved(systemDark)
    CompositionLocalProvider(LocalTheme provides resolved, content = content)
}
