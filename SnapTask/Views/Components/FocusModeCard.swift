import SwiftUI

struct FocusModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let gradient: [Color]
    let isDisabled: Bool
    let action: () -> Void
    
    @Environment(\.theme) private var theme
    
    init(title: String, description: String, icon: String, color: Color, gradient: [Color], action: @escaping () -> Void, isDisabled: Bool = false) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.gradient = gradient
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                HapticManager.shared.impact(.light)
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isDisabled ? [Color.gray.opacity(0.3)] : gradient.map { $0.opacity(0.18) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isDisabled ? .gray : color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(isDisabled ? theme.secondaryTextColor : theme.textColor)
                    
                    Text(description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow or disabled indicator
                if isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor.opacity(0.7))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                isDisabled ? 
                                    AnyShapeStyle(Color.gray.opacity(0.2)) : 
                                    AnyShapeStyle(LinearGradient(
                                        colors: gradient.map { $0.opacity(0.35) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(
                        color: theme.shadowColor,
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .opacity(isDisabled ? 0.7 : 1.0)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        FocusModeCard(
            title: "Simple Timer",
            description: "Free-form focus session with manual timing",
            icon: "stopwatch",
            color: .yellow,
            gradient: [.yellow, .orange],
            action: {
                print("Simple timer selected")
            }
        )
        
        FocusModeCard(
            title: "Pomodoro Technique",
            description: "25min work sessions with 5min breaks",
            icon: "timer",
            color: .red,
            gradient: [.red, .pink],
            action: {
                print("Pomodoro selected")
            }
        )
        
        FocusModeCard(
            title: "Coming Soon",
            description: "More focus methods will be added",
            icon: "sparkles",
            color: .gray,
            gradient: [.gray, .secondary],
            action: {
                // No action
            },
            isDisabled: true
        )
    }
    .padding()
}