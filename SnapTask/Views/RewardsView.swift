import SwiftUI
import Combine

struct RewardsView: View {
    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingAddReward = false
    @State private var selectedReward: Reward?
    @State private var showingPointsHistory = false
    @State private var showingRedeemedRewards = false
    @State private var showingCategoryPointsBreakdown = false
    @State private var selectedFilter: RewardFrequency = .daily
    @Environment(\.colorScheme) private var colorScheme
    
    private var filteredRewards: [Reward] {
        let allRewards = (viewModel.dailyRewards + viewModel.weeklyRewards + viewModel.monthlyRewards)
        return allRewards.filter { $0.frequency == selectedFilter }
            .sorted { $0.pointsCost < $1.pointsCost }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header con titolo manuale come in StatisticsView
                    VStack(spacing: 16) {
                        HStack {
                            Text("rewards".localized)
                                .font(.largeTitle.bold())
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Unified Points & Filter View
                            unifiedPointsFilterView
                            
                            // Quick Actions
                            quickActionsView
                            
                            // Rewards List
                            rewardsListView
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
                
                // Centered Add Button
                VStack {
                    Spacer()
                    
                    AddRewardButton(isShowingRewardForm: $showingAddReward)
                        .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddReward) {
                RewardFormView()
            }
            .sheet(item: $selectedReward) { reward in
                RewardFormView(initialReward: reward)
            }
            .sheet(isPresented: $showingPointsHistory) {
                PointsHistoryView()
            }
            .sheet(isPresented: $showingRedeemedRewards) {
                RedeemedRewardsView()
            }
            .sheet(isPresented: $showingCategoryPointsBreakdown) {
                CategoryPointsBreakdownView()
            }
            .onAppear {
                viewModel.updatePoints()
            }
        }
    }
    
    private var unifiedPointsFilterView: some View {
        VStack(spacing: 16) {
            // Header with total points and detail button
            Button(action: {
                showingCategoryPointsBreakdown = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("available_points".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        let totalPoints = viewModel.dailyPoints + viewModel.weeklyPoints + viewModel.monthlyPoints + RewardManager.shared.availablePoints(for: .yearly)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(totalPoints)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("pts")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "5E5CE6").opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "5E5CE6"))
                        }
                        
                        Text("tap_for_details".localized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Period breakdown chips
            HStack(spacing: 6) {
                CompactPointsChip(title: "today".localized, points: viewModel.dailyPoints, color: Color(hex: "FF6B6B"))
                CompactPointsChip(title: "settimana".localized, points: viewModel.weeklyPoints, color: Color(hex: "4ECDC4"))
                CompactPointsChip(title: "mese".localized, points: viewModel.monthlyPoints, color: Color(hex: "45B7D1"))
                CompactPointsChip(title: "anno".localized, points: RewardManager.shared.availablePoints(for: .yearly), color: Color(hex: "FFD700"))
            }
            
            // Filter Section
            VStack(spacing: 10) {
                HStack {
                    Text("filter_by_frequency".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    let currentPoints = viewModel.currentPoints(for: selectedFilter)
                    Text("\(currentPoints) " + "pts_available".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selectedFilter == .daily ? Color(hex: "FF6B6B") : 
                                       selectedFilter == .weekly ? Color(hex: "4ECDC4") :
                                       selectedFilter == .monthly ? Color(hex: "45B7D1") : 
                                       Color(hex: "FFD700"))
                }
                
                HStack(spacing: 6) {
                    ForEach([RewardFrequency.daily, .weekly, .monthly, .yearly], id: \.self) { frequency in
                        Button(action: {
                            selectedFilter = frequency
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: frequency.iconName)
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text(frequency.displayName)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedFilter == frequency ? 
                                          (frequency == .daily ? Color(hex: "FF6B6B") :
                                           frequency == .weekly ? Color(hex: "4ECDC4") :
                                           frequency == .monthly ? Color(hex: "45B7D1") : 
                                           Color(hex: "FFD700")) : 
                                          Color(UIColor.secondarySystemGroupedBackground))
                            )
                            .foregroundColor(selectedFilter == frequency ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selectedFilter == frequency ? 
                                        Color.clear : 
                                        Color.primary.opacity(0.2), 
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            ZStack {
                // Base background
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                
                // Gradient overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "5E5CE6").opacity(0.06),
                                Color(hex: "9747FF").opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "5E5CE6").opacity(0.2),
                                Color(hex: "9747FF").opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color(hex: "5E5CE6").opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.top, 4)
    }
    
    private var quickActionsView: some View {
        HStack(spacing: 8) {
            CompactActionCard(
                title: "points_history".localized,
                icon: "chart.line.uptrend.xyaxis",
                color: Color(hex: "00C853")
            ) {
                showingPointsHistory = true
            }
            
            CompactActionCard(
                title: "redeemed_rewards".localized,
                icon: "gift.circle",
                color: Color(hex: "FF6B6B")
            ) {
                showingRedeemedRewards = true
            }
        }
    }
    
    private var rewardsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("available_rewards".localized)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Text("\(filteredRewards.count) " + "rewards_count".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if filteredRewards.isEmpty {
                emptyRewardsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRewards) { reward in
                        RewardCard(
                            reward: reward,
                            canRedeem: viewModel.canRedeemReward(reward),
                            currentPoints: viewModel.currentPoints(for: reward.frequency),
                            onRedeemTapped: {
                                viewModel.redeemReward(reward)
                            },
                            onEditTapped: {
                                selectedReward = reward
                            },
                            onDeleteTapped: {
                                viewModel.removeReward(reward)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var emptyRewardsView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(hex: "5E5CE6").opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "gift")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "5E5CE6"))
            }
            
            VStack(spacing: 8) {
                Text("no_rewards_yet".localized)
                    .font(.system(size: 18, weight: .semibold))
                
                Text("create_first_reward_motivation".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// Add Reward Button with centered position and purple gradient
private struct AddRewardButton: View {
    @Binding var isShowingRewardForm: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { isShowingRewardForm = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Circle()
                            .fill(Color(hex: "5E5CE6").opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: Color(hex: "5E5CE6").opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                )
        }
        .padding(.horizontal, 20)
    }
}

struct CompactPointsChip: View {
    let title: String
    let points: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text("\(points)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

struct PointsMiniCard: View {
    let title: String
    let points: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(points)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CompactActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RewardCard: View {
    let reward: Reward
    let canRedeem: Bool
    let currentPoints: Int
    let onRedeemTapped: () -> Void
    let onEditTapped: () -> Void
    let onDeleteTapped: () -> Void
    
    @StateObject private var categoryManager = CategoryManager.shared
    
    private var progress: Double {
        let safeCurrentPoints = max(currentPoints, 0)
        let actualAvailablePoints = reward.isGeneralReward ? 
            RewardManager.shared.availablePoints(for: reward.frequency) :
            RewardManager.shared.availablePointsForCategory(reward.categoryId!, frequency: reward.frequency)
        return min(Double(actualAvailablePoints) / Double(reward.pointsCost), 1.0)
    }
    
    private var categoryColor: Color {
        if let categoryId = reward.categoryId,
           let category = categoryManager.categories.first(where: { $0.id == categoryId }) {
            return Color(hex: category.color)
        }
        return Color(hex: "5E5CE6")
    }
    
    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
            
            ZStack {
                // Base progress layer
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: reward.isGeneralReward ? 
                            [Color(hex: "5E5CE6").opacity(0.15), Color(hex: "9747FF").opacity(0.20)] :
                            [categoryColor.opacity(0.15), categoryColor.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        GeometryReader { geometry in
                            HStack {
                                Rectangle()
                                    .frame(width: geometry.size.width * progress)
                                Spacer(minLength: 0)
                            }
                        }
                    )
            }
            
            // Card content with improved layout
            VStack(spacing: 12) {
                // Header row with icon and title
                HStack(spacing: 14) {
                    // Enhanced icon with category color
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: canRedeem ? 
                                (reward.isGeneralReward ? 
                                 [Color(hex: "5E5CE6"), Color(hex: "9747FF")] :
                                 [categoryColor, categoryColor.opacity(0.8)]) :
                                [Color.gray.opacity(0.4), Color.gray.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: reward.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Title and tag
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(reward.name)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            rewardTypeTag
                        }
                        
                        if let description = reward.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                // Category tag (if category-specific)
                if !reward.isGeneralReward, let categoryName = reward.categoryName {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 8, height: 8)
                            
                            Text(categoryName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(categoryColor)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(categoryColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(categoryColor.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        
                        Spacer()
                    }
                }
                
                // Bottom row with points and redeem button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if reward.isGeneralReward {
                            let actualPoints = RewardManager.shared.availablePoints(for: reward.frequency)
                            let safePoints = max(actualPoints, 0)
                            Text("\(safePoints)/\(reward.pointsCost) points")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(canRedeem ? Color(hex: "00C853") : Color(hex: "5E5CE6"))
                        } else if let categoryId = reward.categoryId {
                            let categoryPoints = RewardManager.shared.availablePointsForCategory(categoryId, frequency: reward.frequency)
                            let safeCategoryPoints = max(categoryPoints, 0)
                            Text("\(safeCategoryPoints)/\(reward.pointsCost) points")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(canRedeem ? Color(hex: "00C853") : categoryColor)
                        }
                        
                        if !canRedeem {
                            let actualAvailablePoints = reward.isGeneralReward ? 
                                RewardManager.shared.availablePoints(for: reward.frequency) :
                                RewardManager.shared.availablePointsForCategory(reward.categoryId!, frequency: reward.frequency)
                            let missingPoints = reward.pointsCost - max(actualAvailablePoints, 0)
                            Text("Need \(missingPoints) more")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onRedeemTapped) {
                        Text("redeem".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        canRedeem ?
                                        (reward.isGeneralReward ?
                                         LinearGradient(
                                            colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                         ) :
                                         LinearGradient(
                                            colors: [categoryColor, categoryColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                         )) :
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .foregroundColor(.white)
                            .shadow(color: canRedeem ? (reward.isGeneralReward ? Color(hex: "5E5CE6").opacity(0.3) : categoryColor.opacity(0.3)) : Color.clear, radius: 2, x: 0, y: 1)
                    }
                    .disabled(!canRedeem)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button {
                onEditTapped()
            } label: {
                Label("edit".localized, systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDeleteTapped()
            } label: {
                Label("delete".localized, systemImage: "trash")
            }
        }
    }
    
    private var rewardTypeTag: some View {
        HStack(spacing: 3) {
            Image(systemName: reward.isGeneralReward ? "star.fill" : "folder.fill")
                .font(.system(size: 8))
                .foregroundColor(reward.isGeneralReward ? Color(hex: "5E5CE6") : categoryColor)
            Text(reward.isGeneralReward ? "general".localized : reward.frequency.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(reward.isGeneralReward ? Color(hex: "5E5CE6") : categoryColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((reward.isGeneralReward ? Color(hex: "5E5CE6") : categoryColor).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder((reward.isGeneralReward ? Color(hex: "5E5CE6") : categoryColor).opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct RewardsView_Previews: PreviewProvider {
    static var previews: some View {
        RewardsView()
    }
}