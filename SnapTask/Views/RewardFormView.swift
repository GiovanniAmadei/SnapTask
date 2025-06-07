import SwiftUI

struct RewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = RewardViewModel()
    @StateObject private var categoryManager = CategoryManager.shared
    
    @State private var rewardName: String = ""
    @State private var rewardDescription: String = ""
    @State private var pointsCost: Int = 100
    @State private var selectedFrequency: RewardFrequency = .daily
    @State private var icon: String = "gift"
    
    @State private var selectedCategoryId: UUID? = nil
    @State private var isGeneralReward: Bool = true
    @State private var useCustomPoints: Bool = false
    @State private var customPointsText: String = "100"
    
    var initialReward: Reward?
    var onSave: ((Reward) -> Void)?
    
    init(initialReward: Reward? = nil, onSave: ((Reward) -> Void)? = nil) {
        self.initialReward = initialReward
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Reward Details Card
                    ModernCard(title: "Reward Details", icon: "gift") {
                        VStack(spacing: 16) {
                            ModernTextField(
                                title: "Reward Name",
                                text: $rewardName,
                                placeholder: "Enter reward name..."
                            )
                            
                            ModernTextField(
                                title: "Description",
                                text: $rewardDescription,
                                placeholder: "Add description...",
                                axis: .vertical,
                                lineLimit: 3...6
                            )
                            
                            NavigationLink {
                                IconPickerView(selectedIcon: $icon)
                            } label: {
                                ModernNavigationRow(
                                    title: "Icon",
                                    value: icon,
                                    isSystemImage: true
                                )
                            }
                        }
                    }
                    
                    // Category Selection Card
                    ModernCard(title: "Category", icon: "folder") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use Specific Category")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("Use points from a specific category only")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ModernToggle(isOn: Binding(
                                    get: { !isGeneralReward },
                                    set: { isGeneralReward = !$0 }
                                ))
                            }
                            .onChange(of: isGeneralReward) { newValue in
                                if newValue {
                                    selectedCategoryId = nil
                                }
                            }
                            
                            if !isGeneralReward {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Select Category")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    if categoryManager.categories.isEmpty {
                                        Text("No categories available. Create a category first.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.vertical, 8)
                                    } else {
                                        LazyVGrid(columns: [
                                            GridItem(.flexible()),
                                            GridItem(.flexible())
                                        ], spacing: 12) {
                                            ForEach(categoryManager.categories) { category in
                                                RewardCategoryCard(
                                                    category: category,
                                                    isSelected: selectedCategoryId == category.id,
                                                    onTap: {
                                                        selectedCategoryId = category.id
                                                    }
                                                )
                                            }
                                        }
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isGeneralReward)
                    }
                    .animation(.easeInOut(duration: 0.2), value: isGeneralReward)
                    
                    // Points Card
                    ModernCard(title: "Points", icon: "star.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Custom Points")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $useCustomPoints)
                            }
                            
                            HStack(alignment: .center) {
                                Text("Cost")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                Group {
                                    if useCustomPoints {
                                        HStack {
                                            TextField("Points", text: $customPointsText)
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(PlainTextFieldStyle())
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.1))
                                                )
                                                .onChange(of: customPointsText) { oldValue, newValue in
                                                    let filtered = String(newValue.filter { $0.isNumber })
                                                    if filtered != newValue {
                                                        customPointsText = filtered
                                                    }
                                                    if let points = Int(filtered), points >= 1, points <= 999 {
                                                        pointsCost = points
                                                    }
                                                }
                                            
                                            Text("(1-999)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Picker("Points", selection: $pointsCost) {
                                            // Quick rewards (1-10)
                                            ForEach([1, 2, 3, 5, 8, 10], id: \.self) { points in
                                                Text("\(points)").tag(points)
                                            }
                                            // Regular rewards (15-50)
                                            ForEach([15, 20, 25, 30, 40, 50], id: \.self) { points in
                                                Text("\(points)").tag(points)
                                            }
                                            // Complex rewards (75-200)
                                            ForEach([75, 100, 150, 200], id: \.self) { points in
                                                Text("\(points)").tag(points)
                                            }
                                            // Premium rewards (250-500)
                                            ForEach([250, 300, 400, 500], id: \.self) { points in
                                                Text("\(points)").tag(points)
                                            }
                                        }
                                        .pickerStyle(WheelPickerStyle())
                                        .frame(width: 80, height: 100)
                                        .clipped()
                                        .onChange(of: pointsCost) { oldValue, newValue in
                                            customPointsText = "\(newValue)"
                                        }
                                    }
                                }
                                .frame(height: 100)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Point Guidelines:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                Text("• 1-10: Quick rewards (5-15 min worth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 15-50: Regular rewards (30-90 min worth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 75-200: Complex rewards (2-4 hours worth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 250-500: Premium rewards (major milestones)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                            
                            pointsPreview
                        }
                        .animation(.easeInOut(duration: 0.2), value: useCustomPoints)
                    }
                    .animation(.easeInOut(duration: 0.2), value: useCustomPoints)
                    
                    // Frequency Card
                    ModernCard(title: "Frequency", icon: "repeat") {
                        VStack(spacing: 16) {
                            Picker("Frequency", selection: $selectedFrequency) {
                                ForEach(RewardFrequency.allCases) { frequency in
                                    Text(frequency.displayName).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Point accumulation period:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                
                                Text(frequencyDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        }
                    }
                    
                    // Save Button
                    Button(action: {
                        saveReward()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .medium))
                            Text("Save Reward")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: canSave ? [.pink, .pink.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: canSave ? .pink.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!canSave)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(initialReward == nil ? "New Reward" : "Edit Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveReward()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let reward = initialReward {
                rewardName = reward.name
                rewardDescription = reward.description ?? ""
                pointsCost = reward.pointsCost
                selectedFrequency = reward.frequency
                icon = reward.icon
                selectedCategoryId = reward.categoryId
                isGeneralReward = reward.categoryId == nil
                customPointsText = "\(reward.pointsCost)"
                useCustomPoints = ![1,2,3,5,8,10,15,20,25,30,40,50,75,100,150,200,250,300,400,500].contains(reward.pointsCost)
            }
        }
    }
    
    @ViewBuilder
    private var pointsPreview: some View {
        if !isGeneralReward, let categoryId = selectedCategoryId {
            let categoryName = categoryManager.categories.first(where: { $0.id == categoryId })?.name ?? "Selected Category"
            let availablePoints = RewardManager.shared.availablePointsForCategory(categoryId, frequency: selectedFrequency)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Available \(categoryName) Points:")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(availablePoints) points")
                        .font(.caption)
                        .foregroundColor(availablePoints >= pointsCost ? .green : .orange)
                    
                    Spacer()
                    
                    if availablePoints < pointsCost {
                        Text("Need \(pointsCost - availablePoints) more")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } else if isGeneralReward {
            let availablePoints = RewardManager.shared.availablePoints(for: selectedFrequency)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Total Points:")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(availablePoints) points")
                        .font(.caption)
                        .foregroundColor(availablePoints >= pointsCost ? .green : .orange)
                    
                    Spacer()
                    
                    if availablePoints < pointsCost {
                        Text("Need \(pointsCost - availablePoints) more")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
    
    private var frequencyDescription: String {
        switch selectedFrequency {
        case .daily:
            return "Daily rewards reset at midnight"
        case .weekly:
            return "Weekly rewards accumulate Sunday through Saturday"
        case .monthly:
            return "Monthly rewards accumulate for the calendar month"
        case .yearly:
            return "Yearly rewards accumulate for the calendar year"
        case .oneTime:
            return "One-time rewards can be redeemed only once"
        }
    }
    
    private var canSave: Bool {
        !rewardName.isEmpty && (isGeneralReward || selectedCategoryId != nil)
    }
    
    private func saveReward() {
        let categoryName = selectedCategoryId != nil ? 
            categoryManager.categories.first(where: { $0.id == selectedCategoryId })?.name : nil
        
        let reward = Reward(
            id: initialReward?.id ?? UUID(),
            name: rewardName,
            description: rewardDescription.isEmpty ? nil : rewardDescription,
            pointsCost: pointsCost,
            frequency: selectedFrequency,
            icon: icon,
            categoryId: isGeneralReward ? nil : selectedCategoryId,
            categoryName: categoryName
        )
        
        if initialReward != nil {
            RewardManager.shared.updateReward(reward)
        } else {
            RewardManager.shared.addReward(reward)
        }
        
        onSave?(reward)
    }
}

struct RewardCategoryCard: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: category.color))
                    .frame(width: 32, height: 32)
                
                Text(category.name)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: category.color).opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(hex: category.color) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RewardFormView_Previews: PreviewProvider {
    static var previews: some View {
        RewardFormView()
    }
}
