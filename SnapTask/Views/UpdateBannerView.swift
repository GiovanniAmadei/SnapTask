import SwiftUI

struct UpdateBannerView: View {
    @State private var showBanner = false
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let currentVersion = "0.3" // Updated version
    
    var body: some View {
        VStack(spacing: 0) {
            if showBanner {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("whats_new".localized)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button {
                                    dismissBanner()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("version_update".localized + " \(currentVersion)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        
                        VStack(spacing: 16) {
                            UpdateFeatureRow(
                                icon: "star.fill",
                                iconColor: .orange,
                                title: "Quality & Difficulty Rating",
                                description: "task_quality_rating_desc".localized
                            )
                            
                            UpdateFeatureRow(
                                icon: "stopwatch",
                                iconColor: .blue,
                                title: "Manual Time Tracking",
                                description: "manual_time_tracking_desc".localized
                            )
                            
                            UpdateFeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                iconColor: .green,
                                title: "Enhanced Statistics",
                                description: "enhanced_statistics_desc".localized
                            )
                            
                            UpdateFeatureRow(
                                icon: "text.bubble",
                                iconColor: .purple,
                                title: "Task Comments",
                                description: "task_comments_desc".localized
                            )
                            
                            UpdateFeatureRow(
                                icon: "trash.slash",
                                iconColor: .red,
                                title: "Complete Data Reset",
                                description: "data_reset_option_desc".localized
                            )
                            
                            UpdateFeatureRow(
                                icon: "wrench.and.screwdriver",
                                iconColor: .gray,
                                title: "General Bug Fixes",
                                description: "general_improvements_desc".localized
                            )
                        }
                        
                        Button {
                            dismissBanner()
                        } label: {
                            Text("got_it".localized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                    .padding(24)
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
                    
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom))
                ))
                .zIndex(999)
            }
        }
        .onAppear {
            showBannerWithDelay()
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
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct UpdateBannerManager {
    private static let currentVersion = "0.3" // Updated version
    private static let lastShownVersionKey = "lastShownUpdateVersion"
    private static let bannerShownKey = "update_banner_0_3_shown"
    
    static func shouldShowUpdateBanner() -> Bool {
        let bannerShown = UserDefaults.standard.bool(forKey: bannerShownKey)
        
        if !bannerShown {
            print("🎉 Should show update banner - Banner not shown yet")
            return true
        }
        
        print("📱 Update banner already shown")
        return false
    }
    
    static func markBannerAsShown() {
        UserDefaults.standard.set(true, forKey: bannerShownKey)
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
        print("✅ Marked update banner as shown")
    }
    
    static func resetBannerForTesting() {
        UserDefaults.standard.removeObject(forKey: bannerShownKey)
        UserDefaults.standard.removeObject(forKey: lastShownVersionKey)
        print("🧪 Reset banner for testing - next app launch will show banner")
    }
    
    static func getCurrentVersion() -> String {
        return currentVersion
    }
    
    static func getLastShownVersion() -> String? {
        return UserDefaults.standard.string(forKey: lastShownVersionKey)
    }
}

#Preview {
    UpdateBannerView(isPresented: .constant(true))
        .onAppear {
            // Preview will show banner immediately
        }
}
