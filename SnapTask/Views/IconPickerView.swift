import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private struct IconCategory: Identifiable {
        let id = UUID()
        let titleKey: String
        let icons: [String]
    }
    
    private let categories: [IconCategory] = [
        IconCategory(
            titleKey: "icon_category_general",
            icons: [
                "circle.fill", "circle",
                "checkmark.circle.fill",
                "flag.fill", "bookmark.fill", "tag.fill",
                "star.fill", "sparkles", "crown.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_time_planning",
            icons: [
                "bell.fill", "alarm", "calendar", "clock.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_study_work",
            icons: [
                "book.fill", "text.book.closed.fill", "graduationcap.fill",
                "briefcase.fill", "building.2.fill",
                "pencil", "pencil.and.list.clipboard",
                "list.bullet", "checklist", "note.text"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_energy_nature",
            icons: [
                "bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "lightbulb.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_sport_wellbeing",
            icons: [
                "dumbbell.fill", "figure.run", "bicycle", "sportscourt.fill",
                "heart.fill", "stethoscope", "cross.case.fill", "pills.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_food_drink",
            icons: [
                "cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_home_security",
            icons: [
                "house.fill", "bed.double.fill", "moon.fill", "zzz",
                "key.fill", "lock.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_travel_places",
            icons: [
                "car.fill", "bus.fill", "tram.fill", "airplane", "ferry.fill",
                "globe", "map.fill", "mappin.and.ellipse"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_shopping_money",
            icons: [
                "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill", "receipt.fill",
                "gift.fill", "party.popper.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_creativity_media",
            icons: [
                "brain.head.profile", "paintbrush.fill",
                "music.note", "headphones", "tv.fill", "camera.fill",
                "gamecontroller.fill", "dice.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_communication",
            icons: [
                "phone.fill", "video.fill",
                "message.fill", "bubble.left.and.bubble.right.fill",
                "envelope.fill", "paperplane.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_weather",
            icons: [
                "sun.max.fill", "cloud.fill", "cloud.sun.fill",
                "cloud.rain.fill", "cloud.snow.fill",
                "wind", "umbrella.fill"
            ]
        ),
        IconCategory(
            titleKey: "icon_category_animals",
            icons: [
                "pawprint.fill", "ladybug.fill", "tortoise.fill", "hare.fill", "bird.fill", "fish.fill"
            ]
        )
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(categories) { category in
                        Text(category.titleKey.localized)
                            .font(.headline)
                            .themedPrimaryText()
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(category.icons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                    dismiss()
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .themedPrimaryText()
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
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .themedBackground()
            .navigationTitle("choose_icon".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}