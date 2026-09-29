import SwiftUI

struct WatchRewardDetailView: View {
    let reward: Reward
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRedeemConfirmation = false
    
    private var canAfford: Bool {
        syncManager.totalPoints >= reward.pointsCost
    }
    
    private var isRedeemed: Bool {
        reward.hasBeenRedeemed()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                headerCard
                
                if hasDetails {
                    detailsCard
                }
                
                if !reward.redemptions.isEmpty {
                    redemptionHistoryCard
                }
                
                actionsCard
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(reward.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            WatchRewardFormView(mode: .edit(reward))
        }
        .confirmationDialog("Delete Reward?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                syncManager.deleteReward(reward)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Redeem for \(reward.pointsCost) points?", isPresented: $showingRedeemConfirmation) {
            Button("Redeem") {
                redeemReward()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var hasDetails: Bool {
        (reward.description != nil && !reward.description!.isEmpty)
    }
    
    private var headerCard: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: reward.icon)
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
            
            // Cost
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("\(reward.pointsCost)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            
            // Frequency badge
            Text(reward.frequency.displayName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Status
            if isRedeemed {
                Label("Already redeemed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.green)
            } else if !canAfford {
                Label("Need \(reward.pointsCost - syncManager.totalPoints) more", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            // Your points bar
            HStack {
                Text("Your points")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(syncManager.totalPoints)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let description = reward.description, !description.isEmpty {
                Text(description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    private var redemptionHistoryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            
            ForEach(reward.redemptions.suffix(3).reversed(), id: \.self) { date in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(date, style: .date)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    private var actionsCard: some View {
        VStack(spacing: 6) {
            // Redeem button
            if !isRedeemed && canAfford {
                Button {
                    showingRedeemConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 11))
                        Text("Redeem")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            
            // Edit & Delete row
            HStack(spacing: 6) {
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Edit")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Delete")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
    
    private func redeemReward() {
        syncManager.redeemReward(reward)
        HapticService.shared.play(.success)
    }
}

#Preview {
    NavigationStack {
        WatchRewardDetailView(
            reward: Reward(
                name: "Coffee Break",
                description: "Enjoy a nice coffee",
                pointsCost: 50,
                frequency: .daily,
                icon: "cup.and.saucer.fill"
            )
        )
        .environmentObject(WatchSyncManager.shared)
    }
}
