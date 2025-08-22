import SwiftUI

struct UpdateBannerView: View {
    @State private var showBanner = false
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let currentVersion = "1.0"
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showBanner {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        let cardMaxWidth = min(geo.size.width - 40, 600)
                        let cardMaxHeight = min(geo.size.height * 0.85, 700)
                        let featuresMaxHeight = min(geo.size.height * 0.45, 420)
                        
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "party.popper.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    Text("version_1_0_launch".localized + " 🚀")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.9)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer(minLength: 8)
                                    
                                    Button {
                                        dismissBanner()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text("official_launch".localized)
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // REMOVE: Long marketing description to keep the message concise
                            
                            ScrollView {
                                VStack(spacing: 12) {
                                    UpdateFeatureRow(
                                        icon: "target",
                                        iconColor: .blue,
                                        title: "smart_goal_system".localized,
                                        description: "weekly_monthly_yearly_goals_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "camera.fill",
                                        iconColor: .green,
                                        title: "rich_task_media".localized,
                                        description: "photos_audio_tasks_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "bell.badge.fill",
                                        iconColor: .red,
                                        title: "smart_notifications".localized,
                                        description: "task_notifications_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "location.fill",
                                        iconColor: .purple,
                                        title: "location_based_tasks".localized,
                                        description: "location_tasks_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "paintbrush.fill",
                                        iconColor: .orange,
                                        title: "custom_themes".localized,
                                        description: "custom_themes_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "globe",
                                        iconColor: .indigo,
                                        title: "multi_language_support".localized,
                                        description: "multi_language_desc".localized
                                    )
                                    
                                    UpdateFeatureRow(
                                        icon: "wrench.and.screwdriver.fill",
                                        iconColor: .gray,
                                        title: "major_improvements".localized,
                                        description: "major_bug_fixes_desc".localized
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: featuresMaxHeight)
                            
                            Button {
                                dismissBanner()
                            } label: {
                                Text("lets_get_started".localized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .red, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(
                                        color: .orange.opacity(0.3),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: cardMaxWidth)
                        .frame(maxHeight: cardMaxHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(
                                    color: .black.opacity(0.15),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 0)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom))
                    ))
                    .zIndex(999)
                }
            }
            .onAppear {
                showBannerWithDelay()
            }
        }
    }
    
    private func dismissBanner() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showBanner = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            UpdateBannerManager.markBannerAsShown()
        }
    }
    
    func showBannerWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showBanner = true
            }
        }
    }
}

struct UpdateFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

struct UpdateBannerManager {
    private static let currentVersion = "1.0"
    private static let lastShownVersionKey = "lastShownUpdateVersion"
    private static let bannerShownKey = "update_banner_1_0_shown"
    
    static func shouldShowUpdateBanner() -> Bool {
        let bannerShown = UserDefaults.standard.bool(forKey: bannerShownKey)
        
        if !bannerShown {
            return true
        }
        
        return false
    }
    
    static func markBannerAsShown() {
        UserDefaults.standard.set(true, forKey: bannerShownKey)
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
    }
    
    static func resetBannerForTesting() {
        UserDefaults.standard.removeObject(forKey: bannerShownKey)
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
    }
    
    static func getCurrentVersion() -> String {
        return currentVersion
    }
    
    static func getLastShownVersion() -> String? {
        return UserDefaults.standard.string(forKey: lastShownVersionKey)
    }
}