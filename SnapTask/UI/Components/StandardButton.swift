import SwiftUI

struct StandardButton: View {
    // Button properties
    var title: String
    var icon: String?
    var action: () -> Void
    
    // Style properties
    var style: ButtonStyle = .primary
    var size: ButtonSize = .medium
    var isEnabled: Bool = true
    
    enum ButtonStyle {
        case primary, secondary, destructive, plain, outline
        
        var foregroundColor: Color {
            switch self {
            case .primary:
                return .white
            case .secondary:
                return .accentColor
            case .destructive:
                return .white
            case .plain:
                return .primary
            case .outline:
                return .accentColor
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return .accentColor
            case .secondary:
                return .accentColor.opacity(0.2)
            case .destructive:
                return .red
            case .plain:
                return .clear
            case .outline:
                return .clear
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outline:
                return .accentColor
            default:
                return nil
            }
        }
    }
    
    enum ButtonSize {
        case small, medium, large
        
        var padding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
        
        var horizontalPadding: CGFloat {
            padding * 1.5
        }
        
        var font: Font {
            switch self {
            case .small: return .subheadline
            case .medium: return .body
            case .large: return .headline
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 20
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(style.foregroundColor)
            .padding(.vertical, size.padding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: style == .plain ? nil : .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(style.backgroundColor)
            )
            .overlay(
                Group {
                    if let borderColor = style.borderColor {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: 1.5)
                    }
                }
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

extension StandardButton {
    // Factory methods for common button types
    static func primary(title: String, icon: String? = nil, action: @escaping () -> Void) -> StandardButton {
        StandardButton(title: title, icon: icon, action: action, style: .primary)
    }
    
    static func secondary(title: String, icon: String? = nil, action: @escaping () -> Void) -> StandardButton {
        StandardButton(title: title, icon: icon, action: action, style: .secondary)
    }
    
    static func destructive(title: String, icon: String? = nil, action: @escaping () -> Void) -> StandardButton {
        StandardButton(title: title, icon: icon, action: action, style: .destructive)
    }
    
    static func outline(title: String, icon: String? = nil, action: @escaping () -> Void) -> StandardButton {
        StandardButton(title: title, icon: icon, action: action, style: .outline)
    }
    
    static func plain(title: String, icon: String? = nil, action: @escaping () -> Void) -> StandardButton {
        StandardButton(title: title, icon: icon, action: action, style: .plain)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StandardButton.primary(title: "Primary Button", icon: "checkmark") { }
        StandardButton.secondary(title: "Secondary Button", icon: "star") { }
        StandardButton.destructive(title: "Delete", icon: "trash") { }
        StandardButton.outline(title: "Outline Button") { }
        StandardButton.plain(title: "Plain Button", icon: "info") { }
        
        StandardButton(title: "Small Primary", action: {}, size: .small)
        StandardButton(title: "Large Secondary", action: {}, style: .secondary, size: .large)
        StandardButton(title: "Disabled Button", action: {}, isEnabled: false)
    }
    .padding()
} 