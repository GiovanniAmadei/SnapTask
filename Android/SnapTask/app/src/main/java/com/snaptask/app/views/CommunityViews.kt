package com.snaptask.app

import android.icu.text.MeasureFormat
import android.icu.text.RelativeDateTimeFormatter
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import android.icu.util.ULocale
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.util.UUID

// MARK: - Dates

/** `RelativeDateTimeFormatter`: "2 days ago". */
fun relativeDateText(date: Date): String {
    val seconds = now().epochSecond - date.epochSecond
    val direction = if (seconds >= 0) RelativeDateTimeFormatter.Direction.LAST else RelativeDateTimeFormatter.Direction.NEXT
    val value = kotlin.math.abs(seconds)
    val formatter = RelativeDateTimeFormatter.getInstance(ULocale.forLocale(appLocale))
    fun format(amount: Long, unit: RelativeDateTimeFormatter.RelativeUnit) = formatter.format(amount.toDouble(), direction, unit)
    return when {
        value < 60 -> format(value, RelativeDateTimeFormatter.RelativeUnit.SECONDS)
        value < 3_600 -> format(value / 60, RelativeDateTimeFormatter.RelativeUnit.MINUTES)
        value < 86_400 -> format(value / 3_600, RelativeDateTimeFormatter.RelativeUnit.HOURS)
        value < 604_800 -> format(value / 86_400, RelativeDateTimeFormatter.RelativeUnit.DAYS)
        value < 2_629_800 -> format(value / 604_800, RelativeDateTimeFormatter.RelativeUnit.WEEKS)
        value < 31_557_600 -> format(value / 2_629_800, RelativeDateTimeFormatter.RelativeUnit.MONTHS)
        else -> format(value / 31_557_600, RelativeDateTimeFormatter.RelativeUnit.YEARS)
    }
}

/** `Text(date, style: .relative)`: the time passed, in its largest unit. */
private fun elapsedText(date: Date): String {
    val value = kotlin.math.abs(now().epochSecond - date.epochSecond)
    val format = MeasureFormat.getInstance(ULocale.forLocale(appLocale), MeasureFormat.FormatWidth.WIDE)
    fun measure(amount: Long, unit: MeasureUnit) = format.format(Measure(amount, unit))
    return when {
        value < 60 -> measure(value, MeasureUnit.SECOND)
        value < 3_600 -> measure(value / 60, MeasureUnit.MINUTE)
        value < 86_400 -> measure(value / 3_600, MeasureUnit.HOUR)
        value < 604_800 -> measure(value / 86_400, MeasureUnit.DAY)
        value < 2_629_800 -> measure(value / 604_800, MeasureUnit.WEEK)
        value < 31_557_600 -> measure(value / 2_629_800, MeasureUnit.MONTH)
        else -> measure(value / 31_557_600, MeasureUnit.YEAR)
    }
}

// MARK: - Feedback

private sealed class FeedbackFilter {
    data object AllMostVoted : FeedbackFilter()
    data object Recent : FeedbackFilter()
    data object Answered : FeedbackFilter()
    data object Completed : FeedbackFilter()
    data class ByCategory(val category: FeedbackCategory) : FeedbackFilter()

    val title: String
        get() = when (this) {
            AllMostVoted -> "all_category_filter".localized
            Recent -> "feedback_filter_recent".localized
            Answered -> "feedback_tab_answered".localized
            Completed -> "feedback_tab_completed".localized
            is ByCategory -> category.displayName
        }
    val icon: String
        get() = when (this) {
            AllMostVoted -> "flame.fill"
            Recent -> "clock.fill"
            Answered -> "person.badge.shield.checkmark.fill"
            Completed -> "checkmark.circle.fill"
            is ByCategory -> category.icon
        }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedbackView(focusFeedbackId: UUID? = null) {
    val theme = theme
    val presenter = LocalPresenter.current
    val manager = FeedbackManager
    var filter by remember { mutableStateOf<FeedbackFilter>(FeedbackFilter.AllMostVoted) }
    var searchText by remember { mutableStateOf("") }
    var searchExpanded by remember { mutableStateOf(false) }
    var expanded by remember { mutableStateOf<Set<UUID>>(emptySet()) }
    var toDelete by remember { mutableStateOf<FeedbackItem?>(null) }
    var didApplyFocus by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    LaunchedEffect(Unit) { manager.loadFeedback() }

    val query = searchText.trim()
    val visible = manager.feedbackItems.filter { it.status != FeedbackStatus.rejected }.filter {
        query.isEmpty() || it.title.contains(query, ignoreCase = true) || it.description.contains(query, ignoreCase = true)
    }
    val filtered = when (val current = filter) {
        FeedbackFilter.AllMostVoted -> visible.sortedByDescending { it.votes }
        FeedbackFilter.Recent -> visible.sortedByDescending { it.creationDate }
        FeedbackFilter.Answered -> visible.filter { item -> item.replies.any { it.isFromDeveloper } }.sortedByDescending { it.creationDate }
        FeedbackFilter.Completed -> visible.filter { it.status == FeedbackStatus.completed }.sortedByDescending { it.creationDate }
        is FeedbackFilter.ByCategory -> visible.filter { it.category == current.category }.sortedByDescending { it.votes }
    }

    // Opened from a developer-reply notification.
    LaunchedEffect(focusFeedbackId, manager.feedbackItems.map { it.id }) {
        val id = focusFeedbackId ?: return@LaunchedEffect
        if (didApplyFocus || manager.feedbackItems.none { it.id == id }) return@LaunchedEffect
        didApplyFocus = true
        filter = FeedbackFilter.AllMostVoted
        expanded = expanded + id
        val index = visible.sortedByDescending { it.votes }.indexOfFirst { it.id == id }
        if (index >= 0) listState.animateScrollToItem(index)
    }

    toDelete?.let { item ->
        IOSAlert(
            "delete_feedback_alert_title".localized,
            "delete_feedback_alert_message".localized,
            listOf(
                AlertAction("cancel".localized, AlertRole.cancel),
                AlertAction("delete".localized, AlertRole.destructive) { manager.deleteFeedback(item) },
            ),
            { toDelete = null },
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "community_title".localized,
            trailing = {
                Box(
                    Modifier
                        .size(32.dp)
                        .shadow(3.dp, CircleShape, clip = false, ambientColor = theme.accentColor, spotColor = theme.accentColor)
                        .background(theme.accentColor, CircleShape)
                        .pressable { presenter.sheet { NewFeedbackView() } },
                    contentAlignment = Alignment.Center,
                ) { SF("plus", Color.White, 18.dp) }
            },
        )
        // Header
        Row(
            Modifier
                .padding(start = 14.dp, end = 14.dp, top = 8.dp, bottom = 6.dp)
                .fillMaxWidth()
                .shadow(2.dp, RoundedCornerShape(14.dp), clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(RoundedCornerShape(14.dp))
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor, RoundedCornerShape(14.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp)
                .animateContentSize(tween(200)),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            val options = listOf(FeedbackFilter.AllMostVoted, FeedbackFilter.Recent, FeedbackFilter.Answered, FeedbackFilter.Completed) +
                FeedbackCategory.entries.map { FeedbackFilter.ByCategory(it) }
            IOSMenu(options.map { option -> MenuItem(option.title, option.icon, checked = filter == option) { filter = option } }) {
                Row(
                    Modifier.clip(RoundedCornerShape(12.dp)).background(theme.accentColor).padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SF(filter.icon, Color.White, 13.dp)
                    T(filter.title, Fonts.caption.semibold, Color.White, maxLines = 1)
                    SF("chevron.down", Color.White.copy(alpha = 0.9f), 11.dp)
                }
            }
            if (searchExpanded) {
                Row(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(theme.backgroundColor)
                        .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SF("magnifyingglass", theme.secondaryTextColor, 16.dp)
                    PlainField(searchText, { searchText = it }, "search_feedback_placeholder".localized, style = Fonts.subheadline, modifier = Modifier.weight(1f))
                    Box(
                        Modifier
                            .size(24.dp)
                            .background(theme.backgroundColor, CircleShape)
                            .tap {
                                searchText = ""
                                searchExpanded = false
                            },
                        contentAlignment = Alignment.Center,
                    ) { SF("xmark", theme.secondaryTextColor, 12.dp) }
                }
            } else {
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier
                        .size(34.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(theme.backgroundColor)
                        .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                        .tap { searchExpanded = true },
                    contentAlignment = Alignment.Center,
                ) { SF("magnifyingglass", theme.secondaryTextColor, 16.dp) }
            }
        }
        // List
        PullToRefreshBox(manager.isLoading, { manager.loadFeedback() }, Modifier.weight(1f)) {
            LazyColumn(
                Modifier.fillMaxSize(),
                state = listState,
                contentPadding = PaddingValues(start = 14.dp, end = 14.dp, top = 8.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(filtered, key = { it.id }) { item ->
                    FeedbackCard(
                        item,
                        item.id in expanded,
                        Modifier.animateItem(),
                        onToggle = { expanded = if (item.id in expanded) expanded - item.id else expanded + item.id },
                        onVote = { manager.toggleVote(item) },
                        onDelete = { toDelete = item },
                    )
                }
                if (filtered.isEmpty() && !manager.isLoading) {
                    item {
                        Column(Modifier.fillMaxWidth().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            SF("tray.fill", theme.secondaryTextColor, 40.dp)
                            T("no_feedback_found_title".localized, Fonts.headline, align = TextAlign.Center)
                            T("be_the_first_to_share_ideas".localized, Fonts.subheadline, theme.secondaryTextColor, TextAlign.Center, Modifier.padding(horizontal = 32.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FeedbackCard(item: FeedbackItem, isExpanded: Boolean, modifier: Modifier, onToggle: () -> Unit, onVote: () -> Unit, onDelete: () -> Unit) {
    val theme = theme
    val devReply = item.replies.firstOrNull { it.isFromDeveloper }
    val categoryColor = colorFromHex(item.category.color)
    val statusColor = colorFromHex(item.status.color)
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier
            .fillMaxWidth()
            .shadow(2.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(1.dp, if (devReply != null) theme.accentColor.copy(alpha = if (isExpanded) 0.4f else 0.2f) else theme.borderColor, shape)
            .padding(12.dp)
            .animateContentSize(tween(250)),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                Modifier.clip(RoundedCornerShape(6.dp)).background(categoryColor.copy(alpha = 0.15f)).padding(horizontal = 7.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SF(item.category.icon, categoryColor, 11.dp)
                T(item.category.displayName, Fonts.caption2.semibold, categoryColor, maxLines = 1)
            }
            Row(
                Modifier.clip(RoundedCornerShape(6.dp)).background(statusColor.copy(alpha = 0.12f)).padding(horizontal = 6.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(Modifier.size(6.dp).background(statusColor, CircleShape))
                T(item.status.displayName, Fonts.caption2.semibold, statusColor, maxLines = 1)
            }
            Spacer(Modifier.weight(1f))
            if (item.isAuthoredByCurrentUser) {
                Box(Modifier.size(22.dp).background(Color.SysRed.copy(alpha = 0.1f), CircleShape).tap(onClick = onDelete), contentAlignment = Alignment.Center) {
                    SF("trash", Color.SysRed.copy(alpha = 0.85f), 11.dp)
                }
            }
        }
        Column(Modifier.fillMaxWidth().tap(onClick = onToggle), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            T(item.title, Fonts.subheadline.bold)
            T(item.description, Fonts.footnote, theme.secondaryTextColor, maxLines = if (isExpanded) Int.MAX_VALUE else 2)
            if (!isExpanded && item.description.length > 110) {
                Row(Modifier.padding(top = 1.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    T("feedback_tap_to_read_more".localized, Fonts.caption2, theme.accentColor, maxLines = 1)
                    SF("chevron.down", theme.accentColor, 11.dp)
                }
            }
        }
        if (isExpanded) {
            Column(Modifier.padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.padding(vertical = 2.dp).fillMaxWidth().height(0.5.dp).background(theme.borderColor.copy(alpha = 0.6f)))
                devReply?.let { DeveloperReplyBox(it) }
                val others = item.replies.filter { !it.isFromDeveloper }
                if (others.isNotEmpty()) {
                    T("feedback_replies_title".localized, Fonts.caption.semibold, theme.secondaryTextColor)
                    others.forEach { ReplyCard(it) }
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.weight(1f).height(28.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                SF("person.circle.fill", theme.secondaryTextColor, 11.dp)
                T(item.authorName ?: "feedback_anonymous".localized, Fonts.caption2.medium, theme.secondaryTextColor, maxLines = 1, modifier = Modifier.weight(1f, fill = false))
                if (item.isAuthoredByCurrentUser) T("feedback_you_indicator".localized, Fonts.caption2.bold, theme.accentColor, maxLines = 1)
                T("•", Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
                T(elapsedText(item.creationDate), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
            }
            if (devReply != null) {
                Row(
                    Modifier
                        .height(28.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(theme.accentColor.copy(alpha = if (isExpanded) 0.18f else 0.12f))
                        .border(1.dp, theme.accentColor.copy(alpha = if (isExpanded) 0.45f else 0.28f), RoundedCornerShape(8.dp))
                        .pressable(onClick = onToggle)
                        .padding(horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    SF("person.badge.shield.checkmark.fill", theme.accentColor, 11.dp)
                    T("feedback_read_dev_reply".localized, Fonts.caption2.bold, theme.accentColor, maxLines = 1)
                    SF(if (isExpanded) "chevron.up" else "chevron.down", theme.accentColor, 9.dp)
                }
            }
            val voteTint = if (item.hasVoted) Color.SysRed else theme.secondaryTextColor
            Row(
                Modifier
                    .scale(if (item.hasVoted) 1.04f else 1f)
                    .height(28.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (item.hasVoted) Color.SysRed.copy(alpha = 0.12f) else theme.backgroundColor)
                    .border(1.dp, if (item.hasVoted) Color.SysRed.copy(alpha = 0.3f) else theme.borderColor, RoundedCornerShape(14.dp))
                    .pressable(onClick = onVote)
                    .padding(horizontal = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SF(if (item.hasVoted) "heart.fill" else "heart", voteTint, 13.dp)
                T(item.votes.toString(), Fonts.caption.semibold, if (item.hasVoted) Color.SysRed else theme.textColor, maxLines = 1)
            }
        }
    }
}

@Composable
private fun DeveloperReplyBox(reply: FeedbackReply) {
    val theme = theme
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(theme.accentColor.copy(alpha = 0.09f))
            .border(1.dp, theme.accentColor.copy(alpha = 0.3f), RoundedCornerShape(10.dp))
            .padding(11.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SF("person.badge.shield.checkmark.fill", theme.accentColor, 16.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    T(reply.authorName ?: "Giovanni (Developer)", Fonts.caption.bold, theme.accentColor, maxLines = 1)
                    SF("checkmark.seal.fill", theme.accentColor, 10.dp)
                }
                T("feedback_official_dev_response".localized, systemFont(10, FontWeight.Normal), theme.secondaryTextColor)
            }
            // Replies written from the console may have no date.
            if (reply.creationDate.epochSecond > 86_400) T(elapsedText(reply.creationDate), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
        }
        T(reply.content, Fonts.footnote, modifier = Modifier.padding(top = 2.dp))
    }
}

@Composable
private fun ReplyCard(reply: FeedbackReply) {
    val theme = theme
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(theme.backgroundColor)
            .border(1.dp, theme.borderColor, RoundedCornerShape(8.dp))
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.padding(top = 2.dp)) {
            SF(if (reply.isFromDeveloper) "person.badge.shield.checkmark.fill" else "person.circle.fill", if (reply.isFromDeveloper) theme.accentColor else theme.secondaryTextColor, 14.dp)
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T(reply.authorName ?: "feedback_anonymous".localized, Fonts.caption2.semibold, if (reply.isFromDeveloper) theme.accentColor else theme.textColor, modifier = Modifier.weight(1f))
                T(elapsedText(reply.creationDate), Fonts.caption2, theme.secondaryTextColor, maxLines = 1)
            }
            T(reply.content, Fonts.footnote)
        }
    }
}

@Composable
internal fun NewFeedbackView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val scope = rememberCoroutineScope()
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var category by remember { mutableStateOf(FeedbackCategory.featureRequest) }
    var authorName by remember { mutableStateOf("") }
    var anonymous by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    val canSubmit = title.isNotEmpty() && description.isNotEmpty() && !submitting

    if (failed) {
        IOSAlert("feedback_submission_failed_alert_title".localized, "feedback_submission_failed_alert_message".localized, listOf(AlertAction("OK", AlertRole.cancel)), { failed = false })
    }

    @Composable
    fun card(icon: String, tint: Color, label: String, content: @Composable ColumnScope.() -> Unit) {
        val shape = RoundedCornerShape(16.dp)
        Column(
            Modifier
                .fillMaxWidth()
                .shadow(4.dp, shape, clip = false)
                .clip(shape)
                .background(Color.SystemBackground)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SF(icon, tint, 20.dp)
                T(label, Fonts.headline.semibold)
            }
            content()
        }
    }
    @Composable
    fun field(value: String, onChange: (String) -> Unit, placeholder: String, singleLine: Boolean = true) {
        PlainField(
            value, onChange, placeholder, singleLine = singleLine, minLines = if (singleLine) 1 else 5,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Gray6)
                .border(1.dp, Color.Secondary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                .padding(16.dp),
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("new_feedback".localized, leading = { BarButton("close_button".localized, onClick = dismiss) })
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).imePadding().navigationBarsPadding().padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SF("bubble.left.and.bubble.right.fill", Color.SysBlue, 28.dp)
                T("share_your_feedback_title".localized, Fonts.title3.bold, align = TextAlign.Center)
            }
            card("tag.fill", Color.SysBlue, "feedback_category_title".localized) {
                FeedbackCategory.entries.chunked(2).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { option ->
                            val color = colorFromHex(option.color)
                            val selected = option == category
                            Column(
                                Modifier
                                    .weight(1f)
                                    .scale(if (selected) 1.02f else 1f)
                                    .height(80.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (selected) color.copy(alpha = if (theme.isDark) 0.3f else 0.15f) else Color.Gray6)
                                    .border(2.dp, if (selected) color else Color.Transparent, RoundedCornerShape(12.dp))
                                    .tap { category = option },
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically),
                            ) {
                                SF(option.icon, color, 22.dp)
                                T(option.displayName, Fonts.caption.semibold, if (selected) color else Color.Primary, TextAlign.Center, maxLines = 2)
                            }
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
            card("text.cursor", Color.SysGreen, "feedback_title_label".localized) { field(title, { title = it }, "feedback_title_placeholder".localized) }
            card("doc.text.fill", Color.SysOrange, "description".localized) { field(description, { description = it }, "feedback_description_placeholder".localized, singleLine = false) }
            card("person.fill", Color.SysPurple, "author_info_title".localized) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T("submit_anonymously_toggle".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                    IOSToggle(anonymous, { anonymous = it })
                }
                if (!anonymous) field(authorName, { authorName = it }, "author_name_placeholder".localized)
            }
            Row(
                Modifier
                    .padding(bottom = 32.dp)
                    .fillMaxWidth()
                    .alpha(if (title.isEmpty() || description.isEmpty()) 0.6f else 1f)
                    .shadow(6.dp, RoundedCornerShape(16.dp), clip = false, ambientColor = Color.SysBlue, spotColor = Color.SysBlue)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(Color.SysBlue, Color.SysPurple)))
                    .pressable(enabled = canSubmit) {
                        submitting = true
                        scope.launch {
                            val item = FeedbackItem(
                                title = title,
                                description = description,
                                category = category,
                                authorId = FeedbackManager.currentUserId(),
                                authorName = if (anonymous) null else authorName.ifEmpty { null },
                            )
                            val success = FeedbackManager.submitFeedback(item)
                            submitting = false
                            if (success) dismiss() else failed = true
                        }
                    }
                    .padding(vertical = 18.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (submitting) androidx.compose.material3.CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
                else SF("paperplane.fill", Color.White, 20.dp)
                T((if (submitting) "submitting_button" else "submit_feedback_button").localized, Fonts.headline.semibold, Color.White)
            }
        }
    }
}

// MARK: - What's new

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WhatsNewView() {
    val theme = theme
    val service = UpdateNewsService
    val scope = rememberCoroutineScope()
    var selectedTab by remember { mutableStateOf(0) }
    val tabs = listOf("recent_tab".localized, "coming_soon_tab".localized, "roadmap_tab".localized)
    LaunchedEffect(Unit) {
        service.markAsViewed()
        service.fetchNews()
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "whats_cooking_title".localized,
            trailing = {
                if (service.isLoading) androidx.compose.material3.CircularProgressIndicator(Modifier.padding(end = 8.dp).size(18.dp), color = theme.accentColor, strokeWidth = 2.dp)
                else BarIcon("arrow.clockwise", theme.primaryColor) { scope.launch { service.fetchNews() } }
            },
        )
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 16.dp)) {
            tabs.forEachIndexed { index, tab ->
                val selected = selectedTab == index
                Column(Modifier.weight(1f).tap { selectedTab = index }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ShrinkText(tab, systemFont(16, if (selected) FontWeight.SemiBold else FontWeight.Medium), if (selected) theme.accentColor else theme.secondaryTextColor)
                    Box(Modifier.fillMaxWidth().height(2.dp).background(if (selected) theme.accentColor else Color.Transparent))
                }
            }
        }
        PullToRefreshBox(service.isLoading, { scope.launch { service.fetchNews() } }, Modifier.weight(1f)) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                when {
                    service.isLoading && service.newsItems.isEmpty() -> repeat(3) { NewsItemSkeleton() }
                    selectedTab == 0 -> RecentUpdates(service.newsItems)
                    else -> {
                        val news = service.news(if (selectedTab == 1) NewsType.comingSoon else NewsType.roadmap)
                        if (news.isEmpty()) EmptyNews(selectedTab) else news.forEach { key(it.id) { NewsItemCard(it) } }
                    }
                }
            }
        }
    }
}

private fun compareVersions(first: String, second: String): Int {
    val a = first.split(".").mapNotNull { it.toIntOrNull() }
    val b = second.split(".").mapNotNull { it.toIntOrNull() }
    for (index in 0 until maxOf(a.size, b.size)) {
        val difference = a.getOrElse(index) { 0 } - b.getOrElse(index) { 0 }
        if (difference != 0) return difference
    }
    return 0
}

@Composable
private fun RecentUpdates(items: List<UpdateNews>) {
    val groups = items.filter { it.type == NewsType.recentUpdate && it.version != null }
        .groupBy { it.version!! }
        .toList()
        .sortedWith { first, second -> compareVersions(second.first, first.first) }
    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        groups.forEach { (version, updates) -> key(version) { VersionSection(version, updates) } }
    }
}

@Composable
private fun VersionSection(version: String, updates: List<UpdateNews>) {
    val theme = theme
    var expanded by remember { mutableStateOf(true) }
    Column(Modifier.animateContentSize(tween(300)), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .shadow(2.dp, RoundedCornerShape(12.dp), clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
                .clip(RoundedCornerShape(12.dp))
                .background(theme.surfaceColor)
                .border(1.dp, theme.borderColor, RoundedCornerShape(12.dp))
                .tap { expanded = !expanded }
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                T("${"version".localized} $version", systemFont(20, FontWeight.Bold))
                updates.firstOrNull()?.date?.let { T(relativeDateText(it), systemFont(14, FontWeight.Medium), theme.secondaryTextColor) }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                T("${updates.size}", systemFont(14, FontWeight.SemiBold), theme.accentColor, maxLines = 1)
                T(if (updates.size == 1) "update" else "updates", systemFont(14, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1)
                SF(if (expanded) "chevron.down" else "chevron.right", theme.secondaryTextColor, 12.dp)
            }
        }
        if (expanded) {
            Column(Modifier.padding(start = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                updates.sortedWith(newsOrder).forEach { key(it.id) { CompactNewsCard(it) } }
            }
        }
    }
}

@Composable
private fun NewsItemCard(news: UpdateNews) {
    val theme = theme
    val color = colorFromHex(news.type.color)
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(4.dp, shape, clip = false, ambientColor = theme.shadowColor, spotColor = theme.shadowColor)
            .clip(shape)
            .background(theme.surfaceColor)
            .border(if (news.isHighlighted) 2.dp else 1.dp, if (news.isHighlighted) Color.SysYellow.copy(alpha = 0.4f) else theme.borderColor, shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(36.dp).background(color.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) { SF(news.type.icon, color, 18.dp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row {
                    T(news.title, systemFont(18, FontWeight.Bold), modifier = Modifier.weight(1f))
                    if (news.isHighlighted) SF("star.fill", Color.SysYellow, 14.dp)
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    T(news.type.displayName, systemFont(12, FontWeight.SemiBold), color, maxLines = 1, modifier = Modifier.clip(CircleShape).background(color.copy(alpha = 0.15f)).padding(horizontal = 8.dp, vertical = 4.dp))
                    news.version?.takeIf { version -> version.any { it.isDigit() } }?.let {
                        T("v$it", systemFont(12, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1, modifier = Modifier.clip(CircleShape).background(theme.surfaceColor).padding(horizontal = 8.dp, vertical = 4.dp))
                    }
                    Spacer(Modifier.weight(1f))
                    news.date?.let { T(relativeDateText(it), systemFont(12, FontWeight.Medium), theme.secondaryTextColor, maxLines = 1) }
                }
            }
        }
        T(news.description, systemFont(15, FontWeight.Normal), theme.secondaryTextColor)
    }
}

@Composable
private fun CompactNewsCard(news: UpdateNews) {
    val theme = theme
    val color = colorFromHex(news.type.color)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(theme.backgroundColor)
            .border(if (news.isHighlighted) 2.dp else 1.dp, if (news.isHighlighted) Color.SysYellow.copy(alpha = 0.3f) else theme.borderColor, RoundedCornerShape(10.dp))
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(28.dp).background(color.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) { SF(news.type.icon, color, 14.dp) }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row {
                T(news.title, systemFont(16, FontWeight.SemiBold), modifier = Modifier.weight(1f))
                if (news.isHighlighted) SF("star.fill", Color.SysYellow, 12.dp)
            }
            T(news.description, systemFont(14, FontWeight.Normal), theme.secondaryTextColor)
        }
    }
}

@Composable
private fun NewsItemSkeleton() {
    val theme = theme
    val bone = theme.secondaryTextColor.copy(alpha = 0.3f)
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(theme.surfaceColor).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(36.dp).background(bone, CircleShape))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.fillMaxWidth().height(18.dp).background(bone))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(80.dp, 12.dp).background(bone))
                    Box(Modifier.size(60.dp, 12.dp).background(bone))
                    Spacer(Modifier.weight(1f))
                    Box(Modifier.size(70.dp, 12.dp).background(bone))
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(14.dp).background(bone))
        Box(Modifier.fillMaxWidth().height(14.dp).background(bone))
    }
}

@Composable
private fun EmptyNews(tab: Int) {
    val theme = theme
    val (icon, title, subtitle) = when (tab) {
        1 -> Triple("clock", "Stay Tuned!", "Exciting features are in development")
        2 -> Triple("map", "Planning Ahead", "Our roadmap will be shared soon")
        else -> Triple("info.circle", "Nothing Here", "No items to display")
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 60.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SF(icon, theme.secondaryTextColor, 48.dp)
        T(title, systemFont(20, FontWeight.SemiBold), align = TextAlign.Center)
        T(subtitle, systemFont(16, FontWeight.Normal), theme.secondaryTextColor, TextAlign.Center)
    }
}

// MARK: - Calendar

private val CalendarProvider.calendars: List<DeviceCalendar>
    get() = when (this) {
        CalendarProvider.apple -> AppleCalendarService.writableCalendars()
        CalendarProvider.google -> AppleCalendarService.writableCalendars().filter { it.accountType == "com.google" }
    }

private fun openCalendarAppSettings() {
    runCatching {
        App.context.startActivity(
            android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${App.context.packageName}"))
                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}

@Composable
fun CalendarIntegrationView() {
    val theme = theme
    val navigator = LocalNavigator.current
    val presenter = LocalPresenter.current
    val manager = CalendarIntegrationManager
    val feed = CalendarEventsFeed
    val settings = manager.settings
    val scope = rememberCoroutineScope()
    var isLoading by remember { mutableStateOf(false) }
    var settingsAlert by remember { mutableStateOf(false) }
    // Read again after every permission answer.
    var permissionTick by remember { mutableStateOf(0) }
    var afterPermission by remember { mutableStateOf<((Boolean) -> Unit)?>(null) }
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        permissionTick++
        val granted = results.values.all { it }
        afterPermission?.invoke(granted)
        afterPermission = null
    }
    fun withAccess(action: (Boolean) -> Unit) {
        if (AppleCalendarService.hasReadAccess && AppleCalendarService.hasWriteAccess) {
            action(true)
            return
        }
        afterPermission = { granted ->
            if (!granted) settingsAlert = true
            action(granted)
        }
        launcher.launch(arrayOf(android.Manifest.permission.READ_CALENDAR, android.Manifest.permission.WRITE_CALENDAR))
    }
    val canRead = remember(permissionTick) { AppleCalendarService.hasReadAccess }

    if (settingsAlert) {
        IOSAlert(
            "calendar_access_required".localized,
            "calendar_access_required_message".localized,
            listOf(AlertAction("open_settings".localized) { openCalendarAppSettings() }, AlertAction("cancel".localized, AlertRole.cancel)),
            { settingsAlert = false },
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("calendar_integration".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection("integration".localized, "sync_tasks_calendar_automatically".localized) {
                ToggleRow(
                    "enable_calendar_integration".localized, settings.isEnabled,
                    { value ->
                        manager.updateSettings(manager.settings.copy(isEnabled = value))
                        if (value) withAccess { }
                    },
                    divider = false,
                )
            }
            // Independent of the toggle above, which only writes tasks to the calendar.
            FormSection("calendar_events_feed_header".localized, "show_calendar_events_footer".localized) {
                val showing = feed.isEnabled && canRead
                ToggleRow(
                    "show_calendar_events".localized, showing,
                    { value ->
                        if (!value) feed.updateEnabled(false) else withAccess { granted -> if (granted) feed.updateEnabled(true) }
                    },
                    divider = showing,
                )
                if (showing) FormRow("visible_calendars".localized, chevron = true, divider = false, onClick = { navigator?.push { VisibleCalendarsView() } })
            }
            if (settings.isEnabled) {
                FormSection("calendar_provider".localized) {
                    CalendarProvider.entries.forEachIndexed { index, provider ->
                        FormRow(
                            provider.displayName,
                            icon = provider.iconName,
                            iconTint = if (provider == CalendarProvider.apple) theme.primaryColor else theme.secondaryColor,
                            divider = index < CalendarProvider.entries.lastIndex,
                            onClick = {
                                manager.updateSettings(manager.settings.copy(provider = provider, selectedCalendarId = null, selectedCalendarName = null))
                                withAccess { }
                            },
                            trailing = { if (settings.provider == provider) SF("checkmark", theme.accentColor, 18.dp) },
                        )
                    }
                }
                FormSection("calendar_selection".localized) {
                    FormRow(
                        "selected_calendar".localized, value = settings.selectedCalendarName ?: "none".localized, chevron = true, divider = false,
                        onClick = { withAccess { granted -> if (granted) presenter.sheet { CalendarSelectionView() } } },
                    )
                }
                FormSection("sync_options".localized) {
                    ToggleRow("auto_sync_task_creation".localized, settings.autoSyncOnTaskCreate, { manager.updateSettings(manager.settings.copy(autoSyncOnTaskCreate = it)) })
                    ToggleRow("auto_sync_task_updates".localized, settings.autoSyncOnTaskUpdate, { manager.updateSettings(manager.settings.copy(autoSyncOnTaskUpdate = it)) })
                    ToggleRow("sync_completed_tasks".localized, settings.autoSyncOnTaskComplete, { manager.updateSettings(manager.settings.copy(autoSyncOnTaskComplete = it)) })
                    ToggleRow("sync_recurring_tasks".localized, settings.syncRecurringTasks, { manager.updateSettings(manager.settings.copy(syncRecurringTasks = it)) }, divider = false)
                }
                FormSection("status".localized) {
                    val connected = remember(permissionTick, settings.provider) {
                        AppleCalendarService.hasWriteAccess && settings.provider.calendars.isNotEmpty()
                    }
                    FormRow("provider_status".localized, trailing = {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Box(Modifier.size(8.dp).background(if (connected) theme.accentColor else Color.SysRed, CircleShape))
                            val reason = if (settings.provider == CalendarProvider.apple && !AppleCalendarService.hasWriteAccess) "calendar_status_access_needed" else "not_connected"
                            T((if (connected) "connected" else reason).localized, Fonts.body, theme.secondaryTextColor, maxLines = 1)
                        }
                    })
                    FormRow("sync_status".localized, value = manager.syncStatus.displayText)
                    val synced = remember(manager.syncStatus) { manager.getSyncedTasksCount() }
                    FormRow("synced_events".localized, value = "$synced")
                    val canSync = !isLoading && settings.selectedCalendarId != null
                    FormRow(
                        "sync_all_tasks_now".localized, titleColor = if (canSync) theme.accentColor else theme.secondaryTextColor, divider = synced > 0 || isLoading,
                        onClick = if (canSync) ({
                            isLoading = true
                            scope.launch {
                                manager.syncAllTasksToCalendar(TaskManager.tasks)
                                isLoading = false
                            }
                        }) else null,
                    )
                    if (synced > 0) {
                        FormRow(
                            "delete_all_synced_tasks".localized, titleColor = Color.SysRed, divider = isLoading,
                            onClick = if (!isLoading) ({
                                isLoading = true
                                scope.launch {
                                    manager.deleteAllSyncedTasksFromCalendar()
                                    isLoading = false
                                }
                            }) else null,
                        )
                    }
                    if (isLoading) {
                        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            androidx.compose.material3.CircularProgressIndicator(Modifier.size(16.dp), color = theme.accentColor, strokeWidth = 2.dp)
                            T("syncing".localized, Fonts.body, theme.secondaryTextColor)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarRow(calendar: DeviceCalendar, selected: Boolean, divider: Boolean, onClick: () -> Unit) {
    val theme = theme
    Row(
        Modifier.fillMaxWidth().tap(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(12.dp).background(Color(calendar.color), CircleShape))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(calendar.title, Fonts.body)
            T(calendar.accountName, Fonts.caption, theme.secondaryTextColor)
        }
        if (selected) SF("checkmark", theme.accentColor, 18.dp)
    }
    if (divider) RowDivider(40.dp)
}

@Composable
internal fun CalendarSelectionView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val manager = CalendarIntegrationManager
    val calendars = remember { manager.settings.provider.calendars }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("select_calendar".localized, trailing = { BarButton("done".localized, color = theme.accentColor, onClick = dismiss) })
        FormPage(Modifier.weight(1f)) {
            FormSection {
                calendars.forEachIndexed { index, calendar ->
                    CalendarRow(calendar, manager.settings.selectedCalendarId == calendar.id, index < calendars.lastIndex) {
                        manager.updateSettings(manager.settings.copy(selectedCalendarId = calendar.id, selectedCalendarName = calendar.title))
                    }
                }
            }
        }
    }
}

/** Which calendars appear in the day list (birthdays, holidays and subscriptions included). */
@Composable
internal fun VisibleCalendarsView() {
    val theme = theme
    val feed = CalendarEventsFeed
    val calendars = remember { AppleCalendarService.allEventCalendars().sortedBy { it.title.lowercase() } }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("visible_calendars".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection {
                calendars.forEachIndexed { index, calendar ->
                    CalendarRow(calendar, calendar.id !in feed.hiddenCalendarIds, index < calendars.lastIndex) {
                        feed.setHidden(if (calendar.id in feed.hiddenCalendarIds) feed.hiddenCalendarIds - calendar.id else feed.hiddenCalendarIds + calendar.id)
                    }
                }
            }
        }
    }
}
