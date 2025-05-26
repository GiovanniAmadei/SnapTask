import StoreKit
import SwiftUI

protocol DonationProduct {
    var id: String { get }
    var displayPrice: String { get }
    var displayName: String { get }
}

extension Product: DonationProduct {}

@MainActor
class DonationService: ObservableObject {
    static let shared = DonationService()
    
    @Published var donationProducts: [DonationProduct] = []
    @Published var isLoading = false
    @Published var lastDonationDate: Date?
    @Published var usingMockProducts = false
    
    private let productIDs = [
        "com.giovanniamadei.SnapTask.donation.small",
        "com.giovanniamadei.SnapTask.donation.medium", 
        "com.giovanniamadei.SnapTask.donation.large"
    ]
    
    private init() {
        loadLastDonationDate()
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            let sortedProducts = products.sorted { $0.price < $1.price }
            
            if !sortedProducts.isEmpty {
                donationProducts = sortedProducts
                usingMockProducts = false
                print("✅ Loaded \(sortedProducts.count) real products from App Store Connect")
            } else {
                print("⚠️ No products found from App Store Connect, using mock products for development")
                createMockProducts()
            }
        } catch {
            print("❌ Failed to load donation products: \(error)")
            print("🔄 Using mock products for development")
            createMockProducts()
        }
    }
    
    private func createMockProducts() {
        donationProducts = [
            MockProduct(id: "small", price: 2.99, displayName: "Small Coffee"),
            MockProduct(id: "medium", price: 4.99, displayName: "Big Coffee"),
            MockProduct(id: "large", price: 9.99, displayName: "Dinner")
        ]
        usingMockProducts = true
    }
    
    func purchase(_ product: DonationProduct) async -> Bool {
        if let mockProduct = product as? MockProduct {
            print("🧪 Processing mock purchase for: \(mockProduct.displayName)")
            return await purchaseMockProduct(mockProduct)
        } else if let realProduct = product as? Product {
            print("💳 Processing real purchase for: \(realProduct.displayName)")
            return await purchaseRealProduct(realProduct)
        }
        return false
    }
    
    private func purchaseRealProduct(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Purchase successful: \(product.displayName)")
                    await transaction.finish()
                    recordDonation()
                    return true
                case .unverified:
                    print("❌ Purchase unverified")
                    return false
                }
            case .userCancelled:
                print("❌ Purchase cancelled by user")
                return false
            case .pending:
                print("⏳ Purchase pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            return false
        }
    }
    
    private func purchaseMockProduct(_ mockProduct: MockProduct) async -> Bool {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        print("✅ Mock purchase completed: \(mockProduct.displayName)")
        recordDonation()
        return true
    }
    
    private func recordDonation() {
        lastDonationDate = Date()
        UserDefaults.standard.set(lastDonationDate, forKey: "lastDonationDate")
        print("📝 Donation recorded at: \(lastDonationDate!)")
    }
    
    private func loadLastDonationDate() {
        lastDonationDate = UserDefaults.standard.object(forKey: "lastDonationDate") as? Date
    }
    
    var hasEverDonated: Bool {
        lastDonationDate != nil
    }
}

struct MockProduct: DonationProduct {
    let id: String
    let price: Double
    let displayName: String
    
    var displayPrice: String { 
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: price)) ?? "€\(price)"
    }
}
