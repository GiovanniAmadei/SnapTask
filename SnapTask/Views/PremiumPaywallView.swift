import SwiftUI
import StoreKit

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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                // Premium Features - Compact Grid
                premiumFeaturesCompact
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                // Subscription Plans
                subscriptionPlansCompact
                    .padding(.horizontal, 20)
                
                // Purchase Button
                purchaseButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                // Footer actions
                footerActions
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                Spacer(minLength: 0)
            }
            .navigationTitle(NSLocalizedString("snaptask_pro", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .disabled(isProcessingPurchase)
        .alert(NSLocalizedString("subscription", comment: ""), isPresented: $showingAlert) {
            Button(NSLocalizedString("ok", comment: "")) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                print("🔍 Products loaded in PaywallView:")
                print("   Monthly: \(subscriptionManager.monthlyProduct?.displayPrice ?? "nil")")
                print("   Yearly: \(subscriptionManager.yearlyProduct?.displayPrice ?? "nil")")
                print("   Lifetime: \(subscriptionManager.lifetimeProduct?.displayPrice ?? "nil")")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 3)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(NSLocalizedString("unlock_snaptask_pro", comment: ""))
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text(NSLocalizedString("maximize_your_productivity", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Compact Premium Features
    private var premiumFeaturesCompact: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("everything_you_get", comment: ""))
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
                    title: NSLocalizedString("unlimited_categories", comment: ""),
                    color: .blue
                )
                CompactFeatureCard(
                    icon: "star.fill", 
                    title: NSLocalizedString("task_evaluation", comment: ""),
                    color: .yellow
                )
                CompactFeatureCard(
                    icon: "gift.fill",
                    title: NSLocalizedString("unlimited_rewards", comment: ""),
                    color: .purple
                )
                CompactFeatureCard(
                    icon: "icloud.fill",
                    title: NSLocalizedString("cloud_sync", comment: ""),
                    color: .cyan
                )
                CompactFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: NSLocalizedString("advanced_statistics", comment: ""),
                    color: .green
                )
                CompactFeatureCard(
                    icon: "paintbrush.fill",
                    title: NSLocalizedString("custom_themes", comment: ""),
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - Compact Subscription Plans
    private var subscriptionPlansCompact: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("choose_your_plan", comment: ""))
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                // Lifetime Option - Most attractive
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedPlan = "lifetime"
                        selectedProduct = subscriptionManager.lifetimeProduct
                    }
                }) {
                    CompactSubscriptionCard(
                        title: NSLocalizedString("lifetime_access", comment: ""),
                        price: subscriptionManager.lifetimeProduct?.displayPrice ?? "---",
                        subtitle: NSLocalizedString("one_time_no_subscription", comment: ""),
                        badge: NSLocalizedString("best_value", comment: ""),
                        isSelected: selectedPlan == "lifetime",
                        badgeColor: .orange,
                        isLifetime: true,
                        savingsAmount: subscriptionManager.lifetimeSavingsAmount
                    )
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 8) {
                    // Yearly Plan
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPlan = "yearly"
                            selectedProduct = subscriptionManager.yearlyProduct
                        }
                    }) {
                        CompactSubscriptionCard(
                            title: NSLocalizedString("yearly", comment: ""),
                            price: subscriptionManager.yearlyProduct?.displayPrice ?? "---",
                            subtitle: subscriptionManager.hasUsedTrial ? subscriptionManager.monthlyEquivalentForYearly + NSLocalizedString("per_month", comment: "") : String(format: NSLocalizedString("days_free_then", comment: ""), subscriptionManager.yearlyProduct?.displayPrice ?? "---"),
                            badge: subscriptionManager.hasUsedTrial ? nil : NSLocalizedString("free_trial", comment: ""),
                            isSelected: selectedPlan == "yearly",
                            badgeColor: .green,
                            isLifetime: false,
                            savingsAmount: subscriptionManager.yearlySavingsAmount
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Monthly Plan
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedPlan = "monthly"
                            selectedProduct = subscriptionManager.monthlyProduct
                        }
                    }) {
                        CompactSubscriptionCard(
                            title: NSLocalizedString("monthly", comment: ""),
                            price: subscriptionManager.monthlyProduct?.displayPrice ?? "---",
                            subtitle: NSLocalizedString("total_flexibility", comment: ""),
                            badge: nil,
                            isSelected: selectedPlan == "monthly",
                            badgeColor: .purple,
                            isLifetime: false,
                            savingsAmount: nil
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
            Task {
                await handlePurchase()
            }
        } label: {
            HStack {
                if isProcessingPurchase {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    VStack(spacing: 2) {
                        if selectedPlan == "yearly" && !subscriptionManager.hasUsedTrial {
                            Text(NSLocalizedString("start_free_trial", comment: ""))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text(String(format: NSLocalizedString("days_free_then", comment: ""), selectedProduct?.displayPrice ?? "---"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else if selectedPlan == "lifetime" {
                            Text(NSLocalizedString("purchase_lifetime_access", comment: ""))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text(NSLocalizedString("one_time_payment", comment: ""))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(selectedPlan == "yearly" ? NSLocalizedString("subscribe_yearly_plan", comment: "") : NSLocalizedString("subscribe_monthly_plan", comment: ""))
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
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
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    Task {
                        await handleRestorePurchases()
                    }
                } label: {
                    Text(NSLocalizedString("restore_purchases", comment: ""))
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
                .disabled(isProcessingPurchase)
                
                Button {
                    subscriptionManager.manageSubscriptions()
                } label: {
                    Text(NSLocalizedString("manage_subscriptions", comment: ""))
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
            }
            
            HStack(spacing: 16) {
                Button(NSLocalizedString("terms_of_service", comment: "")) {
                    showingTerms = true
                }
                
                Button(NSLocalizedString("privacy_policy", comment: "")) {
                    showingPrivacy = true
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
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
                alertMessage = NSLocalizedString("welcome_snaptask_pro_lifetime", comment: "")
            } else {
                alertMessage = (selectedPlan == "yearly" && subscriptionManager.subscriptionStatus.isInTrial) ? 
                    NSLocalizedString("free_trial_activated", comment: "") :
                    NSLocalizedString("welcome_snaptask_pro", comment: "")
            }
            
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            alertMessage = NSLocalizedString("purchase_not_completed", comment: "")
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }
    
    private func handleRestorePurchases() async {
        isProcessingPurchase = true
        
        let success = await subscriptionManager.restorePurchases()
        
        if success {
            alertMessage = NSLocalizedString("purchases_restored_successfully", comment: "")
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } else {
            alertMessage = NSLocalizedString("no_purchases_to_restore", comment: "")
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }
}

// MARK: - Compact Feature Card
struct CompactFeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    
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
        .frame(height: 50)
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
    
    // Calcolo del risparmio
    private var savingsText: String? {
        guard let savingsAmount = savingsAmount else { return nil }
        return String(format: NSLocalizedString("savings_amount", comment: ""), savingsAmount)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Badge - spazio fisso
            VStack {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(badgeColor)
                        )
                } else {
                    // Spazio invisibile della stessa altezza del badge
                    Text(" ")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .opacity(0)
                }
            }
            .frame(height: 20)
            
            Spacer(minLength: 4) // Spazio flessibile dopo il badge
            
            // Contenuto principale
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
            }
            
            Spacer(minLength: 4) // Spazio flessibile prima del savings
            
            // Savings text
            VStack {
                if let savingsText = savingsText {
                    Text(savingsText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    // Spazio invisibile per mantenere l'allineamento
                    Text(" ")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0)
                }
            }
            .frame(height: 16)
            
            Spacer(minLength: 2) // Piccolo spazio finale
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLifetime ? 100 : 95) // Altezze più ragionevoli
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
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
                    color: isSelected ? 
                        (isLifetime ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15)) : 
                        Color.black.opacity(0.05), 
                    radius: isSelected ? 8 : 3, 
                    x: 0, 
                    y: isSelected ? 4 : 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Legal Views 
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("terms_of_service_title", comment: ""))
                        .font(.title.bold())
                    
                    Text(NSLocalizedString("terms_content", comment: ""))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("terms", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("privacy_policy_title", comment: ""))
                        .font(.title.bold())
                    
                    Text(NSLocalizedString("privacy_content", comment: ""))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("privacy", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("close", comment: "")) {
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