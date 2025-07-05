import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons = [
        "alarm", "book.fill", "dumbbell.fill", "cup.and.saucer.fill",
        "fork.knife", "bed.double.fill", "car.fill", "airplane",
        "briefcase.fill", "cart.fill", "gift.fill", "heart.fill",
        "house.fill", "lightbulb.fill", "music.note", "pawprint.fill",
        "phone.fill", "star.fill", "gamecontroller.fill", "pencil"
    ]
    
    var body: some View {
        List {
            ForEach(icons, id: \.self) { icon in
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                    Spacer()
                    if icon == selectedIcon {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedIcon = icon
                    dismiss()
                }
            }
        }
        .navigationTitle("choose_icon".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}