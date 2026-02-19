import Foundation

// MARK: - Finance Entry Type
enum FinanceEntryType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case subscription
    case saving
    case investment
    case debt
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .income: return "finance_income".localized
        case .expense: return "finance_expense".localized
        case .subscription: return "finance_subscription".localized
        case .saving: return "finance_saving".localized
        case .investment: return "finance_investment".localized
        case .debt: return "finance_debt".localized
        }
    }
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .subscription: return "repeat.circle.fill"
        case .saving: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .debt: return "creditcard.fill"
        }
    }
    
    var color: String {
        switch self {
        case .income: return "#22C55E"
        case .expense: return "#EF4444"
        case .subscription: return "#F97316"
        case .saving: return "#3B82F6"
        case .investment: return "#8B5CF6"
        case .debt: return "#DC2626"
        }
    }
    
    var isOutflow: Bool {
        switch self {
        case .income, .saving, .investment: return false
        case .expense, .subscription, .debt: return true
        }
    }
}

// MARK: - Finance Category
enum FinanceCategory: String, Codable, CaseIterable, Identifiable {
    case housing
    case food
    case transport
    case health
    case entertainment
    case education
    case clothing
    case utilities
    case insurance
    case salary
    case freelance
    case passive
    case gifts
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .housing: return "finance_cat_housing".localized
        case .food: return "finance_cat_food".localized
        case .transport: return "finance_cat_transport".localized
        case .health: return "finance_cat_health".localized
        case .entertainment: return "finance_cat_entertainment".localized
        case .education: return "finance_cat_education".localized
        case .clothing: return "finance_cat_clothing".localized
        case .utilities: return "finance_cat_utilities".localized
        case .insurance: return "finance_cat_insurance".localized
        case .salary: return "finance_cat_salary".localized
        case .freelance: return "finance_cat_freelance".localized
        case .passive: return "finance_cat_passive".localized
        case .gifts: return "finance_cat_gifts".localized
        case .other: return "finance_cat_other".localized
        }
    }
    
    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .health: return "heart.fill"
        case .entertainment: return "gamecontroller.fill"
        case .education: return "book.fill"
        case .clothing: return "tshirt.fill"
        case .utilities: return "bolt.fill"
        case .insurance: return "shield.fill"
        case .salary: return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .passive: return "chart.line.uptrend.xyaxis"
        case .gifts: return "gift.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var isIncomeCategory: Bool {
        switch self {
        case .salary, .freelance, .passive: return true
        default: return false
        }
    }
}

// MARK: - Subscription Frequency
enum SubscriptionFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .weekly: return "sub_weekly".localized
        case .monthly: return "sub_monthly".localized
        case .quarterly: return "sub_quarterly".localized
        case .yearly: return "sub_yearly".localized
        }
    }
    
    var monthlyMultiplier: Double {
        switch self {
        case .weekly: return 4.33
        case .monthly: return 1.0
        case .quarterly: return 1.0 / 3.0
        case .yearly: return 1.0 / 12.0
        }
    }
}

// MARK: - Finance Entry
struct FinanceEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var amount: Double
    var type: FinanceEntryType
    var category: FinanceCategory
    var customCategoryId: UUID?
    var date: Date
    var notes: String?
    var isRecurring: Bool
    var recurringFrequency: SubscriptionFrequency?
    var recurringEndDate: Date?
    var tags: [String]
    var creationDate: Date
    var lastModifiedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        type: FinanceEntryType,
        category: FinanceCategory = .other,
        customCategoryId: UUID? = nil,
        date: Date = Date(),
        notes: String? = nil,
        isRecurring: Bool = false,
        recurringFrequency: SubscriptionFrequency? = nil,
        recurringEndDate: Date? = nil,
        tags: [String] = [],
        creationDate: Date = Date(),
        lastModifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = abs(amount)
        self.type = type
        self.category = category
        self.customCategoryId = customCategoryId
        self.date = date
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurringFrequency = isRecurring ? (recurringFrequency ?? .monthly) : nil
        self.recurringEndDate = recurringEndDate
        self.tags = tags
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
    
    var monthlyEquivalent: Double {
        guard isRecurring, let freq = recurringFrequency else { return amount }
        return amount * freq.monthlyMultiplier
    }
    
    var signedAmount: Double {
        type.isOutflow ? -amount : amount
    }
    
    static func == (lhs: FinanceEntry, rhs: FinanceEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.amount == rhs.amount &&
        lhs.type == rhs.type &&
        lhs.category == rhs.category &&
        lhs.date == rhs.date &&
        lhs.isRecurring == rhs.isRecurring
    }
}

// MARK: - Finance Budget
struct FinanceBudget: Identifiable, Codable, Equatable {
    let id: UUID
    var category: FinanceCategory
    var monthlyLimit: Double
    var isActive: Bool
    var creationDate: Date
    
    init(
        id: UUID = UUID(),
        category: FinanceCategory,
        monthlyLimit: Double,
        isActive: Bool = true,
        creationDate: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.isActive = isActive
        self.creationDate = creationDate
    }
    
    static func == (lhs: FinanceBudget, rhs: FinanceBudget) -> Bool {
        lhs.id == rhs.id &&
        lhs.category == rhs.category &&
        lhs.monthlyLimit == rhs.monthlyLimit &&
        lhs.isActive == rhs.isActive
    }
}

// MARK: - Financial Goal
struct FinancialGoal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date?
    var type: FinancialGoalType
    var isActive: Bool
    var creationDate: Date
    var lastModifiedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        targetDate: Date? = nil,
        type: FinancialGoalType = .savings,
        isActive: Bool = true,
        creationDate: Date = Date(),
        lastModifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.type = type
        self.isActive = isActive
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
    
    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }
    
    var monthlyNeeded: Double? {
        guard let target = targetDate else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: target).month ?? 0
        guard months > 0 else { return remainingAmount }
        return remainingAmount / Double(months)
    }
    
    static func == (lhs: FinancialGoal, rhs: FinancialGoal) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.targetAmount == rhs.targetAmount &&
        lhs.currentAmount == rhs.currentAmount
    }
}

// MARK: - Financial Stress Level
enum FinancialStressLevel: String, Codable {
    case comfortable
    case balanced
    case tight
    case stressed
    case critical
    
    var color: String {
        switch self {
        case .comfortable: return "#22C55E"
        case .balanced: return "#3B82F6"
        case .tight: return "#F59E0B"
        case .stressed: return "#F97316"
        case .critical: return "#EF4444"
        }
    }
}

// MARK: - Finance Snapshot Summary
struct FinanceSnapshotSummary {
    let totalIncome: Double
    let totalExpenses: Double
    let netFlow: Double
    let savingsRate: Double
    let stressLevel: FinancialStressLevel
    let topExpenseCategory: String?
    let monthlyBurnRate: Double
    let runwayMonths: Double?
}

// MARK: - Built-in Category Override (custom name/icon for default categories)
struct FinanceCategoryOverride: Codable, Equatable {
    var categoryRawValue: String
    var customName: String?
    var customIcon: String?
}

// MARK: - Custom Finance Category
struct CustomFinanceCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var isExpenseCategory: Bool
    var creationDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "tag.fill",
        isExpenseCategory: Bool = true,
        creationDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isExpenseCategory = isExpenseCategory
        self.creationDate = creationDate
    }
}

// MARK: - Supported Currencies
enum SupportedCurrency: String, Codable, CaseIterable, Identifiable {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case chf = "CHF"
    case jpy = "JPY"
    case cny = "CNY"
    case cad = "CAD"
    case aud = "AUD"
    case brl = "BRL"
    case inr = "INR"
    case krw = "KRW"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case pln = "PLN"
    case czk = "CZK"
    case mxn = "MXN"
    case try_ = "TRY"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .eur: return "€"
        case .usd: return "$"
        case .gbp: return "£"
        case .chf: return "CHF"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .cad: return "CA$"
        case .aud: return "A$"
        case .brl: return "R$"
        case .inr: return "₹"
        case .krw: return "₩"
        case .sek: return "kr"
        case .nok: return "kr"
        case .dkk: return "kr"
        case .pln: return "zł"
        case .czk: return "Kč"
        case .mxn: return "MX$"
        case .try_: return "₺"
        }
    }
    
    var displayName: String {
        "\(symbol) - \(rawValue)"
    }
}

enum FinancialGoalType: String, Codable, CaseIterable, Identifiable {
    case savings
    case debtPayoff
    case investment
    case emergency
    case purchase
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .savings: return "fin_goal_savings".localized
        case .debtPayoff: return "fin_goal_debt_payoff".localized
        case .investment: return "fin_goal_investment".localized
        case .emergency: return "fin_goal_emergency".localized
        case .purchase: return "fin_goal_purchase".localized
        }
    }
    
    var icon: String {
        switch self {
        case .savings: return "banknote.fill"
        case .debtPayoff: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .emergency: return "shield.fill"
        case .purchase: return "cart.fill"
        }
    }
}
