import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                if appState.hasCompletedOnboarding {
                    DashboardView()
                } else {
                    OnboardingView()
                }
            }
            .opacity(showSplash ? 0 : 1)
            
            // Splash screen
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Hide splash after animations complete - extended duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

