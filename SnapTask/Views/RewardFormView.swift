import SwiftUI

struct RewardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = RewardViewModel()
    
    @State private var rewardName: String = ""
    @State private var rewardDescription: String = ""
    @State private var pointsCost: Int = 100
    @State private var selectedFrequency: RewardFrequency = .daily
    @State private var icon: String = "gift"
    
    var initialReward: Reward?
    var onSave: ((Reward) -> Void)?
    
    init(initialReward: Reward? = nil, onSave: ((Reward) -> Void)? = nil) {
        self.initialReward = initialReward
        self.onSave = onSave
        
        if let reward = initialReward {
            _rewardName = State(initialValue: reward.name)
            _rewardDescription = State(initialValue: reward.description ?? "")
            _pointsCost = State(initialValue: reward.pointsCost)
            _selectedFrequency = State(initialValue: reward.frequency)
            _icon = State(initialValue: reward.icon)
        }
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
                    
                    // Points Card
                    ModernCard(title: "Points", icon: "star.fill") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Cost")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                Menu {
                                    ForEach(1...40, id: \.self) { index in
                                        let points = index * 5
                                        Button(action: {
                                            pointsCost = points
                                        }) {
                                            HStack {
                                                Text("\(points) points")
                                                if pointsCost == points {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.pink)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(pointsCost) points")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    
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
                                
                                switch selectedFrequency {
                                case .daily:
                                    Text("Daily rewards reset at midnight")
                                case .weekly:
                                    Text("Weekly rewards accumulate Sunday through Saturday")
                                case .monthly:
                                    Text("Monthly rewards accumulate for the calendar month")
                                case .yearly:
                                    Text("Yearly rewards accumulate for the calendar year")
                                case .oneTime:
                                    Text("One-time rewards can be redeemed only once")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                                colors: !rewardName.isEmpty ? [.pink, .pink.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: !rewardName.isEmpty ? .pink.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(rewardName.isEmpty)
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
                    .disabled(rewardName.isEmpty)
                }
            }
        }
    }
    
    private func saveReward() {
        let reward = Reward(
            id: initialReward?.id ?? UUID(),
            name: rewardName,
            description: rewardDescription.isEmpty ? nil : rewardDescription,
            pointsCost: pointsCost,
            frequency: selectedFrequency,
            icon: icon
        )
        
        if initialReward != nil {
            RewardManager.shared.updateReward(reward)
        } else {
            RewardManager.shared.addReward(reward)
        }
        
        onSave?(reward)
    }
}

struct RewardFormView_Previews: PreviewProvider {
    static var previews: some View {
        RewardFormView()
    }
}
