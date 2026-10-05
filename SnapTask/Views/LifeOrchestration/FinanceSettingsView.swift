import SwiftUI

struct FinanceSettingsView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    private enum SettingsField: Hashable {
        case balance, budget, savings, income
    }
    
    @FocusState private var focusedField: SettingsField?
    @State private var balanceText: String
    @State private var budgetText: String
    @State private var savingsText: String
    @State private var savingsIsPercent: Bool
    @State private var incomeText: String
    @State private var showingResetConfirm = false
    @State private var editingGoal: FinancialGoal? = nil
    @State private var showingAddGoal = false
    @State private var showingAddCategory = false
    @State private var newCategoryIsExpense: Bool = true
    @State private var editingCategory: CustomFinanceCategory? = nil
    @State private var showingBuiltInCategoryEdit = false
    @State private var builtInCategoryToEdit: FinanceCategory = .other
    @State private var categoryToHide: FinanceCategory? = nil
    @State private var showingHideBuiltInAlert = false
    @State private var customCategoryToDelete: CustomFinanceCategory? = nil
    @State private var showingDeleteCustomAlert = false
    @State private var editingBudget: FinanceBudget? = nil
    @State private var showingEditBudget = false
    
    /// The fields are filled in here (not in `onAppear`) so that setting the savings mode does not
    /// trigger the mode-change handler and overwrite the stored goal.
    init() {
        let manager = FinanceManager.shared
        func text(_ value: Double, digits: Int = 2) -> String {
            value != 0 ? FinanceNumber.editableText(value, fractionDigits: digits) : ""
        }
        _balanceText = State(initialValue: text(manager.startingBalance))
        _budgetText = State(initialValue: text(manager.monthlyBudgetTarget))
        _incomeText = State(initialValue: text(manager.monthlyIncomeGoal))
        _savingsIsPercent = State(initialValue: manager.savingsGoalIsPercent)
        _savingsText = State(initialValue: manager.savingsGoalIsPercent
            ? text(manager.savingsGoalPercent, digits: 1)
            : text(manager.savingsGoalAmount))
    }
    
    private var currencySymbol: String {
        financeManager.selectedCurrency.symbol
    }
    
    private var expenseCustomCategories: [CustomFinanceCategory] {
        financeManager.customCategories.filter { $0.isExpenseCategory }
    }
    
    private var incomeCustomCategories: [CustomFinanceCategory] {
        financeManager.customCategories.filter { !$0.isExpenseCategory }
    }
    
    var body: some View {
        Form {
            // Order of the cards on the Finance screen
            Section {
                NavigationLink(destination: FinanceCardLayoutView()) {
                    HStack {
                        Image(systemName: "rectangle.3.group")
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text("finance_cards_layout".localized)
                            .themedPrimaryText()
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
            
            // Currency
            Section {
                Picker("currency".localized, selection: Binding(
                    get: { financeManager.selectedCurrency },
                    set: { financeManager.setSelectedCurrency($0) }
                )) {
                    ForEach(SupportedCurrency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
                .contentShape(Rectangle())
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("currency".localized)
                    .themedSecondaryText()
            } footer: {
                Text("currency_footer".localized)
                    .themedSecondaryText()
            }
            
            // Starting Balance
            Section {
                HStack {
                    Text(currencySymbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField(FinanceNumber.placeholder, text: $balanceText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
                        .focused($focusedField, equals: .balance)
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("starting_balance".localized)
                    .themedSecondaryText()
            } footer: {
                Text("starting_balance_footer".localized)
                    .themedSecondaryText()
            }
            
            // Monthly Budget Target
            Section {
                HStack {
                    Text(currencySymbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField(FinanceNumber.placeholder, text: $budgetText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
                        .focused($focusedField, equals: .budget)
                }
                .listRowBackground(theme.surfaceColor)
                
                if financeManager.monthlyBudgetTarget > 0 {
                    HStack {
                        Text("current_spending".localized)
                            .themedPrimaryText()
                        Spacer()
                        Text(formatCurrency(financeManager.monthlyExpenses))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundColor(financeManager.monthlyExpenses > financeManager.monthlyBudgetTarget ? .red : .green)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            } header: {
                Text("monthly_budget_target".localized)
                    .themedSecondaryText()
            } footer: {
                Text("monthly_budget_footer".localized)
                    .themedSecondaryText()
            }
            
            // Savings Goal
            Section {
                ThemedSegmentedPicker(selection: $savingsIsPercent, options: [true, false]) { isPercent in
                    Text(isPercent ? "percentage".localized : "fixed_amount".localized)
                }
                .listRowBackground(theme.surfaceColor)
                .onChange(of: savingsIsPercent) { oldValue, newValue in
                    // Keep what was typed for the previous mode, then show the stored value of the new one.
                    commitSavings(isPercent: oldValue)
                    financeManager.setSavingsGoalIsPercent(newValue)
                    savingsText = savingsFieldText(isPercent: newValue)
                }
                
                if savingsIsPercent {
                    HStack {
                        TextField("0", text: $savingsText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .themedPrimaryText()
                            .focused($focusedField, equals: .savings)
                        Text("%")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .listRowBackground(theme.surfaceColor)
                } else {
                    HStack {
                        Text(currencySymbol)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(theme.secondaryTextColor)
                        TextField(FinanceNumber.placeholder, text: $savingsText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .themedPrimaryText()
                            .focused($focusedField, equals: .savings)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
                
                if financeManager.savingsGoalConfigured && financeManager.monthlyIncome > 0 {
                    HStack {
                        Text("current_savings_rate".localized)
                            .themedPrimaryText()
                        Spacer()
                        if savingsIsPercent {
                            Text(financeManager.formatPercent(financeManager.monthlySavingsRate, maxFractionDigits: 1))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .foregroundColor(financeManager.monthlySavingsRate * 100 >= financeManager.savingsGoalPercent ? .green : .orange)
                        } else {
                            let actualSavings = max(financeManager.monthlyIncome - financeManager.monthlyExpenses, 0)
                            Text(formatCurrency(actualSavings))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .foregroundColor(actualSavings >= financeManager.savingsGoalAmount ? .green : .orange)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            } header: {
                Text("savings_goal".localized)
                    .themedSecondaryText()
            } footer: {
                Text(savingsIsPercent ? "savings_goal_footer".localized : "savings_goal_amount_footer".localized)
                    .themedSecondaryText()
            }
            
            // Monthly Income Goal
            Section {
                HStack {
                    Text(currencySymbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField(FinanceNumber.placeholder, text: $incomeText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
                        .focused($focusedField, equals: .income)
                }
                .listRowBackground(theme.surfaceColor)
                
                if financeManager.monthlyIncomeGoal > 0 {
                    HStack {
                        Text("current_income".localized)
                            .themedPrimaryText()
                        Spacer()
                        Text(formatCurrency(financeManager.monthlyIncome))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundColor(financeManager.monthlyIncome >= financeManager.monthlyIncomeGoal ? .green : .orange)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            } header: {
                Text("income_goal".localized)
                    .themedSecondaryText()
            } footer: {
                Text("income_goal_footer".localized)
                    .themedSecondaryText()
            }
            
            // Expense built-in categories
            Section {
                ForEach(FinanceCategory.allCases.filter { !$0.isIncomeCategory }, id: \.self) { cat in
                    HStack {
                        Image(systemName: financeManager.icon(for: cat))
                            .foregroundColor(
                                financeManager.isHidden(cat)
                                    ? theme.secondaryTextColor.opacity(0.4)
                                    : Color(hex: financeManager.colorHex(for: cat)).opacity(0.9)
                            )
                            .frame(width: 24)
                        Text(financeManager.displayName(for: cat))
                            .themedPrimaryText()
                            .opacity(financeManager.isHidden(cat) ? 0.4 : 1)
                        Spacer()
                    }
                    .listRowBackground(theme.surfaceColor)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if financeManager.isHidden(cat) {
                            Button {
                                financeManager.restoreBuiltInCategory(cat)
                            } label: {
                                Label("restore".localized, systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        } else {
                            Button(role: .destructive) {
                                categoryToHide = cat
                                showingHideBuiltInAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                            Button {
                                builtInCategoryToEdit = cat
                                showingBuiltInCategoryEdit = true
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(theme.primaryColor)
                        }
                    }
                }
            } header: {
                Text("finance_outflow".localized)
                    .themedSecondaryText()
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("builtin_categories_footer".localized)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                        Text("swipe_to_edit_delete".localized)
                            .font(.caption)
                    }
                }
                .themedSecondaryText()
            }
            
            // Expense custom categories (deletable)
            if !expenseCustomCategories.isEmpty {
                Section {
                    ForEach(expenseCustomCategories) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundColor(Color(hex: financeManager.colorHex(for: cat.id)).opacity(0.9))
                                .frame(width: 24)
                            Text(cat.name)
                                .themedPrimaryText()
                            Spacer()
                        }
                        .listRowBackground(theme.surfaceColor)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                customCategoryToDelete = cat
                                showingDeleteCustomAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                            Button {
                                editingCategory = cat
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(theme.primaryColor)
                        }
                    }
                } footer: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                        Text("swipe_to_edit_delete".localized)
                            .font(.caption)
                    }
                    .themedSecondaryText()
                }
            }
            
            // Add expense category button
            Section {
                Button {
                    newCategoryIsExpense = true
                    showingAddCategory = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.primaryColor)
                        Text("add_custom_category".localized)
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
            
            // Income built-in categories
            Section {
                ForEach(FinanceCategory.allCases.filter { $0.isIncomeCategory }, id: \.self) { cat in
                    HStack {
                        Image(systemName: financeManager.icon(for: cat))
                            .foregroundColor(
                                financeManager.isHidden(cat)
                                    ? theme.secondaryTextColor.opacity(0.4)
                                    : Color(hex: financeManager.colorHex(for: cat)).opacity(0.9)
                            )
                            .frame(width: 24)
                        Text(financeManager.displayName(for: cat))
                            .themedPrimaryText()
                            .opacity(financeManager.isHidden(cat) ? 0.4 : 1)
                        Spacer()
                    }
                    .listRowBackground(theme.surfaceColor)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if financeManager.isHidden(cat) {
                            Button {
                                financeManager.restoreBuiltInCategory(cat)
                            } label: {
                                Label("restore".localized, systemImage: "arrow.uturn.backward")
                            }
                            .tint(.blue)
                        } else {
                            Button(role: .destructive) {
                                categoryToHide = cat
                                showingHideBuiltInAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                            Button {
                                builtInCategoryToEdit = cat
                                showingBuiltInCategoryEdit = true
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(theme.primaryColor)
                        }
                    }
                }
            } header: {
                Text("finance_inflow".localized)
                    .themedSecondaryText()
            } footer: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.caption2)
                    Text("swipe_to_edit_delete".localized)
                        .font(.caption)
                }
                .themedSecondaryText()
            }
            
            // Income custom categories (deletable)
            if !incomeCustomCategories.isEmpty {
                Section {
                    ForEach(incomeCustomCategories) { cat in
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundColor(Color(hex: financeManager.colorHex(for: cat.id)).opacity(0.9))
                                .frame(width: 24)
                            Text(cat.name)
                                .themedPrimaryText()
                            Spacer()
                        }
                        .listRowBackground(theme.surfaceColor)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                customCategoryToDelete = cat
                                showingDeleteCustomAlert = true
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                            Button {
                                editingCategory = cat
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(theme.primaryColor)
                        }
                    }
                } footer: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                        Text("swipe_to_edit_delete".localized)
                            .font(.caption)
                    }
                    .themedSecondaryText()
                }
            }
            
            // Add income category button
            Section {
                Button {
                    newCategoryIsExpense = false
                    showingAddCategory = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.primaryColor)
                        Text("add_custom_category".localized)
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .listRowBackground(theme.surfaceColor)
            }
            
            // Category Budgets
            Section {
                ForEach(financeManager.budgets) { budget in
                    HStack {
                        Image(systemName: financeManager.budgetIcon(for: budget))
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text(financeManager.budgetDisplayName(for: budget))
                            .themedPrimaryText()
                        Spacer()
                        Text(formatCurrency(budget.monthlyLimit))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .themedSecondaryText()
                        
                        let usage = financeManager.budgetUsage(for: budget)
                        if usage > 0 {
                            Text(financeManager.formatPercent(usage))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundColor(usage > 1 ? .red : usage > 0.8 ? .orange : .green)
                        }
                        
                        // Swipe hint indicator
                        Image(systemName: "chevron.left")
                            .font(.caption2)
                            .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    .listRowBackground(theme.surfaceColor)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            financeManager.removeBudget(budget)
                        } label: {
                            Label("delete".localized, systemImage: "trash")
                        }
                        Button {
                            editingBudget = budget
                            showingEditBudget = true
                        } label: {
                            Label("edit".localized, systemImage: "pencil")
                        }
                        .tint(theme.primaryColor)
                    }
                }

                NavigationLink(destination: AddCategoryBudgetView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.primaryColor)
                        Text("add_category_budget".localized)
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("category_budgets".localized)
                    .themedSecondaryText()
            } footer: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.caption2)
                    Text("swipe_to_edit_delete".localized)
                        .font(.caption)
                }
                .themedSecondaryText()
            }
            
            // Savings goals
            Section {
                ForEach(financeManager.financialGoals) { goal in
                    HStack {
                        Image(systemName: goal.type.icon)
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text(goal.name)
                            .themedPrimaryText()
                        Spacer()
                        Text(financeManager.formatPercent(goal.progress))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(goal.isCompleted ? .green : theme.secondaryTextColor)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingGoal = goal }
                    .listRowBackground(theme.surfaceColor)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            financeManager.removeFinancialGoal(goal)
                        } label: {
                            Label("delete".localized, systemImage: "trash")
                        }
                        Button {
                            editingGoal = goal
                        } label: {
                            Label("edit".localized, systemImage: "pencil")
                        }
                        .tint(theme.primaryColor)
                    }
                }
                
                Button {
                    showingAddGoal = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(theme.primaryColor)
                        Text("add_financial_goal".localized)
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("financial_goals".localized)
                    .themedSecondaryText()
            } footer: {
                if !financeManager.financialGoals.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                        Text("swipe_to_edit_delete".localized)
                            .font(.caption)
                    }
                    .themedSecondaryText()
                }
            }
            
            // Reset
            Section {
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("reset_finance_data".localized)
                    }
                    .foregroundColor(.red)
                }
                .listRowBackground(theme.surfaceColor)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .themedBackground()
        .financeNavigationTitle("finance_settings".localized)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done".localized) { focusedField = nil }
            }
        }
        .onChange(of: focusedField) { oldField, _ in
            // A value is saved as soon as its field is left, not only when the screen closes.
            if let oldField { commit(oldField) }
        }
        .onDisappear {
            saveAll()
        }
        .sheet(isPresented: $showingAddGoal) {
            NavigationStack {
                FinancialGoalFormView(goal: nil)
            }
        }
        .sheet(item: $editingGoal) { goal in
            NavigationStack {
                FinancialGoalFormView(goal: goal)
            }
        }
        .alert("reset_finance_confirm_title".localized, isPresented: $showingResetConfirm) {
            Button("cancel".localized, role: .cancel) {}
            Button("reset".localized, role: .destructive) { resetEverything() }
        } message: {
            Text("reset_finance_confirm_message".localized)
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                CustomCategoryFormView(initialIsExpense: newCategoryIsExpense)
            }
        }
        .sheet(item: $editingCategory) { cat in
            NavigationStack {
                CustomCategoryFormView(editingCategory: cat)
            }
        }
        .sheet(isPresented: $showingBuiltInCategoryEdit) {
            NavigationStack {
                BuiltInCategoryFormView(category: builtInCategoryToEdit)
            }
        }
        .sheet(isPresented: $showingEditBudget) {
            NavigationStack {
                EditCategoryBudgetView(budget: editingBudget)
            }
        }
        .alert("hide_category".localized, isPresented: $showingHideBuiltInAlert) {
            Button("cancel".localized, role: .cancel) { categoryToHide = nil }
            Button("hide".localized, role: .destructive) {
                if let cat = categoryToHide {
                    financeManager.hideBuiltInCategory(cat)
                }
                categoryToHide = nil
            }
        } message: {
            if let cat = categoryToHide {
                Text("hide_category_message".localized + " '\(financeManager.displayName(for: cat))'?")
            }
        }
        .alert("delete_category".localized, isPresented: $showingDeleteCustomAlert) {
            Button("cancel".localized, role: .cancel) { customCategoryToDelete = nil }
            Button("delete".localized, role: .destructive) {
                if let cat = customCategoryToDelete {
                    financeManager.removeCustomCategory(cat, reassignEntries: true)
                }
                customCategoryToDelete = nil
            }
        } message: {
            if let cat = customCategoryToDelete {
                Text("delete_category_message".localized + " '\(cat.name)'?\n" + "delete_category_reassign_note".localized)
            }
        }
    }
    
    /// An emptied field means "no value": the goal is cleared instead of silently keeping the old one.
    private func commit(_ field: SettingsField) {
        switch field {
        case .balance:
            let value = FinanceNumber.parse(balanceText) ?? 0
            if value != financeManager.startingBalance { financeManager.setStartingBalance(value) }
        case .budget:
            let value = max(FinanceNumber.parse(budgetText) ?? 0, 0)
            if value != financeManager.monthlyBudgetTarget { financeManager.setMonthlyBudgetTarget(value) }
        case .savings:
            commitSavings(isPercent: savingsIsPercent)
        case .income:
            let value = max(FinanceNumber.parse(incomeText) ?? 0, 0)
            if value != financeManager.monthlyIncomeGoal { financeManager.setMonthlyIncomeGoal(value) }
        }
    }
    
    private func commitSavings(isPercent: Bool) {
        let value = max(FinanceNumber.parse(savingsText) ?? 0, 0)
        if isPercent {
            let clamped = min(value, 100)
            if clamped != financeManager.savingsGoalPercent { financeManager.setSavingsGoalPercent(clamped) }
        } else if value != financeManager.savingsGoalAmount {
            financeManager.setSavingsGoalAmount(value)
        }
    }
    
    private func savingsFieldText(isPercent: Bool) -> String {
        let value = isPercent ? financeManager.savingsGoalPercent : financeManager.savingsGoalAmount
        guard value != 0 else { return "" }
        return FinanceNumber.editableText(value, fractionDigits: isPercent ? 1 : 2)
    }
    
    private func saveAll() {
        commit(.balance)
        commit(.budget)
        commit(.savings)
        commit(.income)
    }
    
    private func resetEverything() {
        focusedField = nil
        financeManager.resetAll(syncToCloud: true)
        balanceText = ""
        budgetText = ""
        savingsText = ""
        incomeText = ""
        savingsIsPercent = true
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        financeManager.formatCurrency(amount)
    }
}

// MARK: - Add Category Budget View

struct AddCategoryBudgetView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    private enum BudgetCategorySelection: Hashable {
        case builtIn(FinanceCategory)
        case custom(UUID)
    }
    
    @State private var selectedCategory: BudgetCategorySelection = .builtIn(.food)
    @State private var limitText: String = ""
    
    private var availableBuiltInCategories: [FinanceCategory] {
        let existing = Set(financeManager.budgets.filter { $0.customCategoryId == nil }.map { $0.category })
        return FinanceCategory.allCases.filter { !$0.isIncomeCategory && !existing.contains($0) && !financeManager.isHidden($0) }
    }
    
    private var hasAvailableCategory: Bool {
        !availableBuiltInCategories.isEmpty || !availableCustomCategories.isEmpty
    }
    
    private var parsedLimit: Double {
        FinanceNumber.parse(limitText) ?? 0
    }
    
    private var canSave: Bool {
        guard hasAvailableCategory, parsedLimit > 0 else { return false }
        switch selectedCategory {
        case .builtIn(let cat): return availableBuiltInCategories.contains(cat)
        case .custom(let id): return availableCustomCategories.contains { $0.id == id }
        }
    }
    
    private var availableCustomCategories: [CustomFinanceCategory] {
        let existing = Set(financeManager.budgets.compactMap { $0.customCategoryId })
        return financeManager.customCategories
            .filter { $0.isExpenseCategory && !existing.contains($0.id) }
    }
    
    var body: some View {
        Form {
            Section {
                if hasAvailableCategory {
                    Picker("category".localized, selection: $selectedCategory) {
                        ForEach(availableBuiltInCategories) { cat in
                            HStack {
                                Image(systemName: financeManager.icon(for: cat))
                                Text(financeManager.displayName(for: cat))
                            }
                            .tag(BudgetCategorySelection.builtIn(cat))
                        }
                        ForEach(availableCustomCategories) { custom in
                            HStack {
                                Image(systemName: custom.icon)
                                Text(custom.name)
                            }
                            .tag(BudgetCategorySelection.custom(custom.id))
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                } else {
                    Text("budget_no_categories_left".localized)
                        .themedSecondaryText()
                        .listRowBackground(theme.surfaceColor)
                }
                
                HStack {
                    Text(financeManager.selectedCurrency.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField(FinanceNumber.placeholder, text: $limitText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("monthly_limit".localized)
                    .themedSecondaryText()
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .financeNavigationTitle("add_category_budget".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) {
                    guard canSave else { return }
                    let budget: FinanceBudget
                    switch selectedCategory {
                    case .builtIn(let cat):
                        budget = FinanceBudget(category: cat, monthlyLimit: parsedLimit)
                    case .custom(let id):
                        budget = FinanceBudget(category: .other, customCategoryId: id, monthlyLimit: parsedLimit)
                    }
                    financeManager.addBudget(budget)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let first = availableBuiltInCategories.first {
                selectedCategory = .builtIn(first)
            } else if let firstCustom = availableCustomCategories.first {
                selectedCategory = .custom(firstCustom.id)
            }
        }
    }
}

// MARK: - Edit Category Budget View

struct EditCategoryBudgetView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var budget: FinanceBudget?
    
    @State private var limitText: String = ""
    
    private var currencySymbol: String {
        financeManager.selectedCurrency.symbol
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: budget.map { financeManager.budgetIcon(for: $0) } ?? "banknote")
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 24)
                    Text(budget.map { financeManager.budgetDisplayName(for: $0) } ?? "")
                        .themedPrimaryText()
                    Spacer()
                }
                .listRowBackground(theme.surfaceColor)
                
                HStack {
                    Text(currencySymbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField(FinanceNumber.placeholder, text: $limitText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("monthly_limit".localized)
                    .themedSecondaryText()
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .financeNavigationTitle("edit_budget".localized)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) {
                    if let val = FinanceNumber.parse(limitText), val > 0, var existingBudget = budget {
                        existingBudget.monthlyLimit = val
                        financeManager.updateBudget(existingBudget)
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .disabled((FinanceNumber.parse(limitText) ?? 0) <= 0)
            }
        }
        .onAppear {
            if let b = budget {
                limitText = FinanceNumber.editableText(b.monthlyLimit)
            }
        }
    }
}

// MARK: - Custom Category Form View

struct CustomCategoryFormView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var editingCategory: CustomFinanceCategory? = nil
    var initialIsExpense: Bool = true
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColorHex: String = "#3B82F6"
    @State private var isExpenseCategory: Bool = true
    
    private let availableIcons = FinanceIconCatalog.icons
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        Form {
            Section {
                TextField("category_name".localized, text: $name)
                    .themedPrimaryText()
                    .listRowBackground(theme.surfaceColor)
            } header: {
                Text("category_name".localized)
                    .themedSecondaryText()
            }
            
            Section {
                ThemedSegmentedPicker(selection: $isExpenseCategory, options: [true, false]) { isExpense in
                    Text(isExpense ? "finance_outflow".localized : "finance_inflow".localized)
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("category_type".localized)
                    .themedSecondaryText()
            }
            
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedIcon == icon ? .white : theme.secondaryTextColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? theme.primaryColor : theme.surfaceColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedIcon == icon ? theme.primaryColor : theme.borderColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("icon".localized)
                    .themedSecondaryText()
            }

            Section {
                ColorPickerGrid(selectedColor: $selectedColorHex)
                    .listRowBackground(theme.surfaceColor)
            } header: {
                Text("color".localized)
                    .themedSecondaryText()
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .financeNavigationTitle(editingCategory != nil ? "edit_category".localized : "new_category".localized)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) {
                    saveCategory()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let cat = editingCategory {
                name = cat.name
                selectedIcon = cat.icon
                isExpenseCategory = cat.isExpenseCategory
                selectedColorHex = cat.colorHex ?? financeManager.colorHex(for: cat.id)
            } else {
                isExpenseCategory = initialIsExpense
                selectedColorHex = initialIsExpense ? "#EF4444" : "#22C55E"
            }
        }
    }
    
    private func saveCategory() {
        if var existing = editingCategory {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.icon = selectedIcon
            existing.colorHex = selectedColorHex
            existing.isExpenseCategory = isExpenseCategory
            financeManager.updateCustomCategory(existing)
        } else {
            let cat = CustomFinanceCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                colorHex: selectedColorHex,
                isExpenseCategory: isExpenseCategory
            )
            financeManager.addCustomCategory(cat)
        }
        dismiss()
    }
}

// MARK: - Built-in Category Edit View

struct BuiltInCategoryFormView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    let category: FinanceCategory
    
    @State private var customName: String = ""
    @State private var selectedIcon: String = ""
    @State private var selectedColorHex: String = "#3B82F6"
    
    private let availableIcons = FinanceIconCatalog.icons
    
    private var hasChanges: Bool {
        let currentName = financeManager.override(for: category)?.customName ?? category.displayName
        let currentIcon = financeManager.override(for: category)?.customIcon ?? category.icon
        let currentColor = financeManager.override(for: category)?.customColorHex ?? financeManager.baseColorHex(for: category)
        return customName != currentName || selectedIcon != currentIcon || selectedColorHex != currentColor
    }
    
    private var canReset: Bool {
        financeManager.override(for: category) != nil
    }
    
    var body: some View {
        Form {
            Section {
                TextField("category_name".localized, text: $customName)
                    .themedPrimaryText()
                    .listRowBackground(theme.surfaceColor)
            } header: {
                Text("category_name".localized)
                    .themedSecondaryText()
            }
            
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedIcon == icon ? .white : theme.secondaryTextColor)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon ? theme.primaryColor : theme.surfaceColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedIcon == icon ? theme.primaryColor : theme.borderColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("icon".localized)
                    .themedSecondaryText()
            }

            Section {
                ColorPickerGrid(selectedColor: $selectedColorHex)
                    .listRowBackground(theme.surfaceColor)
            } header: {
                Text("color".localized)
                    .themedSecondaryText()
            }
            
            if canReset {
                Section {
                    Button(role: .destructive) {
                        financeManager.setCategoryOverride(category, customName: nil, customIcon: nil, customColorHex: nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("reset_to_default".localized)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .financeNavigationTitle("edit_category".localized)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) { saveCategory() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .onAppear {
            if let ov = financeManager.override(for: category) {
                customName = ov.customName ?? category.displayName
                selectedIcon = ov.customIcon ?? category.icon
                selectedColorHex = ov.customColorHex ?? financeManager.baseColorHex(for: category)
            } else {
                customName = category.displayName
                selectedIcon = category.icon
                selectedColorHex = financeManager.baseColorHex(for: category)
            }
        }
    }
    
    private func saveCategory() {
        let nameToSave = customName.trimmingCharacters(in: .whitespaces)
        let nameNilIfDefault = nameToSave.isEmpty || nameToSave == category.displayName ? nil : nameToSave
        let iconNilIfDefault = selectedIcon == category.icon ? nil : selectedIcon
        let baseColor = financeManager.baseColorHex(for: category)
        let colorNilIfDefault = selectedColorHex == baseColor ? nil : selectedColorHex
        financeManager.setCategoryOverride(category, customName: nameNilIfDefault, customIcon: iconNilIfDefault, customColorHex: colorNilIfDefault)
        dismiss()
    }
}


// MARK: - Financial Goal Form View

struct FinancialGoalFormView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    let goal: FinancialGoal?
    
    @State private var name: String
    @State private var type: FinancialGoalType
    @State private var targetText: String
    @State private var currentText: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var showingDeleteConfirm = false
    
    private enum Field: Hashable {
        case name, target, current
    }
    
    init(goal: FinancialGoal?) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _type = State(initialValue: goal?.type ?? .savings)
        _targetText = State(initialValue: goal.map { FinanceNumber.editableText($0.targetAmount) } ?? "")
        _currentText = State(initialValue: goal.map { $0.currentAmount != 0 ? FinanceNumber.editableText($0.currentAmount) : "" } ?? "")
        _hasDeadline = State(initialValue: goal?.targetDate != nil)
        _deadline = State(initialValue: goal?.targetDate
            ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (FinanceNumber.parse(targetText) ?? 0) > 0
    }
    
    var body: some View {
        Form {
            Section {
                TextField("goal_name".localized, text: $name)
                    .themedPrimaryText()
                    .focused($focusedField, equals: .name)
                    .listRowBackground(theme.surfaceColor)
                
                Picker("type".localized, selection: $type) {
                    ForEach(FinancialGoalType.allCases) { goalType in
                        Label(goalType.displayName, systemImage: goalType.icon).tag(goalType)
                    }
                }
                .listRowBackground(theme.surfaceColor)
            } header: {
                Text("goal_name".localized)
                    .themedSecondaryText()
            }
            
            Section {
                amountRow(text: $targetText, field: .target)
            } header: {
                Text("goal_target_amount".localized)
                    .themedSecondaryText()
            }
            
            Section {
                amountRow(text: $currentText, field: .current)
            } header: {
                Text("goal_saved_amount".localized)
                    .themedSecondaryText()
            }
            
            Section {
                Toggle("goal_has_deadline".localized, isOn: $hasDeadline.animation(.easeInOut(duration: 0.2)))
                    .tint(theme.primaryColor)
                    .themedPrimaryText()
                    .listRowBackground(theme.surfaceColor)
                
                if hasDeadline {
                    DatePicker("deadline".localized, selection: $deadline, in: Date()..., displayedComponents: .date)
                        .themedPrimaryText()
                        .listRowBackground(theme.surfaceColor)
                }
            }
            
            if goal != nil {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("delete".localized)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .themedBackground()
        .financeNavigationTitle((goal == nil ? "new_financial_goal" : "edit_financial_goal").localized)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done".localized) { focusedField = nil }
            }
        }
        .confirmationDialog(goal?.name ?? "", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("delete".localized, role: .destructive) {
                if let goal { financeManager.removeFinancialGoal(goal) }
                dismiss()
            }
            Button("cancel".localized, role: .cancel) {}
        }
    }
    
    private func amountRow(text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(financeManager.selectedCurrency.symbol)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.secondaryTextColor)
            TextField(FinanceNumber.placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold).monospacedDigit())
                .themedPrimaryText()
                .focused($focusedField, equals: field)
        }
        .listRowBackground(theme.surfaceColor)
    }
    
    private func save() {
        guard canSave, let target = FinanceNumber.parse(targetText) else { return }
        let current = max(FinanceNumber.parse(currentText) ?? 0, 0)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let targetDate: Date? = hasDeadline ? deadline : nil
        
        if var existing = goal {
            existing.name = trimmedName
            existing.type = type
            existing.targetAmount = target
            existing.currentAmount = current
            existing.targetDate = targetDate
            financeManager.updateFinancialGoal(existing)
        } else {
            financeManager.addFinancialGoal(FinancialGoal(
                name: trimmedName,
                targetAmount: target,
                currentAmount: current,
                targetDate: targetDate,
                type: type
            ))
        }
        dismiss()
    }
}


// MARK: - Card Layout View

/// Reorder (drag) and show / hide the cards of the Finance screen.
struct FinanceCardLayoutView: View {
    @AppStorage(FinanceCardLayout.storageKey) private var layoutRaw = ""
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var showsDoneButton = false
    
    private var layout: FinanceCardLayout {
        FinanceCardLayout(rawValue: layoutRaw)
    }
    
    var body: some View {
        List {
            Section {
                ForEach(layout.order) { card in
                    let isVisible = !layout.hidden.contains(card)
                    HStack(spacing: 12) {
                        Image(systemName: card.icon)
                            .foregroundColor(isVisible ? theme.primaryColor : theme.secondaryTextColor.opacity(0.4))
                            .frame(width: 24)
                        Text(card.title)
                            .themedPrimaryText()
                            .opacity(isVisible ? 1 : 0.45)
                        Spacer()
                        // A borderless button keeps working while the list is in reorder mode (a Toggle does not).
                        Button {
                            setVisible(!isVisible, for: card)
                        } label: {
                            Image(systemName: isVisible ? "eye.fill" : "eye.slash")
                                .font(.body.weight(.medium))
                                .foregroundColor(isVisible ? theme.primaryColor : theme.secondaryTextColor.opacity(0.6))
                                .frame(width: 36, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(card.title)
                        .accessibilityValue((isVisible ? "visible" : "hidden").localized)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
                .onMove { source, destination in
                    var updated = layout
                    updated.order.move(fromOffsets: source, toOffset: destination)
                    layoutRaw = updated.rawValue
                }
            } footer: {
                Text("finance_cards_footer".localized)
                    .themedSecondaryText()
            }
            
            Section {
                Button {
                    withAnimation { layoutRaw = "" }
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("reset_to_default".localized)
                    }
                    .foregroundColor(theme.primaryColor)
                }
                .disabled(layout == .default)
                .listRowBackground(theme.surfaceColor)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .themedBackground()
        .financeNavigationTitle("finance_cards_layout".localized)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func setVisible(_ isVisible: Bool, for card: FinanceDashboardCard) {
        var updated = layout
        if isVisible {
            updated.hidden.remove(card)
        } else {
            updated.hidden.insert(card)
        }
        withAnimation(.easeInOut(duration: 0.2)) { layoutRaw = updated.rawValue }
    }
}


// MARK: - Title that never truncates

extension View {
    /// Inline navigation title that shrinks a little instead of ending in "…" when the
    /// toolbar buttons leave little room (long translations such as German or French).
    func financeNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .themedPrimaryText()
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.55)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
