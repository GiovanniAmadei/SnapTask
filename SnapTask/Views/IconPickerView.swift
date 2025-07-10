import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    private let icons = [
        "alarm", "book.fill", "dumbbell.fill", "cup.and.saucer.fill",
        "fork.knife", "bed.double.fill", "car.fill", "airplane",
        "briefcase.fill", "cart.fill", "gift.fill", "heart.fill",
        "house.fill", "lightbulb.fill", "music.note", "pawprint.fill",
        "phone.fill", "star.fill", "gamecontroller.fill", "pencil"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .themedPrimaryText()
                                
                                if icon == selectedIcon {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.primaryColor)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(icon == selectedIcon ? theme.primaryColor.opacity(0.1) : theme.surfaceColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                icon == selectedIcon ? theme.primaryColor : theme.borderColor,
                                                lineWidth: icon == selectedIcon ? 2 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("choose_icon".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}