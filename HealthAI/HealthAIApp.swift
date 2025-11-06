import SwiftUI

@main
struct HealthAIApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var hasCompletedOnboarding = false
    @Published var isRefreshing = false
    
    let healthKitManager = HealthKitManager()
    let aiCore = AICore()
    let healthDataCache = HealthDataCache()
    let subscriptionManager = SubscriptionManager.shared
    
    lazy var appleIntelligence: AppleIntelligence? = {
        if #available(iOS 26.0, *) {
            return AppleIntelligence()
        } else {
            return nil
        }
    }()
    
    init() {
        loadUserProfile()
    }
    
    private func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
            self.hasCompletedOnboarding = true
        }
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        self.userProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
        self.hasCompletedOnboarding = true
    }
}

