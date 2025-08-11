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
            if subscriptionManager.isSubscribed {
                // Stato Premium attivo: mostra features e informazioni abbonamento
                VStack(spacing: 0) {
                    statusHeaderSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    premiumFeaturesCompact
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    
                    subscriptionInfoCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    statusFooterActions
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    Spacer(minLength: 0)
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
            } else {
                // Paywall per utenti non premium
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
                    color: .blue
                )
                CompactFeatureCard(
                    icon: "star.fill", 
                    title: "task_evaluation".localized,
                    color: .yellow
                )
                CompactFeatureCard(
                    icon: "gift.fill",
                    title: "unlimited_rewards".localized,
                    color: .purple
                )
                CompactFeatureCard(
                    icon: "icloud.fill",
                    title: "cloud_sync".localized,
                    color: .cyan
                )
                CompactFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "advanced_statistics".localized,
                    color: .green
                )
                CompactFeatureCard(
                    icon: "paintbrush.fill",
                    title: "custom_themes".localized,
                    color: .pink
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
                // Lifetime Option - Most attractive
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
                            title: "yearly".localized,
                            price: subscriptionManager.yearlyProduct?.displayPrice ?? "---",
                            subtitle: subscriptionManager.hasUsedTrial ? subscriptionManager.monthlyEquivalentForYearly + "per_month".localized : String(format: "days_free_then".localized, subscriptionManager.yearlyProduct?.displayPrice ?? "---"),
                            badge: subscriptionManager.hasUsedTrial ? nil : "free_trial".localized,
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
                            title: "monthly".localized,
                            price: subscriptionManager.monthlyProduct?.displayPrice ?? "---",
                            subtitle: "total_flexibility".localized,
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
                            Text("start_free_trial".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text(String(format: "days_free_then".localized, selectedProduct?.displayPrice ?? "---"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else if selectedPlan == "lifetime" {
                            Text("purchase_lifetime_access".localized)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("one_time_payment".localized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text(selectedPlan == "yearly" ? "subscribe_yearly_plan".localized : "subscribe_monthly_plan".localized)
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
                    Text("restore_purchases".localized)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
                .disabled(isProcessingPurchase)
                
                Button {
                    subscriptionManager.manageSubscriptions()
                } label: {
                    Text("manage_subscriptions".localized)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
            }
            
            HStack(spacing: 16) {
                Button("terms_of_service".localized) {
                    showingTerms = true
                }
                
                Button("privacy_policy".localized) {
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
    
    private var statusHeaderSection: some View {
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
                Text("premium_plan_active".localized)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                if let expirationDate = subscriptionManager.subscriptionExpirationDate {
                    if expirationDate == .distantFuture {
                        Text("lifetime_access".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("\("subscription_expires".localized) \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
    
    private var subscriptionInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("subscription_active".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let expirationDate = subscriptionManager.subscriptionExpirationDate {
                if expirationDate == .distantFuture {
                    HStack {
                        Image(systemName: "infinity")
                            .foregroundColor(.orange)
                        Text("lifetime_access".localized)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                        Text("\("subscription_expires".localized) \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }
    
    private var statusFooterActions: some View {
        HStack(spacing: 16) {
            Button {
                subscriptionManager.manageSubscriptions()
            } label: {
                Text("manage_subscriptions".localized)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.purple)
            }
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
        return String(format: "savings_amount".localized, savingsAmount)
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
                    Text("terms_of_service_title".localized)
                        .font(.title.bold())
                    
                    Text("terms_content".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("terms".localized)
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("privacy_policy_title".localized)
                        .font(.title.bold())
                    
                    Text("privacy_content".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("privacy".localized)
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