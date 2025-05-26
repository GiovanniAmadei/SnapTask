import SwiftUI

struct RedeemedRewardsView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var redeemedRewards: [(Reward, [Date])] {
        rewardManager.rewards.compactMap { reward in
            let redemptions = reward.redemptions
            return redemptions.isEmpty ? nil : (reward, redemptions)
        }
        .sorted { $0.1.max() ?? Date.distantPast > $1.1.max() ?? Date.distantPast }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if redeemedRewards.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(redeemedRewards, id: \.0.id) { reward, dates in
                            RedeemedRewardCard(reward: reward, redemptionDates: dates)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Redeemed Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "5E5CE6").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "gift.circle")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "5E5CE6"))
            }
            
            VStack(spacing: 8) {
                Text("No Rewards Redeemed Yet")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Start earning points and redeem your first reward!")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RedeemedRewardCard: View {
    let reward: Reward
    let redemptionDates: [Date]
    
    private var totalPointsSpent: Int {
        redemptionDates.count * reward.pointsCost
    }
    
    private var lastRedeemed: Date? {
        redemptionDates.max()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: reward.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let description = reward.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(reward.frequency.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("-\(totalPointsSpent)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FF6B6B"))
                    
                    Text("\(redemptionDates.count) times")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastRedeemed = lastRedeemed {
                HStack {
                    Text("Last redeemed:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.fullDate.string(from: lastRedeemed))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "5E5CE6"))
                    
                    Spacer()
                }
            }
            
            if redemptionDates.count > 1 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                    ForEach(redemptionDates.suffix(8).reversed(), id: \.self) { date in
                        Text(DateFormatter.shortDate.string(from: date))
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "FF6B6B").opacity(0.1))
                            .foregroundColor(Color(hex: "FF6B6B"))
                            .cornerRadius(6)
                    }
                    
                    if redemptionDates.count > 8 {
                        Text("+\(redemptionDates.count - 8)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

extension DateFormatter {
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}