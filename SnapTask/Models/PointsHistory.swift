import Foundation

struct PointsHistory: Codable, Identifiable {
    let id: UUID
    let date: Date
    let points: Int
    let frequency: RewardFrequency
    
    init(id: UUID = UUID(), date: Date, points: Int, frequency: RewardFrequency) {
        self.id = id
        self.date = date
        self.points = points
        self.frequency = frequency
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