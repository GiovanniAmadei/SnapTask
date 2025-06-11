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
                    headerSection
                    
                    if donationService.usingMockProducts {
                        betaNoticeSection
                    }
                    
                    donationContentSection
                }
                .navigationTitle("donations".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("close".localized) {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .alert("thanks_so_much".localized, isPresented: $showingThankYou) {
            Button("continue".localized) {
                dismiss()
            }
        } message: {
            Text("donation_helps_development".localized)
        }
        .task {
            if donationService.donationProducts.isEmpty {
                await donationService.loadProducts()
            }
        }
    }
    
    private var headerSection: some View {
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
                Text("support_snaptask_pro".localized)
                    .font(.title3.bold())
                
                Text("help_continue_development".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }
    
    private var betaNoticeSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("beta_mode".localized)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.blue)
                }
                
                Text("testflight_notice".localized)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("after_appstore_release".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(14)
            
            paypalAlternativeCard
        }
        .padding(.horizontal)
    }
    
    private var paypalAlternativeCard: some View {
        VStack(spacing: 12) {
            Text("paypal_alternative".localized)
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text("support_now_paypal".localized)
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
                        Text("donate_with_paypal".localized)
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
            
            Text("opens_paypal_browser".localized)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var donationContentSection: some View {
        if donationService.isLoading {
            ProgressView("loading_donation_options".localized)
                .padding(.vertical, 40)
        } else if donationService.donationProducts.isEmpty {
            emptyDonationProductsSection
        } else {
            donationProductsSection
        }
    }
    
    private var emptyDonationProductsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("cannot_load_donation_options".localized)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("check_internet_retry".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("retry".localized) {
                Task {
                    await donationService.loadProducts()
                }
            }
            .buttonStyle(.bordered)
            
            Divider()
                .padding(.vertical, 12)
            
            fallbackPaypalSection
        }
        .padding(.horizontal)
    }
    
    private var fallbackPaypalSection: some View {
        VStack(spacing: 12) {
            Text("paypal_alternative_title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("if_iap_not_working".localized)
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
                        Text("donate_with_paypal".localized)
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
    
    private var donationProductsSection: some View {
        VStack(spacing: 0) {
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
            
            paypalOptionSection
            donationBenefitsSection
            previousDonorSection
        }
    }
    
    private var paypalOptionSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Text("prefer_paypal".localized)
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
                        
                        Text("donate_via_paypal".localized)
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
    }
    
    private var donationBenefitsSection: some View {
        VStack(spacing: 8) {
            Text("donations_help_me".localized)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("•")
                    Text("develop_new_features".localized)
                }
                HStack {
                    Text("•")
                    Text("maintain_sync_servers".localized)
                }
                HStack {
                    Text("•")
                    Text("continue_free_updates".localized)
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
    }
    
    @ViewBuilder
    private var previousDonorSection: some View {
        if donationService.hasEverDonated {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("thanks_previous_support".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lastDonation = donationService.lastDonationDate {
                    Text("\("last_donation".localized): \(lastDonation, style: .date)")
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

struct DonationCard: View {
    let product: DonationProduct
    let isSelected: Bool
    let onTap: () -> Void
    
    private var donationInfo: (title: String, description: String, icon: String) {
        let productId = product.id
        if productId.contains("small") || productId == "small" {
            return ("coffee_for_giovanni".localized, "small_coffee".localized, "cup.and.saucer.fill")
        } else if productId.contains("medium") || productId == "medium" {
            return ("pizza_for_giovanni".localized, "pizza_for_dinner".localized, "mug.fill")
        } else if productId.contains("large") || productId == "large" {
            return ("dinner_for_giovanni".localized, "nice_dinner".localized, "fork.knife")
        } else {
            return ("support".localized, "support_development".localized, "heart.fill")
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
