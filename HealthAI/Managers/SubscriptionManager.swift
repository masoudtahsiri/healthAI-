import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // Product ID from App Store Connect
    private let productID = "com.healthai.app.pro_monthly"
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var products: [Product] = []
    @Published var isLoading = false
    
    enum SubscriptionStatus {
        case subscribed
        case notSubscribed
        case unknown
    }
    
    private init() {
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    // Load products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: [productID])
            self.products = products
            print("✅ [Subscription] Loaded \(products.count) products")
        } catch {
            print("❌ [Subscription] Failed to load products: \(error)")
        }
    }
    
    // Check current subscription status
    func checkSubscriptionStatus() async {
        guard let product = products.first(where: { $0.id == productID }) else {
            subscriptionStatus = .notSubscribed
            return
        }
        
        // Check for active subscription
        let statuses = try? await product.subscription?.status
        let hasActiveSubscription = statuses?.contains { status in
            switch status.state {
            case .subscribed, .inGracePeriod:
                return true
            default:
                return false
            }
        } ?? false
        
        subscriptionStatus = hasActiveSubscription ? .subscribed : .notSubscribed
        print("✅ [Subscription] Status: \(subscriptionStatus)")
    }
    
    // Purchase subscription
    func purchase() async throws -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else {
            throw SubscriptionError.productNotFound
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Transaction is verified
                await transaction.finish()
                await checkSubscriptionStatus()
                return true
            case .unverified(_, let error):
                print("❌ [Subscription] Unverified transaction: \(error)")
                throw SubscriptionError.unverifiedTransaction
            }
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }
    
    // Restore purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ [Subscription] Purchases restored")
        } catch {
            print("❌ [Subscription] Failed to restore: \(error)")
        }
    }
    
    // Check if user has active subscription (convenience method)
    var isSubscribed: Bool {
        return subscriptionStatus == .subscribed
    }
}

enum SubscriptionError: LocalizedError {
    case productNotFound
    case unverifiedTransaction
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .unverifiedTransaction:
            return "Transaction could not be verified"
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

