import SwiftUI
import StoreKit

struct DonationView: View {
    @StateObject private var donationService = DonationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingThankYou = false
    @State private var selectedProduct: DonationProduct?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 6) {
                            Text("Supporta SnapTask Pro")
                                .font(.title3.bold())
                            
                            Text("Aiutami a continuare lo sviluppo con nuove funzionalità")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 4)
                    
                    if donationService.usingMockProducts {
                        VStack(spacing: 16) {
                            // Beta notice with better formatting
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Modalità Beta")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.blue)
                                }
                                
                                Text("Siamo ancora in TestFlight, quindi le donazioni in-app sono solo simulate.")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Dopo il rilascio sull'App Store funzioneranno normalmente.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(14)
                            
                            VStack(spacing: 12) {
                                Text("💳 Alternativa PayPal")
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                
                                Text("Puoi supportarmi subito tramite PayPal:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    if let url = URL(string: "https://paypal.me/ampe") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "creditcard.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Dona con PayPal")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text("paypal.me/ampe")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("Si aprirà PayPal nel browser")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if donationService.isLoading {
                        ProgressView("Caricamento opzioni donazione...")
                            .padding(.vertical, 40)
                    } else if donationService.donationProducts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("Impossibile caricare le opzioni di donazione")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("Controlla la connessione internet e riprova")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Riprova") {
                                Task {
                                    await donationService.loadProducts()
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Divider()
                                .padding(.vertical, 12)
                            
                            VStack(spacing: 12) {
                                Text("Alternativa PayPal")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Se le donazioni in-app non funzionano, puoi supportarmi direttamente:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    if let url = URL(string: "https://paypal.me/ampe") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "creditcard.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Dona con PayPal")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text("paypal.me/ampe")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Donation options
                        VStack(spacing: 12) {
                            ForEach(donationService.donationProducts, id: \.id) { product in
                                DonationCard(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id
                                ) {
                                    selectedProduct = product
                                    Task {
                                        let success = await donationService.purchase(product)
                                        if success {
                                            showingThankYou = true
                                        }
                                        selectedProduct = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Divider()
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                Text("Preferisci PayPal?")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    if let url = URL(string: "https://paypal.me/ampe") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "creditcard")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Dona tramite PayPal")
                                            .font(.body.weight(.medium))
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text("paypal.me/ampe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        VStack(spacing: 8) {
                            Text("💝 Le tue donazioni mi aiutano a:")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("•")
                                    Text("Sviluppare nuove funzionalità")
                                }
                                HStack {
                                    Text("•")
                                    Text("Mantenere i server per la sincronizzazione")
                                }
                                HStack {
                                    Text("•")
                                    Text("Continuare gli aggiornamenti gratuiti")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Thank you message for previous donors
                        if donationService.hasEverDonated {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Grazie per il tuo supporto precedente!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let lastDonation = donationService.lastDonationDate {
                                    Text("Ultima donazione: \(lastDonation, style: .date)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                .navigationTitle("Donazioni")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Chiudi") {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .alert("Grazie di cuore! ❤️", isPresented: $showingThankYou) {
            Button("Continua") {
                dismiss()
            }
        } message: {
            Text("La tua donazione mi aiuta a continuare lo sviluppo di SnapTask Pro. Apprezzo davvero il tuo supporto!")
        }
        .task {
            if donationService.donationProducts.isEmpty {
                await donationService.loadProducts()
            }
        }
    }
}

struct DonationCard: View {
    let product: DonationProduct
    let isSelected: Bool
    let onTap: () -> Void
    
    private var donationInfo: (title: String, description: String, icon: String) {
        let productId = product.id
        if productId.contains("small") || productId == "small" {
            return ("Caffè per Giovanni", "Un piccolo caffè ☕️", "cup.and.saucer.fill")
        } else if productId.contains("medium") || productId == "medium" {
            return ("Pizza per Giovanni", "Una pizza per cena 🍕", "mug.fill")
        } else if productId.contains("large") || productId == "large" {
            return ("Cena per Giovanni", "Una bella cena 🍽️", "fork.knife")
        } else {
            return ("Supporto", "Supporta lo sviluppo", "heart.fill")
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: donationInfo.icon)
                    .font(.title2)
                    .foregroundColor(.pink)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(donationInfo.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(donationInfo.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.pink : Color(.systemGray4),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color.pink.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    DonationView()
}
