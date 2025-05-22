import SwiftUI

struct RewardsView: View {
    @StateObject private var viewModel = RewardViewModel()
    @State private var showingAddReward = false
    @State private var selectedReward: Reward?
    @State private var showingEditReward = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Points Summary
                HStack(spacing: 20) {
                    PointsCard(title: "Daily", points: viewModel.dailyPoints, systemImage: "sun.max")
                    PointsCard(title: "Weekly", points: viewModel.weeklyPoints, systemImage: "calendar.badge.clock")
                    PointsCard(title: "Monthly", points: viewModel.monthlyPoints, systemImage: "calendar")
                }
                .padding()
                
                // Tab Selector
                Picker("Frequency", selection: $selectedTab) {
                    Text("Daily").tag(0)
                    Text("Weekly").tag(1)
                    Text("Monthly").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Rewards List
                TabView(selection: $selectedTab) {
                    rewardsList(for: .daily)
                        .tag(0)
                    
                    rewardsList(for: .weekly)
                        .tag(1)
                    
                    rewardsList(for: .monthly)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddReward = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReward) {
                RewardFormView()
            }
            .sheet(item: $selectedReward) { reward in
                RewardFormView(initialReward: reward)
            }
            .onAppear {
                viewModel.updatePoints()
            }
        }
    }
    
    @ViewBuilder
    private func rewardsList(for frequency: RewardFrequency) -> some View {
        let rewards = getRewards(for: frequency)
        
        if rewards.isEmpty {
            emptyRewardsView(for: frequency)
        } else {
            List {
                ForEach(rewards) { reward in
                    RewardRow(reward: reward, 
                              canRedeem: viewModel.canRedeemReward(reward),
                              onRedeemTapped: {
                                  viewModel.redeemReward(reward)
                              })
                    .swipeActions {
                        Button {
                            selectedReward = reward
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            viewModel.removeReward(reward)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    private func getRewards(for frequency: RewardFrequency) -> [Reward] {
        switch frequency {
        case .daily:
            return viewModel.dailyRewards
        case .weekly:
            return viewModel.weeklyRewards
        case .monthly:
            return viewModel.monthlyRewards
        }
    }
    
    private func emptyRewardsView(for frequency: RewardFrequency) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "gift")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No \(frequency.displayName.lowercased()) rewards yet")
                .font(.headline)
            
            Text("Create rewards to motivate yourself!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showingAddReward = true
            } label: {
                Text("Add a reward")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct PointsCard: View {
    let title: String
    let points: Int
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(points)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("points")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RewardRow: View {
    let reward: Reward
    let canRedeem: Bool
    let onRedeemTapped: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: reward.icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.name)
                    .font(.headline)
                
                if let description = reward.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text("\(reward.pointsCost) points")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button {
                onRedeemTapped()
            } label: {
                Text("Redeem")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canRedeem ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .disabled(!canRedeem)
        }
        .padding(.vertical, 4)
    }
}

struct RewardsView_Previews: PreviewProvider {
    static var previews: some View {
        RewardsView()
    }
}
