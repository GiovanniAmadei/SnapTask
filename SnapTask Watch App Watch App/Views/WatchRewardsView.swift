import SwiftUI

struct WatchRewardsView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @State private var showingRewardForm = false
    @State private var selectedReward: Reward?
    
    var body: some View {
        // COPIO ESATTAMENTE la struttura del WatchMenuView!
        ScrollView {
            VStack(spacing: 6) {
                // Points header come prima riga
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Points")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Today: \(rewardManager.todayPoints) • Total: \(rewardManager.totalPoints)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
                
                // Add reward button se non ci sono rewards
                if rewardManager.rewards.isEmpty {
                    Button(action: { showingRewardForm = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24)
                            
                            Text("Add First Reward")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Empty state info
                    HStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        Text("Add rewards to motivate yourself!")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.05))
                    )
                } else {
                    // Reward rows - IDENTICO al menu
                    ForEach(rewardManager.rewards) { reward in
                        Button(action: { selectedReward = reward }) {
                            HStack(spacing: 12) {
                                Image(systemName: reward.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reward.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text("\(reward.pointsCost) pts")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { rewardManager.redeemReward(reward) }) {
                                    Text("Redeem")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(canRedeem(reward) ? .green : .gray)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!canRedeem(reward))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add more rewards button
                    Button(action: { showingRewardForm = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Add More Rewards")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8) // IDENTICO al menu
            .padding(.vertical, 8)   // IDENTICO al menu
        }
        .sheet(isPresented: $showingRewardForm) { 
            WatchRewardFormView() 
        }
        .sheet(item: $selectedReward) { reward in
            WatchRewardDetailView(reward: reward) 
        }
    }
    
    private func canRedeem(_ reward: Reward) -> Bool {
        rewardManager.canRedeemReward(reward)
    }
}

struct WatchPointsHeader: View {
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            PointsCard(
                title: "Today",
                value: rewardManager.todayPoints,
                color: .blue
            )
            
            PointsCard(
                title: "Week",
                value: rewardManager.weekPoints,
                color: .green
            )
            
            PointsCard(
                title: "Month",
                value: rewardManager.monthPoints,
                color: .orange
            )
            
            PointsCard(
                title: "Total",
                value: rewardManager.totalPoints,
                color: .purple
            )
        }
    }
}

struct PointsCard: View {
    let title: String
    let value: Int
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

struct WatchRewardCard: View {
    let reward: Reward
    let onTap: () -> Void
    let onRedeem: () -> Void
    
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: reward.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(reward.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("\(reward.pointsCost) pts")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: onRedeem) {
                    Text("Redeem")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(canRedeem ? .green : .gray)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canRedeem)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var canRedeem: Bool {
        rewardManager.canRedeemReward(reward)
    }
}

struct WatchRewardsEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            
            Text("No Rewards Yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("Add rewards to motivate yourself!")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
}

struct WatchRewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var description = ""
    @State private var pointsCost = 10
    @State private var selectedIcon = "star.fill"
    @State private var frequency = RewardFrequency.daily
    
    private let icons = ["star.fill", "heart.fill", "trophy.fill", "gift.fill", "crown.fill", "diamond.fill"]
    private let pointsOptions = [5, 10, 15, 20, 25, 30, 50, 75, 100]
    
    var body: some View {
        NavigationStack { 
            ScrollView {
                VStack(spacing: 12) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("Reward name", text: $name)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    // Points Cost
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Points Cost")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Picker("Points", selection: $pointsCost) {
                            ForEach(pointsOptions, id: \.self) { points in
                                Text("\(points) points").tag(points)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 60)
                    }
                    
                    // Icon Selection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Icon")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 12))
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(selectedIcon == icon ? .blue : Color.gray.opacity(0.2))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Frequency
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequency")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Picker("Frequency", selection: $frequency) {
                            ForEach(RewardFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue.capitalized).tag(freq)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 60)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4) 
                .padding(.bottom, 8) 
            }
            .navigationTitle("New Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 12))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let reward = Reward(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            pointsCost: pointsCost,
                            frequency: frequency,
                            icon: selectedIcon
                        )
                        rewardManager.addReward(reward)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .font(.system(size: 12))
                }
            }
        }
    }
}

struct WatchRewardDetailView: View {
    let reward: Reward
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack { 
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: reward.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.purple)
                    
                    Text(reward.name)
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                    
                    if let description = reward.description {
                        Text(description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("\(reward.pointsCost) Points")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                    
                    Text("Frequency: \(reward.frequency.rawValue.capitalized)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    
                    Button(action: {
                        rewardManager.redeemReward(reward)
                        dismiss()
                    }) {
                        Text("Redeem Reward")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(canRedeem ? .green : .gray)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRedeem)
                }
                .padding()
                .padding(.top, 4) 
            }
            .navigationTitle("Reward Details") 
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    private var canRedeem: Bool {
        rewardManager.canRedeemReward(reward)
    }
}
