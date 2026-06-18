import SwiftUI
import Charts

enum ChartPeriod: String, CaseIterable {
    case day, week, month, year
    
    var displayName: String {
        switch self {
        case .day: return "period_day".localized
        case .week: return "period_week".localized
        case .month: return "period_month".localized
        case .year: return "period_year".localized
        }
    }
}

enum ChartStyle: String, CaseIterable {
    case pie, bar
    
    var displayName: String {
        switch self {
        case .pie: return "chart_pie".localized
        case .bar: return "chart_bar".localized
        }
    }
    
    var icon: String {
        switch self {
        case .pie: return "chart.pie.fill"
        case .bar: return "chart.bar.fill"
        }
    }
}

struct FinanceDashboardView: View {
    @StateObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @State private var showingAddEntry = false
    @State private var editingEntry: FinanceEntry?
    @State private var showingAllEntries = false
    @State private var balanceText: String = ""
    @State private var breakdownPeriod: ChartPeriod = .month
    @State private var breakdownStyle: ChartStyle = .pie
    @State private var breakdownOffset: Int = 0
    @State private var selectedBreakdownKey: FinanceExpenseBreakdownKey? = nil
    @State private var trendPeriod: ChartPeriod = .month
    @State private var trendStyle: ChartStyle = .bar
    @State private var trendOffset: Int = 0
    @State private var selectedBudgetIndex: Int = 0
    @State private var summaryShowsYearly: Bool = false
    @State private var summaryOffset: Int = 0
    
    private var hasGoalsConfigured: Bool {
        financeManager.monthlyBudgetTarget > 0 ||
        financeManager.savingsGoalConfigured ||
        financeManager.monthlyIncomeGoal > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header fisso come in RewardsView e StatisticsView
            VStack(spacing: 16) {
                HStack {
                    Text("finance".localized)
                        .font(.largeTitle.bold())
                        .themedPrimaryText()
                    Spacer()
                    NavigationLink(destination: FinanceSettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(theme.backgroundColor)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Current balance
                    balanceCard
                    
                    // Quick actions
                    quickActions

                    // Recent entries (preview)
                    recentEntriesSection
                    
                    // Goal progress (if configured)
                    if hasGoalsConfigured {
                        goalProgressSection
                    }
                    
                    // Budget alerts
                    if !financeManager.overBudgetCategories().isEmpty {
                        budgetAlertsCard
                    }
                    
                    // Charts combined in TabView with swipe
                    chartsSection
                    
                    // Subscriptions
                    if !financeManager.activeSubscriptions.isEmpty {
                        subscriptionsSection
                    }

                    // Budget management chart (when any budget is set)
                    if financeManager.monthlyBudgetTarget > 0 || !financeManager.budgets.isEmpty {
                        budgetManagementCard
                    }
                }
                .padding(16)
            }
        }
        .background(theme.backgroundColor)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddEntry) {
            NavigationStack {
                FinanceEntryFormView(editingEntry: nil)
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                FinanceEntryFormView(editingEntry: entry)
            }
        }
        .sheet(isPresented: $showingAllEntries) {
            NavigationStack {
                FinanceAllEntriesView(onSelect: { entry in
                    showingAllEntries = false
                    editingEntry = entry
                })
            }
        }
    }
    
    // MARK: - Goal Progress Section
    
    private var goalProgressSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .font(.subheadline)
                    .foregroundColor(theme.primaryColor)
                Text("monthly_goals".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
            }
            
            if let progress = financeManager.budgetProgress {
                goalRow(
                    icon: "cart.fill",
                    title: "monthly_budget_target".localized,
                    current: formatCurrency(financeManager.monthlyExpenses),
                    target: formatCurrency(financeManager.monthlyBudgetTarget),
                    progress: min(progress, 1.5),
                    isInverted: true
                )
            }
            
            if let progress = financeManager.savingsProgress {
                if financeManager.savingsGoalIsPercent {
                    goalRow(
                        icon: "banknote.fill",
                        title: "savings_goal".localized,
                        current: String(format: "%.1f%%", financeManager.monthlySavingsRate * 100),
                        target: String(format: "%.0f%%", financeManager.savingsGoalPercent),
                        progress: min(progress, 1.5),
                        isInverted: false
                    )
                } else {
                    let actualSavings = max(financeManager.monthlyIncome - financeManager.monthlyExpenses, 0)
                    goalRow(
                        icon: "banknote.fill",
                        title: "savings_goal".localized,
                        current: formatCurrency(actualSavings),
                        target: formatCurrency(financeManager.savingsGoalAmount),
                        progress: min(progress, 1.5),
                        isInverted: false
                    )
                }
            }
            
            if let progress = financeManager.incomeProgress {
                goalRow(
                    icon: "arrow.down.circle.fill",
                    title: "income_goal".localized,
                    current: formatCurrency(financeManager.monthlyIncome),
                    target: formatCurrency(financeManager.monthlyIncomeGoal),
                    progress: min(progress, 1.5),
                    isInverted: false
                )
            }
        }
        .padding(16)
        .themedCard()
    }
    
    private func goalRow(icon: String, title: String, current: String, target: String, progress: Double, isInverted: Bool) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(goalColor(progress: progress, inverted: isInverted))
                if !title.isEmpty {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .themedPrimaryText()
                }
                Spacer()
                Text("\(current) / \(target)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(goalColor(progress: progress, inverted: isInverted))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.secondaryTextColor.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goalColor(progress: progress, inverted: isInverted))
                        .frame(width: geo.size.width * min(isInverted ? progress : progress, 1.0))
                }
            }
            .frame(height: 6)
        }
    }
    
    private func goalColor(progress: Double, inverted: Bool) -> Color {
        if inverted {
            // For budget: lower is better
            if progress > 1.0 { return .red }
            if progress > 0.8 { return .orange }
            return .green
        } else {
            // For savings/income: higher is better
            if progress >= 1.0 { return .green }
            if progress >= 0.6 { return .orange }
            return .red
        }
    }
    
    // MARK: - Budget Management Chart (semicircle gauge)
    
    private var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 0 }
        let totalDays = range.count
        let currentDay = calendar.component(.day, from: now)
        return max(totalDays - currentDay, 0)
    }
    
    private var budgetManagementCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.14))
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primaryColor)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("budget_management".localized)
                        .font(.subheadline.weight(.semibold))
                        .themedPrimaryText()
                    Text("monthly_overview".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryTextColor)
                }
                Spacer()
            }
            
            let allItems = budgetGaugeItems
            if allItems.isEmpty {
                Text("no_data_yet".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                // Budget selector tabs (scrollable)
                if allItems.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedBudgetIndex = index
                                    }
                                } label: {
                                    Text(item.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(selectedBudgetIndex == index ? theme.buttonTextColor : theme.secondaryTextColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(selectedBudgetIndex == index ? theme.primaryColor.opacity(0.95) : theme.surfaceColor.opacity(0.6))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(selectedBudgetIndex == index ? theme.primaryColor.opacity(0.35) : theme.borderColor.opacity(0.35), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                
                // Gauge for selected budget
                let safeIndex = min(selectedBudgetIndex, allItems.count - 1)
                let selected = allItems[max(safeIndex, 0)]
                let progress = selected.limit > 0 ? min(selected.spent / selected.limit, 1.5) : 0
                let remaining = max(selected.limit - selected.spent, 0)
                let spentPercent = Int(min(progress * 100, 999))
                
                BudgetOverallGauge(
                    progress: progress,
                    spentPercent: spentPercent,
                    remaining: remaining,
                    totalLimit: selected.limit,
                    formatCurrency: formatCurrency
                )
                
                // Individual budget cards in a 2-column grid
                let categoryItems = budgetCategoryItems
                if !categoryItems.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(categoryItems.enumerated()), id: \.offset) { _, item in
                            BudgetCategoryCard(
                                label: item.label,
                                icon: item.icon,
                                limit: item.limit,
                                spent: item.spent,
                                daysLeft: daysLeftInMonth,
                                categoryColor: item.color,
                                formatCurrency: formatCurrency
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .themedCard()
    }

    private struct FinanceAllEntriesView: View {
        @StateObject private var financeManager = FinanceManager.shared
        @Environment(\.theme) private var theme

        let onSelect: (FinanceEntry) -> Void

        private func formatCurrency(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = financeManager.selectedCurrency.rawValue
            formatter.currencySymbol = financeManager.selectedCurrency.symbol
            return formatter.string(from: NSNumber(value: amount)) ?? "\(financeManager.selectedCurrency.symbol)0.00"
        }

        private func entryDateText(_ date: Date) -> String {
            let calendar = Calendar.current
            if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
                return date.formatted(.dateTime.day().month(.abbreviated))
            } else {
                return date.formatted(.dateTime.day().month(.abbreviated).year())
            }
        }

        var body: some View {
            List {
                ForEach(financeManager.entries.sorted(by: { $0.date > $1.date })) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: financeManager.categoryIcon(for: entry))
                            .font(.caption)
                            .foregroundColor(Color(hex: entry.type.color))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: entry.type.color).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.subheadline.weight(.medium))
                                .themedPrimaryText()
                                .lineLimit(1)
                            Text(financeManager.categoryDisplayName(for: entry))
                                .font(.caption)
                                .foregroundColor(theme.secondaryTextColor)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text((entry.type.isOutflow ? "-" : "+") + formatCurrency(entry.amount))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundColor(entry.type.isOutflow ? .red : .green)
                            Text(entryDateText(entry.date))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(entry)
                    }
                    .listRowBackground(theme.surfaceColor)
                }
            }
            .scrollContentBackground(.hidden)
            .themedBackground()
            .navigationTitle("recent_entries".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// All items that can be shown in the gauge (overall + per-category budgets)
    private var budgetGaugeItems: [(label: String, limit: Double, spent: Double)] {
        var items: [(label: String, limit: Double, spent: Double)] = []
        let period = financeManager.currentMonthPeriod()
        
        if financeManager.monthlyBudgetTarget > 0 {
            items.append((
                label: "budget_total".localized,
                limit: financeManager.monthlyBudgetTarget,
                spent: financeManager.monthlyExpenses
            ))
        }
        
        for budget in financeManager.budgets where budget.isActive {
            let spent = financeManager.spentAmount(for: budget, in: period)
            items.append((
                label: financeManager.budgetDisplayName(for: budget),
                limit: budget.monthlyLimit,
                spent: spent
            ))
        }
        return items
    }
    
    /// Only individual category items for the cards grid
    private var budgetCategoryItems: [(label: String, icon: String, limit: Double, spent: Double, color: Color)] {
        let period = financeManager.currentMonthPeriod()
        return financeManager.budgets.filter { $0.isActive }.map { budget in
            let spent = financeManager.spentAmount(for: budget, in: period)
            return (
                label: financeManager.budgetDisplayName(for: budget),
                icon: financeManager.budgetIcon(for: budget),
                limit: budget.monthlyLimit,
                spent: spent,
                color: Color(hex: financeManager.budgetColorHex(for: budget))
            )
        }
    }
    
    // MARK: - Budget Alerts
    
    private var budgetAlertsCard: some View {
        let items = financeManager.overBudgetCategories()
        return VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("over_budget".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
            }

            ForEach(items, id: \.0.id) { budget, usage in
                HStack {
                    Image(systemName: financeManager.budgetIcon(for: budget))
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 20)
                    Text(financeManager.budgetDisplayName(for: budget))
                        .font(.caption.weight(.medium))
                        .themedPrimaryText()
                    Spacer()
                    Text(String(format: "%.0f%%", usage * 100))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .themedCard()
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: 12) {
            // Always show balance
            VStack(spacing: 10) {
                Text("current_balance".localized)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                
                Text(formatCurrency(financeManager.currentBalance))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(financeManager.currentBalance >= 0 ? .green : .red)
                
                if financeManager.startingBalance > 0 {
                    let change = financeManager.currentBalance - financeManager.startingBalance
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11))
                        Text(formatCurrency(abs(change)))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                        Text("since_start".localized)
                            .font(.caption)
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .themedCard()
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        Button {
            showingAddEntry = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("add_entry".localized)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(theme.buttonTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.primaryColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Summary Content (Monthly / Yearly toggle) — lives inside chartsSection card
    
    private var summaryCardContent: some View {
        let isYearly = summaryShowsYearly
        let calendar = Calendar.current
        let now = Date()

        // Compute the exact period based on offset
        let periodIncome: Double
        let periodExpenses: Double
        let periodLabel: String
        let periodRate: Double

        if isYearly {
            let base = calendar.date(byAdding: .year, value: -summaryOffset, to: now) ?? now
            let year = calendar.component(.year, from: base)
            guard let yearStart = calendar.dateInterval(of: .year, for: base)?.start,
                  let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
                return AnyView(EmptyView())
            }
            let interval = DateInterval(start: yearStart, end: summaryOffset == 0 ? now : yearEnd)
            periodIncome   = financeManager.totalIncome(for: interval)
            periodExpenses = financeManager.totalExpenses(for: interval)
            periodLabel    = "\(year)"
            let inc = periodIncome
            periodRate = inc > 0 ? max((inc - periodExpenses) / inc, 0) : 0
        } else {
            let base = calendar.date(byAdding: .month, value: -summaryOffset, to: now) ?? now
            guard let monthInterval = calendar.dateInterval(of: .month, for: base) else {
                return AnyView(EmptyView())
            }
            let df = DateFormatter()
            df.locale = Locale.current
            df.dateFormat = "MMMM yyyy"
            periodLabel    = df.string(from: monthInterval.start)
            let interval   = summaryOffset == 0
                ? DateInterval(start: monthInterval.start, end: now)
                : monthInterval
            periodIncome   = financeManager.totalIncome(for: interval)
            periodExpenses = financeManager.totalExpenses(for: interval)
            let inc = periodIncome
            periodRate = inc > 0 ? max((inc - periodExpenses) / inc, 0) : 0
        }

        let net = periodIncome - periodExpenses
        let rateColor: Color = periodRate >= 0.2 ? .green : periodRate >= 0.1 ? .orange : .red

        // Yearly avg/projection helpers (only used when isYearly + offset 0)
        let calendar2 = Calendar.current
        let monthsElapsed = max(calendar2.component(.month, from: now), 1)
        let avgIncome   = summaryOffset == 0 ? periodIncome / Double(monthsElapsed) : periodIncome / 12.0
        let avgExpenses = summaryOffset == 0 ? periodExpenses / Double(monthsElapsed) : periodExpenses / 12.0
        let projNet = avgIncome * 12 - avgExpenses * 12

        return AnyView(
            VStack(spacing: 14) {
                // Header: label on left, month/year toggle on right, then nav
                HStack {
                    Text(isYearly ? "yearly_overview".localized : "monthly_overview".localized)
                        .font(.subheadline.weight(.semibold))
                        .themedPrimaryText()
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                summaryShowsYearly = false
                                summaryOffset = 0
                            }
                        } label: {
                            Text("period_month".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(!isYearly ? theme.buttonTextColor : theme.secondaryTextColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(!isYearly ? theme.primaryColor : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                summaryShowsYearly = true
                                summaryOffset = 0
                            }
                        } label: {
                            Text("ytd".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(isYearly ? theme.buttonTextColor : theme.secondaryTextColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isYearly ? theme.primaryColor : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(theme.secondaryTextColor.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Period navigation row
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { summaryOffset += 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.primaryColor)
                            .frame(width: 28, height: 28)
                            .background(theme.primaryColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(periodLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { summaryOffset -= 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(summaryOffset > 0 ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .background((summaryOffset > 0 ? theme.primaryColor : theme.secondaryTextColor).opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(summaryOffset == 0)
                }

                // Numbers row
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        Text(formatCurrency(periodIncome))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundColor(.green)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("income".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text(formatCurrency(periodExpenses))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundColor(.red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("expenses".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Image(systemName: net >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(net >= 0 ? .green : .red)
                        Text(formatCurrency(abs(net)))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundColor(net >= 0 ? .green : .red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("net".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Yearly-only: averages + projection
                if isYearly {
                    Divider().background(theme.secondaryTextColor.opacity(0.15))
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("avg_monthly".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                            Text(formatCurrency(avgIncome))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(.green)
                                .minimumScaleFactor(0.7).lineLimit(1)
                            Text("income".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("avg_monthly".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                            Text(formatCurrency(avgExpenses))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(.red)
                                .minimumScaleFactor(0.7).lineLimit(1)
                            Text("expenses".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: 4) {
                            Text("projected".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                            Text(formatCurrency(abs(projNet)))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundColor(projNet >= 0 ? .green : .red)
                                .minimumScaleFactor(0.7).lineLimit(1)
                            Text("annual_net".localized)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Savings rate bar
                VStack(spacing: 6) {
                    HStack {
                        Text(isYearly ? "ytd_savings_rate".localized : "savings_rate".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                        Spacer()
                        Text("\(Int(periodRate * 100))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(rateColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.secondaryTextColor.opacity(0.12))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(rateColor)
                                .frame(width: geo.size.width * min(periodRate, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: summaryShowsYearly)
            .animation(.easeInOut(duration: 0.2), value: summaryOffset)
        )
    }
    
    private var savingsColor: Color {
        switch financeManager.monthlySavingsRate {
        case 0.2...: return .green
        case 0.1..<0.2: return .orange
        default: return .red
        }
    }
    
    // MARK: - Chart Helpers

    private func periodInterval(for period: ChartPeriod, offset: Int = 0) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .day:
            let base = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let start = calendar.startOfDay(for: base)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            let base = calendar.date(byAdding: .weekOfYear, value: -offset, to: now) ?? now
            let start = calendar.dateInterval(of: .weekOfYear, for: base)?.start ?? base
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .month:
            let base = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let start = calendar.dateInterval(of: .month, for: base)?.start ?? base
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .year:
            let base = calendar.date(byAdding: .year, value: -offset, to: now) ?? now
            let start = calendar.dateInterval(of: .year, for: base)?.start ?? base
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }

    private func periodLabel(for period: ChartPeriod, offset: Int) -> String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        switch period {
        case .day:
            if offset == 0 { return "today".localized }
            if offset == 1 { return "yesterday".localized }
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            formatter.dateFormat = "EEE d MMM"
            return formatter.string(from: date)
        case .week:
            let base = calendar.date(byAdding: .weekOfYear, value: -offset, to: now) ?? now
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: base)?.start,
                  let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
                return ""
            }
            let weekNum = calendar.component(.weekOfYear, from: weekStart)
            formatter.dateFormat = "d MMM"
            let startStr = formatter.string(from: weekStart)
            let endStr = formatter.string(from: weekEnd)
            return "W\(weekNum) • \(startStr)–\(endStr)"
        case .month:
            let base = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: base)
        case .year:
            let base = calendar.date(byAdding: .year, value: -offset, to: now) ?? now
            formatter.dateFormat = "yyyy"
            return formatter.string(from: base)
        }
    }
    
    // MARK: - Expense Breakdown Chart Content (without card wrapper)
    
    private var expenseBreakdownChartContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("expense_breakdown".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
                ThemedSegmentedPicker(selection: $breakdownStyle, options: Array(ChartStyle.allCases)) { style in
                    Image(systemName: style.icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 108, height: 48)
            }
            .padding(.top, 4)

            ThemedSegmentedPicker(selection: $breakdownPeriod, options: Array(ChartPeriod.allCases)) { period in
                Text(period.displayName)
            }
            .onChange(of: breakdownPeriod) { _ in breakdownOffset = 0; selectedBreakdownKey = nil }
            .onChange(of: breakdownStyle) { _ in selectedBreakdownKey = nil }

            // Period navigation row
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { breakdownOffset += 1; selectedBreakdownKey = nil }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 28, height: 28)
                        .background(theme.primaryColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(periodLabel(for: breakdownPeriod, offset: breakdownOffset))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { breakdownOffset -= 1; selectedBreakdownKey = nil }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(breakdownOffset > 0 ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background((breakdownOffset > 0 ? theme.primaryColor : theme.secondaryTextColor).opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(breakdownOffset == 0)
            }

            let breakdown = financeManager.expenseBreakdownDetailed(for: periodInterval(for: breakdownPeriod, offset: breakdownOffset))
            
            if breakdown.isEmpty {
                Text("no_data_yet".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                let isSingleBar = breakdown.count == 1

                if breakdownStyle == .pie {
                    // Interactive donut chart
                    ZStack {
                        Chart(breakdown, id: \.0.id) { item in
                            let isSelected = selectedBreakdownKey == item.0
                            SectorMark(
                                angle: .value(financeManager.expenseBreakdownDisplayName(for: item.0), item.1),
                                innerRadius: .ratio(isSelected ? 0.45 : 0.55),
                                outerRadius: .ratio(isSelected ? 1.0 : 0.95),
                                angularInset: 2
                            )
                            .foregroundStyle(Color(hex: financeManager.expenseBreakdownColorHex(for: item.0)))
                            .cornerRadius(4)
                            .opacity(selectedBreakdownKey == nil || isSelected ? 1.0 : 0.45)
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        guard let plotFrame = proxy.plotFrame.map({ geo[$0] }) else { return }
                                        let center = CGPoint(x: plotFrame.midX, y: plotFrame.midY)
                                        let dx = location.x - center.x
                                        let dy = location.y - center.y
                                        // angle from top (12 o'clock), clockwise, 0-360°
                                        var angle = atan2(dx, -dy) * 180 / .pi
                                        if angle < 0 { angle += 360 }
                                        let total = breakdown.reduce(0.0) { $0 + $1.1 }
                                        var cumulative = 0.0
                                        for item in breakdown {
                                            cumulative += item.1 / total * 360
                                            if angle <= cumulative {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedBreakdownKey = (selectedBreakdownKey == item.0) ? nil : item.0
                                                }
                                                return
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedBreakdownKey = nil
                                        }
                                    }
                            }
                        }
                        .frame(height: 180)
                        .padding(.vertical, 4)

                        // Center label when a sector is selected — non-interactive so it never blocks chart taps
                        if let key = selectedBreakdownKey,
                           let item = breakdown.first(where: { $0.0 == key }) {
                            VStack(spacing: 2) {
                                Text(financeManager.expenseBreakdownDisplayName(for: item.0))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(theme.secondaryTextColor)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                                Text(formatCurrency(item.1))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundColor(Color(hex: financeManager.expenseBreakdownColorHex(for: item.0)))
                                let total = breakdown.reduce(0.0) { $0 + $1.1 }
                                Text(String(format: "%.0f%%", item.1 / total * 100))
                                    .font(.caption2)
                                    .foregroundColor(theme.secondaryTextColor)
                            }
                            .frame(width: 90)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 188)
                } else {
                    // Bar chart: horizontal scroll to avoid label overlap
                    let barWidth: CGFloat = isSingleBar ? 60 : 52
                    let chartWidth = max(280, CGFloat(breakdown.count) * barWidth)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Chart(breakdown, id: \.0.id) { item in
                            BarMark(
                                x: .value("category".localized, financeManager.expenseBreakdownDisplayName(for: item.0)),
                                y: .value("amount".localized, item.1)
                            )
                            .foregroundStyle(Color(hex: financeManager.expenseBreakdownColorHex(for: item.0)))
                            .cornerRadius(4)
                            .opacity(selectedBreakdownKey == nil || selectedBreakdownKey == item.0 ? 1.0 : 0.35)
                        }
                        .frame(width: chartWidth, height: 180)
                        .padding(.vertical, 4)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(formatCompact(v))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { location in
                                        guard let frame = proxy.plotFrame.map({ geo[$0] }) else { return }
                                        let x = location.x - frame.minX
                                        if let tappedLabel: String = proxy.value(atX: x) {
                                            if let tappedKey = breakdown.first(where: {
                                                financeManager.expenseBreakdownDisplayName(for: $0.0) == tappedLabel
                                            })?.0 {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedBreakdownKey = (selectedBreakdownKey == tappedKey) ? nil : tappedKey
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .frame(height: 188)
                }

                // Single ScrollView always at fixed height — prevents ANY layout shift on selection
                ScrollView(.vertical, showsIndicators: false) {
                    if let key = selectedBreakdownKey,
                       let selectedItem = breakdown.first(where: { $0.0 == key }) {
                        let accentColor = Color(hex: financeManager.expenseBreakdownColorHex(for: key))
                        let interval = periodInterval(for: breakdownPeriod, offset: breakdownOffset)
                        let detailEntries = financeManager.entries(for: interval)
                            .filter { entry in
                                guard entry.type.isOutflow else { return false }
                                switch key {
                                case .builtIn(let cat): return entry.customCategoryId == nil && entry.category == cat
                                case .custom(let id): return entry.customCategoryId == id
                                }
                            }
                            .sorted { $0.date > $1.date }

                        VStack(alignment: .leading, spacing: 0) {
                            // Selected category header
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 10, height: 10)
                                Image(systemName: financeManager.expenseBreakdownIcon(for: key))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(accentColor)
                                Text(financeManager.expenseBreakdownDisplayName(for: key))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(accentColor)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatCurrency(selectedItem.1))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundColor(accentColor)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedBreakdownKey = nil }
                            }
                            .padding(.bottom, 8)

                            Divider().padding(.bottom, 4)

                            ForEach(detailEntries) { entry in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.name)
                                            .font(.caption.weight(.medium))
                                            .themedPrimaryText()
                                            .lineLimit(1)
                                        Text(entryDateText(entry.date))
                                            .font(.caption2)
                                            .foregroundColor(theme.secondaryTextColor)
                                    }
                                    Spacer()
                                    Text("-" + formatCurrency(entry.amount))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundColor(.red)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { editingEntry = entry }
                                .padding(.vertical, 5)

                                if entry.id != detailEntries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(breakdown, id: \.0.id) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: financeManager.expenseBreakdownColorHex(for: item.0)))
                                        .frame(width: 10, height: 10)
                                    Text(financeManager.expenseBreakdownDisplayName(for: item.0))
                                        .font(.caption)
                                        .themedPrimaryText()
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatCurrency(item.1))
                                        .font(.caption.weight(.medium).monospacedDigit())
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedBreakdownKey = item.0
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Trend Chart Content (without card wrapper)
    
    private var trendChartContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trendChartTitle)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
                ThemedSegmentedPicker(selection: $trendStyle, options: Array(ChartStyle.allCases)) { style in
                    Image(systemName: style.icon)
                }
                .frame(width: 100)
            }

            ThemedSegmentedPicker(selection: $trendPeriod, options: Array(ChartPeriod.allCases)) { period in
                Text(period.displayName)
            }
            .onChange(of: trendPeriod) { _ in trendOffset = 0 }

            // Period navigation row
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { trendOffset += 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 28, height: 28)
                        .background(theme.primaryColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(periodLabel(for: trendPeriod, offset: trendOffset))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { trendOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(trendOffset > 0 ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background((trendOffset > 0 ? theme.primaryColor : theme.secondaryTextColor).opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(trendOffset == 0)
            }

            let trendData = trendData(for: trendPeriod, offset: trendOffset)
            
            if trendData.isEmpty {
                Text("no_data_yet".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                if trendStyle == .bar {
                    Chart {
                        ForEach(trendData, id: \.date) { item in
                            BarMark(
                                x: .value("period".localized, item.label),
                                y: .value("income".localized, item.income)
                            )
                            .foregroundStyle(.green.opacity(0.7))
                            .cornerRadius(4)
                            .position(by: .value("type", "income"))
                            
                            BarMark(
                                x: .value("period".localized, item.label),
                                y: .value("expenses".localized, item.expenses)
                            )
                            .foregroundStyle(.red.opacity(0.7))
                            .cornerRadius(4)
                            .position(by: .value("type", "expenses"))
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical, 4)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(formatCompact(v))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                } else {
                    // Pie chart: show totals for the period
                    let totalInc = trendData.reduce(0) { $0 + $1.income }
                    let totalExp = trendData.reduce(0) { $0 + $1.expenses }
                    Chart {
                        SectorMark(
                            angle: .value("income".localized, totalInc),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(.green.opacity(0.7))
                        .cornerRadius(4)
                        
                        SectorMark(
                            angle: .value("expenses".localized, totalExp),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(.red.opacity(0.7))
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .padding(.vertical, 4)
                }
                
                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.green.opacity(0.7))
                            .frame(width: 12, height: 12)
                        Text("income".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.red.opacity(0.7))
                            .frame(width: 12, height: 12)
                        Text("expenses".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Charts Section (Combined with TabView)
    
    @State private var selectedChartTab = 0
    
    private var chartsSection: some View {
        VStack(spacing: 12) {
            // Tab indicator dots
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(selectedChartTab == index ? theme.primaryColor : theme.secondaryTextColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedChartTab = index
                            }
                        }
                }
            }
            
            TabView(selection: $selectedChartTab) {
                expenseBreakdownChartContent
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(0)
                
                trendChartContent
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(1)
                
                summaryCardContent
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 560)
        }
        .padding(16)
        .themedCard()
    }
    
    private var trendChartTitle: String {
        switch trendPeriod {
        case .day: return "hourly_trend".localized
        case .week: return "daily_trend".localized
        case .month: return "monthly_trend".localized
        case .year: return "yearly_trend".localized
        }
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("recent_entries".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
                Button {
                    showingAllEntries = true
                } label: {
                    Text("show_more".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.primaryColor)
                }
                .buttonStyle(.plain)
                .opacity(financeManager.entries.isEmpty ? 0 : 1)
                .disabled(financeManager.entries.isEmpty)
            }
            
            if financeManager.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "banknote")
                        .font(.title)
                        .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                    Text("no_finance_entries".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(financeManager.entries.sorted(by: { $0.date > $1.date }).prefix(4)) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: financeManager.categoryIcon(for: entry))
                            .font(.caption)
                            .foregroundColor(Color(hex: entry.type.color))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: entry.type.color).opacity(0.12))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.subheadline.weight(.medium))
                                .themedPrimaryText()
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(financeManager.categoryDisplayName(for: entry))
                                    .font(.caption)
                                if entry.isRecurring {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 9))
                                }
                            }
                            .foregroundColor(theme.secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text((entry.type.isOutflow ? "-" : "+") + formatCurrency(entry.amount))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundColor(entry.type.isOutflow ? .red : .green)
                            Text(entryDateText(entry.date))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingEntry = entry
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("edit".localized, systemImage: "pencil")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            financeManager.removeEntry(entry)
                        } label: {
                            Label("delete".localized, systemImage: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .themedCard()
    }
    
    // MARK: - Subscriptions
    
    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(.orange)
                Text("active_subscriptions".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
                Text(formatCurrency(financeManager.monthlySubscriptionCost) + "/mo")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(.orange)
            }
            
            ForEach(financeManager.activeSubscriptions) { sub in
                HStack {
                    Text(sub.name)
                        .font(.subheadline)
                        .themedPrimaryText()
                    Spacer()
                    Text(formatCurrency(sub.amount))
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundColor(theme.secondaryTextColor)
                    if let freq = sub.recurringFrequency {
                        Text("/ " + freq.displayName)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingEntry = sub
                }
            }
        }
        .padding(16)
        .themedCard()
    }
    
    private func categoryColor(_ cat: FinanceCategory) -> String {
        switch cat {
        case .housing: return "#3B82F6"
        case .food: return "#F97316"
        case .transport: return "#8B5CF6"
        case .health: return "#EF4444"
        case .entertainment: return "#EC4899"
        case .education: return "#06B6D4"
        case .clothing: return "#F59E0B"
        case .utilities: return "#6366F1"
        case .insurance: return "#14B8A6"
        case .salary: return "#22C55E"
        case .freelance: return "#10B981"
        case .passive: return "#84CC16"
        case .gifts: return "#A855F7"
        case .other: return "#6B7280"
        }
    }
    
    private struct TrendItem {
        let date: Date
        let label: String
        let income: Double
        let expenses: Double
    }
    
    private func trendData(for period: ChartPeriod, offset: Int = 0) -> [TrendItem] {
        let calendar = Calendar.current
        let now = Date()
        var items: [TrendItem] = []
        let formatter = DateFormatter()
        
        switch period {
        case .day:
            // Show 3-hour buckets of the target day
            formatter.dateFormat = "HH"
            let base = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let startOfDay = calendar.startOfDay(for: base)
            let isToday = offset == 0
            let lastHour = isToday ? calendar.component(.hour, from: now) : 23
            for h in stride(from: 0, through: lastHour, by: 3) {
                guard let hourStart = calendar.date(byAdding: .hour, value: h, to: startOfDay),
                      let hourEnd = calendar.date(byAdding: .hour, value: 3, to: hourStart) else { continue }
                let interval = DateInterval(start: hourStart, end: hourEnd)
                items.append(TrendItem(
                    date: hourStart,
                    label: formatter.string(from: hourStart),
                    income: financeManager.totalIncome(for: interval),
                    expenses: financeManager.totalExpenses(for: interval)
                ))
            }
        case .week:
            // Show days of the target week
            formatter.dateFormat = "EEE"
            let base = calendar.date(byAdding: .weekOfYear, value: -offset, to: now) ?? now
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: base)?.start else { return [] }
            for d in 0..<7 {
                guard let dayStart = calendar.date(byAdding: .day, value: d, to: weekStart),
                      let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
                let interval = DateInterval(start: dayStart, end: dayEnd)
                items.append(TrendItem(
                    date: dayStart,
                    label: formatter.string(from: dayStart),
                    income: financeManager.totalIncome(for: interval),
                    expenses: financeManager.totalExpenses(for: interval)
                ))
            }
        case .month:
            // Show 6 monthly buckets ending at `offset` months ago
            formatter.dateFormat = "MMM"
            for i in (0..<6).reversed() {
                guard let monthStart = calendar.date(byAdding: .month, value: -(i + offset), to: now),
                      let interval = calendar.dateInterval(of: .month, for: monthStart) else { continue }
                items.append(TrendItem(
                    date: interval.start,
                    label: formatter.string(from: interval.start),
                    income: financeManager.totalIncome(for: interval),
                    expenses: financeManager.totalExpenses(for: interval)
                ))
            }
        case .year:
            // Show 4 yearly buckets ending at `offset` years ago
            formatter.dateFormat = "yyyy"
            for i in (0..<4).reversed() {
                guard let yearStart = calendar.date(byAdding: .year, value: -(i + offset), to: now),
                      let interval = calendar.dateInterval(of: .year, for: yearStart) else { continue }
                items.append(TrendItem(
                    date: interval.start,
                    label: formatter.string(from: interval.start),
                    income: financeManager.totalIncome(for: interval),
                    expenses: financeManager.totalExpenses(for: interval)
                ))
            }
        }
        return items
    }
    
    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = financeManager.selectedCurrency.rawValue
        formatter.currencySymbol = financeManager.selectedCurrency.symbol
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(financeManager.selectedCurrency.symbol)\(Int(amount))"
    }

    private func entryDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        } else {
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }
}

// MARK: - Budget Overall Gauge (large speedometer-style semicircle)

private struct BudgetOverallGauge: View {
    let progress: Double  // 0...1+ (spent / limit)
    let spentPercent: Int
    let remaining: Double
    let totalLimit: Double
    let formatCurrency: (Double) -> String
    @Environment(\.theme) private var theme
    
    private let gaugeLineWidth: CGFloat = 20
    
    private var gaugeColor: Color {
        if progress > 1.0 { return .red }
        if progress > 0.8 { return .orange }
        return theme.primaryColor
    }
    
    var body: some View {
        GeometryReader { geo in
            let gaugeWidth = geo.size.width
            let gaugeHeight = gaugeWidth / 2
            let extraBottom: CGFloat = 40  // room for labels perfectly below arc endpoints
            
            ZStack(alignment: .top) {
                // Background track
                ArcShape(startAngle: .degrees(180), endAngle: .degrees(0))
                    .stroke(
                        Color.gray.opacity(0.25),
                        style: StrokeStyle(lineWidth: gaugeLineWidth, lineCap: .round)
                    )
                    .frame(width: gaugeWidth, height: gaugeHeight)
                
                // Filled arc
                ArcShape(
                    startAngle: .degrees(180),
                    endAngle: .degrees(180 + min(progress, 1.0) * 180)
                )
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: gaugeLineWidth, lineCap: .round)
                )
                .frame(width: gaugeWidth, height: gaugeHeight)
                
                // Needle indicator
                GaugeNeedle(progress: min(progress, 1.0))
                    .frame(width: gaugeWidth, height: gaugeHeight)
                
                // Center text: positioned in the open belly of the semicircle
                VStack(spacing: 3) {
                    Text("\(spentPercent)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(gaugeColor)
                    
                    Text(formatCurrency(remaining))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(theme.textColor)
                    
                    Text("left_this_month".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .position(x: gaugeWidth / 2, y: gaugeHeight * 0.72)
                
                // Min label — slightly inward to perfectly align with the arc stroke's visual bounds
                Text("0,00")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                    .position(x: gaugeLineWidth * 0.5, y: gaugeHeight + 25)
                
                // Max label — slightly inward
                Text(formatCurrency(totalLimit))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                    .position(x: gaugeWidth - gaugeLineWidth * 0.5, y: gaugeHeight + 25)
            }
            // Add extra height purely for the label bounds so they don't clip
            .frame(width: gaugeWidth, height: gaugeHeight + extraBottom)
        }
        // Aspect Ratio 1 : 0.6 to allocate the space properly considering labels
        .aspectRatio(CGSize(width: 1, height: 0.6), contentMode: .fit)
    }
}

// MARK: - Budget Category Card

private struct BudgetCategoryCard: View {
    let label: String
    let icon: String
    let limit: Double
    let spent: Double
    let daysLeft: Int
    let categoryColor: Color
    let formatCurrency: (Double) -> String
    @Environment(\.theme) private var theme
    
    private var remaining: Double {
        max(limit - spent, 0)
    }
    
    private var spentPercent: Int {
        guard limit > 0 else { return 0 }
        return Int(min(spent / limit * 100, 999))
    }
    
    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }
    
    private var spentColor: Color {
        let ratio = limit > 0 ? spent / limit : 0
        if ratio > 1.0 { return .red }
        if ratio > 0.8 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon + name
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(categoryColor)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textColor)
                    .lineLimit(1)
            }
            
            // Days left
            Text(String(format: "budget_days_left".localized, daysLeft))
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
            
            Spacer(minLength: 4)
            
            // Spent percentage + amount
            HStack(spacing: 6) {
                Text("\(spentPercent)%")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundColor(spentColor)
                Text("(\(formatCurrency(spent)))")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                Text("SPENT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
            }
            
            // Remaining amount
            Text(formatCurrency(remaining))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(theme.textColor)
            
            Text("left_this_month".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryTextColor)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.secondaryTextColor.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor, categoryColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, 4))
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Arc Shape for gauge

private struct ArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height * 2) / 2 - 8
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Gauge Needle

private struct GaugeNeedle: View {
    let progress: Double  // 0...1
    @Environment(\.theme) private var theme
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height)
            let radius = min(geo.size.width, geo.size.height * 2) / 2 - 8
            let angle = Angle.degrees(180 + progress * 180)
            let tipX = center.x + radius * CGFloat(cos(angle.radians))
            let tipY = center.y + radius * CGFloat(sin(angle.radians))
            
            // Glowing dot indicator on the arc
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .shadow(color: Color.black.opacity(0.35), radius: 6)
                .position(x: tipX, y: tipY)
        }
    }
}
