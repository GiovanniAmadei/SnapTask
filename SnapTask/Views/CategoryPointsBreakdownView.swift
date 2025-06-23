import SwiftUI

struct CategoryPointsBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Points Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                }
            }
        }
    }
    
    private var mainPointsHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("Total Available Points")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                let totalPoints = rewardManager.availablePoints(for: .daily) + 
                                rewardManager.availablePoints(for: .weekly) + 
                                rewardManager.availablePoints(for: .monthly) + 
                                rewardManager.availablePoints(for: .yearly)
                
                Text("\(totalPoints)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            if !categoryManager.categories.isEmpty && !topCategoriesByPoints.isEmpty {
                VStack(spacing: 10) {
                    Text("Top Categories")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
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
                                        .foregroundColor(.secondary)
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(hex: "5E5CE6").opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
    
    private var periodBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Points by Period")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                PeriodPointsCard(
                    title: "Today",
                    points: rewardManager.availablePoints(for: .daily),
                    color: Color(hex: "FF6B6B"),
                    icon: "sun.max"
                )
                
                PeriodPointsCard(
                    title: "Week",
                    points: rewardManager.availablePoints(for: .weekly),
                    color: Color(hex: "4ECDC4"),
                    icon: "calendar.circle"
                )
                
                PeriodPointsCard(
                    title: "Month",
                    points: rewardManager.availablePoints(for: .monthly),
                    color: Color(hex: "45B7D1"),
                    icon: "calendar"
                )
                
                PeriodPointsCard(
                    title: "Year",
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Points by Category")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if categoryManager.categories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No categories available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Create categories to organize your rewards")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
        return rewardManager.availablePointsForCategory(categoryId, frequency: .daily) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .weekly) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .monthly) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .yearly)
    }
}

struct PeriodPointsCard: View {
    let title: String
    let points: Int
    let color: Color
    let icon: String
    
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
                .foregroundColor(.secondary)
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
    
    private var categoryColor: Color {
        Color(hex: category.color)
    }
    
    private var totalPoints: Int {
        rewardManager.availablePointsForCategory(category.id, frequency: .daily) +
        rewardManager.availablePointsForCategory(category.id, frequency: .weekly) +
        rewardManager.availablePointsForCategory(category.id, frequency: .monthly) +
        rewardManager.availablePointsForCategory(category.id, frequency: .yearly)
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
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(totalPoints)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(categoryColor)
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("Daily")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .daily))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("Weekly")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .weekly))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("Monthly")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(rewardManager.availablePointsForCategory(category.id, frequency: .monthly))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                HStack {
                    Text("Yearly")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
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
