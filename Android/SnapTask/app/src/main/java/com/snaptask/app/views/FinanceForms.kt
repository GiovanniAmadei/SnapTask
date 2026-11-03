package com.snaptask.app

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

private val fm = FinanceManager

// MARK: - Color picker

private val presetColors = listOf(
    "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#22C55E", "#10B981", "#14B8A6", "#06B6D4",
    "#3B82F6", "#6366F1", "#8B5CF6", "#A855F7", "#EC4899", "#F43F5E", "#84CC16", "#94A3B8",
)

@Composable
fun ColorPickerGrid(selected: String, onSelect: (String) -> Unit) {
    val presenter = LocalPresenter.current
    Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        presetColors.chunked(8).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { hex ->
                    Box(
                        Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .background(colorFromHex(hex), CircleShape)
                            .border(1.dp, Color.Primary.copy(alpha = 0.15f), CircleShape)
                            .tap { onSelect(hex) },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (selected.equals(hex, ignoreCase = true)) SF("checkmark", Color.White, 14.dp)
                    }
                }
            }
        }
        Row(
            Modifier.fillMaxWidth().tap { presenter.sheet(SheetDetent.fit) { CustomColorSheet(selected, onSelect) } },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            T("custom_colors".localized, Fonts.body, modifier = Modifier.weight(1f))
            Box(Modifier.size(28.dp).background(colorFromHex(selected), CircleShape).border(1.dp, Color.Primary.copy(alpha = 0.15f), CircleShape))
        }
    }
}

@Composable
fun CustomColorSheet(initial: String, onSelect: (String) -> Unit) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val start = remember {
        FloatArray(3).also { android.graphics.Color.colorToHSV(android.graphics.Color.parseColor(if (initial.startsWith("#")) initial else "#$initial"), it) }
    }
    var hue by remember { mutableStateOf(start[0]) }
    var saturation by remember { mutableStateOf(start[1]) }
    var brightness by remember { mutableStateOf(start[2]) }
    fun current() = Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, saturation, brightness)))

    Column(Modifier.fillMaxWidth().background(theme.backgroundColor).navigationBarsPadding()) {
        NavBar(
            "custom_colors".localized,
            leading = { BarButton("cancel".localized, onClick = dismiss) },
            trailing = {
                BarButton("done".localized, bold = true) {
                    onSelect(current().toHex())
                    dismiss()
                }
            },
        )
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Box(Modifier.fillMaxWidth().height(64.dp).clip(RoundedCornerShape(14.dp)).background(current()))
            GradientSlider(hue / 360f, (0..6).map { Color(android.graphics.Color.HSVToColor(floatArrayOf(it * 60f, 1f, 1f))) }) { hue = it * 360f }
            GradientSlider(saturation, listOf(Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, 0f, brightness))), Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, 1f, brightness))))) { saturation = it }
            GradientSlider(brightness, listOf(Color.Black, Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, saturation, 1f))))) { brightness = it }
        }
    }
}

@Composable
private fun GradientSlider(value: Float, colors: List<Color>, onChange: (Float) -> Unit) {
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(32.dp)
            .clip(CircleShape)
            .background(Brush.horizontalGradient(colors))
            .pointerInput(Unit) {
                detectTapGestures { onChange((it.x / size.width).coerceIn(0f, 1f)) }
            }
            .pointerInput(Unit) {
                detectDragGestures { change, _ -> onChange((change.position.x / size.width).coerceIn(0f, 1f)) }
            },
    ) {
        Box(
            Modifier
                .offset(x = (maxWidth - 28.dp) * value + 2.dp, y = 2.dp)
                .size(28.dp)
                .background(Color.White, CircleShape)
                .border(1.dp, Color.Black.copy(alpha = 0.15f), CircleShape),
        )
    }
}

// MARK: - Entry form

@Composable
fun FinanceEntryFormView(editingEntry: FinanceEntry?) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var name by remember { mutableStateOf(editingEntry?.name ?: "") }
    var amount by remember { mutableStateOf(editingEntry?.let { FinanceNumber.editableText(it.amount) } ?: "") }
    var isExpense by remember { mutableStateOf(editingEntry?.type?.isOutflow ?: true) }
    var category by remember { mutableStateOf(editingEntry?.category ?: FinanceCategory.other) }
    var customId by remember { mutableStateOf(editingEntry?.customCategoryId) }
    var date by remember { mutableStateOf(editingEntry?.date ?: now()) }
    var notes by remember { mutableStateOf(editingEntry?.notes ?: "") }
    var isRecurring by remember { mutableStateOf(editingEntry?.isRecurring ?: false) }
    var frequency by remember { mutableStateOf(editingEntry?.recurringFrequency ?: SubscriptionFrequency.monthly) }
    var hasEndDate by remember { mutableStateOf(editingEntry?.recurringEndDate != null) }
    var endDate by remember { mutableStateOf(editingEntry?.recurringEndDate ?: (editingEntry?.date ?: now()).addingYears(1)) }
    var confirmDelete by remember { mutableStateOf(false) }

    val categories = FinanceCategory.entries.filter { cat ->
        !fm.isHidden(cat) && if (isExpense) !cat.isIncomeCategory else cat.isIncomeCategory || cat == FinanceCategory.other || cat == FinanceCategory.gifts
    }
    val customCategories = fm.customCategories.filter { it.isExpenseCategory == isExpense }
    val canSave = name.isNotBlank() && (FinanceNumber.parse(amount) ?: 0.0) > 0

    fun setDirection(expense: Boolean) {
        isExpense = expense
        // Keep the category coherent with the direction just picked.
        if (customId != null && fm.customCategory(customId)?.isExpenseCategory != expense) customId = null
        val available = FinanceCategory.entries.filter { cat ->
            !fm.isHidden(cat) && if (expense) !cat.isIncomeCategory else cat.isIncomeCategory || cat == FinanceCategory.other || cat == FinanceCategory.gifts
        }
        if (customId == null && category !in available) category = if (expense) FinanceCategory.other else available.firstOrNull() ?: FinanceCategory.salary
    }

    fun save() {
        val value = FinanceNumber.parse(amount)?.takeIf { it > 0 } ?: return
        val original = editingEntry?.type
        val type = if (original != null && original.isOutflow == isExpense && original !in listOf(FinanceEntryType.income, FinanceEntryType.expense, FinanceEntryType.subscription)) {
            // Entries created elsewhere keep their type while the direction is unchanged.
            original
        } else if (isRecurring && isExpense) {
            FinanceEntryType.subscription
        } else if (isExpense) FinanceEntryType.expense else FinanceEntryType.income
        val end = if (isRecurring && hasEndDate) endDate else null
        val trimmedNotes = notes.takeIf { it.isNotBlank() }
        if (editingEntry != null) {
            fm.updateEntry(
                editingEntry.copy(
                    name = name.trim(), amount = value, type = type, category = category, customCategoryId = customId, date = date,
                    notes = trimmedNotes, isRecurring = isRecurring, recurringFrequency = if (isRecurring) frequency else null, recurringEndDate = end,
                ),
            )
        } else {
            fm.addEntry(
                FinanceEntry.create(
                    name = name.trim(), amount = value, type = type, category = category, customCategoryId = customId, date = date,
                    notes = trimmedNotes, isRecurring = isRecurring, recurringFrequency = if (isRecurring) frequency else null, recurringEndDate = end,
                ),
            )
        }
        dismiss()
    }

    if (confirmDelete) {
        ConfirmationDialog(
            title = "delete_entry_title".localized,
            actions = listOf(
                AlertAction("delete".localized, AlertRole.destructive) {
                    editingEntry?.let { fm.removeEntry(it) }
                    dismiss()
                },
                AlertAction("cancel".localized, AlertRole.cancel),
            ),
            onDismiss = { confirmDelete = false },
        )
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            (if (editingEntry != null) "edit_entry" else "new_entry").localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = { BarButton("save".localized, enabled = canSave, bold = true, color = theme.primaryColor, onClick = ::save) },
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = 32.dp).navigationBarsPadding().imePadding(),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            ModernCard("finance_direction".localized, "arrow.left.arrow.right", Modifier.padding(horizontal = 16.dp)) {
                Row {
                    DirectionButton("finance_outflow".localized, "arrow.up.circle.fill", Color.SysRed, isExpense, Modifier.weight(1f)) { setDirection(true) }
                    DirectionButton("finance_inflow".localized, "arrow.down.circle.fill", Color.SysGreen, !isExpense, Modifier.weight(1f)) { setDirection(false) }
                }
            }
            ModernCard("details".localized, "doc.text", Modifier.padding(horizontal = 16.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("entry_name".localized, Fonts.subheadline.medium)
                        BorderedField(name, { name = it }, "entry_name".localized)
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        T("amount".localized, Fonts.subheadline.medium)
                        var focused by remember { mutableStateOf(false) }
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(theme.backgroundColor)
                                .border(if (focused) 2.dp else 1.dp, if (focused) theme.primaryColor else theme.borderColor, RoundedCornerShape(10.dp))
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            T(fm.selectedCurrency.symbol, Fonts.title3.semibold, if (isExpense) Color.SysRed else Color.SysGreen, maxLines = 1)
                            PlainField(
                                amount, { amount = it }, FinanceNumber.placeholder,
                                style = Fonts.title3.semibold.monospacedDigit,
                                keyboard = KeyboardType.Decimal,
                                modifier = Modifier.weight(1f).onFocusChanged { focused = it.isFocused },
                            )
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T((if (isRecurring) "recurring_starts" else "date_and_time").localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                        CompactDateTime(date) {
                            date = it
                            if (endDate < it) endDate = it
                        }
                    }
                }
            }
            ModernCard("category".localized, "folder.fill", Modifier.padding(horizontal = 16.dp)) {
                val custom = fm.customCategory(customId)
                IOSMenu(
                    categories.map { cat ->
                        MenuItem(fm.displayName(cat), fm.icon(cat), checked = customId == null && category == cat) {
                            category = cat
                            customId = null
                        }
                    } + customCategories.map { item ->
                        MenuItem(item.name, item.icon, checked = customId == item.id) {
                            customId = item.id
                            category = FinanceCategory.other
                        }
                    },
                    Modifier.fillMaxWidth(),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(theme.backgroundColor)
                            .border(1.dp, theme.borderColor, RoundedCornerShape(10.dp))
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Box(Modifier.size(32.dp).clip(RoundedCornerShape(8.dp)).background(theme.primaryColor.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) {
                            SF(custom?.icon ?: category.icon, theme.primaryColor, 20.dp)
                        }
                        T(custom?.name ?: category.displayName, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                        SF("chevron.up.chevron.down", theme.secondaryTextColor, 15.dp)
                    }
                }
            }
            ModernCard("recurrence".localized, "repeat", Modifier.padding(horizontal = 16.dp).animateContentSize(tween(200))) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T("recurring".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                        IOSToggle(isRecurring, { isRecurring = it }, theme.primaryColor)
                    }
                    if (isRecurring) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            T("frequency".localized, Fonts.subheadline.medium)
                            ThemedSegmentedPicker(frequency, SubscriptionFrequency.entries, { frequency = it }, label = {
                                ShrinkText(it.displayName, Fonts.footnote.medium, minScale = 0.6f)
                            })
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                T("recurring_has_end".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                                IOSToggle(hasEndDate, { hasEndDate = it }, theme.primaryColor)
                            }
                            if (hasEndDate) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    T("end_date".localized, Fonts.subheadline.medium, modifier = Modifier.weight(1f))
                                    CompactDateTime(endDate, showTime = false, minDate = date) { endDate = it }
                                }
                            }
                        }
                    }
                }
            }
            ModernCard("notes".localized, "note.text", Modifier.padding(horizontal = 16.dp)) {
                BorderedField(notes, { notes = it }, "notes_optional".localized, singleLine = false, minLines = 2)
            }
            Row(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (editingEntry != null) {
                    Row(
                        Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(Color.SysRed.copy(alpha = 0.85f)).pressable { confirmDelete = true }.padding(vertical = 14.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SF("trash", theme.buttonTextColor, 18.dp)
                        T("delete".localized, Fonts.subheadline.semibold, theme.buttonTextColor, maxLines = 1)
                    }
                }
                val tint = if (canSave) Color.SysGreen else theme.secondaryTextColor
                Row(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Brush.verticalGradient(listOf(tint, tint.copy(alpha = 0.8f))))
                        .pressable(enabled = canSave, onClick = ::save)
                        .padding(vertical = 14.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SF("checkmark", theme.buttonTextColor, 18.dp)
                    T("save".localized, Fonts.subheadline.semibold, theme.buttonTextColor, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun DirectionButton(title: String, icon: String, color: Color, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val theme = theme
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier
            .clip(shape)
            .background(if (selected) color.copy(alpha = 0.1f) else Color.Transparent)
            .border(if (selected) 1.5.dp else 0.dp, if (selected) color.copy(alpha = 0.4f) else Color.Transparent, shape)
            .tap(onClick = onClick)
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SF(icon, if (selected) color else theme.secondaryTextColor.copy(alpha = 0.4f), 28.dp)
        ShrinkText(title, Fonts.subheadline.medium, if (selected) color else theme.secondaryTextColor.copy(alpha = 0.6f))
    }
}

@Composable
private fun BorderedField(value: String, onChange: (String) -> Unit, placeholder: String, singleLine: Boolean = true, minLines: Int = 1) {
    val theme = theme
    var focused by remember { mutableStateOf(false) }
    PlainField(
        value, onChange, placeholder,
        singleLine = singleLine,
        minLines = minLines,
        modifier = Modifier
            .fillMaxWidth()
            .onFocusChanged { focused = it.isFocused }
            .clip(RoundedCornerShape(10.dp))
            .background(theme.backgroundColor)
            .border(if (focused) 2.dp else 1.dp, if (focused) theme.primaryColor else theme.borderColor, RoundedCornerShape(10.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

/** Date (and time) in small chips that open the picker, as iOS's compact `DatePicker`. */
@Composable
fun CompactDateTime(date: Date, showTime: Boolean = true, minDate: Date? = null, onChange: (Date) -> Unit) {
    val presenter = LocalPresenter.current
    val theme = theme
    @Composable
    fun chip(text: String, onClick: () -> Unit) {
        T(
            text, Fonts.subheadline, theme.textColor, maxLines = 1,
            modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color.TertiaryFill).tap(onClick = onClick).padding(horizontal = 10.dp, vertical = 6.dp),
        )
    }
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        chip(date.skeleton("dMMMy")) {
            presenter.sheet(SheetDetent.fit) {
                var picked by remember { mutableStateOf(date) }
                Column(Modifier.fillMaxWidth().background(theme.backgroundColor).navigationBarsPadding()) {
                    val dismiss = LocalDismiss.current
                    NavBar("", trailing = {
                        BarButton("done".localized, bold = true) {
                            onChange(picked)
                            dismiss()
                        }
                    })
                    GraphicalDatePicker(picked, { picked = it.withTime(date.hour, date.minute, 0) }, Modifier.padding(horizontal = 12.dp), minDate = minDate)
                    Spacer(Modifier.height(12.dp))
                }
            }
        }
        if (showTime) {
            chip(date.timeText()) {
                presenter.sheet(SheetDetent.fit) {
                    var picked by remember { mutableStateOf(date) }
                    Column(Modifier.fillMaxWidth().background(theme.backgroundColor).navigationBarsPadding()) {
                        val dismiss = LocalDismiss.current
                        NavBar("", trailing = {
                            BarButton("done".localized, bold = true) {
                                onChange(picked)
                                dismiss()
                            }
                        })
                        TimeWheel(picked, { picked = it })
                        Spacer(Modifier.height(12.dp))
                    }
                }
            }
        }
    }
}

// MARK: - Settings

private fun amountText(value: Double, digits: Int = 2) = if (value != 0.0) FinanceNumber.editableText(value, digits) else ""

@Composable
private fun AmountRow(symbol: String?, trailingSymbol: String? = null, value: String, placeholder: String = FinanceNumber.placeholder, onChange: (String) -> Unit, onBlur: () -> Unit = {}, divider: Boolean = false) {
    val theme = theme
    var hadFocus by remember { mutableStateOf(false) }
    Column {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (symbol != null) T(symbol, Fonts.title3.semibold, theme.secondaryTextColor, maxLines = 1)
            PlainField(
                value, onChange, placeholder,
                style = Fonts.title3.semibold.monospacedDigit,
                keyboard = KeyboardType.Decimal,
                modifier = Modifier.weight(1f).onFocusChanged {
                    if (hadFocus && !it.isFocused) onBlur()
                    hadFocus = it.isFocused
                },
            )
            if (trailingSymbol != null) T(trailingSymbol, Fonts.title3.semibold, theme.secondaryTextColor, maxLines = 1)
        }
        if (divider) RowDivider()
    }
}

@Composable
private fun ValueRow(title: String, value: String, color: Color, divider: Boolean = false) {
    Column {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
            T(title, Fonts.body, modifier = Modifier.weight(1f))
            T(value, Fonts.subheadline.medium.monospacedDigit, color, maxLines = 1)
        }
        if (divider) RowDivider()
    }
}

@Composable
private fun SwipeHint(text: String? = null) {
    val theme = theme
    Column(Modifier.padding(horizontal = 32.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (text != null) T(text, Fonts.footnote, theme.secondaryTextColor)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            SF("arrow.left", theme.secondaryTextColor, 12.dp)
            T("swipe_to_edit_delete".localized, Fonts.caption, theme.secondaryTextColor)
        }
    }
}

@Composable
fun FinanceSettingsView() {
    val theme = theme
    val presenter = LocalPresenter.current
    val navigator = LocalNavigator.current
    var balance by remember { mutableStateOf(amountText(fm.startingBalance)) }
    var budget by remember { mutableStateOf(amountText(fm.monthlyBudgetTarget)) }
    var income by remember { mutableStateOf(amountText(fm.monthlyIncomeGoal)) }
    var savingsIsPercent by remember { mutableStateOf(fm.savingsGoalIsPercent) }
    var savings by remember { mutableStateOf(if (fm.savingsGoalIsPercent) amountText(fm.savingsGoalPercent, 1) else amountText(fm.savingsGoalAmount)) }
    var confirmReset by remember { mutableStateOf(false) }
    var categoryToHide by remember { mutableStateOf<FinanceCategory?>(null) }
    var customToDelete by remember { mutableStateOf<CustomFinanceCategory?>(null) }
    val symbol = fm.selectedCurrency.symbol

    fun commitBalance() {
        val value = FinanceNumber.parse(balance) ?: 0.0
        if (value != fm.startingBalance) fm.updateStartingBalance(value)
    }
    fun commitBudget() {
        val value = max(FinanceNumber.parse(budget) ?: 0.0, 0.0)
        if (value != fm.monthlyBudgetTarget) fm.updateMonthlyBudgetTarget(value)
    }
    fun commitIncome() {
        val value = max(FinanceNumber.parse(income) ?: 0.0, 0.0)
        if (value != fm.monthlyIncomeGoal) fm.updateMonthlyIncomeGoal(value)
    }
    fun commitSavings(isPercent: Boolean) {
        val value = max(FinanceNumber.parse(savings) ?: 0.0, 0.0)
        if (isPercent) {
            val clamped = min(value, 100.0)
            if (clamped != fm.savingsGoalPercent) fm.updateSavingsGoalPercent(clamped)
        } else if (value != fm.savingsGoalAmount) fm.updateSavingsGoalAmount(value)
    }
    DisposableEffect(Unit) {
        onDispose {
            commitBalance()
            commitBudget()
            commitSavings(savingsIsPercent)
            commitIncome()
        }
    }

    if (confirmReset) {
        IOSAlert(
            "reset_finance_confirm_title".localized,
            "reset_finance_confirm_message".localized,
            listOf(
                AlertAction("cancel".localized, AlertRole.cancel),
                AlertAction("reset".localized, AlertRole.destructive) {
                    fm.resetAll()
                    balance = ""
                    budget = ""
                    savings = ""
                    income = ""
                    savingsIsPercent = true
                },
            ),
            { confirmReset = false },
        )
    }
    categoryToHide?.let { cat ->
        IOSAlert(
            "hide_category".localized,
            "hide_category_message".localized + " '${fm.displayName(cat)}'?",
            listOf(AlertAction("cancel".localized, AlertRole.cancel), AlertAction("hide".localized, AlertRole.destructive) { fm.hideBuiltInCategory(cat) }),
            { categoryToHide = null },
        )
    }
    customToDelete?.let { cat ->
        IOSAlert(
            "delete_category".localized,
            "delete_category_message".localized + " '${cat.name}'?\n" + "delete_category_reassign_note".localized,
            listOf(AlertAction("cancel".localized, AlertRole.cancel), AlertAction("delete".localized, AlertRole.destructive) { fm.removeCustomCategory(cat, reassignEntries = true) }),
            { customToDelete = null },
        )
    }

    @Composable
    fun builtInSection(header: String, footer: @Composable () -> Unit, income: Boolean) {
        FormSection(header) {
            val cats = FinanceCategory.entries.filter { it.isIncomeCategory == income }
            cats.forEachIndexed { index, cat ->
                key(cat) {
                    val hidden = fm.isHidden(cat)
                    SwipeRow(
                        trailing = if (hidden) {
                            listOf(SwipeAction2("arrow.uturn.backward", "restore".localized, Color.SysBlue) { fm.restoreBuiltInCategory(cat) })
                        } else {
                            listOf(
                                SwipeAction2("pencil", "edit".localized, theme.primaryColor) { presenter.sheet { BuiltInCategoryFormView(cat) } },
                                SwipeAction2("trash", "delete".localized, Color.SysRed) { categoryToHide = cat },
                            )
                        },
                    ) {
                        Row(Modifier.fillMaxWidth().background(theme.surfaceColor).padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
                                SF(fm.icon(cat), if (hidden) theme.secondaryTextColor.copy(alpha = 0.4f) else colorFromHex(fm.colorHex(cat)).copy(alpha = 0.9f), 20.dp)
                            }
                            T(fm.displayName(cat), Fonts.body, modifier = Modifier.weight(1f).alpha(if (hidden) 0.4f else 1f))
                        }
                    }
                }
                if (index < cats.lastIndex) RowDivider()
            }
        }
        footer()
    }

    @Composable
    fun customSection(items: List<CustomFinanceCategory>) {
        if (items.isEmpty()) return
        FormSection {
            items.forEachIndexed { index, cat ->
                key(cat.id) {
                    SwipeRow(
                        trailing = listOf(
                            SwipeAction2("pencil", "edit".localized, theme.primaryColor) { presenter.sheet { CustomCategoryFormView(editing = cat) } },
                            SwipeAction2("trash", "delete".localized, Color.SysRed) { customToDelete = cat },
                        ),
                    ) {
                        Row(Modifier.fillMaxWidth().background(theme.surfaceColor).padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(cat.icon, colorFromHex(fm.colorHex(cat.id)).copy(alpha = 0.9f), 20.dp) }
                            T(cat.name, Fonts.body, modifier = Modifier.weight(1f))
                        }
                    }
                }
                if (index < items.lastIndex) RowDivider()
            }
        }
        SwipeHint()
    }

    @Composable
    fun addButton(title: String, onClick: () -> Unit) {
        FormRow(title, icon = "plus.circle.fill", iconTint = theme.primaryColor, titleColor = theme.primaryColor, divider = false, onClick = onClick)
    }

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar("finance_settings".localized)
        FormPage(Modifier.weight(1f)) {
            FormSection {
                FormRow("finance_cards_layout".localized, icon = "rectangle.3.group", chevron = true, divider = false, onClick = { navigator?.push { FinanceCardLayoutView() } })
            }
            FormSection("currency".localized, "currency_footer".localized) {
                IOSMenu(
                    SupportedCurrency.entries.map { currency ->
                        MenuItem(currency.displayName, checked = fm.selectedCurrency == currency) { fm.updateSelectedCurrency(currency) }
                    },
                    Modifier.fillMaxWidth(),
                ) { FormRow("currency".localized, value = fm.selectedCurrency.displayName, divider = false, trailing = { SF("chevron.up.chevron.down", Color.Secondary, 14.dp) }) }
            }
            FormSection("starting_balance".localized, "starting_balance_footer".localized) {
                AmountRow(symbol, value = balance, onChange = { balance = it }, onBlur = ::commitBalance)
            }
            FormSection("monthly_budget_target".localized, "monthly_budget_footer".localized) {
                AmountRow(symbol, value = budget, onChange = { budget = it }, onBlur = ::commitBudget, divider = fm.monthlyBudgetTarget > 0)
                if (fm.monthlyBudgetTarget > 0) {
                    ValueRow("current_spending".localized, fm.formatCurrency(fm.monthlyExpenses), if (fm.monthlyExpenses > fm.monthlyBudgetTarget) Color.SysRed else Color.SysGreen)
                }
            }
            FormSection("savings_goal".localized, (if (savingsIsPercent) "savings_goal_footer" else "savings_goal_amount_footer").localized) {
                Box(Modifier.padding(12.dp)) {
                    ThemedSegmentedPicker(savingsIsPercent, listOf(true, false), { newValue ->
                        // Keep what was typed for the previous mode, then show the stored value of the new one.
                        commitSavings(savingsIsPercent)
                        fm.updateSavingsGoalIsPercent(newValue)
                        savingsIsPercent = newValue
                        savings = if (newValue) amountText(fm.savingsGoalPercent, 1) else amountText(fm.savingsGoalAmount)
                    }, label = { T((if (it) "percentage" else "fixed_amount").localized, Fonts.footnote.medium, maxLines = 1) })
                }
                RowDivider()
                val showsCurrent = fm.savingsGoalConfigured && fm.monthlyIncome > 0
                if (savingsIsPercent) AmountRow(null, "%", savings, "0", { savings = it }, { commitSavings(true) }, showsCurrent)
                else AmountRow(symbol, value = savings, onChange = { savings = it }, onBlur = { commitSavings(false) }, divider = showsCurrent)
                if (showsCurrent) {
                    if (savingsIsPercent) {
                        ValueRow("current_savings_rate".localized, fm.formatPercent(fm.monthlySavingsRate, 1), if (fm.monthlySavingsRate * 100 >= fm.savingsGoalPercent) Color.SysGreen else Color.SysOrange)
                    } else {
                        val actual = max(fm.monthlyIncome - fm.monthlyExpenses, 0.0)
                        ValueRow("current_savings_rate".localized, fm.formatCurrency(actual), if (actual >= fm.savingsGoalAmount) Color.SysGreen else Color.SysOrange)
                    }
                }
            }
            FormSection("income_goal".localized, "income_goal_footer".localized) {
                AmountRow(symbol, value = income, onChange = { income = it }, onBlur = ::commitIncome, divider = fm.monthlyIncomeGoal > 0)
                if (fm.monthlyIncomeGoal > 0) {
                    ValueRow("current_income".localized, fm.formatCurrency(fm.monthlyIncome), if (fm.monthlyIncome >= fm.monthlyIncomeGoal) Color.SysGreen else Color.SysOrange)
                }
            }
            builtInSection("finance_outflow".localized, { SwipeHint("builtin_categories_footer".localized) }, false)
            customSection(fm.customCategories.filter { it.isExpenseCategory })
            FormSection { addButton("add_custom_category".localized) { presenter.sheet { CustomCategoryFormView(initialIsExpense = true) } } }
            builtInSection("finance_inflow".localized, { SwipeHint() }, true)
            customSection(fm.customCategories.filter { !it.isExpenseCategory })
            FormSection { addButton("add_custom_category".localized) { presenter.sheet { CustomCategoryFormView(initialIsExpense = false) } } }
            FormSection("category_budgets".localized) {
                fm.budgets.forEach { item ->
                    key(item.id) {
                        SwipeRow(
                            trailing = listOf(
                                SwipeAction2("pencil", "edit".localized, theme.primaryColor) { presenter.sheet { EditCategoryBudgetView(item) } },
                                SwipeAction2("trash", "delete".localized, Color.SysRed) { fm.removeBudget(item) },
                            ),
                        ) {
                            Row(Modifier.fillMaxWidth().background(theme.surfaceColor).padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(fm.budgetIcon(item), theme.primaryColor, 20.dp) }
                                T(fm.budgetDisplayName(item), Fonts.body, modifier = Modifier.weight(1f))
                                T(fm.formatCurrency(item.monthlyLimit), Fonts.subheadline.medium.monospacedDigit, theme.secondaryTextColor, maxLines = 1)
                                val usage = fm.budgetUsage(item)
                                if (usage > 0) T(fm.formatPercent(usage), Fonts.caption.bold.monospacedDigit, if (usage > 1) Color.SysRed else if (usage > 0.8) Color.SysOrange else Color.SysGreen, maxLines = 1)
                                SF("chevron.left", theme.secondaryTextColor.copy(alpha = 0.4f), 12.dp)
                            }
                        }
                    }
                    RowDivider()
                }
                addButton("add_category_budget".localized) { navigator?.push { AddCategoryBudgetView() } }
            }
            SwipeHint()
            FormSection("financial_goals".localized) {
                fm.financialGoals.forEach { goal ->
                    key(goal.id) {
                        SwipeRow(
                            trailing = listOf(
                                SwipeAction2("pencil", "edit".localized, theme.primaryColor) { presenter.sheet { NavigationStack { FinancialGoalFormView(goal) } } },
                                SwipeAction2("trash", "delete".localized, Color.SysRed) { fm.removeFinancialGoal(goal) },
                            ),
                        ) {
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .background(theme.surfaceColor)
                                    .tap { presenter.sheet { NavigationStack { FinancialGoalFormView(goal) } } }
                                    .padding(horizontal = 16.dp, vertical = 11.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(goal.type.icon, theme.primaryColor, 20.dp) }
                                T(goal.name, Fonts.body, modifier = Modifier.weight(1f))
                                T(fm.formatPercent(goal.progress), Fonts.caption.bold.monospacedDigit, if (goal.isCompleted) Color.SysGreen else theme.secondaryTextColor, maxLines = 1)
                            }
                        }
                    }
                    RowDivider()
                }
                addButton("add_financial_goal".localized) { presenter.sheet { NavigationStack { FinancialGoalFormView(null) } } }
            }
            if (fm.financialGoals.isNotEmpty()) SwipeHint()
            FormSection {
                FormRow("reset_finance_data".localized, icon = "trash", iconTint = Color.SysRed, titleColor = Color.SysRed, divider = false, onClick = { confirmReset = true })
            }
            Spacer(Modifier.height(tabBarInset()))
        }
    }
}

@Composable
internal fun AddCategoryBudgetView() {
    val theme = theme
    val dismiss = LocalDismiss.current
    val existingBuiltIn = fm.budgets.filter { it.customCategoryId == null }.map { it.category }.toSet()
    val availableBuiltIn = FinanceCategory.entries.filter { !it.isIncomeCategory && it !in existingBuiltIn && !fm.isHidden(it) }
    val existingCustom = fm.budgets.mapNotNull { it.customCategoryId }.toSet()
    val availableCustom = fm.customCategories.filter { it.isExpenseCategory && it.id !in existingCustom }
    var builtIn by remember { mutableStateOf(availableBuiltIn.firstOrNull()) }
    var custom by remember { mutableStateOf(if (availableBuiltIn.isEmpty()) availableCustom.firstOrNull()?.id else null) }
    var limit by remember { mutableStateOf("") }
    val parsed = FinanceNumber.parse(limit) ?: 0.0
    val hasAvailable = availableBuiltIn.isNotEmpty() || availableCustom.isNotEmpty()
    val canSave = hasAvailable && parsed > 0 && (custom != null || builtIn != null)

    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "add_category_budget".localized,
            trailing = {
                BarButton("save".localized, enabled = canSave, bold = true) {
                    val customId = custom
                    fm.addBudget(
                        if (customId != null) FinanceBudget(category = FinanceCategory.other, customCategoryId = customId, monthlyLimit = parsed)
                        else FinanceBudget(category = builtIn ?: FinanceCategory.other, monthlyLimit = parsed),
                    )
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("monthly_limit".localized) {
                if (hasAvailable) {
                    IOSMenu(
                        availableBuiltIn.map { cat ->
                            MenuItem(fm.displayName(cat), fm.icon(cat), checked = custom == null && builtIn == cat) {
                                builtIn = cat
                                custom = null
                            }
                        } + availableCustom.map { item ->
                            MenuItem(item.name, item.icon, checked = custom == item.id) { custom = item.id }
                        },
                        Modifier.fillMaxWidth(),
                    ) {
                        FormRow(
                            "category".localized,
                            value = fm.customCategory(custom)?.name ?: builtIn?.let { fm.displayName(it) } ?: "",
                            trailing = { SF("chevron.up.chevron.down", Color.Secondary, 14.dp) },
                        )
                    }
                } else {
                    T("budget_no_categories_left".localized, Fonts.body, theme.secondaryTextColor, modifier = Modifier.padding(16.dp))
                    RowDivider()
                }
                AmountRow(fm.selectedCurrency.symbol, value = limit, onChange = { limit = it })
            }
            Spacer(Modifier.height(tabBarInset()))
        }
    }
}

@Composable
internal fun EditCategoryBudgetView(budget: FinanceBudget) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var limit by remember { mutableStateOf(FinanceNumber.editableText(budget.monthlyLimit)) }
    val parsed = FinanceNumber.parse(limit) ?: 0.0
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "edit_budget".localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = parsed > 0, bold = true) {
                    fm.updateBudget(budget.copy(monthlyLimit = parsed))
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("monthly_limit".localized) {
                FormRow(fm.budgetDisplayName(budget), icon = fm.budgetIcon(budget))
                AmountRow(fm.selectedCurrency.symbol, value = limit, onChange = { limit = it })
            }
        }
    }
}

@Composable
private fun IconGrid(selected: String, onSelect: (String) -> Unit) {
    val theme = theme
    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        FinanceIconCatalog.icons.chunked(6).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                row.forEach { icon ->
                    val isSelected = selected == icon
                    Box(
                        Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isSelected) theme.primaryColor else theme.surfaceColor)
                            .border(1.dp, if (isSelected) theme.primaryColor else theme.borderColor.copy(alpha = 0.3f), RoundedCornerShape(8.dp))
                            .tap { onSelect(icon) },
                        contentAlignment = Alignment.Center,
                    ) { SF(icon, if (isSelected) Color.White else theme.secondaryTextColor, 22.dp) }
                }
                repeat(6 - row.size) { Spacer(Modifier.size(40.dp)) }
            }
        }
    }
}

@Composable
internal fun CustomCategoryFormView(editing: CustomFinanceCategory? = null, initialIsExpense: Boolean = true) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var name by remember { mutableStateOf(editing?.name ?: "") }
    var icon by remember { mutableStateOf(editing?.icon ?: "tag.fill") }
    var isExpense by remember { mutableStateOf(editing?.isExpenseCategory ?: initialIsExpense) }
    var color by remember { mutableStateOf(editing?.let { it.colorHex ?: fm.colorHex(it.id) } ?: if (initialIsExpense) "#EF4444" else "#22C55E") }
    val canSave = name.isNotBlank()
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            (if (editing != null) "edit_category" else "new_category").localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = canSave, bold = true) {
                    if (editing != null) fm.updateCustomCategory(editing.copy(name = name.trim(), icon = icon, colorHex = color, isExpenseCategory = isExpense))
                    else fm.addCustomCategory(CustomFinanceCategory(name = name.trim(), icon = icon, colorHex = color, isExpenseCategory = isExpense))
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("category_name".localized) { FieldRow(name, { name = it }, "category_name".localized, divider = false) }
            FormSection("category_type".localized) {
                Box(Modifier.padding(12.dp)) {
                    ThemedSegmentedPicker(isExpense, listOf(true, false), { isExpense = it }, label = { T((if (it) "finance_outflow" else "finance_inflow").localized, Fonts.footnote.medium, maxLines = 1) })
                }
            }
            FormSection("icon".localized) { IconGrid(icon) { icon = it } }
            FormSection("color".localized) { ColorPickerGrid(color) { color = it } }
        }
    }
}

@Composable
internal fun BuiltInCategoryFormView(category: FinanceCategory) {
    val theme = theme
    val dismiss = LocalDismiss.current
    val override = fm.override(category)
    val currentName = override?.customName ?: category.displayName
    val currentIcon = override?.customIcon ?: category.icon
    val currentColor = override?.customColorHex ?: fm.baseColorHex(category)
    var name by remember { mutableStateOf(currentName) }
    var icon by remember { mutableStateOf(currentIcon) }
    var color by remember { mutableStateOf(currentColor) }
    val hasChanges = name != currentName || icon != currentIcon || color != currentColor
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            "edit_category".localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = hasChanges, bold = true) {
                    val trimmed = name.trim()
                    fm.setCategoryOverride(
                        category,
                        trimmed.takeIf { it.isNotEmpty() && it != category.displayName },
                        icon.takeIf { it != category.icon },
                        color.takeIf { it != fm.baseColorHex(category) },
                    )
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("category_name".localized) { FieldRow(name, { name = it }, "category_name".localized, divider = false) }
            FormSection("icon".localized) { IconGrid(icon) { icon = it } }
            FormSection("color".localized) { ColorPickerGrid(color) { color = it } }
            if (override != null) {
                FormSection {
                    FormRow("reset_to_default".localized, icon = "arrow.uturn.backward", iconTint = Color.SysRed, titleColor = Color.SysRed, divider = false, onClick = {
                        fm.setCategoryOverride(category, null, null, null)
                        dismiss()
                    })
                }
            }
        }
    }
}

@Composable
fun FinancialGoalFormView(goal: FinancialGoal?) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var name by remember { mutableStateOf(goal?.name ?: "") }
    var type by remember { mutableStateOf(goal?.type ?: FinancialGoalType.savings) }
    var target by remember { mutableStateOf(goal?.let { FinanceNumber.editableText(it.targetAmount) } ?: "") }
    var current by remember { mutableStateOf(goal?.let { amountText(it.currentAmount) } ?: "") }
    var hasDeadline by remember { mutableStateOf(goal?.targetDate != null) }
    var deadline by remember { mutableStateOf(goal?.targetDate ?: now().addingMonths(6)) }
    var confirmDelete by remember { mutableStateOf(false) }
    val canSave = name.isNotBlank() && (FinanceNumber.parse(target) ?: 0.0) > 0
    val symbol = fm.selectedCurrency.symbol

    if (confirmDelete && goal != null) {
        ConfirmationDialog(
            title = goal.name,
            actions = listOf(
                AlertAction("delete".localized, AlertRole.destructive) {
                    fm.removeFinancialGoal(goal)
                    dismiss()
                },
                AlertAction("cancel".localized, AlertRole.cancel),
            ),
            onDismiss = { confirmDelete = false },
        )
    }
    Column(Modifier.fillMaxSize().background(theme.backgroundColor)) {
        NavBar(
            (if (goal == null) "new_financial_goal" else "edit_financial_goal").localized,
            leading = { BarButton("cancel".localized, color = theme.secondaryTextColor, onClick = dismiss) },
            trailing = {
                BarButton("save".localized, enabled = canSave, bold = true) {
                    val targetValue = FinanceNumber.parse(target) ?: return@BarButton
                    val currentValue = max(FinanceNumber.parse(current) ?: 0.0, 0.0)
                    val date = if (hasDeadline) deadline else null
                    if (goal != null) fm.updateFinancialGoal(goal.copy(name = name.trim(), type = type, targetAmount = targetValue, currentAmount = currentValue, targetDate = date))
                    else fm.addFinancialGoal(FinancialGoal(name = name.trim(), targetAmount = targetValue, currentAmount = currentValue, targetDate = date, type = type))
                    dismiss()
                }
            },
        )
        FormPage(Modifier.weight(1f)) {
            FormSection("goal_name".localized) {
                FieldRow(name, { name = it }, "goal_name".localized)
                IOSMenu(
                    FinancialGoalType.entries.map { item -> MenuItem(item.displayName, item.icon, checked = type == item) { type = item } },
                    Modifier.fillMaxWidth(),
                ) { FormRow("type".localized, value = type.displayName, divider = false, trailing = { SF("chevron.up.chevron.down", Color.Secondary, 14.dp) }) }
            }
            FormSection("goal_target_amount".localized) { AmountRow(symbol, value = target, onChange = { target = it }) }
            FormSection("goal_saved_amount".localized) { AmountRow(symbol, value = current, onChange = { current = it }) }
            FormSection {
                ToggleRow("goal_has_deadline".localized, hasDeadline, { hasDeadline = it }, divider = hasDeadline)
                if (hasDeadline) DateRow("deadline".localized, deadline, { deadline = it }, divider = false, minDate = now())
            }
            if (goal != null) {
                FormSection {
                    FormRow("delete".localized, icon = "trash", iconTint = Color.SysRed, titleColor = Color.SysRed, divider = false, onClick = { confirmDelete = true })
                }
            }
        }
    }
}

/** Reorder (drag) and show / hide the cards of the Finance screen. */
@Composable
fun FinanceCardLayoutView(showsDoneButton: Boolean = false) {
    val theme = theme
    val dismiss = LocalDismiss.current
    var raw by appStorage(FinanceCardLayout.storageKey, "")
    val layout = if (raw.isEmpty()) FinanceCardLayout.default else FinanceCardLayout.from(raw)
    val listState = rememberLazyListState()
    val reorder = rememberReorderableLazyListState(listState) { from, to ->
        val order = layout.order.toMutableList()
        val fromIndex = order.indexOfFirst { it == from.key }
        val toIndex = order.indexOfFirst { it == to.key }
        if (fromIndex >= 0 && toIndex >= 0) {
            order.add(toIndex, order.removeAt(fromIndex))
            raw = layout.copy(order = order).rawValue
        }
    }
    Column(Modifier.fillMaxSize().background(Color.GroupedBackground)) {
        NavBar(
            "finance_cards_layout".localized,
            background = Color.GroupedBackground,
            trailing = if (showsDoneButton) ({ BarButton("done".localized, bold = true, onClick = dismiss) }) else null,
        )
        LazyColumn(Modifier.weight(1f), state = listState, contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 32.dp)) {
            items(layout.order, key = { it }) { card ->
                ReorderableItem(reorder, key = card) { dragging ->
                    val visible = card !in layout.hidden
                    val index = layout.order.indexOf(card)
                    val shape = RoundedCornerShape(
                        topStart = if (index == 0) 12.dp else 0.dp,
                        topEnd = if (index == 0) 12.dp else 0.dp,
                        bottomStart = if (index == layout.order.lastIndex) 12.dp else 0.dp,
                        bottomEnd = if (index == layout.order.lastIndex) 12.dp else 0.dp,
                    )
                    Column(Modifier.clip(if (dragging) RoundedCornerShape(12.dp) else shape).background(theme.surfaceColor)) {
                        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) { SF(card.icon, if (visible) theme.primaryColor else theme.secondaryTextColor.copy(alpha = 0.4f), 20.dp) }
                            T(card.title, Fonts.body, modifier = Modifier.weight(1f).alpha(if (visible) 1f else 0.45f))
                            Box(
                                Modifier.size(36.dp, 32.dp).tap {
                                    raw = layout.copy(hidden = if (visible) layout.hidden + card else layout.hidden - card).rawValue
                                },
                                contentAlignment = Alignment.Center,
                            ) { SF(if (visible) "eye.fill" else "eye.slash", if (visible) theme.primaryColor else theme.secondaryTextColor.copy(alpha = 0.6f), 20.dp) }
                            Box(Modifier.size(32.dp).draggableHandle(), contentAlignment = Alignment.Center) { SF("line.3.horizontal", Color.Tertiary, 22.dp) }
                        }
                        if (index < layout.order.lastIndex) RowDivider(52.dp)
                    }
                }
            }
            item {
                T("finance_cards_footer".localized, Fonts.footnote, theme.secondaryTextColor, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 24.dp))
                val isDefault = layout == FinanceCardLayout.default
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(theme.surfaceColor)
                        .alpha(if (isDefault) 0.4f else 1f)
                        .tap(enabled = !isDefault) { raw = "" }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    SF("arrow.uturn.backward", theme.primaryColor, 18.dp)
                    T("reset_to_default".localized, Fonts.body, theme.primaryColor)
                }
            }
        }
    }
}
