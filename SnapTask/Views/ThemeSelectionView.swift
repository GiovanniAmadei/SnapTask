import SwiftUI

struct ThemeSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPremiumPaywall = false
    @State private var justSelectedThemeId: String?
    @State private var showingDarkModeWarning = false
    @State private var pendingTheme: Theme?
    @Environment(\.theme) private var theme
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Current theme section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("current_theme".localized)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .themedPrimaryText()
                        Spacer()
                    }
                    
                    CurrentThemeCard(theme: themeManager.currentTheme)
                }
                
                // Free themes section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("free_themes".localized)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .themedPrimaryText()
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(themeManager.freeThemes) { themeOption in
                            ThemeCard(
                                theme: themeOption,
                                isSelected: themeManager.currentTheme.id == themeOption.id,
                                justSelected: justSelectedThemeId == themeOption.id,
                                canUse: true
                            ) {
                                selectTheme(themeOption)
                            }
                        }
                    }
                }
                
                // Premium themes section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("premium_themes".localized)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .themedPrimaryText()
                        
                        Spacer()
                        
                        if !subscriptionManager.isSubscribed {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(themeManager.premiumThemes) { themeOption in
                            ThemeCard(
                                theme: themeOption,
                                isSelected: themeManager.currentTheme.id == themeOption.id,
                                justSelected: justSelectedThemeId == themeOption.id,
                                canUse: themeManager.canUseTheme(themeOption)
                            ) {
                                selectTheme(themeOption)
                            }
                        }
                    }
                    
                    if !subscriptionManager.isSubscribed {
                        Text("unlock_premium_themes".localized)
                            .font(.system(.caption, design: .rounded))
                            .themedSecondaryText()
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .themedBackground()
        .navigationTitle("themes".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumPaywallView()
        }
        .alert("dark_mode_theme_warning_title".localized, isPresented: $showingDarkModeWarning) {
            Button("keep_dark_mode".localized) {
                // Disable dark mode and apply the theme
                isDarkMode = false
                if let theme = pendingTheme {
                    applyTheme(theme)
                }
                pendingTheme = nil
            }
            Button("keep_simple_theme".localized, role: .cancel) {
                // Keep current theme and don't change anything
                pendingTheme = nil
            }
        } message: {
            Text("theme_dark_mode_warning_message".localized)
        }
    }
    
    private func selectTheme(_ selectedTheme: Theme) {
        if themeManager.canUseTheme(selectedTheme) {
            // Don't do anything if already selected
            guard themeManager.currentTheme.id != selectedTheme.id else { return }
            
            // Check if we're trying to select a theme with custom colors while dark mode is active
            if selectedTheme.overridesSystemColors && isDarkMode {
                pendingTheme = selectedTheme
                showingDarkModeWarning = true
                return
            }
            
            applyTheme(selectedTheme)
        } else {
            showingPremiumPaywall = true
        }
    }
    
    private func applyTheme(_ selectedTheme: Theme) {
        // Store the selected theme ID for visual feedback
        justSelectedThemeId = selectedTheme.id
        
        // Apply theme with animation and haptic feedback
        withAnimation(.easeInOut(duration: 0.4)) {
            themeManager.setTheme(selectedTheme)
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Clear the "just selected" state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            justSelectedThemeId = nil
        }
    }
}

struct CurrentThemeCard: View {
    let theme: Theme
    @Environment(\.theme) private var currentTheme
    
    var body: some View {
        HStack(spacing: 16) {
            ThemePreviewCard(theme: theme, isSelected: true)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .themedPrimaryText()
                
                Text("current_theme".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .themedSecondaryText()
                
                if theme.isPremium {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text("premium".localized)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentTheme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(currentTheme.accentColor.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let justSelected: Bool
    let canUse: Bool
    let action: () -> Void
    @Environment(\.theme) private var currentTheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ThemePreviewCard(theme: theme, isSelected: isSelected)
                
                VStack(spacing: 6) {
                    Text(theme.name)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .themedPrimaryText()
                        .lineLimit(1)
                    
                    if theme.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            
                            Text("premium".localized)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.purple)
                        }
                    }
                    
                    if theme.overridesSystemColors {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("custom_colors".localized)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentTheme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? currentTheme.accentColor : currentTheme.borderColor.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .opacity(canUse ? 1.0 : 0.6)
            .scaleEffect(justSelected ? 1.08 : (isSelected ? 1.02 : 1.0))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: justSelected)
            .overlay(
                // Success checkmark when just selected
                Group {
                    if justSelected {
                        Circle()
                            .fill(currentTheme.accentColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: justSelected),
                alignment: .topTrailing
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ThemePreviewCard: View {
    let theme: Theme
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Color palette preview
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.primaryColor)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .fill(theme.secondaryColor)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 14, height: 14)
            }
            
            // Mock UI elements
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.surfaceColor)
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.borderColor.opacity(0.3), lineWidth: 1)
                    )
                
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.textColor.opacity(0.8))
                        .frame(width: 36, height: 10)
                    
                    Spacer()
                    
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(16)
        .background(theme.backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.borderColor.opacity(0.2), lineWidth: 1)
        )
        .frame(height: 90)
    }
}

#Preview {
    NavigationView {
        ThemeSelectionView()
    }
}