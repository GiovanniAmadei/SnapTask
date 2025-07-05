import Foundation

enum RewardFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly
    case oneTime
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily: return "daily".localized
        case .weekly: return "weekly".localized
        case .monthly: return "monthly".localized
        case .yearly: return "yearly".localized
        case .oneTime: return "onetime_rewards_once".localized
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .daily: return "day".localized
        case .weekly: return "settimana".localized
        case .monthly: return "mese".localized
        case .yearly: return "anno".localized
        case .oneTime: return "1x"
        }
    }
    
    var iconName: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar.circle"
        case .monthly: return "calendar"
        case .yearly: return "star.circle"
        case .oneTime: return "infinity"
        }
    }
}

struct Reward: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var pointsCost: Int
    var frequency: RewardFrequency
    var icon: String
    var redemptions: [Date] = []
    var creationDate: Date = Date()
    var lastModifiedDate: Date = Date()
    
    var categoryId: UUID?
    var categoryName: String?
    
    var isGeneralReward: Bool {
        return categoryId == nil
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        pointsCost: Int,
        frequency: RewardFrequency = .daily,
        icon: String = "gift",
        categoryId: UUID? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.pointsCost = pointsCost
        self.frequency = frequency
        self.icon = icon
        self.categoryId = categoryId
        self.categoryName = categoryName
    }
    
    func canRedeem(availablePoints: Int) -> Bool {
        return availablePoints >= pointsCost
    }
    
    func hasBeenRedeemed(on date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            return redemptions.contains { calendar.isDate($0, inSameDayAs: date) }
        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return redemptions.contains { 
                $0 >= weekStart && $0 < weekEnd
            }
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return redemptions.contains { 
                $0 >= monthStart && $0 < monthEnd
            }
        case .yearly:
            let components = calendar.dateComponents([.year], from: date)
            let yearStart = calendar.date(from: components)!
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            return redemptions.contains { 
                $0 >= yearStart && $0 < yearEnd
            }
        case .oneTime:
            return !redemptions.isEmpty
        }
    }
    
    static func == (lhs: Reward, rhs: Reward) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.pointsCost == rhs.pointsCost &&
        lhs.frequency == rhs.frequency &&
        lhs.icon == rhs.icon &&
        lhs.redemptions == rhs.redemptions &&
        lhs.categoryId == rhs.categoryId &&
        lhs.categoryName == rhs.categoryName
    }
}