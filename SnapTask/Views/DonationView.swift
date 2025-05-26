import SwiftUI
import StoreKit

struct DonationView: View {
    @StateObject private var donationService = DonationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingThankYou = false
    @State private var selectedProduct: DonationProduct?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 8) {
                        Text("Support SnapTask")
                            .font(.title.bold())
                        
                        Text("Help us keep improving SnapTask with new features and updates")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                if donationService.isLoading {
                    ProgressView("Loading donation options...")
                        .frame(maxHeight: .infinity)
                } else if donationService.donationProducts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Unable to load donation options")
                            .font(.headline)
                        
                        Text("Please check your internet connection and try again")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task {
                                await donationService.loadProducts()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxHeight: .infinity)
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
                    
                    Spacer()
                    
                    // Thank you message for previous donors
                    if donationService.hasEverDonated {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Thank you for your previous support!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let lastDonation = donationService.lastDonationDate {
                                Text("Last donation: \(lastDonation, style: .date)")
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
            .navigationTitle("Donate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Thank You! ❤️", isPresented: $showingThankYou) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Your donation helps us continue developing SnapTask. We really appreciate your support!")
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
            return ("Small Coffee", "Buy us a coffee ☕️", "cup.and.saucer.fill")
        } else if productId.contains("medium") || productId == "medium" {
            return ("Big Coffee", "Buy us a fancy coffee ☕️✨", "mug.fill")
        } else if productId.contains("large") || productId == "large" {
            return ("Dinner", "Buy us dinner 🍕", "fork.knife")
        } else {
            return ("Support", "Support development", "heart.fill")
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
