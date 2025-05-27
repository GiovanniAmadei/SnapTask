import SwiftUI

enum ControlButtonSize {
    case small, medium, large
    
    var size: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 56
        case .large: return 72
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 20
        case .large: return 28
        }
    }
}

struct ControlButton: View {
    let icon: String
    let size: ControlButtonSize
    let color: Color
    let isDisabled: Bool
    let isPulsing: Bool
    let action: () -> Void
    
    init(
        icon: String,
        size: ControlButtonSize = .medium,
        color: Color = .blue,
        isDisabled: Bool = false,
        isPulsing: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.isDisabled = isDisabled
        self.isPulsing = isPulsing
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDisabled ? [Color.gray.opacity(0.3)] : [color, color.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.size, height: size.size)
                
                // Pulsing effect for active states
                if isPulsing && !isDisabled {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: size.size * 1.2, height: size.size * 1.2)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.3)
                        .animation(
                            isPulsing ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none,
                            value: isPulsing
                        )
                }
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(isDisabled ? .gray : .white)
            }
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
        .shadow(
            color: isDisabled ? .clear : color.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        ControlButton(icon: "play.fill", size: .small, color: .blue) { }
        ControlButton(icon: "pause.fill", size: .medium, color: .green, isPulsing: true) { }
        ControlButton(icon: "stop.fill", size: .large, color: .red, isDisabled: true) { }
    }
    .padding()
}