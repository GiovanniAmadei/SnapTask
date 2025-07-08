import SwiftUI

struct ThemeSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPremiumPaywall = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Current theme section
                Section {
                    HStack {
                        ThemePreviewCard(theme: themeManager.currentTheme, isSelected: true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(themeManager.currentTheme.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("current_theme".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if themeManager.currentTheme.isPremium {
                            PremiumBadge(size: .small)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("current_theme".localized)
                }
                
                // Free themes section
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(themeManager.freeThemes) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme.id == theme.id,
                                canUse: true
                            ) {
                                themeManager.setTheme(theme)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("free_themes".localized)
                }
                
                // Premium themes section
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(themeManager.premiumThemes) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: themeManager.currentTheme.id == theme.id,
                                canUse: themeManager.canUseTheme(theme)
                            ) {
                                if themeManager.canUseTheme(theme) {
                                    themeManager.setTheme(theme)
                                } else {
                                    showingPremiumPaywall = true
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    HStack {
                        Text("premium_themes".localized)
                        
                        Spacer()
                        
                        if !subscriptionManager.isSubscribed {
                            PremiumBadge(size: .small)
                        }
                    }
                } footer: {
                    if !subscriptionManager.isSubscribed {
                        Text("unlock_premium_themes".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("themes".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPremiumPaywall) {
                PremiumPaywallView()
            }
        }
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let canUse: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ThemePreviewCard(theme: theme, isSelected: isSelected)
                
                VStack(spacing: 4) {
                    Text(theme.name)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if theme.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            
                            Text("premium".localized)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .opacity(canUse ? 1.0 : 0.6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 2)
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
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.primaryColor)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(theme.secondaryColor)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 12, height: 12)
            }
            
            // Mock UI elements
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.surfaceColor)
                    .frame(height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
                    )
                
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.textColor.opacity(0.8))
                        .frame(width: 30, height: 8)
                    
                    Spacer()
                    
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.surfaceColor, lineWidth: 1)
        )
        .frame(height: 80)
        .shadow(color: theme.textColor.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ThemeSelectionView()
}