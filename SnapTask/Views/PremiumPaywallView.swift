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
            ScrollView {
                VStack(spacing: 20) {
                    // Premium Header
                    premiumHeader
                    
                    // Features Grid
                    premiumFeatures
                    
                    // Subscription Options
                    subscriptionOptions
                    
                    // Purchase Button
                    purchaseButton
                    
                    // Alternative actions
                    alternativeActions
                    
                    // Legal links
                    legalLinks
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("SnapTask Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .disabled(isProcessingPurchase)
        .alert("Abbonamento", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var premiumHeader: some View {
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
                    .frame(width: 60, height: 60)
                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 4)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text("Sblocca SnapTask Pro")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Massimizza la tua produttività")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 10)
    }
    
    private var premiumFeatures: some View {
        VStack(spacing: 12) {
            Text("Tutto quello che ottieni")
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(PremiumFeature.allCases, id: \.self) { feature in
                    PremiumFeatureCard(feature: feature)
                }
            }
        }
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            Text("Scegli il tuo piano")
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 10) {
                // Lifetime Option - Most attractive
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedPlan = "lifetime"
                        selectedProduct = subscriptionManager.lifetimeProduct
                    }
                }) {
                    SubscriptionPlanCard(
                        title: "Accesso a Vita",
                        price: subscriptionManager.lifetimeProduct?.displayPrice ?? "€49,99",
                        period: "una tantum",
                        isPopular: true,
                        isSelected: selectedPlan == "lifetime",
                        savings: "Nessun abbonamento",
                        pricePerMonth: "€0 al mese dopo l'acquisto",
                        hasFreeTrial: false,
                        trialDays: 0,
                        isLifetime: true
                    )
                }
                .buttonStyle(.plain)
                
                // Yearly Plan with 3-day trial
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedPlan = "yearly"
                        selectedProduct = subscriptionManager.yearlyProduct
                    }
                }) {
                    SubscriptionPlanCard(
                        title: "Piano Annuale",
                        price: subscriptionManager.yearlyProduct?.displayPrice ?? "€24,99",
                        period: "anno",
                        isPopular: false,
                        isSelected: selectedPlan == "yearly",
                        savings: "Risparmi \(subscriptionManager.yearlySavingsAmount) (\(subscriptionManager.yearlySavingsPercentage)%)",
                        pricePerMonth: "Solo €2,08 al mese",
                        hasFreeTrial: !subscriptionManager.hasUsedTrial,
                        trialDays: 3,
                        isLifetime: false
                    )
                }
                .buttonStyle(.plain)
                
                // Monthly Plan
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedPlan = "monthly"
                        selectedProduct = subscriptionManager.monthlyProduct
                    }
                }) {
                    SubscriptionPlanCard(
                        title: "Piano Mensile",
                        price: subscriptionManager.monthlyProduct?.displayPrice ?? "€3,99",
                        period: "mese",
                        isPopular: false,
                        isSelected: selectedPlan == "monthly",
                        savings: nil,
                        pricePerMonth: "Massima flessibilità",
                        hasFreeTrial: false,
                        trialDays: 0,
                        isLifetime: false
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
                    VStack(spacing: 2) {
                        if selectedPlan == "yearly" && !subscriptionManager.hasUsedTrial {
                            Text("Inizia Prova Gratuita")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("3 giorni gratis, poi \(selectedProduct?.displayPrice ?? "€24,99")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else if selectedPlan == "lifetime" {
                            Text("Acquista Accesso a Vita")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                            
                            Text("Pagamento unico - Nessun abbonamento")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("Sottoscrivi \(selectedPlan == "yearly" ? "Piano Annuale" : "Piano Mensile")")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: selectedPlan == "lifetime" ? [.orange, .red] : [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .animation(.easeInOut(duration: 0.3), value: selectedPlan)
            )
            .cornerRadius(16)
            .shadow(color: (selectedPlan == "lifetime" ? Color.orange : Color.purple).opacity(0.3), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.3), value: selectedPlan)
        }
        .disabled(isProcessingPurchase || selectedProduct == nil)
    }
    
    private var alternativeActions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await handleRestorePurchases()
                }
            } label: {
                Text("Ripristina Acquisti")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.purple)
            }
            .disabled(isProcessingPurchase)
            
            Button {
                subscriptionManager.manageSubscriptions()
            } label: {
                Text("Gestisci Abbonamenti")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.purple)
            }
        }
    }
    
    private var legalLinks: some View {
        HStack(spacing: 20) {
            Button("Termini di Servizio") {
                showingTerms = true
            }
            
            Button("Privacy Policy") {
                showingPrivacy = true
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
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
                alertMessage = "Benvenuto in SnapTask Pro! Hai accesso completo a tutte le funzionalità per sempre."
            } else {
                alertMessage = (selectedPlan == "yearly" && subscriptionManager.subscriptionStatus.isInTrial) ? 
                    "Prova gratuita di 3 giorni attivata! Esplora tutte le funzionalità Pro." :
                    "Benvenuto in SnapTask Pro! Tutte le funzionalità sono ora sbloccate."
            }
            
            showingAlert = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            alertMessage = "Acquisto non completato. Riprova o contatta il supporto."
            showingAlert = true
        }
        
        isProcessingPurchase = false
    }
    
    private func handleRestorePurchases() async {
        isProcessingPurchase = true
        
        let success = await subscriptionManager.restorePurchases()
        
        if success {
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

// MARK: - Supporting Views

struct PremiumFeatureCard: View {
    let feature: PremiumFeature
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.15), .pink.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForFeature(feature))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            VStack(spacing: 4) {
                Text(feature.localizedName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(feature.localizedDescription)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    let pricePerMonth: String?
    let hasFreeTrial: Bool
    let trialDays: Int
    let isLifetime: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Popular or Lifetime badge
            if isPopular {
                HStack {
                    Spacer()
                    Text(isLifetime ? "Migliore Valore" : "Più Popolare")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: isLifetime ? [.orange, .red] : [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
            // Free trial badge (only for yearly plan)
            if hasFreeTrial && trialDays > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Prova Gratuita \(trialDays) Giorni")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if let pricePerMonth = pricePerMonth {
                        Text(pricePerMonth)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if isLifetime {
                        Text("Pagamento unico")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Fatturazione mensile")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(.caption.weight(.medium))
                            .foregroundColor(isLifetime ? Color.orange : Color.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill((isLifetime ? Color.orange : Color.green).opacity(0.15))
                            )
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.title2.bold())
                        .foregroundColor(isLifetime ? Color.orange : Color.purple)
                    
                    if !isLifetime {
                        Text("/ \(period)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                )
                .shadow(
                    color: isSelected ? 
                        (isLifetime ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15)) : 
                        Color.black.opacity(0.05), 
                    radius: isSelected ? 12 : 4, 
                    x: 0, 
                    y: isSelected ? 6 : 2
                )
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: isSelected)
    }
}

// MARK: - Legal Views

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Termini di Servizio")
                        .font(.title.bold())
                    
                    Text("""
                    Benvenuto in SnapTask Pro. Utilizzando i nostri servizi, accetti i seguenti termini:
                    
                    1. **Abbonamento**: L'abbonamento a SnapTask Pro è ricorrente e si rinnova automaticamente.
                    
                    2. **Prova Gratuita**: La prova gratuita di 3 giorni è disponibile per i nuovi utenti.
                    
                    3. **Cancellazione**: Puoi cancellare l'abbonamento in qualsiasi momento dalle impostazioni del tuo account Apple.
                    
                    4. **Rimborsi**: I rimborsi sono gestiti secondo le politiche di Apple App Store.
                    
                    5. **Modifiche**: Ci riserviamo il diritto di modificare questi termini con preavviso.
                    """)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Termini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
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
                    Text("Privacy Policy")
                        .font(.title.bold())
                    
                    Text("""
                    La tua privacy è importante per noi. Questa policy spiega come gestiamo i tuoi dati:
                    
                    1. **Dati Raccolti**: Raccogliamo solo i dati necessari per fornire il servizio.
                    
                    2. **Utilizzo**: I dati sono utilizzati per migliorare l'esperienza dell'app e fornire supporto.
                    
                    3. **Condivisione**: Non condividiamo i tuoi dati personali con terze parti.
                    
                    4. **Sicurezza**: Utilizziamo crittografia e misure di sicurezza per proteggere i tuoi dati.
                    
                    5. **Diritti**: Hai il diritto di accedere, modificare o eliminare i tuoi dati.
                    """)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
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