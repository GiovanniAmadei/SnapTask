import SwiftUI

// Theme application extensions with full styling support
extension View {
    /// Apply theme-aware background color
    func themedBackground() -> some View {
        self.background(ThemeManager.shared.currentTheme.backgroundColor)
    }
    
    /// Apply theme-aware surface color
    func themedSurface() -> some View {
        self.background(ThemeManager.shared.currentTheme.surfaceColor)
    }
    
    /// Apply theme-aware primary text color
    func themedPrimaryText() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.textColor)
    }
    
    /// Apply theme-aware secondary text color  
    func themedSecondaryText() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.secondaryTextColor)
    }
    
    /// Apply theme-aware accent color
    func themedAccent() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.accentColor)
    }
    
    /// Apply theme-aware primary color
    func themedPrimary() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.primaryColor)
    }
    
    /// Apply theme-aware secondary color
    func themedSecondary() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.secondaryColor)
    }
    
    /// Apply smart button text color (contrast with primary button background)
    func themedButtonText() -> some View {
        self.foregroundColor(ThemeManager.shared.currentTheme.buttonTextColor)
    }
    
    /// Apply themed card styling with enhanced shadow and border
    func themedCard() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeManager.shared.currentTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeManager.shared.currentTheme.borderColor, lineWidth: 1)
                )
                .shadow(
                    color: ThemeManager.shared.currentTheme.shadowColor,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
    
    /// Apply themed gradient background
    func themedGradient() -> some View {
        self.background(ThemeManager.shared.currentTheme.gradient)
    }
    
    /// Apply themed button styling with smart text color
    func themedButton() -> some View {
        self.background(ThemeManager.shared.currentTheme.primaryColor)
            .foregroundColor(ThemeManager.shared.currentTheme.buttonTextColor)
            .cornerRadius(8)
    }
    
    /// Apply themed border
    func themedBorder(_ width: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ThemeManager.shared.currentTheme.borderColor, lineWidth: width)
        )
    }
}

// MARK: - Themed Segmented Picker (selection buttons in line with app theme)
struct ThemedSegmentedPicker<SelectionValue: Hashable, Label: View>: View {
    @Binding var selection: SelectionValue
    let options: [SelectionValue]
    @ViewBuilder let label: (SelectionValue) -> Label
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { opt in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = opt }
                } label: {
                    label(opt)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selection == opt ? theme.primaryColor : theme.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selection == opt ? theme.primaryColor.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selection == opt ? theme.primaryColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.borderColor.opacity(0.5), lineWidth: 1)
        )
    }
}