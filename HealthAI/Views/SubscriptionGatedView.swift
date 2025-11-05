import SwiftUI

struct SubscriptionGatedView<Content: View>: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    let featureName: String
    let featureIcon: String
    let content: Content
    
    init(featureName: String, featureIcon: String, @ViewBuilder content: () -> Content) {
        self.featureName = featureName
        self.featureIcon = featureIcon
        self.content = content()
    }
    
    var body: some View {
        Group {
            if subscriptionManager.isSubscribed {
                content
            } else {
                SubscriptionLockedView(
                    featureName: featureName,
                    featureIcon: featureIcon,
                    onUpgrade: {
                        showPaywall = true
                    }
                )
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
            }
        }
        .task {
            await subscriptionManager.checkSubscriptionStatus()
        }
    }
}

struct SubscriptionLockedView: View {
    let featureName: String
    let featureIcon: String
    let onUpgrade: () -> Void
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 20
    }
    
    var body: some View {
        ModernCard {
            VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
                // Lock Icon
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: horizontalSizeClass == .regular ? 80 : 64, height: horizontalSizeClass == .regular ? 80 : 64)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: horizontalSizeClass == .regular ? 32 : 28))
                        .foregroundColor(.purple)
                }
                
                // Feature Name
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: featureIcon)
                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                            .foregroundColor(.purple)
                        
                        Text(featureName)
                            .font(.responsiveHeadline())
                    }
                    
                    Text("Premium Feature")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                }
                
                // Upgrade Button
                Button(action: onUpgrade) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                        Text("Upgrade to Premium")
                            .font(.system(size: horizontalSizeClass == .regular ? 18 : 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: horizontalSizeClass == .regular ? 56 : 50)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.top, 8)
            }
            .padding(adaptivePadding)
            .frame(minHeight: horizontalSizeClass == .regular ? 300 : 250)
        }
    }
}

