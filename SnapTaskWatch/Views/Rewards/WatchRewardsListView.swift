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
        Group {
            if syncManager.rewards.isEmpty {
                emptyState
            } else {
                rewardsList
            }
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
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 8)
                
                Image(systemName: "gift")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No rewards")
                    .font(.system(.headline, design: .rounded))
                
                Text("Tap + to add a reward")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var rewardsList: some View {
        List {
            // Points header
            Section {
                pointsHeader
            }
            
            if !availableRewards.isEmpty {
                Section("Available") {
                    ForEach(availableRewards) { reward in
                        NavigationLink(destination: WatchRewardDetailView(reward: reward)) {
                            WatchRewardRowView(reward: reward, canRedeem: true)
                        }
                    }
                }
            }
            
            if !redeemedRewards.isEmpty {
                Section("Redeemed") {
                    ForEach(redeemedRewards) { reward in
                        NavigationLink(destination: WatchRewardDetailView(reward: reward)) {
                            WatchRewardRowView(reward: reward, canRedeem: false)
                        }
                    }
                }
            }
        }
    }
    
    private var pointsHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            
            Text("\(syncManager.totalPoints)")
                .font(.system(.title3, design: .rounded, weight: .bold))
            
            Spacer()
            
            Text("Points")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
                .foregroundColor(canRedeem && canAfford ? .accentColor : .gray)
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
                .foregroundColor(.accentColor)
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
        .padding(.vertical, 4)
        .opacity(canRedeem ? 1 : 0.6)
    }
}

#Preview {
    WatchRewardsListView()
        .environmentObject(WatchSyncManager.shared)
}
