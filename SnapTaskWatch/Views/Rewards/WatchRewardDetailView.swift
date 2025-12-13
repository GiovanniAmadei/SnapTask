import SwiftUI
import WatchKit

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
            VStack(spacing: 12) {
                // Header
                headerSection
                
                Divider()
                
                // Details
                detailsSection
                
                // Redemption history
                if !reward.redemptions.isEmpty {
                    Divider()
                    redemptionHistorySection
                }
                
                Divider()
                
                // Actions
                actionsSection
            }
            .padding(.horizontal, 8)
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
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: reward.icon)
                .font(.system(size: 36))
                .foregroundColor(.yellow)
            
            // Cost
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(reward.pointsCost)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            
            // Frequency
            Text(reward.frequency.displayName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(6)
            
            // Status
            if isRedeemed {
                Text("Already redeemed")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else if !canAfford {
                Text("Need \(reward.pointsCost - syncManager.totalPoints) more points")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = reward.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Your points
            HStack {
                Text("Your points:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(syncManager.totalPoints)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private var redemptionHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Redemptions")
                .font(.caption)
                .fontWeight(.semibold)
            
            ForEach(reward.redemptions.suffix(3).reversed(), id: \.self) { date in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 8) {
            // Redeem button
            if !isRedeemed && canAfford {
                Button {
                    showingRedeemConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "gift.fill")
                        Text("Redeem")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Edit
            Button {
                showingEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Delete
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func redeemReward() {
        syncManager.redeemReward(reward)
        WKInterfaceDevice.current().play(.success)
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
