import SwiftUI
import Combine

struct RewardsView: View {
    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingAddReward = false
    @State private var selectedReward: Reward?
    @State private var showingPointsHistory = false
    @State private var showingRedeemedRewards = false
    @State private var showingCategoryPointsBreakdown = false
    @State private var selectedFilter: RewardFrequency = .daily
    @State private var showingPremiumPaywall = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    private var filteredRewards: [Reward] {
        let allRewards = (viewModel.dailyRewards + viewModel.weeklyRewards + viewModel.monthlyRewards)
        return allRewards.filter { $0.frequency == selectedFilter }
            .sorted { $0.pointsCost < $1.pointsCost }
    }
    
    private var canAddMoreRewards: Bool {
        if subscriptionManager.hasAccess(to: .unlimitedRewards) {
            return true
        }
        let totalRewards = viewModel.dailyRewards.count + viewModel.weeklyRewards.count + viewModel.monthlyRewards.count
        return totalRewards < SubscriptionManager.maxRewardsForFree
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header con titolo manuale come in StatisticsView
                    VStack(spacing: 16) {
                        HStack {
                            Text("rewards".localized)
                                .font(.largeTitle.bold())
                                .themedPrimaryText()
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
                            
                            // Premium limit info
                            if !subscriptionManager.hasAccess(to: .unlimitedRewards) {
                                premiumLimitInfo
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
                
                // Centered Add Button - stesso posizionamento della Timeline
                VStack {
                    Spacer()
                    
                    AddRewardButton(
                        isShowingRewardForm: $showingAddReward,
                        canAdd: canAddMoreRewards,
                        onPremiumTapped: {
                            showingPremiumPaywall = true
                        }
                    )
                    .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddReward) {
                if canAddMoreRewards {
                    RewardFormView()
                }
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
            .sheet(isPresented: $showingPremiumPaywall) {
                PremiumPaywallView()
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
                            .themedSecondaryText()
                        
                        // FIXED: Use total points instead of summing overlapping periods
                        let totalPoints = RewardManager.shared.totalPoints()
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(totalPoints)")
                                .font(.system(size: 32, weight: .bold))
                                .themedPrimaryText()
                            
                            Text("pts")
                                .font(.system(size: 14, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(theme.primaryColor.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .themedPrimary()
                        }
                        
                        Text("tap_for_details".localized)
                            .font(.system(size: 9, weight: .medium))
                            .themedSecondaryText()
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Period breakdown chips - using theme colors
            HStack(spacing: 6) {
                CompactPointsChip(title: "today".localized, points: viewModel.dailyPoints, color: theme.primaryColor)
                CompactPointsChip(title: "week_short".localized, points: viewModel.weeklyPoints, color: theme.secondaryColor)
                CompactPointsChip(title: "month_short".localized, points: viewModel.monthlyPoints, color: theme.accentColor)
                CompactPointsChip(title: "year_short".localized, points: RewardManager.shared.availablePoints(for: .yearly), color: theme.primaryColor.opacity(0.8))
            }
            
            // Filter Section - themed
            VStack(spacing: 10) {
                HStack {
                    Text("filter_by_frequency".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .themedPrimaryText()
                    
                    Spacer()
                    
                    let currentPoints = viewModel.currentPoints(for: selectedFilter)
                    Text("\(currentPoints) " + "pts_available".localized)
                        .font(.system(size: 12, weight: .medium))
                        .themedSecondaryText()
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
                                    .fill(selectedFilter == frequency ? theme.primaryColor : theme.surfaceColor)
                            )
                            .foregroundColor(selectedFilter == frequency ? theme.backgroundColor : theme.textColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        selectedFilter == frequency ? 
                                        Color.clear : 
                                        theme.borderColor, 
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
        .themedCard()
        .padding(.top, 4)
    }
    
    private var quickActionsView: some View {
        HStack(spacing: 8) {
            CompactActionCard(
                title: "points_history".localized,
                icon: "chart.line.uptrend.xyaxis",
                color: theme.primaryColor
            ) {
                showingPointsHistory = true
            }
            
            CompactActionCard(
                title: "redeemed_rewards".localized,
                icon: "gift.circle",
                color: theme.secondaryColor
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
                    .themedPrimaryText()
                
                Spacer()
                
                Text("\(filteredRewards.count) " + "rewards_count".localized)
                    .font(.system(size: 14))
                    .themedSecondaryText()
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
                                // Check if we can actually redeem (fixed logic)
                                if viewModel.canRedeemReward(reward) {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    // Redeem reward
                                    viewModel.redeemReward(reward)
                                }
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
                    .fill(theme.primaryColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "gift")
                    .font(.system(size: 32))
                    .themedPrimary()
            }
            
            VStack(spacing: 8) {
                Text("no_rewards_yet".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .themedPrimaryText()
                
                Text("create_first_reward_motivation".localized)
                    .font(.system(size: 14))
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .themedCard()
    }
    
    private var premiumLimitInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                Text("Limiti Piano Gratuito")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("Il piano gratuito include fino a 3 premi personalizzati")
                .font(.subheadline)
                .themedSecondaryText()
            
            HStack {
                let totalRewards = viewModel.dailyRewards.count + viewModel.weeklyRewards.count + viewModel.monthlyRewards.count
                Text("\(totalRewards)/\(SubscriptionManager.maxRewardsForFree)")
                    .font(.caption)
                    .themedSecondaryText()
                
                Spacer()
                
                Button("Passa a Pro") {
                    showingPremiumPaywall = true
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.gradient)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .themedCard()
    }
}

private struct AddRewardButton: View {
    @Binding var isShowingRewardForm: Bool
    let canAdd: Bool
    let onPremiumTapped: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                    isPressed = false
                }
                
                if canAdd {
                    isShowingRewardForm = true
                } else {
                    onPremiumTapped()
                }
            }
        }) {
            ZStack {
                if canAdd {
                    // Design normale con colori del tema
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(theme.backgroundColor)
                        .frame(width: 56, height: 56)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(theme.gradient)
                                Circle()
                                    .fill(theme.primaryColor.opacity(0.3))
                                    .blur(radius: 8)
                                    .scaleEffect(1.2)
                                
                                Circle()
                                    .fill(theme.gradient)
                            }
                            .shadow(
                                color: theme.primaryColor.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        )
                } else {
                    // Design premium
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("PRO")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.25))
                        )
                    }
                    .frame(width: 56, height: 56)
                    .background(
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color.pink,
                                            Color.purple.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .fill(Color.purple.opacity(0.4))
                                .blur(radius: 12)
                                .scaleEffect(1.3)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color.pink,
                                            Color.purple.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Effetto shimmer per premium
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.0),
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .opacity(0.8)
                        }
                        .shadow(
                            color: Color.purple.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    )
                }
            }
            .scaleEffect(isPressed ? 0.95 : (canAdd ? 1.0 : 1.05))
            .animation(.interpolatingSpring(stiffness: 600, damping: 25), value: isPressed)
        }
        .padding(.horizontal, 20)
    }
}

struct CompactPointsChip: View {
    let title: String
    let points: Int
    let color: Color
    @Environment(\.theme) private var theme
    
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
                .themedSecondaryText()
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
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(points)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .themedCard()
    }
}

struct CompactActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .themedPrimaryText()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: theme.shadowColor, radius: 1, x: 0, y: 0.5)
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
    @Environment(\.theme) private var theme
    @State private var isAnimating = false
    @State private var successAnimation = false
    
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
        return theme.primaryColor
    }
    
    private var redemptionInfo: (hasBeenRedeemed: Bool, redemptionCount: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        let relevantRedemptions = reward.redemptions.filter { redemptionDate in
            switch reward.frequency {
            case .daily:
                return calendar.isDate(redemptionDate, inSameDayAs: now)
            case .weekly:
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
                return redemptionDate >= weekStart && redemptionDate < weekEnd
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: now)
                let monthStart = calendar.date(from: components)!
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                return redemptionDate >= monthStart && redemptionDate < monthEnd
            case .yearly:
                let components = calendar.dateComponents([.year], from: now)
                let yearStart = calendar.date(from: components)!
                let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
                return redemptionDate >= yearStart && redemptionDate < yearEnd
            case .oneTime:
                return true
            }
        }
        
        return (hasBeenRedeemed: !relevantRedemptions.isEmpty, redemptionCount: relevantRedemptions.count)
    }
    
    var body: some View {
        ZStack {
            // Background card
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
            
            ZStack {
                // Base progress layer
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: reward.isGeneralReward ? 
                            [theme.primaryColor.opacity(0.15), theme.secondaryColor.opacity(0.20)] :
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
            
            // Success animation overlay
            if successAnimation {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 40, height: 40)
                                )
                            
                            Text("riscattato!".localized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    )
                    .transition(.opacity)
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
                                 [theme.primaryColor, theme.secondaryColor] :
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
                                .themedPrimaryText()
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                rewardTypeTag
                                
                                // Redemption counter (only if redeemed multiple times)
                                if redemptionInfo.redemptionCount > 1 {
                                    redemptionCounterTag
                                } else if redemptionInfo.hasBeenRedeemed {
                                    redemptionIndicator
                                }
                            }
                        }
                        
                        if let description = reward.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12))
                                .themedSecondaryText()
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
                                .foregroundColor(canRedeem ? Color(hex: "00C853") : theme.primaryColor)
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
                                .themedSecondaryText()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Animation sequence
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isAnimating = true
                        }
                        
                        // Show success animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                successAnimation = true
                            }
                        }
                        
                        // Call redeem action
                        onRedeemTapped()
                        
                        // Hide success animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                successAnimation = false
                                isAnimating = false
                            }
                        }
                    }) {
                        Text("redeem".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        canRedeem ?
                                        (reward.isGeneralReward ?
                                         theme.gradient :
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
                            .shadow(color: canRedeem ? (reward.isGeneralReward ? theme.primaryColor.opacity(0.3) : categoryColor.opacity(0.3)) : Color.clear, radius: 2, x: 0, y: 1)
                    }
                    .disabled(!canRedeem)
                    .scaleEffect(isAnimating ? 0.95 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .opacity(successAnimation ? 0.3 : 1.0)
        }
        .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)

        // Context Menu
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
    
    private var redemptionIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.green)
            
            Text("riscattato".localized)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    private var redemptionCounterTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.green)
            
            Text("\(redemptionInfo.redemptionCount)x")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical,3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    private var rewardTypeTag: some View {
        HStack(spacing: 3) {
            Image(systemName: reward.isGeneralReward ? "star.fill" : "folder.fill")
                .font(.system(size: 8))
                .foregroundColor(reward.isGeneralReward ? theme.primaryColor : categoryColor)
            Text(reward.isGeneralReward ? "general".localized : reward.frequency.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(reward.isGeneralReward ? theme.primaryColor : categoryColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((reward.isGeneralReward ? theme.primaryColor : categoryColor).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder((reward.isGeneralReward ? theme.primaryColor : categoryColor).opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct RedeemAnimationView: View {
    @State private var particles: [ParticleModel] = []
    @State private var showSuccessIcon = false
    @State private var successScale: CGFloat = 0.1
    @State private var successOpacity: Double = 0.0
    @Environment(\.theme) private var theme
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.1)
            
            // Particles
            ForEach(particles) { particle in
                ParticleView(particle: particle)
            }
            
            // Success icon
            if showSuccessIcon {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: theme.primaryColor.opacity(0.4), radius: 20)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(successScale)
                    .opacity(successOpacity)
                    
                    Text("reward_redeemed".localized)
                        .font(.system(size: 18, weight: .semibold))
                        .themedPrimaryText()
                        .opacity(successOpacity)
                }
            }
        }
        .onAppear {
            createParticles()
            
            // Show success icon with animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showSuccessIcon = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    successScale = 1.0
                    successOpacity = 1.0
                }
            }
            
            // Fade out success icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    successOpacity = 0.0
                }
            }
        }
    }
    
    private func createParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        // Create 20 particles
        for i in 0..<20 {
            let angle = Double(i) * (360.0 / 20.0) * .pi / 180.0
            let distance = Double.random(in: 100...200)
            
            let particle = ParticleModel(
                id: UUID(),
                x: centerX + CGFloat(cos(angle) * distance),
                y: centerY + CGFloat(sin(angle) * distance),
                color: [theme.primaryColor, theme.secondaryColor, theme.accentColor, .yellow, .orange].randomElement() ?? theme.primaryColor,
                size: CGFloat.random(in: 4...8),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
            
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.5)) {
            for i in 0..<particles.count {
                particles[i].opacity = 0.0
                particles[i].y += CGFloat.random(in: 100...200)
                particles[i].rotation += Double.random(in: 180...360)
            }
        }
    }
}

struct ParticleModel: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var opacity: Double
    var rotation: Double
}

struct ParticleView: View {
    let particle: ParticleModel
    
    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .opacity(particle.opacity)
            .rotationEffect(.degrees(particle.rotation))
            .position(x: particle.x, y: particle.y)
    }
}

struct RewardsView_Previews: PreviewProvider {
    static var previews: some View {
        RewardsView()
    }
}
