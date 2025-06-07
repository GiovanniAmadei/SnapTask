import SwiftUI

struct CategoryPointsBreakdownView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Header with Total Points
                    mainPointsHeader
                    
                    // Category Breakdown
                    categoryBreakdownSection
                    
                    // Frequency Breakdown
                    frequencyBreakdownSection
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
        VStack(spacing: 20) {
            // Big total points display with category preview
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Total Available Points")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    let totalPoints = rewardManager.availablePoints(for: .daily) + 
                                    rewardManager.availablePoints(for: .weekly) + 
                                    rewardManager.availablePoints(for: .monthly) + 
                                    rewardManager.availablePoints(for: .yearly)
                    
                    Text("\(totalPoints)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.primary)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                
                // Top categories preview
                if !categoryManager.categories.isEmpty {
                    VStack(spacing: 8) {
                        Text("Top Categories")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(Array(topCategoriesByPoints.prefix(3)), id: \.id) { category in
                                let totalCategoryPoints = getTotalPointsForCategory(category.id)
                                if totalCategoryPoints > 0 {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: category.color))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(category.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(totalCategoryPoints)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(hex: category.color))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(hex: category.color).opacity(0.1))
                                    )
                                }
                            }
                            
                            if topCategoriesByPoints.count > 3 {
                                Text("+\(topCategoriesByPoints.count - 3) more")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "5E5CE6").opacity(0.08),
                        Color(hex: "9747FF").opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
            
            // Period breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Points by Period")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    PointsCard(
                        title: "Today",
                        points: rewardManager.availablePoints(for: .daily),
                        color: Color(hex: "FF6B6B")
                    )
                    
                    PointsCard(
                        title: "Week",
                        points: rewardManager.availablePoints(for: .weekly),
                        color: Color(hex: "4ECDC4")
                    )
                    
                    PointsCard(
                        title: "Month",
                        points: rewardManager.availablePoints(for: .monthly),
                        color: Color(hex: "45B7D1")
                    )
                    
                    PointsCard(
                        title: "Year",
                        points: rewardManager.availablePoints(for: .yearly),
                        color: Color(hex: "FFD700")
                    )
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
        categoryManager.categories.sorted { category1, category2 in
            getTotalPointsForCategory(category1.id) > getTotalPointsForCategory(category2.id)
        }
    }
    
    private func getTotalPointsForCategory(_ categoryId: UUID) -> Int {
        return rewardManager.availablePointsForCategory(categoryId, frequency: .daily) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .weekly) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .monthly) +
               rewardManager.availablePointsForCategory(categoryId, frequency: .yearly)
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Points by Category")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if categoryManager.categories.isEmpty {
                Text("No categories available")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categoryManager.categories) { category in
                        CategoryPointsCard(category: category)
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
    
    private var frequencyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Points by Frequency")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach([RewardFrequency.daily, .weekly, .monthly, .yearly], id: \.self) { frequency in
                    FrequencyPointsRow(frequency: frequency)
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
}

struct PointsCard: View {
    let title: String
    let points: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(points)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
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

struct CategoryPointsCard: View {
    let category: Category
    @StateObject private var rewardManager = RewardManager.shared
    
    private var categoryColor: Color {
        Color(hex: category.color)
    }
    
    var body: some View {
        VStack(spacing: 12) {
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
            }
            
            // Points breakdown
            VStack(spacing: 8) {
                PointsBreakdownRow(
                    title: "Daily",
                    points: rewardManager.availablePointsForCategory(category.id, frequency: .daily),
                    color: categoryColor
                )
                
                PointsBreakdownRow(
                    title: "Weekly",
                    points: rewardManager.availablePointsForCategory(category.id, frequency: .weekly),
                    color: categoryColor
                )
                
                PointsBreakdownRow(
                    title: "Monthly",
                    points: rewardManager.availablePointsForCategory(category.id, frequency: .monthly),
                    color: categoryColor
                )
                
                PointsBreakdownRow(
                    title: "Yearly",
                    points: rewardManager.availablePointsForCategory(category.id, frequency: .yearly),
                    color: categoryColor
                )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(categoryColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct PointsBreakdownRow: View {
    let title: String
    let points: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(points)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

struct FrequencyPointsRow: View {
    let frequency: RewardFrequency
    @StateObject private var rewardManager = RewardManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    
    private var frequencyColor: Color {
        switch frequency {
        case .daily: return Color(hex: "FF6B6B")
        case .weekly: return Color(hex: "4ECDC4")
        case .monthly: return Color(hex: "45B7D1")
        case .yearly: return Color(hex: "FFD700")
        case .oneTime: return Color(hex: "9747FF")
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(frequencyColor)
                    .frame(width: 10, height: 10)
                
                Text(frequency.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(rewardManager.availablePoints(for: frequency)) total")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(frequencyColor)
            }
            
            // Category breakdown for this frequency
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(categoryManager.categories.prefix(6)) { category in
                    let points = rewardManager.availablePointsForCategory(category.id, frequency: frequency)
                    if points > 0 {
                        VStack(spacing: 4) {
                            Text(category.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text("\(points)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: category.color))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: category.color).opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(frequencyColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(frequencyColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct CategoryPointsBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryPointsBreakdownView()
    }
}
