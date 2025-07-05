import SwiftUI

struct RedeemedRewardsView: View {
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time Filter Section
                timeFilterSection
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if filteredRedeemedRewards.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(filteredRedeemedRewards, id: \.0.id) { reward, dates in
                                RedeemedRewardCard(reward: reward, redemptionDates: dates)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var timeFilterSection: some View {
        VStack(spacing: 16) {
            // Header with title and count
            HStack {
                Text("redeemed_rewards".localized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredRedeemedRewards.count) \(filteredRedeemedRewards.count == 1 ? "reward".localized : "rewards".localized)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }
            
            // Single row of filter buttons
            HStack(spacing: 6) {
                RedeemedTimeFilterChip(filter: .all, isSelected: selectedTimeFilter == .all) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .all }
                }
                RedeemedTimeFilterChip(filter: .day, isSelected: selectedTimeFilter == .day) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .day }
                }
                RedeemedTimeFilterChip(filter: .week, isSelected: selectedTimeFilter == .week) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .week }
                }
                RedeemedTimeFilterChip(filter: .month, isSelected: selectedTimeFilter == .month) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .month }
                }
                RedeemedTimeFilterChip(filter: .year, isSelected: selectedTimeFilter == .year) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .year }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(selectedTimeFilter.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "gift.circle")
                    .font(.system(size: 40))
                    .foregroundColor(selectedTimeFilter.color)
            }
            
            VStack(spacing: 8) {
                Text("no_rewards_redeemed_for".localized.replacingOccurrences(of: "{period}", with: selectedTimeFilter.localizedName))
                    .font(.system(size: 18, weight: .semibold))
                
                Text("start_earning_redeem_first".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RedeemedRewardCard: View {
    let reward: Reward
    let redemptionDates: [Date]
    
    private var totalPointsSpent: Int {
        redemptionDates.count * reward.pointsCost
    }
    
    private var lastRedeemed: Date? {
        redemptionDates.max()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: reward.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let description = reward.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(reward.frequency.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("-\(totalPointsSpent)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FF6B6B"))
                    
                    Text("\(redemptionDates.count) " + "times".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastRedeemed = lastRedeemed {
                HStack {
                    Text("last_redeemed".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.fullDate.string(from: lastRedeemed))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "5E5CE6"))
                    
                    Spacer()
                }
            }
            
            if redemptionDates.count > 1 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                    ForEach(redemptionDates.suffix(8).reversed(), id: \.self) { date in
                        Text(DateFormatter.shortDate.string(from: date))
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "FF6B6B").opacity(0.1))
                            .foregroundColor(Color(hex: "FF6B6B"))
                            .cornerRadius(6)
                    }
                    
                    if redemptionDates.count > 8 {
                        Text("+\(redemptionDates.count - 8)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct RedeemedTimeFilterChip: View {
    let filter: RedeemedRewardsView.TimeFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(compactTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? filter.color : Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.clear : filter.color.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: isSelected ? filter.color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var compactTitle: String {
        switch filter {
        case .all: return "sempre".localized
        case .day: return "today".localized
        case .week: return "settimana".localized
        case .month: return "mese".localized
        case .year: return "anno".localized
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