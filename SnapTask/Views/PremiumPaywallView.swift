import SwiftUI
import StoreKit
import UIKit

struct PremiumPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isProcessingPurchase = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedPlan: String = "yearly"
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @Environment(\.openURL) private var openURL

    // Metriche responsive per iPhone vs iPad
    private var isCompactPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    private var headerIconSize: CGFloat { isCompactPhone ? 44 : 50 }
    private var headerCrownSize: CGFloat { isCompactPhone ? 18 : 20 }
    private var featureCardHeight: CGFloat { isCompactPhone ? 46 : 50 }
    private var lifetimeCardHeight: CGFloat { isCompactPhone ? 104 : 96 }
    private var planCardHeight: CGFloat { isCompactPhone ? 102 : 95 }
    private var purchaseButtonHeight: CGFloat { isCompactPhone ? 46 : 50 }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    premiumFeaturesCompact
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    
                    subscriptionPlansCompact
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    purchaseButton
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    
                    footerActions
                        .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }
                .background(.ultraThinMaterial)
            }
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
        .disabled(isProcessingPurchase)
        .alert("subscription".localized, isPresented: $showingAlert) {
            Button("ok".localized) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                if selectedProduct == nil {
                    switch selectedPlan {
                    case "lifetime": selectedProduct = subscriptionManager.lifetimeProduct
                    case "yearly": selectedProduct = subscriptionManager.yearlyProduct
                    default: selectedProduct = subscriptionManager.monthlyProduct
                    }
                }
                print("🔍 Products loaded in PaywallView:")
                print("   Monthly: \(subscriptionManager.monthlyProduct?.displayPrice ?? "nil")")
                print("   Yearly: \(subscriptionManager.yearlyProduct?.displayPrice ?? "nil")")
                print("   Lifetime: \(subscriptionManager.lifetimeProduct?.displayPrice ?? "nil")")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: headerIconSize, height: headerIconSize)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 3)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: headerCrownSize, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 3) {
                Text("unlock_snaptask_pro".localized)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text("maximize_your_productivity".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Compact Premium Features
    private var premiumFeaturesCompact: some View {
        VStack(spacing: 8) {
            Text("everything_you_get".localized)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                CompactFeatureCard(
                    icon: "folder.fill",
                    title: "unlimited_categories".localized,
                    color: .blue,
                    height: featureCardHeight
                )
                CompactFeatureCard(
                    icon: "star.fill",
                    title: "task_evaluation".localized,
                    color: .yellow,
                    height: featureCardHeight
                )
                CompactFeatureCard(
                    icon: "gift.fill",
                    title: "unlimited_rewards".localized,
                    color: .purple,
                    height: featureCardHeight
                )
                CompactFeatureCard(
                    icon: "icloud.fill",
                    title: "cloud_sync".localized,
                    color: .cyan,
                    height: featureCardHeight
                )
                CompactFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "advanced_statistics".localized,
                    color: .green,
                    height: featureCardHeight
                )
                CompactFeatureCard(
                    icon: "paintbrush.fill",
                    title: "custom_themes".localized,
                    color: .pink,
                    height: featureCardHeight
                )
            }
        }
    }
    
    // MARK: - Compact Subscription Plans
    private var subscriptionPlansCompact: some View {
        VStack(spacing: 8) {
            Text("choose_your_plan".localized)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedPlan = "lifetime"
                        selectedProduct = subscriptionManager.lifetimeProduct
                    }
                }) {
                    CompactSubscriptionCard(
                        title: "lifetime_access".localized,
                        price: subscriptionManager.lifetimeProduct?.displayPrice ?? "---",
                        subtitle: "one_time_no_subscription".localized,
                        badge: "best_value".localized,
                        isSelected: selectedPlan == "lifetime",
                        badgeColor: .orange,
                        isLifetime: true,
                        savingsAmount: nil,
                        cardHeight: lifetimeCardHeight
                    )
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPlan = "yearly"
                            selectedProduct = subscriptionManager.yearlyProduct
                        }
                    }) {
                        CompactSubscriptionCard(
                            title: "yearly".localized,
                            price: subscriptionManager.yearlyProduct?.displayPrice ?? "---",
                            subtitle: String(format: "days_free_then".localized, subscriptionManager.yearlyProduct?.displayPrice ?? "---"),
                            badge: "free_trial".localized,
                            isSelected: selectedPlan == "yearly",
                            badgeColor: .green,
                            isLifetime: false,
                            savingsAmount: subscriptionManager.yearlySavingsAmount,
                            cardHeight: planCardHeight
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPlan = "monthly"
                            selectedProduct = subscriptionManager.monthlyProduct
                        }
                    }) {
                        CompactSubscriptionCard(
                            title: "monthly".localized,
                            price: subscriptionManager.monthlyProduct?.displayPrice ?? "---",
                            subtitle: "total_flexibility".localized,
                            badge: nil,
                            isSelected: selectedPlan == "monthly",
                            badgeColor: .purple,
                            isLifetime: false,
                            savingsAmount: nil,
                            cardHeight: planCardHeight
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            HStack {
                if isProcessingPurchase {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    VStack(spacing: 2) {
                        if selectedPlan == "yearly" {
                            Text("start_free_trial".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text(String(format: "days_free_then".localized, selectedProduct?.displayPrice ?? "---"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else if selectedPlan == "lifetime" {
                            Text("purchase_lifetime_access".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("one_time_payment".localized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("subscribe_monthly_plan".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: purchaseButtonHeight)
            .background(
                LinearGradient(
                    colors: selectedPlan == "lifetime" ? [.orange, .red] : [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .animation(.easeInOut(duration: 0.3), value: selectedPlan)
            )
            .cornerRadius(14)
            .shadow(color: (selectedPlan == "lifetime" ? Color.orange : Color.purple).opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .disabled(isProcessingPurchase || selectedProduct == nil)
    }
    
    // MARK: - Footer Actions
    private var footerActions: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Button {
                    Task { await handleRestorePurchases() }
                } label: {
                    Text("restore_purchases".localized)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .disabled(isProcessingPurchase)
                
                Button { subscriptionManager.manageSubscriptions() } label: {
                    Text("manage_subscriptions".localized)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            
            HStack(spacing: 16) {
                Button("terms_of_service".localized) { showingTerms = true }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                Button("privacy_policy".localized) { showingPrivacy = true }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                Button("EULA") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingTerms) { TermsOfServiceView() }
        .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
    }

    // MARK: - Actions
    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        
        isProcessingPurchase = true
        
        let success = await subscriptionManager.purchase(product)
        
        if success {
            if selectedPlan == "yearly" && !subscriptionManager.hasUsedTrial {
                subscriptionManager.markTrialAsUsed()
            }
            
            if selectedPlan == "lifetime" {
                alertMessage = "welcome_snaptask_pro_lifetime".localized
            } else {
                alertMessage = (selectedPlan == "yearly" && subscriptionManager.subscriptionStatus.isInTrial) ? 
                    "free_trial_activated".localized :
                    "welcome_snaptask_pro".localized
            }
            
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            alertMessage = "purchase_not_completed".localized
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }
    
    private func handleRestorePurchases() async {
        isProcessingPurchase = true
        
        let success = await subscriptionManager.restorePurchases()
        
        if success {
            alertMessage = "purchases_restored_successfully".localized
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } else {
            alertMessage = "no_purchases_to_restore".localized
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }

    private func hasIntroOffer(for product: Product?) -> Bool {
        guard let p = product, let sub = p.subscription else { return false }
        return sub.introductoryOffer != nil
    }
}

// MARK: - Compact Feature Card
struct CompactFeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Compact Subscription Card
struct CompactSubscriptionCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let badgeColor: Color
    let isLifetime: Bool
    let savingsAmount: String?
    let cardHeight: CGFloat
    
    // Calcolo del risparmio
    private var savingsText: String? {
        guard let savingsAmount = savingsAmount else { return nil }
        return String(format: "savings_amount".localized, savingsAmount)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Badge
            VStack {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(badgeColor))
                } else {
                    Text(" ")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .opacity(0)
                }
            }
            .frame(height: 20)
            
            Spacer(minLength: 4)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(price)
                    .font(.title3.bold())
                    .foregroundColor(isLifetime ? .orange : .purple)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.9)
            }
            
            Spacer(minLength: 4)
            
            // Savings text (collapse space when absent)
            VStack {
                if let savingsText = savingsText {
                    Text(savingsText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(height: savingsText == nil ? 0 : 20)
            .padding(.bottom, savingsText == nil ? 0 : 4)
            
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ?
                        LinearGradient(
                            colors: isLifetime ? [.orange, .red] : [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? (isLifetime ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15)) : Color.black.opacity(0.05),
            radius: isSelected ? 8 : 3,
            x: 0,
            y: isSelected ? 4 : 2
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Legal Views 
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mdText: String = ""
    
    private func reload() {
        let lang = LanguageManager.shared.actualLanguageCode
        mdText = LegalMarkdownLoader.load(.terms, languageCode: lang) ?? LegalTexts.termsOfServiceEN
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("terms_of_service".localized)
                        .font(.title.bold())
                        .padding(.bottom, 4)
                    
                    MarkdownView(text: mdText.isEmpty ? LegalTexts.termsOfServiceEN : mdText)
                        .tint(.blue)
                }
                .padding()
            }
            .onAppear { reload() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
                reload()
            }
            .navigationTitle("terms_of_service".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mdText: String = ""
    
    private func reload() {
        let lang = LanguageManager.shared.actualLanguageCode
        mdText = LegalMarkdownLoader.load(.privacy, languageCode: lang) ?? LegalTexts.privacyPolicyEN
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("privacy_policy".localized)
                        .font(.title.bold())
                        .padding(.bottom, 4)
                    
                    MarkdownView(text: mdText.isEmpty ? LegalTexts.privacyPolicyEN : mdText)
                        .tint(.blue)
                }
                .padding()
            }
            .onAppear { reload() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
                reload()
            }
            .navigationTitle("privacy_policy".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PremiumPaywallView()
}