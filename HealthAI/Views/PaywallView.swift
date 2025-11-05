import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
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
                            // Price Display
                            VStack(spacing: 8) {
                                if let subscription = product.subscription {
                                    Text("3-Day Free Trial")
                                        .font(.responsiveHeadline())
                                        .foregroundColor(.green)
                                    
                                    Text("Then \(product.displayPrice)/month")
                                        .font(.responsiveBody())
                                        .foregroundColor(.secondary)
                                    
                                    Text("Cancel anytime")
                                        .font(.responsiveCaption())
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                } else {
                                    Text(product.displayPrice)
                                        .font(.system(size: horizontalSizeClass == .regular ? 48 : 36, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text(product.description)
                                        .font(.responsiveBody())
                                        .foregroundColor(.secondary)
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
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, adaptivePadding)
                    }
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

