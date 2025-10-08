import SwiftUI

struct MoodSelectionView: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var moodManager = MoodManager.shared
    @Environment(\.theme) private var theme
    @State private var selected: MoodType?

    private let columns = [
        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(MoodType.allCases, id: \.self) { mood in
                        Button {
                            select(mood)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: mood.colorHex).opacity(0.12))
                                        .frame(width: 66, height: 66)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    selected == mood ? Color(hex: mood.colorHex) : theme.borderColor,
                                                    lineWidth: selected == mood ? 2 : 1
                                                )
                                        )
                                    Text(mood.emoji)
                                        .font(.system(size: 30))
                                }
                                Text(mood.localizedName.capitalized)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundColor(theme.textColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: mood.colorHex).opacity(selected == mood ? 0.12 : 0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .themedBackground()
            .onAppear {
                selected = moodManager.mood(on: date)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if moodManager.mood(on: date) != nil {
                            Button(role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    moodManager.removeMood(for: date)
                                    selected = nil
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                dismiss()
                            } label: {
                                Text("remove".localized)
                            }
                        }
                        Button("done".localized) { dismiss() }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text(titleText)
                    .font(.title3.bold())
                    .themedPrimaryText()
                Spacer()
            }
            .padding(.horizontal)
            HStack {
                Text(subtitleText)
                    .font(.system(.caption, design: .rounded))
                    .themedSecondaryText()
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var titleText: String {
        let isToday = Calendar.current.isDateInToday(date)
        return isToday ? "how_do_you_feel_today".localized : "how_did_you_feel_that_day".localized
    }

    private var subtitleText: String {
        if let mood = selected {
            return String(format: "selected_mood_format".localized, mood.localizedName.capitalized)
        }
        return "tap_icon_to_select".localized
    }

    private func select(_ mood: MoodType) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selected = mood
            moodManager.setMood(for: date, type: mood)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        dismiss()
    }
}