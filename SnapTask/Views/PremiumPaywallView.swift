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
                Text("Sblocca SnapTask Pro")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text("Massimizza la tua produttività")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Compact Premium Features
    private var premiumFeaturesCompact: some View {
        VStack(spacing: 8) {
            Text("Tutto quello che ottieni")
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
                    title: "Categorie Illimitate",
                    color: .blue
                )
                CompactFeatureCard(
                    icon: "star.fill", 
                    title: "Task Evaluation",
                    color: .yellow
                )
                CompactFeatureCard(
                    icon: "gift.fill",
                    title: "Premi Illimitati",
                    color: .purple
                )
                CompactFeatureCard(
                    icon: "icloud.fill",
                    title: "Sync Cloud",
                    color: .cyan
                )
                CompactFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Statistiche Avanzate",
                    color: .green
                )
                CompactFeatureCard(
                    icon: "paintbrush.fill",
                    title: "Temi Custom",
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - Compact Subscription Plans
    private var subscriptionPlansCompact: some View {
        VStack(spacing: 8) {
            Text("Scegli il tuo piano")
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
                        title: "Accesso a Vita",
                        price: subscriptionManager.lifetimeProduct?.displayPrice ?? "€49,99",
                        subtitle: "Una tantum - Nessun abbonamento",
                        badge: "Migliore Valore",
                        isSelected: selectedPlan == "lifetime",
                        badgeColor: .orange,
                        isLifetime: true
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
                            title: "Annuale",
                            price: subscriptionManager.yearlyProduct?.displayPrice ?? "€24,99",
                            subtitle: subscriptionManager.hasUsedTrial ? "€2,08/mese" : "3 giorni gratis",
                            badge: subscriptionManager.hasUsedTrial ? nil : "Prova Gratis",
                            isSelected: selectedPlan == "yearly",
                            badgeColor: .green,
                            isLifetime: false
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
                            title: "Mensile",
                            price: subscriptionManager.monthlyProduct?.displayPrice ?? "€3,99",
                            subtitle: "Flessibilità totale",
                            badge: nil,
                            isSelected: selectedPlan == "monthly",
                            badgeColor: .purple,
                            isLifetime: false
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
                            
                            Text("Pagamento unico")
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
                    Text("Ripristina Acquisti")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
                .disabled(isProcessingPurchase)
                
                Button {
                    subscriptionManager.manageSubscriptions()
                } label: {
                    Text("Gestisci Abbonamenti")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.purple)
                }
            }
            
            HStack(spacing: 16) {
                Button("Termini di Servizio") {
                    showingTerms = true
                }
                
                Button("Privacy Policy") {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Badge
            if let badge = badge {
                HStack {
                    Spacer()
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(badgeColor)
                        )
                    Spacer()
                }
                .padding(.bottom, 4)
            }
            
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
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLifetime ? 80 : 70)
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