package com.snaptask.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.format.FormatStyle
import java.util.UUID

/** 1.234 → "1.2k" only when space is tight. */
private fun compactPoints(n: Int): String = when {
    n >= 1_000_000 -> "%.1fM".format(java.util.Locale.ROOT, n / 1_000_000.0).replace(".0", "")
    n >= 10_000 -> "%.1fk".format(java.util.Locale.ROOT, n / 1_000.0).replace(".0", "")
    else -> n.formatted()
}

enum class RewardDeletionMode { refund, keepSpent }

private object RewardDeletion {
    fun title(reward: Reward?) = "delete_reward_title".localized(reward?.name ?: "")
    fun spentPoints(reward: Reward?) = reward?.let { it.redemptions.size * it.pointsCost } ?: 0
    fun message(reward: Reward?): String {
        val count = reward?.redemptions?.size ?: 0
        if (count == 0) return "delete_reward_message".localized
        val times = if (count == 1) "reward_redeemed_once".localized else "reward_redeemed_times".localized(count)
        return "delete_reward_choice_message".localized(times, spentPoints(reward))
    }
    fun actions(reward: Reward, onDelete: (RewardDeletionMode) -> Unit, onCancel: () -> Unit = {}): List<AlertAction> {
        val choices = if (reward.redemptions.isEmpty()) {
            listOf(AlertAction("delete".localized, AlertRole.destructive) { onDelete(RewardDeletionMode.refund) })
        } else {
            listOf(
                AlertAction("delete_reward_refund".localized(spentPoints(reward))) { onDelete(RewardDeletionMode.refund) },
                AlertAction("delete_reward_keep_spent".localized, AlertRole.destructive) { onDelete(RewardDeletionMode.keepSpent) },
            )
        }
        return choices + AlertAction("cancel".localized, AlertRole.cancel) { onCancel() }
    }
}

// MARK: - Rewards

@Composable
fun RewardsView() {
    val theme = theme
    val presenter = LocalPresenter.current
    val manager = RewardManager
    var filter by remember { mutableStateOf<RewardFrequency?>(null) }
    var rewardToDelete by remember { mutableStateOf<Reward?>(null) }
    var pendingDeletion by remember { mutableStateOf<Reward?>(null) }
    var pendingMode by remember { mutableStateOf(RewardDeletionMode.refund) }
    var deletionJob by remember { mutableStateOf<Job?>(null) }
    var redeemedId by remember { mutableStateOf<UUID?>(null) }
    val scope = rememberCoroutineScope()

    val allRewards = manager.rewards.filter { !it.isArchived && it.id != pendingDeletion?.id }.sortedBy { it.pointsCost }
    val sections = RewardFrequency.entries.mapNotNull { frequency ->
        allRewards.filter { it.frequency == frequency }.takeIf { it.isNotEmpty() }?.let { frequency to it }
    }
    val shown = filter?.let { selected -> sections.filter { it.first == selected } } ?: sections
    val hasUnlimited = SubscriptionManager.hasAccess(PremiumFeature.unlimitedRewards)
    val canAdd = hasUnlimited || allRewards.size < SubscriptionManager.maxRewardsForFree

    fun commit() {
        deletionJob?.cancel()
        deletionJob = null
        val reward = pendingDeletion ?: return
        if (pendingMode == RewardDeletionMode.refund) manager.removeReward(reward) else manager.archiveReward(reward)
        pendingDeletion = null
    }
    fun schedule(reward: Reward, mode: RewardDeletionMode) {
        commit()
        Haptics.medium()
        pendingMode = mode
        pendingDeletion = reward
        deletionJob = scope.launch {
            delay(5000)
            commit()
        }
    }
    DisposableEffect(Unit) { onDispose { commit() } }

    rewardToDelete?.let { reward ->
        IOSAlert(
            RewardDeletion.title(reward),
            RewardDeletion.message(reward),
            RewardDeletion.actions(reward, { schedule(reward, it) }),
            { rewardToDelete = null },
        )
    }

    Box(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            T("rewards".localized, Fonts.largeTitle.bold, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 8.dp))
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = tabBarInset() + 100.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // Points
                Column(
                    Modifier.padding(top = 4.dp).fillMaxWidth().themedCard().padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Row(
                        Modifier.fillMaxWidth().pressable { presenter.sheet { CategoryPointsBreakdownView() } },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            ShrinkText("available_points".localized, systemFont(13, FontWeight.Medium), theme.secondaryTextColor)
                            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                ShrinkText(manager.availablePoints(RewardFrequency.oneTime).formatted(), systemFont(32, FontWeight.Bold).monospacedDigit, theme.textColor, Modifier.weight(1f, fill = false))
                                T("pts".localized, systemFont(12, FontWeight.SemiBold), theme.secondaryTextColor, maxLines = 1, modifier = Modifier.padding(bottom = 5.dp))
                            }
                        }
                        Spacer(Modifier.width(8.dp))
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Box(Modifier.size(32.dp).background(theme.primaryColor.copy(alpha = 0.1f), CircleShape), contentAlignment = Alignment.Center) {
                                SF("chevron.right", theme.primaryColor, 14.dp)
                            }
                            T("tap_for_details".localized, systemFont(9, FontWeight.Medium), theme.secondaryTextColor, TextAlign.Center, Modifier.widthIn(max = 60.dp))
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        CompactPointsChip("rewards_period_day".localized, manager.availablePoints(RewardFrequency.daily), theme.primaryColor, Modifier.weight(1f))
                        CompactPointsChip("rewards_period_week".localized, manager.availablePoints(RewardFrequency.weekly), theme.secondaryColor, Modifier.weight(1f))
                        CompactPointsChip("rewards_period_month".localized, manager.availablePoints(RewardFrequency.monthly), theme.accentColor, Modifier.weight(1f))
                        CompactPointsChip("rewards_period_year".localized, manager.availablePoints(RewardFrequency.yearly), theme.primaryColor.copy(alpha = 0.8f), Modifier.weight(1f))
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CompactActionCard("points_history".localized, "chart.line.uptrend.xyaxis", theme.primaryColor, Modifier.weight(1f)) { presenter.sheet { PointsHistoryView() } }
                    CompactActionCard("redeemed_rewards".localized, "gift.circle", theme.secondaryColor, Modifier.weight(1f)) { presenter.sheet { RedeemedRewardsView() } }
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ShrinkText("available_rewards".localized, Fonts.title3.bold, theme.textColor, Modifier.padding(top = 6.dp), minScale = 0.8f)
                    if (allRewards.isEmpty()) {
                        Column(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(theme.surfaceColor).padding(28.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Box(Modifier.size(64.dp).background(theme.primaryColor.copy(alpha = 0.12f), CircleShape), contentAlignment = Alignment.Center) { SF("gift", theme.primaryColor, 30.dp) }
                            T("no_rewards_yet".localized, Fonts.headline, align = TextAlign.Center)
                            T("create_first_reward_motivation".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center)
                        }
                    } else {
                        Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 2.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            FilterPill("rewards_period_all".localized, "square.grid.2x2", filter == null, theme.primaryColor, allRewards.size) { filter = null }
                            sections.forEach { (frequency, rewards) ->
                                FilterPill(frequency.pickerLabel, frequency.iconName, filter == frequency, theme.primaryColor, rewards.size) {
                                    filter = if (filter == frequency) null else frequency
                                }
                            }
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                            shown.forEach { (frequency, rewards) ->
                                key(frequency) {
                                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                        Row(Modifier.padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                            SF(frequency.iconName, theme.primaryColor, 13.dp)
                                            T(frequency.pickerLabel.uppercase(appLocale), Fonts.footnote.semibold, theme.secondaryTextColor, modifier = Modifier.weight(1f), maxLines = 1)
                                            T(manager.availablePoints(frequency).formatted() + " " + "pts".localized, Fonts.footnote.semibold.monospacedDigit, theme.primaryColor, maxLines = 1)
                                        }
                                        rewards.forEach { reward ->
                                            key(reward.id) {
                                                RewardCard(
                                                    reward,
                                                    showsRedeemSuccess = redeemedId == reward.id,
                                                    onRedeem = {
                                                        Haptics.success()
                                                        manager.redeemReward(reward)
                                                        redeemedId = reward.id
                                                        scope.launch {
                                                            delay(1600)
                                                            if (redeemedId == reward.id) redeemedId = null
                                                        }
                                                    },
                                                    onEdit = { presenter.sheet { RewardFormView(reward, onDelete = { r, mode -> schedule(r, mode) }) } },
                                                    onDuplicate = {
                                                        val copy = Reward(name = reward.name, description = reward.description, pointsCost = reward.pointsCost, frequency = reward.frequency, icon = reward.icon, categoryId = reward.categoryId, categoryName = reward.categoryName)
                                                        presenter.sheet { RewardFormView(copy, isEditing = false) }
                                                    },
                                                    onDelete = { rewardToDelete = reward },
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if (!hasUnlimited) {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(theme.surfaceColor).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SF("info.circle", Color.SysOrange, 20.dp)
                            T("premium_limit_info".localized, Fonts.headline, Color.SysOrange)
                        }
                        T("premium_limit_description".localized, Fonts.subheadline, theme.secondaryTextColor)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("${allRewards.size}/${SubscriptionManager.maxRewardsForFree}", Fonts.caption, theme.secondaryTextColor, modifier = Modifier.weight(1f))
                            T(
                                "upgrade_to_pro".localized,
                                Fonts.subheadline.medium,
                                Color.White,
                                maxLines = 1,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(theme.gradient)
                                    .pressable { presenter.sheet { PremiumPaywallView() } }
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                            )
                        }
                    }
                }
            }
        }
        AddRewardButton(canAdd, Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarInset() + 12.dp)) {
            if (canAdd) presenter.sheet { RewardFormView() } else presenter.sheet { PremiumPaywallView() }
        }
        AnimatedVisibility(
            pendingDeletion != null,
            modifier = Modifier.align(Alignment.BottomCenter).padding(start = 16.dp, end = 16.dp, bottom = tabBarInset() + 84.dp),
            enter = slideInVertically { it } + fadeIn(),
            exit = slideOutVertically { it } + fadeOut(),
        ) {
            pendingDeletion?.let { reward ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(Color.Black.copy(alpha = 0.85f)).padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    SF("trash.fill", Color.White.copy(alpha = 0.8f), 18.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        ShrinkText("reward_deleted".localized(reward.name), Fonts.subheadline.medium, Color.White)
                        if (reward.redemptions.isNotEmpty()) {
                            ShrinkText(
                                if (pendingMode == RewardDeletionMode.refund) "reward_points_refunded".localized(RewardDeletion.spentPoints(reward)) else "reward_points_kept".localized,
                                Fonts.caption,
                                Color.White.copy(alpha = 0.7f),
                            )
                        }
                    }
                    T(
                        "undo".localized,
                        Fonts.subheadline.bold,
                        Color.SysYellow,
                        maxLines = 1,
                        modifier = Modifier.tap {
                            deletionJob?.cancel()
                            deletionJob = null
                            Haptics.light()
                            pendingDeletion = null
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun AddRewardButton(canAdd: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val theme = theme
    val purple = Color.SysPurple
    Box(modifier.size(56.dp).pressable(onClick = onClick), contentAlignment = Alignment.Center) {
        if (canAdd) {
            Box(Modifier.requiredSize(84.dp).background(Brush.radialGradient(listOf(theme.primaryColor.copy(alpha = 0.3f), theme.primaryColor.copy(alpha = 0.3f), Color.Transparent)), CircleShape))
            Box(
                Modifier.fillMaxSize().shadow(8.dp, CircleShape, ambientColor = theme.primaryColor, spotColor = theme.primaryColor).clip(CircleShape).background(theme.gradient),
                contentAlignment = Alignment.Center,
            ) { SF("plus", theme.backgroundColor, 28.dp) }
        } else {
            Box(Modifier.requiredSize(90.dp).background(Brush.radialGradient(listOf(purple.copy(alpha = 0.4f), purple.copy(alpha = 0.4f), Color.Transparent)), CircleShape))
            Box(
                Modifier
                    .scale(1.05f)
                    .fillMaxSize()
                    .shadow(12.dp, CircleShape, ambientColor = purple, spotColor = purple)
                    .clip(CircleShape)
                    .background(Brush.linearGradient(listOf(purple, Color.SysPink, purple.copy(alpha = 0.8f))))
                    .background(Brush.linearGradient(listOf(Color.White.copy(alpha = 0f), Color.White.copy(alpha = 0.24f), Color.White.copy(alpha = 0f)))),
                contentAlignment = Alignment.Center,
            ) {
                Row(
                    Modifier.clip(RoundedCornerShape(6.dp)).background(Color.White.copy(alpha = 0.25f)).padding(horizontal = 6.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    SF("lock.fill", Color.White, 13.dp)
                    T("PRO", systemFont(8, FontWeight.Black), Color.White, maxLines = 1)
                }
            }
        }
    }
}

private fun currentRedemptions(reward: Reward): Int {
    val time = now()
    return reward.redemptions.count { date ->
        when (reward.frequency) {
            RewardFrequency.daily -> date.isSameDay(time)
            RewardFrequency.weekly -> date.startOfWeek().isSameDay(time.startOfWeek())
            RewardFrequency.monthly -> date.isSameMonth(time)
            RewardFrequency.yearly -> date.isSameYear(time)
            RewardFrequency.oneTime -> true
        }
    }
}

@Composable
private fun RewardCard(reward: Reward, showsRedeemSuccess: Boolean, onRedeem: () -> Unit, onEdit: () -> Unit, onDuplicate: () -> Unit, onDelete: () -> Unit) {
    val theme = theme
    val manager = RewardManager
    val general = reward.isGeneralReward
    val category = reward.categoryId?.let { id -> CategoryManager.categories.firstOrNull { it.id == id } }
    val categoryColor = category?.let { colorFromHex(it.color) } ?: theme.primaryColor
    val available = reward.categoryId?.let { manager.availablePointsForCategory(it, reward.frequency) } ?: manager.availablePoints(reward.frequency)
    val canRedeem = reward.canRedeem(available)
    val progress = (available.toFloat() / reward.pointsCost).coerceIn(0f, 1f)
    val redemptions = currentRedemptions(reward)
    val safePoints = maxOf(available, 0)
    var menuOpen by remember { mutableStateOf(false) }
    val green = Color(0xFF00C853)
    val shape = RoundedCornerShape(16.dp)
    val tag = if (general) theme.primaryColor else categoryColor

    Box(
        Modifier
            .fillMaxWidth()
            .shadow(if (theme.systemDark) 0.dp else 4.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .pressable(onLongPress = {
                Haptics.medium()
                menuOpen = true
            }, onClick = onEdit),
    ) {
        Box(Modifier.matchParentSize()) {
            Box(
                Modifier
                    .fillMaxWidth(progress)
                    .fillMaxHeight()
                    .background(Brush.linearGradient(if (general) listOf(theme.primaryColor.copy(alpha = 0.15f), theme.secondaryColor.copy(alpha = 0.2f)) else listOf(categoryColor.copy(alpha = 0.15f), categoryColor.copy(alpha = 0.2f)))),
            )
        }
        Column(Modifier.alpha(if (showsRedeemSuccess) 0f else 1f).padding(horizontal = 14.dp, vertical = 11.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    Modifier
                        .size(38.dp)
                        .background(
                            Brush.linearGradient(
                                when {
                                    !canRedeem -> listOf(Color.SysGray.copy(alpha = 0.4f), Color.SysGray.copy(alpha = 0.5f))
                                    general -> listOf(theme.primaryColor, theme.secondaryColor)
                                    else -> listOf(categoryColor, categoryColor.copy(alpha = 0.8f))
                                },
                            ),
                            CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) { SF(reward.icon, Color.White, 18.dp) }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.Top) {
                        T(reward.name, systemFont(15, FontWeight.SemiBold), modifier = Modifier.weight(1f), maxLines = 2)
                        Spacer(Modifier.width(4.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            RewardTag(
                                if (general) "star.fill" else category?.displayIcon ?: "folder.fill",
                                if (general) "general".localized else reward.categoryName ?: reward.frequency.shortDisplayName,
                                tag,
                            )
                            if (redemptions > 1) {
                                RewardTag("checkmark.circle.fill", "${redemptions}x", Color.SysGreen, bold = true)
                            } else if (redemptions == 1) {
                                ViewThatFits(
                                    { RewardTag("checkmark.circle.fill", "redeemed".localized, Color.SysGreen) },
                                    { SF("checkmark.circle.fill", Color.SysGreen, 15.dp) },
                                )
                            }
                        }
                    }
                    if (!reward.description.isNullOrEmpty()) T(reward.description, systemFont(12), theme.secondaryTextColor, maxLines = 1)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    ShrinkText("$safePoints/${reward.pointsCost} " + "points".localized, systemFont(13, FontWeight.Medium), if (canRedeem) green else tag)
                    if (!canRedeem) {
                        ShrinkText("need_more_points".localized.replace("{points}", "${reward.pointsCost - safePoints}"), systemFont(11), theme.secondaryTextColor, minScale = 0.85f)
                    }
                }
                Spacer(Modifier.width(8.dp))
                T(
                    "redeem".localized,
                    systemFont(12, FontWeight.SemiBold),
                    Color.White,
                    maxLines = 1,
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            when {
                                !canRedeem -> Brush.horizontalGradient(listOf(Color.SysGray.copy(alpha = 0.3f), Color.SysGray.copy(alpha = 0.4f)))
                                general -> theme.gradient
                                else -> Brush.horizontalGradient(listOf(categoryColor, categoryColor.copy(alpha = 0.8f)))
                            },
                        )
                        .pressable(enabled = canRedeem, onClick = onRedeem)
                        .padding(horizontal = 16.dp, vertical = 7.dp),
                )
            }
        }
        // Redeem confirmation: covers the card instead of mixing with it.
        androidx.compose.animation.AnimatedVisibility(
            showsRedeemSuccess,
            modifier = Modifier.matchParentSize(),
            enter = fadeIn() + scaleIn(initialScale = 0.95f),
            exit = fadeOut(tween(300)),
        ) {
            Row(
                Modifier.fillMaxSize().background(Brush.linearGradient(listOf(green, Color(0xFF00A844)))).padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SF("checkmark.circle.fill", Color.White, 36.dp)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T("reward_redeemed_success".localized, Fonts.headline, Color.White)
                    ShrinkText("${reward.name} · -${reward.pointsCost} " + "pts".localized, Fonts.subheadline, Color.White.copy(alpha = 0.9f))
                }
            }
        }
        if (menuOpen) {
            MenuPopup(
                listOf(
                    MenuItem("edit".localized, "pencil") { onEdit() },
                    MenuItem("duplicate".localized, "plus.square.on.square") { onDuplicate() },
                    MenuItem("delete".localized, "trash", destructive = true) { onDelete() },
                ),
            ) { menuOpen = false }
        }
    }
}

@Composable
private fun RewardTag(icon: String, text: String, color: Color, bold: Boolean = false) {
    Row(
        Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(color.copy(alpha = 0.12f))
            .border(0.5.dp, color.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        SF(icon, color, 10.dp)
        T(text, systemFont(if (bold) 9 else 10, if (bold) FontWeight.Bold else FontWeight.Medium), color, maxLines = 1)
    }
}

@Composable
private fun FilterPill(label: String, icon: String, selected: Boolean, color: Color, badge: Int, onClick: () -> Unit) {
    val theme = theme
    val foreground = if (selected) Color.White else theme.textColor
    Row(
        Modifier
            .height(32.dp)
            .clip(CircleShape)
            .background(if (selected) color else theme.surfaceColor)
            .tap(onClick = onClick)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        SF(icon, foreground, 13.dp)
        T(label, Fonts.footnote.semibold, foreground, maxLines = 1)
        T(
            "$badge",
            Fonts.caption2.bold.monospacedDigit,
            if (selected) color else theme.secondaryTextColor,
            maxLines = 1,
            modifier = Modifier
                .clip(CircleShape)
                .background(if (selected) Color.White.copy(alpha = 0.9f) else theme.secondaryTextColor.copy(alpha = 0.12f))
                .padding(horizontal = 5.dp),
        )
    }
}

@Composable
private fun CompactPointsChip(title: String, points: Int, color: Color, modifier: Modifier) {
    val theme = theme
    val value = if (points >= 1000) "%.1fk".format(java.util.Locale.ROOT, points / 1000.0).replace(".0k", "k") else "$points"
    Row(
        modifier.clip(RoundedCornerShape(8.dp)).background(color.copy(alpha = 0.08f)).padding(horizontal = 6.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
    ) {
        Box(Modifier.size(6.dp).background(color, CircleShape))
        // Number and label shrink together instead of the label being cut.
        val text = androidx.compose.ui.text.buildAnnotatedString {
            withStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.SemiBold, color = color)) { append(value) }
            withStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.Medium, color = theme.secondaryTextColor, fontSize = androidx.compose.ui.unit.TextUnit(11f, androidx.compose.ui.unit.TextUnitType.Sp))) { append(" $title") }
        }
        val measurer = androidx.compose.ui.text.rememberTextMeasurer()
        val style = systemFont(12).monospacedDigit
        BoxWithConstraints {
            val full = remember(text) { measurer.measure(text, style, maxLines = 1, softWrap = false).size.width }
            val scale = if (full > constraints.maxWidth) (constraints.maxWidth.toFloat() / full).coerceAtLeast(0.6f) else 1f
            androidx.compose.foundation.text.BasicText(text, style = style.copy(fontSize = style.fontSize * scale), maxLines = 1, softWrap = false)
        }
    }
}

@Composable
private fun CompactActionCard(title: String, icon: String, color: Color, modifier: Modifier, onClick: () -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier
            .shadow(1.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(0.5.dp, color.copy(alpha = 0.15f), shape)
            .pressable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        SF(icon, color, 15.dp)
        ShrinkText(title, systemFont(12, FontWeight.Medium), theme.textColor, minScale = 0.75f)
    }
}

// MARK: - Form

private val pointChoices = listOf(1, 2, 3, 5, 8, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 300, 400, 500)

@Composable
fun RewardFormView(initialReward: Reward? = null, isEditing: Boolean = initialReward != null, onDelete: ((Reward, RewardDeletionMode) -> Unit)? = null) {
    val dismiss = LocalDismiss.current
    val navigatorHost = @Composable { content: @Composable () -> Unit -> NavigationStack { content() } }
    navigatorHost {
        val navigator = LocalNavigator.current
        var name by remember { mutableStateOf(initialReward?.let { if (isEditing) it.name else "reward_copy_name".localized(it.name) } ?: "") }
        var description by remember { mutableStateOf(initialReward?.description ?: "") }
        var pointsCost by remember { mutableStateOf(initialReward?.pointsCost ?: 100) }
        var frequency by remember { mutableStateOf(initialReward?.frequency ?: RewardFrequency.daily) }
        var icon by remember { mutableStateOf(initialReward?.icon ?: "gift") }
        var categoryId by remember { mutableStateOf(initialReward?.categoryId) }
        var isGeneral by remember { mutableStateOf(initialReward?.categoryId == null) }
        var useCustomPoints by remember { mutableStateOf(initialReward != null && initialReward.pointsCost !in pointChoices) }
        var customPoints by remember { mutableStateOf("${initialReward?.pointsCost ?: 100}") }
        var confirmDelete by remember { mutableStateOf(false) }
        val canSave = name.isNotBlank() && (isGeneral || categoryId != null)
        val categories = CategoryManager.categories

        fun save() {
            val category = categoryId?.let { id -> categories.firstOrNull { it.id == id } }
            val base = initialReward ?: Reward(name = name, pointsCost = pointsCost)
            val reward = base.copy(
                name = name.trim(),
                description = description.ifEmpty { null },
                pointsCost = pointsCost,
                frequency = frequency,
                icon = icon,
                categoryId = if (isGeneral) null else categoryId,
                categoryName = if (isGeneral) null else category?.name,
                lastModifiedDate = now(),
            )
            if (isEditing) RewardManager.updateReward(reward) else RewardManager.addReward(reward)
            dismiss()
        }

        if (confirmDelete && initialReward != null) {
            IOSAlert(
                RewardDeletion.title(initialReward),
                RewardDeletion.message(initialReward),
                RewardDeletion.actions(initialReward, { mode ->
                    dismiss()
                    onDelete?.invoke(initialReward, mode)
                }),
                { confirmDelete = false },
            )
        }

        Column(Modifier.fillMaxSize().background(Color.GroupedBackground)) {
            NavBar(
                (if (isEditing) "edit_reward" else "new_reward").localized,
                leading = { BarButton("cancel".localized, color = Color.Secondary, onClick = dismiss) },
                trailing = { BarButton("save".localized, enabled = canSave, bold = true, color = Color.SysPink, onClick = ::save) },
            )
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = 24.dp).navigationBarsPadding().imePadding(),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                ModernCard("reward_details".localized, "gift", Modifier.padding(horizontal = 16.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        FormLabelField("reward_name".localized, name, { name = it }, "enter_reward_name".localized, true)
                        FormLabelField("description".localized, description, { description = it }, "add_description".localized, false)
                        Row(
                            Modifier.fillMaxWidth().tap { navigator?.push { IconPickerView(icon) { icon = it } } }.padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            T("icon".localized, Fonts.subheadline.medium, Color.Primary, modifier = Modifier.weight(1f))
                            SF(icon, Color.SysPink, 20.dp)
                            Spacer(Modifier.width(8.dp))
                            SF("chevron.right", Color.Secondary, 14.dp)
                        }
                    }
                }
                ModernCard("category".localized, "folder.fill", Modifier.padding(horizontal = 16.dp).animateContentSize(tween(200))) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                T("use_specific_category".localized, Fonts.subheadline.medium, Color.Primary)
                                T("use_points_from_specific_category".localized, Fonts.caption, Color.Secondary)
                            }
                            Spacer(Modifier.width(8.dp))
                            ModernToggle(!isGeneral) {
                                isGeneral = !it
                                if (isGeneral) categoryId = null
                            }
                        }
                        if (!isGeneral) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                T("select_category".localized, Fonts.subheadline.medium, Color.Primary)
                                if (categories.isEmpty()) {
                                    T("no_categories_available".localized, Fonts.caption, Color.Secondary, modifier = Modifier.padding(vertical = 8.dp))
                                } else {
                                    categories.chunked(2).forEach { row ->
                                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                            row.forEach { category ->
                                                val selected = categoryId == category.id
                                                val color = colorFromHex(category.color)
                                                Column(
                                                    Modifier
                                                        .weight(1f)
                                                        .clip(RoundedCornerShape(12.dp))
                                                        .background(if (selected) color.copy(alpha = 0.1f) else Color.SysGray.copy(alpha = 0.05f))
                                                        .border(if (selected) 2.dp else 0.dp, if (selected) color else Color.Transparent, RoundedCornerShape(12.dp))
                                                        .pressable { categoryId = category.id }
                                                        .padding(vertical = 12.dp, horizontal = 6.dp),
                                                    horizontalAlignment = Alignment.CenterHorizontally,
                                                    verticalArrangement = Arrangement.spacedBy(8.dp),
                                                ) {
                                                    CategoryIconTile(category.displayIcon, color, 32.dp)
                                                    ShrinkText(category.name, Fonts.caption.medium, Color.Primary)
                                                }
                                            }
                                            if (row.size == 1) Spacer(Modifier.weight(1f))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ModernCard("points".localized, "star.fill", Modifier.padding(horizontal = 16.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            T("custom_points".localized, Fonts.subheadline.medium, Color.Primary, modifier = Modifier.weight(1f))
                            ModernToggle(useCustomPoints) { useCustomPoints = it }
                        }
                        Row(Modifier.height(100.dp), verticalAlignment = Alignment.CenterVertically) {
                            T("cost".localized, Fonts.subheadline.medium, Color.Primary, modifier = Modifier.weight(1f))
                            if (useCustomPoints) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    PlainField(
                                        customPoints,
                                        { text ->
                                            val filtered = text.filter { it.isDigit() }
                                            customPoints = filtered
                                            filtered.toIntOrNull()?.takeIf { it in 1..999 }?.let { pointsCost = it }
                                        },
                                        "points".localized,
                                        keyboard = KeyboardType.Number,
                                        align = TextAlign.Center,
                                        modifier = Modifier
                                            .width(104.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color.SysGray.copy(alpha = 0.1f))
                                            .padding(horizontal = 12.dp, vertical = 8.dp),
                                    )
                                    T("(1-999)", Fonts.caption, Color.Secondary, maxLines = 1)
                                }
                            } else {
                                WheelPicker(
                                    pointChoices.let { if (pointsCost in it) it else (it + pointsCost).sorted() },
                                    pointsCost,
                                    {
                                        pointsCost = it
                                        customPoints = "$it"
                                    },
                                    { "$it" },
                                    Modifier.width(80.dp),
                                    rowHeight = 32.dp,
                                    visibleRows = 3,
                                )
                            }
                        }
                        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            T("point_guidelines".localized + ":", Fonts.caption.medium, Color.Secondary)
                            T("• 1-10: " + "quick_rewards_worth".localized, Fonts.caption, Color.Secondary)
                            T("• 15-50: " + "regular_rewards_worth".localized, Fonts.caption, Color.Secondary)
                            T("• 75-200: " + "complex_rewards_worth".localized, Fonts.caption, Color.Secondary)
                            T("• 250-500: " + "premium_rewards_worth".localized, Fonts.caption, Color.Secondary)
                        }
                        val previewCategory = categoryId
                        if (isGeneral || previewCategory != null) {
                            val available = if (previewCategory != null) RewardManager.availablePointsForCategory(previewCategory, frequency) else RewardManager.availablePoints(frequency)
                            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                T(
                                    if (previewCategory != null) "available_category_points".localized.replace("{category}", categories.firstOrNull { it.id == previewCategory }?.name ?: "") else "available_total_points".localized,
                                    Fonts.caption.medium,
                                    Color.Secondary,
                                )
                                Row {
                                    T("$available " + "points".localized, Fonts.caption, if (available >= pointsCost) Color.SysGreen else Color.SysOrange, modifier = Modifier.weight(1f))
                                    if (available < pointsCost) T("need_more_points".localized.replace("{points}", "${pointsCost - available}"), Fonts.caption, Color.SysOrange)
                                }
                            }
                        }
                    }
                }
                ModernCard("frequency".localized, "repeat", Modifier.padding(horizontal = 16.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        SegmentedControl(RewardFrequency.entries, frequency, { frequency = it }, { it.pickerLabel })
                        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            T("point_accumulation_period".localized + ":", Fonts.caption.medium, Color.Secondary)
                            T(
                                when (frequency) {
                                    RewardFrequency.daily -> "daily_rewards_reset"
                                    RewardFrequency.weekly -> "weekly_rewards_accumulate"
                                    RewardFrequency.monthly -> "monthly_rewards_accumulate"
                                    RewardFrequency.yearly -> "yearly_rewards_accumulate"
                                    RewardFrequency.oneTime -> "onetime_rewards_once"
                                }.localized,
                                Fonts.caption,
                                Color.Secondary,
                            )
                        }
                    }
                }
                val tint = if (canSave) Color.SysPink else Color.SysGray
                Row(
                    Modifier
                        .padding(start = 16.dp, end = 16.dp, top = 8.dp)
                        .fillMaxWidth()
                        .shadow(if (canSave) 8.dp else 0.dp, RoundedCornerShape(16.dp), clip = false, ambientColor = Color.SysPink, spotColor = Color.SysPink)
                        .clip(RoundedCornerShape(16.dp))
                        .background(Brush.verticalGradient(listOf(tint, tint.copy(alpha = 0.8f))))
                        .pressable(enabled = canSave, onClick = ::save)
                        .padding(vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SF("checkmark", Color.White, 18.dp)
                    T("save_reward".localized, Fonts.headline, Color.White, maxLines = 1)
                }
                if (isEditing && initialReward != null) {
                    Column(Modifier.padding(horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        val count = initialReward.redemptions.size
                        if (count > 0) {
                            T(
                                (if (count == 1) "reward_history_summary_one" else "reward_history_summary").localized(count, initialReward.redemptions.max().dateStyle(FormatStyle.MEDIUM)),
                                Fonts.caption,
                                Color.Secondary,
                                TextAlign.Center,
                            )
                        }
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(Color.SysRed.copy(alpha = 0.1f))
                                .pressable { confirmDelete = true }
                                .padding(vertical = 14.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            SF("trash", Color.SysRed, 16.dp)
                            T("delete_reward".localized, Fonts.subheadline.semibold, Color.SysRed, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FormLabelField(label: String, value: String, onChange: (String) -> Unit, placeholder: String, singleLine: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        T(label, Fonts.subheadline.medium, Color.Primary)
        PlainField(
            value, onChange, placeholder,
            singleLine = singleLine,
            minLines = if (singleLine) 1 else 3,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(Color.SysGray.copy(alpha = 0.1f))
                .padding(horizontal = 16.dp, vertical = 12.dp),
        )
    }
}

// MARK: - History

private enum class PointsTimeFilter(val key: String, val icon: String, val shortKey: String) {
    all("all_time", "clock", "rewards_period_all"),
    day("today", "sun.max", "rewards_period_day"),
    week("this_week", "calendar.badge.clock", "rewards_period_week"),
    month("this_month", "calendar", "rewards_period_month"),
    year("this_year", "calendar.badge.plus", "rewards_period_year");

    fun matches(date: Date): Boolean {
        val time = now()
        return when (this) {
            all -> true
            day -> date.isSameDay(time)
            week -> date.startOfWeek().isSameDay(time.startOfWeek())
            month -> date.isSameMonth(time)
            year -> date.isSameYear(time)
        }
    }
}

@Composable
internal fun PointsHistoryView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    var filter by remember { mutableStateOf(PointsTimeFilter.all) }
    var selected by remember { mutableStateOf<Set<UUID>>(emptySet()) }
    var isEditMode by remember { mutableStateOf(false) }
    var showingReset by remember { mutableStateOf(false) }
    var showingRemove by remember { mutableStateOf(false) }

    val tasks = TaskManager.tasks.filter { it.hasRewardPoints }
        .mapNotNull { task -> task.completionDates.filter(filter::matches).takeIf { it.isNotEmpty() }?.let { task to it } }
        .sortedByDescending { (_, dates) -> dates.max() }

    if (showingReset) {
        IOSAlert(
            "reset_all_points".localized,
            "reset_all_points_alert".localized,
            listOf(AlertAction("cancel".localized, AlertRole.cancel), AlertAction("reset".localized, AlertRole.destructive) { RewardManager.resetAllPoints() }),
            { showingReset = false },
        )
    }
    if (showingRemove) {
        IOSAlert(
            "remove_selected_points".localized,
            "remove_selected_alert".localized,
            listOf(
                AlertAction("cancel".localized, AlertRole.cancel),
                AlertAction("remove".localized, AlertRole.destructive) {
                    selected.forEach { id -> TaskManager.task(id)?.let { RewardManager.removePointsFromTask(it) } }
                    selected = emptySet()
                    isEditMode = false
                },
            ),
            { showingRemove = false },
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "rewards_history_short".localized,
            leading = {
                if (isEditMode) {
                    BarButton("cancel".localized) {
                        isEditMode = false
                        selected = emptySet()
                    }
                } else {
                    IOSMenu(
                        buildList {
                            if (tasks.isNotEmpty()) add(MenuItem("edit".localized, "checkmark.circle") { isEditMode = true })
                            add(MenuItem("recalculate_from_tasks".localized, "arrow.clockwise") { RewardManager.recalculateDailyPointsFromSources() })
                            add(MenuItem("reset_all_points".localized, "trash", destructive = true) { showingReset = true })
                        },
                    ) { SF("ellipsis.circle", theme.primaryColor, 24.dp) }
                }
            },
            trailing = {
                if (isEditMode) BarButton("remove".localized, enabled = selected.isNotEmpty(), color = Color.SysRed) { showingRemove = true }
                else BarButton("done".localized, bold = true, onClick = dismiss)
            },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            StatsSegmentedControl(PointsTimeFilter.entries, filter, { filter = it }, { it.shortKey.localized })
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("+" + tasks.sumOf { (task, dates) -> dates.size * task.rewardPoints }.formatted(), "rewards_points_earned".localized, "plus.circle.fill", Color.SysGreen, Modifier.weight(1f))
                StatTile(tasks.sumOf { it.second.size }.formatted(), "stats_completed".localized, "checkmark.circle.fill", theme.primaryColor, Modifier.weight(1f))
            }
            if (tasks.isEmpty()) {
                StatsEmptyState(
                    filter.icon,
                    "no_points_for".localized.replace("{period}", filter.key.localized),
                    "complete_tasks_points_enabled".localized,
                    Modifier.clip(RoundedCornerShape(20.dp)).background(theme.surfaceColor),
                )
            } else {
                tasks.forEach { (task, dates) ->
                    key(task.id) {
                        TaskPointsCard(task, dates, task.id in selected, isEditMode) {
                            selected = if (task.id in selected) selected - task.id else selected + task.id
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TaskPointsCard(task: TodoTask, dates: List<Date>, isSelected: Boolean, isEditMode: Boolean, onToggle: () -> Unit) {
    val theme = theme
    val tint = task.category?.let { colorFromHex(it.color) } ?: theme.primaryColor
    val icon = if (task.icon.isEmpty() || task.icon == "circle") task.category?.displayIcon ?: "checkmark.circle" else task.icon
    val shape = RoundedCornerShape(20.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(theme.surfaceColor)
            .border(if (isSelected) 2.dp else 0.dp, if (isSelected) theme.primaryColor else Color.Transparent, shape)
            .tap { if (isEditMode) onToggle() }
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (isEditMode) {
            SF(if (isSelected) "checkmark.circle.fill" else "circle", if (isSelected) theme.primaryColor else theme.secondaryTextColor.copy(alpha = 0.5f), 24.dp, Modifier.padding(top = 10.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CategoryIconTile(icon, tint, 42.dp)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    T(task.name, Fonts.headline)
                    ShrinkText("${task.rewardPoints} " + "points_per_completion".localized, Fonts.caption, theme.secondaryTextColor, minScale = 0.85f)
                }
                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    T("+" + (dates.size * task.rewardPoints).formatted(), Fonts.headline.bold.monospacedDigit, Color.SysGreen, maxLines = 1)
                    T("${dates.size}×", Fonts.caption.semibold.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                }
            }
            if (dates.size > 1) DateChipsGrid(dates.sortedDescending(), tint, 6)
        }
    }
}

/** Recent dates as small chips on a fixed adaptive grid (never overflows, in any language). */
@Composable
private fun DateChipsGrid(dates: List<Date>, color: Color, limit: Int = 8) {
    val theme = theme
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns = (((maxWidth + 6.dp) / 70.dp).toInt()).coerceAtLeast(1)
        val texts: List<Pair<String, Boolean>> = dates.take(limit).map { it.skeleton("dMMM") to false } +
            (if (dates.size > limit) listOf("+${dates.size - limit}" to true) else emptyList())
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            texts.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    row.forEach { (text, more) ->
                        val tint = if (more) theme.secondaryTextColor else color
                        Box(Modifier.weight(1f).clip(CircleShape).background(tint.copy(alpha = 0.1f)).padding(vertical = 4.dp, horizontal = 2.dp), contentAlignment = Alignment.Center) {
                            ShrinkText(text, Fonts.caption2.medium, tint, minScale = 0.8f)
                        }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
internal fun RedeemedRewardsView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    var filter by remember { mutableStateOf(PointsTimeFilter.all) }
    val rewards = RewardManager.rewards
        .mapNotNull { reward -> reward.redemptions.filter(filter::matches).takeIf { it.isNotEmpty() }?.let { reward to it } }
        .sortedByDescending { (_, dates) -> dates.max() }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("rewards_redeemed_short".localized, trailing = { BarButton("done".localized, bold = true, onClick = dismiss) })
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            StatsSegmentedControl(PointsTimeFilter.entries, filter, { filter = it }, { it.shortKey.localized })
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatTile("-" + rewards.sumOf { (reward, dates) -> reward.pointsCost * dates.size }.formatted(), "rewards_points_spent".localized, "minus.circle.fill", Color.SysRed, Modifier.weight(1f))
                StatTile(rewards.sumOf { it.second.size }.formatted(), "rewards_redemptions".localized, "gift.fill", theme.primaryColor, Modifier.weight(1f))
            }
            if (rewards.isEmpty()) {
                StatsEmptyState(
                    "gift",
                    "no_rewards_redeemed_for".localized.replace("{period}", filter.key.localized),
                    "start_earning_redeem_first".localized,
                    Modifier.clip(RoundedCornerShape(20.dp)).background(theme.surfaceColor),
                )
            } else {
                rewards.forEach { (reward, dates) -> key(reward.id) { RedeemedRewardCard(reward, dates) } }
            }
        }
    }
}

@Composable
private fun RedeemedRewardCard(reward: Reward, dates: List<Date>) {
    val theme = theme
    val tint = reward.categoryId?.let { id -> CategoryManager.categories.firstOrNull { it.id == id } }?.let { colorFromHex(it.color) } ?: theme.primaryColor
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(theme.surfaceColor).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CategoryIconTile(reward.icon, tint, 42.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    T(reward.name, Fonts.headline, modifier = Modifier.weight(1f, fill = false))
                    if (reward.isArchived) {
                        T(
                            "reward_archived_tag".localized,
                            Fonts.caption2.semibold,
                            theme.secondaryTextColor,
                            maxLines = 1,
                            modifier = Modifier.clip(CircleShape).background(theme.secondaryTextColor.copy(alpha = 0.15f)).padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
                ShrinkText(reward.frequency.pickerLabel + " · " + "reward_last_on".localized(dates.max().dateStyle(FormatStyle.MEDIUM)), Fonts.caption, theme.secondaryTextColor, minScale = 0.85f)
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(1.dp)) {
                T("-" + (dates.size * reward.pointsCost).formatted(), Fonts.headline.bold.monospacedDigit, Color.SysRed, maxLines = 1)
                T("${dates.size}×", Fonts.caption.semibold.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
            }
        }
        if (dates.size > 1) DateChipsGrid(dates.sortedDescending(), tint)
    }
}

// MARK: - Breakdown

@Composable
internal fun CategoryPointsBreakdownView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val manager = RewardManager
    val categories = CategoryManager.categories
    val top = categories.filter { manager.totalPointsForCategory(it.id) > 0 }.sortedByDescending { manager.totalPointsForCategory(it.id) }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("points_overview".localized, trailing = { BarButton("done".localized, bold = true, color = theme.primaryColor, onClick = dismiss) })
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 40.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            val shape = RoundedCornerShape(24.dp)
            BoxWithConstraints(
                Modifier
                    .fillMaxWidth()
                    .shadow(16.dp, shape, clip = false, ambientColor = theme.primaryColor, spotColor = theme.primaryColor)
                    .clip(shape)
                    .background(Brush.linearGradient(listOf(theme.primaryColor, theme.primaryColor.copy(alpha = 0.7f), theme.secondaryColor.copy(alpha = 0.6f)))),
            ) {
                Box(Modifier.offset(x = maxWidth - 60.dp, y = (-40).dp).size(160.dp).background(Color.White.copy(alpha = 0.07f), CircleShape))
                Column(
                    Modifier.fillMaxWidth().padding(vertical = 28.dp, horizontal = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    T("available_points".localized.uppercase(appLocale), systemFont(12, FontWeight.SemiBold).copy(letterSpacing = androidx.compose.ui.unit.TextUnit(1.5f, androidx.compose.ui.unit.TextUnitType.Sp)), Color.White.copy(alpha = 0.75f), TextAlign.Center)
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        ShrinkText(manager.availablePoints(RewardFrequency.oneTime).formatted(), systemFont(56, FontWeight.Black).monospacedDigit, Color.White, Modifier.weight(1f, fill = false), minScale = 0.5f)
                        T("pts".localized, systemFont(20, FontWeight.SemiBold), Color.White.copy(alpha = 0.8f), maxLines = 1, modifier = Modifier.padding(bottom = 10.dp))
                    }
                    if (top.isNotEmpty()) {
                        Box(Modifier.padding(horizontal = 20.dp, vertical = 2.dp).fillMaxWidth().height(0.5.dp).background(Color.White.copy(alpha = 0.2f)))
                        Row(Modifier.padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            top.take(3).forEach { category ->
                                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                    Box(Modifier.size(10.dp).background(colorFromHex(category.color), CircleShape))
                                    ShrinkText(compactPoints(manager.totalPointsForCategory(category.id)), systemFont(13, FontWeight.Bold).monospacedDigit, Color.White)
                                    ShrinkText(category.name, systemFont(10, FontWeight.Medium), Color.White.copy(alpha = 0.75f))
                                }
                            }
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                T("points_by_period".localized, systemFont(17, FontWeight.SemiBold), modifier = Modifier.padding(horizontal = 2.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PeriodCard("rewards_period_day".localized, manager.availablePoints(RewardFrequency.daily), "sun.max.fill", listOf(Color(0xFFFF6B6B), Color(0xFFFF8E53)), Modifier.weight(1f))
                    PeriodCard("rewards_period_week".localized, manager.availablePoints(RewardFrequency.weekly), "calendar.circle.fill", listOf(Color(0xFF4ECDC4), Color(0xFF44A08D)), Modifier.weight(1f))
                    PeriodCard("rewards_period_month".localized, manager.availablePoints(RewardFrequency.monthly), "calendar.badge.clock", listOf(Color(0xFF45B7D1), Color(0xFF2980B9)), Modifier.weight(1f))
                    PeriodCard("rewards_period_year".localized, manager.availablePoints(RewardFrequency.yearly), "star.circle.fill", listOf(Color(0xFFFFD700), Color(0xFFFFA000)), Modifier.weight(1f))
                }
            }
            if (categories.isNotEmpty()) {
                val cardShape = RoundedCornerShape(20.dp)
                Column(
                    Modifier
                        .fillMaxWidth()
                        .shadow(if (theme.systemDark) 0.dp else 6.dp, cardShape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                        .clip(cardShape)
                        .background(theme.surfaceColor)
                        .padding(vertical = 18.dp, horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    T("points_by_category".localized, systemFont(17, FontWeight.SemiBold), modifier = Modifier.padding(horizontal = 2.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        categories.forEach { category -> key(category.id) { CategoryPointRow(category) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodCard(title: String, points: Int, icon: String, gradient: List<Color>, modifier: Modifier) {
    val theme = theme
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier
            .shadow(if (theme.systemDark) 0.dp else 6.dp, shape, clip = false, ambientColor = gradient[0], spotColor = gradient[0])
            .clip(shape)
            .background(theme.surfaceColor)
            .border(1.5.dp, Brush.linearGradient(gradient.map { it.copy(alpha = 0.4f) }), shape)
            .padding(horizontal = 4.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(38.dp).background(Brush.linearGradient(gradient), CircleShape), contentAlignment = Alignment.Center) { SF(icon, Color.White, 18.dp) }
        ShrinkText(compactPoints(points), systemFont(20, FontWeight.Bold).monospacedDigit, gradient[0])
        ShrinkText(title, systemFont(11, FontWeight.Medium), theme.secondaryTextColor, minScale = 0.7f)
    }
}

@Composable
private fun CategoryPointRow(category: Category) {
    val theme = theme
    val manager = RewardManager
    val color = colorFromHex(category.color)
    val total = manager.totalPointsForCategory(category.id)
    val periods = listOf(
        "daily" to manager.availablePointsForCategory(category.id, RewardFrequency.daily),
        "weekly" to manager.availablePointsForCategory(category.id, RewardFrequency.weekly),
        "monthly" to manager.availablePointsForCategory(category.id, RewardFrequency.monthly),
        "yearly" to manager.availablePointsForCategory(category.id, RewardFrequency.yearly),
    )
    val most = periods.maxOf { it.second }
    val ratio = if (most > 0) (total.toFloat() / (most * 4)).coerceAtMost(1f) else 0f
    val shape = RoundedCornerShape(14.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(color.copy(alpha = 0.05f)).border(1.dp, color.copy(alpha = 0.18f), shape).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CategoryIconTile(category.displayIcon, color, 36.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(category.name, systemFont(15, FontWeight.SemiBold))
                T("total_available_points".localized, systemFont(11), theme.secondaryTextColor)
            }
            ShrinkText(total.formatted(), systemFont(22, FontWeight.Bold).monospacedDigit, color, minScale = 0.7f)
        }
        Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(3.dp)).background(color.copy(alpha = 0.12f))) {
            Box(Modifier.fillMaxWidth(ratio).fillMaxHeight().clip(RoundedCornerShape(3.dp)).background(Brush.horizontalGradient(listOf(color, color.copy(alpha = 0.6f)))))
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            periods.forEach { (key, points) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(key.localized, systemFont(12, FontWeight.Medium), theme.secondaryTextColor, modifier = Modifier.weight(1f))
                    T(points.formatted() + " " + "pts".localized, systemFont(12, FontWeight.SemiBold).monospacedDigit, if (points > 0) color else theme.secondaryTextColor, maxLines = 1)
                }
            }
        }
    }
}
