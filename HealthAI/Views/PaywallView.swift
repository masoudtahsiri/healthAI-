import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // MARK: - Required URLs for App Store Compliance
    // Privacy Policy URL
    private let privacyPolicyURL = URL(string: "https://healthaiplus-app.vercel.app/healthai-privacy.html")!
    
    // Terms of Use (EULA):
    // - If using Apple's standard EULA: Use the URL below (Apple's standard EULA)
    // - If using a custom EULA: Replace with your custom EULA URL
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 32 : 24
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 24
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: adaptiveSpacing) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: horizontalSizeClass == .regular ? 80 : 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Unlock Premium Features")
                            .font(.responsiveHeadline())
                            .multilineTextAlignment(.center)
                        
                        Text("Get AI-powered insights, advanced analysis, and personalized recommendations")
                            .font(.responsiveBody())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, horizontalSizeClass == .regular ? 40 : 20)
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Efficiency Analysis",
                            description: "Advanced AI-powered efficiency metrics and insights"
                        )
                        
                        FeatureRow(
                            icon: "scalemass.fill",
                            title: "Body & Fitness Analysis",
                            description: "Detailed body composition and fitness tracking"
                        )
                        
                        FeatureRow(
                            icon: "figure.strengthtraining.traditional",
                            title: "Fitness Analysis",
                            description: "Comprehensive fitness pattern recognition"
                        )
                        
                        FeatureRow(
                            icon: "brain.head.profile",
                            title: "Coach Recommendations",
                            description: "Personalized AI coach recommendations"
                        )
                    }
                    .padding(adaptivePadding)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, adaptivePadding)
                    
                    // Subscription Product
                    if let product = subscriptionManager.products.first(where: { $0.id == "com.healthai.app.pro_monthly" }) {
                        VStack(spacing: 16) {
                            // Subscription Details (Required by App Store)
                            VStack(spacing: 12) {
                                // Subscription Title
                                if let subscription = product.subscription {
                                    VStack(spacing: 8) {
                                        Text(product.displayName)
                                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        // Subscription Length
                                        Text(subscriptionDurationText(subscription: subscription))
                                            .font(.responsiveBody())
                                            .foregroundColor(.secondary)
                                        
                                        // Price Display
                                        VStack(spacing: 4) {
                                            Text("3-Day Free Trial")
                                                .font(.responsiveHeadline())
                                                .foregroundColor(.green)
                                            
                                            Text("Then \(product.displayPrice)/\(subscriptionUnitText(subscription: subscription))")
                                                .font(.responsiveBody())
                                                .foregroundColor(.secondary)
                                            
                                            // Price per unit
                                            Text("Price per \(subscriptionUnitText(subscription: subscription)): \(product.displayPrice)")
                                                .font(.responsiveCaption())
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top, 4)
                                        
                                        Text("Cancel anytime")
                                            .font(.responsiveCaption())
                                            .foregroundColor(.secondary)
                                            .padding(.top, 4)
                                    }
                                } else {
                                    // Fallback for non-subscription products
                                    VStack(spacing: 8) {
                                        Text(product.displayName)
                                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text(product.displayPrice)
                                            .font(.system(size: horizontalSizeClass == .regular ? 48 : 36, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text(product.description)
                                            .font(.responsiveBody())
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Subscribe Button
                            Button(action: {
                                Task {
                                    await purchaseSubscription(product: product)
                                }
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Start Free Trial")
                                            .font(.system(size: horizontalSizeClass == .regular ? 20 : 18, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: horizontalSizeClass == .regular ? 60 : 54)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .disabled(isPurchasing)
                            }
                            .padding(.horizontal, adaptivePadding)
                        }
                        .padding(.vertical, adaptiveSpacing)
                    } else if subscriptionManager.isLoading {
                        ProgressView("Loading subscription options...")
                            .padding(.vertical, 40)
                    }
                    
                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isSubscribed {
                                dismiss()
                            }
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.responsiveBody())
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Terms and Privacy (Required by App Store - Must be functional links)
                    VStack(spacing: 12) {
                        Text("By subscribing, you agree to our")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 8) {
                            // Terms of Use (EULA) Link
                            Link("Terms of Use", destination: termsOfUseURL)
                                .font(.responsiveCaption())
                                .foregroundColor(.blue)
                            
                            Text("and")
                                .font(.responsiveCaption())
                                .foregroundColor(.secondary)
                            
                            // Privacy Policy Link
                            Link("Privacy Policy", destination: privacyPolicyURL)
                                .font(.responsiveCaption())
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, adaptivePadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
    }
    
    private func purchaseSubscription(product: Product) async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let success = try await subscriptionManager.purchase()
            if success {
                dismiss()
            }
        } catch {
            if let subscriptionError = error as? SubscriptionError {
                switch subscriptionError {
                case .userCancelled:
                    // User cancelled, don't show error
                    break
                default:
                    errorMessage = subscriptionError.errorDescription
                    showError = true
                }
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        isPurchasing = false
    }
    
    // MARK: - Helper Methods for Subscription Details
    
    private func subscriptionDurationText(subscription: Product.SubscriptionInfo) -> String {
        let period = subscription.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return "Billed every \(period.value) \(period.value == 1 ? "day" : "days")"
        case .week:
            return "Billed every \(period.value) \(period.value == 1 ? "week" : "weeks")"
        case .month:
            return "Billed every \(period.value) \(period.value == 1 ? "month" : "months")"
        case .year:
            return "Billed every \(period.value) \(period.value == 1 ? "year" : "years")"
        @unknown default:
            return "Subscription"
        }
    }
    
    private func subscriptionUnitText(subscription: Product.SubscriptionInfo) -> String {
        let period = subscription.subscriptionPeriod
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "days"
        case .week:
            return period.value == 1 ? "week" : "weeks"
        case .month:
            return period.value == 1 ? "month" : "months"
        case .year:
            return period.value == 1 ? "year" : "years"
        @unknown default:
            return "period"
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.purple)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

