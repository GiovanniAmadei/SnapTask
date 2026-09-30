import SwiftUI

struct RedeemedRewardsView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var selectedTimeFilter: TimeFilter = .all
    
    enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        
        var localizedName: String {
            switch self {
            case .all: return "all_time".localized
            case .day: return "today".localized
            case .week: return "this_week".localized
            case .month: return "this_month".localized
            case .year: return "this_year".localized
            }
        }
        
        var color: Color {
            switch self {
            case .all: return Color(hex: "5E5CE6")
            case .day: return Color(hex: "FF6B6B")
            case .week: return Color(hex: "4ECDC4")
            case .month: return Color(hex: "45B7D1")
            case .year: return Color(hex: "FFD700")
            }
        }
    }
    
    private var filteredRedeemedRewards: [(Reward, [Date])] {
        rewardManager.rewards.compactMap { reward in
            let filteredRedemptions = reward.redemptions.filter { date in
                dateMatchesFilter(date, filter: selectedTimeFilter)
            }
            return filteredRedemptions.isEmpty ? nil : (reward, filteredRedemptions)
        }
        .sorted { $0.1.max() ?? Date.distantPast > $1.1.max() ?? Date.distantPast }
    }
    
    private func dateMatchesFilter(_ date: Date, filter: TimeFilter) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            return true
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }
    
    private var shortLabel: (TimeFilter) -> String {
        { filter in
            switch filter {
            case .all: return RewardPeriodLabel.all.localized
            case .day: return RewardPeriodLabel.day.localized
            case .week: return RewardPeriodLabel.week.localized
            case .month: return RewardPeriodLabel.month.localized
            case .year: return RewardPeriodLabel.year.localized
            }
        }
    }

    private var totalSpent: Int {
        filteredRedeemedRewards.reduce(0) { $0 + $1.0.pointsCost * $1.1.count }
    }

    private var redemptionsCount: Int {
        filteredRedeemedRewards.reduce(0) { $0 + $1.1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    StatsSegmentedControl(options: TimeFilter.allCases, selection: $selectedTimeFilter, label: shortLabel)

                    HStack(spacing: 10) {
                        StatTile(value: "-" + totalSpent.formatted(), label: "rewards_points_spent".localized,
                                 systemImage: "minus.circle.fill", tint: .red)
                        StatTile(value: redemptionsCount.formatted(), label: "rewards_redemptions".localized,
                                 systemImage: "gift.fill", tint: theme.primaryColor)
                    }

                    if filteredRedeemedRewards.isEmpty {
                        StatsEmptyState(systemImage: "gift",
                                        title: "no_rewards_redeemed_for".localized.replacingOccurrences(of: "{period}", with: selectedTimeFilter.localizedName),
                                        message: "start_earning_redeem_first".localized)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.surfaceColor))
                    } else {
                        ForEach(filteredRedeemedRewards, id: \.0.id) { reward, dates in
                            RedeemedRewardCard(reward: reward, redemptionDates: dates)
                        }
                    }
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle("rewards_redeemed_short".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
}

struct RedeemedRewardCard: View {
    let reward: Reward
    let redemptionDates: [Date]
    @ObservedObject private var categoryManager = CategoryManager.shared
    @Environment(\.theme) private var theme

    private var tint: Color {
        reward.categoryId.flatMap { id in categoryManager.categories.first { $0.id == id } }
            .map { Color(hex: $0.color) } ?? theme.primaryColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                CategoryIconTile(icon: reward.icon, color: tint, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(reward.name)
                            .font(.headline)
                            .lineLimit(1)
                            .themedPrimaryText()
                        if reward.isArchived {
                            Text("reward_archived_tag".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(theme.secondaryTextColor)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(theme.secondaryTextColor.opacity(0.15)))
                                .fixedSize()
                        }
                    }
                    Text(reward.frequency.pickerLabel + " · " + String(format: "reward_last_on".localized,
                         (redemptionDates.max() ?? Date()).formatted(date: .abbreviated, time: .omitted)))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .themedSecondaryText()
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("-" + (redemptionDates.count * reward.pointsCost).formatted())
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.red)
                    Text("\(redemptionDates.count)×")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .themedSecondaryText()
                }
            }
            if redemptionDates.count > 1 {
                DateChipsGrid(dates: redemptionDates.sorted(by: >), color: tint)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.surfaceColor))
    }
}

/// Recent dates as small chips on a fixed adaptive grid (never overflows, in any language).
struct DateChipsGrid: View {
    let dates: [Date]
    let color: Color
    var limit = 8
    @Environment(\.theme) private var theme

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Array(dates.prefix(limit)), id: \.self) { date in
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(color.opacity(0.1)))
            }
            if dates.count > limit {
                Text("+\(dates.count - limit)")
                    .font(.caption2.weight(.semibold))
                    .themedSecondaryText()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.secondaryTextColor.opacity(0.1)))
            }
        }
    }
}

extension DateFormatter {
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}