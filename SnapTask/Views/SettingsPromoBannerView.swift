import SwiftUI

struct SettingsPromoBannerView: View {
    let isSubscribed: Bool
    let expirationDate: Date?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
            
            HStack(spacing: 14) {
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(
                        Image(systemName: isSubscribed ? "crown.fill" : "crown")
                            .font(.system(size: 22, weight: .semibold))
                    )
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSubscribed ? "premium_plan_active".localized : "upgrade_to_pro".localized)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if isSubscribed, let exp = expirationDate {
                        Text("subscription_expires".localized + " " + exp.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("premium_features".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !isSubscribed {
                    PremiumBadge(size: .small)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}