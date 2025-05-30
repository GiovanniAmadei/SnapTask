import SwiftUI

struct WatchMenuView: View {
    @Binding var selectedView: WatchViewType
    @Binding var showingMenu: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(WatchViewType.allCases, id: \.self) { viewType in
                        WatchMenuRow(
                            viewType: viewType,
                            isSelected: viewType == selectedView,
                            onTap: {
                                selectedView = viewType
                                showingMenu = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingMenu = false
                    }
                    .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }
}

struct WatchMenuRow: View {
    let viewType: WatchViewType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: viewType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 20)
                
                // Title
                Text(viewType.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum WatchViewType: String, CaseIterable {
    case timeline = "timeline"
    case focus = "focus"
    case rewards = "rewards"
    case statistics = "statistics"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .focus: return "Focus"
        case .rewards: return "Rewards"
        case .statistics: return "Stats"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "calendar"
        case .focus: return "timer"
        case .rewards: return "star.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gear"
        }
    }
}
