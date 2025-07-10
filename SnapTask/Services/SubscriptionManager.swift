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
enum SubscriptionStatus: Equatable {
    case notSubscribed
    case subscribed(expirationDate: Date)
    case expired
    case inTrial(expirationDate: Date)
    case pending
    case failed(error: String)
    
    var isActive: Bool {
        switch self {
        case .subscribed(let expirationDate):
            return expirationDate > Date()
        case .inTrial(let expirationDate):
            return expirationDate > Date()
        case .notSubscribed, .expired, .pending, .failed:
            return false
        }
    }
    
    var isInTrial: Bool {
        if case .inTrial = self {
            return true
        }
        return false
    }
    
    var displayStatus: String {
        switch self {
        case .notSubscribed:
            return "Non abbonato"
        case .subscribed(let expirationDate):
            return "Abbonato fino al \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
        case .expired:
            return "Abbonamento scaduto"
        case .inTrial(let expirationDate):
            return "Trial gratuito fino al \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
        case .pending:
            return "Acquisto in elaborazione"
        case .failed(let error):
            return "Errore: \(error)"
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
    @Published var monthlyProduct: Product?
    @Published var yearlyProduct: Product?
    @Published var lifetimeProduct: Product?
    @Published var testingMode = false {
        didSet {
            saveTestingMode()
            print("🧪 Testing mode: \(testingMode ? "ON" : "OFF")")
        }
    }
    
    private let productIDs = [
        "com.giovanniamadei.SnapTaskProAlpha.subscription.monthly",
        "com.giovanniamadei.SnapTaskProAlpha.subscription.yearly",
        "com.giovanniamadei.SnapTaskProAlpha.lifetime"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSubscriptionStatus()
        loadTestingMode()
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products on initialization
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.subscriptionProducts = products.filter { $0.type == .autoRenewable }.sorted { $0.price < $1.price }
                
                // Separate products by type
                for product in products {
                    if product.id.contains("monthly") {
                        self.monthlyProduct = product
                    } else if product.id.contains("yearly") {
                        self.yearlyProduct = product
                    } else if product.id.contains("lifetime") {
                        self.lifetimeProduct = product
                    }
                }
                
                print("✅ Loaded \(products.count) products")
                if let monthly = monthlyProduct {
                    print("   Monthly: \(monthly.displayName) - \(monthly.displayPrice)")
                }
                if let yearly = yearlyProduct {
                    print("   Yearly: \(yearly.displayName) - \(yearly.displayPrice)")
                }
                if let lifetime = lifetimeProduct {
                    print("   Lifetime: \(lifetime.displayName) - \(lifetime.displayPrice)")
                }
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            await MainActor.run {
                self.subscriptionStatus = .failed(error: "Impossibile caricare i prodotti")
            }
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Purchase successful: \(product.displayName)")
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    return true
                case .unverified(let transaction, let error):
                    print("❌ Purchase unverified: \(error)")
                    await transaction.finish()
                    return false
                }
            case .userCancelled:
                print("❌ Purchase cancelled by user")
                return false
            case .pending:
                print("⏳ Purchase pending")
                await MainActor.run {
                    self.subscriptionStatus = .pending
                }
                return false
            @unknown default:
                print("❌ Unknown purchase result")
                return false
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            await MainActor.run {
                self.subscriptionStatus = .failed(error: "Acquisto fallito")
            }
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            return subscriptionStatus.isActive
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            await MainActor.run {
                self.subscriptionStatus = .failed(error: "Ripristino fallito")
            }
            return false
        }
    }
    
    func hasAccess(to feature: PremiumFeature) -> Bool {
        // If testing mode is enabled, use actual subscription status
        if testingMode {
            return subscriptionStatus.isActive
        }
        
        // In production, check actual subscription status
        return subscriptionStatus.isActive
    }
    
    func manageSubscriptions() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("❌ Failed to show manage subscriptions: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSubscriptionStatus() async {
        var activeSubscription: StoreKit.Transaction?
        var hasLifetimePurchase = false
        var isInTrialPeriod = false
        
        // Check for active subscriptions and lifetime purchases
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if productIDs.contains(transaction.productID) {
                    if transaction.productID.contains("lifetime") {
                        hasLifetimePurchase = true
                        break
                    } else {
                        activeSubscription = transaction
                        
                        // Check if it's a trial period
                        if let subscription = await getSubscriptionStatus(for: transaction.productID) {
                            isInTrialPeriod = subscription.state == .inBillingRetryPeriod || subscription.state == .inGracePeriod
                        }
                    }
                }
            case .unverified(let transaction, let error):
                print("❌ Unverified transaction: \(error)")
                continue
            }
        }
        
        await MainActor.run {
            if hasLifetimePurchase {
                // Lifetime purchase - never expires
                self.subscriptionStatus = .subscribed(expirationDate: Date.distantFuture)
            } else if let transaction = activeSubscription {
                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        if isInTrialPeriod {
                            self.subscriptionStatus = .inTrial(expirationDate: expirationDate)
                        } else {
                            self.subscriptionStatus = .subscribed(expirationDate: expirationDate)
                        }
                    } else {
                        self.subscriptionStatus = .expired
                    }
                } else {
                    // Non-expiring subscription
                    self.subscriptionStatus = .subscribed(expirationDate: Date.distantFuture)
                }
            } else {
                self.subscriptionStatus = .notSubscribed
            }
            
            self.saveSubscriptionStatus()
        }
    }
    
    private func getSubscriptionStatus(for productID: String) async -> Product.SubscriptionInfo.Status? {
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first,
                  let subscription = product.subscription else {
                return nil
            }
            
            let statuses = try await subscription.status
            return statuses.first
        } catch {
            print("❌ Failed to get subscription status: \(error)")
            return nil
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                switch result {
                case .verified(let transaction):
                    if self.productIDs.contains(transaction.productID) {
                        await self.updateSubscriptionStatus()
                    }
                case .unverified(let transaction, let error):
                    print("❌ Unverified transaction update: \(error)")
                    continue
                }
            }
        }
    }
    
    private func saveSubscriptionStatus() {
        switch subscriptionStatus {
        case .subscribed(let expirationDate):
            UserDefaults.standard.set(expirationDate, forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set("subscribed", forKey: "subscriptionStatusType")
        case .inTrial(let expirationDate):
            UserDefaults.standard.set(expirationDate, forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set("inTrial", forKey: "subscriptionStatusType")
        case .notSubscribed:
            UserDefaults.standard.removeObject(forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set("notSubscribed", forKey: "subscriptionStatusType")
        case .expired:
            UserDefaults.standard.removeObject(forKey: "subscriptionExpirationDate")
            UserDefaults.standard.set("expired", forKey: "subscriptionStatusType")
        case .pending:
            UserDefaults.standard.set("pending", forKey: "subscriptionStatusType")
        case .failed(let error):
            UserDefaults.standard.set("failed", forKey: "subscriptionStatusType")
            UserDefaults.standard.set(error, forKey: "subscriptionError")
        }
    }
    
    private func loadSubscriptionStatus() {
        let statusType = UserDefaults.standard.string(forKey: "subscriptionStatusType") ?? "notSubscribed"
        let expirationDate = UserDefaults.standard.object(forKey: "subscriptionExpirationDate") as? Date
        
        switch statusType {
        case "subscribed":
            if let expirationDate = expirationDate {
                subscriptionStatus = .subscribed(expirationDate: expirationDate)
            } else {
                subscriptionStatus = .notSubscribed
            }
        case "inTrial":
            if let expirationDate = expirationDate {
                subscriptionStatus = .inTrial(expirationDate: expirationDate)
            } else {
                subscriptionStatus = .notSubscribed
            }
        case "expired":
            subscriptionStatus = .expired
        case "pending":
            subscriptionStatus = .pending
        case "failed":
            let error = UserDefaults.standard.string(forKey: "subscriptionError") ?? "Errore sconosciuto"
            subscriptionStatus = .failed(error: error)
        default:
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
        case .subscribed(let expirationDate), .inTrial(let expirationDate):
            return expirationDate
        default:
            return nil
        }
    }
    
    var yearlySavingsPercentage: Int {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else {
            return 48 // Updated default percentage
        }
        
        let monthlyYearlyPrice = monthly.price * 12
        let savings = monthlyYearlyPrice - yearly.price
        let percentage = (savings / monthlyYearlyPrice) * 100
        
        return Int(NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    var yearlySavingsAmount: String {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else {
            return "€22,89" // Updated default amount
        }
        
        let monthlyYearlyPrice = monthly.price * 12
        let savings = monthlyYearlyPrice - yearly.price
        
        return savings.formatted(.currency(code: "EUR"))
    }
    
    // Premium feature limits for free users
    static let maxCategoriesForFree = 4
    static let maxRewardsForFree = 3
}

// MARK: - Trial Management
extension SubscriptionManager {
    var trialDaysRemaining: Int {
        switch subscriptionStatus {
        case .inTrial(let expirationDate):
            let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            return max(0, remaining)
        default:
            return 0
        }
    }
    
    var hasUsedTrial: Bool {
        // Check if user has previously used trial
        return UserDefaults.standard.bool(forKey: "hasUsedFreeTrial")
    }
    
    func markTrialAsUsed() {
        UserDefaults.standard.set(true, forKey: "hasUsedFreeTrial")
    }
}