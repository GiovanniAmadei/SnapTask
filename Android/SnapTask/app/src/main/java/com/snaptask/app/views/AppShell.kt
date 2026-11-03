package com.snaptask.app

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.random.Random

/** `ContentView`: the five tabs and what notifications and links ask to open. */
@Composable
fun ContentView() {
    val theme = theme
    val presenter = LocalPresenter.current
    var hasShownWelcome by appStorage("hasShownWelcome", false)
    var selectedTab by remember { mutableStateOf(0) }

    LaunchedEffect(Unit) {
        if (!hasShownWelcome) presenter.fullScreen { WelcomeView() }
        InProgressTip
    }
    LaunchedEffect(AppEvents.selectTab) {
        AppEvents.selectTab?.let {
            selectedTab = it
            AppEvents.selectTab = null
        }
    }
    LaunchedEffect(AppEvents.openTaskId) {
        AppEvents.openTaskId?.let { id ->
            selectedTab = 0
            presenter.sheet { NavigationStack { TaskDetailView(taskId = id) } }
            AppEvents.openTaskId = null
        }
    }
    LaunchedEffect(AppEvents.openJournalDate) {
        AppEvents.openJournalDate?.let { date ->
            presenter.sheet { JournalView(date = date) }
            AppEvents.openJournalDate = null
        }
    }
    LaunchedEffect(AppEvents.openFeedbackId) {
        AppEvents.openFeedbackId?.let { id ->
            presenter.sheet { NavigationStack { FeedbackView(focusFeedbackId = id) } }
            AppEvents.openFeedbackId = null
        }
    }

    Box(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        // Tabs keep their state, as in SwiftUI's TabView. The pages scroll under the bar.
        val saved = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
        Crossfade(selectedTab, animationSpec = tween(160), label = "tab") { tab ->
            saved.SaveableStateProvider(tab) {
                when (tab) {
                    0 -> TimelineView()
                    1 -> FocusTabView()
                    2 -> RewardsView()
                    3 -> NavigationStack { FinanceDashboardView() }
                    else -> StatisticsView()
                }
            }
        }
        TabBar(selectedTab, Modifier.align(Alignment.BottomCenter)) { selectedTab = it }
    }
}

/** How much of the bottom of a tab's page the floating bar covers. */
@Composable
fun tabBarInset(): androidx.compose.ui.unit.Dp =
    72.dp + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

/** The floating capsule of iOS 26, with the selection sliding between the tabs. */
@Composable
private fun TabBar(selected: Int, modifier: Modifier = Modifier, onSelect: (Int) -> Unit) {
    val theme = theme
    val tabs = listOf(
        "timeline" to "calendar",
        "focus" to "timer",
        "rewards" to "star.fill",
        "finance" to "banknote.fill",
        "statistics" to "chart.bar.fill",
    )
    val shape = RoundedCornerShape(32.dp)
    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(start = 16.dp, end = 16.dp, bottom = 6.dp)
            .shadow(14.dp, shape, clip = false, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
            .clip(shape)
            .background(theme.surfaceColor.copy(alpha = 0.9f))
            .border(1.dp, if (theme.isDark) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.8f), shape)
            .height(62.dp),
    ) {
        val tabWidth = (maxWidth - 8.dp) / tabs.size
        val offset by animateDpAsState(4.dp + tabWidth * selected, spring(dampingRatio = 0.8f, stiffness = 500f), label = "tabPill")
        Box(
            Modifier
                .offset(x = offset, y = 4.dp)
                .size(tabWidth, 54.dp)
                .clip(RoundedCornerShape(27.dp))
                .background(theme.primaryColor.copy(alpha = if (theme.isDark) 0.18f else 0.12f)),
        )
        Row(Modifier.fillMaxSize().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            tabs.forEachIndexed { index, (title, icon) ->
                val isSelected = index == selected
                val color = if (isSelected) theme.primaryColor else theme.textColor
                Column(
                    Modifier
                        .weight(1f)
                        .tap {
                            Haptics.selection()
                            onSelect(index)
                        },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    SF(icon, color, 24.dp)
                    T(title.localized, systemFont(10, androidx.compose.ui.text.font.FontWeight.Medium), color, TextAlign.Center, maxLines = 1)
                }
            }
        }
    }
}

// MARK: - Confetti

private class Particle(val color: Color, val width: Float, val height: Float, val startX: Float, val delay: Float, val speed: Float, val drift: Float, val rotation: Float)

@Composable
fun ConfettiOverlay() {
    val trigger = ConfettiManager.trigger
    if (trigger == 0 || !AppSettings.enableConfettiCelebration) return
    key(trigger) {
        val colors = listOf(Color.SysRed, Color.SysBlue, Color.SysGreen, Color.SysYellow, Color.SysPurple, Color.SysOrange, Color.SysPink, Color.SysMint, Color.SysCyan, Color.SysIndigo)
        val particles = remember {
            List(90) {
                val w = Random.nextFloat() * 6f + 6f
                Particle(
                    colors.random(), w, if (Random.nextBoolean()) w else w * (Random.nextFloat() + 1.5f),
                    Random.nextFloat(), Random.nextFloat() * 0.3f, Random.nextFloat() * 0.4f + 0.4f,
                    Random.nextFloat() * 60f - 30f, Random.nextFloat() * 6f - 3f,
                )
            }
        }
        var time by remember { mutableStateOf(0f) }
        LaunchedEffect(Unit) {
            val start = withFrameNanos { it }
            while (time < 1.2f) {
                time = (withFrameNanos { it } - start) / 1_000_000_000f
            }
        }
        if (time < 1.2f) {
            Canvas(Modifier.fillMaxSize()) {
                val total = size.height + 60.dp.toPx()
                particles.forEach { particle ->
                    val t = ((time - particle.delay) / particle.speed).coerceIn(0f, 1f)
                    if (time >= particle.delay && t < 1f) {
                        val alpha = if (t < 0.65f) 1f else (1f - (t - 0.65f) / 0.35f)
                        val x = particle.startX * size.width + particle.drift * t * density
                        val y = -20f * density + total * t
                        val w = particle.width * density
                        val h = particle.height * density
                        rotate(particle.rotation * 360f * t, Offset(x, y)) {
                            drawRect(particle.color.copy(alpha = alpha), Offset(x - w / 2, y - h / 2), Size(w, h))
                        }
                    }
                }
            }
        }
    }
}
