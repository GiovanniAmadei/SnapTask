import SwiftUI

struct PremiumStatusView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    private var expirationText: String {
        if let date = subscriptionManager.subscriptionExpirationDate {
            if date == .distantFuture {
                return "lifetime_access".localized
            } else {
                return String(
                    format: "subscription_expires_on".localized,
                    date.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
        return subscriptionManager.subscriptionStatus.displayStatus
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    headerCard
                        .listRowBackground(theme.surfaceColor)
                    
                    benefitsCard
                        .listRowBackground(theme.surfaceColor)
                    
                    actionsSection
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle("snaptask_pro".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.9), .pink.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "crown.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("premium_plan_active".localized)
                        .font(.headline)
                        .themedPrimaryText()
                    Text(expirationText)
                        .font(.subheadline)
                        .themedSecondaryText()
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
        )
    }
    
    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("everything_you_get".localized)
                .font(.headline)
                .themedPrimaryText()
            
            VStack(spacing: 10) {
                ForEach(PremiumFeature.allCases, id: \.self) { feature in
                    HStack(alignment: .center, spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(feature.color.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: feature.iconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(feature.color)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.localizedName)
                                .font(.subheadline.weight(.semibold))
                                .themedPrimaryText()
                            Text(feature.localizedDescription)
                                .font(.caption)
                                .themedSecondaryText()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        VStack {
                            if subscriptionManager.hasAccess(to: feature) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20, weight: .semibold))
                            } else {
                                Image(systemName: "xmark.seal")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18, weight: .regular))
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .padding(.vertical, 8)
                    
                    if feature != PremiumFeature.allCases.last {
                        Divider()
                            .background(theme.borderColor.opacity(0.2))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceColor)
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                subscriptionManager.manageSubscriptions()
            } label: {
                HStack {
                    Spacer()
                    Text("manage_subscriptions".localized)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
            
            Button {
                Task { _ = await subscriptionManager.restorePurchases() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("restore_purchases".localized)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .fill(theme.surfaceColor)
                )
            }
            
            HStack(spacing: 16) {
                Button("terms_of_service".localized) {
                    showingTerms = true
                }
                Button("privacy_policy".localized) {
                    showingPrivacy = true
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

extension PremiumFeature {
    var iconName: String {
        switch self {
        case .unlimitedCategories: return "folder.fill"
        case .taskEvaluation: return "star.fill"
        case .unlimitedRewards: return "gift.fill"
        case .cloudSync: return "icloud.fill"
        case .advancedStatistics: return "chart.line.uptrend.xyaxis"
        case .customThemes: return "paintbrush.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unlimitedCategories: return .blue
        case .taskEvaluation: return .yellow
        case .unlimitedRewards: return .purple
        case .cloudSync: return .cyan
        case .advancedStatistics: return .green
        case .customThemes: return .pink
        }
    }
}

#Preview {
    PremiumStatusView()
}