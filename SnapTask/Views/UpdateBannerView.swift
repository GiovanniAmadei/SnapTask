import SwiftUI

struct UpdateBannerView: View {
    @State private var showBanner = false
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let currentVersion = "2.1.0" // Update this with your actual version
    
    var body: some View {
        if showBanner {
            VStack(spacing: 0) {
                // Background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissBanner()
                    }
                
                Spacer()
                
                // Banner content
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("what_s_new".localized)
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
                    
                    // Features list
                    VStack(spacing: 16) {
                        UpdateFeatureRow(
                            icon: "timer",
                            iconColor: .blue,
                            title: "background_timers".localized,
                            description: "background_timers_desc".localized
                        )
                        
                        UpdateFeatureRow(
                            icon: "globe",
                            iconColor: .green,
                            title: "full_localization".localized,
                            description: "full_localization_desc".localized
                        )
                        
                        UpdateFeatureRow(
                            icon: "creditcard",
                            iconColor: .orange,
                            title: "paypal_support".localized,
                            description: "paypal_support_desc".localized
                        )
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
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
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        
                        Button {
                            // Open What's New view
                            dismissBanner()
                            // You can add navigation to WhatsNewView here if needed
                        } label: {
                            Text("view_all_updates".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(
                            color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.ultraThinMaterial, lineWidth: 1)
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
    
    private func dismissBanner() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showBanner = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            UserDefaults.standard.set(currentVersion, forKey: "lastShownUpdateVersion")
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
    private static let currentVersion = "2.1.0" // Update this with your actual version
    private static let lastShownVersionKey = "lastShownUpdateVersion"
    
    static func shouldShowUpdateBanner() -> Bool {
        let lastShownVersion = UserDefaults.standard.string(forKey: lastShownVersionKey)
        
        // Show banner if:
        // 1. Never shown before (first install)
        // 2. Last shown version is different from current version
        if lastShownVersion == nil || lastShownVersion != currentVersion {
            print("🎉 Should show update banner - Last: \(lastShownVersion ?? "none"), Current: \(currentVersion)")
            return true
        }
        
        return false
    }
    
    static func markBannerAsShown() {
        UserDefaults.standard.set(currentVersion, forKey: lastShownVersionKey)
    }
}

#Preview {
    UpdateBannerView(isPresented: .constant(true))
        .onAppear {
            // Preview will show banner immediately
        }
}