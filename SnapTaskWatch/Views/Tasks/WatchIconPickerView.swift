import SwiftUI

struct WatchIconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons: [String] = [
        // Common
        "circle", "star", "heart", "bolt", "flame",
        // Tasks
        "checkmark.circle", "list.bullet", "doc.text", "pencil", "book",
        // Health
        "figure.walk", "figure.run", "dumbbell", "heart.fill", "bed.double",
        // Work
        "briefcase", "laptopcomputer", "phone", "envelope", "calendar",
        // Home
        "house", "cart", "fork.knife", "cup.and.saucer", "leaf",
        // Finance
        "dollarsign.circle", "creditcard", "banknote", "chart.line.uptrend.xyaxis",
        // Social
        "person", "person.2", "message", "bubble.left", "hand.thumbsup",
        // Creative
        "paintbrush", "camera", "music.note", "gamecontroller", "film",
        // Travel
        "car", "airplane", "tram", "bicycle", "figure.hiking",
        // Misc
        "gift", "tag", "flag", "bell", "lightbulb"
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 36), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                        dismiss()
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedIcon == icon ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Icon")
    }
}

#Preview {
    NavigationStack {
        WatchIconPickerView(selectedIcon: .constant("star"))
    }
}
