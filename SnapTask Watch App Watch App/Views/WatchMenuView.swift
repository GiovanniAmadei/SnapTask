import SwiftUI

struct WatchMenuView: View {
    @Binding var selectedView: WatchViewType
    @Binding var showingMenu: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
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
                .padding(.vertical, 8)
            }
            .navigationTitle("SnapTask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingMenu = false
                    }
                    .font(.system(size: 14, weight: .medium))
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
            HStack(spacing: 12) {
                // Icon
                Image(systemName: viewType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 24)
                
                // Title
                Text(viewType.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}