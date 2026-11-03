package com.snaptask.app

import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.anchoredDraggable
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.lazy.LazyListState
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle as JavaTextStyle
import kotlin.math.abs
import kotlin.math.roundToInt

// MARK: - Text

/** Plain `Text`: never cut with "…", it wraps instead. */
@Composable
fun T(text: String, style: TextStyle = Fonts.body, color: Color = theme.textColor, align: TextAlign? = null, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE) {
    Text(text, style = style, color = color, textAlign = align, modifier = modifier, maxLines = maxLines)
}

// MARK: - Haptics

object Haptics {
    var view: android.view.View? = null
    fun light() { view?.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
    fun medium() { view?.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY) }
    fun heavy() { view?.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS) }
    fun success() { view?.performHapticFeedback(HapticFeedbackConstants.CONFIRM) }
    fun selection() { view?.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
}

// MARK: - Modifiers

fun Modifier.tap(enabled: Boolean = true, onClick: () -> Unit): Modifier =
    this.clickable(MutableInteractionSource(), null, enabled = enabled, onClick = onClick)

/** A press effect similar to `.buttonStyle(.plain)` on iOS: the content dims while pressed. */
@Composable
fun Modifier.pressable(enabled: Boolean = true, onLongPress: (() -> Unit)? = null, onClick: () -> Unit): Modifier {
    var pressed by remember { mutableStateOf(false) }
    return this
        .graphicsLayer { alpha = if (pressed) 0.55f else 1f }
        .pointerInput(enabled, onClick, onLongPress) {
            if (!enabled) return@pointerInput
            detectTapGestures(
                onLongPress = onLongPress?.let { action -> { action() } },
                onPress = {
                    pressed = true
                    tryAwaitRelease()
                    pressed = false
                },
                onTap = { onClick() },
            )
        }
}

// MARK: - Toggle

/** The iOS switch. */
@Composable
fun IOSToggle(checked: Boolean, onChange: (Boolean) -> Unit, tint: Color = theme.accentColor, enabled: Boolean = true) {
    val track by animateColorAsState(if (checked) tint else Color.Gray4, tween(200), label = "track")
    val offset by animateDpAsState(if (checked) 20.dp else 0.dp, tween(200), label = "knob")
    Box(
        Modifier
            .size(width = 51.dp, height = 31.dp)
            .clip(CircleShape)
            .background(track)
            .graphicsLayer { alpha = if (enabled) 1f else 0.5f }
            .tap(enabled) {
                Haptics.selection()
                onChange(!checked)
            }
            .semantics { toggleableState = androidx.compose.ui.state.ToggleableState(checked) }
            .padding(2.dp)
    ) {
        Box(
            Modifier
                .offset(x = offset)
                .size(27.dp)
                .shadow(2.dp, CircleShape)
                .background(Color.White, CircleShape)
        )
    }
}

// MARK: - Grouped list (`List` / `Form` with `.insetGrouped`)

/** The scrolling page of a `Form`. */
@Composable
fun FormPage(
    modifier: Modifier = Modifier,
    background: Color = theme.backgroundColor,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxSize()
            .background(background)
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(bottom = 32.dp)
            .navigationBarsPadding(),
        content = content,
    )
}

@Composable
fun FormSection(
    header: String? = null,
    footer: String? = null,
    modifier: Modifier = Modifier,
    background: Color = theme.surfaceColor,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth().padding(top = 18.dp)) {
        if (header != null) {
            T(
                header,
                style = Fonts.footnote,
                color = Color.Secondary,
                modifier = Modifier.padding(start = 32.dp, end = 32.dp, bottom = 7.dp),
            )
        }
        Column(
            Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(background),
            content = content,
        )
        if (footer != null) {
            T(
                footer,
                style = Fonts.footnote,
                color = Color.Secondary,
                modifier = Modifier.padding(start = 32.dp, end = 32.dp, top = 7.dp),
            )
        }
    }
}

@Composable
fun RowDivider(start: Dp = 16.dp) {
    Box(
        Modifier
            .padding(start = start)
            .fillMaxWidth()
            .height(0.5.dp)
            .background(theme.divider)
    )
}

/** One row of a `Form`: icon, title, what's on the right. */
@Composable
fun FormRow(
    title: String,
    icon: String? = null,
    iconTint: Color = theme.primaryColor,
    subtitle: String? = null,
    titleColor: Color = theme.textColor,
    value: String? = null,
    chevron: Boolean = false,
    divider: Boolean = true,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
                .heightIn(min = 44.dp)
                .padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (icon != null) {
                SF(icon, iconTint, 22.dp)
                Spacer(Modifier.width(12.dp))
            }
            Column(Modifier.weight(1f)) {
                T(title, Fonts.body, titleColor)
                if (subtitle != null) T(subtitle, Fonts.footnote, Color.Secondary)
            }
            if (value != null) {
                Spacer(Modifier.width(8.dp))
                T(value, Fonts.body, Color.Secondary, align = TextAlign.End)
            }
            if (trailing != null) {
                Spacer(Modifier.width(8.dp))
                trailing()
            }
            if (chevron) {
                Spacer(Modifier.width(6.dp))
                SF("chevron.right", Color.Tertiary, 20.dp)
            }
        }
        if (divider) RowDivider(if (icon != null) 50.dp else 16.dp)
    }
}

@Composable
fun ToggleRow(
    title: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
    icon: String? = null,
    iconTint: Color = theme.primaryColor,
    subtitle: String? = null,
    divider: Boolean = true,
    enabled: Boolean = true,
) {
    FormRow(title, icon, iconTint, subtitle, divider = divider, trailing = {
        IOSToggle(checked, onChange, enabled = enabled)
    })
}

// MARK: - Text fields

@Composable
fun PlainField(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String = "",
    style: TextStyle = Fonts.body,
    color: Color = theme.textColor,
    keyboard: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
    minLines: Int = 1,
    align: TextAlign = TextAlign.Start,
    modifier: Modifier = Modifier,
) {
    BasicTextField(
        value = value,
        onValueChange = onChange,
        textStyle = style.copy(color = color, textAlign = align),
        singleLine = singleLine,
        minLines = minLines,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        cursorBrush = SolidColor(theme.accentColor),
        modifier = modifier,
        decorationBox = { inner ->
            Box(contentAlignment = if (align == TextAlign.End) Alignment.CenterEnd else Alignment.CenterStart) {
                if (value.isEmpty()) T(placeholder, style, Color.Tertiary, align = align)
                inner()
            }
        },
    )
}

/** A text field inside a `Form` row. */
@Composable
fun FieldRow(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
    keyboard: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
    minLines: Int = 1,
    divider: Boolean = true,
) {
    Column {
        PlainField(
            value, onChange, placeholder,
            keyboard = keyboard,
            singleLine = singleLine,
            minLines = minLines,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .padding(horizontal = 16.dp, vertical = 11.dp),
        )
        if (divider) RowDivider()
    }
}

// MARK: - Segmented control

/** `Picker(...).pickerStyle(.segmented)` */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selection: T,
    onSelect: (T) -> Unit,
    label: (T) -> String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(9.dp))
            .background(Color.TertiaryFill)
            .padding(2.dp)
    ) {
        options.forEach { option ->
            val selected = option == selection
            val background by animateColorAsState(
                if (selected) (if (theme.systemDark) Color(0xFF636366) else Color.White) else Color.Transparent,
                tween(200), label = "segment",
            )
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(7.dp))
                    .background(background)
                    .tap {
                        Haptics.selection()
                        onSelect(option)
                    }
                    .padding(horizontal = 4.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                T(label(option), Fonts.footnote.let { if (selected) it.semibold else it.medium }, align = TextAlign.Center)
            }
        }
    }
}

/** `ThemedSegmentedPicker` of `View+Theme.swift`. */
@Composable
fun <T> ThemedSegmentedPicker(
    selection: T,
    options: List<T>,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    label: @Composable (T) -> Unit,
) {
    val theme = theme
    Row(
        modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clip(RoundedCornerShape(12.dp))
            .background(theme.surfaceColor.copy(alpha = 0.6f))
            .border(1.dp, theme.borderColor.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEach { option ->
            val selected = selection == option
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (selected) theme.primaryColor.copy(alpha = 0.12f) else Color.Transparent)
                    .border(1.5.dp, if (selected) theme.primaryColor.copy(alpha = 0.4f) else Color.Transparent, RoundedCornerShape(10.dp))
                    .tap { onSelect(option) }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                CompositionLocalProvider(LocalSegmentSelected provides selected) { label(option) }
            }
        }
    }
}

val LocalSegmentSelected = compositionLocalOf { false }

// MARK: - Menus and dialogs

class MenuItem(
    val title: String,
    val icon: String? = null,
    val destructive: Boolean = false,
    val checked: Boolean = false,
    val enabled: Boolean = true,
    val action: () -> Unit,
)

/** `Menu`: the label opens an iOS-style popup list. */
@Composable
fun IOSMenu(
    items: List<MenuItem>,
    modifier: Modifier = Modifier,
    label: @Composable () -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Box(Modifier.tap { open = true }) { label() }
        if (open) MenuPopup(items) { open = false }
    }
}

/** Under the button that opened it, lined up with its nearest edge; above it when there's no room below. */
private class MenuPosition(private val gap: Int) : androidx.compose.ui.window.PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: androidx.compose.ui.unit.IntRect,
        windowSize: androidx.compose.ui.unit.IntSize,
        layoutDirection: androidx.compose.ui.unit.LayoutDirection,
        popupContentSize: androidx.compose.ui.unit.IntSize,
    ): IntOffset {
        val startsOnTheLeft = anchorBounds.center.x < windowSize.width / 2
        val x = if (startsOnTheLeft) anchorBounds.left else anchorBounds.right - popupContentSize.width
        val below = anchorBounds.bottom + gap
        val y = if (below + popupContentSize.height <= windowSize.height - gap) below else anchorBounds.top - gap - popupContentSize.height
        return IntOffset(
            x.coerceIn(gap, (windowSize.width - popupContentSize.width - gap).coerceAtLeast(gap)),
            y.coerceIn(gap, (windowSize.height - popupContentSize.height - gap).coerceAtLeast(gap)),
        )
    }
}

@Composable
fun MenuPopup(items: List<MenuItem>, onClose: () -> Unit) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    val position = remember(density) { MenuPosition(with(density) { 8.dp.roundToPx() }) }
    Popup(
        popupPositionProvider = position,
        onDismissRequest = onClose,
        properties = PopupProperties(focusable = true),
    ) {
        Column(
            Modifier
                .widthIn(min = 200.dp, max = 300.dp)
                .heightIn(max = androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp.dp * 0.7f)
                .shadow(16.dp, RoundedCornerShape(13.dp))
                .clip(RoundedCornerShape(13.dp))
                .background(if (theme.systemDark) Color(0xFF2C2C2E) else Color(0xFFF7F7F7))
                .verticalScroll(rememberScrollState())
        ) {
            items.forEachIndexed { index, item ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable(enabled = item.enabled) {
                            onClose()
                            item.action()
                        }
                        .padding(horizontal = 16.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (item.checked) {
                        SF("checkmark", Color.Primary, 16.dp)
                        Spacer(Modifier.width(8.dp))
                    }
                    T(
                        item.title,
                        Fonts.body,
                        when {
                            item.destructive -> Color.SysRed
                            !item.enabled -> Color.Secondary
                            else -> Color.Primary
                        },
                        modifier = Modifier.weight(1f),
                    )
                    if (item.icon != null) {
                        Spacer(Modifier.width(12.dp))
                        SF(item.icon, if (item.destructive) Color.SysRed else Color.Primary, 20.dp)
                    }
                }
                if (index < items.lastIndex) RowDivider(0.dp)
            }
        }
    }
}

class AlertAction(val title: String, val role: AlertRole = AlertRole.normal, val action: () -> Unit = {})
enum class AlertRole { normal, cancel, destructive }

/** `.alert` */
@Composable
fun IOSAlert(title: String, message: String? = null, actions: List<AlertAction>, onDismiss: () -> Unit, content: (@Composable () -> Unit)? = null) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .width(290.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(if (theme.systemDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F2))
        ) {
            Column(
                Modifier.fillMaxWidth().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                T(title, Fonts.headline, Color.Primary, TextAlign.Center)
                if (message != null) T(message, Fonts.footnote, Color.Primary, TextAlign.Center)
                content?.invoke()
            }
            RowDivider(0.dp)
            if (actions.size == 2) {
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
                    actions.forEachIndexed { index, action ->
                        AlertButton(action, Modifier.weight(1f), onDismiss)
                        if (index == 0) Box(Modifier.width(0.5.dp).fillMaxHeight().background(theme.divider))
                    }
                }
            } else {
                actions.forEachIndexed { index, action ->
                    AlertButton(action, Modifier.fillMaxWidth(), onDismiss)
                    if (index < actions.lastIndex) RowDivider(0.dp)
                }
            }
        }
    }
}

@Composable
private fun AlertButton(action: AlertAction, modifier: Modifier, onDismiss: () -> Unit) {
    Box(
        modifier
            .clickable {
                onDismiss()
                action.action()
            }
            .padding(vertical = 12.dp, horizontal = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        T(
            action.title,
            if (action.role == AlertRole.cancel) Fonts.body.semibold else Fonts.body,
            if (action.role == AlertRole.destructive) Color.SysRed else Color.SysBlue,
            TextAlign.Center,
        )
    }
}

/** `.confirmationDialog`: buttons rising from the bottom of the screen. */
@Composable
fun ConfirmationDialog(title: String? = null, message: String? = null, actions: List<AlertAction>, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().tap(onClick = onDismiss), contentAlignment = Alignment.BottomCenter) {
            Column(
                Modifier
                    .padding(horizontal = 8.dp)
                    .navigationBarsPadding()
                    .padding(bottom = 8.dp)
                    .fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                val panel = if (theme.systemDark) Color(0xFF2C2C2E) else Color(0xFFF2F2F2)
                Column(Modifier.clip(RoundedCornerShape(14.dp)).background(panel)) {
                    if (title != null || message != null) {
                        Column(
                            Modifier.fillMaxWidth().padding(14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            if (title != null) T(title, Fonts.footnote.semibold, Color.Secondary, TextAlign.Center)
                            if (message != null) T(message, Fonts.footnote, Color.Secondary, TextAlign.Center)
                        }
                        RowDivider(0.dp)
                    }
                    val main = actions.filter { it.role != AlertRole.cancel }
                    main.forEachIndexed { index, action ->
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onDismiss()
                                    action.action()
                                }
                                .padding(vertical = 16.dp, horizontal = 12.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            T(action.title, Fonts.title3, if (action.role == AlertRole.destructive) Color.SysRed else Color.SysBlue, TextAlign.Center)
                        }
                        if (index < main.lastIndex) RowDivider(0.dp)
                    }
                }
                val cancel = actions.firstOrNull { it.role == AlertRole.cancel }
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(panel)
                        .clickable {
                            onDismiss()
                            cancel?.action?.invoke()
                        }
                        .padding(vertical = 16.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    T(cancel?.title ?: "cancel".localized, Fonts.title3.semibold, Color.SysBlue)
                }
            }
        }
    }
}

// MARK: - Wheel picker

/** `Picker(...).pickerStyle(.wheel)` */
@Composable
fun <T> WheelPicker(
    items: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
    label: (T) -> String,
    modifier: Modifier = Modifier,
    rowHeight: Dp = 34.dp,
    visibleRows: Int = 5,
) {
    val start = items.indexOf(selected).coerceAtLeast(0)
    val state = rememberLazyListState(initialFirstVisibleItemIndex = start)
    val fling = rememberSnapFlingBehavior(state)
    val current by rememberUpdatedState(onSelect)
    val currentItems by rememberUpdatedState(items)
    LaunchedEffect(state) {
        snapshotFlow { state.firstVisibleItemIndex to state.firstVisibleItemScrollOffset }
            .map { (index, offset) -> if (offset > state.layoutInfo.visibleItemsInfo.firstOrNull()?.size?.div(2) ?: 0) index + 1 else index }
            .distinctUntilChanged()
            .collect { index ->
                currentItems.getOrNull(index)?.let {
                    Haptics.selection()
                    current(it)
                }
            }
    }
    LaunchedEffect(selected) {
        val target = items.indexOf(selected)
        if (target >= 0 && target != state.firstVisibleItemIndex && !state.isScrollInProgress) state.scrollToItem(target)
    }
    val padding = rowHeight * ((visibleRows - 1) / 2)
    Box(modifier.height(rowHeight * visibleRows), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(rowHeight)
                .clip(RoundedCornerShape(8.dp))
                .background(Color.TertiaryFill)
        )
        LazyColumn(
            state = state,
            flingBehavior = fling,
            contentPadding = PaddingValues(vertical = padding),
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            itemsIndexed(items) { index, item ->
                val distance by remember {
                    derivedStateOf {
                        val info = state.layoutInfo.visibleItemsInfo.firstOrNull { it.index == index }
                        if (info == null) 3f else {
                            val center = state.layoutInfo.viewportEndOffset / 2f
                            abs(info.offset + info.size / 2f - center) / info.size.coerceAtLeast(1)
                        }
                    }
                }
                Box(
                    Modifier
                        .height(rowHeight)
                        .fillMaxWidth()
                        .graphicsLayer {
                            alpha = (1f - distance * 0.28f).coerceIn(0.2f, 1f)
                            rotationX = (distance * 14f).coerceAtMost(50f)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    T(label(item), systemFont(21), Color.Primary)
                }
            }
        }
    }
}

/** Date with `displayedComponents: .hourAndMinute` as a wheel. */
@Composable
fun TimeWheel(date: Date, onChange: (Date) -> Unit, modifier: Modifier = Modifier) {
    val twelve = TimeFormatPreference.uses12HourClock
    val hour = date.hour
    val minute = date.minute
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
        if (twelve) {
            val hour12 = if (hour % 12 == 0) 12 else hour % 12
            val isPm = hour >= 12
            WheelPicker((1..12).toList(), hour12, { value ->
                val h = (value % 12) + if (isPm) 12 else 0
                onChange(date.withTime(h, minute))
            }, { it.toString() }, Modifier.width(70.dp))
            WheelPicker((0..59).toList(), minute, { onChange(date.withTime(date.hour, it)) }, { it.toString().padStart(2, '0') }, Modifier.width(70.dp))
            WheelPicker(listOf(false, true), isPm, { pm ->
                val base = date.hour % 12
                onChange(date.withTime(base + if (pm) 12 else 0, date.minute))
            }, { if (it) "PM" else "AM" }, Modifier.width(70.dp))
        } else {
            WheelPicker((0..23).toList(), hour, { onChange(date.withTime(it, date.minute)) }, { it.toString().padStart(2, '0') }, Modifier.width(90.dp))
            WheelPicker((0..59).toList(), minute, { onChange(date.withTime(date.hour, it)) }, { it.toString().padStart(2, '0') }, Modifier.width(90.dp))
        }
    }
}

// MARK: - Graphical date picker

/** `DatePicker(...).datePickerStyle(.graphical)` */
@Composable
fun GraphicalDatePicker(
    date: Date,
    onChange: (Date) -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = theme.accentColor,
    minDate: Date? = null,
    maxDate: Date? = null,
) {
    var shownMonth by remember { mutableStateOf(YearMonth.from(date.z())) }
    Column(modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            T(
                shownMonth.atDay(1).instant().format("LLLL yyyy").replaceFirstChar { it.titlecase(appLocale) },
                Fonts.body.semibold,
                Color.Primary,
                modifier = Modifier.weight(1f),
            )
            BarIcon("chevron.left", tint) { shownMonth = shownMonth.minusMonths(1) }
            BarIcon("chevron.right", tint) { shownMonth = shownMonth.plusMonths(1) }
        }
        val first = firstDayOfWeek
        Row(Modifier.fillMaxWidth()) {
            for (index in 0 until 7) {
                val day = first.plus(index.toLong())
                T(
                    day.getDisplayName(JavaTextStyle.SHORT, appLocale).uppercase(appLocale).take(3),
                    Fonts.caption2.semibold,
                    Color.Tertiary,
                    TextAlign.Center,
                    Modifier.weight(1f),
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        val firstDay = shownMonth.atDay(1)
        val leading = ((firstDay.dayOfWeek.value - first.value) + 7) % 7
        val days = shownMonth.lengthOfMonth()
        val selected = date.z().toLocalDate()
        val today = LocalDate.now()
        val cells = leading + days
        val rows = (cells + 6) / 7
        for (row in 0 until rows) {
            Row(Modifier.fillMaxWidth()) {
                for (column in 0 until 7) {
                    val dayNumber = row * 7 + column - leading + 1
                    Box(Modifier.weight(1f).aspectRatio(1f), contentAlignment = Alignment.Center) {
                        if (dayNumber in 1..days) {
                            val day = shownMonth.atDay(dayNumber)
                            val isSelected = day == selected
                            val allowed = (minDate == null || day >= minDate.z().toLocalDate()) &&
                                (maxDate == null || day <= maxDate.z().toLocalDate())
                            Box(
                                Modifier
                                    .size(38.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) tint.copy(alpha = 0.16f) else Color.Transparent)
                                    .tap(allowed) {
                                        Haptics.selection()
                                        val current = date.z()
                                        onChange(day.atTime(current.hour, current.minute, current.second).atZone(zone).toInstant())
                                    },
                                contentAlignment = Alignment.Center,
                            ) {
                                T(
                                    dayNumber.toString(),
                                    if (isSelected) systemFont(20, FontWeight.SemiBold) else systemFont(20),
                                    when {
                                        !allowed -> Color.Tertiary
                                        isSelected || day == today -> tint
                                        else -> Color.Primary
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/** A date row of a `Form` that opens the calendar and/or the wheel underneath, as compact pickers do. */
@Composable
fun DateRow(
    title: String,
    date: Date,
    onChange: (Date) -> Unit,
    showDate: Boolean = true,
    showTime: Boolean = false,
    divider: Boolean = true,
    icon: String? = null,
    minDate: Date? = null,
    maxDate: Date? = null,
) {
    var open by remember { mutableStateOf<String?>(null) }
    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .padding(horizontal = 16.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (icon != null) {
                SF(icon, theme.primaryColor, 22.dp)
                Spacer(Modifier.width(12.dp))
            }
            T(title, Fonts.body, modifier = Modifier.weight(1f))
            if (showDate) DateChip(date.dateStyle(java.time.format.FormatStyle.MEDIUM), open == "date") { open = if (open == "date") null else "date" }
            if (showTime) {
                Spacer(Modifier.width(6.dp))
                DateChip(date.timeText(), open == "time") { open = if (open == "time") null else "time" }
            }
        }
        AnimatedVisibility(open == "date", enter = expandVertically(tween(260)) + fadeIn(tween(260)), exit = shrinkVertically(tween(220)) + fadeOut(tween(220))) {
            GraphicalDatePicker(date, onChange, Modifier.padding(horizontal = 16.dp, vertical = 8.dp), minDate = minDate, maxDate = maxDate)
        }
        AnimatedVisibility(open == "time", enter = expandVertically(tween(260)) + fadeIn(tween(260)), exit = shrinkVertically(tween(220)) + fadeOut(tween(220))) {
            TimeWheel(date, onChange, Modifier.padding(vertical = 8.dp))
        }
        if (divider) RowDivider(if (icon != null) 50.dp else 16.dp)
    }
}

@Composable
private fun DateChip(text: String, active: Boolean, onClick: () -> Unit) {
    T(
        text,
        Fonts.body,
        if (active) theme.accentColor else Color.Primary,
        modifier = Modifier
            .clip(RoundedCornerShape(7.dp))
            .background(Color.TertiaryFill)
            .tap(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
    )
}

// MARK: - Stepper

@Composable
fun IOSStepper(onMinus: () -> Unit, onPlus: () -> Unit, minusEnabled: Boolean = true, plusEnabled: Boolean = true) {
    Row(
        Modifier
            .height(32.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(Color.TertiaryFill),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(47.dp).fillMaxHeight().tap(minusEnabled) { Haptics.selection(); onMinus() }, contentAlignment = Alignment.Center) {
            SF("minus", if (minusEnabled) Color.Primary else Color.Tertiary, 18.dp)
        }
        Box(Modifier.width(0.5.dp).height(18.dp).background(theme.divider))
        Box(Modifier.width(47.dp).fillMaxHeight().tap(plusEnabled) { Haptics.selection(); onPlus() }, contentAlignment = Alignment.Center) {
            SF("plus", if (plusEnabled) Color.Primary else Color.Tertiary, 18.dp)
        }
    }
}

// MARK: - Empty states

/** `ContentUnavailableView` */
@Composable
fun EmptyState(icon: String, title: String, message: String? = null, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    Column(
        modifier.fillMaxWidth().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SF(icon, Color.Secondary, 44.dp)
        T(title, Fonts.title3.semibold, align = TextAlign.Center)
        if (message != null) T(message, Fonts.subheadline, Color.Secondary, TextAlign.Center)
        action?.invoke()
    }
}

// MARK: - Buttons

/** A filled, rounded button of the app (`StandardButton`). */
@Composable
fun FilledButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: String? = null,
    color: Color = theme.primaryColor,
    textColor: Color = theme.buttonTextColor,
    enabled: Boolean = true,
    corner: Dp = 12.dp,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(corner))
            .background(if (enabled) color else Color.SysGray.copy(alpha = 0.4f))
            .pressable(enabled, onClick = onClick)
            .padding(vertical = 14.dp, horizontal = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            SF(icon, textColor, 20.dp)
            Spacer(Modifier.width(8.dp))
        }
        T(title, Fonts.headline, textColor, TextAlign.Center)
    }
}

// MARK: - Layout helpers

/**
 * `ViewThatFits(in: .horizontal)`: the first candidate that fits the available width.
 * A plain layout, not a subcomposition, so it works inside rows that ask for intrinsic sizes.
 */
@Composable
fun ViewThatFits(vararg candidates: @Composable () -> Unit, modifier: Modifier = Modifier) {
    androidx.compose.ui.layout.Layout(
        content = { candidates.forEach { candidate -> Box { candidate() } } },
        modifier = modifier,
    ) { measurables, constraints ->
        val unbounded = constraints.copy(minWidth = 0, maxWidth = androidx.compose.ui.unit.Constraints.Infinity)
        var chosen: androidx.compose.ui.layout.Placeable? = null
        var last: androidx.compose.ui.layout.Placeable? = null
        for (measurable in measurables) {
            val placeable = measurable.measure(unbounded)
            last = placeable
            if (placeable.width <= constraints.maxWidth) {
                chosen = placeable
                break
            }
        }
        val result = chosen ?: last
        layout(minOf(result?.width ?: 0, constraints.maxWidth), result?.height ?: 0) {
            result?.placeRelative(0, 0)
        }
    }
}

/**
 * Tells its content how wide it may be, for text that picks its size from the space available.
 * It works where a row asks for intrinsic sizes, unlike BoxWithConstraints. Only real measures are
 * read: intrinsic queries pass other widths, and writing those would lay the screen out forever.
 */
@Composable
internal fun WidthReader(available: MutableState<Int?>, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val policy = remember(available) {
        object : androidx.compose.ui.layout.MeasurePolicy {
            override fun androidx.compose.ui.layout.MeasureScope.measure(
                measurables: List<androidx.compose.ui.layout.Measurable>,
                constraints: androidx.compose.ui.unit.Constraints,
            ): androidx.compose.ui.layout.MeasureResult {
                if (constraints.hasBoundedWidth && constraints.maxWidth != available.value) available.value = constraints.maxWidth
                val placeable = measurables.first().measure(constraints)
                return layout(placeable.width, placeable.height) { placeable.place(0, 0) }
            }

            override fun androidx.compose.ui.layout.IntrinsicMeasureScope.minIntrinsicWidth(
                measurables: List<androidx.compose.ui.layout.IntrinsicMeasurable>,
                height: Int,
            ) = measurables.first().minIntrinsicWidth(height)

            override fun androidx.compose.ui.layout.IntrinsicMeasureScope.maxIntrinsicWidth(
                measurables: List<androidx.compose.ui.layout.IntrinsicMeasurable>,
                height: Int,
            ) = measurables.first().maxIntrinsicWidth(height)

            override fun androidx.compose.ui.layout.IntrinsicMeasureScope.minIntrinsicHeight(
                measurables: List<androidx.compose.ui.layout.IntrinsicMeasurable>,
                width: Int,
            ) = measurables.first().minIntrinsicHeight(width)

            override fun androidx.compose.ui.layout.IntrinsicMeasureScope.maxIntrinsicHeight(
                measurables: List<androidx.compose.ui.layout.IntrinsicMeasurable>,
                width: Int,
            ) = measurables.first().maxIntrinsicHeight(width)
        }
    }
    androidx.compose.ui.layout.Layout(content, modifier, policy)
}

/** One bold line, never truncated: the largest size that fits; then the next shorter text. */
@Composable
fun FitText(texts: List<String>, sizes: List<Int>, color: Color, modifier: Modifier = Modifier) {
    val measurer = androidx.compose.ui.text.rememberTextMeasurer()
    val available = remember { mutableStateOf<Int?>(null) }
    val maxPx = available.value ?: Int.MAX_VALUE
    fun width(text: String, size: Int) = measurer.measure(text, systemFont(size, FontWeight.Bold), maxLines = 1, softWrap = false).size.width
    var chosenText = texts.last()
    var chosenSize = sizes.last()
    search@ for (text in texts) {
        for (size in sizes) {
            if (width(text, size) <= maxPx) {
                chosenText = text
                chosenSize = size
                break@search
            }
        }
    }
    var fitted = chosenSize
    while (fitted > 11 && width(chosenText, fitted) > maxPx) fitted--
    WidthReader(available, modifier) {
        Text(
            chosenText,
            Modifier.drawWithContent { if (available.value != null) drawContent() },
            style = systemFont(fitted, FontWeight.Bold),
            color = color,
            maxLines = 1,
            softWrap = false,
        )
    }
}
