package com.snaptask.app

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import java.text.NumberFormat

/** `n.formatted()`: digits grouped the way the language writes them. */
fun Int.formatted(): String = NumberFormat.getIntegerInstance(appLocale).format(this)

/** One line that shrinks instead of being cut (`.lineLimit(1).minimumScaleFactor`). */
@Composable
fun ShrinkText(text: String, style: TextStyle, color: Color = Color.Unspecified, modifier: Modifier = Modifier, minScale: Float = 0.6f, align: TextAlign? = null) {
    val measurer = rememberTextMeasurer()
    val full = remember(text, style) { measurer.measure(text, style, maxLines = 1, softWrap = false).size.width }
    val available = remember { mutableStateOf<Int?>(null) }
    val width = available.value
    val scale = if (width != null && full > width) (width.toFloat() / full).coerceAtLeast(minScale) else 1f
    val resolved = if (color == Color.Unspecified) theme.textColor else color
    WidthReader(available, modifier.then(if (align != null) Modifier.fillMaxWidth() else Modifier)) {
        T(
            text, style.copy(fontSize = style.fontSize * scale), resolved, align ?: TextAlign.Start,
            Modifier
                .then(if (align != null) Modifier.fillMaxWidth() else Modifier)
                .drawWithContent { if (available.value != null) drawContent() },
            maxLines = 1,
        )
    }
}

object StatsFormat {
    fun hours(hours: Double): String {
        val totalMinutes = Math.round(hours * 60).toInt()
        val h = totalMinutes / 60
        val m = totalMinutes % 60
        if (h == 0) return "${m}m"
        if (h >= 100) return "${Math.round(hours)}h"
        return if (m == 0) "${h}h" else "${h}h ${m}m"
    }

    fun percent(value: Double) = "${Math.round(value * 100)}%"
}

@Composable
fun StatsCard(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val theme = theme
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(theme.surfaceColor).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(title, Fonts.headline)
                if (subtitle != null) T(subtitle, Fonts.caption, theme.secondaryTextColor)
            }
            if (trailing != null) {
                Spacer(Modifier.width(8.dp))
                trailing()
            }
        }
        content()
    }
}

@Composable
fun StatTile(value: String, label: String, systemImage: String, tint: Color, modifier: Modifier = Modifier, caption: String? = null) {
    val theme = theme
    Column(
        modifier.clip(RoundedCornerShape(16.dp)).background(theme.surfaceColor).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SF(systemImage, tint, 14.dp)
            ShrinkText(label, Fonts.caption.medium, theme.secondaryTextColor)
        }
        ShrinkText(value, Fonts.title2.bold.monospacedDigit, theme.textColor)
        // Always reserve the caption line so tiles in the same row share the same height.
        ShrinkText(caption ?: " ", Fonts.caption2, theme.secondaryTextColor)
    }
}

@Composable
fun StatsEmptyState(systemImage: String, title: String, message: String, modifier: Modifier = Modifier) {
    val theme = theme
    Column(
        modifier.fillMaxWidth().padding(vertical = 24.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SF(systemImage, theme.secondaryTextColor.copy(alpha = 0.5f), 32.dp)
        T(title, Fonts.subheadline.semibold, align = TextAlign.Center)
        T(message, Fonts.caption, theme.secondaryTextColor, TextAlign.Center)
    }
}

@Composable
fun ChartTooltip(title: String, lines: List<Pair<Color, String>>, modifier: Modifier = Modifier) {
    val theme = theme
    Column(
        modifier
            .shadow(6.dp, RoundedCornerShape(10.dp), clip = false)
            .clip(RoundedCornerShape(10.dp))
            .background(theme.backgroundColor)
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        T(title, Fonts.caption2.semibold, theme.secondaryTextColor, maxLines = 1)
        lines.forEach { (color, text) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Box(Modifier.size(6.dp).background(color, CircleShape))
                T(text, Fonts.caption.semibold.monospacedDigit, maxLines = 1)
            }
        }
    }
}

@Composable
fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(Modifier.size(10.dp).clip(RoundedCornerShape(2.dp)).background(color))
        T(label, Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
    }
}

/** Capsule segmented control used for the tab bar and the period selector. */
@Composable
fun <V> StatsSegmentedControl(
    options: List<V>,
    selection: V,
    onSelect: (V) -> Unit,
    label: (V) -> String,
    modifier: Modifier = Modifier,
    icon: ((V) -> String?)? = null,
    isLocked: (V) -> Boolean = { false },
    onLockedTap: ((V) -> Unit)? = null,
) {
    val theme = theme
    BoxWithConstraints(modifier.fillMaxWidth().clip(CircleShape).background(theme.surfaceColor).padding(3.dp)) {
        val segment: Dp = (maxWidth - 2.dp * (options.size - 1)) / options.size
        val index = options.indexOf(selection).coerceAtLeast(0)
        val offset by animateDpAsState((segment + 2.dp) * index, tween(250), label = "segment")
        Box(
            Modifier
                .offset(x = offset)
                .size(segment, 32.dp)
                .shadow(2.dp, CircleShape, clip = false, ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.08f))
                .clip(CircleShape)
                .background(theme.backgroundColor),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            options.forEach { option ->
                val selected = option == selection
                val locked = isLocked(option)
                val color = if (selected) theme.textColor else theme.secondaryTextColor.copy(alpha = if (locked) 0.6f else 1f)
                Row(
                    Modifier
                        .width(segment)
                        .height(32.dp)
                        .clip(CircleShape)
                        .tap {
                            if (locked) onLockedTap?.invoke(option) else onSelect(option)
                        }
                        .padding(horizontal = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
                ) {
                    icon?.invoke(option)?.let { SF(it, color, 13.dp) }
                    ShrinkText(label(option), Fonts.footnote.weight(if (selected) FontWeight.SemiBold else FontWeight.Medium), color, minScale = 0.75f)
                    if (locked) SF("lock.fill", color, 11.dp)
                }
            }
        }
    }
}
