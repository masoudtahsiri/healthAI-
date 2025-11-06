import SwiftUI
import Charts
import HealthKit
#if canImport(FoundationModels)
import FoundationModels
#endif
import UIKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var healthInsight: HealthInsight?
    @State private var bodyCompositionPrediction: BodyCompositionPrediction?
    @State private var patternInsights: PatternInsights?
    @State private var comprehensiveRecommendations: ComprehensiveRecommendations?
    @State private var isLoading = false
    @State private var isLoadingCache = false
    @State private var isLoadingAI = false
    @State private var isLoadingRecommendations = false
    @State private var errorMessage: String?
    @State private var pullToRefreshCooldownMessage: String?
    @State private var showCooldownAlert = false
    
    // Persistent storage for pull-to-refresh timestamp
    private func getLastPullToRefreshDate() -> Date? {
        UserDefaults.standard.object(forKey: "DashboardView.lastPullToRefreshDate") as? Date
    }
    
    private func setLastPullToRefreshDate(_ date: Date?) {
        if let date = date {
            UserDefaults.standard.set(date, forKey: "DashboardView.lastPullToRefreshDate")
        } else {
            UserDefaults.standard.removeObject(forKey: "DashboardView.lastPullToRefreshDate")
        }
    }
    
    // Date range selection
    @State private var selectedRange: DateRangeType = .weekly
    
    // Track current data loading task to cancel if needed
    @State private var currentLoadingTask: Task<Void, Never>?
    
    // Debounce task for expensive AI operations (prevents rapid switching issues)
    @State private var rangeLoadDebounceTask: Task<Void, Never>?
    
    // Dedicated task for recommendation generation (can be cancelled independently)
    @State private var recommendationTask: Task<ComprehensiveRecommendations?, Never>?
    @State private var recommendationRange: DateRangeType?
    
    // Pattern analyzer instance
    private let patternAnalyzer = PatternAnalyzer()
    
    // Dynamic welcome title based on user's name
    private var welcomeTitle: String {
        if let profile = appState.userProfile, !profile.firstName.isEmpty {
            return "Welcome \(profile.firstName)"
        }
        return "Health Insights"
    }
    
    // Adaptive values based on native size classes
    // Reduced iPad padding to allow full-width content
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 32 : 20
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        VStack(spacing: adaptiveSpacing) {
                            if isLoadingCache {
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .scaleEffect(horizontalSizeClass == .regular ? 1.5 : 1.0)
                                    Text("Loading your health data...")
                                        .font(.responsiveBody())
                                        .foregroundColor(.secondary)
                                    Text("This may take a moment")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, horizontalSizeClass == .regular ? 80 : 40)
                            }
                            
                            if let error = errorMessage {
                                ErrorView(message: error)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            if let insight = healthInsight {
                                // Single column layout for both iPhone and iPad (iPad uses larger sizes)
                                VStack(spacing: adaptiveSpacing) {
                                    // Pattern & Efficiency Insights
                                    if let patterns = patternInsights {
                                        PatternInsightsCard(insights: patterns, onRetry: {
                                            refreshEfficiencyInsights()
                                        })
                                        .frame(maxWidth: .infinity)
                                    }
                                    
                                    WeeklySummaryCard(summary: insight.weeklySummary)
                                        .frame(maxWidth: .infinity)
                                    
                                    // Body & Fitness Analysis (Premium)
                                    SubscriptionGatedView(
                                        featureName: "Body & Fitness Analysis",
                                        featureIcon: "scalemass.fill"
                                    ) {
                                        BodyCompositionCard(
                                            composition: insight.bodyComposition,
                                            prediction: bodyCompositionPrediction,
                                            isCalculatingDesiredWeight: isLoadingAI
                                        )
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Coach Recommendations (Premium)
                                    SubscriptionGatedView(
                                        featureName: "Coach Recommendations",
                                        featureIcon: "brain.head.profile"
                                    ) {
                                        ComprehensiveRecommendationsCard(
                                            recommendations: comprehensiveRecommendations,
                                            isLoading: isLoadingRecommendations
                                        )
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, adaptivePadding)
                        .padding(.vertical, horizontalSizeClass == .regular ? 20 : 16)
                    } header: {
                        DateRangePicker(selectedRange: $selectedRange)
                            .frame(maxWidth: .infinity)
                            .onChange(of: selectedRange) { oldValue, newValue in
                                // Cancel any in-flight data loading
                                currentLoadingTask?.cancel()
                                // Cancel debounce task (prevents delayed operations from starting)
                                rangeLoadDebounceTask?.cancel()
                                // Cancel dedicated recommendation task
                                recommendationTask?.cancel()
                                recommendationRange = nil
                                // Clear old recommendations and show loading immediately
                                comprehensiveRecommendations = nil
                                isLoadingRecommendations = true  // Show loading immediately when switching
                                // Load data for the new range (will load cached recommendations if available)
                                loadDataFromCache()
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(welcomeTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView().environmentObject(appState)) {
                        Image(systemName: "gearshape")
                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                            .foregroundColor(.primary)
                    }
                }
            }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("", isPresented: $showCooldownAlert) {
            Button("OK", role: .cancel) {
                pullToRefreshCooldownMessage = nil
                showCooldownAlert = false
            }
        } message: {
            if let message = pullToRefreshCooldownMessage {
                Text(message)
            }
        }
        .onAppear {
            // Increase navigation bar height to accommodate larger button
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            
            // Customize toolbar height using UIKit
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    // Find navigation controller
                    if let rootVC = window.rootViewController {
                        var navController: UINavigationController?
                        
                        if let nav = rootVC as? UINavigationController {
                            navController = nav
                        } else if let presented = rootVC.presentedViewController as? UINavigationController {
                            navController = presented
                        }
                        
                        // Adjust navigation bar to allow more height for toolbar items
                        navController?.navigationBar.prefersLargeTitles = true
                    }
                }
            }
            
            loadHealthDataWithCache()
        }
        .onDisappear {
            // Clean up all tasks when view disappears to prevent memory leaks
            currentLoadingTask?.cancel()
            rangeLoadDebounceTask?.cancel()
            recommendationTask?.cancel()
            currentLoadingTask = nil
            rangeLoadDebounceTask = nil
            recommendationTask = nil
            recommendationRange = nil
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                Task { await handleAppForeground() }
            }
        }
        .refreshable {
            await handlePullToRefresh()
        }
    }
    /// Handle app coming to foreground - check if cache needs refresh based on 1-hour rule
    private func handleAppForeground() async {
        print("🔄 [Foreground] App came to foreground, checking cache validity...")
        
        // Check if HealthKit cache needs refresh (1-hour rule)
        if appState.healthDataCache.needsRefresh() {
            print("♻️ [Foreground] Cache expired (>1 hour), refreshing data...")
            await loadAllDataIntoCache()
        } else {
            print("📦 [Foreground] Cache still valid (<1 hour), using cached data")
            // Just load from cache, no refresh needed
            loadDataFromCache()
        }
    }
    
    /// Handle pull-to-refresh with 15-minute cooldown and countdown message
    private func handlePullToRefresh() async {
        let now = Date()
        let cooldownSeconds: TimeInterval = 900 // 15 minutes
        
        // Check if cooldown is active
        if let lastRefresh = getLastPullToRefreshDate() {
            let timeSinceLastRefresh = now.timeIntervalSince(lastRefresh)
            
            // Edge case: if time went backwards (device time changed), allow refresh
            guard timeSinceLastRefresh >= 0 else {
                print("⚠️ [PullToRefresh] Time went backwards, allowing refresh")
                setLastPullToRefreshDate(now)
                
                // Start refresh and ensure minimum 10-second delay
                let startTime = Date()
                await loadAllDataIntoCache()
                
                // Ensure minimum 10 seconds for loading indicator visibility
                let elapsed = Date().timeIntervalSince(startTime)
                let minDelay: TimeInterval = 10.0
                if elapsed < minDelay {
                    let remainingDelay = minDelay - elapsed
                    try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
                }
                return
            }
            
            if timeSinceLastRefresh < cooldownSeconds {
                // Still in cooldown - calculate remaining time
                let remainingSeconds = cooldownSeconds - timeSinceLastRefresh
                let remainingMinutes = max(1, Int(ceil(remainingSeconds / 60))) // Ensure at least 1 minute
                
                let message = "Your data is up to date. You can refresh again in \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s")."
                
                // Set message and show alert on main thread
                await MainActor.run {
                    pullToRefreshCooldownMessage = message
                    showCooldownAlert = true
                    print("✅ [Alert] Showing cooldown alert: \(message)")
                }
                
                // Small delay to ensure UI updates
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                print("⏱️ [PullToRefresh] Cooldown active: \(remainingMinutes) minutes remaining")
                
                // Keep loading indicator visible for 4 seconds during cooldown
                // Shorter than normal refresh since no data is being loaded
                // Note: Alert stays visible until user presses OK
                try? await Task.sleep(nanoseconds: 3_900_000_000) // 3.9 seconds (total 4 seconds with the 0.1s above)
                
                // Don't auto-dismiss - let user dismiss by pressing OK
                return
            }
        }
        
        // Cooldown passed or no previous refresh - allow refresh
        print("🔄 [PullToRefresh] Refreshing data...")
        
        // Start refresh and ensure minimum 10-second delay for loading indicator visibility
        let startTime = Date()
        await loadAllDataIntoCache()
        
        // Ensure minimum 10 seconds for loading indicator visibility
        let elapsed = Date().timeIntervalSince(startTime)
        let minDelay: TimeInterval = 10.0
        if elapsed < minDelay {
            let remainingDelay = minDelay - elapsed
            print("⏱️ [PullToRefresh] Adding delay to ensure 10-second minimum: \(String(format: "%.1f", remainingDelay))s")
            try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
        }
        
        // Update pull-to-refresh timestamp
        setLastPullToRefreshDate(now)
    }
    
    // MARK: - Cache-Based Loading
    
    private func loadHealthDataWithCache() {
        // First-time app open: if no cache exists, always fetch
        if !appState.healthDataCache.isDataLoaded || appState.healthDataCache.lastFetchedDate == nil {
            print("🔄 [Cache] First-time load or no cache, fetching data...")
            Task {
                await loadAllDataIntoCache()
            }
            return
        }
        
        // Check if cache is fresh (1-hour rule)
        if !appState.healthDataCache.needsRefresh() {
            print("📦 [Cache] Using cached data (valid for \(Int(Date().timeIntervalSince(appState.healthDataCache.lastFetchedDate ?? Date()) / 60)) minutes)")
            loadDataFromCache()
            return
        }
        
        // Cache expired (>1 hour), fetch fresh data
        print("🔄 [Cache] Cache expired, fetching fresh data...")
        Task {
            await loadAllDataIntoCache()
        }
    }
    
    private func loadAllDataIntoCache() async {
        // Prevent duplicate loads - check and set flag atomically
        let shouldProceed = await MainActor.run {
            if isLoadingCache {
                return false
            }
            isLoadingCache = true
            return true
        }
        
        guard shouldProceed else {
            print("⏸️ [Cache] Cache load already in progress, skipping...")
            return
        }
        
        print("🔄 [Cache] Loading all data into cache...")
        
        defer {
            Task { @MainActor in
                isLoadingCache = false
            }
        }
        
        guard appState.userProfile != nil else {
            print("❌ No user profile")
            return
        }
        
        await requestHealthKitAccess()
        
        let manager = appState.healthKitManager
        let now = Date()
        let healthKitEarliest = manager.healthStore.earliestPermittedSampleDate()
        // Limit to last 2 years max to avoid excessive data fetching
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? healthKitEarliest
        let earliest = max(healthKitEarliest, twoYearsAgo)
        
        // If cache not loaded, bootstrap full history; else incremental from lastFetchedDate
        if !appState.healthDataCache.isDataLoaded || appState.healthDataCache.lastFetchedDate == nil {
            let allMetrics = await manager.fetchAllDailyMetrics(startDate: earliest, endDate: now)
            appState.healthDataCache.merge(allMetrics: allMetrics, fetchedAt: now)
        } else {
            let cacheStart = appState.healthDataCache.lastFetchedDate ?? earliest
            let start = max(cacheStart, earliest) // Ensure we don't go before the earliest limit
            let allMetrics = await manager.fetchAllDailyMetrics(startDate: start, endDate: now)
            appState.healthDataCache.merge(allMetrics: allMetrics, fetchedAt: now)
        }
        
        print("✅ [Cache] Data loaded into cache")
        
        // Mark HealthKit refresh (invalidates only stale AI cache entries, preserves fresh ones)
        if let appleAI = appState.appleIntelligence {
            appleAI.markHealthKitRefreshed(fetchedAt: now)
        }
        
        await MainActor.run {
            loadDataFromCache()
        }
    }
    
    private func loadDataFromCache() {
        // Store the current selected range to verify we're still on it when done
        let requestedRange = selectedRange
        let rangeKey = requestedRange.rawValue
        
        print("🔄 [Dashboard] loadDataFromCache() called for range: '\(rangeKey)'")
        
        // Check AI cache BEFORE starting any async work
        // This needs to happen synchronously to avoid unnecessary task creation
        var hasPartialCache = false
        if let appleAI = appState.appleIntelligence {
            print("   [Dashboard] AppleIntelligence available, checking cache...")
            if let cached = appleAI.getCachedResponse(for: rangeKey) {
                print("✅ [Dashboard] Found cache for '\(rangeKey)'")
                // Load any cached sections immediately
                if let cachedPatterns = cached.patternInsights {
                    print("   ✅ Loading cached pattern insights")
                    self.patternInsights = cachedPatterns
                    hasPartialCache = true
                }
                if let cachedHealth = cached.healthInsight {
                    print("   ✅ Loading cached health insight")
                    self.healthInsight = cachedHealth
                    hasPartialCache = true
                }
                if let cachedBody = cached.bodyCompositionPrediction {
                    print("   ✅ Loading cached body composition")
                    self.bodyCompositionPrediction = cachedBody
                    hasPartialCache = true
                }
                
                // Load cached recommendations if available
                if let cachedRecs = cached.comprehensiveRecommendations {
                    print("   ✅ Loading cached comprehensive recommendations")
                    self.comprehensiveRecommendations = cachedRecs
                    self.isLoadingRecommendations = false
                    hasPartialCache = true
                } else {
                    // Recommendations are not cached, so we'll need to generate them
                    // Set loading state immediately to show "preparing analysis" or loading indicator
                    self.comprehensiveRecommendations = nil
                    self.isLoadingRecommendations = true
                    print("   ⏳ No cached recommendations, will generate")
                }
                
                // If all sections are cached, we're done
                if cached.isComplete {
                    print("✅ [Dashboard] Complete cache HIT for '\(rangeKey)' - all sections cached")
                    currentLoadingTask?.cancel()
                    currentLoadingTask = nil
                    self.isLoading = false
                    self.isLoadingAI = false
                    self.isLoadingRecommendations = false
                    return
                }
                
                if hasPartialCache {
                    print("📦 [Dashboard] Partial cache - some sections available, will generate missing ones")
                }
            } else {
                print("❌ [Dashboard] Cache MISS for '\(rangeKey)'")
                // No cache at all - ensure loading state is set for recommendations
                self.comprehensiveRecommendations = nil
                self.isLoadingRecommendations = true
            }
        } else {
            print("⚠️ [Dashboard] AppleIntelligence not available")
            // No AI available - clear recommendations and show loading
            self.comprehensiveRecommendations = nil
            self.isLoadingRecommendations = true
        }
        
        // Cancel any existing loading task before starting a new one
        currentLoadingTask?.cancel()
        
        // Load HealthKit metrics IMMEDIATELY (synchronously) before any async work
        // This ensures metrics appear instantly when switching date ranges
        guard let profile = appState.userProfile else {
            errorMessage = "No user profile found"
            isLoading = false
            return
        }
        
        guard appState.healthDataCache.isDataLoaded else {
            errorMessage = "Please wait for data to load"
            isLoading = false
            return
        }
        
        let (startDate, endDate) = DateRangeCalculator.getDates(for: requestedRange)
        
        // Filter cached data by date range - this is synchronous and fast
        let filteredData = appState.healthDataCache.filterByDateRange(startDate: startDate, endDate: endDate)
        
        print("📊 [Cache] Displaying data for \(requestedRange.rawValue):")
        print("   - Workouts: \(filteredData.workoutCount)")
        print("   - Steps: \(Int(filteredData.totalSteps))")
        print("   - Active Calories: \(Int(filteredData.activeCalories))")
        print("   - Total Calories: \(Int(filteredData.totalCalories)) (Active: \(Int(filteredData.activeCalories)) + Basal: \(Int(filteredData.totalCalories - filteredData.activeCalories)))")
        
        // Calculate basic body composition prediction immediately (no async HealthKit calls yet)
        // Use calculated values, will be refined later with actual HealthKit measurements
        let basicBodyComposition = BodyCompositionCalculator.calculate(
            profile: profile,
            filteredData: filteredData,
            workouts: filteredData.workouts,
            currentBodyFatPercentage: nil,
            currentLeanBodyMass: nil,
            avgVO2Max: filteredData.avgCardioFitness,
            startBodyFat: nil,
            endBodyFat: nil,
            startLeanMass: nil,
            endLeanMass: nil,
            startWeight: nil,
            endWeight: nil,
            startWaistCircumference: nil,
            endWaistCircumference: nil
        )
        
        // Create basic health insight with metrics immediately
        let basicInsight = convertToHealthInsightFromFilteredData(
            filteredData: filteredData,
            dayCount: filteredData.dayCount,
            profile: profile,
            bodyCompositionPrediction: basicBodyComposition
        )
        
        // Update UI immediately with basic metrics (no waiting for AI)
        self.healthInsight = basicInsight
        self.bodyCompositionPrediction = basicBodyComposition
        
        if hasPartialCache {
            print("🔄 [AI Cache] Generating missing AI responses for '\(rangeKey)'...")
        } else {
            print("🔄 [AI Cache] No cache found for '\(rangeKey)', generating all AI responses...")
        }
        
        isLoading = true
        isLoadingAI = true  // AI is still loading
        errorMessage = nil
        
        // ✅ SAFE DEBOUNCE: Cancel any pending debounced operations
        // This prevents expensive AI operations from starting if user switches ranges quickly
        rangeLoadDebounceTask?.cancel()
        
        // Debounce expensive async operations (150ms delay)
        // If user switches ranges within 150ms, this task gets cancelled and nothing expensive runs
        rangeLoadDebounceTask = Task {
            // Short debounce delay - only affects expensive AI operations, not UI updates
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            
            // Check if task was cancelled or range changed during debounce
            guard !Task.isCancelled, requestedRange == selectedRange else {
                print("⏸️ [Debounce] Range changed during debounce, cancelling expensive operations")
                return
            }
            
            // Now start the expensive async operations
            await MainActor.run {
                self.startExpensiveAIOperations(
                    for: requestedRange,
                    rangeKey: rangeKey,
                    startDate: startDate,
                    endDate: endDate,
                    filteredData: filteredData,
                    profile: profile,
                    basicBodyComposition: basicBodyComposition,
                    basicInsight: basicInsight,
                    hasPartialCache: hasPartialCache
                )
            }
        }
    }
    
    // Extract expensive async operations to separate function for debouncing
    private func startExpensiveAIOperations(
        for requestedRange: DateRangeType,
        rangeKey: String,
        startDate: Date,
        endDate: Date,
        filteredData: FilteredHealthData,
        profile: UserProfile,
        basicBodyComposition: BodyCompositionPrediction,
        basicInsight: HealthInsight,
        hasPartialCache: Bool
    ) {
        // Verify range hasn't changed during debounce
        guard requestedRange == selectedRange else {
            print("⚠️ [Debounce] Range changed before starting expensive operations")
            return
        }
        
        currentLoadingTask = Task {
            // Capture patternInsights at the start so we can cache it even if range changes
            var capturedPatternInsights: PatternInsights?
            
            // Check if task was cancelled or range changed
            guard !Task.isCancelled, requestedRange == selectedRange else {
                print("⚠️ [Cache] Task cancelled or range changed, aborting")
                return
            }
            
            // Fetch optional body composition data from HealthKit (async)
            // Get most recent for fallback
            let currentBodyFatPercentage = await appState.healthKitManager.readMostRecentBodyFatPercentage()
            let currentLeanBodyMass = await appState.healthKitManager.readMostRecentLeanBodyMass()
            
            // Get actual measurements at start and end of date range (prioritize these)
            let (startBF, endBF, startLBM, endLBM, startWeight, endWeight, startWaist, endWaist) = await appState.healthKitManager.readBodyCompositionForDateRange(
                startDate: startDate,
                endDate: endDate
            )
            
            // Recalculate body composition predictions with actual HealthKit measurements
            // This refines the initial basic calculation we did earlier
            let bodyCompositionPrediction = BodyCompositionCalculator.calculate(
                profile: profile,
                filteredData: filteredData,
                workouts: filteredData.workouts,
                currentBodyFatPercentage: currentBodyFatPercentage,
                currentLeanBodyMass: currentLeanBodyMass,
                avgVO2Max: filteredData.avgCardioFitness,
                // Actual HealthKit measurements (prioritized)
                startBodyFat: startBF,
                endBodyFat: endBF,
                startLeanMass: startLBM,
                endLeanMass: endLBM,
                startWeight: startWeight,
                endWeight: endWeight,
                startWaistCircumference: startWaist,
                endWaistCircumference: endWaist
            )
            
            // Update body composition with refined data
            await MainActor.run {
                guard requestedRange == selectedRange else { return }
                self.bodyCompositionPrediction = bodyCompositionPrediction
            }
            
            // Cache body composition immediately
            if let appleAI = appState.appleIntelligence {
                appleAI.cacheBodyCompositionPrediction(bodyCompositionPrediction, for: rangeKey)
            }
            
            print("🎯 [Body Composition] Refined with HealthKit data:")
            print("   - Fat Loss: \(String(format: "%.2f", bodyCompositionPrediction.fatLoss)) kg")
            print("   - Muscle Gain: \(String(format: "%.2f", bodyCompositionPrediction.muscleGain)) kg")
            print("   - Muscle Loss: \(String(format: "%.2f", bodyCompositionPrediction.muscleLoss)) kg")
            print("   - Net Weight Change: \(String(format: "%.2f", bodyCompositionPrediction.netWeightChange)) kg")
            
            // Recreate health insight with refined body composition
            let basicInsight = convertToHealthInsightFromFilteredData(
                filteredData: filteredData,
                dayCount: filteredData.dayCount,
                profile: profile,
                bodyCompositionPrediction: bodyCompositionPrediction
            )
            
            // Update UI with refined body composition (if range hasn't changed)
            await MainActor.run {
                guard requestedRange == selectedRange else { return }
                // Update health insight with refined body composition data
                self.healthInsight = basicInsight
            }
            
            // Calculate pattern insights
            let dateRange = DateRangeCalculator.getDates(for: requestedRange)
            let patternStartDate = dateRange.start
            let patternEndDate = dateRange.end
            let patterns = await patternAnalyzer.analyzePatterns(
                cache: appState.healthDataCache,
                startDate: patternStartDate,
                endDate: patternEndDate,
                rangeType: requestedRange,
                profile: profile,
                bodyCompositionPrediction: bodyCompositionPrediction,
                healthKitManager: appState.healthKitManager
            )
            
            // Generate AI efficiency insight if available
            var patternsWithAI = patterns
            
            // Check if we already have cached pattern insights with efficiency insights
            let needEfficiencyInsights = await MainActor.run {
                if let cached = appState.appleIntelligence?.getCachedResponse(for: rangeKey),
                   let cachedPatterns = cached.patternInsights,
                   cachedPatterns.efficiencyScore.categorizedInsights != nil {
                    print("✅ [Cache] Using cached efficiency insights, skipping generation")
                    return false
                }
                return true
            }
            
            if let appleAI = appState.appleIntelligence, needEfficiencyInsights {
                let efficiency = patterns.efficiencyScore
                
                // First set loading state
                let loadingEfficiency = EfficiencyMetrics(
                    workoutEfficiency: efficiency.workoutEfficiency,
                    heartHealthEfficiency: efficiency.heartHealthEfficiency,
                    fitnessGains: efficiency.fitnessGains,
                    sleepEfficiency: efficiency.sleepEfficiency,
                    hasWorkouts: efficiency.hasWorkouts,
                    overallScore: efficiency.overallScore,
                    insight: efficiency.insight,
                    categorizedInsights: nil,
                    isLoadingInsights: true
                )
                
                patternsWithAI = PatternInsights(
                    bestPerformingDays: patterns.bestPerformingDays,
                    comparisons: patterns.comparisons,
                    activeInactivePattern: patterns.activeInactivePattern,
                    efficiencyScore: loadingEfficiency,
                    consistencyHeatmap: patterns.consistencyHeatmap,
                    plateauStatus: patterns.plateauStatus
                )
                
                await MainActor.run {
                    self.patternInsights = patternsWithAI
                }
                
                // Generate AI insights with retry logic
                var categorizedInsights = await appleAI.generateEfficiencyInsight(
                    profile: profile,
                    workoutEfficiency: efficiency.workoutEfficiency,
                    heartHealthEfficiency: efficiency.heartHealthEfficiency,
                    fitnessGains: efficiency.fitnessGains,
                    sleepEfficiency: efficiency.sleepEfficiency,
                    hasWorkouts: efficiency.hasWorkouts,
                    rangeType: requestedRange.rawValue
                )
                
                // Cache efficiency insights immediately
                appleAI.cacheEfficiencyInsights(categorizedInsights, for: rangeKey)
                
                // Retry if invalid response (up to 2 retries)
                var retryCount = 0
                while !categorizedInsights.isValid && retryCount < 2 {
                    print("⚠️ [AI] Invalid response detected, retrying... (attempt \(retryCount + 2)/3)")
                    
                    // Wait longer before retry to ensure previous request finishes
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Additional check: if task was cancelled, don't retry
                    guard !Task.isCancelled, requestedRange == selectedRange else {
                        print("⚠️ [AI] Task cancelled or range changed during retry")
                        break
                    }
                    
                    categorizedInsights = await appleAI.generateEfficiencyInsight(
                        profile: profile,
                        workoutEfficiency: efficiency.workoutEfficiency,
                        heartHealthEfficiency: efficiency.heartHealthEfficiency,
                        fitnessGains: efficiency.fitnessGains,
                        sleepEfficiency: efficiency.sleepEfficiency,
                        hasWorkouts: efficiency.hasWorkouts,
                        rangeType: requestedRange.rawValue
                    )
                    
                    // Cache the retried response
                    appleAI.cacheEfficiencyInsights(categorizedInsights, for: rangeKey)
                    retryCount += 1
                }
                
                // Update efficiency metrics with AI insights
                let updatedEfficiency = EfficiencyMetrics(
                    workoutEfficiency: efficiency.workoutEfficiency,
                    heartHealthEfficiency: efficiency.heartHealthEfficiency,
                    fitnessGains: efficiency.fitnessGains,
                    sleepEfficiency: efficiency.sleepEfficiency,
                    hasWorkouts: efficiency.hasWorkouts,
                    overallScore: efficiency.overallScore,
                    insight: efficiency.insight,
                    categorizedInsights: categorizedInsights,
                    isLoadingInsights: false
                )
                
                patternsWithAI = PatternInsights(
                    bestPerformingDays: patterns.bestPerformingDays,
                    comparisons: patterns.comparisons,
                    activeInactivePattern: patterns.activeInactivePattern,
                    efficiencyScore: updatedEfficiency,
                    consistencyHeatmap: patterns.consistencyHeatmap,
                    plateauStatus: patterns.plateauStatus
                )
                
                // Cache pattern insights with efficiency insights
                appleAI.cachePatternInsights(patternsWithAI, for: rangeKey)
            } else {
                // Check if we have cached pattern insights
                let cached = await MainActor.run {
                    return appState.appleIntelligence?.getCachedResponse(for: rangeKey)
                }
                if let cachedPatterns = cached?.patternInsights {
                    // Use cached pattern insights
                    patternsWithAI = cachedPatterns
                }
            }
            
            // Store patternInsights for this specific range so we can cache it later
            capturedPatternInsights = patternsWithAI
            
            // Cache pattern insights if not already cached
            if let appleAI = appState.appleIntelligence {
                appleAI.cachePatternInsights(patternsWithAI, for: rangeKey)
            }
            
            // Generate comprehensive recommendations (only if not already cached)
            if let appleAI = appState.appleIntelligence {
                // Check if recommendations are already cached
                let cached = await MainActor.run {
                    return appState.appleIntelligence?.getCachedResponse(for: rangeKey)
                }
                
                if let cachedRecs = cached?.comprehensiveRecommendations {
                    print("✅ [Dashboard] Recommendations already cached for '\(rangeKey)', skipping generation")
                    await MainActor.run {
                        guard requestedRange == selectedRange else { return }
                        self.comprehensiveRecommendations = cachedRecs
                        self.isLoadingRecommendations = false
                    }
                } else {
                    // ✅ DEDICATED RECOMMENDATION TASK: Cancel previous task if switching ranges
                    await MainActor.run {
                        if let existingTask = recommendationTask,
                           recommendationRange != requestedRange {
                            print("🛑 [Recommendations] Cancelling previous task for '\(recommendationRange?.rawValue ?? "unknown")'")
                            existingTask.cancel()
                        }
                    }
                    
                    print("🎯 [Dashboard] Starting to generate comprehensive recommendations...")
                    print("   - Range: \(requestedRange.rawValue)")
                    print("   - Day count: \(filteredData.dayCount)")
                    print("   - Has patterns: true")
                    print("   - Has body composition: true")
                    
                    // Set loading state for recommendations
                    await MainActor.run {
                        guard requestedRange == selectedRange else { return }
                        self.isLoadingRecommendations = true
                        self.comprehensiveRecommendations = nil
                    }
                    
                    // Create dedicated task for recommendation generation
                    let avgStepsPerDay = filteredData.dayCount > 0 ? filteredData.totalSteps / Double(filteredData.dayCount) : 0
                    
                    // Store task and range on MainActor
                    let task = await MainActor.run {
                        self.recommendationRange = requestedRange
                        return Task<ComprehensiveRecommendations?, Never> {
                            // Check cancellation at start
                            guard !Task.isCancelled, requestedRange == selectedRange else {
                                print("⚠️ [Recommendations] Task cancelled or range changed at start")
                                return nil
                            }
                            
                            let comprehensiveRecs = await appleAI.generateComprehensiveRecommendations(
                                profile: profile,
                                patternInsights: patternsWithAI,
                                bodyCompositionPrediction: bodyCompositionPrediction,
                                rangeType: requestedRange.rawValue,
                                dayCount: filteredData.dayCount,
                                avgStepsPerDay: avgStepsPerDay
                            )
                            
                            // Check again before returning
                            guard !Task.isCancelled, requestedRange == selectedRange else {
                                print("⚠️ [Recommendations] Task cancelled or range changed after generation")
                                return nil // Discard result if range changed
                            }
                            
                            return comprehensiveRecs
                        }
                    }
                    
                    // Store the task reference
                    await MainActor.run {
                        self.recommendationTask = task
                    }
                    
                    // Wait for recommendation task to complete
                    let comprehensiveRecs = await task.value
                    
                    print("🔄 [Dashboard] Received result from generateComprehensiveRecommendations")
                    print("   - Result is nil: \(comprehensiveRecs == nil)")
                    if let recs = comprehensiveRecs {
                        print("   - Recommendations count: \(recs.topRecommendations.count)")
                    }
                    
                    await MainActor.run {
                        // Verify this result is still for the current range
                        guard recommendationRange == selectedRange else {
                            print("⚠️ [Recommendations] Range changed after generation - discarding result")
                            self.isLoadingRecommendations = false
                            return
                        }
                        
                        // Always cache recommendations even if range changed - they're valid for the requested range
                        if let recs = comprehensiveRecs {
                            print("✅ [Dashboard] Received comprehensive recommendations: \(recs.topRecommendations.count) recommendations")
                            print("   - Analyzed period: \(recs.analyzedPeriod)")
                            
                            // Cache the recommendations for future use (even if range changed)
                            if let appleAI = appState.appleIntelligence {
                                appleAI.cacheComprehensiveRecommendations(recs, for: rangeKey)
                                print("💾 [Dashboard] Cached comprehensive recommendations for '\(rangeKey)' (range changed: \(requestedRange != selectedRange))")
                            }
                            
                            // Only update UI if range hasn't changed
                            if requestedRange == selectedRange {
                                self.comprehensiveRecommendations = recs
                            } else {
                                print("⚠️ [Recommendations] Range changed while generating - cached but not showing in UI")
                            }
                        } else {
                            print("⚠️ [Dashboard] No comprehensive recommendations returned - setting to nil")
                            if requestedRange == selectedRange {
                                self.comprehensiveRecommendations = nil
                            }
                        }
                        
                        // Clear loading state
                        self.isLoadingRecommendations = false
                    }
                }
            } else {
                print("❌ [Dashboard] appleIntelligence is nil - cannot generate recommendations")
                await MainActor.run {
                    guard requestedRange == selectedRange else { return }
                    self.isLoadingRecommendations = false
                    self.comprehensiveRecommendations = nil
                }
            }
            
            await MainActor.run {
                // Double check range hasn't changed
                guard requestedRange == selectedRange else {
                    print("⚠️ [Cache] Range changed while processing, discarding UI update")
                    // Still cache the data even if range changed, as it's valid for the requested range
                    if let appleAI = appState.appleIntelligence,
                       let patternsToCache = capturedPatternInsights,
                       let efficiencyInsights = patternsToCache.efficiencyScore.categorizedInsights {
                        appleAI.cacheResponse(
                            for: rangeKey,
                            efficiencyInsights: efficiencyInsights,
                            patternInsights: patternsToCache,
                            healthInsight: basicInsight,
                            bodyCompositionPrediction: bodyCompositionPrediction
                        )
                        print("💾 [Cache] Cached data for '\(rangeKey)' even though range changed")
                    }
                    return
                }
                self.healthInsight = basicInsight
                self.bodyCompositionPrediction = bodyCompositionPrediction
                self.patternInsights = patternsWithAI
                
                
                self.isLoading = false
            }
            
            // Now fetch AI analysis in the background
            guard let appleAI = appState.appleIntelligence else {
                print("⚠️ [AI] AI not available - showing data only")
                return
            }
            
            // Check again before AI processing
            guard !Task.isCancelled, requestedRange == selectedRange else {
                print("⚠️ [AI] Task cancelled or range changed before AI processing, skipping AI for '\(rangeKey)'")
                // Still try to cache what we have so far (pattern insights)
                if let patternsToCache = capturedPatternInsights,
                   let efficiencyInsights = patternsToCache.efficiencyScore.categorizedInsights {
                    appleAI.cacheResponse(
                        for: rangeKey,
                        efficiencyInsights: efficiencyInsights,
                        patternInsights: patternsToCache,
                        healthInsight: basicInsight,
                        bodyCompositionPrediction: bodyCompositionPrediction
                    )
                    print("💾 [AI] Cached partial response (patterns only) for '\(rangeKey)' before cancellation")
                }
                return
            }
            
            // Check if health insights are already cached
            let needHealthInsights = await MainActor.run {
                if let cached = appState.appleIntelligence?.getCachedResponse(for: rangeKey),
                   cached.healthInsight != nil {
                    print("✅ [Cache] Using cached health insights, skipping generation")
                    if let cachedHealth = cached.healthInsight {
                        self.healthInsight = cachedHealth
                        self.isLoadingAI = false
                    }
                    return false
                }
                return true
            }
            
            if !needHealthInsights {
                // Already loaded from cache above
                return
            }
            
            // Health insight already created from filtered data above (basicInsight), just cache it
            // The healthInsight is created from HealthKit data, not AI analysis
            appleAI.cacheHealthInsight(basicInsight, for: rangeKey)
            
            // Only update UI if range hasn't changed
            await MainActor.run {
                guard !Task.isCancelled, requestedRange == selectedRange else {
                    if requestedRange != selectedRange {
                        print("⚠️ [Dashboard] Range changed before update (from '\(requestedRange.rawValue)' to '\(selectedRange.rawValue)'), skipping UI update but cache stored")
                    }
                    self.isLoadingAI = false
                    return
                }
                self.healthInsight = basicInsight
                self.isLoadingAI = false
                print("🎉 [UI] Dashboard updated for \(requestedRange.rawValue)")
            }
        }
    }
    
    /// Legacy refresh method - redirects to optimized pull-to-refresh handler
    private func refreshData() async {
        await handlePullToRefresh()
    }
    
    // MARK: - Targeted Refresh Functions
    
    /// Refresh only the efficiency insights AI response without reloading all data
    private func refreshEfficiencyInsights() {
        // Guard: Need patternInsights, user profile, and AI instance
        guard let currentPatterns = patternInsights,
              let profile = appState.userProfile,
              let appleAI = appState.appleIntelligence else {
            print("⚠️ [Efficiency Refresh] Missing required data or AI instance")
            return
        }
        
        let requestedRange = selectedRange
        let efficiency = currentPatterns.efficiencyScore
        
        // Set loading state immediately
        let loadingEfficiency = EfficiencyMetrics(
            workoutEfficiency: efficiency.workoutEfficiency,
            heartHealthEfficiency: efficiency.heartHealthEfficiency,
            fitnessGains: efficiency.fitnessGains,
            sleepEfficiency: efficiency.sleepEfficiency,
            hasWorkouts: efficiency.hasWorkouts,
            overallScore: efficiency.overallScore,
            insight: efficiency.insight,
            categorizedInsights: nil,
            isLoadingInsights: true
        )
        
        let loadingPatterns = PatternInsights(
            bestPerformingDays: currentPatterns.bestPerformingDays,
            comparisons: currentPatterns.comparisons,
            activeInactivePattern: currentPatterns.activeInactivePattern,
            efficiencyScore: loadingEfficiency,
            consistencyHeatmap: currentPatterns.consistencyHeatmap,
            plateauStatus: currentPatterns.plateauStatus
        )
        
        Task {
            await MainActor.run {
                self.patternInsights = loadingPatterns
            }
            
            // Generate AI insights with retry logic
            var categorizedInsights = await appleAI.generateEfficiencyInsight(
                profile: profile,
                workoutEfficiency: efficiency.workoutEfficiency,
                heartHealthEfficiency: efficiency.heartHealthEfficiency,
                fitnessGains: efficiency.fitnessGains,
                sleepEfficiency: efficiency.sleepEfficiency,
                hasWorkouts: efficiency.hasWorkouts,
                rangeType: requestedRange.rawValue
            )
            
            // Retry if invalid response (up to 2 retries)
            var retryCount = 0
            while !categorizedInsights.isValid && retryCount < 2 {
                print("⚠️ [Efficiency Refresh] Invalid response detected, retrying... (attempt \(retryCount + 2)/3)")
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check if range changed
                guard requestedRange == selectedRange else {
                    print("⚠️ [Efficiency Refresh] Range changed during retry, aborting")
                    break
                }
                
                categorizedInsights = await appleAI.generateEfficiencyInsight(
                    profile: profile,
                    workoutEfficiency: efficiency.workoutEfficiency,
                    heartHealthEfficiency: efficiency.heartHealthEfficiency,
                    fitnessGains: efficiency.fitnessGains,
                    sleepEfficiency: efficiency.sleepEfficiency,
                    hasWorkouts: efficiency.hasWorkouts,
                    rangeType: requestedRange.rawValue
                )
                retryCount += 1
            }
            
            // Update only the efficiency insights, keeping all other data unchanged
            let updatedEfficiency = EfficiencyMetrics(
                workoutEfficiency: efficiency.workoutEfficiency,
                heartHealthEfficiency: efficiency.heartHealthEfficiency,
                fitnessGains: efficiency.fitnessGains,
                sleepEfficiency: efficiency.sleepEfficiency,
                hasWorkouts: efficiency.hasWorkouts,
                overallScore: efficiency.overallScore,
                insight: efficiency.insight,
                categorizedInsights: categorizedInsights,
                isLoadingInsights: false
            )
            
            let updatedPatterns = PatternInsights(
                bestPerformingDays: currentPatterns.bestPerformingDays,
                comparisons: currentPatterns.comparisons,
                activeInactivePattern: currentPatterns.activeInactivePattern,
                efficiencyScore: updatedEfficiency,
                consistencyHeatmap: currentPatterns.consistencyHeatmap,
                plateauStatus: currentPatterns.plateauStatus
            )
            
            await MainActor.run {
                // Verify range hasn't changed before updating
                guard requestedRange == selectedRange else {
                    print("⚠️ [Efficiency Refresh] Range changed before update, discarding")
                    return
                }
                self.patternInsights = updatedPatterns
                print("✅ [Efficiency Refresh] Efficiency insights refreshed successfully")
            }
        }
    }
    
    private func requestHealthKitAccess() async {
        _ = await appState.healthKitManager.requestAuthorization()
    }
    
    private func fetchWorkouts(startDate: Date, endDate: Date) async -> [HKWorkout] {
        let workouts = await appState.healthKitManager.readWorkouts(limit: 50)
        // Filter workouts by date range
        return workouts.filter { workout in
            workout.startDate >= startDate && workout.endDate <= endDate
        }
    }
    
    // MARK: - Helper Functions
    
    private func mostCommonElement<T: Hashable>(in array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let counts = Dictionary(grouping: array, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    private func workoutTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Functional Training"
        case .hiking: return "Hiking"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .crossTraining, .crossCountrySkiing: return "Cross Training"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .mixedCardio: return "Cardio"
        default: return "Mixed"
        }
    }
    
    private func calculateActivityLevel(stepsPerDay: Double, caloriesPerDay: Double, workoutsPerWeek: Double) -> String {
        var level = ""
        
        // Determine activity level based on steps
        if stepsPerDay >= 10000 {
            level = "Very Active"
        } else if stepsPerDay >= 7500 {
            level = "Active"
        } else if stepsPerDay >= 5000 {
            level = "Moderately Active"
        } else {
            level = "Low Activity"
        }
        
        // Refine based on workouts
        let workoutDescription: String
        if workoutsPerWeek >= 6 {
            workoutDescription = "6-7 workouts per week"
        } else if workoutsPerWeek >= 4 {
            workoutDescription = "4-5 workouts per week"
        } else if workoutsPerWeek >= 2 {
            workoutDescription = "2-3 workouts per week"
        } else if workoutsPerWeek >= 1 {
            workoutDescription = "1 workout per week"
        } else {
            workoutDescription = "occasional workouts"
        }
        
        return "\(level) (\(workoutDescription))"
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return variance / (mean > 0 ? mean : 1) // Coefficient of variation
    }
    
    private func convertToHealthInsightFromFilteredData(
        filteredData: FilteredHealthData,
        dayCount: Int,
        profile: UserProfile,
        bodyCompositionPrediction: BodyCompositionPrediction
    ) -> HealthInsight {
        // Calculate averages from totals
        let avgDailySteps = dayCount > 0 ? filteredData.totalSteps / Double(dayCount) : 0
        let avgDailyDistanceKM = dayCount > 0 ? filteredData.distanceKM / Double(dayCount) : 0
        let avgActiveCal = dayCount > 0 ? filteredData.activeCalories / Double(dayCount) : 0
        let avgTotalCal = dayCount > 0 ? filteredData.totalCalories / Double(dayCount) : 0
        let avgSleepHours = dayCount > 0 ? filteredData.totalSleepHours / Double(dayCount) : 0
        
        let weeklySummary = WeeklySummary(
            totalSteps: filteredData.totalSteps,
            avgDailySteps: avgDailySteps,
            totalDistanceKM: filteredData.distanceKM,
            avgDailyDistanceKM: avgDailyDistanceKM,
            activeCalories: filteredData.activeCalories,
            totalCalories: filteredData.totalCalories,
            avgActiveCalories: avgActiveCal,
            avgTotalCalories: avgTotalCal,
            avgHeartRate: filteredData.avgHeartRate,
            workoutCount: filteredData.workoutCount,
            totalWorkoutMinutes: filteredData.totalWorkoutMinutes,
            totalSleepHours: filteredData.totalSleepHours,
            avgSleepHours: avgSleepHours,
            avgBloodOxygen: filteredData.avgBloodOxygen,
            avgCardioFitness: filteredData.avgCardioFitness
        )
        
        // Use calculated body composition from prediction
        let bodyComposition = BodyCompositionEstimate(
            estimatedFatLoss: bodyCompositionPrediction.fatLoss,
            estimatedMuscleGain: bodyCompositionPrediction.muscleGain,
            currentWeight: profile.weight,
            estimatedCurrentWeight: profile.weight - bodyCompositionPrediction.netWeightChange,
            desiredWeight: nil
        )
        
        return HealthInsight(
            progressScore: 0,
            bodyComposition: bodyComposition,
            recommendations: [],
            weeklySummary: weeklySummary,
            estimatedFatLoss: 0,
            estimatedMuscleGain: 0
        )
    }
    
    // REMOVED: convertToHealthInsight(), calculateBodyComposition(), calculateProgressFromAI() - no longer needed since analyzeWithAppleIntelligence() was removed
}

// MARK: - Progress Score Card

struct ProgressScoreCard: View {
    let progressScore: Int
    let predictions: (timelineToGoal: String, warnings: [String], dimensions: [(name: String, score: Int, insight: String)])?
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 20
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 40 : 24
    }
    
    var body: some View {
        ModernCard(shadowColor: progressColor.opacity(0.2)) {
            VStack(spacing: adaptiveSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Progress")
                            .font(.responsiveHeadline())
                        Text("Multi-dimensional analysis")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .responsiveIcon()
                        .foregroundColor(progressColor)
                }
                
                if let preds = predictions {
                    // Carousel with dimension cards + predictions page
                    let allPages = buildPages(dimensions: preds.dimensions, timeline: preds.timelineToGoal, warnings: preds.warnings)
                    
                    VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                        TabView(selection: $currentPage) {
                            // Dimension score pages
                            ForEach(Array(allPages.enumerated()), id: \.offset) { pageIndex, page in
                                page
                                    .tag(pageIndex)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: horizontalSizeClass == .regular ? 280 : 220)
                        
                        // Page indicator
                        if allPages.count > 1 {
                            HStack(spacing: 8) {
                                ForEach(0..<allPages.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .animation(.easeInOut, value: currentPage)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } else {
                    // Fallback: Show overall score
                    HStack(spacing: horizontalSizeClass == .regular ? 40 : 30) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: horizontalSizeClass == .regular ? 18 : 14)
                            Circle()
                                .trim(from: 0, to: CGFloat(progressScore) / 100)
                                .stroke(progressColor, style: StrokeStyle(lineWidth: horizontalSizeClass == .regular ? 18 : 14, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 4) {
                                Text("\(progressScore)")
                                    .font(.system(size: horizontalSizeClass == .regular ? 64 : 48, weight: .bold, design: .rounded))
                                    .foregroundColor(progressColor)
                                Text("points")
                                    .font(.responsiveCaption())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: horizontalSizeClass == .regular ? 200 : 150, height: horizontalSizeClass == .regular ? 200 : 150)
                        
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 16 : 12) {
                            StatLabel(icon: "target", value: goalMessage, color: progressColor)
                            StatLabel(icon: "star.fill", value: performanceLevel, color: performanceColor)
                        }
                        .padding(.leading, horizontalSizeClass == .regular ? 8 : 4)
                    }
                }
            }
            .padding(adaptivePadding)
        }
    }
    
    private func buildPages(dimensions: [(name: String, score: Int, insight: String)], timeline: String, warnings: [String]) -> [AnyView] {
        var pages: [AnyView] = []
        
        // Add dimension score pages (4 pages)
        for dimension in dimensions {
            pages.append(AnyView(
                DimensionScoreView(
                    name: dimension.name,
                    score: dimension.score,
                    insight: dimension.insight
                )
            ))
        }
        
        // Add predictions page (last page)
        pages.append(AnyView(
            PredictionsView(
                timeline: timeline,
                warnings: warnings
            )
        ))
        
        return pages
    }
    
    private var progressColor: Color {
        switch progressScore {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private var goalMessage: String {
        switch progressScore {
        case 80...100: return "Exceeding Goals"
        case 60..<80: return "On Track"
        default: return "Needs Attention"
        }
    }
    
    private var performanceLevel: String {
        switch progressScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        default: return "Improve"
        }
    }
    
    private var performanceColor: Color {
        progressColor.opacity(0.8)
    }
}

// MARK: - Dimension Score View

struct DimensionScoreView: View {
    let name: String
    let score: Int
    let insight: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private var icon: String {
        switch name {
        case "Body & Fitness Analysis", "Body Composition": return "scalemass.fill"
        case "Activity Consistency": return "figure.run"
        case "Recovery Quality": return "bed.double.fill"
        case "Goal Progress": return "target"
        default: return "star.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: horizontalSizeClass == .regular ? 24 : 20) {
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: horizontalSizeClass == .regular ? 16 : 12)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: horizontalSizeClass == .regular ? 16 : 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: horizontalSizeClass == .regular ? 32 : 24))
                        .foregroundColor(scoreColor)
                    Text("\(score)")
                        .font(.system(size: horizontalSizeClass == .regular ? 48 : 36, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
            }
            .frame(width: horizontalSizeClass == .regular ? 180 : 140, height: horizontalSizeClass == .regular ? 180 : 140)
            
            // Dimension name and insight
            VStack(spacing: 8) {
                Text(name)
                    .font(.responsiveHeadline())
                    .multilineTextAlignment(.center)
                
                Text(insight)
                    .font(.responsiveBody())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, horizontalSizeClass == .regular ? 16 : 12)
    }
}

// MARK: - Predictions View

struct PredictionsView: View {
    let timeline: String
    let warnings: [String]
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            // Timeline Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Timeline to Goal")
                        .font(.responsiveBody())
                        .fontWeight(.semibold)
                }
                
                Text(timeline)
                    .font(.system(size: horizontalSizeClass == .regular ? 32 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.leading, 24)
            }
            
            // Warnings Section (if any)
            if !warnings.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Warnings")
                            .font(.responsiveBody())
                            .fontWeight(.semibold)
                    }
                    
                    ForEach(warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.orange)
                                .padding(.top, 6)
                            Text(warning)
                                .font(.responsiveBody())
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 24)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DeviceType.isIPad ? 16 : 12)
    }
}

struct StatLabel: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: DeviceType.isIPad ? 16 : 14))
                .foregroundColor(color)
            Text(value)
                .font(.responsiveCaption())
                .fontWeight(.medium)
        }
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 20
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 20
    }
    
    private var adaptiveCardHeight: CGFloat {
        horizontalSizeClass == .regular ? 140.0 : 99.0
    }
    
    private var adaptiveCardSpacing: CGFloat {
        horizontalSizeClass == .regular ? 16.0 : 12.0
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: adaptiveSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Summary")
                            .font(.responsiveHeadline())
                        Text("Your health metrics")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .responsiveIcon()
                        .foregroundColor(.blue)
                }
                
                // Horizontal scrolling carousel with 2 cards per page (1 column, 2 rows)
                let statCards = buildStatCards(summary: summary)
                let chunks = statCards.chunked(into: 2)
                // Card height: frame (75/90) + padding top/bottom (24/32) = ~99/122
                let singleCardHeight = adaptiveCardHeight
                let spacing = adaptiveCardSpacing
                let chunkHeight = (singleCardHeight * 2) + spacing
                
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ForEach(Array(chunks.enumerated()), id: \.offset) { index, cardPair in
                            VStack(alignment: .leading, spacing: DeviceType.isIPad ? 16 : 12) {
                                ForEach(cardPair.indices, id: \.self) { cardIndex in
                                    cardPair[cardIndex]
                                }
                                // Spacer to push single card to top
                                if cardPair.count == 1 {
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, horizontalSizeClass == .regular ? 8 : 4)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: chunkHeight)
                    .padding(.vertical, horizontalSizeClass == .regular ? 8 : 4)
                    
                    // Custom pagination dots below the cards
                    if chunks.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<chunks.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, DeviceType.isIPad ? 12 : 8)
                    }
                }
            }
            .padding(adaptivePadding)
        }
    }
    
    // Helper function to build all stat cards
    private func buildStatCards(summary: WeeklySummary) -> [AnyView] {
        var cards: [AnyView] = []
        
        // Page 1: Active and Total Calories together
        // Active Calories (with kcal unit)
        cards.append(AnyView(
                    StatView(
                value: formatKcal(summary.activeCalories),
                label: "Active Calories",
                        icon: "flame.fill",
                        color: .orange
                    )
        ))
                    
        // Total Calories (with kcal unit)
        cards.append(AnyView(
                    StatView(
                value: formatKcal(summary.totalCalories),
                label: "Total Calories",
                        icon: "bolt.fill",
                        color: .yellow
                    )
        ))
        
        // Page 2: Steps and Workouts together
        // Steps & Distance
        cards.append(AnyView(
            StepsDistanceView(
                steps: summary.totalSteps,
                distanceKM: summary.totalDistanceKM,
                icon: "figure.walk",
                color: .blue
            )
        ))
        
        // Workouts - show minutes as main value, workout count in parentheses (like steps/distance)
        cards.append(AnyView(
            WorkoutView(
                minutes: summary.totalWorkoutMinutes,
                workoutCount: summary.workoutCount,
                icon: "dumbbell.fill",
                color: .purple
            )
        ))
                    
                    // Heart Rate
                    if let heartRate = summary.avgHeartRate {
            cards.append(AnyView(
                        StatView(
                            value: String(format: "%.0f", heartRate),
                            label: "Avg HR (BPM)",
                            icon: "heart.fill",
                            color: .red
                        )
            ))
        }
                    
                    // Sleep
        cards.append(AnyView(
                    StatView(
                        value: String(format: "%.1f", summary.avgSleepHours),
                        label: "Sleep (hours)",
                        icon: "bed.double.fill",
                        color: .mint
                    )
        ))
                    
                    // Blood Oxygen
                    if let bloodOxygen = summary.avgBloodOxygen {
                        // HealthKit stores oxygen saturation as decimal (0.0-1.0), convert to percentage (0-100)
                        let displayValue = bloodOxygen * 100
            cards.append(AnyView(
                        StatView(
                            value: String(format: "%.1f", displayValue),
                            label: "SpO2 (%)",
                            icon: "lungs.fill",
                            color: .teal
                        )
            ))
                    }
                    
                    // Cardio Fitness - always show, use "-" if no value
            cards.append(AnyView(
                        StatView(
                            value: summary.avgCardioFitness != nil ? String(format: "%.1f", summary.avgCardioFitness!) : "—",
                            label: "VO2 Max",
                            icon: "figure.run",
                            color: .green
                        )
            ))
        
        return cards
    }
}

// Extension to chunk array into groups
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct StatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var mainValue: String {
        if value.contains("(kcal)") {
            let parts = value.components(separatedBy: " (kcal)")
            return parts.isEmpty ? value : parts[0]
        }
        return value
    }
    
    private var hasKcal: Bool {
        value.contains("(kcal)")
    }
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 18 : 14) {
            Image(systemName: icon)
                .font(.system(size: horizontalSizeClass == .regular ? 36 : 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: horizontalSizeClass == .regular ? 72 : 52, height: horizontalSizeClass == .regular ? 72 : 52)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
            
            VStack(alignment: .leading, spacing: 4) {
                // Check if value contains (kcal) and split it
                if hasKcal {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        // Main value - number
                        Text(mainValue)
                            .font(.system(
                                size: horizontalSizeClass == .regular ? 32 : 20,
                                weight: .bold,
                                design: .rounded
                            ))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        // (kcal) - secondary value (smaller, in parentheses)
                        Text("(kcal)")
                            .font(.system(
                                size: horizontalSizeClass == .regular ? 22 : 15,
                                weight: .medium,
                                design: .rounded
                            ))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Regular value display
                    Text(value)
                        .font(.system(
                            size: horizontalSizeClass == .regular ? 32 : 20,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text(label)
                    .font(.system(
                        size: horizontalSizeClass == .regular ? 18 : 13,
                        weight: .medium
                    ))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: horizontalSizeClass == .regular ? 110 : 75)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DeviceType.isIPad ? 14 : 12))
    }
}

// MARK: - Steps & Distance View

struct StepsDistanceView: View {
    let steps: Double
    let distanceKM: Double
    let icon: String
    let color: Color
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 18 : 14) {
            Image(systemName: icon)
                .font(.system(size: horizontalSizeClass == .regular ? 36 : 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: horizontalSizeClass == .regular ? 72 : 52, height: horizontalSizeClass == .regular ? 72 : 52)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
            
            VStack(alignment: .leading, spacing: 4) {
                // Steps and Distance on same line
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // Steps - main value
                    Text(formatSteps(steps))
                        .font(.system(
                            size: horizontalSizeClass == .regular ? 32 : 20,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Distance - secondary value (smaller, in parentheses)
                    Text("(\(formatDistance(distanceKM)))")
                        .font(.system(
                            size: horizontalSizeClass == .regular ? 22 : 15,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Steps & Distance")
                    .font(.system(
                        size: horizontalSizeClass == .regular ? 18 : 13,
                        weight: .medium
                    ))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: horizontalSizeClass == .regular ? 110 : 75)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
    }
    
    private func formatSteps(_ steps: Double) -> String {
        // More compact formatting for large numbers
        if steps >= 10000 {
            return String(format: "%.1fK", steps / 1000.0)
        } else if steps >= 1000 {
            return String(format: "%.0fK", steps / 1000.0)
        } else {
            return String(format: "%.0f", steps)
        }
    }
    
    private func formatDistance(_ km: Double) -> String {
        // Compact format - always show in km, fewer decimals for large values
        if km >= 10 {
            return String(format: "%.0f km", km)
        } else if km >= 1 {
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.2f km", km)
        }
    }
}

// MARK: - Workout View

struct WorkoutView: View {
    let minutes: Double
    let workoutCount: Int
    let icon: String
    let color: Color
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 18 : 14) {
            Image(systemName: icon)
                .font(.system(size: horizontalSizeClass == .regular ? 36 : 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: horizontalSizeClass == .regular ? 72 : 52, height: horizontalSizeClass == .regular ? 72 : 52)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
            
            VStack(alignment: .leading, spacing: 4) {
                // Minutes and Workout Count on same line
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // Minutes - main value
                    Text(formatMinutes(minutes))
                        .font(.system(
                            size: DeviceType.isIPad ? 26 : 20,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Workout Count - secondary value (smaller, in parentheses)
                    Text("(\(workoutCount))")
                        .font(.system(
                            size: DeviceType.isIPad ? 18 : 15,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Workouts")
                    .font(.system(
                        size: horizontalSizeClass == .regular ? 18 : 13,
                        weight: .medium
                    ))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: horizontalSizeClass == .regular ? 110 : 75)
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DeviceType.isIPad ? 14 : 12))
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if mins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(mins)m"
            }
        } else {
            return "\(totalMinutes)m"
        }
    }
}

// MARK: - Body Composition Card

struct BodyCompositionCard: View {
    let composition: BodyCompositionEstimate
    let prediction: BodyCompositionPrediction?
    let isCalculatingDesiredWeight: Bool
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 20
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 20
    }
    
    // Computed property to build all metrics
    private var allMetricsPages: [[(icon: String, title: String, value: String, color: Color)]] {
        guard let pred = prediction else { return [] }
        
        // Build all metrics into an array - ordered by importance (most important first)
        var allMetrics: [(icon: String, title: String, value: String, color: Color)] = []
        
        // ===== MOST IMPORTANT: Primary Body Composition Changes =====
        allMetrics.append(("arrow.down.circle.fill", "Fat Loss", "\(String(format: "%.2f", pred.fatLoss)) kg", .green))
        allMetrics.append(("arrow.up.circle.fill", "Muscle Gain", "+\(String(format: "%.2f", pred.muscleGain)) kg", .blue))
        allMetrics.append(("scale.3d", "Net Weight Change", "\(String(format: "%.2f", pred.netWeightChange > 0 ? pred.netWeightChange : abs(pred.netWeightChange))) kg", pred.netWeightChange > 0 ? .red : .green))
        allMetrics.append(("arrow.down.square.fill", "Muscle Loss", "\(String(format: "%.2f", pred.muscleLoss)) kg", .orange))
        
        // ===== VERY IMPORTANT: Body Composition Details =====
        allMetrics.append(("figure.strengthtraining.traditional", "Lean Body Mass Change", "\(String(format: "%.2f", pred.leanBodyMassChange)) kg", .blue))
        allMetrics.append(("percent", "Body Fat Mass Change", "\(String(format: "%.2f", pred.bodyFatMassChange)) kg", .green))
        if let bfChange = pred.bodyFatPercentageChange {
            allMetrics.append(("chart.pie.fill", "Body Fat % Change", "\(String(format: "%.2f", bfChange > 0 ? bfChange : abs(bfChange)))%", bfChange < 0 ? .green : .orange))
        } else {
            allMetrics.append(("chart.pie.fill", "Body Fat % Change", "—", .secondary))
        }
        if let waistChange = pred.waistCircumferenceChange {
            allMetrics.append(("ruler.fill", "Waist Circumference Change", "\(String(format: "%.1f", waistChange > 0 ? waistChange : abs(waistChange))) cm", waistChange < 0 ? .green : .orange))
        } else {
            allMetrics.append(("ruler.fill", "Waist Circumference Change", "—", .secondary))
        }
        if let currentLBM = pred.currentLeanBodyMass {
            allMetrics.append(("scalemass.fill", "Current Lean Body Mass", "\(String(format: "%.2f", currentLBM)) kg", .blue))
        } else {
            allMetrics.append(("scalemass.fill", "Current Lean Body Mass", "—", .secondary))
        }
        
        // ===== IMPORTANT: Metabolic Impact =====
        allMetrics.append(("scalemass", "Calorie Base", "\(formatKcal(pred.maintenanceCalories))", .secondary))
        allMetrics.append(("bolt.fill", "New Calorie Base", "\(formatKcal(pred.newMaintenanceCalories))", .purple))
        allMetrics.append(("flame.fill", "Calorie Burn", "\(formatKcal(pred.calorieDeficit))", .green))
        allMetrics.append(("arrow.up.circle.fill", "Calorie Gain", "\(formatKcal(pred.calorieSurplus))", .blue))
        allMetrics.append(("flame.fill", "BMR Increase", "\(formatKcal(pred.bmrIncrease))/day", .orange))
        
        // ===== MODERATELY IMPORTANT: Fitness Improvements =====
        allMetrics.append(("dumbbell.fill", "Strength Gain", "\(String(format: "%.1f", pred.strengthGain))%", .blue))
        allMetrics.append(("figure.run", "Endurance Gain", "\(String(format: "%.1f", pred.enduranceGain))%", .green))
        if let vo2Improvement = pred.vo2MaxImprovement {
            allMetrics.append(("lungs.fill", "VO₂ Max Improvement", "+\(String(format: "%.2f", vo2Improvement))", .teal))
        } else {
            allMetrics.append(("lungs.fill", "VO₂ Max Improvement", "—", .secondary))
        }
        allMetrics.append(("battery.100.bolt", "Energy Level", "\(String(format: "%.0f", pred.energyLevelImprovement))%", .yellow))
        
        // ===== MODERATELY IMPORTANT: Recovery & Health =====
        allMetrics.append(("bed.double.fill", "Recovery Score", "\(String(format: "%.0f", pred.recoveryQualityScore))%", recoveryColor(for: pred.recoveryQualityScore)))
        allMetrics.append(("exclamationmark.triangle.fill", "Overtraining Risk", riskText(pred.overtrainingRisk), riskColor(pred.overtrainingRisk)))
        
        // ===== LESS IMPORTANT: Activity Summary (contextual info) =====
        allMetrics.append(("dumbbell", "Strength Workouts", "\(pred.strengthWorkoutCount)", .blue))
        allMetrics.append(("figure.run", "Cardio Workouts", "\(pred.cardioWorkoutCount)", .green))
        allMetrics.append(("clock.fill", "Workout Minutes", "\(String(format: "%.0f", pred.totalWorkoutMinutes))", .orange))
        allMetrics.append(("moon.zzz.fill", "Avg Sleep Hours", "\(String(format: "%.1f", pred.avgSleepHours))", .indigo))
        
        // Split into chunks of 8
        let metricsPerPage = 8
        return stride(from: 0, to: allMetrics.count, by: metricsPerPage).map {
            Array(allMetrics[$0..<min($0 + metricsPerPage, allMetrics.count)])
        }
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: adaptiveSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body & Fitness Analysis")
                            .font(.responsiveHeadline())
                        Text("Detailed analysis")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "scalemass.fill")
                        .responsiveIcon()
                        .foregroundColor(.purple)
                }
                
                if prediction != nil {
                    let pages = allMetricsPages
                    
                    // Carousel with TabView
                    VStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
                        TabView(selection: $currentPage) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageMetrics in
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: horizontalSizeClass == .regular ? 16 : 12),
                                        GridItem(.flexible(), spacing: horizontalSizeClass == .regular ? 16 : 12)
                                    ],
                                    spacing: horizontalSizeClass == .regular ? 16 : 12
                                ) {
                                    ForEach(Array(pageMetrics.enumerated()), id: \.offset) { _, metric in
                                        MetricItem(
                                            icon: metric.icon,
                                            title: metric.title,
                                            value: metric.value,
                                            color: metric.color
                                        )
                                    }
                                }
                                .padding(.horizontal, horizontalSizeClass == .regular ? 8 : 4)
                                .tag(pageIndex)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: calculatePageHeight(pages: pages))
                        
                        // Custom page indicator
                        if pages.count > 1 {
                            HStack(spacing: 8) {
                                ForEach(0..<pages.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .animation(.easeInOut, value: currentPage)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, DeviceType.isIPad ? 8 : 4)
                } else {
                    // Fallback to simple view if prediction not available
                    VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
                        if composition.estimatedFatLoss > 0 {
                            MetricRow(
                                icon: "arrow.down.circle.fill",
                                title: "Estimated Fat Loss",
                                value: "\(String(format: "%.2f", abs(composition.estimatedFatLoss))) kg",
                                color: .green
                            )
                        }
                        
                        if composition.estimatedMuscleGain > 0 {
                            MetricRow(
                                icon: "arrow.up.circle.fill",
                                title: "Estimated Muscle Gain",
                                value: "+\(String(format: "%.2f", composition.estimatedMuscleGain)) kg",
                                color: .blue
                            )
                        }
                    }
                }
            }
            .padding(adaptivePadding)
        }
    }
    
    private func recoveryColor(for score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }
    
    private func riskColor(_ risk: OvertrainingRisk) -> Color {
        switch risk {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .red
        }
    }
    
    private func riskText(_ risk: OvertrainingRisk) -> String {
        switch risk {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
    
    private func calculatePageHeight(pages: [[(icon: String, title: String, value: String, color: Color)]]) -> CGFloat {
        guard !pages.isEmpty else { return 200 }
        // Calculate based on number of rows (4 rows = 8 metrics in 2 columns)
        let maxMetricsOnPage = pages.map { $0.count }.max() ?? 8
        let numberOfRows = ceil(Double(maxMetricsOnPage) / 2.0)
        
        // Each row needs approximately 80-100 points of height (including spacing)
        // Note: This function needs access to size class, but it's a static helper
        // Using device type as fallback for now
        let rowHeight = DeviceType.isIPad ? 100.0 : 80.0
        let spacing = DeviceType.isIPad ? 16.0 : 12.0
        let totalSpacing = spacing * (numberOfRows - 1)
        let totalHeight = (rowHeight * numberOfRows) + totalSpacing
        
        return CGFloat(totalHeight)
    }
}

struct MetricItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @State private var showTooltip = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var tooltipText: String {
        BodyCompositionTooltips.tooltip(for: title)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 16)
                HStack(alignment: .top, spacing: 4) {
                    Text(title)
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    Button(action: { showTooltip = true }) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showTooltip, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                                .fontWeight(.semibold)
                            
                            Text(tooltipText)
                                .font(.system(size: horizontalSizeClass == .regular ? 13 : 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(horizontalSizeClass == .regular ? 14 : 12)
                        .frame(width: horizontalSizeClass == .regular ? 300 : 260)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                Spacer()
            }
            Text(value)
                .font(.responsiveBody())
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(horizontalSizeClass == .regular ? 12 : 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 16 : 12) {
            Image(systemName: icon)
                .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                .foregroundColor(color)
                .frame(width: horizontalSizeClass == .regular ? 48 : 40, height: horizontalSizeClass == .regular ? 48 : 40)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.responsiveCaption())
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.responsiveBody())
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(horizontalSizeClass == .regular ? 12 : 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 16 : 12))
    }
}

// MARK: - Comprehensive Recommendations Card

struct ComprehensiveRecommendationsCard: View {
    let recommendations: ComprehensiveRecommendations?
    let isLoading: Bool
    @State private var currentPage = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 32 : 28
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 20
    }
    
    var body: some View {
        ModernCard(shadowColor: Color.purple.opacity(0.2)) {
            VStack(alignment: .leading, spacing: adaptiveSpacing) {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .responsiveIcon()
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coach Recommendations")
                                .font(.responsiveHeadline())
                            if let recommendations = recommendations {
                                Text(recommendations.analyzedPeriod)
                                    .font(.responsiveCaption())
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Preparing analysis...")
                                    .font(.responsiveCaption())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .responsiveIcon()
                        .foregroundColor(.purple)
                }
                
                if isLoading {
                    // Loading state inside the card
                    VStack(spacing: horizontalSizeClass == .regular ? 20 : 16) {
                        ProgressView()
                            .scaleEffect(horizontalSizeClass == .regular ? 1.3 : 1.1)
                            .tint(.purple)
                        Text("Analyzing your metrics please wait")
                            .font(.responsiveBody())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, horizontalSizeClass == .regular ? 60 : 40)
                } else if let recommendations = recommendations {
                    let sortedRecommendations = recommendations.topRecommendations.sorted(by: { $0.priority < $1.priority })
                    
                    TabView(selection: $currentPage) {
                        ForEach(Array(sortedRecommendations.enumerated()), id: \.element.id) { index, action in
                            CoachActionCard(action: action)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: horizontalSizeClass == .regular ? 500 : 450)
                    .id("\(recommendations.analyzedPeriod)-\(recommendations.topRecommendations.count)")
                    .onChange(of: recommendations.analyzedPeriod) { oldValue, newValue in
                        currentPage = 0
                    }
                    .onChange(of: recommendations.topRecommendations.count) { oldValue, newValue in
                        currentPage = 0
                    }
                }
            }
            .padding(adaptivePadding)
        }
    }
}

struct CoachActionCard: View {
    let action: CoachAction
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var categoryColor: Color {
        switch action.category {
        case .cardio: return .red
        case .strength: return .blue
        case .nutrition: return .green
        case .recovery: return .purple
        case .activity: return .orange
        case .calories: return .pink
        }
    }
    
    private var categoryIcon: String {
        switch action.category {
        case .cardio: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .nutrition: return "fork.knife"
        case .recovery: return "bed.double.fill"
        case .activity: return "figure.walk"
        case .calories: return "flame.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DeviceType.isIPad ? 12 : 10) {
            // Header with priority and category
            HStack(alignment: .top, spacing: 10) {
                // Priority badge
                Text("\(action.priority)")
                    .font(.system(size: DeviceType.isIPad ? 18 : 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: DeviceType.isIPad ? 32 : 28, height: DeviceType.isIPad ? 32 : 28)
                    .background(categoryColor)
                    .clipShape(Circle())
                
                // Category and command
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: DeviceType.isIPad ? 14 : 12))
                            .foregroundColor(categoryColor)
                        Text(action.category.rawValue)
                            .font(.responsiveCaption())
                            .fontWeight(.medium)
                            .foregroundColor(categoryColor)
                    }
                    Text(action.command)
                        .font(.responsiveBody())
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Estimated indicator
                if action.isEstimated {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DeviceType.isIPad ? 14 : 12))
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Current → Target
            if !action.currentState.isEmpty || !action.targetState.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !action.currentState.isEmpty {
                        HStack(spacing: 6) {
                            Text("Current:")
                                .font(.responsiveCaption())
                                .foregroundColor(.secondary)
                            Text(action.currentState)
                                .font(.responsiveCaption())
                                .fontWeight(.medium)
                        }
                    }
                    if !action.targetState.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: DeviceType.isIPad ? 10 : 9))
                                .foregroundColor(categoryColor)
                            Text("Target:")
                                .font(.responsiveCaption())
                                .foregroundColor(.secondary)
                            Text(action.targetState)
                                .font(.responsiveCaption())
                                .fontWeight(.semibold)
                                .foregroundColor(categoryColor)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            
            // Impact
            if !action.impact.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: DeviceType.isIPad ? 12 : 10))
                        .foregroundColor(categoryColor)
                    Text(action.impact)
                        .font(.responsiveCaption())
                        .fontWeight(.medium)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)
            }
            
            // Why
            if !action.why.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                    Text(action.why)
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Health benefit
            if let health = action.healthBenefit, !health.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: DeviceType.isIPad ? 10 : 9))
                        .foregroundColor(.red)
                    Text(health)
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(DeviceType.isIPad ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: DeviceType.isIPad ? 14 : 12)
                .fill(categoryColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DeviceType.isIPad ? 14 : 12)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: horizontalSizeClass == .regular ? 48 : 40))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.responsiveBody())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
            .padding(horizontalSizeClass == .regular ? 40 : 20)
        .background(
            RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 20 : 16)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Pattern Insights Card

struct PatternInsightsCard: View {
    let insights: PatternInsights
    let onRetry: () -> Void
    @State private var currentPage = 0
    @State private var showPaywall = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private let tabLabels = ["Comparisons", "Efficiency"]
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 20
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 36 : 20
    }
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 12 : 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comparisons & Efficiency")
                            .font(.responsiveHeadline())
                        Text("Activity insights")
                            .font(.responsiveCaption())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .responsiveIcon()
                        .foregroundColor(.blue)
                }
                
                // Carousel with swipeable pages
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ComparisonsView(comparisons: insights.comparisons)
                            .tag(0)
                        
                        // Efficiency tab - check subscription
                        Group {
                            if subscriptionManager.isSubscribed {
                                EfficiencyView(
                                    efficiency: insights.efficiencyScore,
                                    onRetry: onRetry
                                )
                            } else {
                                // Show locked view for Efficiency when not subscribed
                                SubscriptionLockedView(
                                    featureName: "Efficiency Analysis",
                                    featureIcon: "chart.line.uptrend.xyaxis",
                                    onUpgrade: {
                                        showPaywall = true
                                    }
                                )
                            }
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: DeviceType.isIPad ? 520 : 440)
                    .onChange(of: currentPage) { oldValue, newValue in
                        // Check subscription when user tries to view Efficiency tab
                        if newValue == 1 && !subscriptionManager.isSubscribed {
                            Task {
                                await subscriptionManager.checkSubscriptionStatus()
                            }
                        }
                    }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                            .onDisappear {
                                // Refresh subscription status when paywall is dismissed
                                Task {
                                    await subscriptionManager.checkSubscriptionStatus()
                                }
                            }
                    }
                    .task {
                        // Check subscription status when view appears
                        await subscriptionManager.checkSubscriptionStatus()
                    }
                    
                    // Tab labels and page indicators at bottom center
                    VStack(spacing: DeviceType.isIPad ? 12 : 8) {
                        // Tab label
                        Text(tabLabels[currentPage])
                            .font(.responsiveBody())
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Page indicators (dots)
                        HStack(spacing: 8) {
                            ForEach(0..<tabLabels.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? Color.blue : Color.secondary.opacity(0.3))
                                    .frame(width: DeviceType.isIPad ? 10 : 8, height: DeviceType.isIPad ? 10 : 8)
                                    .animation(.easeInOut, value: currentPage)
                            }
                        }
                    }
                    .padding(.top, DeviceType.isIPad ? 8 : 4)
                }
            }
            .padding(adaptivePadding)
        }
    }
}

// MARK: - Comparisons View (replaces Best Days)

struct ComparisonsView: View {
    let comparisons: ComparisonInsights
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: DeviceType.isIPad ? 8 : 6)
            
            Text(comparisons.periodLabel)
                .font(.responsiveBody())
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Spacer()
                .frame(height: DeviceType.isIPad ? 20 : 16)
            
            if comparisons.metrics.isEmpty {
                Text("No comparison data available")
                    .font(.responsiveCaption())
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DeviceType.isIPad ? 12 : 8) {
                    ForEach(Array(comparisons.metrics.prefix(9).enumerated()), id: \.offset) { _, m in
                        HStack {
                            Text(m.name)
                                .font(.responsiveBody())
                            Spacer()
                            HStack(spacing: 6) {
                                if let change = m.absoluteChange, let pct = m.percentChange {
                                    Image(systemName: m.direction == .improving ? "arrow.up.right" : (m.direction == .declining ? "arrow.down.right" : "minus"))
                                        .font(.caption)
                                        .foregroundColor(m.direction == .improving ? .green : (m.direction == .declining ? .orange : .secondary))
                                    Text(formattedChange(change: change, percent: pct, name: m.name, direction: m.direction))
                                        .font(.responsiveCaption())
                                        .foregroundColor(m.direction == .improving ? .green : (m.direction == .declining ? .orange : .secondary))
                                } else {
                                    Text("—")
                                        .font(.responsiveCaption())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, DeviceType.isIPad ? 8 : 6)
                        .padding(.horizontal, DeviceType.isIPad ? 12 : 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DeviceType.isIPad ? 12 : 10))
                    }
                }
            }
        }
    }
}

private func formattedChange(change: Double, percent: Double, name: String, direction: TrendDirection) -> String {
    // For blood oxygen, show only the percentage change (the absolute change in percentage points)
    if name.contains("Blood Oxygen") {
        let signedChange = change >= 0 ? "+" : "-"
        let changeAbs = abs(change)
        let changeStr = String(format: "%.1f", changeAbs)
        // Remove trailing .0 if present
        let finalStr = changeStr.hasSuffix(".0") ? String(changeStr.dropLast(2)) : changeStr
        return "\(signedChange)\(finalStr)%"
    }
    
    // For heart rate (lower is better), when improving (negative change), show absolute value with positive percentage
    if name.contains("Heart Rate") && direction == .improving && change < 0 {
        let changeAbs = abs(change)
        let changeStr = compactNumberString(value: changeAbs, decimals: 1)
        // For improving heart rate, show percentage as positive (since lower is better)
        let pctAbs = abs(percent)
        let pctStr = String(format: "+%.0f%%", pctAbs)
        return "+\(changeStr) ( \(pctStr) )"
    }
    
    let noDecimal = name.contains("Steps") || name.contains("Workout Duration")
    let signedChange = change >= 0 ? "+" : "-"
    let changeAbs = abs(change)
    let changeStr = compactNumberString(value: changeAbs, decimals: noDecimal ? 0 : 1)
    let signedPct = percent >= 0 ? "+" : "-"
    let pctStr = String(format: "%@%.0f%%", signedPct, abs(percent))
    return "\(signedChange)\(changeStr) ( \(pctStr) )"
}

// Formats numbers to drop trailing .0 and abbreviate thousands with K
private func compactNumberString(value: Double, decimals: Int) -> String {
    let absVal = abs(value)
    if absVal >= 1000 {
        let k = absVal / 1000.0
        let formatted = String(format: decimals > 0 ? "%0.*f" : "%0.*f", decimals, k)
        if formatted.hasSuffix(".0") { return String(formatted.dropLast(2)) + "K" }
        return formatted + "K"
    } else {
        if decimals == 0 { return String(format: "%.0f", absVal) }
        let formatted = String(format: "%0.*f", decimals, absVal)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }
}

// Formats kcal values with "k" abbreviation for large numbers, with unit in parentheses
private func formatKcal(_ value: Double) -> String {
    let absVal = abs(value)
    if absVal >= 1000 {
        let k = absVal / 1000.0
        let formatted = String(format: "%.1f", k)
        // Remove trailing .0 if present
        let cleanFormatted = formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        return "\(cleanFormatted)k (kcal)"
    } else {
        return String(format: "%.0f (kcal)", absVal)
    }
}

// MARK: - Efficiency View

struct EfficiencyView: View {
    let efficiency: EfficiencyMetrics
    let onRetry: () -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 20 : 16) {
            // Metrics
            VStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
                MetricRowView(
                    icon: "flame.fill",
                    title: "Workout Efficiency",
                    value: String(format: "%.1f cal/min", efficiency.workoutEfficiency),
                    iconColor: .orange,
                    valueColor: .primary,
                    tooltip: "Workout Efficiency measures how many calories you burn per minute of exercise. Higher values indicate more intense or effective workouts. This is calculated by dividing total calories burned by total workout minutes."
                )
                
                MetricRowView(
                    icon: "heart.fill",
                    title: "Heart Health Efficiency",
                    value: efficiency.heartHealthEfficiency != nil ? String(format: "%.1f bpm/min", efficiency.heartHealthEfficiency!) : "—",
                    iconColor: .red,
                    valueColor: efficiency.heartHealthEfficiency != nil ? (efficiency.heartHealthEfficiency! > 20 ? .green : (efficiency.heartHealthEfficiency! > 15 ? .orange : .red)) : .secondary,
                    tooltip: "Heart Health Efficiency measures your heart rate recovery rate - how quickly your heart rate drops after exercise (beats per minute per minute). Higher values (above 20 bpm/min) indicate excellent cardiovascular fitness, while lower values suggest room for improvement. Good recovery is a key indicator of heart health."
                )
                
                MetricRowView(
                    icon: "figure.run",
                    title: "Fitness Gains",
                    value: efficiency.fitnessGains != nil ? String(format: "%.2f VO₂/%@", efficiency.fitnessGains!, efficiency.hasWorkouts ? "workout" : "day") : "—",
                    iconColor: .green,
                    valueColor: efficiency.fitnessGains != nil ? (efficiency.fitnessGains! > 1.0 ? .green : (efficiency.fitnessGains! > 0.5 ? .orange : .red)) : .secondary,
                    tooltip: "Fitness Gains tracks your VO₂ Max (maximum oxygen consumption) improvement per workout or active day. VO₂ Max is the best indicator of cardiovascular fitness. Higher values mean you're making good progress in building your aerobic capacity and overall fitness level."
                )
                
                MetricRowView(
                    icon: "bed.double.fill",
                    title: "Sleep Efficiency",
                    value: efficiency.sleepEfficiency != nil ? String(format: "%.0f%%", efficiency.sleepEfficiency!) : "—",
                    iconColor: .indigo,
                    valueColor: efficiency.sleepEfficiency != nil ? (efficiency.sleepEfficiency! >= 85 ? .green : (efficiency.sleepEfficiency! >= 75 ? .orange : .red)) : .secondary,
                    tooltip: "Sleep Efficiency measures the percentage of time you actually sleep compared to the total time you spend in bed. It's calculated by dividing sleep duration by time in bed. Higher values (85%+) indicate quality sleep with less tossing and turning. Lower values may indicate sleep disruptions or difficulty falling asleep."
                )
            }
            
            // Categorized AI Insights Carousel
            if efficiency.isLoadingInsights {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating AI insights...")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(horizontalSizeClass == .regular ? 16 : 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 12 : 10))
                .padding(.top, horizontalSizeClass == .regular ? 8 : 4)
            } else if let insights = efficiency.categorizedInsights {
                // Show carousel with refresh button overlay if AI response is invalid
                // AI might not respond due to:
                // 1. Foundation Models session unavailable or initialization failure
                // 2. API request timeout or network connectivity issues
                // 3. Response parsing failure (AI response doesn't match expected format)
                // 4. Context window exceeded (prompt too long)
                // 5. AI response too short or matches fallback strings (invalid content)
                EfficiencyInsightsCarousel(
                    insights: insights,
                    onRefresh: !insights.isValid ? onRetry : nil
                )
                .padding(.top, horizontalSizeClass == .regular ? 8 : 4)
            }
        }
    }
}

// MARK: - Efficiency Insights Carousel

struct EfficiencyInsightsCarousel: View {
    let insights: EfficiencyInsights
    let onRefresh: (() -> Void)?
    @State private var currentPage = 0
    
    init(insights: EfficiencyInsights, onRefresh: (() -> Void)? = nil) {
        self.insights = insights
        self.onRefresh = onRefresh
    }
    
    // Create a unique identifier for the insights to force view refresh
    private var insightsId: String {
        return "\(insights.overallAssessment.prefix(20))-\(insights.areasForImprovement.count)-\(insights.whatIsWorkingWell.prefix(20))"
    }
    
    // Structure to hold bullet point with potential continuation
    struct BulletPage {
        let bulletIndex: Int
        let text: String
        let isComplete: Bool // False if truncated with "..."
    }
    
    // Estimate line count for text (approximate: iPhone ~40 chars/line, iPad ~55 chars/line)
    private func estimateLineCount(for text: String) -> Int {
        let charsPerLine = DeviceType.isIPad ? 55 : 40
        let lineCount = max(1, Int(ceil(Double(text.count) / Double(charsPerLine))))
        return lineCount
    }
    
    // Split a text into lines (approximate) and truncate at specific line
    private func splitTextIntoLines(_ text: String, maxLines: Int) -> (displayed: String, remaining: String?, isComplete: Bool) {
        let charsPerLine = DeviceType.isIPad ? 55 : 40
        let maxChars = maxLines * charsPerLine
        
        if text.count <= maxChars {
            return (text, nil, true)
        }
        
        // Find a good breaking point (prefer sentence end or word boundary)
        let truncated = String(text.prefix(maxChars))
        
        // Try to break at a word boundary
        if let lastSpaceIndex = truncated.lastIndex(of: " ") {
            let beforeSpace = String(truncated.prefix(upTo: lastSpaceIndex))
            let afterSpace = String(text[text.index(after: lastSpaceIndex)...])
            return (beforeSpace + "...", afterSpace, false)
        } else {
            // Hard break if no space found
            let remaining = String(text.dropFirst(maxChars))
            return (truncated + "...", remaining, false)
        }
    }
    
    // Split improvements into pages based on max 8 lines per page, splitting bullets if needed
    private var improvementPages: [[BulletPage]] {
        let items = insights.areasForImprovement
        guard !items.isEmpty else { return [] }
        
        var pages: [[BulletPage]] = []
        var currentPage: [BulletPage] = []
        var currentPageLines = 0
        let maxLinesPerPage = 8
        
        var currentItemIndex = 0
        var currentItemText: String? = nil // For handling split bullets
        
        while currentItemIndex < items.count || currentItemText != nil {
            let remainingLines = maxLinesPerPage - currentPageLines
            
            if remainingLines <= 0 {
                // Current page is full, start new page
                pages.append(currentPage)
                currentPage = []
                currentPageLines = 0
                continue
            }
            
            // Get current item (either from continuation or new item)
            let item: String
            let isContinuation: Bool
            if let continuationText = currentItemText {
                item = continuationText
                isContinuation = true
                currentItemText = nil // Clear it now that we're using it
            } else {
                item = items[currentItemIndex]
                isContinuation = false
            }
            
            let itemLines = estimateLineCount(for: item)
            if itemLines <= remainingLines {
                // Entire item fits on current page
                currentPage.append(BulletPage(bulletIndex: currentItemIndex, text: item, isComplete: true))
                currentPageLines += itemLines
                
                // Only move to next item if we're not processing a continuation
                if !isContinuation {
                    currentItemIndex += 1
                }
            } else {
                // Item is too long, split it at remainingLines
                let (displayed, remaining, isComplete) = splitTextIntoLines(item, maxLines: remainingLines)
                currentPage.append(BulletPage(bulletIndex: currentItemIndex, text: displayed, isComplete: isComplete))
                currentPageLines += estimateLineCount(for: displayed)
                
                // Save remaining text for next page
                if let remainingText = remaining {
                    currentItemText = remainingText
                    // Current page is now full, move to next page
                    pages.append(currentPage)
                    currentPage = []
                    currentPageLines = 0
                } else {
                    // Item is complete
                    if !isContinuation {
                        currentItemIndex += 1
                    }
                }
            }
        }
        
        // Add remaining items to a page
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }
        
        return pages.isEmpty ? [[BulletPage]()] : pages
    }
    
    // Total number of pages: 1 (Overall) + improvement pages + 1 (Working Well)
    private var totalPages: Int {
        return 1 + improvementPages.count + 1
    }
    
    // Index for "What's Working Well" page
    private var workingWellPageIndex: Int {
        return 1 + improvementPages.count
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: DeviceType.isIPad ? 12 : 10) {
                HStack(spacing: 0) {
                    // Left arrow
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DeviceType.isIPad ? 20 : 18, weight: .semibold))
                            .foregroundColor(currentPage > 0 ? .primary : .secondary.opacity(0.3))
                            .frame(width: DeviceType.isIPad ? 40 : 36, height: DeviceType.isIPad ? 40 : 36)
                    }
                    .disabled(currentPage == 0)
                    
                    TabView(selection: $currentPage) {
                        // Overall Insight
                        InsightCard(
                            title: "Overall Insight",
                            icon: "chart.bar.fill",
                            iconColor: .blue,
                            content: [insights.overallAssessment]
                        )
                        .tag(0)
                        
                        // Areas for Improvement - multiple pages if needed
                        ForEach(Array(improvementPages.enumerated()), id: \.offset) { index, improvements in
                            InsightCard(
                                title: "Areas for Improvement",
                                icon: "arrow.up.circle.fill",
                                iconColor: .orange,
                                content: improvements.map { $0.text }
                            )
                            .tag(1 + index)
                        }
                        
                        // What's Working Well
                        InsightCard(
                            title: "What's Working Well",
                            icon: "checkmark.circle.fill",
                            iconColor: .green,
                            content: [insights.whatIsWorkingWell]
                        )
                        .tag(workingWellPageIndex)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: DeviceType.isIPad ? 280 : 220)
                    .id(insightsId) // Force refresh when insights change
                    .onChange(of: insights.overallAssessment) {
                        // Reset to first page when insights change
                        currentPage = 0
                    }
                    .onChange(of: currentPage) { _, _ in
                        // Sync when user swipes
                    }
                    
                    // Right arrow
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentPage < totalPages - 1 {
                                currentPage += 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: DeviceType.isIPad ? 20 : 18, weight: .semibold))
                            .foregroundColor(currentPage < totalPages - 1 ? .primary : .secondary.opacity(0.3))
                            .frame(width: DeviceType.isIPad ? 40 : 36, height: DeviceType.isIPad ? 40 : 36)
                    }
                    .disabled(currentPage == totalPages - 1)
                }
                .overlay(alignment: .topTrailing) {
                    // AI Sparkles icon - aligned with right arrow, top right corner
                    HStack {
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: DeviceType.isIPad ? 20 : 18, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: DeviceType.isIPad ? 40 : 36, alignment: .trailing)
                            .padding(.top, 0)
                    }
                }
            }
            
            // Refresh button overlay - centered when AI has no valid response
            if let onRefresh = onRefresh {
                Button(action: {
                    onRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DeviceType.isIPad ? 16 : 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(DeviceType.isIPad ? 10 : 8)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
        }
    }
}

struct InsightCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DeviceType.isIPad ? 12 : 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: DeviceType.isIPad ? 20 : 18))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.responsiveBody())
                    .fontWeight(.semibold)
            }
            
            if content.count == 1 {
                // Single text content
                Text(content[0])
                    .font(.responsiveCaption())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // List content (improvements)
                VStack(alignment: .leading, spacing: DeviceType.isIPad ? 8 : 6) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(iconColor.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(item)
                                .font(.responsiveCaption())
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(DeviceType.isIPad ? 16 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DeviceType.isIPad ? 12 : 10))
    }
}

// MARK: - Consistency View

struct ConsistencyView: View {
    let heatmap: ConsistencyHeatmap
    let pattern: ActiveInactivePattern
    @State private var selectedWeek = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: DeviceType.isIPad ? 16 : 12) {
            // Active/Inactive Summary
            HStack(spacing: DeviceType.isIPad ? 20 : 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Days")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(pattern.activeDaysCount)")
                            .font(.system(size: DeviceType.isIPad ? 32 : 28, weight: .bold))
                        Text("/\(pattern.totalDays)")
                            .font(.responsiveBody())
                            .foregroundColor(.secondary)
                    }
                    Text("\(String(format: "%.0f", pattern.activePercentage))%")
                        .font(.responsiveCaption())
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Longest Streak")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                    Text("\(pattern.longestActiveStreak) days")
                        .font(.system(size: DeviceType.isIPad ? 28 : 24, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, DeviceType.isIPad ? 12 : 8)
            
            // Trend indicator
            HStack(spacing: 6) {
                Image(systemName: trendIcon(pattern.trend))
                    .font(.caption)
                    .foregroundColor(trendColor(pattern.trend))
                Text(trendText(pattern.trend))
                    .font(.responsiveCaption())
                    .foregroundColor(trendColor(pattern.trend))
            }
            .padding(.bottom, DeviceType.isIPad ? 8 : 4)
            
            // Heatmap
            if heatmap.weeks > 1 {
                VStack(alignment: .leading, spacing: DeviceType.isIPad ? 12 : 8) {
                    Text("Activity Heatmap")
                        .font(.responsiveBody())
                        .fontWeight(.semibold)
                    
                    HeatmapGridView(heatmap: heatmap)
                }
            }
        }
    }
    
    private func trendIcon(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "minus"
        case .declining: return "arrow.down.right"
        }
    }
    
    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .gray
        case .declining: return .orange
        }
    }
    
    private func trendText(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "Trending up"
        case .stable: return "Stable"
        case .declining: return "Trending down"
        }
    }
}

// MARK: - Heatmap Grid View

struct HeatmapGridView: View {
    let heatmap: ConsistencyHeatmap
    
    var body: some View {
        // Group days by week
        let weeks = groupDaysByWeek(heatmap.days)
        
        VStack(alignment: .leading, spacing: DeviceType.isIPad ? 8 : 6) {
            // Day headers
            HStack(spacing: DeviceType.isIPad ? 6 : 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: DeviceType.isIPad ? 12 : 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: DeviceType.isIPad ? 28 : 24)
                }
            }
            
            // Weeks
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, weekDays in
                HStack(spacing: DeviceType.isIPad ? 6 : 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if dayIndex < weekDays.count {
                            let day = weekDays[dayIndex]
                            RoundedRectangle(cornerRadius: DeviceType.isIPad ? 4 : 3)
                                .fill(activityColor(day.activityLevel))
                                .frame(width: DeviceType.isIPad ? 28 : 24, height: DeviceType.isIPad ? 28 : 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DeviceType.isIPad ? 4 : 3)
                                        .stroke(Color(.systemBackground), lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: DeviceType.isIPad ? 4 : 3)
                                .fill(Color.clear)
                                .frame(width: DeviceType.isIPad ? 28 : 24, height: DeviceType.isIPad ? 28 : 24)
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: DeviceType.isIPad ? 12 : 8) {
                Text("Less")
                    .font(.system(size: DeviceType.isIPad ? 10 : 9))
                    .foregroundColor(.secondary)
                
                HStack(spacing: DeviceType.isIPad ? 4 : 3) {
                    ForEach([ActivityLevel.inactive, .low, .medium, .high, .veryHigh], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(activityColor(level))
                            .frame(width: DeviceType.isIPad ? 12 : 10, height: DeviceType.isIPad ? 12 : 10)
                    }
                }
                
                Text("More")
                    .font(.system(size: DeviceType.isIPad ? 10 : 9))
                    .foregroundColor(.secondary)
            }
            .padding(.top, DeviceType.isIPad ? 8 : 6)
        }
    }
    
    private func groupDaysByWeek(_ days: [HeatmapDay]) -> [[HeatmapDay]] {
        let calendar = Calendar.current
        var weeks: [[HeatmapDay]] = []
        var currentWeek: [HeatmapDay] = []
        
        for day in days.sorted(by: { $0.date < $1.date }) {
            let weekday = calendar.component(.weekday, from: day.date)
            let adjustedWeekday = (weekday == 1) ? 7 : weekday - 1 // Sunday = 7
            
            // Start new week if needed
            if adjustedWeekday == 1 && !currentWeek.isEmpty {
                // Pad with empty days to fill week
                while currentWeek.count < 7 {
                    currentWeek.append(HeatmapDay(date: Date(), activityLevel: .inactive, value: 0))
                }
                weeks.append(currentWeek)
                currentWeek = []
            }
            
            // Pad to correct day position
            while currentWeek.count < adjustedWeekday - 1 {
                currentWeek.append(HeatmapDay(date: Date(), activityLevel: .inactive, value: 0))
            }
            
            currentWeek.append(day)
        }
        
        // Pad last week and add it
        while currentWeek.count < 7 {
            currentWeek.append(HeatmapDay(date: Date(), activityLevel: .inactive, value: 0))
        }
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    private func activityColor(_ level: ActivityLevel) -> Color {
        switch level {
        case .inactive: return Color.gray.opacity(0.2)
        case .low: return Color.yellow.opacity(0.4)
        case .medium: return Color.green.opacity(0.5)
        case .high: return Color.green
        case .veryHigh: return Color(red: 0, green: 0.6, blue: 0)
        }
    }
}

// MARK: - Plateau View

struct PlateauView: View {
    let status: PlateauStatus
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 16 : 12) {
            if status.isPlateau {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 12 : 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                            .foregroundColor(severityColor(status.severity))
                        Text("Plateau Detected")
                            .font(.responsiveBody())
                            .fontWeight(.semibold)
                            .foregroundColor(severityColor(status.severity))
                    }
                    
                    Text("No significant progress for \(status.daysInPlateau) days")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                        .padding(.leading, horizontalSizeClass == .regular ? 32 : 28)
                    
                    if !status.suggestedActions.isEmpty {
                        Divider()
                            .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                        
                        Text("Suggestions:")
                            .font(.responsiveBody())
                            .fontWeight(.medium)
                            .padding(.bottom, horizontalSizeClass == .regular ? 6 : 4)
                        
                        VStack(alignment: .leading, spacing: horizontalSizeClass == .regular ? 8 : 6) {
                            ForEach(Array(status.suggestedActions.enumerated()), id: \.offset) { _, action in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.orange)
                                        .padding(.top, 6)
                                    Text(action)
                                        .font(.responsiveCaption())
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(horizontalSizeClass == .regular ? 16 : 12)
                .background(severityColor(status.severity).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 24 : 20))
                            .foregroundColor(.green)
                        Text("No Plateau Detected")
                            .font(.responsiveBody())
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Text("You're making steady progress toward your goals")
                        .font(.responsiveCaption())
                        .foregroundColor(.secondary)
                }
                .padding(horizontalSizeClass == .regular ? 16 : 12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 14 : 12))
            }
        }
    }
    
    private func severityColor(_ severity: PlateauSeverity) -> Color {
        switch severity {
        case .none, .mild: return .orange
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Metric Row View

struct MetricRowView: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    let valueColor: Color
    let tooltip: String?
    
    @State private var showTooltip = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(icon: String, title: String, value: String, iconColor: Color, valueColor: Color, tooltip: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
        self.valueColor = valueColor
        self.tooltip = tooltip
    }
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .regular ? 12 : 10) {
            Image(systemName: icon)
                .font(.system(size: horizontalSizeClass == .regular ? 20 : 18))
                .foregroundColor(iconColor)
                .frame(width: horizontalSizeClass == .regular ? 36 : 32)
            
            HStack(spacing: 4) {
                Text(title)
                    .font(.responsiveBody())
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let tooltip = tooltip {
                    Button(action: { showTooltip = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showTooltip, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.system(size: horizontalSizeClass == .regular ? 16 : 14))
                                .fontWeight(.semibold)
                            
                            Text(tooltip)
                                .font(.system(size: horizontalSizeClass == .regular ? 13 : 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(horizontalSizeClass == .regular ? 14 : 12)
                        .frame(width: horizontalSizeClass == .regular ? 300 : 260)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(horizontalSizeClass == .regular ? 10 : 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 10 : 8))
    }
}

// MARK: - Toast Message

struct ToastMessage: View {
    let message: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
        .onAppear {
            print("🎯 [Toast] ToastMessage appeared with message: \(message)")
        }
    }
}


