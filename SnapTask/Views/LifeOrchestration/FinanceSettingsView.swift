import SwiftUI

struct FinanceSettingsView: View {
    @StateObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    @State private var balanceText: String = ""
    @State private var budgetText: String = ""
    @State private var savingsText: String = ""
    @State private var savingsIsPercent: Bool = true
    @State private var incomeText: String = ""
    @State private var showingAddCategory = false
    @State private var editingCategory: CustomFinanceCategory? = nil
    @State private var showingBuiltInCategoryEdit = false
    @State private var builtInCategoryToEdit: FinanceCategory = .other
    
    private var currencySymbol: String {
        financeManager.selectedCurrency.symbol
    }
    
    var body: some View {
        Form {
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
                    TextField("0.00", text: $balanceText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
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
                    TextField("0.00", text: $budgetText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
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
                .onChange(of: savingsIsPercent) { _, newValue in
                    financeManager.setSavingsGoalIsPercent(newValue)
                }
                
                if savingsIsPercent {
                    HStack {
                        TextField("0", text: $savingsText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .themedPrimaryText()
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
                        TextField("0.00", text: $savingsText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .themedPrimaryText()
                    }
                    .listRowBackground(theme.surfaceColor)
                }
                
                if financeManager.savingsGoalConfigured && financeManager.monthlyIncome > 0 {
                    HStack {
                        Text("current_savings_rate".localized)
                            .themedPrimaryText()
                        Spacer()
                        if savingsIsPercent {
                            Text(String(format: "%.1f%%", financeManager.monthlySavingsRate * 100))
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
                    TextField("0.00", text: $incomeText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .themedPrimaryText()
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
            
            // Built-in categories (customizable name & icon)
            Section {
                ForEach(FinanceCategory.allCases, id: \.self) { cat in
                    HStack {
                        Image(systemName: financeManager.icon(for: cat))
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text(financeManager.displayName(for: cat))
                            .themedPrimaryText()
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .listRowBackground(theme.surfaceColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        builtInCategoryToEdit = cat
                        showingBuiltInCategoryEdit = true
                    }
                }
            } header: {
                Text("builtin_categories".localized)
                    .themedSecondaryText()
            } footer: {
                Text("builtin_categories_footer".localized)
                    .themedSecondaryText()
            }
            
            // Custom Categories
            Section {
                ForEach(financeManager.customCategories) { cat in
                    HStack {
                        Image(systemName: cat.icon)
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text(cat.name)
                            .themedPrimaryText()
                        Spacer()
                        Text(cat.isExpenseCategory ? "finance_outflow".localized : "finance_inflow".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .listRowBackground(theme.surfaceColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCategory = cat
                    }
                }
                .onDelete { indexSet in
                    let toRemove = indexSet.map { financeManager.customCategories[$0] }
                    toRemove.forEach { financeManager.removeCustomCategory($0) }
                }
                
                Button {
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
            } header: {
                Text("custom_categories".localized)
                    .themedSecondaryText()
            } footer: {
                Text("custom_categories_footer".localized)
                    .themedSecondaryText()
            }
            
            // Category Budgets
            Section {
                ForEach(financeManager.budgets) { budget in
                    HStack {
                        Image(systemName: financeManager.icon(for: budget.category))
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 24)
                        Text(financeManager.displayName(for: budget.category))
                            .themedPrimaryText()
                        Spacer()
                        Text(formatCurrency(budget.monthlyLimit))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .themedSecondaryText()
                        
                        let usage = financeManager.budgetUsage(for: budget.category)
                        if usage > 0 {
                            Text(String(format: "%.0f%%", usage * 100))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundColor(usage > 1 ? .red : usage > 0.8 ? .orange : .green)
                                .frame(width: 44)
                        }
                    }
                    .listRowBackground(theme.surfaceColor)
                }
                .onDelete { indexSet in
                    let toRemove = indexSet.map { financeManager.budgets[$0] }
                    toRemove.forEach { financeManager.removeBudget($0) }
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
                Text("category_budgets_footer".localized)
                    .themedSecondaryText()
            }
            
            // Reset
            Section {
                Button(role: .destructive) {
                    financeManager.resetAll()
                    balanceText = ""
                    budgetText = ""
                    savingsText = ""
                    incomeText = ""
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
        .themedBackground()
        .navigationTitle("finance_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            balanceText = financeManager.startingBalance > 0 ? String(format: "%.2f", financeManager.startingBalance) : ""
            budgetText = financeManager.monthlyBudgetTarget > 0 ? String(format: "%.2f", financeManager.monthlyBudgetTarget) : ""
            savingsIsPercent = financeManager.savingsGoalIsPercent
            if financeManager.savingsGoalIsPercent {
                savingsText = financeManager.savingsGoalPercent > 0 ? String(format: "%.0f", financeManager.savingsGoalPercent) : ""
            } else {
                savingsText = financeManager.savingsGoalAmount > 0 ? String(format: "%.2f", financeManager.savingsGoalAmount) : ""
            }
            incomeText = financeManager.monthlyIncomeGoal > 0 ? String(format: "%.2f", financeManager.monthlyIncomeGoal) : ""
        }
        .onDisappear {
            saveAll()
        }
        .sheet(isPresented: $showingAddCategory) {
            NavigationStack {
                CustomCategoryFormView()
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
    }
    
    private func saveAll() {
        if let val = Double(balanceText.replacingOccurrences(of: ",", with: ".")) {
            financeManager.setStartingBalance(val)
        }
        if let val = Double(budgetText.replacingOccurrences(of: ",", with: ".")) {
            financeManager.setMonthlyBudgetTarget(val)
        }
        if let val = Double(savingsText.replacingOccurrences(of: ",", with: ".")) {
            if savingsIsPercent {
                financeManager.setSavingsGoalPercent(val)
            } else {
                financeManager.setSavingsGoalAmount(val)
            }
        }
        if let val = Double(incomeText.replacingOccurrences(of: ",", with: ".")) {
            financeManager.setMonthlyIncomeGoal(val)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = financeManager.selectedCurrency.rawValue
        formatter.currencySymbol = financeManager.selectedCurrency.symbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)0.00"
    }
}

// MARK: - Add Category Budget View

struct AddCategoryBudgetView: View {
    @StateObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: FinanceCategory = .food
    @State private var limitText: String = ""
    
    private var availableCategories: [FinanceCategory] {
        let existingCategories = Set(financeManager.budgets.map { $0.category })
        return FinanceCategory.allCases.filter { !$0.isIncomeCategory && !existingCategories.contains($0) }
    }
    
    var body: some View {
        Form {
            Section {
                Picker("category".localized, selection: $selectedCategory) {
                    ForEach(availableCategories) { cat in
                        HStack {
                            Image(systemName: financeManager.icon(for: cat))
                            Text(financeManager.displayName(for: cat))
                        }
                        .tag(cat)
                    }
                }
                .listRowBackground(theme.surfaceColor)
                
                HStack {
                    Text(financeManager.selectedCurrency.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    TextField("0.00", text: $limitText)
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
        .navigationTitle("add_category_budget".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) {
                    if let val = Double(limitText.replacingOccurrences(of: ",", with: ".")), val > 0 {
                        let budget = FinanceBudget(
                            category: selectedCategory,
                            monthlyLimit: val
                        )
                        financeManager.addBudget(budget)
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .disabled(Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0 <= 0)
            }
        }
        .onAppear {
            if let first = availableCategories.first {
                selectedCategory = first
            }
        }
    }
}

// MARK: - Custom Category Form View

struct CustomCategoryFormView: View {
    @StateObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var editingCategory: CustomFinanceCategory? = nil
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var isExpenseCategory: Bool = true
    
    private let availableIcons = [
        "tag.fill", "cart.fill", "bag.fill", "creditcard.fill",
        "house.fill", "car.fill", "airplane", "bus.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
        "heart.fill", "cross.case.fill", "pills.fill",
        "book.fill", "graduationcap.fill", "music.note",
        "gamecontroller.fill", "tv.fill", "film.fill",
        "tshirt.fill", "eyeglasses", "gift.fill",
        "wrench.fill", "hammer.fill", "paintbrush.fill",
        "leaf.fill", "pawprint.fill", "figure.run",
        "dumbbell.fill", "bicycle", "fuelpump.fill",
        "wifi", "phone.fill", "envelope.fill",
        "dollarsign.circle.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
        "briefcase.fill", "building.2.fill", "storefront.fill",
        "stethoscope", "bed.double.fill", "washer.fill",
        "lightbulb.fill", "bolt.fill", "drop.fill",
        "flame.fill", "snowflake", "sun.max.fill"
    ]
    
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
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .navigationTitle(editingCategory != nil ? "edit_category".localized : "new_category".localized)
        .navigationBarTitleDisplayMode(.inline)
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
            }
        }
    }
    
    private func saveCategory() {
        if var existing = editingCategory {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.icon = selectedIcon
            existing.isExpenseCategory = isExpenseCategory
            financeManager.updateCustomCategory(existing)
        } else {
            let cat = CustomFinanceCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                isExpenseCategory: isExpenseCategory
            )
            financeManager.addCustomCategory(cat)
        }
        dismiss()
    }
}

// MARK: - Built-in Category Edit View

struct BuiltInCategoryFormView: View {
    @StateObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    let category: FinanceCategory
    
    @State private var customName: String = ""
    @State private var selectedIcon: String = ""
    
    private let availableIcons = [
        "tag.fill", "cart.fill", "bag.fill", "creditcard.fill",
        "house.fill", "car.fill", "airplane", "bus.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill",
        "heart.fill", "cross.case.fill", "pills.fill",
        "book.fill", "graduationcap.fill", "music.note",
        "gamecontroller.fill", "tv.fill", "film.fill",
        "tshirt.fill", "eyeglasses", "gift.fill",
        "wrench.fill", "hammer.fill", "paintbrush.fill",
        "leaf.fill", "pawprint.fill", "figure.run",
        "dumbbell.fill", "bicycle", "fuelpump.fill",
        "wifi", "phone.fill", "envelope.fill",
        "dollarsign.circle.fill", "banknote.fill", "chart.line.uptrend.xyaxis",
        "briefcase.fill", "building.2.fill", "storefront.fill",
        "stethoscope", "bed.double.fill", "washer.fill",
        "lightbulb.fill", "bolt.fill", "drop.fill",
        "flame.fill", "snowflake", "sun.max.fill"
    ]
    
    private var hasChanges: Bool {
        let currentName = financeManager.override(for: category)?.customName ?? category.displayName
        let currentIcon = financeManager.override(for: category)?.customIcon ?? category.icon
        return customName != currentName || selectedIcon != currentIcon
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
            
            if canReset {
                Section {
                    Button(role: .destructive) {
                        financeManager.setCategoryOverride(category, customName: nil, customIcon: nil)
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
        .navigationTitle("edit_category".localized)
        .navigationBarTitleDisplayMode(.inline)
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
            } else {
                customName = category.displayName
                selectedIcon = category.icon
            }
        }
    }
    
    private func saveCategory() {
        let nameToSave = customName.trimmingCharacters(in: .whitespaces)
        let nameNilIfDefault = nameToSave.isEmpty || nameToSave == category.displayName ? nil : nameToSave
        let iconNilIfDefault = selectedIcon == category.icon ? nil : selectedIcon
        financeManager.setCategoryOverride(category, customName: nameNilIfDefault, customIcon: iconNilIfDefault)
        dismiss()
    }
}
