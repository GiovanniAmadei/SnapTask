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
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
    
    /// How many of these periods the trend chart shows.
    var trendBucketCount: Int {
        switch self {
        case .day: return 14
        case .week: return 8
        case .month: return 6
        case .year: return 4
        }
    }
    
    /// Label every n-th bar on the trend axis so the labels never collide.
    var axisStride: Int {
        switch self {
        case .day: return 3
        case .week: return 2
        case .month, .year: return 1
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

/// One slice of the expense breakdown (the smallest categories are folded into "Other").
private struct BreakdownSlice: Identifiable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let value: Double
}

struct FinanceDashboardView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @State private var showingAddEntry = false
    @State private var editingEntry: FinanceEntry?
    @State private var editingGoal: FinancialGoal?
    @State private var showingAllEntries = false
    @State private var showingCardLayout = false
    @State private var breakdownPeriod: ChartPeriod = .month
    @State private var breakdownOffset = 0
    @State private var breakdownStyle: ChartStyle = .pie
    @State private var trendPeriod: ChartPeriod = .month
    @State private var summaryShowsYearly: Bool = false
    @State private var selectedAngle: Double?
    @State private var selectedSliceID: String?
    @State private var trendSelection: Date?
    @AppStorage(FinanceCardLayout.storageKey) private var cardLayoutRaw = ""
    
    private var activeGoals: [FinancialGoal] {
        financeManager.financialGoals.filter { $0.isActive }
    }
    
    private var isTotalBudgetExceeded: Bool {
        financeManager.monthlyBudgetTarget > 0 && financeManager.monthlyExpenses > financeManager.monthlyBudgetTarget
    }
    
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
                    .accessibilityLabel("finance_settings".localized)
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

                    // Everything else follows the order chosen by the user
                    ForEach(FinanceCardLayout(rawValue: cardLayoutRaw).visibleCards) { card in
                        dashboardCard(card)
                    }
                    
                    customizeCardsButton
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
        .sheet(item: $editingGoal) { goal in
            NavigationStack {
                FinancialGoalFormView(goal: goal)
            }
        }
        .sheet(isPresented: $showingAllEntries) {
            NavigationStack {
                FinanceAllEntriesView()
            }
        }
        .sheet(isPresented: $showingCardLayout) {
            NavigationStack {
                FinanceCardLayoutView(showsDoneButton: true)
            }
        }
    }
    
    // MARK: - Card list
    
    @ViewBuilder
    private func dashboardCard(_ card: FinanceDashboardCard) -> some View {
        switch card {
        case .recentEntries:
            recentEntriesSection
        case .monthlyGoals:
            if hasGoalsConfigured { goalProgressSection }
        case .savingsGoals:
            if !activeGoals.isEmpty { financialGoalsCard }
        case .budgetAlerts:
            if !financeManager.overBudgetCategories().isEmpty || isTotalBudgetExceeded { budgetAlertsCard }
        case .breakdown:
            expenseBreakdownCard
        case .trend:
            trendCard
        case .summary:
            summaryCard
        case .subscriptions:
            if !financeManager.activeSubscriptions.isEmpty { subscriptionsSection }
        case .budget:
            if budgetGaugeTotals != nil { budgetManagementCard }
        }
    }
    
    private var customizeCardsButton: some View {
        Button {
            showingCardLayout = true
        } label: {
            Label("finance_customize_cards".localized, systemImage: "slider.horizontal.3")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.primaryColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Capsule().fill(theme.primaryColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
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
                    current: formatWhole(financeManager.monthlyExpenses),
                    target: formatWhole(financeManager.monthlyBudgetTarget),
                    progress: min(progress, 1.5),
                    isInverted: true
                )
            }
            
            if let progress = financeManager.savingsProgress {
                if financeManager.savingsGoalIsPercent {
                    goalRow(
                        icon: "banknote.fill",
                        title: "savings_goal".localized,
                        current: financeManager.formatPercent(financeManager.monthlySavingsRate, maxFractionDigits: 1),
                        target: financeManager.formatPercent(financeManager.savingsGoalPercent / 100, maxFractionDigits: 1),
                        progress: min(progress, 1.5),
                        isInverted: false
                    )
                } else {
                    let actualSavings = max(financeManager.monthlyIncome - financeManager.monthlyExpenses, 0)
                    goalRow(
                        icon: "banknote.fill",
                        title: "savings_goal".localized,
                        current: formatWhole(actualSavings),
                        target: formatWhole(financeManager.savingsGoalAmount),
                        progress: min(progress, 1.5),
                        isInverted: false
                    )
                }
            }
            
            if let progress = financeManager.incomeProgress {
                goalRow(
                    icon: "arrow.down.circle.fill",
                    title: "income_goal".localized,
                    current: formatWhole(financeManager.monthlyIncome),
                    target: formatWhole(financeManager.monthlyIncomeGoal),
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
                        .frame(width: geo.size.width * min(max(progress, 0), 1.0))
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
    
    // MARK: - Savings Goals
    
    private var financialGoalsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.subheadline)
                    .foregroundColor(theme.primaryColor)
                Text("financial_goals".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
            }
            
            ForEach(activeGoals) { goal in
                Button {
                    editingGoal = goal
                } label: {
                    financialGoalRow(goal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .themedCard()
    }
    
    private func financialGoalRow(_ goal: FinancialGoal) -> some View {
        let color: Color = goal.isCompleted ? .green : theme.primaryColor
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: goal.type.icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(goal.name)
                    .font(.caption.weight(.medium))
                    .themedPrimaryText()
                Spacer()
                Text(financeManager.formatPercent(goal.progress))
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.secondaryTextColor.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * goal.progress)
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 8) {
                Text("\(formatWhole(goal.currentAmount)) / \(formatWhole(goal.targetAmount))")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                Spacer()
                Text(goalInfoText(goal))
                    .font(.caption2)
                    .foregroundColor(goal.isCompleted ? .green : theme.secondaryTextColor)
                    .multilineTextAlignment(.trailing)
            }
        }
        .contentShape(Rectangle())
    }
    
    private func goalInfoText(_ goal: FinancialGoal) -> String {
        if goal.isCompleted { return "goal_completed".localized }
        if let monthly = goal.monthlyNeeded, goal.targetDate != nil {
            return String(format: "goal_save_per_month".localized, formatWhole(monthly))
        }
        return String(format: "goal_to_go".localized, formatWhole(goal.remainingAmount))
    }
    
    // MARK: - Budget Management
    
    /// Days left in the month, today included.
    private var daysLeftInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return 0 }
        return max(range.count - calendar.component(.day, from: now) + 1, 0)
    }
    
    /// What the gauge shows: the monthly budget when set, otherwise the sum of the category budgets.
    private var budgetGaugeTotals: (limit: Double, spent: Double)? {
        if financeManager.monthlyBudgetTarget > 0 {
            return (financeManager.monthlyBudgetTarget, financeManager.monthlyExpenses)
        }
        let items = budgetCategoryItems
        guard !items.isEmpty else { return nil }
        return (items.reduce(0) { $0 + $1.limit }, items.reduce(0) { $0 + $1.spent })
    }
    
    private var budgetManagementCard: some View {
        let categoryItems = budgetCategoryItems
        
        return VStack(alignment: .leading, spacing: 16) {
            cardHeader("budget_management".localized, icon: FinanceDashboardCard.budget.icon)
            
            if let totals = budgetGaugeTotals {
                let remaining = max(totals.limit - totals.spent, 0)
                VStack(spacing: 8) {
                    BudgetOverallGauge(
                        progress: totals.limit > 0 ? min(totals.spent / totals.limit, 1.5) : 0,
                        spentPercent: totals.limit > 0 ? Int(min(totals.spent / totals.limit * 100, 999)) : 0,
                        remaining: remaining,
                        overAmount: max(totals.spent - totals.limit, 0),
                        totalLimit: totals.limit,
                        formatCurrency: formatWhole
                    )
                    
                    Text(budgetPaceText(remaining: remaining))
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if !categoryItems.isEmpty {
                VStack(spacing: 14) {
                    ForEach(categoryItems, id: \.id) { item in
                        BudgetCategoryRow(
                            label: item.label,
                            icon: item.icon,
                            limit: item.limit,
                            spent: item.spent,
                            categoryColor: item.color,
                            formatCurrency: formatWhole
                        )
                    }
                }
            }
        }
        .padding(16)
        .themedCard()
    }
    
    /// "27 giorni rimanenti · circa 12 € al giorno"
    private func budgetPaceText(remaining: Double) -> String {
        let days = daysLeftInMonth
        var text = String(format: "budget_days_left".localized, days)
        if remaining > 0, days > 0 {
            text += " · " + String(format: "budget_daily_allowance".localized, formatWhole(remaining / Double(days)))
        }
        return text
    }
    
    private var budgetCategoryItems: [(id: UUID, label: String, icon: String, limit: Double, spent: Double, color: Color)] {
        let period = financeManager.currentMonthPeriod()
        return financeManager.budgets.filter { $0.isActive }.map { budget in
            (
                id: budget.id,
                label: financeManager.budgetDisplayName(for: budget),
                icon: financeManager.budgetIcon(for: budget),
                limit: budget.monthlyLimit,
                spent: financeManager.spentAmount(for: budget, in: period),
                color: Color(hex: financeManager.budgetColorHex(for: budget))
            )
        }
    }
    
    // MARK: - Budget Alerts
    
    private var budgetAlertsCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("over_budget".localized)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                Spacer()
            }
            
            if isTotalBudgetExceeded {
                HStack {
                    Image(systemName: "cart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 20)
                    Text("budget_total".localized)
                        .font(.caption)
                        .themedPrimaryText()
                    Spacer()
                    Text(cappedPercent(financeManager.monthlyExpenses / financeManager.monthlyBudgetTarget))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(.red)
                }
            }
            
            ForEach(financeManager.overBudgetCategories(), id: \.0.id) { budget, usage in
                HStack {
                    Image(systemName: financeManager.budgetIcon(for: budget))
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 20)
                    Text(financeManager.budgetDisplayName(for: budget))
                        .font(.caption)
                        .themedPrimaryText()
                    Spacer()
                    Text(cappedPercent(usage))
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
                
                if financeManager.startingBalance != 0 {
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
    
    // MARK: - Summary (Monthly / Year to date)
    
    private var summaryCard: some View {
        let isYearly = summaryShowsYearly
        let income = isYearly ? financeManager.yearlyIncome : financeManager.monthlyIncome
        let expenses = isYearly ? financeManager.yearlyExpenses : financeManager.monthlyExpenses
        let rate = isYearly ? financeManager.yearlySavingsRate : financeManager.monthlySavingsRate
        let rateColor: Color = rate >= 0.2 ? .green : rate >= 0.1 ? .orange : .red
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return VStack(alignment: .leading, spacing: 16) {
            cardHeader(
                isYearly ? "yearly_overview".localized + " \(currentYear)" : "monthly_overview".localized,
                icon: FinanceDashboardCard.summary.icon
            )
            
            FinancePillPicker(selection: $summaryShowsYearly, options: [false, true], fillsWidth: true) { yearly in
                Text((yearly ? "ytd" : "period_month").localized)
            }
            
            flowColumns(income: income, expenses: expenses)
            
            if isYearly {
                let projectedNet = financeManager.projectedAnnualIncome - financeManager.projectedAnnualExpenses
                HStack(alignment: .top, spacing: 0) {
                    summaryStat("avg_monthly".localized, caption: "income".localized,
                                value: formatWhole(financeManager.yearlyAverageMonthlyIncome), color: .green)
                    summaryStat("avg_monthly".localized, caption: "expenses".localized,
                                value: formatWhole(financeManager.yearlyAverageMonthlyExpenses), color: .red)
                    summaryStat("projected".localized, caption: "annual_net".localized,
                                value: (projectedNet >= 0 ? "+" : "−") + formatWhole(abs(projectedNet)),
                                color: projectedNet >= 0 ? .green : .red)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.secondaryTextColor.opacity(0.12))
                        .frame(height: 1)
                }
                .transition(.opacity)
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text((isYearly ? "ytd_savings_rate" : "savings_rate").localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                    Spacer()
                    Text(financeManager.formatPercent(rate))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundColor(rateColor)
                }
                thinBar(fraction: rate, color: rateColor)
            }
        }
        .padding(16)
        .themedCard()
        .animation(.easeInOut(duration: 0.25), value: summaryShowsYearly)
    }
    
    private func summaryStat(_ title: String, caption: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(theme.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundColor(theme.secondaryTextColor.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Card building blocks
    
    /// Same header on every card: icon and title on the left, an optional control on the right.
    private func cardHeader<Trailing: View>(_ title: String, icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(theme.primaryColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .themedPrimaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            trailing()
        }
    }
    
    private func cardHeader(_ title: String, icon: String) -> some View {
        cardHeader(title, icon: icon) { EmptyView() }
    }
    
    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundColor(theme.secondaryTextColor.opacity(0.35))
            Text("no_data_yet".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }
    
    private func thinBar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.secondaryTextColor.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: fraction > 0 ? max(geo.size.width * min(fraction, 1), 6) : 0)
            }
        }
        .frame(height: 6)
    }
    
    /// Income / expenses / net in three aligned columns (trend and summary cards).
    private func flowColumns(income: Double, expenses: Double) -> some View {
        let net = income - expenses
        return HStack(alignment: .top, spacing: 0) {
            flowColumn("income".localized, value: formatWhole(income), color: .green, dot: .green)
            flowColumn("expenses".localized, value: formatWhole(expenses), color: .red, dot: .red)
            flowColumn("net".localized, value: (net >= 0 ? "+" : "−") + formatWhole(abs(net)),
                       color: net >= 0 ? .green : .red, dot: nil)
        }
    }
    
    private func flowColumn(_ title: String, value: String, color: Color, dot: Color?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let dot {
                    Circle()
                        .fill(dot.opacity(0.8))
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Periods
    
    private var appLocale: Locale {
        Locale(identifier: LanguageManager.shared.actualLanguageCode)
    }
    
    /// The day / week / month / year containing today, moved back by `offset` periods.
    private func periodInterval(for period: ChartPeriod, offset: Int = 0) -> DateInterval {
        let calendar = Calendar.current
        let reference = calendar.date(byAdding: period.calendarComponent, value: offset, to: Date()) ?? Date()
        return calendar.dateInterval(of: period.calendarComponent, for: reference)
            ?? DateInterval(start: calendar.startOfDay(for: reference), duration: 86_400)
    }
    
    /// "Oggi", "lun 28 set", "28 set – 4 ott", "Settembre 2026", "2026"
    private func periodLabel(_ period: ChartPeriod, _ interval: DateInterval) -> String {
        let calendar = Calendar.current
        let style = Date.FormatStyle().locale(appLocale)
        switch period {
        case .day:
            if calendar.isDateInToday(interval.start) { return "today".localized }
            if calendar.isDateInYesterday(interval.start) { return "yesterday".localized }
            return interval.start.formatted(style.weekday(.abbreviated).day().month(.abbreviated))
        case .week:
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let dayMonth = style.day().month(.abbreviated)
            return "\(interval.start.formatted(dayMonth)) – \(lastDay.formatted(dayMonth))"
        case .month:
            return interval.start.formatted(style.month(.wide).year()).capitalized(with: appLocale)
        case .year:
            return interval.start.formatted(style.year())
        }
    }
    
    private func periodNavigator(_ label: String, canGoForward: Bool, step: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            navigatorButton("chevron.left", accessibility: "period_previous".localized) { step(-1) }
            Spacer(minLength: 0)
            Text(label)
                .font(.footnote.weight(.semibold))
                .themedPrimaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .id(label)
                .transition(.opacity)
            Spacer(minLength: 0)
            navigatorButton("chevron.right", accessibility: "period_next".localized) { step(1) }
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.3)
        }
    }
    
    private func navigatorButton(_ icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(theme.primaryColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(theme.primaryColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
    
    // MARK: - Expense Breakdown
    
    private var expenseBreakdownCard: some View {
        let interval = periodInterval(for: breakdownPeriod, offset: breakdownOffset)
        let slices = breakdownSlices(in: interval)
        let total = slices.reduce(0) { $0 + $1.value }
        
        return VStack(alignment: .leading, spacing: 14) {
            cardHeader("expense_breakdown".localized, icon: FinanceDashboardCard.breakdown.icon) {
                FinancePillPicker(selection: $breakdownStyle, options: ChartStyle.allCases) { style in
                    Image(systemName: style.icon)
                        .accessibilityLabel(style.displayName)
                }
            }
            
            FinancePillPicker(selection: $breakdownPeriod, options: ChartPeriod.allCases, fillsWidth: true) { period in
                Text(period.displayName)
            }
            
            periodNavigator(periodLabel(breakdownPeriod, interval), canGoForward: breakdownOffset < 0) { step in
                withAnimation(.easeInOut(duration: 0.25)) { breakdownOffset += step }
            }
            
            if slices.isEmpty {
                emptyChartPlaceholder
            } else if breakdownStyle == .pie {
                breakdownDonut(slices, total: total)
                VStack(spacing: 0) {
                    ForEach(slices) { slice in
                        breakdownLegendRow(slice, total: total)
                    }
                }
            } else {
                let maxValue = slices.map(\.value).max() ?? 1
                VStack(spacing: 14) {
                    ForEach(slices) { slice in
                        breakdownBarRow(slice, total: total, maxValue: maxValue)
                    }
                }
            }
        }
        .padding(16)
        .themedCard()
        .onChange(of: breakdownPeriod) { _, _ in
            breakdownOffset = 0
            selectedSliceID = nil
        }
        .onChange(of: breakdownOffset) { _, _ in selectedSliceID = nil }
        .onChange(of: breakdownStyle) { _, _ in selectedSliceID = nil }
    }
    
    private func breakdownDonut(_ slices: [BreakdownSlice], total: Double) -> some View {
        let selected = slices.first { $0.id == selectedSliceID }
        return Chart(slices) { slice in
            SectorMark(
                angle: .value(slice.name, slice.value),
                innerRadius: .ratio(0.66),
                outerRadius: .ratio(slice.id == selectedSliceID ? 1.0 : 0.93),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: slice.colorHex))
            .opacity(selectedSliceID == nil || slice.id == selectedSliceID ? 1 : 0.3)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let rect = geo[plotFrame]
                    VStack(spacing: 2) {
                        Text(selected?.name ?? "total".localized)
                            .font(.caption.weight(.medium))
                            .foregroundColor(selected.map { Color(hex: $0.colorHex) } ?? theme.secondaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(formatWhole(selected?.value ?? total))
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .themedPrimaryText()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if let selected {
                            Text(financeManager.formatPercent(total > 0 ? selected.value / total : 0, maxFractionDigits: 1))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .frame(width: rect.width * 0.55)
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(height: 190)
        .animation(.easeInOut(duration: 0.25), value: selectedSliceID)
        .onChange(of: selectedAngle) { oldAngle, newAngle in
            guard let newAngle else { return }
            var cumulative = 0.0
            for slice in slices {
                cumulative += slice.value
                if newAngle <= cumulative {
                    // Touching the selected slice again (a new touch, not a drag) clears the selection.
                    selectedSliceID = (oldAngle == nil && slice.id == selectedSliceID) ? nil : slice.id
                    break
                }
            }
        }
    }
    
    private func breakdownLegendRow(_ slice: BreakdownSlice, total: Double) -> some View {
        let color = Color(hex: slice.colorHex)
        let isSelected = slice.id == selectedSliceID
        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(slice.name)
                .font(.footnote)
                .themedPrimaryText()
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(financeManager.formatPercent(total > 0 ? slice.value / total : 0, maxFractionDigits: 1))
                .font(.caption.monospacedDigit())
                .foregroundColor(theme.secondaryTextColor)
            Text(formatCurrency(slice.value))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .themedPrimaryText()
                .frame(minWidth: 78, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? color.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, -8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedSliceID = isSelected ? nil : slice.id
            }
        }
    }
    
    private func breakdownBarRow(_ slice: BreakdownSlice, total: Double, maxValue: Double) -> some View {
        let color = Color(hex: slice.colorHex)
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: slice.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 26, height: 26)
                    .background(color.opacity(0.14))
                    .clipShape(Circle())
                Text(slice.name)
                    .font(.footnote.weight(.medium))
                    .themedPrimaryText()
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(formatCurrency(slice.value))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .themedPrimaryText()
            }
            HStack(spacing: 10) {
                thinBar(fraction: maxValue > 0 ? slice.value / maxValue : 0, color: color)
                Text(financeManager.formatPercent(total > 0 ? slice.value / total : 0, maxFractionDigits: 1))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            .padding(.leading, 36)
        }
    }
    
    /// Top categories of the period; everything past the fifth is folded into a single "Other" slice
    /// so the chart and the legend always add up to the real total.
    private func breakdownSlices(in interval: DateInterval) -> [BreakdownSlice] {
        let all = financeManager.expenseBreakdownDetailed(for: interval)
        let maxSlices = 6
        let keep = all.count > maxSlices ? maxSlices - 1 : all.count
        var slices = all.prefix(keep).map { item in
            BreakdownSlice(
                id: item.0.id,
                name: financeManager.expenseBreakdownDisplayName(for: item.0),
                icon: financeManager.expenseBreakdownIcon(for: item.0),
                colorHex: financeManager.expenseBreakdownColorHex(for: item.0),
                value: item.1
            )
        }
        let rest = all.dropFirst(keep).reduce(0) { $0 + $1.1 }
        if rest > 0 {
            if let index = slices.firstIndex(where: { $0.id == "builtIn:other" }) {
                let existing = slices[index]
                slices[index] = BreakdownSlice(id: existing.id, name: existing.name, icon: existing.icon,
                                               colorHex: existing.colorHex, value: existing.value + rest)
            } else {
                slices.append(BreakdownSlice(
                    id: "others",
                    name: financeManager.displayName(for: .other),
                    icon: "ellipsis.circle.fill",
                    colorHex: financeManager.colorHex(for: .other),
                    value: rest
                ))
            }
        }
        return slices
    }
    
    // MARK: - Trend
    
    private var trendCard: some View {
        let data = trendBuckets(for: trendPeriod)
        let hasValues = data.contains { $0.income > 0 || $0.expenses > 0 }
        
        return VStack(alignment: .leading, spacing: 14) {
            cardHeader("finance_trend".localized, icon: FinanceDashboardCard.trend.icon)
            
            FinancePillPicker(selection: $trendPeriod, options: ChartPeriod.allCases, fillsWidth: true) { period in
                Text(period.displayName)
            }
            
            if hasValues {
                trendChart(data)
                trendSummary(data)
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(theme.secondaryTextColor.opacity(0.12))
                            .frame(height: 1)
                    }
            } else {
                emptyChartPlaceholder
            }
        }
        .padding(16)
        .themedCard()
        .onChange(of: trendPeriod) { _, _ in trendSelection = nil }
    }
    
    /// Income above the line, expenses below it: one bar per day / week / month / year.
    private func trendChart(_ data: [TrendItem]) -> some View {
        let unit = trendPeriod.calendarComponent
        return Chart {
            ForEach(data) { item in
                let isDimmed = trendSelection != nil && trendSelection != item.start
                BarMark(
                    x: .value("period".localized, item.start, unit: unit),
                    y: .value("income".localized, item.income)
                )
                .foregroundStyle(Color.green.opacity(isDimmed ? 0.25 : 0.8))
                .cornerRadius(3)
                
                BarMark(
                    x: .value("period".localized, item.start, unit: unit),
                    y: .value("expenses".localized, -item.expenses)
                )
                .foregroundStyle(Color.red.opacity(isDimmed ? 0.25 : 0.8))
                .cornerRadius(3)
            }
            
            RuleMark(y: .value("zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(theme.secondaryTextColor.opacity(0.3))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: unit, count: trendPeriod.axisStride)) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(trendAxisLabel(date))
                            .font(.caption2)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(formatCompact(amount))
                            .font(.caption2)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                // Tap a bar to see that period, tap it again (or an empty spot) to go back to the total.
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        var tapped: Date?
                        if let plotFrame = proxy.plotFrame,
                           let date: Date = proxy.value(atX: location.x - geo[plotFrame].origin.x),
                           let item = data.first(where: { $0.interval.contains(date) }) {
                            tapped = item.start
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            trendSelection = (tapped == trendSelection) ? nil : tapped
                        }
                    }
            }
        }
        .frame(height: 190)
    }
    
    private func trendSummary(_ data: [TrendItem]) -> some View {
        let selected = data.first { $0.start == trendSelection }
        return VStack(alignment: .leading, spacing: 10) {
            Text(selected.map { periodLabel(trendPeriod, $0.interval) } ?? trendRangeLabel)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.secondaryTextColor)
                .id(trendSelection)
                .transition(.opacity)
            flowColumns(
                income: selected?.income ?? data.reduce(0) { $0 + $1.income },
                expenses: selected?.expenses ?? data.reduce(0) { $0 + $1.expenses }
            )
        }
    }
    
    /// "Ultimi 6 mesi"
    private var trendRangeLabel: String {
        let key: String
        switch trendPeriod {
        case .day: key = "last_n_days"
        case .week: key = "last_n_weeks"
        case .month: key = "last_n_months"
        case .year: key = "last_n_years"
        }
        return String(format: key.localized, trendPeriod.trendBucketCount)
    }
    
    private func trendAxisLabel(_ date: Date) -> String {
        let style = Date.FormatStyle().locale(appLocale)
        switch trendPeriod {
        case .day, .week: return date.formatted(style.day().month(.abbreviated))
        case .month: return date.formatted(style.month(.abbreviated))
        case .year: return date.formatted(style.year())
        }
    }
    
    // MARK: - Recent Entries
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("recent_entries".localized, icon: FinanceDashboardCard.recentEntries.icon) {
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
                    FinanceEntryRow(entry: entry)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingEntry = entry
                        }
                        // Swipe actions only work inside a List, so the shortcuts live in the long-press menu here.
                        .contextMenu {
                            Button {
                                editingEntry = entry
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            Button {
                                financeManager.duplicateEntry(entry)
                            } label: {
                                Label("duplicate".localized, systemImage: "plus.square.on.square")
                            }
                            Button(role: .destructive) {
                                financeManager.removeEntry(entry)
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                        }
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
                Text(formatCurrency(financeManager.monthlySubscriptionCost) + "per_month".localized)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundColor(.orange)
            }
            
            ForEach(financeManager.activeSubscriptions) { sub in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.name)
                            .font(.subheadline)
                            .themedPrimaryText()
                        if let caption = subscriptionCaption(sub) {
                            Text(caption)
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                    Spacer()
                    Text(formatCurrency(sub.amount))
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundColor(theme.secondaryTextColor)
                    if let freq = sub.recurringFrequency {
                        Text("/ " + freq.displayName)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .onTapGesture { editingEntry = sub }
            }
        }
        .padding(16)
        .themedCard()
    }
    
    /// "Next: 28 Oct" (and when the subscription stops, if it has an end date).
    private func subscriptionCaption(_ sub: FinanceEntry) -> String? {
        var parts: [String] = []
        if let next = financeManager.nextOccurrence(of: sub) {
            parts.append(String(format: "next_charge".localized, financeManager.formatShortDate(next)))
        }
        if let end = sub.recurringEndDate {
            parts.append(String(format: "recurring_ends_on".localized, financeManager.formatShortDate(end)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    
    private struct TrendItem: Identifiable {
        let interval: DateInterval
        let income: Double
        let expenses: Double
        
        var id: Date { interval.start }
        var start: Date { interval.start }
    }
    
    /// One bucket per day (last 14), week (last 8), month (last 6) or year (last 4), the current one included.
    private func trendBuckets(for period: ChartPeriod) -> [TrendItem] {
        let calendar = Calendar.current
        let component = period.calendarComponent
        guard let current = calendar.dateInterval(of: component, for: Date()) else { return [] }
        return (0..<period.trendBucketCount).reversed().compactMap { back in
            guard let reference = calendar.date(byAdding: component, value: -back, to: current.start),
                  let interval = calendar.dateInterval(of: component, for: reference) else { return nil }
            return TrendItem(
                interval: interval,
                income: financeManager.totalIncome(for: interval),
                expenses: financeManager.totalExpenses(for: interval)
            )
        }
    }
    
    /// Axis labels: 950, 1.5k, -2k
    private func formatCompact(_ value: Double) -> String {
        let sign = value < 0 ? "−" : ""
        let magnitude = abs(value)
        if magnitude >= 1000 {
            let thousands = magnitude / 1000
            let digits = thousands < 10 && thousands.truncatingRemainder(dividingBy: 1) != 0 ? 1 : 0
            return sign + thousands.formatted(.number.precision(.fractionLength(digits))) + "k"
        }
        return sign + magnitude.formatted(.number.precision(.fractionLength(0)))
    }
    
    // MARK: - Helpers
    
    /// Full amount with cents (balance, movements, subscriptions).
    private func formatCurrency(_ amount: Double) -> String {
        financeManager.formatCurrency(amount)
    }
    
    /// Percentage that never grows absurdly long: anything past 999% reads ">999%".
    private func cappedPercent(_ fraction: Double) -> String {
        fraction > 9.99 ? ">" + financeManager.formatPercent(9.99) : financeManager.formatPercent(fraction)
    }
    
    /// Whole amount for compact spots (summaries, goals, gauges).
    private func formatWhole(_ amount: Double) -> String {
        financeManager.formatCurrency(amount, showCents: false)
    }
}

// MARK: - Entry Row

private struct FinanceEntryRow: View {
    let entry: FinanceEntry
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    
    var body: some View {
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
                    .minimumScaleFactor(0.8)
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
                Text((entry.type.isOutflow ? "-" : "+") + financeManager.formatCurrency(entry.amount))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(entry.type.isOutflow ? .red : .green)
                Text(financeManager.formatShortDate(entry.date))
                    .font(.caption2)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
    }
}

// MARK: - All Entries

private struct FinanceAllEntriesView: View {
    @ObservedObject private var financeManager = FinanceManager.shared
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var editingEntry: FinanceEntry?
    
    private struct MonthGroup: Identifiable {
        let id: Date
        let entries: [FinanceEntry]
    }
    
    private var filteredEntries: [FinanceEntry] {
        let sorted = financeManager.entries.sorted { $0.date > $1.date }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { entry in
            [entry.name, financeManager.categoryDisplayName(for: entry), entry.notes ?? ""]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
    
    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        }
        return grouped
            .map { MonthGroup(id: $0.key, entries: $0.value) }
            .sorted { $0.id > $1.id }
    }
    
    private func monthTitle(_ date: Date) -> String {
        let locale = Locale(identifier: LanguageManager.shared.actualLanguageCode)
        return date.formatted(Date.FormatStyle().locale(locale).month(.wide).year()).capitalized(with: locale)
    }
    
    var body: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        FinanceEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { editingEntry = entry }
                            .listRowBackground(theme.surfaceColor)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    financeManager.removeEntry(entry)
                                } label: {
                                    Label("delete".localized, systemImage: "trash")
                                }
                                Button {
                                    editingEntry = entry
                                } label: {
                                    Label("edit".localized, systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    financeManager.duplicateEntry(entry)
                                } label: {
                                    Label("duplicate".localized, systemImage: "plus.square.on.square")
                                }
                                .tint(theme.primaryColor)
                            }
                    }
                } header: {
                    Text(monthTitle(group.id))
                        .themedSecondaryText()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .overlay {
            if groups.isEmpty {
                Text((searchText.isEmpty ? "no_finance_entries" : "no_results_found").localized)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
        .searchable(text: $searchText, prompt: "search_entries".localized)
        .financeNavigationTitle("all_entries".localized)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("done".localized) { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                FinanceEntryFormView(editingEntry: entry)
            }
        }
    }
}

// MARK: - Budget Overall Gauge (large speedometer-style semicircle)

private struct BudgetOverallGauge: View {
    let progress: Double  // 0...1.5 (spent / limit)
    let spentPercent: Int
    let remaining: Double
    let overAmount: Double
    let totalLimit: Double
    let formatCurrency: (Double) -> String
    @Environment(\.theme) private var theme
    @State private var shownProgress: Double = 0
    
    /// Arc area height / width. The stroke is a fixed share of the width, so the ratio is constant.
    private static let lineShare: CGFloat = 0.06
    private static let aspect: CGFloat = (1 - lineShare) / 2 + lineShare
    
    private var isOver: Bool { overAmount > 0 }
    
    private var gaugeColor: Color {
        if progress > 1.0 { return .red }
        if progress > 0.8 { return .orange }
        return theme.primaryColor
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Color.clear
                .aspectRatio(1 / Self.aspect, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        let lineWidth = geo.size.width * Self.lineShare
                        let drawn = min(shownProgress, 1)
                        
                        ZStack(alignment: .bottom) {
                            // Track
                            GaugeArc(progress: 1, lineWidth: lineWidth)
                                .stroke(theme.secondaryTextColor.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            
                            // Filled part
                            if drawn > 0.004 {
                                GaugeArc(progress: drawn, lineWidth: lineWidth)
                                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            }
                            
                            GaugeDot(progress: drawn, lineWidth: lineWidth)
                            
                            // Center: share spent, then what is left (or how much it went over)
                            VStack(spacing: 2) {
                                Text("\(spentPercent)% \("budget_spent".localized)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(gaugeColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                
                                Text(formatCurrency(isOver ? overAmount : remaining))
                                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(isOver ? .red : theme.textColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                
                                Text((isOver ? "over_budget" : "left_this_month").localized)
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .padding(.horizontal, lineWidth * 1.6)
                            .padding(.bottom, lineWidth * 0.4)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            
            // Min & max sit below the feet of the arc, never on top of it
            HStack {
                Text(formatCurrency(0))
                Spacer()
                Text(formatCurrency(totalLimit))
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(theme.secondaryTextColor)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9)) { shownProgress = progress }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) { shownProgress = newValue }
        }
    }
}

// MARK: - Budget Category Row

private struct BudgetCategoryRow: View {
    let label: String
    let icon: String
    let limit: Double
    let spent: Double
    let categoryColor: Color
    let formatCurrency: (Double) -> String
    @Environment(\.theme) private var theme
    
    private var ratio: Double { limit > 0 ? spent / limit : 0 }
    private var isOver: Bool { spent > limit }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(categoryColor)
                    .frame(width: 30, height: 30)
                    .background(categoryColor.opacity(0.14))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                    Text(isOver
                         ? String(format: "amount_over".localized, formatCurrency(spent - limit))
                         : String(format: "amount_left".localized, formatCurrency(max(limit - spent, 0))))
                        .font(.caption)
                        .foregroundColor(isOver ? .red : theme.secondaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text("\(formatCurrency(spent)) / \(formatCurrency(limit))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.secondaryTextColor.opacity(0.12))
                    Capsule()
                        .fill(isOver ? Color.red : (ratio > 0.8 ? Color.orange : categoryColor))
                        .frame(width: spent > 0 ? max(geo.size.width * min(ratio, 1), 6) : 0)
                }
            }
            .frame(height: 6)
            .padding(.leading, 40)
        }
    }
}

// MARK: - Arc Shape for gauge

/// Upper semicircle whose outer edge touches the left, right and top of its rect and whose round
/// caps end exactly on the bottom edge.
private struct GaugeArc: Shape {
    var progress: Double  // 0...1
    var lineWidth: CGFloat
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let radius = (rect.width - lineWidth) / 2
        let center = CGPoint(x: rect.midX, y: rect.maxY - lineWidth / 2)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * progress),
            clockwise: false
        )
        return path
    }
}

// MARK: - Gauge Dot

/// Marker riding on the arc; animatable so it follows the curve instead of cutting across it.
private struct GaugeDot: View, Animatable {
    var progress: Double  // 0...1
    var lineWidth: CGFloat
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        GeometryReader { geo in
            let radius = (geo.size.width - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - lineWidth / 2)
            let angle = Angle.degrees(180 + progress * 180)
            
            Circle()
                .fill(Color.white)
                .frame(width: lineWidth * 0.5, height: lineWidth * 0.5)
                .shadow(color: .black.opacity(0.3), radius: 3)
                .position(
                    x: center.x + radius * CGFloat(cos(angle.radians)),
                    y: center.y + radius * CGFloat(sin(angle.radians))
                )
        }
    }
}

// MARK: - Pill Picker

/// Compact capsule picker shared by the Finance cards (same look as the original Month / YTD toggle).
private struct FinancePillPicker<Value: Hashable, Label: View>: View {
    @Binding var selection: Value
    let options: [Value]
    var fillsWidth: Bool = false
    @ViewBuilder let label: (Value) -> Label
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    label(option)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(isSelected ? theme.buttonTextColor : theme.secondaryTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                        .background(Capsule().fill(isSelected ? theme.primaryColor : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(theme.secondaryTextColor.opacity(0.1)))
    }
}
