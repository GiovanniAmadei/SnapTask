import SwiftUI

struct WatchRewardFormView: View {
    enum Mode {
        case create
        case edit(Reward)
    }
    
    let mode: Mode
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var rewardDescription: String = ""
    @State private var pointsCostValue: Double = 50
    @State private var frequency: RewardFrequency = .daily
    @State private var icon: String = "gift"
    
    private var pointsCost: Int {
        Int(pointsCostValue)
    }
    
    private let iconOptions = [
        "gift", "cup.and.saucer.fill", "gamecontroller.fill", "tv.fill",
        "film.fill", "music.note", "book.fill", "cart.fill",
        "fork.knife", "bed.double.fill", "figure.walk", "star.fill"
    ]
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var existingReward: Reward? {
        if case .edit(let reward) = mode { return reward }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header with cancel
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text(isEditing ? "Edit" : "New Reward")
                        .font(.headline)
                }
                .padding(.bottom, 4)
                
                // Name
                nameSection
                
                // Points cost
                pointsSection
                
                // Frequency
                frequencySection
                
                // Icon
                iconSection
                
                // Save button
                saveButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 20)
        }
        .onAppear {
            loadExistingReward()
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TextField("Reward name", text: $name)
                .font(.caption)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cost")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                
                Text("\(pointsCost)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.yellow)
                
                Spacer()
            }
            .focusable()
            .digitalCrownRotation($pointsCostValue, from: 1, through: 500, by: 5, sensitivity: .medium)
            
            Text("Use Digital Crown to adjust")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Frequency")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(RewardFrequency.allCases, id: \.self) { freq in
                        Button {
                            frequency = freq
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: freq.iconName)
                                    .font(.caption2)
                                Text(freq.shortDisplayName)
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(frequency == freq ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(frequency == freq ? .white : .primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Icon")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(iconOptions, id: \.self) { iconName in
                    Button {
                        icon = iconName
                    } label: {
                        Image(systemName: iconName)
                            .font(.caption)
                            .frame(width: 30, height: 30)
                            .background(icon == iconName ? Color.yellow : Color.gray.opacity(0.3))
                            .foregroundColor(icon == iconName ? .black : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private var saveButton: some View {
        Button {
            saveReward()
        } label: {
            Text(isEditing ? "Save Changes" : "Create Reward")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(name.isEmpty ? Color.gray : Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
    }
    
    private func loadExistingReward() {
        guard let reward = existingReward else { return }
        
        name = reward.name
        rewardDescription = reward.description ?? ""
        pointsCostValue = Double(reward.pointsCost)
        frequency = reward.frequency
        icon = reward.icon
    }
    
    private func saveReward() {
        if isEditing, let existing = existingReward {
            var updatedReward = existing
            updatedReward.name = name
            updatedReward.description = rewardDescription.isEmpty ? nil : rewardDescription
            updatedReward.pointsCost = pointsCost
            updatedReward.frequency = frequency
            updatedReward.icon = icon
            
            syncManager.updateReward(updatedReward)
        } else {
            let newReward = Reward(
                name: name,
                description: rewardDescription.isEmpty ? nil : rewardDescription,
                pointsCost: pointsCost,
                frequency: frequency,
                icon: icon
            )
            
            syncManager.createReward(newReward)
        }
        
        dismiss()
    }
}

#Preview {
    WatchRewardFormView(mode: .create)
        .environmentObject(WatchSyncManager.shared)
}
