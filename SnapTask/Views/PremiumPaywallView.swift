import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isProcessingPurchase = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedPlan: String = "yearly" // Default yearly per incentivare risparmio
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header compatto
                    premiumHeader
                    
                    // Features grid - più compatto
                    premiumFeatures
                    
                    // Subscription Options
                    subscriptionOptions
                    
                    // Purchase Button
                    purchaseButton
                    
                    // Restore purchases button
                    restorePurchasesButton
                    
                    // Development info
                    #if DEBUG
                    developmentInfo
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("upgrade_to_pro".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .disabled(isProcessingPurchase)
            .alert("Abbonamento", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var premiumHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 2) {
                Text("SnapTask Pro")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text("Sblocca tutte le funzionalità premium")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 5)
    }
    
    private var premiumFeatures: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                PremiumFeatureCard(feature: feature)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 8) {
            Text("Scegli il tuo piano")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button(action: {
                    selectedPlan = "yearly"
                    selectedProduct = subscriptionManager.subscriptionProducts.first
                }) {
                    SubscriptionPlanCard(
                        title: "Abbonamento Annuale",
                        price: "€34,99",
                        period: "anno",
                        isPopular: true,
                        isSelected: selectedPlan == "yearly",
                        savings: "Risparmi €12,89 (27%)"
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    selectedPlan = "monthly"
                    selectedProduct = nil
                }) {
                    SubscriptionPlanCard(
                        title: "Abbonamento Mensile",
                        price: "€3,99",
                        period: "mese",
                        isPopular: false,
                        isSelected: selectedPlan == "monthly",
                        savings: nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
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
                    Text(selectedPlan == "yearly" ? "Attiva Piano Annuale" : "Attiva Piano Mensile")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isProcessingPurchase)
    }
    
    private var restorePurchasesButton: some View {
        Button {
            Task {
                await handleRestorePurchases()
            }
        } label: {
            Text("Ripristina Acquisti")
                .font(.caption)
                .foregroundColor(.purple)
        }
        .disabled(isProcessingPurchase)
        .padding(.top, 4)
    }
    
    #if DEBUG
    private var developmentInfo: some View {
        VStack(spacing: 6) {
            Text("🧪 Modalità Sviluppo")
                .font(.caption2.bold())
                .foregroundColor(.orange)
            
            Text("Gli acquisti sono simulati in TestFlight.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    #endif
    
    private func handlePurchase() async {
        isProcessingPurchase = true
        
        if subscriptionManager.usingMockProducts {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            alertMessage = "Acquisto simulato completato! Piano: \(selectedPlan == "monthly" ? "Mensile" : "Annuale")"
            showingAlert = true
        } else if let product = selectedProduct {
            let success = await subscriptionManager.purchase(product)
            if success {
                alertMessage = "Benvenuto in SnapTask Pro! Tutte le funzionalità sono ora sbloccate."
                showingAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } else {
                alertMessage = "Acquisto non completato. Riprova."
                showingAlert = true
            }
        }
        
        isProcessingPurchase = false
    }
    
    private func handleRestorePurchases() async {
        isProcessingPurchase = true
        await subscriptionManager.restorePurchases()
        
        if subscriptionManager.isSubscribed {
            alertMessage = "Acquisti ripristinati con successo!"
            showingAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } else {
            alertMessage = "Nessun acquisto da ripristinare trovato."
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }
}

struct PremiumFeatureCard: View {
    let feature: PremiumFeature
    
    var body: some View {
        VStack(spacing: 6) {
            // Icona più piccola
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 28, height: 28)
                
                Image(systemName: iconForFeature(feature))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 2) {
                Text(feature.localizedName)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(feature.localizedDescription)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Checkmark più piccolo
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 85) 
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
    
    private func iconForFeature(_ feature: PremiumFeature) -> String {
        switch feature {
        case .unlimitedCategories:
            return "folder.fill"
        case .taskEvaluation:
            return "star.fill"
        case .unlimitedRewards:
            return "gift.fill"
        case .cloudSync:
            return "icloud.fill"
        case .advancedStatistics:
            return "chart.line.uptrend.xyaxis"
        case .customThemes:
            return "paintbrush.fill"
        }
    }
}

struct SubscriptionPlanCard: View {
    let title: String
    let price: String
    let period: String
    let isPopular: Bool
    let isSelected: Bool
    let savings: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Popular badge
            if isPopular {
                HStack {
                    Spacer()
                    Text("Più Popolare")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.bottom, 6)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text("/ \(period)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.green.opacity(0.12))
                            )
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.title3.bold())
                        .foregroundColor(.purple)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    PremiumPaywallView()
}