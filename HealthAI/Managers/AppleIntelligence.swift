import Foundation
import HealthKit
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence integration for on-device health analysis
/// Uses Apple's Foundation Models Framework for advanced AI analysis on supported devices
/// Falls back to Groq API for devices without Apple Intelligence support
class AppleIntelligence: ObservableObject {
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.healthai.app", category: "AppleIntelligence")
    
    #if canImport(FoundationModels)
    private var _sessionStorage: Any?
    #else
    private var _sessionStorage: Any? = nil
    #endif
    private let useAppleIntelligence: Bool
    
    // MARK: - Recommendation History Storage
    private let historyStorage: RecommendationHistoryStorage
    
    // MARK: - Groq API Configuration
    private let groqAPIKey: String
    private let groqModel = "llama-3.1-8b-instant"
    private let groqBaseURL = "https://api.groq.com/openai/v1/chat/completions"
    
    init(historyStorage: RecommendationHistoryStorage = FileRecommendationHistoryStorage()) {
        self.historyStorage = historyStorage
        
        // Detect if Apple Intelligence is available (iOS 26.0+ AND A17 Pro or newer)
        let hasAppleIntelligence = Self.isAppleIntelligenceAvailable()
        self.useAppleIntelligence = hasAppleIntelligence
        
        #if canImport(FoundationModels)
        if hasAppleIntelligence {
            // Initialize Apple Intelligence features
            logger.info("🔵 [API Selection] Apple Intelligence detected and available")
            logger.info("✅ Initializing Apple Intelligence with Foundation Models")
            if #available(iOS 26.0, *) {
                self._sessionStorage = LanguageModelSession(model: .default)
                logger.info("LanguageModelSession initialized successfully")
            } else {
                self._sessionStorage = nil
            }
        } else {
            // Use Groq API fallback
            logger.info("🟢 [API Selection] Apple Intelligence not available, using Groq API fallback")
            logger.info("   Reason: Device doesn't meet requirements (iOS 26.0+ AND A17 Pro/M3+)")
            self._sessionStorage = nil
        }
        #else
        // FoundationModels not available - use Groq API
        logger.info("🟢 [API Selection] FoundationModels not available, using Groq API fallback")
        self._sessionStorage = nil
        #endif
        
        // Load Groq API key from Keychain (or use default for now)
        self.groqAPIKey = Self.loadGroqAPIKey()
        
        if !hasAppleIntelligence && groqAPIKey.isEmpty {
            logger.warning("⚠️ Groq API key not found - AI features may not work")
        }
    }
    
    // MARK: - Hardware Detection
    
    /// Check if device supports Apple Intelligence (iOS 26.0+ AND A17 Pro or newer)
    private static func isAppleIntelligenceAvailable() -> Bool {
        // Check iOS version first
        guard #available(iOS 26.0, *) else {
            return false
        }
        
        #if canImport(FoundationModels)
        // Check chip model (A17 Pro or newer, or M3/M4+)
        let chipModel = getChipModel()
        let isA17ProOrNewer = isA17ProOrAbove(chipModel: chipModel)
        
        guard isA17ProOrNewer else {
            return false
        }
        
        // If we reach here, we're on iOS 26.0+ with A17 Pro+ chip
        // FoundationModels should be available
        return true
        #else
        // FoundationModels framework not available
        return false
        #endif
    }
    
    /// Get device chip model identifier
    private static func getChipModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    /// Check if chip is A17 Pro or newer (iPhone 15 Pro+) or M3/M4+ (iPad/Mac)
    private static func isA17ProOrAbove(chipModel: String) -> Bool {
        // iPhone 15 Pro models (A17 Pro): iPhone16,1, iPhone16,2
        // iPhone 16 models (A18): iPhone17,1, iPhone17,2, etc.
        // iPad Pro M3: iPad14,3+
        // iPad Pro M4: iPad15,1+
        // Mac M3/M4: Mac models with M3/M4
        
        if chipModel.contains("iPhone16") || chipModel.contains("iPhone17") || chipModel.contains("iPhone18") {
            // iPhone 15 Pro or newer
            return true
        }
        
        if chipModel.contains("iPad14") || chipModel.contains("iPad15") || chipModel.contains("iPad16") {
            // iPad Pro M3 or newer
            return true
        }
        
        // For Mac, check for M3/M4 in model identifier
        if chipModel.contains("Mac") {
            // Mac with M3/M4 chip (would need additional detection)
            // For now, assume Mac models support it if iOS 26.0+
            return true
        }
        
        return false
    }
    
    // MARK: - Groq API Key Management
    
    /// Load Groq API key from build-time configuration (Info.plist), environment variables, or Keychain
    /// Returns empty string if key is not found
    /// API keys should NEVER be hardcoded in source code
    private static func loadGroqAPIKey() -> String {
        // First, try to load from Info.plist (build-time configuration)
        // This is set via Xcode build settings or CI/CD environment variables
        if let infoPlistKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String,
           !infoPlistKey.isEmpty, infoPlistKey != "$(GROQ_API_KEY)" {
            // Only use if it's not the placeholder value
            return infoPlistKey
        }
        
        // Try environment variable (for Xcode Cloud/CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }
        
        // Fallback to Keychain (for local development/testing)
        if let keychainKey = Self.getKeychainValue(for: "groq_api_key"), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // Return empty string if not found - app will handle gracefully
        return ""
    }
    
    /// Get value from Keychain
    private static func getKeychainValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    // MARK: - AI Response Cache
    
    /// Caches AI-generated insights per date range to avoid regenerating on date switches
    /// Each section can be cached independently as responses complete
    struct CachedAIResponse {
        var efficiencyInsights: EfficiencyInsights?
        var patternInsights: PatternInsights?
        var healthInsight: HealthInsight?
        var bodyCompositionPrediction: BodyCompositionPrediction?
        var comprehensiveRecommendations: ComprehensiveRecommendations?
        var cachedAt: Date
        
        init() {
            self.efficiencyInsights = nil
            self.patternInsights = nil
            self.healthInsight = nil
            self.bodyCompositionPrediction = nil
            self.comprehensiveRecommendations = nil
            self.cachedAt = Date()
        }
        
        /// Check if all sections are cached
        var isComplete: Bool {
            return efficiencyInsights != nil &&
                   patternInsights != nil &&
                   healthInsight != nil &&
                   bodyCompositionPrediction != nil
        }
    }
    
    // Cache AI responses keyed by date range string (e.g., "This Week", "6 Months")
    private var cachedResponses: [String: CachedAIResponse] = [:]
    
    // Track when HealthKit data was last fetched (for cache invalidation)
    // Persisted to UserDefaults to survive app termination
    private var _lastHealthKitFetchDate: Date?
    private var lastHealthKitFetchDate: Date? {
        get {
            // Load from persistent storage if not in memory
            if _lastHealthKitFetchDate == nil {
                if let timestamp = UserDefaults.standard.object(forKey: "AppleIntelligence.lastHealthKitFetchDate") as? Date {
                    _lastHealthKitFetchDate = timestamp
                }
            }
            return _lastHealthKitFetchDate
        }
        set {
            _lastHealthKitFetchDate = newValue
            // Persist to UserDefaults
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: "AppleIntelligence.lastHealthKitFetchDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleIntelligence.lastHealthKitFetchDate")
            }
        }
    }
    
    /// Get cached AI response for a date range (can be partial)
    func getCachedResponse(for rangeType: String) -> CachedAIResponse? {
        logger.debug("🔍 [AI Cache] Checking cache for '\(rangeType)'")
        logger.debug("   Cache entries: \(self.cachedResponses.keys.joined(separator: ", "))")
        logger.debug("   Last HealthKit fetch: \(self.lastHealthKitFetchDate?.description ?? "nil")")
        
        // Check if we have a cached response
        guard let cached = self.cachedResponses[rangeType] else {
            logger.debug("   ❌ No cache entry found")
            return nil
        }
        
        logger.debug("   ✅ Cache entry found, cached at: \(cached.cachedAt)")
        
        // Check if cache is still valid (HealthKit data hasn't been refreshed since)
        if let lastFetch = self.lastHealthKitFetchDate,
           cached.cachedAt < lastFetch {
            // HealthKit data was refreshed after AI cache was created, so cache is stale
            logger.debug("   ⚠️ Cache is stale (created: \(cached.cachedAt), HealthKit refreshed: \(lastFetch))")
            self.cachedResponses.removeValue(forKey: rangeType)
            return nil
        }
        
        // Log which sections are available
        let sections = [
            cached.efficiencyInsights != nil ? "efficiency" : nil,
            cached.patternInsights != nil ? "patterns" : nil,
            cached.healthInsight != nil ? "health" : nil,
            cached.bodyCompositionPrediction != nil ? "bodyComp" : nil,
            cached.comprehensiveRecommendations != nil ? "recommendations" : nil
        ].compactMap { $0 }
        
        logger.info("💾 [AI Cache] Returning cached response for '\(rangeType)' (sections: \(sections.joined(separator: ", ")))")
        return cached
    }
    
    /// Store complete AI response for a date range (all sections at once)
    /// Preserves existing recommendations if they exist
    func cacheResponse(
        for rangeType: String,
        efficiencyInsights: EfficiencyInsights,
        patternInsights: PatternInsights,
        healthInsight: HealthInsight,
        bodyCompositionPrediction: BodyCompositionPrediction
    ) {
        // Preserve existing recommendations if they exist
        let existingRecommendations = self.cachedResponses[rangeType]?.comprehensiveRecommendations
        
        var cached = CachedAIResponse()
        cached.efficiencyInsights = efficiencyInsights
        cached.patternInsights = patternInsights
        cached.healthInsight = healthInsight
        cached.bodyCompositionPrediction = bodyCompositionPrediction
        cached.comprehensiveRecommendations = existingRecommendations  // Preserve existing recommendations
        cached.cachedAt = Date()
        self.cachedResponses[rangeType] = cached
        logger.info("💾 [AI Cache] Cached complete response for '\(rangeType)' (Total cached: \(self.cachedResponses.count))\(existingRecommendations != nil ? ", preserved recommendations" : "")")
    }
    
    /// Cache individual sections as they complete (incremental caching)
    func cacheEfficiencyInsights(_ insights: EfficiencyInsights, for rangeType: String) {
        if self.cachedResponses[rangeType] == nil {
            self.cachedResponses[rangeType] = CachedAIResponse()
        }
        self.cachedResponses[rangeType]?.efficiencyInsights = insights
        logger.info("💾 [AI Cache] Cached efficiency insights for '\(rangeType)'")
    }
    
    func cachePatternInsights(_ insights: PatternInsights, for rangeType: String) {
        if self.cachedResponses[rangeType] == nil {
            self.cachedResponses[rangeType] = CachedAIResponse()
        }
        self.cachedResponses[rangeType]?.patternInsights = insights
        logger.info("💾 [AI Cache] Cached pattern insights for '\(rangeType)'")
    }
    
    func cacheHealthInsight(_ insight: HealthInsight, for rangeType: String) {
        if self.cachedResponses[rangeType] == nil {
            self.cachedResponses[rangeType] = CachedAIResponse()
        }
        self.cachedResponses[rangeType]?.healthInsight = insight
        logger.info("💾 [AI Cache] Cached health insight for '\(rangeType)'")
    }
    
    func cacheBodyCompositionPrediction(_ prediction: BodyCompositionPrediction, for rangeType: String) {
        if self.cachedResponses[rangeType] == nil {
            self.cachedResponses[rangeType] = CachedAIResponse()
        }
        self.cachedResponses[rangeType]?.bodyCompositionPrediction = prediction
        logger.info("💾 [AI Cache] Cached body composition prediction for '\(rangeType)'")
    }
    
    func cacheComprehensiveRecommendations(_ recommendations: ComprehensiveRecommendations, for rangeType: String) {
        if self.cachedResponses[rangeType] == nil {
            self.cachedResponses[rangeType] = CachedAIResponse()
        }
        self.cachedResponses[rangeType]?.comprehensiveRecommendations = recommendations
        logger.info("💾 [AI Cache] Cached comprehensive recommendations for '\(rangeType)' (\(recommendations.topRecommendations.count) recommendations)")
    }
    
    /// Clear all cached AI responses (called when HealthKit data is refreshed)
    func clearAICache() {
        let count = self.cachedResponses.count
        self.cachedResponses.removeAll()
        logger.info("🗑️ [AI Cache] Cleared \(count) cached responses")
    }
    
    /// Mark HealthKit data as refreshed (invalidates all cache entries older than this date)
    func markHealthKitRefreshed(fetchedAt: Date) {
        // Update persistent timestamp
        self.lastHealthKitFetchDate = fetchedAt
        // Remove any cache entries that were created before this refresh
        self.cachedResponses = self.cachedResponses.filter { $0.value.cachedAt >= fetchedAt }
        logger.info("🔄 [AI Cache] HealthKit refreshed at \(fetchedAt), invalidated stale cache entries")
    }
    
    // MARK: - Groq API Helper Methods
    
    /// Call Groq API with a prompt and return the response
    private func callGroqAPI(prompt: String, temperature: Double = 0.7, maxTokens: Int = 2000) async throws -> String {
        guard !groqAPIKey.isEmpty else {
            throw NSError(domain: "GroqAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Groq API key not configured"])
        }
        
        logger.info("🌐 [Groq API] Calling Groq API (prompt: \(prompt.count) chars)")
        
        var request = URLRequest(url: URL(string: groqBaseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": groqModel,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GroqAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("❌ [Groq API] HTTP \(httpResponse.statusCode): \(errorMessage)")
            throw NSError(domain: "GroqAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "GroqAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
        
        logger.info("✅ [Groq API] Response received (\(content.count) chars)")
        return content
    }
    
    /// Generate AI-powered efficiency insights based on all efficiency metrics
    func generateEfficiencyInsight(
        profile: UserProfile,
        workoutEfficiency: Double,
        heartHealthEfficiency: Double?,
        fitnessGains: Double?,
        sleepEfficiency: Double?,
        hasWorkouts: Bool,
        rangeType: String
    ) async -> EfficiencyInsights {
        // Route to appropriate API based on availability
        #if canImport(FoundationModels)
        if useAppleIntelligence, #available(iOS 26.0, *), let session = _sessionStorage as? LanguageModelSession {
            logger.info("🔵 [Routing] Using Apple Intelligence for efficiency insights")
            return await generateEfficiencyInsightWithAppleIntelligence(
                profile: profile,
                workoutEfficiency: workoutEfficiency,
                heartHealthEfficiency: heartHealthEfficiency,
                fitnessGains: fitnessGains,
                sleepEfficiency: sleepEfficiency,
                hasWorkouts: hasWorkouts,
                rangeType: rangeType,
                session: session
            )
        }
        #endif
        
        // Fallback to Groq API
        logger.info("🟢 [Routing] Using Groq API for efficiency insights")
        return await generateEfficiencyInsightWithGroq(
            profile: profile,
            workoutEfficiency: workoutEfficiency,
            heartHealthEfficiency: heartHealthEfficiency,
            fitnessGains: fitnessGains,
            sleepEfficiency: sleepEfficiency,
            hasWorkouts: hasWorkouts,
            rangeType: rangeType
        )
    }
    
    /// Generate efficiency insights using Apple Intelligence
    @available(iOS 26.0, *)
    private func generateEfficiencyInsightWithAppleIntelligence(
        profile: UserProfile,
        workoutEfficiency: Double,
        heartHealthEfficiency: Double?,
        fitnessGains: Double?,
        sleepEfficiency: Double?,
        hasWorkouts: Bool,
        rangeType: String,
        session: LanguageModelSession
    ) async -> EfficiencyInsights {
        
        logger.info("Generating AI efficiency insight for \(rangeType)")
        
        // Create a fresh session for efficiency insights to avoid context window issues
        // Using a new session prevents context accumulation from previous calls
        #if canImport(FoundationModels)
        let freshSession = LanguageModelSession(model: .default)
        #else
        fatalError("FoundationModels not available")
        #endif
        
        // Calculate day count for time range context
        let dayCount = DateRangeCalculator.getDayCount(for: DateRangeType(rawValue: rangeType) ?? .weekly)
        
        // Build comprehensive prompt with all efficiency metrics
        let heartHealthStr = heartHealthEfficiency != nil ? String(format: "%.1f bpm/min", heartHealthEfficiency!) : "N/A"
        let fitnessStr = fitnessGains != nil ? String(format: "%.2f VO₂/%@", fitnessGains!, hasWorkouts ? "workout" : "day") : "N/A"
        let sleepStr = sleepEfficiency != nil ? String(format: "%.0f%%", sleepEfficiency!) : "N/A"
        
        let prompt = """
        EFFICIENCY ANALYSIS
        
        \(createTimeRangeContext(rangeType: rangeType, dayCount: dayCount))
        
        User Profile:
        - Goals: \(profile.fitnessGoals.map { $0.rawValue }.joined(separator: ", "))
        - Age: \(profile.age.map { "\($0)" } ?? "unknown"), Gender: \(profile.gender.rawValue)
        - Current Weight: \(String(format: "%.1f", profile.weight))kg, Target: \(String(format: "%.1f", profile.targetWeight))kg
        
        Efficiency Metrics (Period: \(rangeType)):
        1. Workout Efficiency: \(String(format: "%.1f", workoutEfficiency)) cal/min
           - Calculated as: total calories burned / total workout minutes
        
        2. Heart Health Efficiency: \(heartHealthStr) bpm/min
           - Calculated as: heart rate drop 1 minute after workout ends
        
        3. Fitness Gains: \(fitnessStr) VO₂/\(hasWorkouts ? "workout" : "day")
           - Calculated as: VO₂ Max per \(hasWorkouts ? "workout" : "active day")
        
        4. Sleep Efficiency: \(sleepStr)%
           - Calculated as: (time asleep / time in bed) × 100
           - This doen not measures  total sleep duration
           - Focus insights on: restlessness, time spent awake in bed, sleep disruptions, quality of sleep periods
        
        IMPORTANT INTERPRETATION GUIDELINES:
        - Each metric measures a SPECIFIC aspect: intensity, recovery speed, improvement rate, or sleep quality
        - Do NOT conflate these metrics with related but different concepts (e.g., sleep efficiency ≠ sleep duration)
        - Base insights on what each metric ACTUALLY measures, not on assumptions about what you think it should mean
        - For sleep efficiency: provide actionable advice about reducing restlessness, improving sleep environment, or addressing sleep disruptions - NOT about getting more sleep
        
        You MUST provide exactly 3 sections in this EXACT format (separated by blank lines):
        
        OVERALL INSIGHT:
        [One concise sentence summarizing overall efficiency status]
        
        AREAS FOR IMPROVEMENT:
        1. [Specific area] - [Actionable recommendation]
        2. [Specific area] - [Actionable recommendation]
        [Add more items as needed]
        
        WHAT'S WORKING WELL:
        [What's performing well and should be maintained - be specific about which metrics are improving]
        
        REQUIREMENTS:
        - You MUST include all 3 sections above
        - Each section header must be exactly as shown (OVERALL INSIGHT:, AREAS FOR IMPROVEMENT:, WHAT'S WORKING WELL:)
        - Separate each section with a blank line
        - Be concise and actionable
        """
        
        do {
            #if canImport(FoundationModels)
            let promptObj = Prompt(prompt)
            logger.info("🔄 [AI] Generating efficiency insight...")
            
            let response = try await safeRespond(session: freshSession, prompt: promptObj, operation: "efficiency insight")
            
            logger.info("✅ [AI] Efficiency insight generated (\(response.content.count) chars)")
            return parseEfficiencyInsights(response.content)
            #else
            // FoundationModels not available - should not reach here
            return EfficiencyInsights(
                overallAssessment: "",
                areasForImprovement: [],
                whatIsWorkingWell: "",
                isValid: false
            )
            #endif
        } catch {
            logger.error("❌ [AI] Efficiency insight error: \(error.localizedDescription)")
            
            // If error is due to concurrent call, wait and retry once
            #if canImport(FoundationModels)
            if error.localizedDescription.contains("second time before the model finished") {
                logger.info("⏳ [AI] Waiting for previous response to finish...")
                var waitCount = 0
                while freshSession.isResponding && waitCount < 100 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    waitCount += 1
                }
                
                // Try one more time if session is now available
                if !freshSession.isResponding {
                    do {
                        let promptObj = Prompt(prompt)
                        let response = try await safeRespond(session: freshSession, prompt: promptObj, operation: "efficiency insight retry")
                        logger.info("✅ [AI] Efficiency insight generated on retry (\(response.content.count) chars)")
                        return parseEfficiencyInsights(response.content)
                    } catch {
                        logger.error("❌ [AI] Retry also failed: \(error.localizedDescription)")
                    }
                }
            }
            #endif
            
            // Return invalid insights - will show refresh button in UI
            return EfficiencyInsights(
                overallAssessment: "",
                areasForImprovement: [],
                whatIsWorkingWell: "",
                isValid: false
            )
        }
    }
    
    private func parseEfficiencyInsights(_ response: String) -> EfficiencyInsights {
        logger.info("🔍 [AI] Parsing categorized efficiency insights...")
        logger.debug("📝 [AI] Raw response (\(response.count) chars):\n\(response)")
        
        var overallAssessment = ""
        var areasForImprovement: [String] = []
        var whatIsWorkingWell = ""
        
        // Normalize the response - handle various formatting
        let normalizedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try multiple parsing strategies
        
        // Strategy 1: Parse by double newline sections (most common)
        let sections = normalizedResponse.components(separatedBy: "\n\n")
        logger.debug("📋 Found \(sections.count) sections separated by double newlines")
        for (index, section) in sections.enumerated() {
            logger.debug("   Section \(index + 1): \(section.prefix(80))...")
        }
        
        var foundOverall = false
        var foundImprovements = false
        var foundWorkingWell = false
        
        for section in sections {
            let trimmedSection = section.trimmingCharacters(in: .whitespaces)
            if trimmedSection.isEmpty { continue }
            
            let lowerSection = trimmedSection.lowercased()
            let lines = trimmedSection.components(separatedBy: "\n")
            let firstLine = lines.first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            
            // Parse OVERALL INSIGHT section
            if !foundOverall && (firstLine.contains("overall insight") || firstLine.contains("overall assessment") || firstLine.contains("overall:")) {
                // Extract content after the header
                for (index, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let lowerTrimmed = trimmed.lowercased()
                    
                    // Skip the header line and empty lines
                    if lowerTrimmed.contains("overall") && index == 0 { continue }
                    if trimmed.isEmpty { continue }
                    
                    // Found the content line
                    overallAssessment = trimmed
                    // Remove trailing colon if present
                    if overallAssessment.hasSuffix(":") {
                        overallAssessment = String(overallAssessment.dropLast()).trimmingCharacters(in: .whitespaces)
                    }
                    foundOverall = true
                    logger.debug("✅ Extracted overall: \(overallAssessment.prefix(50))...")
                    break
                }
            }
            // Parse AREAS FOR IMPROVEMENT section
            else if !foundImprovements && (firstLine.contains("areas for improvement") || firstLine.contains("improvement")) && !lowerSection.contains("what's working") && !lowerSection.contains("working well") {
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let lowerTrimmed = trimmed.lowercased()
                    
                    // Skip section headers, empty lines, and "what's working" content
                    if lowerTrimmed.contains("areas for improvement") || lowerTrimmed.contains("improvement:") || 
                       lowerTrimmed.contains("what's working") || lowerTrimmed.contains("working well") || 
                       trimmed.isEmpty {
                        continue
                    }
                    
                    // Remove numbering patterns: "1. ", "1) ", "- ", "• "
                    var cleaned = trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^\d+\)\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    
                    // Remove " - " separator if present (for "area - recommendation" format)
                    if let dashIndex = cleaned.range(of: " - ") {
                        cleaned = String(cleaned[dashIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    
                    if !cleaned.isEmpty && cleaned.count > 15 && cleaned.count < 250 {
                        areasForImprovement.append(cleaned)
                        logger.debug("✅ Extracted improvement: \(cleaned.prefix(50))...")
                    }
                }
                foundImprovements = !areasForImprovement.isEmpty
            }
            // Parse WHAT'S WORKING WELL section - check both first line and entire section
            else if !foundWorkingWell {
                let sectionContainsWorking = lowerSection.contains("what's working") || 
                                           lowerSection.contains("whats working") || 
                                           lowerSection.contains("working well") ||
                                           firstLine.contains("what's working") || 
                                           firstLine.contains("working well") || 
                                           firstLine.contains("whats working")
                
                if sectionContainsWorking {
                    logger.debug("🔍 Found 'Working Well' section, extracting content...")
                    var contentLines: [String] = []
                    
                    for (lineIndex, line) in lines.enumerated() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        let lowerTrimmed = trimmed.lowercased()
                        
                        // Skip section headers (usually first line or very short lines containing keywords)
                        let isHeader = (lineIndex == 0 && (lowerTrimmed.contains("what's working") || lowerTrimmed.contains("whats working") || lowerTrimmed.contains("working well"))) ||
                                       (trimmed.count < 25 && (lowerTrimmed.contains("what's working") || lowerTrimmed.contains("whats working") || lowerTrimmed.contains("working well:")))
                        
                        if isHeader || trimmed.isEmpty {
                            continue
                        }
                        
                        // Found content line
                        contentLines.append(trimmed)
                    }
                    
                    // Join all content lines (in case it spans multiple lines)
                    if !contentLines.isEmpty {
                        whatIsWorkingWell = contentLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                        // Remove trailing colon if present
                        if whatIsWorkingWell.hasSuffix(":") {
                            whatIsWorkingWell = String(whatIsWorkingWell.dropLast()).trimmingCharacters(in: .whitespaces)
                        }
                        foundWorkingWell = true
                        logger.debug("✅ Extracted working well (\(whatIsWorkingWell.count) chars): \(whatIsWorkingWell.prefix(60))...")
                    } else {
                        logger.warning("⚠️ 'Working Well' section found but no content extracted. Section: \(trimmedSection.prefix(100))...")
                    }
                }
            }
        }
        
        // Strategy 2: If sections weren't found, try parsing by single newlines with keyword detection
        if !foundOverall || !foundImprovements || !foundWorkingWell {
            logger.debug("⚠️ [Parsing] Using fallback parsing strategy")
            logger.debug("   Missing: Overall=\(!foundOverall), Improvements=\(!foundImprovements), WorkingWell=\(!foundWorkingWell)")
            let allLines = normalizedResponse.components(separatedBy: "\n")
            var currentSection: String? = nil
            var improvementItems: [String] = []
            
            for line in allLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let lowerTrimmed = trimmed.lowercased()
                
                if lowerTrimmed.contains("overall insight") || lowerTrimmed.contains("overall assessment") {
                    currentSection = "overall"
                    continue
                } else if lowerTrimmed.contains("areas for improvement") || lowerTrimmed.contains("improvement") {
                    currentSection = "improvements"
                    continue
                } else if lowerTrimmed.contains("what's working") || lowerTrimmed.contains("whats working") || lowerTrimmed.contains("working well") {
                    currentSection = "working"
                    continue
                }
                
                if trimmed.isEmpty { continue }
                
                // Extract content based on current section
                if currentSection == "overall" && !foundOverall {
                    if trimmed.count > 20 && trimmed.count < 200 {
                        overallAssessment = trimmed
                        foundOverall = true
                    }
                } else if currentSection == "improvements" && !foundImprovements {
                    var cleaned = trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^\d+\)\s*"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    
                    if let dashIndex = cleaned.range(of: " - ") {
                        cleaned = String(cleaned[dashIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    
                    if !cleaned.isEmpty && cleaned.count > 15 && cleaned.count < 250 {
                        improvementItems.append(cleaned)
                    }
                } else if currentSection == "working" && !foundWorkingWell {
                    // Skip if it's just a header line
                    let isHeaderLine = lowerTrimmed.contains("what's working") || lowerTrimmed.contains("whats working") || lowerTrimmed.contains("working well:")
                    if !isHeaderLine && trimmed.count > 5 {  // Very lenient - accept any content > 5 chars
                        // If we already have content, append it (multi-line content)
                        if !whatIsWorkingWell.isEmpty {
                            whatIsWorkingWell += " " + trimmed
                        } else {
                            whatIsWorkingWell = trimmed
                        }
                        // Don't break - continue collecting in case there are more lines
                    }
                }
            }
            
            if !improvementItems.isEmpty && !foundImprovements {
                areasForImprovement = improvementItems
                foundImprovements = true
            }
            
            // Mark working well as found if we collected any content
            if !whatIsWorkingWell.isEmpty && !foundWorkingWell {
                foundWorkingWell = true
                whatIsWorkingWell = whatIsWorkingWell.trimmingCharacters(in: .whitespaces)
                logger.debug("✅ Extracted working well from fallback (\(whatIsWorkingWell.count) chars): \(whatIsWorkingWell.prefix(60))...")
            }
        }
        
        // Final check: if we still haven't found "What's Working Well", search more aggressively
        if !foundWorkingWell {
            logger.debug("⚠️ Still missing 'Working Well', doing aggressive search...")
            let allText = normalizedResponse.lowercased()
            
            // Look for any occurrence of working well keywords followed by content
            let patterns = [
                "what's working well:",
                "whats working well:",
                "working well:",
                "what's working:",
                "whats working:"
            ]
            
            for pattern in patterns {
                if let range = allText.range(of: pattern) {
                    let afterKeyword = String(normalizedResponse[range.upperBound...])
                    let linesAfter = afterKeyword.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    if let firstContentLine = linesAfter.first, firstContentLine.count > 5 {
                        whatIsWorkingWell = firstContentLine
                        foundWorkingWell = true
                        logger.debug("✅ Found 'Working Well' via aggressive search: \(whatIsWorkingWell.prefix(60))...")
                        break
                    }
                }
            }
            
            // Fallback: Check if AI mistakenly returned "IMPORTANT:" section instead of "WHAT'S WORKING WELL"
            if !foundWorkingWell {
                if let importantRange = allText.range(of: "important:") {
                    let afterImportant = String(normalizedResponse[importantRange.upperBound...])
                    let linesAfterImportant = afterImportant.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("-") }
                    // Take the first non-bullet line (usually the actual content, not instructions)
                    if let contentLine = linesAfterImportant.first, contentLine.count > 10 {
                        whatIsWorkingWell = contentLine
                        foundWorkingWell = true
                        logger.debug("⚠️ Found 'Working Well' content in 'IMPORTANT:' section (AI format issue): \(whatIsWorkingWell.prefix(60))...")
                    }
                }
            }
        }
        
        // Simple validation: isValid = true if we successfully extracted ANY meaningful content from AI response
        // If parsing failed (all empty), isValid = false → refresh overlay will show
        // Show AI response if we got any content, even if some sections are missing
        let isValidAI = !overallAssessment.isEmpty || 
                       !areasForImprovement.isEmpty || 
                       !whatIsWorkingWell.isEmpty
        
        logger.info("   ✅ Parsed: Overall (\(overallAssessment.count) chars), \(areasForImprovement.count) improvements, Working (\(whatIsWorkingWell.count) chars), Valid: \(isValidAI)")
        if isValidAI {
            logger.info("   📝 Overall: \(overallAssessment.prefix(60))...")
            logger.info("   📝 Working Well: \(whatIsWorkingWell.prefix(60))...")
        } else {
            logger.warning("⚠️ [Parsing] Failed to extract content from AI response - will show refresh overlay")
        }
        
        return EfficiencyInsights(
            overallAssessment: overallAssessment,
            areasForImprovement: areasForImprovement, // No limit - show all improvements, paginated 2 per page
            whatIsWorkingWell: whatIsWorkingWell,
            isValid: isValidAI
        )
    }
    
    /// Generate efficiency insights using Groq API
    private func generateEfficiencyInsightWithGroq(
        profile: UserProfile,
        workoutEfficiency: Double,
        heartHealthEfficiency: Double?,
        fitnessGains: Double?,
        sleepEfficiency: Double?,
        hasWorkouts: Bool,
        rangeType: String
    ) async -> EfficiencyInsights {
        logger.info("🌐 [Groq] Generating efficiency insight for \(rangeType)")
        
        // Calculate day count for time range context
        let dayCount = DateRangeCalculator.getDayCount(for: DateRangeType(rawValue: rangeType) ?? .weekly)
        
        // Build the same prompt as Apple Intelligence version
        let heartHealthStr = heartHealthEfficiency != nil ? String(format: "%.1f bpm/min", heartHealthEfficiency!) : "N/A"
        let fitnessStr = fitnessGains != nil ? String(format: "%.2f VO₂/%@", fitnessGains!, hasWorkouts ? "workout" : "day") : "N/A"
        let sleepStr = sleepEfficiency != nil ? String(format: "%.0f%%", sleepEfficiency!) : "N/A"
        
        let prompt = """
        EFFICIENCY ANALYSIS
        
        \(createTimeRangeContext(rangeType: rangeType, dayCount: dayCount))
        
        User Profile:
        - Goals: \(profile.fitnessGoals.map { $0.rawValue }.joined(separator: ", "))
        - Age: \(profile.age.map { "\($0)" } ?? "unknown"), Gender: \(profile.gender.rawValue)
        - Current Weight: \(String(format: "%.1f", profile.weight))kg, Target: \(String(format: "%.1f", profile.targetWeight))kg
        
        Efficiency Metrics (Period: \(rangeType)):
        1. Workout Efficiency: \(String(format: "%.1f", workoutEfficiency)) cal/min
           - Calculated as: total calories burned / total workout minutes
        
        2. Heart Health Efficiency: \(heartHealthStr) bpm/min
           - Calculated as: heart rate drop 1 minute after workout ends
        
        3. Fitness Gains: \(fitnessStr) VO₂/\(hasWorkouts ? "workout" : "day")
           - Calculated as: VO₂ Max per \(hasWorkouts ? "workout" : "active day")
        
        4. Sleep Efficiency: \(sleepStr)%
           - Calculated as: (time asleep / time in bed) × 100
           - This doen not measures  total sleep duration
           - Focus insights on: restlessness, time spent awake in bed, sleep disruptions, quality of sleep periods
        
        IMPORTANT INTERPRETATION GUIDELINES:
        - Each metric measures a SPECIFIC aspect: intensity, recovery speed, improvement rate, or sleep quality
        - Do NOT conflate these metrics with related but different concepts (e.g., sleep efficiency ≠ sleep duration)
        - Base insights on what each metric ACTUALLY measures, not on assumptions about what you think it should mean
        - For sleep efficiency: provide actionable advice about reducing restlessness, improving sleep environment, or addressing sleep disruptions - NOT about getting more sleep
        
        You MUST provide exactly 3 sections in this EXACT format (separated by blank lines):
        
        OVERALL INSIGHT:
        [One concise sentence summarizing overall efficiency status]
        
        AREAS FOR IMPROVEMENT:
        1. [Specific area] - [Actionable recommendation]
        2. [Specific area] - [Actionable recommendation]
        [Add more items as needed]
        
        WHAT'S WORKING WELL:
        [What's performing well and should be maintained - be specific about which metrics are improving]
        
        REQUIREMENTS:
        - You MUST include all 3 sections above
        - Each section header must be exactly as shown (OVERALL INSIGHT:, AREAS FOR IMPROVEMENT:, WHAT'S WORKING WELL:)
        - Separate each section with a blank line
        - Be concise and actionable
        """
        
        do {
            let response = try await callGroqAPI(prompt: prompt, temperature: 0.7, maxTokens: 1000)
            logger.info("✅ [Groq] Efficiency insight generated (\(response.count) chars)")
            return parseEfficiencyInsights(response)
        } catch {
            logger.error("❌ [Groq] Efficiency insight error: \(error.localizedDescription)")
            // Return invalid insights - will show refresh button in UI
            return EfficiencyInsights(
                overallAssessment: "",
                areasForImprovement: [],
                whatIsWorkingWell: "",
                isValid: false
            )
        }
    }
    
    
    // MARK: - Foundation Models Integration (iOS 26.0+)
    
    /// Safely call session.respond(to:) with waiting for existing responses
    @available(iOS 26.0, *)
    private func safeRespond(
        session: LanguageModelSession,
        prompt: Prompt,
        operation: String
    ) async throws -> LanguageModelSession.Response<String> {
        // Wait for any existing response to finish before starting a new one
        var waitCount = 0
        while session.isResponding && waitCount < 100 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            waitCount += 1
        }
        
        if session.isResponding {
            throw NSError(domain: "AppleIntelligence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session still responding after wait"])
        }
        
        return try await session.respond(to: prompt, options: GenerationOptions())
    }
    
    // MARK: - Comprehensive Recommendations (Single Call)
    
    /// Generate comprehensive coach-level recommendations using all available data
    func generateComprehensiveRecommendations(
        profile: UserProfile,
        patternInsights: PatternInsights,
        bodyCompositionPrediction: BodyCompositionPrediction,
        rangeType: String,
        dayCount: Int,
        avgStepsPerDay: Double = 0  // Optional - for metrics snapshot
    ) async -> ComprehensiveRecommendations? {
        // Route to appropriate API based on availability
        #if canImport(FoundationModels)
        if useAppleIntelligence, #available(iOS 26.0, *), let session = _sessionStorage as? LanguageModelSession {
            logger.info("🔵 [Routing] Using Apple Intelligence for comprehensive recommendations")
            return await generateComprehensiveRecommendationsWithAppleIntelligence(
                profile: profile,
                patternInsights: patternInsights,
                bodyCompositionPrediction: bodyCompositionPrediction,
                rangeType: rangeType,
                dayCount: dayCount,
                avgStepsPerDay: avgStepsPerDay,
                session: session
            )
        }
        #endif
        
        // Fallback to Groq API
        logger.info("🟢 [Routing] Using Groq API for comprehensive recommendations")
        return await generateComprehensiveRecommendationsWithGroq(
            profile: profile,
            patternInsights: patternInsights,
            bodyCompositionPrediction: bodyCompositionPrediction,
            rangeType: rangeType,
            dayCount: dayCount,
            avgStepsPerDay: avgStepsPerDay
        )
    }
    
    /// Generate comprehensive recommendations using Apple Intelligence
    @available(iOS 26.0, *)
    private func generateComprehensiveRecommendationsWithAppleIntelligence(
        profile: UserProfile,
        patternInsights: PatternInsights,
        bodyCompositionPrediction: BodyCompositionPrediction,
        rangeType: String,
        dayCount: Int,
        avgStepsPerDay: Double,
        session: LanguageModelSession
    ) async -> ComprehensiveRecommendations? {
        logger.info("🎯 [AI] Generating comprehensive recommendations for \(rangeType)")
        print("🎯 [AI] Starting comprehensive recommendations generation for \(rangeType)")
        
        // Load previous recommendation history for this range type
        let previousRecommendation = await historyStorage.getLastRecommendation(for: rangeType)
        if let previous = previousRecommendation {
            let daysAgo = Calendar.current.dateComponents([.day], from: previous.generatedAt, to: Date()).day ?? 0
            logger.info("📚 [History] Found previous recommendation from \(daysAgo) days ago")
        } else {
            logger.info("📚 [History] No previous recommendation found - first time for \(rangeType)")
        }
        
        // Create fresh session to avoid context window issues
        #if canImport(FoundationModels)
        let freshSession = LanguageModelSession(model: .default)
        #else
        fatalError("FoundationModels not available")
        #endif
        
        // Create metrics snapshot for comparison
        let metricsSnapshot = createMetricsSnapshot(
            patternInsights: patternInsights,
            bodyCompositionPrediction: bodyCompositionPrediction,
            dayCount: dayCount,
            avgStepsPerDay: avgStepsPerDay
        )
        
        // Build period analyzed string
        let periodAnalyzed = createPeriodAnalyzedString(rangeType: rangeType, dayCount: dayCount)
        
        // Build optimized prompt with history context
        let prompt = buildComprehensivePrompt(
            profile: profile,
            patternInsights: patternInsights,
            bodyCompositionPrediction: bodyCompositionPrediction,
            rangeType: rangeType,
            dayCount: dayCount,
            previousRecommendation: previousRecommendation,
            currentMetrics: metricsSnapshot
        )
        
        do {
            #if canImport(FoundationModels)
            let promptObj = Prompt(prompt)
            logger.info("🔄 [AI] Calling Foundation Models for comprehensive recommendations...")
            logger.debug("📝 [AI] Prompt length: \(prompt.count) chars (~\(prompt.count / 4) tokens)")
            
            let response = try await safeRespond(session: freshSession, prompt: promptObj, operation: "comprehensive recommendations")
            
            logger.info("✅ [AI] Comprehensive recommendations received (\(response.content.count) chars)")
            logger.debug("📝 [AI] Raw response:\n\(response.content)")
            
            // Parse the response
            var recommendations = parseComprehensiveRecommendations(response.content)
            
            // If no recommendations were parsed, return nil
            guard !recommendations.topRecommendations.isEmpty else {
                logger.warning("⚠️ [AI] No recommendations parsed from response")
                print("⚠️ [AI] PARSING FAILED - No recommendations found in response!")
                print("⚠️ [AI] Response length: \(response.content.count) chars")
                print("⚠️ [AI] First 1000 chars of response:\n\(response.content.prefix(1000))")
                return nil
            }
            
            recommendations.analyzedPeriod = periodAnalyzed
            
            // Save to history
            let historyEntry = RecommendationHistoryEntry(
                recommendations: recommendations,
                rangeType: rangeType,
                periodAnalyzed: periodAnalyzed,
                metricsSnapshot: metricsSnapshot
            )
            
            do {
                try await historyStorage.save(historyEntry)
                logger.info("💾 [History] Saved recommendation to history")
            } catch {
                logger.error("❌ [History] Failed to save recommendation: \(error.localizedDescription)")
                // Continue anyway - history save failure shouldn't block recommendations
            }
            
            logger.info("✨ [AI] Parsed comprehensive recommendations successfully (\(recommendations.topRecommendations.count) recommendations)")
            
            return recommendations
            #else
            // FoundationModels not available - should not reach here
            return nil
            #endif
        } catch {
            logger.error("❌ [AI] Comprehensive recommendations error: \(error.localizedDescription)")
            print("❌ [AI] ERROR generating recommendations: \(error.localizedDescription)")
            if error.localizedDescription.contains("context window") {
                logger.warning("⚠️ Context window exceeded - consider splitting into 2 calls")
                print("⚠️ [AI] Context window exceeded - prompt might be too long")
            }
            return nil
        }
    }
    
    /// Generate comprehensive recommendations using Groq API
    private func generateComprehensiveRecommendationsWithGroq(
        profile: UserProfile,
        patternInsights: PatternInsights,
        bodyCompositionPrediction: BodyCompositionPrediction,
        rangeType: String,
        dayCount: Int,
        avgStepsPerDay: Double
    ) async -> ComprehensiveRecommendations? {
        logger.info("🎯 [Groq] Generating comprehensive recommendations for \(rangeType)")
        print("🎯 [Groq] Starting comprehensive recommendations generation for \(rangeType)")
        
        // Load previous recommendation history for this range type
        let previousRecommendation = await historyStorage.getLastRecommendation(for: rangeType)
        if let previous = previousRecommendation {
            let daysAgo = Calendar.current.dateComponents([.day], from: previous.generatedAt, to: Date()).day ?? 0
            logger.info("📚 [History] Found previous recommendation from \(daysAgo) days ago")
        } else {
            logger.info("📚 [History] No previous recommendation found - first time for \(rangeType)")
        }
        
        // Create metrics snapshot for comparison
        let metricsSnapshot = createMetricsSnapshot(
            patternInsights: patternInsights,
            bodyCompositionPrediction: bodyCompositionPrediction,
            dayCount: dayCount,
            avgStepsPerDay: avgStepsPerDay
        )
        
        // Build period analyzed string
        let periodAnalyzed = createPeriodAnalyzedString(rangeType: rangeType, dayCount: dayCount)
        
        // Build optimized prompt with history context (same as Apple Intelligence)
        let prompt = buildComprehensivePrompt(
            profile: profile,
            patternInsights: patternInsights,
            bodyCompositionPrediction: bodyCompositionPrediction,
            rangeType: rangeType,
            dayCount: dayCount,
            previousRecommendation: previousRecommendation,
            currentMetrics: metricsSnapshot
        )
        
        do {
            logger.info("🔄 [Groq] Calling Groq API for comprehensive recommendations...")
            logger.debug("📝 [Groq] Prompt length: \(prompt.count) chars (~\(prompt.count / 4) tokens)")
            
            let response = try await callGroqAPI(prompt: prompt, temperature: 0.7, maxTokens: 2000)
            
            logger.info("✅ [Groq] Comprehensive recommendations received (\(response.count) chars)")
            logger.debug("📝 [Groq] Raw response:\n\(response)")
            
            // Parse the response (same parser as Apple Intelligence)
            var recommendations = parseComprehensiveRecommendations(response)
            
            // If no recommendations were parsed, return nil
            guard !recommendations.topRecommendations.isEmpty else {
                logger.warning("⚠️ [Groq] No recommendations parsed from response")
                print("⚠️ [Groq] PARSING FAILED - No recommendations found in response!")
                print("⚠️ [Groq] Response length: \(response.count) chars")
                print("⚠️ [Groq] First 1000 chars of response:\n\(response.prefix(1000))")
                return nil
            }
            
            recommendations.analyzedPeriod = periodAnalyzed
            
            // Save to history
            let historyEntry = RecommendationHistoryEntry(
                recommendations: recommendations,
                rangeType: rangeType,
                periodAnalyzed: periodAnalyzed,
                metricsSnapshot: metricsSnapshot
            )
            
            do {
                try await historyStorage.save(historyEntry)
                logger.info("💾 [History] Saved recommendation to history")
            } catch {
                logger.error("❌ [History] Failed to save recommendation: \(error.localizedDescription)")
                // Continue anyway - history save failure shouldn't block recommendations
            }
            
            logger.info("✨ [Groq] Parsed comprehensive recommendations successfully (\(recommendations.topRecommendations.count) recommendations)")
            
            return recommendations
        } catch {
            logger.error("❌ [Groq] Comprehensive recommendations error: \(error.localizedDescription)")
            print("❌ [Groq] ERROR generating recommendations: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func buildComprehensivePrompt(
        profile: UserProfile,
        patternInsights: PatternInsights,
        bodyCompositionPrediction: BodyCompositionPrediction,
        rangeType: String,
        dayCount: Int,
        previousRecommendation: RecommendationHistoryEntry?,
        currentMetrics: MetricsSnapshot
    ) -> String {
        let age = profile.age.map { "\($0)" } ?? "unknown"
        let goals = profile.fitnessGoals.map { $0.rawValue }.joined(separator: ", ")
        _ = profile.fitnessGoals.first ?? .loseWeight
        
        // Format efficiency metrics
        let workoutEff = String(format: "%.1f", patternInsights.efficiencyScore.workoutEfficiency)
        let heartEff = patternInsights.efficiencyScore.heartHealthEfficiency.map { String(format: "%.1f", $0) } ?? "N/A"
        let sleepEff = patternInsights.efficiencyScore.sleepEfficiency.map { String(format: "%.0f", $0) } ?? "N/A"
        let fitnessGains = patternInsights.efficiencyScore.fitnessGains.map { String(format: "%.2f", $0) } ?? "N/A"
        let fitnessUnit = patternInsights.efficiencyScore.hasWorkouts ? "workout" : "day"
        
        // Get best/worst performing days
        let bestDay = patternInsights.bestPerformingDays.first(where: { $0.rank == 1 })?.dayOfWeek.shortName ?? "N/A"
        let worstDay = patternInsights.bestPerformingDays.first(where: { $0.rank >= 6 })?.dayOfWeek.shortName ?? "N/A"
        
        // Format activity patterns
        let activePct = String(format: "%.0f", patternInsights.activeInactivePattern.activePercentage)
        let consistency = String(format: "%.0f", patternInsights.consistencyHeatmap.consistencyScore)
        let plateau = patternInsights.plateauStatus.isPlateau ? "Yes" : "No"
        let plateauSev = patternInsights.plateauStatus.isPlateau ? String(describing: patternInsights.plateauStatus.severity) : "none"
        let inactiveDays = patternInsights.activeInactivePattern.inactiveDaysCount
        
        // Calculate average active calories per day
        let avgActiveCalPerDay = bodyCompositionPrediction.avgCaloriesBurned
        
        // Format comparisons - top 5 metrics by absolute change
        let significantMetrics = patternInsights.comparisons.metrics
            .sorted { abs($0.absoluteChange ?? 0) > abs($1.absoluteChange ?? 0) }
            .prefix(5)
        
        var comparisonLines: [String] = []
        for metric in significantMetrics {
            let current = metric.current.map { String(format: "%.1f", $0) } ?? "N/A"
            let pct = metric.percentChange.map { String(format: "%.1f", $0) } ?? "0"
            let trend = metric.direction == .improving ? "↑" : (metric.direction == .declining ? "↓" : "→")
            comparisonLines.append("\(metric.name):\(current) (\(pct)%) \(trend)")
        }
        
        // Top 2 workout types
        let topWorkouts = patternInsights.comparisons.caloriesByWorkoutType.prefix(2)
        var workoutTypeLines: [String] = []
        for workout in topWorkouts {
            let pct = workout.percentChange.map { String(format: "%.1f", $0) } ?? "0"
            let trend = workout.direction == .improving ? "↑" : (workout.direction == .declining ? "↓" : "→")
            workoutTypeLines.append("\(workout.type):\(String(format: "%.0f", workout.currentKcal))kcal(\(pct)%) \(trend)")
        }
        
        // Format body composition
        let fatLoss = String(format: "%.2f", bodyCompositionPrediction.fatLoss)
        let muscleGain = String(format: "%.2f", bodyCompositionPrediction.muscleGain)
        let muscleLoss = String(format: "%.2f", bodyCompositionPrediction.muscleLoss)
        let netChange = String(format: "%.2f", bodyCompositionPrediction.netWeightChange)
        let bfChange = bodyCompositionPrediction.bodyFatPercentageChange.map { String(format: "%.2f", $0) } ?? "N/A"
        
        // Format metabolic data
        let maint = String(format: "%.0f", bodyCompositionPrediction.maintenanceCalories)
        let newMaint = String(format: "%.0f", bodyCompositionPrediction.newMaintenanceCalories)
        let deficit = String(format: "%.0f", bodyCompositionPrediction.calorieDeficit)
        let surplus = String(format: "%.0f", bodyCompositionPrediction.calorieSurplus)
        let bmrIncrease = String(format: "%.0f", bodyCompositionPrediction.bmrIncrease)
        
        // Format fitness progress
        _ = String(format: "%.1f", bodyCompositionPrediction.strengthGain)
        _ = String(format: "%.1f", bodyCompositionPrediction.enduranceGain)
        _ = bodyCompositionPrediction.vo2MaxImprovement.map { String(format: "%.2f", $0) } ?? "N/A"
        let energy = String(format: "%.0f", bodyCompositionPrediction.energyLevelImprovement)
        let strCount = bodyCompositionPrediction.strengthWorkoutCount
        let cardCount = bodyCompositionPrediction.cardioWorkoutCount
        let workoutsPerWeek = Double(strCount + cardCount) / (Double(dayCount) / 7.0)
        let totMinutes = String(format: "%.0f", bodyCompositionPrediction.totalWorkoutMinutes)
        
        // Format recovery
        let recScore = String(format: "%.0f", bodyCompositionPrediction.recoveryQualityScore)
        let risk = String(describing: bodyCompositionPrediction.overtrainingRisk)
        let sleepHrs = String(format: "%.1f", bodyCompositionPrediction.avgSleepHours)
        
        // Build sections conditionally - only include metrics with actual data
        var sections: [String] = []
        
        // USER PROFILE (always included)
        sections.append("""
        USER PROFILE:
        Age: \(age) | Gender: \(profile.gender.rawValue) | Height: \(Int(profile.height))cm
        Weight: \(String(format: "%.1f", profile.weight))kg → Target: \(String(format: "%.1f", profile.targetWeight))kg
        Primary Goal: \(goals) | Period: \(rangeType) (\(dayCount) days)
        """)
        
        // WORKOUT DATA (only if there are workouts)
        if workoutsPerWeek > 0 || strCount > 0 || cardCount > 0 {
            sections.append("""
            WORKOUT DATA:
            Sessions/week: \(String(format: "%.1f", workoutsPerWeek)) | Strength: \(strCount) | Cardio: \(cardCount)
            Total minutes: \(totMinutes)min | Workout efficiency: \(workoutEff) cal/min
            Avg active calories/day: \(String(format: "%.0f", avgActiveCalPerDay)) cal
            """)
        }
        
        // BODY COMPOSITION (always included - it's calculated)
        var bodyCompLines: [String] = [
            "Fat loss: \(fatLoss)kg | Muscle gain: \(muscleGain)kg | Muscle loss: \(muscleLoss)kg",
            "Net change: \(netChange)kg"
        ]
        if bfChange != "N/A" {
            bodyCompLines.append("Body fat % change: \(bfChange)%")
        }
        sections.append("BODY COMPOSITION:\n\(bodyCompLines.joined(separator: "\n"))")
        
        // METABOLIC (always included - calculated from activity)
        sections.append("""
        METABOLIC:
        Maintenance: \(maint)kcal | New maintenance: \(newMaint)kcal
        Deficit: \(deficit)kcal | Surplus: \(surplus)kcal | BMR increase: +\(bmrIncrease)kcal/day
        """)
        
        // EFFICIENCY METRICS (only include metrics that have data, skip if all are N/A)
        var efficiencyLines: [String] = []
        efficiencyLines.append("Workout: \(workoutEff) cal/min")
        if heartEff != "N/A" {
            efficiencyLines.append("Heart recovery: \(heartEff) bpm/min")
        }
        if sleepEff != "N/A" {
            efficiencyLines.append("Sleep efficiency: \(sleepEff)%")
        }
        if fitnessGains != "N/A" {
            efficiencyLines.append("Fitness gains: \(fitnessGains) VO₂/\(fitnessUnit)")
        }
        if !efficiencyLines.isEmpty {
            sections.append("EFFICIENCY METRICS:\n\(efficiencyLines.joined(separator: " | "))")
        }
        
        // ACTIVITY PATTERNS (always included)
        sections.append("""
        ACTIVITY PATTERNS:
        Active days: \(patternInsights.activeInactivePattern.activeDaysCount)/\(patternInsights.activeInactivePattern.totalDays) (\(activePct)%)
        Inactive days: \(inactiveDays) | Consistency: \(consistency)/100
        Best day: \(bestDay) | Worst day: \(worstDay)
        Plateau: \(plateau) (\(plateauSev))
        """)
        
        // RECOVERY (include if we have meaningful recovery data - sleep, recovery score, or energy data)
        var recoveryLines: [String] = []
        var hasRecoveryData = false
        
        if bodyCompositionPrediction.avgSleepHours > 0 {
            var sleepLine = "Sleep: \(sleepHrs)h"
            if sleepEff != "N/A" {
                sleepLine += " (\(sleepEff)% efficiency)"
            }
            recoveryLines.append(sleepLine)
            hasRecoveryData = true
        }
        
        // Include recovery score, overtraining risk, and energy if they have meaningful values
        recoveryLines.append("Recovery score: \(recScore)/100 | Overtraining risk: \(risk)")
        recoveryLines.append("Energy improvement: \(energy)%")
        hasRecoveryData = true // Recovery score and energy are always calculated
        
        if hasRecoveryData {
            sections.append("RECOVERY:\n\(recoveryLines.joined(separator: "\n"))")
        }
        
        // COMPARISONS (only if we have comparison data)
        if !comparisonLines.isEmpty || !workoutTypeLines.isEmpty {
            var comparisonSection = "COMPARISONS (\(patternInsights.comparisons.periodLabel)):"
            if !comparisonLines.isEmpty {
                comparisonSection += "\n\(comparisonLines.joined(separator: "\n"))"
            }
            if !workoutTypeLines.isEmpty {
                comparisonSection += "\nWorkout types: " + workoutTypeLines.joined(separator: " | ")
            }
            sections.append(comparisonSection)
        }
        
        // NUTRITION - ONLY include if we have actual tracked nutrition data
        // We don't track nutrition data in this function, so NUTRITION section is never included
        // (Nutrition data would need to be passed in separately if available)
        
        // Build available metrics whitelist
        var availableMetrics: [String] = ["User Profile"]
        if workoutsPerWeek > 0 || strCount > 0 || cardCount > 0 {
            availableMetrics.append("Workout Data")
        }
        availableMetrics.append("Body Composition")
        availableMetrics.append("Metabolic")
        if !efficiencyLines.isEmpty {
            availableMetrics.append("Efficiency Metrics")
        }
        availableMetrics.append("Activity Patterns")
        if hasRecoveryData {
            availableMetrics.append("Recovery")
        }
        if !comparisonLines.isEmpty || !workoutTypeLines.isEmpty {
            availableMetrics.append("Comparisons")
        }
        // Nutrition is NOT in availableMetrics since we don't have actual tracked nutrition data
        
        return """
        You are a certified fitness coach analyzing a user's health data. Generate 4-5 PRIORITIZED, actionable recommendations.
        
        \(createTimeRangeContext(rangeType: rangeType, dayCount: dayCount))
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        AVAILABLE METRICS (WHITELIST - ONLY USE THESE):
        \(availableMetrics.joined(separator: ", "))
        
        CRITICAL INSTRUCTIONS:
        - You MUST ONLY use metrics from the AVAILABLE METRICS list above
        - Do NOT reference, infer, or mention any metric NOT in the AVAILABLE METRICS list
        - Prioritize by IMPACT on their goal + general health
        - Give DIRECT COMMANDS (e.g., "Do more cardio", "Increase strength training to 3x per week")
        - Focus on HIGHEST IMPACT issues first
        - Consider: age, gender, weight, height, goals, and ONLY the metrics listed in AVAILABLE METRICS
        - If a section is NOT in AVAILABLE METRICS, it does NOT exist - do not reference it at all
        - DO NOT write "Current: [metric] not specified" or "not tracked" - only use metrics from AVAILABLE METRICS
        - Each recommendation's "Current" field MUST reference actual data from the sections below
        - If you cannot provide a "Current" value from available data, create a different recommendation
        - Output EXACTLY 4-5 recommendations (not more, not less)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        \(sections.joined(separator: "\n"))
        
        \(buildPreviousRecommendationContext(previousRecommendation: previousRecommendation, currentMetrics: currentMetrics))
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        OUTPUT FORMAT (CRITICAL - FOLLOW EXACTLY):
        
        You MUST use this exact format for each recommendation. Do NOT use markdown formatting, bullet points, or alternative formats.
        
        [1] PRIORITY: [Direct command - e.g., "Do more cardio"]
        Current: [Current state with numbers]
        Target: [Target state with numbers]
        Impact: [How this affects their goal - be specific with % or timeframes]
        Why: [Reason based on their data]
        Health: [General health benefit if applicable]
        Note: [Mark if estimated data]
        
        [2] PRIORITY: [Direct command]
        Current: [Current state]
        Target: [Target state]
        Impact: [Impact on goal]
        Why: [Reason]
        Health: [Health benefit]
        
        [3] PRIORITY: [Direct command]
        Current: [Current state]
        Target: [Target state]
        Impact: [Impact]
        Why: [Reason]
        Health: [Health benefit]
        
        [4] PRIORITY: [Direct command]
        Current: [Current state]
        Target: [Target state]
        Impact: [Impact]
        Why: [Reason]
        
        [5] PRIORITY: [Direct command]
        Current: [Current state]
        Target: [Target state]
        Impact: [Impact]
        Why: [Reason]
        
        IMPORTANT FORMATTING RULES:
        - Use [1], [2], [3], [4], [5] with square brackets
        - Follow "PRIORITY:" immediately after the number
        - Each field (Current, Target, Impact, Why, Health, Note) should be on its own line
        - Do NOT use markdown formatting (**bold**, ### headers, - bullet points)
        - Do NOT use "Recommendation 1:" format
        - Start each field label at the beginning of the line (no indentation)
        
        PRIORITIZATION RULES:
        1. Goal impact first: Weight loss = calories/cardio priority | Muscle gain = strength training priority (NOT protein if nutrition data unavailable)
        2. Health critical issues: Overtraining risk, sleep deprivation, severe plateaus
        3. Quick wins: Easy changes with high impact
        4. General health: Recovery, consistency, activity levels
        
        STRICT RESTRICTIONS:
        - ONLY reference metrics from the AVAILABLE METRICS list at the top
        - If a metric is NOT in AVAILABLE METRICS, it does NOT exist - do not mention it in any way
        - Do not infer or assume data that isn't provided
        - If NUTRITION is NOT in AVAILABLE METRICS, do not mention protein, nutrition, or dietary recommendations
        - If RECOVERY is NOT in AVAILABLE METRICS, do not mention sleep, recovery, or rest recommendations
        - If EFFICIENCY METRICS is NOT in AVAILABLE METRICS, do not mention efficiency metrics
        - Focus recommendations ONLY on sections listed in AVAILABLE METRICS
        
        Use simple, direct commands. Write in second person. Be specific with numbers.
        """
    }
    
    // MARK: - History Helper Functions
    
    /// Build context about previous recommendation for the prompt
    private func buildPreviousRecommendationContext(
        previousRecommendation: RecommendationHistoryEntry?,
        currentMetrics: MetricsSnapshot
    ) -> String {
        guard let previous = previousRecommendation else {
            return """
            PREVIOUS RECOMMENDATION: None (first time for this date range)
            """
        }
        
        let daysSince = Calendar.current.dateComponents([.day], from: previous.generatedAt, to: Date()).day ?? 0
        let timeAgo = daysSince == 0 ? "today" : daysSince == 1 ? "yesterday" : "\(daysSince) days ago"
        
        // Build previous recommendations list
        var previousRecsText = ""
        for (index, rec) in previous.recommendations.topRecommendations.sorted(by: { $0.priority < $1.priority }).enumerated() {
            previousRecsText += "\(index + 1). \(rec.command)\n"
        }
        
        // Compare metrics if available
        var progressText = ""
        if let prevMetrics = previous.metricsSnapshot {
            let workoutChange = currentMetrics.workoutsPerWeek - prevMetrics.workoutsPerWeek
            let caloriesChange = currentMetrics.avgActiveCalories - prevMetrics.avgActiveCalories
            let stepsChange = currentMetrics.avgSteps - prevMetrics.avgSteps
            
            progressText = """
            
            PROGRESS SINCE LAST RECOMMENDATION (\(timeAgo)):
            Workouts/week: \(String(format: "%.1f", prevMetrics.workoutsPerWeek)) → \(String(format: "%.1f", currentMetrics.workoutsPerWeek)) (\(String(format: "%+.1f", workoutChange)))
            Active calories: \(String(format: "%.0f", prevMetrics.avgActiveCalories)) → \(String(format: "%.0f", currentMetrics.avgActiveCalories)) cal/day (\(String(format: "%+.0f", caloriesChange)))
            Steps/day: \(String(format: "%.0f", prevMetrics.avgSteps)) → \(String(format: "%.0f", currentMetrics.avgSteps)) (\(String(format: "%+.0f", stepsChange)))
            """
        }
        
        return """
        PREVIOUS RECOMMENDATION (Generated \(timeAgo), Period: \(previous.periodAnalyzed)):
        \(previousRecsText)\(progressText)
        
        IMPORTANT: 
        - Reference previous recommendations when relevant (e.g., "Last week I recommended X...")
        - Acknowledge progress made (e.g., "Great job increasing cardio from 2 to 4 sessions!")
        - Build on previous advice - don't contradict unless data clearly shows previous advice was wrong
        - Follow up: Explain how current status relates to previous recommendations
        """
    }
    
    /// Create a snapshot of current metrics for history comparison
    private func createMetricsSnapshot(
        patternInsights: PatternInsights,
        bodyCompositionPrediction: BodyCompositionPrediction,
        dayCount: Int,
        avgStepsPerDay: Double
    ) -> MetricsSnapshot {
        let workoutsPerWeek = Double(bodyCompositionPrediction.strengthWorkoutCount + bodyCompositionPrediction.cardioWorkoutCount) / (Double(dayCount) / 7.0)
        
        return MetricsSnapshot(
            workoutsPerWeek: workoutsPerWeek,
            avgActiveCalories: bodyCompositionPrediction.avgCaloriesBurned,
            avgSteps: avgStepsPerDay,
            strengthWorkoutCount: bodyCompositionPrediction.strengthWorkoutCount,
            cardioWorkoutCount: bodyCompositionPrediction.cardioWorkoutCount,
            sleepHours: bodyCompositionPrediction.avgSleepHours,
            recoveryScore: bodyCompositionPrediction.recoveryQualityScore,
            bodyFatLoss: bodyCompositionPrediction.fatLoss,
            muscleGain: bodyCompositionPrediction.muscleGain
        )
    }
    
    /// Create period analyzed string (e.g., "Jan 8-14, 2024")
    private func createPeriodAnalyzedString(rangeType: String, dayCount: Int) -> String {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -dayCount + 1, to: endDate) else {
            return "\(dayCount) days"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: endDate)
        
        return "\(startStr) - \(endStr), \(year)"
    }
    
    /// Create time range context description for AI prompts
    /// This helps the AI understand what time period it's analyzing
    private func createTimeRangeContext(rangeType: String, dayCount: Int) -> String {
        switch rangeType {
        case "Today":
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for TODAY ONLY (just today's data, not a week or month).
            - All metrics, workouts, and activities shown are from today
            - Recommendations should focus on what happened today and immediate next steps
            - Do not suggest weekly or monthly goals - focus on today's performance and immediate actions
            - If today's data is limited, acknowledge that and provide context-appropriate insights
            """
        case "This Week":
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for THIS WEEK (the current calendar week, approximately 7 days).
            - All metrics, workouts, and activities shown are from this week
            - Recommendations should focus on weekly patterns and weekly goals
            - Compare performance across days within this week
            - Provide insights about weekly consistency and trends
            """
        case "This Month":
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for THIS MONTH (the current calendar month, approximately 30 days).
            - All metrics, workouts, and activities shown are from this month
            - Recommendations should focus on monthly trends and monthly goals
            - Look for patterns and trends over the course of the month
            - Provide insights about monthly progress and consistency
            """
        case "6 Months":
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for THE LAST 6 MONTHS (approximately \(dayCount) days).
            - All metrics, workouts, and activities shown are from the past 6 months
            - Recommendations should focus on long-term trends and patterns
            - Look for significant changes, plateaus, or improvements over this extended period
            - Provide insights about long-term progress and sustained habits
            - Compare early months vs recent months to identify trends
            """
        case "This Year":
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for THIS YEAR (the current calendar year, approximately \(dayCount) days so far).
            - All metrics, workouts, and activities shown are from this year
            - Recommendations should focus on annual trends and long-term goals
            - Look for seasonal patterns, long-term progress, and year-over-year insights
            - Provide insights about annual progress and major milestones
            - Compare different periods within the year to identify trends
            """
        default:
            return """
            TIME RANGE CONTEXT:
            You are analyzing data for a period of \(dayCount) days.
            - All metrics, workouts, and activities shown are from this time period
            - Recommendations should be appropriate for this time scale
            - Consider the length of the period when providing insights and goals
            """
        }
    }
    
    private func parseComprehensiveRecommendations(_ response: String) -> ComprehensiveRecommendations {
        logger.info("🔍 [AI] Parsing coach recommendations...")
        logger.debug("📝 [AI] Raw response (\(response.count) chars):\n\(response)")
        print("📝 [Parsing] Full response (\(response.count) chars):\n\(response)")
        
        var recommendations: [CoachAction] = []
        
        // Split response into lines for parsing
        let lines = response.components(separatedBy: .newlines)
        
        var currentPriority: Int? = nil
        var currentCommand: String = ""
        _ = ActionCategory.activity
        var currentState: String = ""
        var targetState: String = ""
        var impact: String = ""
        var why: String = ""
        var healthBenefit: String? = nil
        var isEstimated: Bool = false
        
        // Helper function to save current recommendation
        func saveCurrentRecommendation() {
            if !currentCommand.isEmpty && currentPriority != nil {
                let category = inferCategory(from: currentCommand)
                recommendations.append(CoachAction(
                    priority: currentPriority!,
                    category: category,
                    command: currentCommand,
                    currentState: currentState,
                    targetState: targetState,
                    impact: impact,
                    why: why,
                    healthBenefit: healthBenefit,
                    isEstimated: isEstimated
                ))
                
                // Reset for next recommendation
                currentCommand = ""
                currentState = ""
                targetState = ""
                impact = ""
                why = ""
                healthBenefit = nil
                isEstimated = false
            }
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines, separators, and markdown horizontal rules
            if trimmed.isEmpty || trimmed.hasPrefix("━") || trimmed.hasPrefix("---") || trimmed.hasPrefix("***") {
                continue
            }
            
            // Match priority header in multiple formats:
            // 1. "[1] PRIORITY: [command]"
            // 2. "### [1] PRIORITY: [command]"
            // 3. "1. PRIORITY: [command]" (no brackets)
            // 4. "### Recommendation 1: [command]" with **Priority:** on next line
            
            let cleanedForPriority = trimmed.replacingOccurrences(of: "###", with: "")
                .replacingOccurrences(of: "##", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            var detectedPriority: Int? = nil
            var detectedCommand: String? = nil
            
            // Pattern 1 & 2: "[1] PRIORITY: command" or "### [1] PRIORITY: command"
            if let bracketMatch = cleanedForPriority.range(of: #"\[(\d+)\]"#, options: .regularExpression) {
                let priorityStr = String(cleanedForPriority[bracketMatch])
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                detectedPriority = Int(priorityStr)
                
                if let priorityRange = cleanedForPriority.range(of: "PRIORITY:", options: .caseInsensitive) {
                    detectedCommand = String(cleanedForPriority[priorityRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            // Pattern 3: "1. PRIORITY: command" (number with period, no brackets)
            else if let numberMatch = cleanedForPriority.range(of: #"^(\d+)\.\s*PRIORITY:"#, options: [.regularExpression, .caseInsensitive]) {
                let matchStr = String(cleanedForPriority[numberMatch])
                if let priorityStr = matchStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined().first.flatMap({ String($0) }),
                   let priority = Int(priorityStr) {
                    detectedPriority = priority
                }
                if let priorityRange = cleanedForPriority.range(of: "PRIORITY:", options: .caseInsensitive) {
                    detectedCommand = String(cleanedForPriority[priorityRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            // Pattern 4: "### Recommendation 1: command" (will check for Priority on next line)
            else if cleanedForPriority.lowercased().hasPrefix("recommendation") {
                // Extract number from "Recommendation 1:"
                if let numMatch = cleanedForPriority.range(of: #"(\d+)"#, options: .regularExpression) {
                    let numStr = String(cleanedForPriority[numMatch])
                    detectedPriority = Int(numStr)
                }
                // Extract command (everything after colon)
                if let colonRange = cleanedForPriority.range(of: ":") {
                    detectedCommand = String(cleanedForPriority[colonRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            // Pattern: "**Priority:** 1" on its own line (for Recommendation format)
            else if trimmed.lowercased().contains("priority:") && trimmed.contains("**") {
                // Extract priority number
                if let numMatch = trimmed.range(of: #"(\d+)"#, options: .regularExpression) {
                    let numStr = String(trimmed[numMatch])
                    if let priority = Int(numStr), currentCommand.isEmpty == false {
                        // If we already have a command but no priority, set it
                        if currentPriority == nil {
                            currentPriority = priority
                        }
                    }
                }
            }
            
            // If we found a new priority header, save previous and start new
            if let priority = detectedPriority, let command = detectedCommand, !command.isEmpty {
                saveCurrentRecommendation()
                currentPriority = priority
                currentCommand = command
                continue
            } else if let priority = detectedPriority, let command = detectedCommand {
                // Priority found but command might be empty - start tracking
                saveCurrentRecommendation()
                currentPriority = priority
                currentCommand = command.isEmpty ? "" : command
                continue
            }
            // Match field labels (handle multiple formats:
            // - "Current: value"
            // - "**Current:** value"
            // - "- **Current:** value" (with bullet point)
            // Fields can be on same line or continue on next line)
            
            let cleaned = trimmed.replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "- ", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if cleaned.lowercased().contains("current:") {
                // Extract content after "Current:"
                if let currentRange = cleaned.range(of: "Current:", options: .caseInsensitive) {
                    let value = String(cleaned[currentRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        currentState = value
                    }
                }
            }
            else if cleaned.lowercased().contains("target:") {
                if let targetRange = cleaned.range(of: "Target:", options: .caseInsensitive) {
                    let value = String(cleaned[targetRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        targetState = value
                    }
                }
            }
            else if cleaned.lowercased().contains("impact:") {
                if let impactRange = cleaned.range(of: "Impact:", options: .caseInsensitive) {
                    let value = String(cleaned[impactRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        impact = value
                    }
                }
            }
            else if cleaned.lowercased().contains("why:") {
                if let whyRange = cleaned.range(of: "Why:", options: .caseInsensitive) {
                    let value = String(cleaned[whyRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        why = value
                    }
                }
            }
            else if cleaned.lowercased().contains("health:") {
                if let healthRange = cleaned.range(of: "Health:", options: .caseInsensitive) {
                    let value = String(cleaned[healthRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        healthBenefit = value
                    }
                }
            }
            else if cleaned.lowercased().contains("note:") {
                if let noteRange = cleaned.range(of: "Note:", options: .caseInsensitive) {
                    let value = String(cleaned[noteRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        isEstimated = value.lowercased().contains("estimated") || value.lowercased().contains("estimate")
                    }
                }
            }
            // Handle continuation lines (if previous field was set and line doesn't start with new field)
            else if !trimmed.isEmpty && 
                    !cleaned.lowercased().hasPrefix("recommendation") &&
                    !cleaned.contains("priority:") &&
                    currentPriority != nil {
                // This might be a continuation of a previous field - append if last field was multi-line
                // (We'll handle this by not clearing fields until we hit a new priority)
            }
        }
        
        // Save last recommendation
        saveCurrentRecommendation()
        
        // Extract period from response or use default
        let analyzedPeriod = extractPeriod(from: response) ?? "This Period"
        
        logger.info("✅ [AI] Parsed \(recommendations.count) coach recommendations")
        print("✅ [Parsing] Found \(recommendations.count) recommendations")
        for (index, rec) in recommendations.enumerated() {
            logger.debug("   [\(index + 1)] \(rec.command.prefix(50))...")
            print("   [\(index + 1)] Priority \(rec.priority): \(rec.command.prefix(60))...")
        }
        
        if recommendations.isEmpty {
            print("⚠️ [Parsing] WARNING: No recommendations were parsed! Response length: \(response.count)")
            print("⚠️ [Parsing] First 500 chars of response:\n\(response.prefix(500))")
        }
        
        return ComprehensiveRecommendations(
            topRecommendations: recommendations,
            analyzedPeriod: analyzedPeriod
        )
    }
    
    // Helper: Infer category from command text
    private func inferCategory(from command: String) -> ActionCategory {
        let lower = command.lowercased()
        if lower.contains("cardio") || lower.contains("run") || lower.contains("walk") || lower.contains("hii") {
            return .cardio
        } else if lower.contains("strength") || lower.contains("muscle") || lower.contains("weight") || lower.contains("lift") {
            return .strength
        } else if lower.contains("eat") || lower.contains("protein") || lower.contains("calorie") || lower.contains("meat") || lower.contains("chicken") || lower.contains("nutrition") {
            return .nutrition
        } else if lower.contains("sleep") || lower.contains("recovery") || lower.contains("rest") {
            return .recovery
        } else if lower.contains("calorie") {
            return .calories
        } else {
            return .activity
        }
    }
    
    // Helper: Extract period from response
    private func extractPeriod(from response: String) -> String? {
        let patterns = [
            "This Week",
            "This Month",
            "Last Week",
            "Last Month",
            "Week",
            "Month"
        ]
        
        for pattern in patterns {
            if response.contains(pattern) {
                return pattern
            }
        }
        return nil
    }
    
    private func parseKeyValuePairs(_ line: String, into storage: inout String, keys: [String]) {
        for key in keys {
            if let range = line.range(of: "\(key):", options: .caseInsensitive) {
                let afterColon = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                // Take up to the next "|" or end of line
                if let pipeIndex = afterColon.firstIndex(of: "|") {
                    storage = String(afterColon[..<pipeIndex]).trimmingCharacters(in: .whitespaces)
                } else {
                    storage = afterColon.trimmingCharacters(in: .whitespaces)
                }
                break
            }
        }
    }
}


// MARK: - Supporting Types

struct HealthMetrics {
    let avgDailySteps: Double
    let avgActiveCalories: Double
    let recentWeekAverage: Double
    let previousWeekAverage: Double
    let weeklyVariance: Double
    let workoutFrequency: Int
    let weightTrend: Double
    let morningAverage: Double
    let eveningAverage: Double
}

// MARK: - Coach Recommendations Types

struct ComprehensiveRecommendations: Codable {
    let topRecommendations: [CoachAction]  // 4-5 prioritized actions
    var analyzedPeriod: String              // "This Week", "1 Month", etc. (mutable to allow setting after parsing)
}

struct CoachAction: Identifiable, Codable {
    var id: Int { priority }               // Use priority as ID for uniqueness
    let priority: Int                      // 1 = highest priority
    let category: ActionCategory           // Cardio, Strength, Nutrition, Recovery, Activity
    let command: String                    // "Do more cardio"
    let currentState: String               // "2 sessions/week, 450 cal/day"
    let targetState: String                // "4 sessions/week, 600 cal/day"
    let impact: String                     // "Will accelerate weight loss by 30%"
    let why: String                        // Brief reason
    let healthBenefit: String?             // General health benefit if applicable
    let isEstimated: Bool                  // True if based on estimated data
}

enum ActionCategory: String, Codable {
    case cardio = "Cardio"
    case strength = "Strength"
    case nutrition = "Nutrition"
    case recovery = "Recovery"
    case activity = "Activity"
    case calories = "Calories"
}

// MARK: - Recommendation History Types

/// A single recommendation entry in history
struct RecommendationHistoryEntry: Codable {
    let id: String                      // Unique ID for this entry
    let generatedAt: Date              // When this recommendation was created
    let rangeType: String               // "This Week", "This Month", etc.
    let periodAnalyzed: String          // "Jan 8-14, 2024" - dates analyzed
    let recommendations: ComprehensiveRecommendations  // The actual recommendations
    let metricsSnapshot: MetricsSnapshot? // Key metrics at time of generation (for comparison)
    
    init(recommendations: ComprehensiveRecommendations, rangeType: String, periodAnalyzed: String, metricsSnapshot: MetricsSnapshot? = nil) {
        self.id = UUID().uuidString
        self.generatedAt = Date()
        self.rangeType = rangeType
        self.periodAnalyzed = periodAnalyzed
        self.recommendations = recommendations
        self.metricsSnapshot = metricsSnapshot
    }
}

/// Snapshot of key metrics when recommendation was generated (for progress comparison)
struct MetricsSnapshot: Codable {
    let workoutsPerWeek: Double
    let avgActiveCalories: Double
    let avgSteps: Double
    let strengthWorkoutCount: Int
    let cardioWorkoutCount: Int
    let sleepHours: Double
    let recoveryScore: Double
    let bodyFatLoss: Double
    let muscleGain: Double
}

/// Storage protocol for recommendation history (CloudKit-ready abstraction)
protocol RecommendationHistoryStorage {
    /// Save a recommendation entry
    func save(_ entry: RecommendationHistoryEntry) async throws
    
    /// Get the most recent recommendation for a date range type
    func getLastRecommendation(for rangeType: String) async -> RecommendationHistoryEntry?
    
    /// Get recent recommendation history (limit: max number to return)
    func getRecentHistory(for rangeType: String, limit: Int) async -> [RecommendationHistoryEntry]
    
    /// Clear all history for a specific range type
    func clearHistory(for rangeType: String) async throws
}

// MARK: - File-Based Recommendation History Storage

/// File-based implementation of recommendation history storage
/// Stores as JSON files in Documents/RecommendationHistory/
/// CloudKit can be added later as alternative implementation
class FileRecommendationHistoryStorage: RecommendationHistoryStorage {
    private let logger = Logger(subsystem: "com.healthai.app", category: "RecommendationHistory")
    private let maxEntriesPerRange = 20 // Keep last 20 recommendations per range type
    
    private var historyDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let historyPath = documentsPath.appendingPathComponent("RecommendationHistory", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: historyPath.path) {
            try? FileManager.default.createDirectory(at: historyPath, withIntermediateDirectories: true)
        }
        
        return historyPath
    }
    
    private func fileURL(for rangeType: String) -> URL {
        // Sanitize range type for filename (remove spaces, special chars)
        let sanitized = rangeType.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .lowercased()
        return historyDirectory.appendingPathComponent("\(sanitized).json")
    }
    
    func save(_ entry: RecommendationHistoryEntry) async throws {
        logger.info("💾 [History] Saving recommendation for \(entry.rangeType)")
        
        // Load existing history
        var history = await getRecentHistory(for: entry.rangeType, limit: maxEntriesPerRange * 2)
        
        // Add new entry at the beginning (most recent first)
        history.insert(entry, at: 0)
        
        // Keep only last maxEntriesPerRange entries
        if history.count > maxEntriesPerRange {
            history = Array(history.prefix(maxEntriesPerRange))
        }
        
        // Save to file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(history)
            let fileURL = fileURL(for: entry.rangeType)
            try data.write(to: fileURL, options: .atomic)
            logger.info("✅ [History] Saved \(history.count) entries for \(entry.rangeType)")
        } catch {
            logger.error("❌ [History] Failed to save: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getLastRecommendation(for rangeType: String) async -> RecommendationHistoryEntry? {
        let history = await getRecentHistory(for: rangeType, limit: 1)
        return history.first
    }
    
    func getRecentHistory(for rangeType: String, limit: Int) async -> [RecommendationHistoryEntry] {
        let fileURL = fileURL(for: rangeType)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.debug("📭 [History] No history file found for \(rangeType)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var history = try decoder.decode([RecommendationHistoryEntry].self, from: data)
            
            // Sort by date (most recent first) and limit
            history.sort { $0.generatedAt > $1.generatedAt }
            return Array(history.prefix(limit))
        } catch {
            logger.error("❌ [History] Failed to load history for \(rangeType): \(error.localizedDescription)")
            return []
        }
    }
    
    func clearHistory(for rangeType: String) async throws {
        let fileURL = fileURL(for: rangeType)
        try FileManager.default.removeItem(at: fileURL)
        logger.info("🗑️ [History] Cleared history for \(rangeType)")
    }
}
