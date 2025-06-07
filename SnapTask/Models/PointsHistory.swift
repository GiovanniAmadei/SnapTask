import Foundation

struct PointsHistory: Codable, Identifiable {
    let id: UUID
    let date: Date
    let points: Int
    let frequency: RewardFrequency
    
    let categoryId: UUID?
    let categoryName: String?
    
    var isGeneralPoints: Bool {
        return categoryId == nil
    }
    
    init(id: UUID = UUID(), date: Date, points: Int, frequency: RewardFrequency, categoryId: UUID? = nil, categoryName: String? = nil) {
        self.id = id
        self.date = date
        self.points = points
        self.frequency = frequency
        self.categoryId = categoryId
        self.categoryName = categoryName
    }
}

struct RedeemedReward: Codable, Identifiable {
    let id: UUID
    let rewardId: UUID
    let rewardName: String
    let pointsCost: Int
    let redeemedDate: Date
    
    init(id: UUID = UUID(), rewardId: UUID, rewardName: String, pointsCost: Int, redeemedDate: Date) {
        self.id = id
        self.rewardId = rewardId
        self.rewardName = rewardName
        self.pointsCost = pointsCost
        self.redeemedDate = redeemedDate
    }
}
