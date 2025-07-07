import SwiftUI

struct PremiumBadge: View {
    let size: PremiumBadgeSize
    
    enum PremiumBadgeSize {
        case small
        case medium
        case large
        
        var font: Font {
            switch self {
            case .small: return .caption2.weight(.bold)
            case .medium: return .caption.weight(.bold)
            case .large: return .subheadline.weight(.bold)
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .medium: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .large: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var height: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
    }
    
    var body: some View {
        Text("PRO")
            .font(size.font)
            .foregroundColor(.white)
            .padding(size.padding)
            .frame(height: size.height)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(size.cornerRadius)
    }
}

#Preview {
    VStack(spacing: 20) {
        PremiumBadge(size: .small)
        PremiumBadge(size: .medium)
        PremiumBadge(size: .large)
    }
}