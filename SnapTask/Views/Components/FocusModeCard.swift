import SwiftUI

struct FocusModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let gradient: [Color]
    let isDisabled: Bool
    let action: () -> Void
    
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
                action()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isDisabled ? [Color.gray.opacity(0.3)] : gradient.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isDisabled ? .gray : color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow or disabled indicator
                if isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isDisabled ? 
                                    AnyShapeStyle(Color.gray.opacity(0.2)) : 
                                    AnyShapeStyle(LinearGradient(
                                        colors: gradient.map { $0.opacity(0.3) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
