import SwiftUI

struct CategoryPointsBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    mainPointsHeader
                    
                    periodBreakdownSection
                    
                    categoryBreakdownSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .themedBackground()
            .navigationTitle("points_overview".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .themedPrimary()
                }
            }
        }
    }
    
    private var mainPointsHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("total_available_points".localized)
                    .font(.system(size: 16, weight: .medium))
                    .themedSecondaryText()
                
                // FIXED: Use total points instead of summing overlapping periods
                let totalPoints = rewardManager.totalPoints()
                
                Text("\(totalPoints)")
                    .font(.system(size: 48, weight: .bold))
                    .themedPrimaryText()
                    .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
            }
            
            if !categoryManager.categories.isEmpty && !topCategoriesByPoints.isEmpty {
                VStack(spacing: 10) {
                    Text("top_categories".localized)
                        .font(.system(size: 14, weight: .medium))
                        .themedSecondaryText()
                    
                    HStack(spacing: 8) {
                        ForEach(Array(topCategoriesByPoints.prefix(4)), id: \.id) { category in
                            let totalCategoryPoints = getTotalPointsForCategory(category.id)
                            if totalCategoryPoints > 0 {
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(Color(hex: category.color))
                                        .frame(width: 8, height: 8)
                                    
                                    Text(category.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .themedSecondaryText()
                                        .lineLimit(1)
                                    
                                    Text("\(totalCategoryPoints)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: category.color))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: category.color).opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color(hex: category.color).opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.primaryColor.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: theme.shadowColor, radius: 6, x: 0, y: 3)
    }
    
    private var periodBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("points_by_period".localized)
                .font(.system(size: 18, weight: .semibold))
                .themedPrimaryText()
            
            HStack(spacing: 12) {
                PeriodPointsCard(
                    title: "today".localized,
                    points: rewardManager.availablePoints(for: .daily),
                    color: Color(hex: "FF6B6B"),
                    icon: "sun.max"
                )
                
                PeriodPointsCard(
                    title: "week".localized,
                    points: rewardManager.availablePoints(for: .weekly),
                    color: Color(hex: "4ECDC4"),
                    icon: "calendar.circle"
                )
                
                PeriodPointsCard(
                    title: "month".localized,
                    points: rewardManager.availablePoints(for: .monthly),
                    color: Color(hex: "45B7D1"),
                    icon: "calendar"
                )
                
                PeriodPointsCard(
                    title: "year".localized,
                    points: rewardManager.availablePoints(for: .yearly),
                    color: Color(hex: "FFD700"),
                    icon: "star.circle"
                )
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)
        )
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("points_by_category".localized)
                .font(.system(size: 18, weight: .semibold))
                .themedPrimaryText()
            
            if categoryManager.categories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .themedSecondaryText()
                    
                    Text("no_categories_available".localized)
                        .font(.system(size: 16, weight: .medium))
                        .themedSecondaryText()
                    
                    Text("create_categories_organize_rewards".localized)
                        .font(.system(size: 14))
                        .themedSecondaryText()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categoryManager.categories) { category in
                        ImprovedCategoryPointsCard(category: category)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.borderColor, lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)
        )
    }
    
    private var topCategoriesByPoints: [Category] {
        categoryManager.categories
            .filter { getTotalPointsForCategory($0.id) > 0 }
            .sorted { category1, category2 in
                getTotalPointsForCategory(category1.id) > getTotalPointsForCategory(category2.id)
            }
    }
    
    private func getTotalPointsForCategory(_ categoryId: UUID) -> Int {
        return rewardManager.totalPointsForCategory(categoryId)
    }
}

struct PeriodPointsCard: View {
    let title: String
    let points: Int
    let color: Color
    let icon: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text("\(points)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ImprovedCategoryPointsCard: View {
    let category: Category
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.theme) private var theme
    
    private var categoryColor: Color {
        Color(hex: category.color)
    }
    
    private var totalPoints: Int {
        rewardManager.totalPointsForCategory(category.id)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Category Header
            HStack(spacing: 8) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 12, height: 12)
                
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                    .themedPrimaryText()
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(totalPoints)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(categoryColor)
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("daily".localized)
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .daily))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("weekly".localized)
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .weekly))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("monthly".localized)
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .monthly))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("yearly".localized)
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .yearly))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(categoryColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct CategoryPointsBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryPointsBreakdownView()
    }
}