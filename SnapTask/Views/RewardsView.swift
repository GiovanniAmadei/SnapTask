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

    private var periods: [(label: String, points: Int)] {
        [(RewardPeriodLabel.day.localized, viewModel.dailyPoints),
         (RewardPeriodLabel.week.localized, viewModel.weeklyPoints),
         (RewardPeriodLabel.month.localized, viewModel.monthlyPoints),
         (RewardPeriodLabel.year.localized, viewModel.yearlyPoints)]
    }

    private var pointsHero: some View {
        Button { showingCategoryPointsBreakdown = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("available_points".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                            .lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(viewModel.totalAvailablePoints.formatted())
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .themedPrimaryText()
                            Text("pts".localized)
                                .font(.subheadline.weight(.semibold))
                                .themedSecondaryText()
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(theme.primaryColor.opacity(0.12)))
                }

                // Four equal columns on one line: values shrink instead of wrapping.
                HStack(spacing: 0) {
                    ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                        VStack(spacing: 2) {
                            Text(PointsFormat.compact(period.points))
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(theme.primaryColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(period.label)
                                .font(.caption2.weight(.medium))
                                .themedSecondaryText()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        if index < periods.count - 1 {
                            Rectangle()
                                .fill(theme.secondaryTextColor.opacity(0.15))
                                .frame(width: 1, height: 26)
                        }
                    }
                }
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.primaryColor.opacity(0.07)))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.surfaceColor))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction("rewards_history_short".localized, icon: "chart.line.uptrend.xyaxis") { showingPointsHistory = true }
            quickAction("rewards_redeemed_short".localized, icon: "gift") { showingRedeemedRewards = true }
        }
    }

    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .themedPrimaryText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.surfaceColor))
        }
        .buttonStyle(.plain)
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
                                        }
                                    },
                                    onEditTapped: { selectedReward = reward },
                                    onDuplicateTapped: {
                                        duplicatingReward = Reward(name: reward.name, description: reward.description,
                                                                   pointsCost: reward.pointsCost, frequency: reward.frequency,
                                                                   icon: reward.icon, categoryId: reward.categoryId,
                                                                   categoryName: reward.categoryName)
                                    },
                                    onDeleteTapped: { rewardToDelete = reward }
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

    @ObservedObject private var categoryManager = CategoryManager.shared
    @Environment(\.theme) private var theme
    @State private var justRedeemed = false

    private var category: Category? {
        reward.categoryId.flatMap { id in categoryManager.categories.first { $0.id == id } }
    }

    private var tint: Color { category.map { Color(hex: $0.color) } ?? theme.primaryColor }

    private var available: Int {
        let points = reward.isGeneralReward
            ? RewardManager.shared.availablePoints(for: reward.frequency)
            : RewardManager.shared.availablePointsForCategory(reward.categoryId!, frequency: reward.frequency)
        return max(points, 0)
    }

    private var progress: Double {
        reward.pointsCost > 0 ? min(Double(available) / Double(reward.pointsCost), 1) : 1
    }

    /// Redemptions in the current period of the reward's frequency.
    private var redeemedThisPeriod: Int {
        let calendar = Calendar.current
        let now = Date()
        return reward.redemptions.filter { date in
            switch reward.frequency {
            case .daily: return calendar.isDate(date, inSameDayAs: now)
            case .weekly: return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .monthly: return calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .yearly: return calendar.isDate(date, equalTo: now, toGranularity: .year)
            case .oneTime: return true
            }
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                CategoryIconTile(icon: reward.icon, color: tint, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.name)
                        .font(.headline)
                        .themedPrimaryText()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let description = reward.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .themedSecondaryText()
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        tag(icon: category?.displayIcon ?? "star.fill",
                            text: category?.name ?? "general".localized, color: tint)
                        if redeemedThisPeriod > 0 {
                            tag(icon: "checkmark",
                                text: redeemedThisPeriod > 1 ? "\(redeemedThisPeriod)×" : "redeemed".localized,
                                color: .green)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(reward.pointsCost.formatted())
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(tint)
                        .lineLimit(1)
                    Text("pts".localized)
                        .font(.caption2.weight(.medium))
                        .themedSecondaryText()
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tint.opacity(0.15))
                            Capsule().fill(canRedeem ? Color.green : tint)
                                .frame(width: max(6, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                    Text(canRedeem
                         ? "\(available.formatted())/\(reward.pointsCost.formatted()) " + "pts".localized
                         : "need_more_points".localized.replacingOccurrences(of: "{points}", with: "\(reward.pointsCost - available)"))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundColor(canRedeem ? .green : theme.secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Button {
                    onRedeemTapped()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { justRedeemed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut) { justRedeemed = false }
                    }
                } label: {
                    Label(justRedeemed ? "riscattato!".localized : "redeem".localized,
                          systemImage: justRedeemed ? "checkmark" : "gift.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(canRedeem || justRedeemed ? .white : theme.secondaryTextColor)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(justRedeemed ? Color.green
                                                   : (canRedeem ? tint : theme.secondaryTextColor.opacity(0.12))))
                }
                .buttonStyle(.plain)
                .disabled(!canRedeem)
                .fixedSize()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.surfaceColor))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(canRedeem ? tint.opacity(0.35) : .clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { onEditTapped() }
        .contextMenu {
            Button { onEditTapped() } label: { Label("edit".localized, systemImage: "pencil") }
            Button { onDuplicateTapped() } label: { Label("duplicate".localized, systemImage: "plus.square.on.square") }
            Button(role: .destructive) { onDeleteTapped() } label: { Label("delete".localized, systemImage: "trash") }
        }
    }

    private func tag(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
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
