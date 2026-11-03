package com.snaptask.app

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitVerticalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.verticalDrag
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/** What SwiftUI's `NavigationStack` does: `NavigationLink` = `push`, the back button = `pop`. */
class Navigator {
    internal class Page(val id: Long, val content: @Composable () -> Unit) {
        var closing by mutableStateOf(false)
    }

    private var nextId = 0L
    internal val pages: SnapshotStateList<Page> = mutableStateListOf()

    fun push(content: @Composable () -> Unit) { pages.add(Page(nextId++, content)) }

    fun pop(): Boolean {
        val top = pages.lastOrNull { !it.closing } ?: return false
        top.closing = true
        return true
    }

    fun popToRoot() { pages.forEach { it.closing = true } }

    val canPop: Boolean get() = pages.any { !it.closing }
}

val LocalNavigator = compositionLocalOf<Navigator?> { null }

/** `@Environment(\\.dismiss)`: leaves the pushed page, or closes the sheet at the root of it. */
val LocalDismiss = compositionLocalOf<() -> Unit> { {} }

@Composable
fun NavigationStack(root: @Composable () -> Unit) {
    val navigator = remember { Navigator() }
    val width = with(LocalDensity.current) { LocalConfiguration.current.screenWidthDp.dp.toPx() }
    BackHandler(enabled = navigator.canPop) { navigator.pop() }

    CompositionLocalProvider(LocalNavigator provides navigator) {
        Box(Modifier.fillMaxSize()) {
            // Pages underneath stay composed, so they keep their scroll position and state.
            root()
            navigator.pages.forEach { page ->
                key(page.id) {
                    val offset = remember { Animatable(width) }
                    LaunchedEffect(Unit) { offset.animateTo(0f, tween(320, easing = FastOutSlowInEasing)) }
                    LaunchedEffect(page.closing) {
                        if (page.closing) {
                            offset.animateTo(width, tween(280, easing = FastOutSlowInEasing))
                            navigator.pages.remove(page)
                        }
                    }
                    Box(
                        Modifier
                            .fillMaxSize()
                            .graphicsLayer { translationX = offset.value }
                            .background(theme.backgroundColor)
                            .pointerInput(Unit) { detectTapGestures {} }
                    ) {
                        CompositionLocalProvider(LocalDismiss provides { navigator.pop() }) {
                            page.content()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sheets

private class PresentedSheet(
    val id: Long,
    val fullScreen: Boolean,
    val detent: SheetDetent,
    val interactiveDismiss: () -> Boolean,
    val onDismiss: () -> Unit,
    val content: @Composable () -> Unit,
)

enum class SheetDetent { large, medium, fit }

/** Hosts what SwiftUI shows with `.sheet` and `.fullScreenCover`, from anywhere in the app. */
class Presenter {
    private var nextId = 0L
    private val sheets = mutableStateListOf<PresentedSheet>()
    private val closing = mutableStateMapOf<Long, Boolean>()

    fun sheet(
        detent: SheetDetent = SheetDetent.large,
        interactiveDismiss: () -> Boolean = { true },
        onDismiss: () -> Unit = {},
        content: @Composable () -> Unit,
    ) {
        sheets.add(PresentedSheet(nextId++, false, detent, interactiveDismiss, onDismiss, content))
    }

    fun fullScreen(onDismiss: () -> Unit = {}, content: @Composable () -> Unit) {
        sheets.add(PresentedSheet(nextId++, true, SheetDetent.large, { false }, onDismiss, content))
    }

    fun dismissTop() {
        sheets.lastOrNull { closing[it.id] != true }?.let { closing[it.id] = true }
    }

    private fun remove(sheet: PresentedSheet) {
        sheets.remove(sheet)
        closing.remove(sheet.id)
        sheet.onDismiss()
    }

    val hasSheets: Boolean get() = sheets.isNotEmpty()

    @Composable
    fun Host(content: @Composable () -> Unit) {
        val top = sheets.lastOrNull()
        Box(Modifier.fillMaxSize()) {
            // Behind a sheet the page steps back a little, as on iPhone.
            val backScale = remember { Animatable(1f) }
            val anyPage = sheets.any { !it.fullScreen }
            LaunchedEffect(anyPage) { backScale.animateTo(if (anyPage) 0.94f else 1f, tween(320)) }
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black)
            ) {
                Box(
                    Modifier
                        .fillMaxSize()
                        .graphicsLayer {
                            scaleX = backScale.value
                            scaleY = backScale.value
                            clip = backScale.value < 1f
                            shape = RoundedCornerShape(if (backScale.value < 1f) 14.dp else 0.dp)
                        }
                ) { content() }
            }
            sheets.forEach { sheet ->
                key(sheet.id) {
                    SheetLayer(
                        sheet = sheet,
                        closing = closing[sheet.id] == true,
                        isTop = sheet === top,
                        requestClose = { closing[sheet.id] = true },
                        onClosed = { remove(sheet) },
                    )
                }
            }
        }
    }

    @Composable
    private fun SheetLayer(
        sheet: PresentedSheet,
        closing: Boolean,
        isTop: Boolean,
        requestClose: () -> Unit,
        onClosed: () -> Unit,
    ) {
        val heightPx = with(LocalDensity.current) { LocalConfiguration.current.screenHeightDp.dp.toPx() }
        val offset = remember { Animatable(heightPx) }
        val scope = rememberCoroutineScope()
        LaunchedEffect(Unit) { offset.animateTo(0f, tween(340, easing = FastOutSlowInEasing)) }
        LaunchedEffect(closing) {
            if (closing) {
                offset.animateTo(heightPx, tween(280, easing = FastOutSlowInEasing))
                onClosed()
            }
        }
        BackHandler(enabled = isTop && !closing) { requestClose() }

        val progress = (1f - offset.value / heightPx).coerceIn(0f, 1f)
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = if (sheet.fullScreen) 0f else 0.32f * progress))
                .clickable(remember { MutableInteractionSource() }, null, enabled = !sheet.fullScreen && sheet.interactiveDismiss()) {
                    requestClose()
                }
        )
        val top = if (sheet.fullScreen) 0.dp else WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 10.dp
        val modifier = when (sheet.detent) {
            SheetDetent.large -> Modifier.fillMaxSize().padding(top = top)
            SheetDetent.medium -> Modifier.fillMaxWidth().fillMaxHeight(0.55f)
            SheetDetent.fit -> Modifier.fillMaxWidth().wrapContentHeight()
        }
        val shape = RoundedCornerShape(topStart = if (sheet.fullScreen) 0.dp else 14.dp, topEnd = if (sheet.fullScreen) 0.dp else 14.dp)
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            Box(
                modifier
                    .graphicsLayer { translationY = offset.value }
                    .clip(shape)
                    .background(theme.backgroundColor)
                    .clickable(remember { MutableInteractionSource() }, null) {}
                    .then(
                        if (sheet.fullScreen) Modifier else Modifier.pointerInput(Unit) {
                            // The top of the sheet drags it down, like a page sheet on iPhone. The
                            // gesture watches from behind, so the bar's buttons still get their taps.
                            val zone = 56.dp.toPx()
                            awaitEachGesture {
                                val down = awaitFirstDown(requireUnconsumed = false)
                                if (down.position.y > zone || !sheet.interactiveDismiss()) return@awaitEachGesture
                                val start = awaitVerticalTouchSlopOrCancellation(down.id) { change, _ -> change.consume() }
                                    ?: return@awaitEachGesture
                                verticalDrag(start.id) { change ->
                                    val amount = change.positionChange().y
                                    change.consume()
                                    scope.launch { offset.snapTo((offset.value + amount).coerceAtLeast(0f)) }
                                }
                                if (offset.value > heightPx * 0.2f) requestClose()
                                else scope.launch { offset.animateTo(0f, tween(220)) }
                            }
                        },
                    )
            ) {
                CompositionLocalProvider(LocalDismiss provides requestClose) {
                    sheet.content()
                }
            }
        }
    }
}

val LocalPresenter = compositionLocalOf { Presenter() }

// MARK: - Navigation bar

/** `NavigationStack`'s bar: large or inline title, with buttons on the two sides. */
@Composable
fun NavBar(
    title: String,
    large: Boolean = false,
    background: Color = theme.backgroundColor,
    showBack: Boolean = true,
    leading: (@Composable RowScope.() -> Unit)? = null,
    trailing: (@Composable RowScope.() -> Unit)? = null,
) {
    val navigator = LocalNavigator.current
    val back = showBack && navigator?.canPop == true && leading == null
    Column(
        Modifier
            .fillMaxWidth()
            .background(background)
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 44.dp)
                .padding(horizontal = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (!large) {
                Text(
                    title,
                    style = Fonts.headline,
                    color = theme.textColor,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 76.dp),
                )
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                if (back) {
                    Row(
                        Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { navigator?.pop() }
                            .padding(vertical = 8.dp, horizontal = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SF("chevron.left", theme.accentColor, 28.dp)
                    }
                }
                leading?.invoke(this)
                Spacer(Modifier.weight(1f))
                trailing?.invoke(this)
            }
        }
        if (large) {
            Text(
                title,
                style = Fonts.largeTitle.bold,
                color = theme.textColor,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 8.dp),
            )
        }
    }
}

/** A text button of a toolbar. */
@Composable
fun BarButton(text: String, enabled: Boolean = true, bold: Boolean = false, color: Color = theme.accentColor, onClick: () -> Unit) {
    Text(
        text,
        style = if (bold) Fonts.body.semibold else Fonts.body,
        color = if (enabled) color else Color.Secondary,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 8.dp),
    )
}

/** An icon button of a toolbar. */
@Composable
fun BarIcon(name: String, color: Color = theme.accentColor, size: androidx.compose.ui.unit.Dp = 24.dp, onClick: () -> Unit) {
    Box(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(8.dp),
        contentAlignment = Alignment.Center,
    ) {
        SF(name, color, size)
    }
}
