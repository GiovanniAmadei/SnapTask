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
    /// True when `initialReward` is an existing reward (false for new ones and duplicates).
    var isEditing: Bool
    var onSave: ((Reward) -> Void)?
    var onDelete: ((Reward, RewardDeletionMode) -> Void)?
    @State private var showingDeleteConfirmation = false
    
    init(initialReward: Reward? = nil, isEditing: Bool? = nil,
         onSave: ((Reward) -> Void)? = nil, onDelete: ((Reward, RewardDeletionMode) -> Void)? = nil) {
        self.initialReward = initialReward
        self.isEditing = isEditing ?? (initialReward != nil)
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Reward Details Card
                    ModernCard(title: "reward_details".localized, icon: "gift") {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("reward_name".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                TextField("enter_reward_name".localized, text: $rewardName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("description".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                TextField("add_description".localized, text: $rewardDescription, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                            }
                            
                            NavigationLink {
                                IconPickerView(selectedIcon: $icon)
                            } label: {
                                ModernNavigationRow(
                                    title: "icon".localized,
                                    value: icon,
                                    isSystemImage: true
                                )
                            }
                        }
                    }
                    
                    // Category Selection Card
                    ModernCard(title: "category".localized, icon: "folder") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("use_specific_category".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("use_points_from_specific_category".localized)
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
                                    Text("select_category".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    if categoryManager.categories.isEmpty {
                                        Text("no_categories_available".localized)
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
                    ModernCard(title: "points".localized, icon: "star.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("custom_points".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $useCustomPoints)
                            }
                            
                            HStack(alignment: .center) {
                                Text("cost".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                Group {
                                    if useCustomPoints {
                                        HStack {
                                            TextField("points".localized, text: $customPointsText)
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
                                        Picker("points".localized, selection: $pointsCost) {
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
                                Text("point_guidelines".localized + ":")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                Text("• 1-10: " + "quick_rewards_worth".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 15-50: " + "regular_rewards_worth".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 75-200: " + "complex_rewards_worth".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("• 250-500: " + "premium_rewards_worth".localized)
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
                    ModernCard(title: "frequency".localized, icon: "repeat") {
                        VStack(spacing: 16) {
                            Picker("frequency".localized, selection: $selectedFrequency) {
                                ForEach(RewardFrequency.allCases) { frequency in
                                    Text(frequency.pickerLabel).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("point_accumulation_period".localized + ":")
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
                            Text("save_reward".localized)
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
                    
                    if isEditing, let reward = initialReward {
                        VStack(spacing: 12) {
                            if !reward.redemptions.isEmpty {
                                Text(String(format: (reward.redemptions.count == 1 ? "reward_history_summary_one" : "reward_history_summary").localized,
                                            reward.redemptions.count,
                                            reward.redemptions.max()!.formatted(date: .abbreviated, time: .omitted)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("delete_reward".localized, systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.1)))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                    
                    Color.clear.frame(height: 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "edit_reward".localized : "new_reward".localized)
            .alert(RewardDeletion.title(for: initialReward),
                                isPresented: $showingDeleteConfirmation) {
                RewardDeletion.buttons(for: initialReward) { reward, mode in
                    dismiss()
                    onDelete?(reward, mode)
                }
            } message: {
                Text(RewardDeletion.message(for: initialReward))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save".localized) {
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
                rewardName = isEditing ? reward.name : String(format: "reward_copy_name".localized, reward.name)
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
                Text("available_category_points".localized.replacingOccurrences(of: "{category}", with: categoryName))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(availablePoints) " + "points".localized)
                        .font(.caption)
                        .foregroundColor(availablePoints >= pointsCost ? .green : .orange)
                    
                    Spacer()
                    
                    if availablePoints < pointsCost {
                        Text("need_more_points".localized.replacingOccurrences(of: "{points}", with: "\(pointsCost - availablePoints)"))
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
                Text("available_total_points".localized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(availablePoints) " + "points".localized)
                        .font(.caption)
                        .foregroundColor(availablePoints >= pointsCost ? .green : .orange)
                    
                    Spacer()
                    
                    if availablePoints < pointsCost {
                        Text("need_more_points".localized.replacingOccurrences(of: "{points}", with: "\(pointsCost - availablePoints)"))
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
            return "daily_rewards_reset".localized
        case .weekly:
            return "weekly_rewards_accumulate".localized
        case .monthly:
            return "monthly_rewards_accumulate".localized
        case .yearly:
            return "yearly_rewards_accumulate".localized
        case .oneTime:
            return "onetime_rewards_once".localized
        }
    }
    
    private var canSave: Bool {
        !rewardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (isGeneralReward || selectedCategoryId != nil)
    }
    
    private func saveReward() {
        let categoryName = selectedCategoryId != nil ? 
            categoryManager.categories.first(where: { $0.id == selectedCategoryId })?.name : nil
        
        // Editing keeps the reward's history (redemptions, creation date): only the edited fields change.
        var reward = initialReward ?? Reward(name: rewardName, pointsCost: pointsCost)
        reward.name = rewardName.trimmingCharacters(in: .whitespacesAndNewlines)
        reward.description = rewardDescription.isEmpty ? nil : rewardDescription
        reward.pointsCost = pointsCost
        reward.frequency = selectedFrequency
        reward.icon = icon
        reward.categoryId = isGeneralReward ? nil : selectedCategoryId
        reward.categoryName = isGeneralReward ? nil : categoryName
        reward.lastModifiedDate = Date()
        
        if isEditing {
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
                CategoryIconTile(icon: category.displayIcon, color: Color(hex: category.color), size: 32)
                
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

enum RewardDeletionMode {
    /// Delete the reward and its redemptions: the points spent become available again.
    case refund
    /// Hide the reward but keep its redemptions: the points stay spent.
    case keepSpent
}

/// Texts and buttons for the delete confirmation (shared by the card menu and the edit form).
enum RewardDeletion {
    static func title(for reward: Reward?) -> String {
        String(format: "delete_reward_title".localized, reward?.name ?? "")
    }

    static func spentPoints(_ reward: Reward?) -> Int {
        guard let reward else { return 0 }
        return reward.redemptions.count * reward.pointsCost
    }

    static func message(for reward: Reward?) -> String {
        let count = reward?.redemptions.count ?? 0
        guard count > 0 else { return "delete_reward_message".localized }
        let times = count == 1 ? "reward_redeemed_once".localized
                               : String(format: "reward_redeemed_times".localized, count)
        return String(format: "delete_reward_choice_message".localized, times, spentPoints(reward))
    }

    /// Alert buttons: a choice about the points only when the reward was redeemed.
    @ViewBuilder
    static func buttons(for reward: Reward?, onDelete: @escaping (Reward, RewardDeletionMode) -> Void,
                        onCancel: @escaping () -> Void = {}) -> some View {
        if let reward {
            if reward.redemptions.isEmpty {
                Button("delete".localized, role: .destructive) { onDelete(reward, .refund) }
            } else {
                Button(String(format: "delete_reward_refund".localized, spentPoints(reward))) { onDelete(reward, .refund) }
                Button("delete_reward_keep_spent".localized, role: .destructive) { onDelete(reward, .keepSpent) }
            }
        }
        Button("cancel".localized, role: .cancel) { onCancel() }
    }
}
