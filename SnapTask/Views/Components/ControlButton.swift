import SwiftUI

struct ControlButton: View {
    let icon: String
    let size: ButtonSize
    let color: Color
    let isDisabled: Bool
    let isPulsing: Bool
    let action: () -> Void
    
    enum ButtonSize {
        case small, medium, large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 50
            case .large: return 70
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
    
    init(
        icon: String,
        size: ButtonSize = .medium,
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
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDisabled ? [.gray.opacity(0.3)] : [color, color.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.dimension, height: size.dimension)
                
                if isPulsing && !isDisabled {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: size.dimension * 1.2, height: size.dimension * 1.2)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .opacity(isPulsing ? 0.7 : 0.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                }
                
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(
                color: isDisabled ? .clear : color.opacity(0.3),
                radius: size == .large ? 8 : 4,
                x: 0,
                y: size == .large ? 4 : 2
            )
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            ControlButton(icon: "play.fill", size: .small, color: .blue) {}
            ControlButton(icon: "pause.fill", size: .medium, color: .green) {}
            ControlButton(icon: "stop.fill", size: .large, color: .red) {}
        }
        
        HStack(spacing: 20) {
            ControlButton(icon: "play.fill", size: .medium, color: .blue, isPulsing: true) {}
            ControlButton(icon: "pause.fill", size: .medium, color: .gray, isDisabled: true) {}
        }
    }
    .padding()
}
