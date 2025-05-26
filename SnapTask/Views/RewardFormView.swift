import SwiftUI

struct RewardFormView: View {
    @Environment(\.dismiss) private var dismiss
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
            Form {
                Section("Reward Details") {
                    TextField("Reward Name", text: $rewardName)
                    TextField("Description", text: $rewardDescription, axis: .vertical)
                        .lineLimit(3...6)
                    NavigationLink {
                        IconPickerView(selectedIcon: $icon)
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Points") {
                    HStack {
                        Text("Cost")
                        Spacer()
                        Picker("", selection: $pointsCost) {
                            ForEach(1...40, id: \.self) { index in
                                let points = index * 5
                                Text("\(points)")
                                    .tag(points)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 100)
                        .clipped()
                        Text("points")
                    }
                }
                
                Section("Frequency") {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(RewardFrequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Point accumulation period:")
                            .font(.caption)
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
            .navigationTitle(initialReward == nil ? "New Reward" : "Edit Reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReward()
                        dismiss()
                    }
                    .disabled(rewardName.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
