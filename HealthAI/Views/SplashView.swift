import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var logoRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var currentLoadingMessageIndex = 0
    @State private var loadingMessageOpacity: Double = 0
    
    // Loading messages in sequence (will complete before splash ends)
    // Reduced to 4 key messages with longer duration for better readability
    private let loadingMessages = [
        "Synchronizing data...",
        "Loading your health data...",
        "Initializing AI Agent....",
        "Almost ready..."
    ]
    
    // Splash screen duration from ContentView (20 seconds)
    // We'll complete messages by ~16 seconds to finish before splash ends
    private let splashDuration: TimeInterval = 20.0
    
    // Version info from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version)"
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background - sporty and professional
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.3, blue: 0.6),      // Deep athletic blue
                    Color(red: 0.0, green: 0.5, blue: 0.8),        // Vibrant ocean blue
                    Color(red: 0.2, green: 0.7, blue: 0.9),      // Bright cyan/teal
                    Color(red: 0.4, green: 0.8, blue: 1.0)       // Electric cyan
                ]),
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(
                Animation.easeInOut(duration: 8.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            // Animated background circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: isAnimating ? -50 : 50, y: isAnimating ? -100 : 100)
                .animation(
                    Animation.easeInOut(duration: 10.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: isAnimating ? 50 : -50, y: isAnimating ? 100 : -100)
                .animation(
                    Animation.easeInOut(duration: 12.0)
                        .repeatForever(autoreverses: true)
                        .delay(1.0),
                    value: isAnimating
                )
            
            VStack {
                Spacer()
                
                // Main logo with animations
                VStack(spacing: 30) {
                    ZStack {
                        // Pulsing ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseScale)
                            .opacity(1 - pulseScale + 0.3)
                        
                        // Rotating gradient ring
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white,
                                        Color.white.opacity(0.3)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(logoRotation))
                        
                        // Main logo image
                        Image("SplashLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 160, height: 160)
                            .scaleEffect(scale)
                            .shadow(color: Color.white.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                    .opacity(logoOpacity)
                    
                    // App name with fade-in
                    VStack(spacing: 16) {
                        Text("HealthAI+")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(textOpacity)
                            .offset(y: textOpacity == 0 ? 20 : 0)
                        
                        Text("Powered by AI")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .opacity(textOpacity)
                            .offset(y: textOpacity == 0 ? 20 : 0)
                            .padding(.bottom, 24)
                        
                        // Loading messages below "Powered by Apple Intelligence™"
                        Text(loadingMessages[currentLoadingMessageIndex])
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(loadingMessageOpacity)
                            .frame(height: 28)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                
                Spacer()
                
                // Version and Copyright at bottom
                VStack(spacing: 8) {
                    Text(appVersion)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("© \(currentYear) All Rights Reserved")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(textOpacity)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start background animation immediately
        isAnimating = true
        
        // Logo entrance animation - start immediately with no delay
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            logoOpacity = 1.0
        }
        
        // Text fade-in - slightly delayed after logo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOpacity = 1.0
            }
        }
        
        // Start loading messages rotation after text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            startLoadingMessages()
        }
        
        // Pulsing animation - start after logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.3
            }
        }
        
        // Rotating ring animation - start after logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(
                Animation.linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
            ) {
                logoRotation = 360
            }
        }
    }
    
    private func startLoadingMessages() {
        // Calculate timing: splash screen lasts 20 seconds
        // 4 messages, each showing for 5 seconds
        let messageDuration: TimeInterval = 5.0 // 5 seconds per message
        let fadeOutDuration: TimeInterval = 0.8 // Longer fade out for smoother transition
        let fadeInDuration: TimeInterval = 0.6 // Slightly shorter fade in
        
        // Show first message after text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: fadeInDuration)) {
                self.loadingMessageOpacity = 1.0
            }
        }
        
        // Sequence through all messages with equal durations and smooth fade transitions
        for index in 1..<loadingMessages.count {
            // Calculate when this message should appear (equal spacing: 5 seconds each)
            let messageStartTime = 0.8 + (Double(index) * messageDuration)
            let fadeOutStartTime = messageStartTime - fadeOutDuration
            
            // Start fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutStartTime) {
                withAnimation(.easeIn(duration: fadeOutDuration)) {
                    self.loadingMessageOpacity = 0
                }
            }
            
            // Change message index mid-way through fade out when opacity is lowest
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutStartTime + (fadeOutDuration * 0.6)) {
                self.currentLoadingMessageIndex = index
            }
            
            // Fade in the new message after fade out completes
            DispatchQueue.main.asyncAfter(deadline: .now() + messageStartTime) {
                withAnimation(.easeOut(duration: fadeInDuration)) {
                    self.loadingMessageOpacity = 1.0
                }
            }
        }
        
        // Last message stays visible until splash ends
    }
}

// MARK: - Preview
#Preview {
    SplashView()
}

