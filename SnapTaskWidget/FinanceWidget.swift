import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Balance Mode

enum FinanceBalanceMode: String, CaseIterable, AppEnum {
    case total = "total"
    case monthly = "monthly"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Balance"))
    }
    static var caseDisplayRepresentations: [FinanceBalanceMode: DisplayRepresentation] {
        [
            .total: DisplayRepresentation(title: LocalizedStringResource("Total Balance"),
                                          subtitle: LocalizedStringResource("Starting balance + all movements")),
            .monthly: DisplayRepresentation(title: LocalizedStringResource("This Month"),
                                            subtitle: LocalizedStringResource("Income and expenses of the current month"))
        ]
    }
}

// MARK: - Finance Widget Intent

struct FinanceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Finance"
    static var description: IntentDescription = IntentDescription("View your balance, income and expenses.")
    @Parameter(title: LocalizedStringResource("Balance Mode"), default: .total)
    var balanceMode: FinanceBalanceMode
}

// MARK: - Budget Item

struct WidgetBudgetItem: Identifiable {
    let id: String
    let categoryName: String
    let categoryIcon: String
    let monthlyLimit: Double
    let spent: Double
    var progress: Double { monthlyLimit > 0 ? min(spent / monthlyLimit, 1.0) : 0 }
    var progressColor: Color { progress > 1.0 ? .red : progress > 0.8 ? .orange : .green }
}

// MARK: - Entry

struct FinanceEntry: TimelineEntry {
    let date: Date
    let totalBalance: Double
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let monthlyBudgetTarget: Double
    let currencySymbol: String
    let hasData: Bool
    let balanceMode: FinanceBalanceMode
    let budgets: [WidgetBudgetItem]
    var displayBalance: Double { balanceMode == .total ? totalBalance : (monthlyIncome - monthlyExpenses) }
}

// MARK: - Provider

private func loadWidgetBudgets(from shared: UserDefaults?) -> [WidgetBudgetItem] {
    guard let data = shared?.data(forKey: "finance_budgets"),
          let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return raw.compactMap { dict in
        guard let id = dict["categoryRaw"] as? String,
              let name = dict["categoryName"] as? String,
              let icon = dict["categoryIcon"] as? String,
              let limit = dict["monthlyLimit"] as? Double,
              let spent = dict["spent"] as? Double else { return nil }
        return WidgetBudgetItem(id: id, categoryName: name, categoryIcon: icon, monthlyLimit: limit, spent: spent)
    }
}

struct FinanceProvider: AppIntentTimelineProvider {
    typealias Entry = FinanceEntry
    typealias Intent = FinanceWidgetIntent

    func placeholder(in context: Context) -> FinanceEntry {
        FinanceEntry(date: Date(), totalBalance: 3840.50, monthlyIncome: 2800, monthlyExpenses: 1560,
                     monthlyBudgetTarget: 2000, currencySymbol: "€", hasData: true, balanceMode: .total,
                     budgets: [WidgetBudgetItem(id: "food", categoryName: "Food", categoryIcon: "fork.knife", monthlyLimit: 400, spent: 280)])
    }
    func snapshot(for configuration: FinanceWidgetIntent, in context: Context) async -> FinanceEntry {
        loadEntry(mode: configuration.balanceMode)
    }
    func timeline(for configuration: FinanceWidgetIntent, in context: Context) async -> Timeline<FinanceEntry> {
        let entry = loadEntry(mode: configuration.balanceMode)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }
    private func loadEntry(mode: FinanceBalanceMode) -> FinanceEntry {
        let shared = UserDefaults(suiteName: "group.com.snapTask.shared")
        return FinanceEntry(
            date: Date(),
            totalBalance: shared?.double(forKey: "finance_balance") ?? 0,
            monthlyIncome: shared?.double(forKey: "finance_monthlyIncome") ?? 0,
            monthlyExpenses: shared?.double(forKey: "finance_monthlyExpenses") ?? 0,
            monthlyBudgetTarget: shared?.double(forKey: "finance_monthlyBudgetTarget") ?? 0,
            currencySymbol: shared?.string(forKey: "finance_currencySymbol") ?? "€",
            hasData: shared?.object(forKey: "finance_balance") != nil,
            balanceMode: mode,
            budgets: loadWidgetBudgets(from: shared)
        )
    }
}

// MARK: - Helpers

private func formatAmount(_ amount: Double, symbol: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return "\(symbol)\(formatter.string(from: NSNumber(value: abs(amount))) ?? "0")"
}

struct FinanceRowView: View {
    let icon: String; let color: Color; let label: LocalizedStringKey; let value: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundColor(.primary).minimumScaleFactor(0.7).lineLimit(1)
        }
    }
}

struct BudgetBarView: View {
    let budget: WidgetBudgetItem; let symbol: String; var showAmount: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: budget.categoryIcon).font(.system(size: 9)).foregroundColor(budget.progressColor)
                Text(budget.categoryName).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                Spacer()
                if showAmount {
                    Text("\(formatAmount(budget.spent, symbol: symbol)) / \(formatAmount(budget.monthlyLimit, symbol: symbol))")
                        .font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundColor(budget.progressColor)
                } else {
                    Text(String(format: "%.0f%%", budget.progress * 100))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(budget.progressColor)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(budget.progressColor)
                        .frame(width: geo.size.width * budget.progress, height: 4)
                }
            }.frame(height: 4)
        }
    }
}

// MARK: - Small Widget View

struct FinanceWidgetSmallView: View {
    let entry: FinanceEntry
    var body: some View {
        if !entry.hasData {
            VStack(spacing: 6) {
                Image(systemName: "eurosign.circle").font(.title2).foregroundColor(.green.opacity(0.7))
                Text(LocalizedStringKey("No finance data")).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "eurosign.circle.fill").font(.system(size: 10)).foregroundColor(.green)
                    Text(LocalizedStringKey("Finance")).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    Spacer()
                    Text(entry.balanceMode == .total ? LocalizedStringKey("Total") : LocalizedStringKey("Month"))
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .padding(.bottom, 4)

                // Balance — takes most vertical space
                Text(formatAmount(entry.displayBalance, symbol: entry.currencySymbol))
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .foregroundColor(entry.displayBalance >= 0 ? .primary : .red)
                    .minimumScaleFactor(0.4).lineLimit(1)
                    .frame(maxHeight: .infinity)

                // Divider
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1).padding(.bottom, 6)

                // Income / Expenses row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down").font(.system(size: 7)).foregroundColor(.green)
                            Text(LocalizedStringKey("Income")).font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        Text(formatAmount(entry.monthlyIncome, symbol: entry.currencySymbol))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(.green)
                            .minimumScaleFactor(0.6).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 3) {
                            Text(LocalizedStringKey("Expenses")).font(.system(size: 9)).foregroundColor(.secondary)
                            Image(systemName: "arrow.up").font(.system(size: 7)).foregroundColor(.red)
                        }
                        Text(formatAmount(entry.monthlyExpenses, symbol: entry.currencySymbol))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundColor(.red)
                            .minimumScaleFactor(0.6).lineLimit(1)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Medium Widget View

struct FinanceWidgetMediumView: View {
    let entry: FinanceEntry
    private var budgetProgress: Double {
        guard entry.monthlyBudgetTarget > 0 else { return 0 }
        return min(entry.monthlyExpenses / entry.monthlyBudgetTarget, 1.0)
    }
    private var progressColor: Color { budgetProgress > 1.0 ? .red : budgetProgress > 0.8 ? .orange : .green }
    private var monthlyNet: Double { entry.monthlyIncome - entry.monthlyExpenses }

    var body: some View {
        if !entry.hasData {
            VStack(spacing: 8) {
                Image(systemName: "eurosign.circle").font(.title).foregroundColor(.green.opacity(0.7))
                Text(LocalizedStringKey("No finance data")).font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                // Left: label + big balance
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "eurosign.circle.fill").font(.system(size: 10)).foregroundColor(.green)
                        Text(LocalizedStringKey("Finance")).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 6)

                    Text(entry.balanceMode == .total ? LocalizedStringKey("Total Balance") : LocalizedStringKey("This Month"))
                        .font(.system(size: 10)).foregroundColor(.secondary)

                    Text(formatAmount(entry.displayBalance, symbol: entry.currencySymbol))
                        .font(.system(size: 26, weight: .bold).monospacedDigit())
                        .foregroundColor(entry.displayBalance >= 0 ? .primary : .red)
                        .minimumScaleFactor(0.4).lineLimit(1)
                        .frame(maxHeight: .infinity)

                    // Net this month
                    HStack(spacing: 3) {
                        Image(systemName: monthlyNet >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8)).foregroundColor(monthlyNet >= 0 ? .green : .red)
                        Text(formatAmount(monthlyNet, symbol: entry.currencySymbol))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundColor(monthlyNet >= 0 ? .green : .red)
                        Text(LocalizedStringKey("net")).font(.system(size: 9)).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 14).padding(.vertical, 14)

                Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1).padding(.vertical, 12)

                // Right: income, expenses, budget bar
                VStack(alignment: .leading, spacing: 0) {
                    mediumRow(icon: "arrow.down.circle.fill", color: .green, label: "Income",
                              value: formatAmount(entry.monthlyIncome, symbol: entry.currencySymbol))
                    Spacer()
                    mediumRow(icon: "arrow.up.circle.fill", color: .red, label: "Expenses",
                              value: formatAmount(entry.monthlyExpenses, symbol: entry.currencySymbol))

                    if entry.monthlyBudgetTarget > 0 {
                        Spacer()
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(LocalizedStringKey("Budget")).font(.system(size: 10)).foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", budgetProgress * 100))
                                    .font(.system(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(progressColor)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2).fill(progressColor)
                                        .frame(width: geo.size.width * budgetProgress, height: 4)
                                }
                            }.frame(height: 4)
                        }
                    } else if !entry.budgets.isEmpty {
                        Spacer()
                        BudgetBarView(budget: entry.budgets[0], symbol: entry.currencySymbol)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 14)
            }
        }
    }

    private func mediumRow(icon: String, color: Color, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(.primary).minimumScaleFactor(0.7).lineLimit(1)
        }
    }
}

// MARK: - Large Widget View

struct FinanceWidgetLargeView: View {
    let entry: FinanceEntry
    private var monthlyNet: Double { entry.monthlyIncome - entry.monthlyExpenses }
    private var budgetProgress: Double {
        guard entry.monthlyBudgetTarget > 0 else { return 0 }
        return min(entry.monthlyExpenses / entry.monthlyBudgetTarget, 1.0)
    }
    private var budgetColor: Color { budgetProgress > 1.0 ? .red : budgetProgress > 0.8 ? .orange : .green }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eurosign.circle.fill").font(.system(size: 15)).foregroundColor(.green)
                Text(LocalizedStringKey("Finance")).font(.headline.weight(.semibold))
                Spacer()
                Text(entry.balanceMode == .total ? LocalizedStringKey("Total Balance") : LocalizedStringKey("This Month"))
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)

            // Big balance
            Text(formatAmount(entry.displayBalance, symbol: entry.currencySymbol))
                .font(.system(size: 36, weight: .bold).monospacedDigit())
                .foregroundColor(entry.displayBalance >= 0 ? .primary : .red)
                .minimumScaleFactor(0.4).lineLimit(1)
                .padding(.horizontal, 16).padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Income / Expenses / Net row — compact
            HStack(spacing: 0) {
                largeStatCell(icon: "arrow.down", label: "Income",
                              value: formatAmount(entry.monthlyIncome, symbol: entry.currencySymbol), color: .green)
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: 36)
                largeStatCell(icon: "arrow.up", label: "Expenses",
                              value: formatAmount(entry.monthlyExpenses, symbol: entry.currencySymbol), color: .red)
                Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: 36)
                largeStatCell(icon: monthlyNet >= 0 ? "arrow.up.right" : "arrow.down.right",
                              label: "Net", value: formatAmount(monthlyNet, symbol: entry.currencySymbol),
                              color: monthlyNet >= 0 ? .green : .red)
            }
            .padding(.vertical, 6)

            Divider().padding(.horizontal, 16)

            // Budget overall bar
            if entry.monthlyBudgetTarget > 0 {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(LocalizedStringKey("Budget")).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(formatAmount(entry.monthlyExpenses, symbol: entry.currencySymbol)) / \(formatAmount(entry.monthlyBudgetTarget, symbol: entry.currencySymbol))")
                            .font(.caption.monospacedDigit()).foregroundColor(budgetColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 3).fill(budgetColor)
                                .frame(width: geo.size.width * budgetProgress, height: 5)
                        }
                    }.frame(height: 5)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }

            // Category budgets list
            if !entry.budgets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey("Category Budgets"))
                        .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        .padding(.top, 8)
                    ForEach(entry.budgets.prefix(5)) { budget in
                        BudgetBarView(budget: budget, symbol: entry.currencySymbol, showAmount: true)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
    }

    private func largeStatCell(icon: String, label: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 8)).foregroundColor(color)
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
            Text(value).font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(color).minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Finance Widget Entry View

struct FinanceWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FinanceEntry
    var body: some View {
        switch family {
        case .systemSmall:  FinanceWidgetSmallView(entry: entry)
        case .systemLarge:  FinanceWidgetLargeView(entry: entry)
        default:            FinanceWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Finance Widget

struct FinanceWidget: Widget {
    let kind: String = "FinanceWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FinanceWidgetIntent.self, provider: FinanceProvider()) { entry in
            FinanceWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Finance")
        .description("View your balance, income and expenses.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Budget Category Entity

struct BudgetCategoryEntity: AppEntity {
    let id: String
    let displayName: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Category"))
    }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }
    static var defaultQuery = BudgetCategoryEntityQuery()
}

struct BudgetCategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BudgetCategoryEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [BudgetCategoryEntity] {
        allEntities()
    }
    private func allEntities() -> [BudgetCategoryEntity] {
        let shared = UserDefaults(suiteName: "group.com.snapTask.shared")
        let budgets = loadWidgetBudgets(from: shared)
        var result = [BudgetCategoryEntity(id: "all", displayName: "Budget Totale", icon: "chart.bar.fill")]
        result.append(contentsOf: budgets.map {
            BudgetCategoryEntity(id: $0.id, displayName: $0.categoryName, icon: $0.categoryIcon)
        })
        return result
    }
}

// MARK: - Budget Widget Intent

struct FinanceBudgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Category Budgets"
    static var description: IntentDescription = IntentDescription("Track spending against a budget.")
    @Parameter(title: LocalizedStringResource("Category"))
    var category: BudgetCategoryEntity?
}

// MARK: - Budget Widget Entry

struct FinanceBudgetEntry: TimelineEntry {
    let date: Date
    let budgets: [WidgetBudgetItem]
    let selectedBudget: WidgetBudgetItem?
    let totalSpent: Double
    let totalLimit: Double
    let currencySymbol: String
    let hasData: Bool
    var totalProgress: Double { totalLimit > 0 ? min(totalSpent / totalLimit, 1.0) : 0 }
    var totalProgressColor: Color { totalProgress > 1.0 ? .red : totalProgress > 0.8 ? .orange : Color(red: 0.9, green: 0.45, blue: 0.2) }
}

// MARK: - Budget Widget Provider

struct FinanceBudgetProvider: AppIntentTimelineProvider {
    typealias Entry = FinanceBudgetEntry
    typealias Intent = FinanceBudgetIntent
    func placeholder(in context: Context) -> FinanceBudgetEntry {
        let b = WidgetBudgetItem(id: "food", categoryName: "Cibo", categoryIcon: "fork.knife", monthlyLimit: 150, spent: 0)
        return FinanceBudgetEntry(date: Date(), budgets: [b], selectedBudget: b, totalSpent: 0, totalLimit: 150, currencySymbol: "€", hasData: true)
    }
    func snapshot(for configuration: FinanceBudgetIntent, in context: Context) async -> FinanceBudgetEntry {
        loadEntry(categoryId: configuration.category?.id)
    }
    func timeline(for configuration: FinanceBudgetIntent, in context: Context) async -> Timeline<FinanceBudgetEntry> {
        let entry = loadEntry(categoryId: configuration.category?.id)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }
    private func loadEntry(categoryId: String?) -> FinanceBudgetEntry {
        let shared = UserDefaults(suiteName: "group.com.snapTask.shared")
        let budgets = loadWidgetBudgets(from: shared)
        let symbol = shared?.string(forKey: "finance_currencySymbol") ?? "€"
        let totalSpent = budgets.reduce(0) { $0 + $1.spent }
        let totalLimit = budgets.reduce(0) { $0 + $1.monthlyLimit }
        let selected: WidgetBudgetItem?
        if let cid = categoryId, cid != "all" {
            selected = budgets.first { $0.id == cid }
        } else {
            selected = nil
        }
        return FinanceBudgetEntry(date: Date(), budgets: budgets, selectedBudget: selected,
                                  totalSpent: totalSpent, totalLimit: totalLimit, currencySymbol: symbol, hasData: !budgets.isEmpty)
    }
}

// MARK: - Semicircle Gauge

struct SemicircleGaugeView: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height * 2)
            let lw = size * 0.115
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: size, height: size)
                    .position(x: geo.size.width / 2, y: geo.size.height)
                Circle()
                    .trim(from: 0, to: CGFloat(progress) * 0.5)
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: size, height: size)
                    .position(x: geo.size.width / 2, y: geo.size.height)
            }
        }
    }
}

// MARK: - Budget Gauge Cell

struct BudgetGaugeCell: View {
    let name: String; let icon: String
    let spent: Double; let limit: Double
    let progress: Double; let color: Color; let symbol: String
    var amountFontSize: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let gaugeH = h * 0.52
            let gaugeW = min(w - 28, gaugeH * 2)

            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 9)).foregroundColor(color)
                    Text(name.uppercased())
                        .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(size: 9, weight: .bold).monospacedDigit()).foregroundColor(color)
                }
                .padding(.horizontal, 12).padding(.top, 12)

                Spacer(minLength: 4)

                // Gauge + amount overlay
                // The arc center is at y=gaugeH (bottom of the gauge frame).
                // We extend the container by textAreaH below the arc so the text
                // sits visually centered in the open mouth of the semicircle.
                let textAreaH: CGFloat = amountFontSize + 14
                ZStack(alignment: .top) {
                    SemicircleGaugeView(progress: progress, color: color)
                        .frame(width: gaugeW, height: gaugeH)
                    VStack(spacing: 1) {
                        Text(formatAmount(spent, symbol: symbol))
                            .font(.system(size: amountFontSize, weight: .bold).monospacedDigit())
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text(LocalizedStringKey("spent"))
                            .font(.system(size: 8)).foregroundColor(.secondary)
                    }
                    .frame(width: gaugeW, height: textAreaH)
                    .offset(y: gaugeH - textAreaH / 2)
                }
                .frame(width: gaugeW, height: gaugeH + textAreaH / 2)

                Spacer(minLength: 4)

                // Scale labels
                HStack {
                    Text(formatAmount(0, symbol: symbol))
                        .font(.system(size: 8).monospacedDigit()).foregroundColor(.secondary)
                    Spacer()
                    Text(formatAmount(limit, symbol: symbol))
                        .font(.system(size: 8).monospacedDigit()).foregroundColor(.secondary)
                }
                .frame(width: gaugeW)
                .padding(.bottom, 10)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Budget Small View

struct FinanceBudgetSmallView: View {
    let entry: FinanceBudgetEntry
    private var displayItem: (name: String, icon: String, spent: Double, limit: Double, progress: Double, color: Color) {
        if let b = entry.selectedBudget {
            return (b.categoryName, b.categoryIcon, b.spent, b.monthlyLimit, b.progress, b.progressColor)
        }
        return ("Total", "chart.bar.fill", entry.totalSpent, entry.totalLimit, entry.totalProgress, entry.totalProgressColor)
    }
    var body: some View {
        if !entry.hasData {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").font(.title2).foregroundColor(.secondary.opacity(0.4))
                Text(LocalizedStringKey("No budgets")).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let item = displayItem
            BudgetGaugeCell(name: item.name, icon: item.icon, spent: item.spent, limit: item.limit,
                            progress: item.progress, color: item.color, symbol: entry.currencySymbol,
                            amountFontSize: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Budget Medium View

struct FinanceBudgetMediumView: View {
    let entry: FinanceBudgetEntry
    var body: some View {
        if !entry.hasData {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").font(.title).foregroundColor(.secondary.opacity(0.4))
                Text(LocalizedStringKey("No budgets")).font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(mediumItems().enumerated()), id: \.offset) { idx, item in
                    if idx > 0 {
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1).padding(.vertical, 12)
                    }
                    BudgetGaugeCell(name: item.name, icon: item.icon, spent: item.spent, limit: item.limit,
                                    progress: item.progress, color: item.color, symbol: entry.currencySymbol)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private struct CellData { let name: String; let icon: String; let spent: Double; let limit: Double; let progress: Double; let color: Color }

    private func mediumItems() -> [CellData] {
        if let sel = entry.selectedBudget {
            return [
                CellData(name: sel.categoryName, icon: sel.categoryIcon, spent: sel.spent, limit: sel.monthlyLimit, progress: sel.progress, color: sel.progressColor),
                CellData(name: "Total", icon: "chart.bar.fill", spent: entry.totalSpent, limit: entry.totalLimit, progress: entry.totalProgress, color: entry.totalProgressColor)
            ]
        }
        return entry.budgets.prefix(2).map { b in
            CellData(name: b.categoryName, icon: b.categoryIcon, spent: b.spent, limit: b.monthlyLimit, progress: b.progress, color: b.progressColor)
        }
    }
}

// MARK: - Budget Large View

struct FinanceBudgetLargeView: View {
    let entry: FinanceBudgetEntry

    var body: some View {
        if !entry.hasData {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
                Text(LocalizedStringKey("No budgets")).font(.body).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill").foregroundColor(entry.totalProgressColor)
                    Text(LocalizedStringKey("Category Budgets")).font(.headline.weight(.semibold))
                    Spacer()
                    Text(LocalizedStringKey("This Month")).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 2)

                // Top section: gauge left, stats right
                GeometryReader { geo in
                    HStack(alignment: .center, spacing: 12) {
                        // Gauge fills left half
                        BudgetGaugeCell(
                            name: "Total", icon: "chart.bar.fill",
                            spent: entry.totalSpent, limit: entry.totalLimit,
                            progress: entry.totalProgress, color: entry.totalProgressColor,
                            symbol: entry.currencySymbol, amountFontSize: 22
                        )
                        .frame(width: geo.size.width * 0.44)

                        // Stats right
                        VStack(alignment: .leading, spacing: 5) {
                            Text(LocalizedStringKey("Total Budget"))
                                .font(.subheadline.weight(.semibold))
                            statRow(label: "Spent", value: formatAmount(entry.totalSpent, symbol: entry.currencySymbol), color: entry.totalProgressColor)
                            statRow(label: "Limit", value: formatAmount(entry.totalLimit, symbol: entry.currencySymbol), color: .primary)
                            let rem = entry.totalLimit - entry.totalSpent
                            statRow(label: "Remaining", value: formatAmount(max(rem, 0), symbol: entry.currencySymbol), color: rem >= 0 ? .green : .red)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15)).frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3).fill(entry.totalProgressColor)
                                        .frame(width: g.size.width * entry.totalProgress, height: 5)
                                }
                            }.frame(height: 5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 16)
                    }
                }
                .frame(height: 130)

                Divider().padding(.horizontal, 16)

                // Category list
                VStack(spacing: 7) {
                    ForEach(entry.budgets.prefix(6)) { b in
                        VStack(spacing: 3) {
                            HStack(spacing: 8) {
                                Image(systemName: b.categoryIcon).font(.system(size: 11)).foregroundColor(b.progressColor).frame(width: 18)
                                Text(b.categoryName).font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                Text(formatAmount(b.spent, symbol: entry.currencySymbol))
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit()).foregroundColor(b.progressColor)
                                Text("/").font(.system(size: 10)).foregroundColor(.secondary)
                                Text(formatAmount(b.monthlyLimit, symbol: entry.currencySymbol))
                                    .font(.system(size: 11).monospacedDigit()).foregroundColor(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.12)).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2).fill(b.progressColor)
                                        .frame(width: geo.size.width * b.progress, height: 4)
                                }
                            }.frame(height: 4)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)

                Spacer(minLength: 0)
            }
        }
    }

    private func statRow(label: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption2.weight(.semibold).monospacedDigit()).foregroundColor(color)
        }
    }
}

// MARK: - Budget Widget Entry View

struct FinanceBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FinanceBudgetEntry
    var body: some View {
        switch family {
        case .systemSmall:  FinanceBudgetSmallView(entry: entry)
        case .systemLarge:  FinanceBudgetLargeView(entry: entry)
        default:            FinanceBudgetMediumView(entry: entry)
        }
    }
}

struct FinanceBudgetWidget: Widget {
    let kind: String = "FinanceBudgetWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FinanceBudgetIntent.self, provider: FinanceBudgetProvider()) { entry in
            FinanceBudgetWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Category Budgets")
        .description("Track your monthly spending against category budgets.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Array chunked helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

// MARK: - Previews

private let previewBudgets = [
    WidgetBudgetItem(id: "food", categoryName: "Cibo", categoryIcon: "fork.knife", monthlyLimit: 150, spent: 0),
    WidgetBudgetItem(id: "transport", categoryName: "Trasporti", categoryIcon: "car.fill", monthlyLimit: 200, spent: 0)
]

#Preview(as: .systemSmall) {
    FinanceWidget()
} timeline: {
    FinanceEntry(date: .now, totalBalance: 3840.50, monthlyIncome: 2800, monthlyExpenses: 1560,
                 monthlyBudgetTarget: 2000, currencySymbol: "€", hasData: true, balanceMode: .total,
                 budgets: previewBudgets)
}

#Preview(as: .systemMedium) {
    FinanceWidget()
} timeline: {
    FinanceEntry(date: .now, totalBalance: 3840.50, monthlyIncome: 2800, monthlyExpenses: 1560,
                 monthlyBudgetTarget: 2000, currencySymbol: "€", hasData: true, balanceMode: .total,
                 budgets: previewBudgets)
}

#Preview(as: .systemLarge) {
    FinanceWidget()
} timeline: {
    FinanceEntry(date: .now, totalBalance: 3840.50, monthlyIncome: 2800, monthlyExpenses: 1560,
                 monthlyBudgetTarget: 2000, currencySymbol: "€", hasData: true, balanceMode: .total,
                 budgets: previewBudgets)
}

#Preview(as: .systemSmall) {
    FinanceBudgetWidget()
} timeline: {
    FinanceBudgetEntry(date: .now, budgets: previewBudgets, selectedBudget: previewBudgets[0],
                       totalSpent: 0, totalLimit: 350, currencySymbol: "€", hasData: true)
}

#Preview(as: .systemMedium) {
    FinanceBudgetWidget()
} timeline: {
    FinanceBudgetEntry(date: .now, budgets: previewBudgets, selectedBudget: nil,
                       totalSpent: 0, totalLimit: 350, currencySymbol: "€", hasData: true)
}

#Preview(as: .systemLarge) {
    FinanceBudgetWidget()
} timeline: {
    FinanceBudgetEntry(date: .now, budgets: previewBudgets, selectedBudget: nil,
                       totalSpent: 0, totalLimit: 350, currencySymbol: "€", hasData: true)
}
