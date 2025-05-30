import SwiftUI

struct WatchRewardsView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @State private var showingRewardForm = false
    @State private var selectedReward: Reward?
    
    var body: some View {
        ScrollView { 
            VStack(spacing: 6) {
                WatchPointsHeader()
                
                if rewardManager.rewards.isEmpty {
                    VStack(spacing: 12) {
                        WatchRewardsEmptyState()
                        
                        Button(action: { showingRewardForm = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                Text("Add Reward")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 10) 
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(rewardManager.rewards) { reward in
                            WatchRewardCard(
                                reward: reward,
                                onTap: { selectedReward = reward },
                                onRedeem: { rewardManager.redeemReward(reward) }
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            .padding(.top, 8) 
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingRewardForm) { 
            WatchRewardFormView() 
        }
        .sheet(item: $selectedReward) { reward in
            WatchRewardDetailView(reward: reward) 
        }
    }
}

struct WatchPointsHeader: View {
    @StateObject private var rewardManager = RewardManager.shared
    
    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 1) {
                Text("\(rewardManager.todayPoints)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("Today")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
            )
            
            VStack(spacing: 1) {
                Text("\(rewardManager.weekPoints)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Week")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.1))
            )
            
            VStack(spacing: 1) {
                Text("\(rewardManager.totalPoints)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.purple)
                
                Text("Total")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.purple.opacity(0.1))
            )
        }
        .padding(.horizontal, 6)
    }
}

struct WatchRewardCard: View {
    let reward: Reward
    let onTap: () -> Void
    let onRedeem: () -> Void
    
    @StateObject private var rewardManager = RewardManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: reward.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(reward.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(reward.pointsCost) pts")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onRedeem) {
                    Text("Redeem")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(canRedeem ? Color.green : Color.gray)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canRedeem)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.08))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var canRedeem: Bool {
        rewardManager.canRedeemReward(reward)
    }
}

struct WatchRewardsEmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "star.circle")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            Text("No Rewards Yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Add rewards to motivate yourself!")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
}

struct WatchRewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rewardManager = RewardManager.shared
    
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
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Name")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Reward name", text: $name)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Description")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Optional description", text: $description)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Points Cost")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Picker("Points", selection: $pointsCost) {
                            ForEach(pointsOptions, id: \.self) { points in
                                Text("\(points) points").tag(points)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 60)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Icon")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frequency")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        
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
                .padding(.vertical, 4) 
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
    
    var body: some View {
        NavigationStack { 
            ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: reward.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                    
                    Text(reward.name)
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                    
                    if let description = reward.description {
                        Text(description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("\(reward.pointsCost) Points")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                    
                    Text("Frequency: \(reward.frequency.rawValue.capitalized)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        rewardManager.redeemReward(reward)
                        dismiss()
                    }) {
                        Text("Redeem Reward")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(canRedeem ? Color.green : Color.gray)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canRedeem)
                }
                .padding()
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
