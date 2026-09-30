import SwiftUI

struct CategoryPointsBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var rewardManager = RewardManager.shared

    private var totalPoints: Int {
        rewardManager.availablePoints(for: .oneTime)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroPointsHeader
                        .padding(.top, 8)
                    periodCardsSection
                    if !categoryManager.categories.isEmpty {
                        categorySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .themedBackground()
            .navigationTitle("points_overview".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) { dismiss() }
                        .fontWeight(.semibold)
                        .themedPrimary()
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroPointsHeader: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.primaryColor.opacity(0.7), theme.secondaryColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 160, height: 160)
                    .offset(x: geo.size.width - 60, y: -40)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .offset(x: -20, y: geo.size.height - 40)
            }
            .clipped()

            VStack(spacing: 6) {
                Text("available_points".localized.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(1.5)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(totalPoints.formatted())
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundColor(.white)

                    Text("pts".localized)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 6)
                }

                if !topCategoriesByPoints.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        ForEach(topCategoriesByPoints.prefix(3)) { category in
                            let pts = rewardManager.totalPointsForCategory(category.id)
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 10, height: 10)
                                Text(PointsFormat.compact(pts))
                                    .font(.system(size: 13, weight: .bold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                Text(category.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: theme.primaryColor.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    // MARK: - Period Cards

    private var periodCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("points_by_period".localized)
                .font(.system(size: 17, weight: .semibold))
                .themedPrimaryText()
                .padding(.horizontal, 2)

            HStack(spacing: 10) {
                PeriodCard(
                    title: RewardPeriodLabel.day.localized,
                    points: rewardManager.availablePoints(for: .daily),
                    icon: "sun.max.fill",
                    gradient: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]
                )
                PeriodCard(
                    title: RewardPeriodLabel.week.localized,
                    points: rewardManager.availablePoints(for: .weekly),
                    icon: "calendar.circle.fill",
                    gradient: [Color(hex: "4ECDC4"), Color(hex: "44A08D")]
                )
                PeriodCard(
                    title: RewardPeriodLabel.month.localized,
                    points: rewardManager.availablePoints(for: .monthly),
                    icon: "calendar.badge.clock",
                    gradient: [Color(hex: "45B7D1"), Color(hex: "2980B9")]
                )
                PeriodCard(
                    title: RewardPeriodLabel.year.localized,
                    points: rewardManager.availablePoints(for: .yearly),
                    icon: "star.circle.fill",
                    gradient: [Color(hex: "FFD700"), Color(hex: "FFA000")]
                )
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("points_by_category".localized)
                .font(.system(size: 17, weight: .semibold))
                .themedPrimaryText()
                .padding(.horizontal, 2)

            LazyVStack(spacing: 10) {
                ForEach(categoryManager.categories) { category in
                    CategoryPointRow(category: category)
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 6, x: 0, y: 3)
        )
    }

    // MARK: - Helpers

    private var topCategoriesByPoints: [Category] {
        categoryManager.categories
            .filter { rewardManager.totalPointsForCategory($0.id) > 0 }
            .sorted { rewardManager.totalPointsForCategory($0.id) > rewardManager.totalPointsForCategory($1.id) }
    }
}

// MARK: - Period Card

private struct PeriodCard: View {
    let title: String
    let points: Int
    let icon: String
    let gradient: [Color]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(PointsFormat.compact(points))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(gradient.first ?? theme.primaryColor)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .themedSecondaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(colors: gradient.map { $0.opacity(0.4) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: (gradient.first ?? theme.primaryColor).opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Category Row

private struct CategoryPointRow: View {
    let category: Category
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.theme) private var theme

    private var categoryColor: Color { Color(hex: category.color) }

    private var totalPoints: Int { rewardManager.totalPointsForCategory(category.id) }

    private var maxPoints: Int {
        let vals = [
            rewardManager.availablePointsForCategory(category.id, frequency: .daily),
            rewardManager.availablePointsForCategory(category.id, frequency: .weekly),
            rewardManager.availablePointsForCategory(category.id, frequency: .monthly),
            rewardManager.availablePointsForCategory(category.id, frequency: .yearly)
        ]
        return vals.max() ?? 1
    }

    private func subRow(_ label: String, points: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .themedSecondaryText()
            Spacer()
            Text("\(points.formatted()) " + "pts".localized)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(points > 0 ? categoryColor : theme.secondaryTextColor)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header row
            HStack(spacing: 10) {
                // Color circle + icon
                CategoryIconTile(icon: category.displayIcon, color: categoryColor, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .themedPrimaryText()
                    Text("total_available_points".localized)
                        .font(.system(size: 11))
                        .themedSecondaryText()
                }

                Spacer()

                Text(totalPoints.formatted())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(categoryColor)
            }

            // Thin progress bar representing the "richest" period
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(categoryColor.opacity(0.12))
                        .frame(height: 4)
                    let ratio = maxPoints > 0 ? min(Double(totalPoints) / Double(maxPoints * 4), 1.0) : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [categoryColor, categoryColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * ratio, height: 4)
                }
            }
            .frame(height: 4)

            // Sub-rows
            VStack(spacing: 6) {
                subRow("daily".localized, points: rewardManager.availablePointsForCategory(category.id, frequency: .daily))
                subRow("weekly".localized, points: rewardManager.availablePointsForCategory(category.id, frequency: .weekly))
                subRow("monthly".localized, points: rewardManager.availablePointsForCategory(category.id, frequency: .monthly))
                subRow("yearly".localized, points: rewardManager.availablePointsForCategory(category.id, frequency: .yearly))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(categoryColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(categoryColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legacy stubs (keep for compatibility)

struct PeriodPointsCard: View {
    let title: String; let points: Int; let color: Color; let icon: String
    @Environment(\.theme) private var theme
    var body: some View { EmptyView() }
}

struct ImprovedCategoryPointsCard: View {
    let category: Category
    var body: some View { EmptyView() }
}

struct CategoryPointsBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryPointsBreakdownView()
    }
}