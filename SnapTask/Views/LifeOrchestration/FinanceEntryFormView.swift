import SwiftUI

struct FinanceEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var financeManager = FinanceManager.shared
    @FocusState private var focusedField: Field?
    
    var editingEntry: FinanceEntry?
    
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var isExpense: Bool = true
    @State private var category: FinanceCategory = .other
    @State private var selectedCustomCategoryId: UUID? = nil
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: SubscriptionFrequency = .monthly
    
    private enum Field: Hashable {
        case name, amount, notes
    }
    
    private var resolvedType: FinanceEntryType {
        if isRecurring && isExpense { return .subscription }
        return isExpense ? .expense : .income
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Direction toggle
                directionCard
                
                // Details
                detailsCard
                
                // Category
                categoryCard
                
                // Recurrence
                recurrenceCard
                
                // Notes
                notesCard
                
                // Save/Delete buttons row (only delete when editing)
                actionButtonsRow
            }
            .padding(.top, 8)
        }
        .themedBackground()
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
        )
        .navigationTitle(editingEntry != nil ? "edit_entry".localized : "new_entry".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) { save() }
                    .fontWeight(.semibold)
                    .themedPrimary()
                    .disabled(!canSave)
            }
        }
        .onAppear {
            if let entry = editingEntry {
                name = entry.name
                amount = String(format: "%.2f", entry.amount)
                isExpense = entry.type.isOutflow
                category = entry.category
                selectedCustomCategoryId = entry.customCategoryId
                date = entry.date
                notes = entry.notes ?? ""
                isRecurring = entry.isRecurring
                recurringFrequency = entry.recurringFrequency ?? .monthly
            }
        }
        .onChange(of: isExpense) { _, _ in
            selectedCustomCategoryId = nil
            if isExpense && category.isIncomeCategory {
                category = .other
            } else if !isExpense && !category.isIncomeCategory {
                category = .salary
            }
        }
    }
    
    // MARK: - Direction Card
    
    private var directionCard: some View {
        ModernCard(title: "finance_direction".localized, icon: "arrow.left.arrow.right") {
            HStack(spacing: 0) {
                directionButton(
                    title: "finance_outflow".localized,
                    icon: "arrow.up.circle.fill",
                    color: .red,
                    isSelected: isExpense
                ) { isExpense = true }
                
                directionButton(
                    title: "finance_inflow".localized,
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    isSelected: !isExpense
                ) { isExpense = false }
            }
        }
    }
    
    private func directionButton(title: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? color : theme.secondaryTextColor.opacity(0.4))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isSelected ? color : theme.secondaryTextColor.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        ModernCard(title: "details".localized, icon: "doc.text") {
            VStack(spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("entry_name".localized)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                    
                    TextField("entry_name".localized, text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.backgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            focusedField == .name ? theme.primaryColor : theme.borderColor,
                                            lineWidth: focusedField == .name ? 2 : 1
                                        )
                                )
                        )
                        .themedPrimaryText()
                        .accentColor(theme.primaryColor)
                        .focused($focusedField, equals: .name)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                }
                
                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    Text("amount".localized)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                    
                    HStack(spacing: 12) {
                        Text(financeManager.selectedCurrency.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(isExpense ? .red : .green)
                        
                        TextField("0.00", text: $amount)
                            .textFieldStyle(PlainTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .themedPrimaryText()
                            .accentColor(theme.primaryColor)
                            .focused($focusedField, equals: .amount)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        focusedField == .amount ? theme.primaryColor : theme.borderColor,
                                        lineWidth: focusedField == .amount ? 2 : 1
                                    )
                            )
                    )
                }
                
                // Date and time
                HStack {
                    Text("date_and_time".localized)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Category Card
    
    private var categoryCard: some View {
        ModernCard(title: "category".localized, icon: "folder") {
            Menu {
                // Built-in categories
                ForEach(filteredCategories) { cat in
                    Button {
                        category = cat
                        selectedCustomCategoryId = nil
                    } label: {
                        Label(financeManager.displayName(for: cat), systemImage: financeManager.icon(for: cat))
                    }
                }
                
                // Custom categories
                let customCats = filteredCustomCategories
                if !customCats.isEmpty {
                    Divider()
                    ForEach(customCats) { custom in
                        Button {
                            selectedCustomCategoryId = custom.id
                            category = .other
                        } label: {
                            Label(custom.name, systemImage: custom.icon)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedCategoryIcon)
                        .font(.system(size: 18))
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(theme.primaryColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text(selectedCategoryName)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(theme.borderColor, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var selectedCategoryIcon: String {
        if let customId = selectedCustomCategoryId,
           let custom = financeManager.customCategory(for: customId) {
            return custom.icon
        }
        return category.icon
    }
    
    private var selectedCategoryName: String {
        if let customId = selectedCustomCategoryId,
           let custom = financeManager.customCategory(for: customId) {
            return custom.name
        }
        return category.displayName
    }
    
    // MARK: - Recurrence Card
    
    private var recurrenceCard: some View {
        ModernCard(title: "recurrence".localized, icon: "repeat") {
            VStack(spacing: 16) {
                HStack {
                    Text("recurring".localized)
                        .font(.subheadline.weight(.medium))
                        .themedPrimaryText()
                    Spacer()
                    Toggle("", isOn: $isRecurring)
                        .labelsHidden()
                        .tint(theme.primaryColor)
                }
                
                if isRecurring {
                    VStack(spacing: 12) {
                        Text("frequency".localized)
                            .font(.subheadline.weight(.medium))
                            .themedPrimaryText()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ThemedSegmentedPicker(selection: $recurringFrequency, options: Array(SubscriptionFrequency.allCases)) { freq in
                            Text(freq.displayName)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.animation(.easeInOut(duration: 0.3))
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRecurring)
        }
    }
    
    // MARK: - Notes Card
    
    private var notesCard: some View {
        ModernCard(title: "notes".localized, icon: "note.text") {
            TextField("notes_optional".localized, text: $notes, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .lineLimit(2...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    focusedField == .notes ? theme.primaryColor : theme.borderColor,
                                    lineWidth: focusedField == .notes ? 2 : 1
                                )
                        )
                )
                .themedPrimaryText()
                .accentColor(theme.primaryColor)
                .focused($focusedField, equals: .notes)
        }
    }
    
    // MARK: - Action Buttons Row (Delete left [red], Save right [green])
    
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Delete button (only when editing)
            if editingEntry != nil {
                Button(action: { deleteEntry() }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        Text("delete".localized)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(theme.buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(12)
                }
            }
            
            // Save button
            Button(action: { save() }) {
                HStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                    Text("save".localized)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(theme.buttonTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSave ? 
                    LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                    LinearGradient(colors: [theme.secondaryTextColor, theme.secondaryTextColor.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(12)
            }
            .disabled(!canSave)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
    
    private func deleteEntry() {
        if let entry = editingEntry {
            financeManager.removeEntry(entry)
        }
        dismiss()
    }
    
    // MARK: - Helpers
    
    private var filteredCategories: [FinanceCategory] {
        if isExpense {
            return FinanceCategory.allCases.filter { !$0.isIncomeCategory && !financeManager.isHidden($0) }
        } else {
            return FinanceCategory.allCases.filter { ($0.isIncomeCategory || $0 == .other || $0 == .gifts) && !financeManager.isHidden($0) }
        }
    }
    
    private var filteredCustomCategories: [CustomFinanceCategory] {
        financeManager.customCategories.filter { $0.isExpenseCategory == isExpense }
    }
    
    private func save() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), amountValue > 0 else { return }
        
        if var existing = editingEntry {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.amount = amountValue
            existing.type = resolvedType
            existing.category = category
            existing.customCategoryId = selectedCustomCategoryId
            existing.date = date
            existing.notes = notes.isEmpty ? nil : notes
            existing.isRecurring = isRecurring
            existing.recurringFrequency = isRecurring ? recurringFrequency : nil
            financeManager.updateEntry(existing)
        } else {
            let entry = FinanceEntry(
                name: name.trimmingCharacters(in: .whitespaces),
                amount: amountValue,
                type: resolvedType,
                category: category,
                customCategoryId: selectedCustomCategoryId,
                date: date,
                notes: notes.isEmpty ? nil : notes,
                isRecurring: isRecurring,
                recurringFrequency: isRecurring ? recurringFrequency : nil
            )
            financeManager.addEntry(entry)
        }
        dismiss()
    }
}

