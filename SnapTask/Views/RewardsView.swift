import SwiftUI
import Combine

/// Short period labels used where space is tight (never wrap, in every language).
enum RewardPeriodLabel {
    static let day = "rewards_period_day"
    static let week = "rewards_period_week"
    static let month = "rewards_period_month"
    static let year = "rewards_period_year"
    static let all = "rewards_period_all"
}

enum PointsFormat {
    /// 1.234 → "1.2k" only when space is tight.
    static func compact(_ n: Int) -> String {
        let v = Double(n)
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000).replacingOccurrences(of: ".0", with: "") }
        if v >= 10_000 { return String(format: "%.1fk", v / 1_000).replacingOccurrences(of: ".0", with: "") }
        return n.formatted()
    }
}

struct RewardsView: View {
    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showingAddReward = false
    @State private var selectedReward: Reward?
    @State private var showingPointsHistory = false
    @State private var showingRedeemedRewards = false
    @State private var showingCategoryPointsBreakdown = false
    @State private var showingPremiumPaywall = false
    @State private var selectedFrequencyFilter: RewardFrequency? = nil
    @State private var duplicatingReward: Reward?
    @State private var rewardToDelete: Reward?
    /// Deleted reward hidden from the list for a few seconds so it can be restored.
    @State private var pendingDeletion: Reward?
    @State private var pendingDeletionMode: RewardDeletionMode = .refund
    @State private var deletionTask: Task<Void, Never>?
    @State private var redeemedRewardId: UUID?
    @Environment(\.theme) private var theme

    private var allRewards: [Reward] {
        (viewModel.dailyRewards + viewModel.weeklyRewards + viewModel.monthlyRewards + viewModel.yearlyRewards + viewModel.oneTimeRewards)
            .filter { $0.id != pendingDeletion?.id }
            .sorted { $0.pointsCost < $1.pointsCost }
    }

    private func rewards(for frequency: RewardFrequency) -> [Reward] {
        allRewards.filter { $0.frequency == frequency }
    }

    private var rewardFrequencySections: [(RewardFrequency, [Reward])] {
        RewardFrequency.allCases.compactMap { freq in
            let r = rewards(for: freq)
            return r.isEmpty ? nil : (freq, r)
        }
    }

    private var filteredRewardSections: [(RewardFrequency, [Reward])] {
        guard let filter = selectedFrequencyFilter else { return rewardFrequencySections }
        let r = rewards(for: filter)
        return r.isEmpty ? [] : [(filter, r)]
    }

    private var canAddMoreRewards: Bool {
        if subscriptionManager.hasAccess(to: .unlimitedRewards) { return true }
        return allRewards.count < SubscriptionManager.maxRewardsForFree
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("rewards".localized)
                        .font(.largeTitle.bold())
                        .themedPrimaryText()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: 14) {
                            pointsHero
                            quickActions
                            rewardsList
                            if !subscriptionManager.hasAccess(to: .unlimitedRewards) {
                                premiumLimitInfo
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 120)
                    }
                }

                AddRewardButton(
                    isShowingRewardForm: $showingAddReward,
                    canAdd: canAddMoreRewards,
                    onPremiumTapped: { showingPremiumPaywall = true }
                )
                .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddReward) {
                if canAddMoreRewards { RewardFormView() }
            }
            .sheet(item: $selectedReward) { reward in
                RewardFormView(initialReward: reward, onDelete: { scheduleDeletion($0, mode: $1) })
            }
            .sheet(item: $duplicatingReward) { reward in
                RewardFormView(initialReward: reward, isEditing: false)
            }
            .alert(RewardDeletion.title(for: rewardToDelete),
                   isPresented: Binding(get: { rewardToDelete != nil }, set: { if !$0 { rewardToDelete = nil } })) {
                RewardDeletion.buttons(for: rewardToDelete, onDelete: { reward, mode in
                    scheduleDeletion(reward, mode: mode)
                    rewardToDelete = nil
                }, onCancel: { rewardToDelete = nil })
            } message: {
                Text(RewardDeletion.message(for: rewardToDelete))
            }
            .overlay(alignment: .bottom) {
                if let reward = pendingDeletion {
                    undoBanner(for: reward)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onDisappear { commitPendingDeletion() }
            .sheet(isPresented: $showingPointsHistory) { PointsHistoryView() }
            .sheet(isPresented: $showingRedeemedRewards) { RedeemedRewardsView() }
            .sheet(isPresented: $showingCategoryPointsBreakdown) { CategoryPointsBreakdownView() }
            .sheet(isPresented: $showingPremiumPaywall) { PremiumPaywallView() }
            .onAppear {
                viewModel.updatePoints()
                #if DEBUG
                // `-rewardsSheet history|redeemed|breakdown` opens a sub-screen at launch (screenshots).
                switch UserDefaults.standard.string(forKey: "rewardsSheet") {
                case "history": showingPointsHistory = true
                case "redeemed": showingRedeemedRewards = true
                case "breakdown": showingCategoryPointsBreakdown = true
                default: break
                }
                #endif
            }
        }
    }

    // MARK: - Points

    private var pointsHero: some View {
        VStack(spacing: 12) {
            // Header with total points and detail button (original style)
            Button(action: { showingCategoryPointsBreakdown = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("available_points".localized)
                            .font(.system(size: 13, weight: .medium))
                            .themedSecondaryText()
                            .lineLimit(1)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(viewModel.totalAvailablePoints.formatted())
                                .font(.system(size: 32, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .themedPrimaryText()
                            Text("pts".localized)
                                .font(.system(size: 12, weight: .semibold))
                                .themedSecondaryText()
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

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
                            .fixedSize()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Period chips: original style, always one line (equal widths, content shrinks instead of wrapping).
            HStack(spacing: 6) {
                CompactPointsChip(title: RewardPeriodLabel.day.localized, points: viewModel.dailyPoints, color: theme.primaryColor)
                CompactPointsChip(title: RewardPeriodLabel.week.localized, points: viewModel.weeklyPoints, color: theme.secondaryColor)
                CompactPointsChip(title: RewardPeriodLabel.month.localized, points: viewModel.monthlyPoints, color: theme.accentColor)
                CompactPointsChip(title: RewardPeriodLabel.year.localized, points: viewModel.yearlyPoints, color: theme.primaryColor.opacity(0.8))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .themedCard()
        .padding(.top, 4)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            CompactActionCard(title: "points_history".localized, icon: "chart.line.uptrend.xyaxis", color: theme.primaryColor) {
                showingPointsHistory = true
            }
            CompactActionCard(title: "redeemed_rewards".localized, icon: "gift.circle", color: theme.secondaryColor) {
                showingRedeemedRewards = true
            }
        }
    }

    // MARK: - Rewards

    private var frequencyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterPill(label: RewardPeriodLabel.all.localized, icon: "square.grid.2x2",
                           isSelected: selectedFrequencyFilter == nil, color: theme.primaryColor,
                           badge: allRewards.count) {
                    withAnimation(.snappy) { selectedFrequencyFilter = nil }
                }
                ForEach(RewardFrequency.allCases) { freq in
                    let count = rewards(for: freq).count
                    if count > 0 {
                        FilterPill(label: freq.pickerLabel, icon: freq.iconName,
                                   isSelected: selectedFrequencyFilter == freq, color: theme.primaryColor,
                                   badge: count) {
                            withAnimation(.snappy) {
                                selectedFrequencyFilter = (selectedFrequencyFilter == freq) ? nil : freq
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var rewardsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("available_rewards".localized)
                .font(.title3.weight(.bold))
                .themedPrimaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)

            if allRewards.isEmpty {
                emptyRewardsView
            } else {
                frequencyFilterBar
                LazyVStack(spacing: 18) {
                    ForEach(filteredRewardSections, id: \.0) { frequency, sectionRewards in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: frequency.iconName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.primaryColor)
                                Text(frequency.pickerLabel)
                                    .font(.footnote.weight(.semibold))
                                    .textCase(.uppercase)
                                    .themedSecondaryText()
                                    .lineLimit(1)
                                Spacer()
                                Text("\(viewModel.currentPoints(for: frequency).formatted()) " + "pts".localized)
                                    .font(.footnote.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundColor(theme.primaryColor)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 4)

                            ForEach(sectionRewards) { reward in
                                RewardCard(
                                    reward: reward,
                                    canRedeem: viewModel.canRedeemReward(reward),
                                    currentPoints: viewModel.currentPoints(for: reward.frequency),
                                    onRedeemTapped: {
                                        if viewModel.canRedeemReward(reward) {
                                            HapticManager.shared.notification(.success)
                                            viewModel.redeemReward(reward)
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { redeemedRewardId = reward.id }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                                if redeemedRewardId == reward.id {
                                                    withAnimation(.easeOut(duration: 0.3)) { redeemedRewardId = nil }
                                                }
                                            }
                                        }
                                    },
                                    onEditTapped: { selectedReward = reward },
                                    onDuplicateTapped: {
                                        duplicatingReward = Reward(name: reward.name, description: reward.description,
                                                                   pointsCost: reward.pointsCost, frequency: reward.frequency,
                                                                   icon: reward.icon, categoryId: reward.categoryId,
                                                                   categoryName: reward.categoryName)
                                    },
                                    onDeleteTapped: { rewardToDelete = reward },
                                    showsRedeemSuccess: redeemedRewardId == reward.id
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Deletion with undo

    private func scheduleDeletion(_ reward: Reward, mode: RewardDeletionMode) {
        commitPendingDeletion()
        HapticManager.shared.notification(.warning)
        pendingDeletionMode = mode
        withAnimation(.snappy) { pendingDeletion = reward }
        deletionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            commitPendingDeletion()
        }
    }

    private func commitPendingDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        guard let reward = pendingDeletion else { return }
        switch pendingDeletionMode {
        case .refund: viewModel.removeReward(reward)
        case .keepSpent: viewModel.archiveReward(reward)
        }
        withAnimation(.snappy) { pendingDeletion = nil }
    }

    private func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        HapticManager.shared.impact(.light)
        withAnimation(.snappy) { pendingDeletion = nil }
    }

    private func undoBanner(for reward: Reward) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundColor(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "reward_deleted".localized, reward.name))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !reward.redemptions.isEmpty {
                    Text(pendingDeletionMode == .refund
                         ? String(format: "reward_points_refunded".localized, RewardDeletion.spentPoints(reward))
                         : "reward_points_kept".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button("undo".localized) { undoDeletion() }
                .font(.subheadline.weight(.bold))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.85)))
    }

    private var emptyRewardsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(theme.primaryColor)
                .frame(width: 64, height: 64)
                .background(Circle().fill(theme.primaryColor.opacity(0.12)))
            Text("no_rewards_yet".localized)
                .font(.headline)
                .themedPrimaryText()
            Text("create_first_reward_motivation".localized)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .themedSecondaryText()
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.surfaceColor))
    }

    private var premiumLimitInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                Text("premium_limit_info".localized)
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("premium_limit_description".localized)
                .font(.subheadline)
                .themedSecondaryText()
            
            HStack {
                Text("\(allRewards.count)/\(SubscriptionManager.maxRewardsForFree)")
                    .font(.caption)
                    .themedSecondaryText()
                
                Spacer()
                
                Button("upgrade_to_pro".localized) {
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
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.surfaceColor))
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


// MARK: - Reward card

struct RewardCard: View {
    let reward: Reward
    let canRedeem: Bool
    let currentPoints: Int
    let onRedeemTapped: () -> Void
    let onEditTapped: () -> Void
    var onDuplicateTapped: () -> Void = {}
    let onDeleteTapped: () -> Void
    /// Owned by the list: the card is redrawn when its points change, so local state would be lost.
    var showsRedeemSuccess = false
    
    @StateObject private var categoryManager = CategoryManager.shared
    @Environment(\.theme) private var theme
    @State private var isAnimating = false
    private var successAnimation: Bool { showsRedeemSuccess }
    
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
            
            // Card content with improved layout
            VStack(spacing: 8) {
                // Header row with icon and title
                HStack(spacing: 12) {
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
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: reward.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Title and tag
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top) {
                            Text(reward.name)
                                .font(.system(size: 15, weight: .semibold))
                                .themedPrimaryText()
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                rewardTypeTag
                                    .fixedSize()
                                
                                // Redemption badge: full label when it fits, otherwise just the check.
                                if redemptionInfo.redemptionCount > 1 {
                                    redemptionCounterTag.fixedSize()
                                } else if redemptionInfo.hasBeenRedeemed {
                                    ViewThatFits(in: .horizontal) {
                                        redemptionIndicator.fixedSize()
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        if let description = reward.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12))
                                .themedSecondaryText()
                                .lineLimit(1)
                        }
                    }
                }

                // Bottom row with points and redeem button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if reward.isGeneralReward {
                            let actualPoints = RewardManager.shared.availablePoints(for: reward.frequency)
                            let safePoints = max(actualPoints, 0)
                            Text("\(safePoints)/\(reward.pointsCost) " + "points".localized)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(canRedeem ? Color(hex: "00C853") : theme.primaryColor)
                        } else if let categoryId = reward.categoryId {
                            let categoryPoints = RewardManager.shared.availablePointsForCategory(categoryId, frequency: reward.frequency)
                            let safeCategoryPoints = max(categoryPoints, 0)
                            Text("\(safeCategoryPoints)/\(reward.pointsCost) " + "points".localized)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(canRedeem ? Color(hex: "00C853") : categoryColor)
                        }
                        
                        if !canRedeem {
                            let actualAvailablePoints = reward.isGeneralReward ? 
                                RewardManager.shared.availablePoints(for: reward.frequency) :
                                RewardManager.shared.availablePointsForCategory(reward.categoryId!, frequency: reward.frequency)
                            let missingPoints = reward.pointsCost - max(actualAvailablePoints, 0)
                            Text("need_more_points".localized.replacingOccurrences(of: "{points}", with: "\(missingPoints)"))
                                .font(.system(size: 11))
                                .themedSecondaryText()
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Animation sequence
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isAnimating = true
                        }
                        
                        onRedeemTapped()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) { isAnimating = false }
                        }
                    }) {
                        Text("redeem".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .opacity(successAnimation ? 0 : 1.0)
        }
        // Redeem confirmation: covers the card (drawn on top, content hidden) instead of mixing with it.
        .overlay {
            if successAnimation {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Color(hex: "00C853"), Color(hex: "00A844")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 34, weight: .bold))
                            .symbolEffect(.bounce, value: successAnimation)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("reward_redeemed_success".localized)
                                .font(.headline)
                            Text("\(reward.name) · -\(reward.pointsCost) " + "pts".localized)
                                .font(.subheadline)
                                .opacity(0.9)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)
        // Tap anywhere on the card (outside the redeem button) to edit.
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { onEditTapped() }

        // Context Menu
        .contextMenu {
            Button {
                onEditTapped()
            } label: {
                Label("edit".localized, systemImage: "pencil")
            }
            
            Button {
                onDuplicateTapped()
            } label: {
                Label("duplicate".localized, systemImage: "plus.square.on.square")
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
            
            Text("redeemed".localized)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
        .padding(.vertical, 3)
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
            Image(systemName: reward.isGeneralReward ? "star.fill" : (categoryManager.categories.first { $0.id == reward.categoryId }?.displayIcon ?? "folder.fill"))
                .font(.system(size: 8))
                .foregroundColor(reward.isGeneralReward ? theme.primaryColor : categoryColor)
            Text(reward.isGeneralReward ? "general".localized : (reward.categoryName ?? reward.frequency.shortDisplayName.localized))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(reward.isGeneralReward ? theme.primaryColor : categoryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

struct FilterPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    var badge: Int? = nil
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.footnote.weight(.semibold)).lineLimit(1)
                if let badge {
                    Text("\(badge)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(isSelected ? color : theme.secondaryTextColor)
                        .padding(.horizontal, 5)
                        .background(Capsule().fill(isSelected ? Color.white.opacity(0.9) : theme.secondaryTextColor.opacity(0.12)))
                }
            }
            .fixedSize()
            .foregroundColor(isSelected ? .white : theme.textColor)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(isSelected ? color : theme.surfaceColor))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct CompactPointsChip: View {
    let title: String
    let points: Int
    let color: Color
    @Environment(\.theme) private var theme

    private var value: String {
        points >= 1_000 ? String(format: "%.1fk", Double(points) / 1_000).replacingOccurrences(of: ".0k", with: "k") : "\(points)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            // One Text: number and label shrink together instead of truncating the label.
            (Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(color)
             + Text(" " + title).font(.system(size: 11, weight: .medium)).foregroundColor(theme.secondaryTextColor))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08)))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.surfaceColor)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.15), lineWidth: 0.5))
            )
            .shadow(color: theme.shadowColor, radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
