import SwiftUI

struct WatchRewardsListView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var showingAddReward = false
    
    private var availableRewards: [Reward] {
        syncManager.rewards.filter { !$0.hasBeenRedeemed() }
    }
    
    private var redeemedRewards: [Reward] {
        syncManager.rewards.filter { $0.hasBeenRedeemed() }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Points header
                pointsHeader
                
                // Available rewards
                if !availableRewards.isEmpty {
                    rewardsSection(title: "Available", rewards: availableRewards, canRedeem: true)
                }
                
                // Redeemed today
                if !redeemedRewards.isEmpty {
                    rewardsSection(title: "Redeemed", rewards: redeemedRewards, canRedeem: false)
                }
                
                if syncManager.rewards.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Rewards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddReward = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddReward) {
            WatchRewardFormView(mode: .create)
        }
    }
    
    private var pointsHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                
                Text("\(syncManager.totalPoints)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            
            Text("Available Points")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(10)
    }
    
    private func rewardsSection(title: String, rewards: [Reward], canRedeem: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(rewards) { reward in
                NavigationLink(destination: WatchRewardDetailView(reward: reward)) {
                    WatchRewardRowView(reward: reward, canRedeem: canRedeem)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gift")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No rewards")
                .font(.headline)
            
            Text("Tap + to add a reward")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}

struct WatchRewardRowView: View {
    let reward: Reward
    let canRedeem: Bool
    @EnvironmentObject var syncManager: WatchSyncManager
    
    private var canAfford: Bool {
        syncManager.totalPoints >= reward.pointsCost
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: reward.icon)
                .font(.title3)
                .foregroundColor(canRedeem && canAfford ? .yellow : .gray)
                .frame(width: 30)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.name)
                    .font(.caption)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text("\(reward.pointsCost)")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
            }
            
            Spacer()
            
            // Frequency badge
            Text(reward.frequency.shortDisplayName)
                .font(.system(size: 9))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
        .opacity(canRedeem ? 1 : 0.6)
    }
}

#Preview {
    WatchRewardsListView()
        .environmentObject(WatchSyncManager.shared)
}
