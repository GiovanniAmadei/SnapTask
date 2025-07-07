import StoreKit
import SwiftUI
import Foundation
import Combine

// MARK: - Premium Features Enum
enum PremiumFeature: String, CaseIterable {
    case unlimitedCategories = "unlimited_categories"
    case taskEvaluation = "task_evaluation"
    case unlimitedRewards = "unlimited_rewards"
    case cloudSync = "cloud_sync"
    case advancedStatistics = "advanced_statistics"
    case customThemes = "custom_themes"
    
    var localizedName: String {
        switch self {
        case .unlimitedCategories:
            return "unlimited_categories".localized
        case .taskEvaluation:
            return "task_evaluation".localized
        case .unlimitedRewards:
            return "unlimited_rewards".localized
        case .cloudSync:
            return "cloud_sync".localized
        case .advancedStatistics:
            return "advanced_statistics".localized
        case .customThemes:
            return "custom_themes".localized
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .unlimitedCategories:
            return "unlimited_categories_desc".localized
        case .taskEvaluation:
            return "task_evaluation_desc".localized
        case .unlimitedRewards:
            return "unlimited_rewards_desc".localized
        case .cloudSync:
            return "cloud_sync_desc".localized
        case .advancedStatistics:
            return "advanced_statistics_desc".localized
        case .customThemes:
            return "custom_themes_desc".localized
        }
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus {
    case notSubscribed
    case subscribed(expirationDate: Date)
    case expired
    case pending
    
    var isActive: Bool {
        switch self {
        case .subscribed(let expirationDate):
            return expirationDate > Date()
        case .notSubscribed, .expired, .pending:
            return false
        }
    }
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    @Published var subscriptionProducts: [Product] = []
    @Published var usingMockProducts = false
    @Published var testingMode = false {
        didSet {
            saveTestingMode()
            print("🧪 Testing mode: \(testingMode ? "ON" : "OFF")")
        }
    }
    
    private let productIDs = [
        "com.giovanniamadei.SnapTaskProAlpha.subscription.monthly",
        "com.giovanniamadei.SnapTaskProAlpha.subscription.yearly"
    ]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSubscriptionStatus()
        loadTestingMode()
        // Listen for transaction updates
        Task {
            await listenForTransactions()
        }
    }
    
    // MARK: - Public Methods
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            let sortedProducts = products.sorted { $0.price < $1.price }
            
            if !sortedProducts.isEmpty {
                subscriptionProducts = sortedProducts
                usingMockProducts = false
                print("✅ Loaded \(sortedProducts.count) real subscription products")
            } else {
                print("⚠️ No subscription products found, using mock products for development")
                createMockProducts()
            }
        } catch {
            print("❌ Failed to load subscription products: \(error)")
            print("🔄 Using mock products for development")
            createMockProducts()
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Subscription purchase successful: \(product.displayName)")
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    return true
                case .unverified:
                    print("❌ Subscription purchase unverified")
                    return false
                }
            case .userCancelled:
                print("❌ Subscription purchase cancelled by user")
                return false
            case .pending:
                print("⏳ Subscription purchase pending")
                subscriptionStatus = .pending
                return false
            @unknown default:
                return false
            }
        } catch {
            print("❌ Subscription purchase failed: \(error)")
            return false
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("❌ Failed to restore purchases: \(error)")
        }
    }
    
    func hasAccess(to feature: PremiumFeature) -> Bool {
        // Check if testing mode is enabled - this allows testing premium restrictions
        if testingMode {
            return subscriptionStatus.isActive
        }
        
        // During development, allow all features by default
        #if DEBUG
        return true
        #else
        return subscriptionStatus.isActive
        #endif
    }
    
    // MARK: - Private Methods
    private func createMockProducts() {
        // For development only - we'll create mock products
        subscriptionProducts = []
        usingMockProducts = true
    }
    
    private func updateSubscriptionStatus() async {
        // Check current subscription status
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if productIDs.contains(transaction.productID) {
                    if let expirationDate = transaction.expirationDate {
                        subscriptionStatus = .subscribed(expirationDate: expirationDate)
                    } else {
                        // Non-renewing subscription or lifetime
                        subscriptionStatus = .subscribed(expirationDate: Date.distantFuture)
                    }
                    saveSubscriptionStatus()
                    return
                }
            case .unverified:
                continue
            }
        }
        
        // No active subscription found
        subscriptionStatus = .notSubscribed
        saveSubscriptionStatus()
    }
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                if productIDs.contains(transaction.productID) {
                    await updateSubscriptionStatus()
                }
            case .unverified:
                continue
            }
        }
    }
    
    private func saveSubscriptionStatus() {
        switch subscriptionStatus {
        case .subscribed(let expirationDate):
            UserDefaults.standard.set(expirationDate, forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set(true, forKey: "hasActiveSubscription")
        case .notSubscribed, .expired, .pending:
            UserDefaults.standard.removeObject(forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set(false, forKey: "hasActiveSubscription")
        }
    }
    
    private func loadSubscriptionStatus() {
        if let expirationDate = UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date {
            if expirationDate > Date() {
                subscriptionStatus = .subscribed(expirationDate: expirationDate)
            } else {
                subscriptionStatus = .expired
            }
        } else {
            subscriptionStatus = .notSubscribed
        }
    }
    
    private func saveTestingMode() {
        UserDefaults.standard.set(testingMode, forKey: "premium_testing_mode")
    }
    
    private func loadTestingMode() {
        testingMode = UserDefaults.standard.bool(forKey: "premium_testing_mode")
    }
}

// MARK: - Convenience Extensions
extension SubscriptionManager {
    var isSubscribed: Bool {
        subscriptionStatus.isActive
    }
    
    var subscriptionExpirationDate: Date? {
        switch subscriptionStatus {
        case .subscribed(let expirationDate):
            return expirationDate
        default:
            return nil
        }
    }
    
    // Premium feature limits for free users
    static let maxCategoriesForFree = 4
    static let maxRewardsForFree = 3
}