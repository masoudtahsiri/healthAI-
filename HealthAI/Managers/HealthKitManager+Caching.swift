
import Foundation
import HealthKit

extension HealthKitManager {
    
    // MARK: - Cache-Friendly Fetching Methods
    
    /// Fetch all workouts and return them
    func fetchAllWorkouts(startDate: Date, endDate: Date) async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error fetching all workouts: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch all data as daily metrics for caching using efficient HealthKit StatisticsCollectionQuery
    func fetchAllDailyMetrics(startDate: Date, endDate: Date) async -> AllDailyMetrics {
        let calendar = Calendar.current
        var allMetrics = AllDailyMetrics()
        
        print("📊 [Cache] Fetching all daily metrics from \(startDate) to \(endDate) using aggregated queries")
        
        // Fetch workouts (this is fast, no limit needed)
        allMetrics.workouts = await fetchAllWorkouts(startDate: startDate, endDate: endDate)
        print("   ✅ Workouts: \(allMetrics.workouts.count)")
        
        // Use StatisticsCollectionQuery to get daily aggregates efficiently
        let anchorDate = calendar.startOfDay(for: endDate)
        let interval = DateComponents(day: 1)
        
        // Fetch all metrics in parallel using collection queries
        // Use native HealthKit units (except distance which we convert to km)
        async let stepsData = fetchDailyCollection(
            for: .stepCount,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true // Use HealthKit's native unit
        )
        
        async let activeCalData = fetchDailyCollection(
            for: .activeEnergyBurned,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        async let basalCalData = fetchDailyCollection(
            for: .basalEnergyBurned,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        // CRITICAL: Fetch nutrition data (calories consumed, protein) - makes body composition MUCH more accurate
        async let dietaryCalData = fetchDailyCollection(
            for: .dietaryEnergyConsumed,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        async let dietaryProteinData = fetchDailyCollection(
            for: .dietaryProtein,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        async let distanceData = fetchDailyCollection(
            for: .distanceWalkingRunning,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: false, // Convert to km
            convertedUnit: HKUnit.meterUnit(with: .kilo)
        )
        
        let steps = await stepsData
        let activeCal = await activeCalData
        let basalCal = await basalCalData
        let dietaryCal = await dietaryCalData
        let dietaryProtein = await dietaryProteinData
        let distance = await distanceData
        
        // Process results
        for (date, stepsVal) in steps {
            allMetrics.stepsDaily.append(DailyHealthMetric(date: date, value: stepsVal))
        }
        
        for (date, activeVal) in activeCal {
            allMetrics.activeCaloriesDaily.append(DailyHealthMetric(date: date, value: activeVal))
        }
        
        for (date, basalVal) in basalCal {
            // Store basal calories separately
            allMetrics.basalCaloriesDaily.append(DailyHealthMetric(date: date, value: basalVal))
            // Find corresponding active calories and calculate total
            let activeVal = activeCal[date] ?? 0
            let totalVal = activeVal + basalVal
            allMetrics.totalCaloriesDaily.append(DailyHealthMetric(date: date, value: totalVal))
        }
        
        // Store nutrition data (calories consumed, protein)
        for (date, calVal) in dietaryCal {
            allMetrics.dietaryCaloriesDaily.append(DailyHealthMetric(date: date, value: calVal))
        }
        
        for (date, proteinVal) in dietaryProtein {
            allMetrics.dietaryProteinDaily.append(DailyHealthMetric(date: date, value: proteinVal))
        }
        
        for (date, distVal) in distance {
            allMetrics.distanceDaily.append(DailyHealthMetric(date: date, value: distVal))
        }
        
        // Sleep requires sample query (not statistics), so fetch it differently
        async let sleepData = fetchDailySleep(startDate: startDate, endDate: endDate)
        async let sleepInBedData = fetchDailySleepInBed(startDate: startDate, endDate: endDate)
        
        let sleep = await sleepData
        let sleepInBed = await sleepInBedData
        
        for (date, sleepHours) in sleep {
            allMetrics.sleepDaily.append(DailyHealthMetric(date: date, value: sleepHours))
        }
        
        for (date, inBedHours) in sleepInBed {
            allMetrics.sleepInBedDaily.append(DailyHealthMetric(date: date, value: inBedHours))
        }
        
        // Fetch average-based metrics (heart rate, resting heart rate, blood oxygen) - use native units
        async let heartRateData = fetchDailyAverage(
            for: .heartRate,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        async let restingHeartRateData = fetchDailyAverage(
            for: .restingHeartRate,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        // Fetch HRV (Heart Rate Variability) data - important recovery metric
        async let hrvData = fetchDailyAverage(
            for: .heartRateVariabilitySDNN,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        // Fetch HR recovery data (1-minute recovery) - use sample query to avoid unit conversion issues
        async let hrRecoveryData = fetchDailyHeartRateRecovery(startDate: startDate, endDate: endDate)
        
        async let bloodOxygenData = fetchDailyAverage(
            for: .oxygenSaturation,
            startDate: startDate,
            endDate: endDate,
            anchorDate: anchorDate,
            interval: interval,
            useNativeUnit: true
        )
        
        // VO2 Max - fetch using sample query to avoid unit conversion issues with StatisticsCollectionQuery
        async let cardioFitnessData = fetchDailyVO2Max(startDate: startDate, endDate: endDate)
        
        let heartRate = await heartRateData
        let restingHeartRate = await restingHeartRateData
        let hrv = await hrvData
        let bloodOxygen = await bloodOxygenData
        let cardioFitness = await cardioFitnessData
        
        for (date, hrValue) in heartRate {
            allMetrics.heartRateDaily.append(DailyHealthMetric(date: date, value: hrValue))
        }
        
        for (date, rhrValue) in restingHeartRate {
            allMetrics.restingHeartRateDaily.append(DailyHealthMetric(date: date, value: rhrValue))
        }
        
        for (date, hrvValue) in hrv {
            allMetrics.hrvDaily.append(DailyHealthMetric(date: date, value: hrvValue))
        }
        
        let hrRecovery = await hrRecoveryData
        for (date, recoveryValue) in hrRecovery {
            allMetrics.heartRateRecoveryDaily.append(DailyHealthMetric(date: date, value: recoveryValue))
        }
        
        for (date, boValue) in bloodOxygen {
            allMetrics.bloodOxygenDaily.append(DailyHealthMetric(date: date, value: boValue))
        }
        
        for (date, cfValue) in cardioFitness {
            allMetrics.cardioFitnessDaily.append(DailyHealthMetric(date: date, value: cfValue))
        }
        
        print("✅ [Cache] All metrics fetched: \(allMetrics.stepsDaily.count) days")
        return allMetrics
    }
    
    /// Fetch daily statistics using HKStatisticsCollectionQuery (much more efficient)
    private func fetchDailyCollection(
        for identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        anchorDate: Date,
        interval: DateComponents,
        useNativeUnit: Bool,
        convertedUnit: HKUnit? = nil
    ) async -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }
        
        // Get the appropriate unit - native or converted (for distance only)
        let unit: HKUnit
        if useNativeUnit {
            // Use HealthKit's default unit (native storage unit)
            unit = HKUnit.defaultUnit(for: identifier)
        } else {
            // Use specified conversion unit (only for distance -> km)
            unit = convertedUnit ?? HKUnit.defaultUnit(for: identifier)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { query, results, error in
                var dailyData: [Date: Double] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching \(identifier.rawValue): \(error)")
                    }
                    continuation.resume(returning: dailyData)
                    return
                }
                
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let date = statistics.startDate
                        // Get value in the requested unit (native or converted)
                        // According to Apple HealthKit documentation: always use the quantity's native unit
                        // to avoid NSInvalidArgumentException from incompatible unit conversions.
                        // The sumQuantity() returns a quantity with its native unit, and converting to
                        // an incompatible unit (e.g., count/min to count) will crash.
                        let value: Double
                        if useNativeUnit {
                            // For native units, use the default unit for this identifier
                            // HKQuantity doesn't expose its unit, but the default unit should match the native unit
                            value = sum.doubleValue(for: unit)
                        } else {
                            // For converted units (currently only distance -> km)
                            // Only distance conversions are requested, which are safe (m to km)
                            // If conversion would fail, we'd catch it, but Swift can't catch NSExceptions
                            // So we only attempt conversion for known-safe cases (distance)
                            value = sum.doubleValue(for: unit)
                        }
                        dailyData[date] = value
                    }
                }
                
                continuation.resume(returning: dailyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch daily averages using HKStatisticsCollectionQuery
    private func fetchDailyAverage(
        for identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        anchorDate: Date,
        interval: DateComponents,
        useNativeUnit: Bool
    ) async -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }
        
        // Use HealthKit's default unit (native storage unit)
        let unit = HKUnit.defaultUnit(for: identifier)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage, // Use average instead of sum
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { query, results, error in
                var dailyData: [Date: Double] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching \(identifier.rawValue): \(error)")
                    }
                    continuation.resume(returning: dailyData)
                    return
                }
                
                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let avg = statistics.averageQuantity() {
                        let date = statistics.startDate
                        // Use the default unit for this identifier (HealthKit's native unit)
                        // HKQuantity doesn't expose its unit, so we use the expected default unit
                        let value = avg.doubleValue(for: unit)
                        
                        // Validate the result - if conversion fails, value will be invalid
                        if !value.isNaN && value >= 0 {
                            dailyData[date] = value
                        } else {
                            print("⚠️ [Daily Average] Invalid value for \(identifier.rawValue), skipping")
                        }
                    }
                }
                
                continuation.resume(returning: dailyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch daily VO2 Max data using sample query to avoid unit conversion issues
    private func fetchDailyVO2Max(startDate: Date, endDate: Date) async -> [Date: Double] {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return [:]
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current
        let defaultUnit = HKUnit.defaultUnit(for: .vo2Max)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                var dailyVO2Max: [Date: [Double]] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching VO2 Max: \(error)")
                    }
                    continuation.resume(returning: [:])
                    return
                }
                
                // Group samples by day
                var validSampleCount = 0
                samples?.forEach { sample in
                    if let quantitySample = sample as? HKQuantitySample {
                        let date = calendar.startOfDay(for: sample.startDate)
                        // Try using defaultUnit first, but if that fails try alternative approaches
                        // Since HKQuantity doesn't expose its native unit directly, we rely on
                        // HealthKit's unit conversion or try the default unit
                        var value = quantitySample.quantity.doubleValue(for: defaultUnit)
                        
                        // If the value is invalid (0 or NaN), it might be a unit conversion issue
                        // Try constructing alternative units programmatically
                        if value.isNaN || value <= 0 {
                            // Try constructing mL/kg·min programmatically
                            let altUnit1 = HKUnit.literUnit(with: .milli)
                                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
                                .unitDivided(by: HKUnit.minute())
                            let altValue1 = quantitySample.quantity.doubleValue(for: altUnit1)
                            if !altValue1.isNaN && altValue1 > 0 {
                                value = altValue1
                            }
                        }
                        
                        // Only add if we have a valid value
                        if !value.isNaN && value > 0 {
                            validSampleCount += 1
                            dailyVO2Max[date, default: []].append(value)
                        }
                    }
                }
                
                if validSampleCount > 0 {
                    print("   ✅ VO2 Max: \(validSampleCount) samples processed")
                } else {
                    print("   ⚠️ No VO2 Max samples found in date range")
                }
                
                // Calculate daily averages from grouped samples
                var dailyAverages: [Date: Double] = [:]
                for (date, values) in dailyVO2Max {
                    let average = values.reduce(0, +) / Double(values.count)
                    dailyAverages[date] = average
                }
                
                continuation.resume(returning: dailyAverages)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch daily Heart Rate Recovery data using sample query to avoid unit conversion issues
    private func fetchDailyHeartRateRecovery(startDate: Date, endDate: Date) async -> [Date: Double] {
        guard let hrRecoveryType = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else {
            return [:]
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current
        let defaultUnit = HKUnit.defaultUnit(for: .heartRateRecoveryOneMinute)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrRecoveryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                var dailyHRRecovery: [Date: [Double]] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching Heart Rate Recovery: \(error)")
                    }
                    continuation.resume(returning: [:])
                    return
                }
                
                // Group samples by day
                samples?.forEach { sample in
                    if let quantitySample = sample as? HKQuantitySample {
                        let date = calendar.startOfDay(for: sample.startDate)
                        // Try using defaultUnit first (count/min)
                        var value = quantitySample.quantity.doubleValue(for: defaultUnit)
                        
                        // If the value is invalid (0 or NaN), it might be a unit conversion issue
                        // Try alternative unit formats
                        if value.isNaN || value <= 0 {
                            // Try count/min unit constructed differently
                            let altUnit = HKUnit.count().unitDivided(by: .minute())
                            let altValue = quantitySample.quantity.doubleValue(for: altUnit)
                            if !altValue.isNaN && altValue > 0 {
                                value = altValue
                            }
                        }
                        
                        // Only add if we have a valid value
                        if !value.isNaN && value > 0 {
                            dailyHRRecovery[date, default: []].append(value)
                        }
                    }
                }
                
                // Calculate daily averages from grouped samples
                var dailyAverages: [Date: Double] = [:]
                for (date, values) in dailyHRRecovery {
                    let average = values.reduce(0, +) / Double(values.count)
                    dailyAverages[date] = average
                }
                
                continuation.resume(returning: dailyAverages)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch daily sleep data (requires sample query, not statistics)
    private func fetchDailySleep(startDate: Date, endDate: Date) async -> [Date: Double] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return [:]
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                var dailySleep: [Date: Double] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching sleep: \(error)")
                    }
                    continuation.resume(returning: dailySleep)
                    return
                }
                
                // Group sleep by day
                samples?.forEach { sample in
                    if let categorySample = sample as? HKCategorySample {
                        // Only count actual sleep (not in bed, etc.)
                        if categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                            let date = calendar.startOfDay(for: sample.startDate)
                            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // Convert to hours
                            dailySleep[date, default: 0] += duration
                        }
                    }
                }
                
                continuation.resume(returning: dailySleep)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch daily sleep "in bed" data for sleep efficiency calculation
    private func fetchDailySleepInBed(startDate: Date, endDate: Date) async -> [Date: Double] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return [:]
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                var dailyInBed: [Date: Double] = [:]
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching sleep in bed: \(error)")
                    }
                    continuation.resume(returning: dailyInBed)
                    return
                }
                
                // Group "in bed" time by day
                // Count all sleep-related periods: inBed, asleep, awake (during sleep session)
                samples?.forEach { sample in
                    if let categorySample = sample as? HKCategorySample {
                        // Count "in bed" time - this includes:
                        // - Explicitly marked as "inBed"
                        // - All sleep states (asleep time is part of in bed time)
                        // Note: We don't double-count since this is separate from sleep tracking
                        let value = categorySample.value
                        if value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                           value == HKCategoryValueSleepAnalysis.awake.rawValue {
                            let date = calendar.startOfDay(for: sample.startDate)
                            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // Convert to hours
                            dailyInBed[date, default: 0] += duration
                        }
                    }
                }
                
                continuation.resume(returning: dailyInBed)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch HR samples for a specific time period (e.g., during workout or recovery period)
    func fetchHeartRateSamples(startDate: Date, endDate: Date) async -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain != "com.apple.healthkit" || nsError.code != 11 {
                        print("   ⚠️ Error fetching HR samples: \(error)")
                    }
                    continuation.resume(returning: [])
                    return
                }
                
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: hrSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Calculate HR recovery rate for workouts using actual HR samples from HealthKit
    func calculateHRRecoveryRate(for workouts: [HKWorkout], restingHR: Double) async -> Double? {
        guard !workouts.isEmpty else { return nil }
        
        var allRecoveryRates: [Double] = []
        let hrUnit = HKUnit(from: "count/min")
        
        // Process workouts in parallel for better performance
        await withTaskGroup(of: Double?.self) { group in
            for workout in workouts {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    
                    // Define recovery window: first 2 minutes after workout ends
                    let recoveryStart = workout.endDate
                    let recoveryEnd = workout.endDate.addingTimeInterval(120) // 2 minutes
                    
                    // Fetch HR samples during workout and recovery period in parallel
                    async let workoutHRSamples = self.fetchHeartRateSamples(
                        startDate: workout.startDate,
                        endDate: workout.endDate
                    )
                    async let recoveryHRSamples = self.fetchHeartRateSamples(
                        startDate: recoveryStart,
                        endDate: recoveryEnd
                    )
                    
                    let workoutHRs = await workoutHRSamples
                    let recoveryHRs = await recoveryHRSamples
                    
                    // Calculate max HR during workout
                    guard !workoutHRs.isEmpty else { return nil }
                    
                    // Safely convert HR values - HKQuantity doesn't expose its unit
                    // so we try conversion and validate the result
                    let maxWorkoutHR = workoutHRs.compactMap { sample -> Double? in
                        let value = sample.quantity.doubleValue(for: hrUnit)
                        // Validate the result - if conversion fails or is invalid, skip it
                        if !value.isNaN && value > 0 {
                            return value
                        } else {
                            return nil
                        }
                    }.max() ?? 0
                    
                    guard maxWorkoutHR > restingHR else { return nil }
                    
                    // Calculate recovery rate
                    if !recoveryHRs.isEmpty {
                        // Use actual recovery HR samples - safely convert units
                        // HKQuantity doesn't expose its unit, so we try conversion and validate
                        let recoveryHRValues = recoveryHRs.compactMap { sample -> Double? in
                            let value = sample.quantity.doubleValue(for: hrUnit)
                            // Validate the result - if conversion fails or is invalid, skip it
                            if !value.isNaN && value > 0 {
                                return value
                            } else {
                                return nil
                            }
                        }
                        
                        guard !recoveryHRValues.isEmpty else { return nil }
                        let avgRecoveryHR = recoveryHRValues.reduce(0, +) / Double(recoveryHRValues.count)
                        let hrDrop = maxWorkoutHR - avgRecoveryHR
                        let recoveryTimeMinutes = 2.0
                        if hrDrop > 0 && recoveryTimeMinutes > 0 {
                            return hrDrop / recoveryTimeMinutes
                        }
                    } else {
                        // Fallback: estimate based on max workout HR vs resting HR
                        let hrDrop = maxWorkoutHR - restingHR
                        if hrDrop > 0 {
                            return hrDrop / 2.0 // Estimate 2-minute recovery
                        }
                    }
                    
                    return nil
                }
            }
            
            // Collect all recovery rates
            for await recoveryRate in group {
                if let rate = recoveryRate {
                    allRecoveryRates.append(rate)
                }
            }
        }
        
        // Return average recovery rate across all workouts
        guard !allRecoveryRates.isEmpty else { return nil }
        return allRecoveryRates.reduce(0, +) / Double(allRecoveryRates.count)
    }
}

struct AllDailyMetrics {
    var workouts: [HKWorkout] = []
    var stepsDaily: [DailyHealthMetric] = []
    var activeCaloriesDaily: [DailyHealthMetric] = []
    var basalCaloriesDaily: [DailyHealthMetric] = [] // Basal (resting) calories from HealthKit
    var totalCaloriesDaily: [DailyHealthMetric] = []
    var distanceDaily: [DailyHealthMetric] = []
    var heartRateDaily: [DailyHealthMetric] = []
    var restingHeartRateDaily: [DailyHealthMetric] = []
    var hrvDaily: [DailyHealthMetric] = [] // Heart Rate Variability (SDNN) in milliseconds
    var heartRateRecoveryDaily: [DailyHealthMetric] = []
    var sleepDaily: [DailyHealthMetric] = []
    var sleepInBedDaily: [DailyHealthMetric] = []
    var bloodOxygenDaily: [DailyHealthMetric] = []
    var cardioFitnessDaily: [DailyHealthMetric] = []
    
    // Nutrition data (if user tracks food intake - CRITICAL for accurate body composition)
    var dietaryCaloriesDaily: [DailyHealthMetric] = [] // Calories consumed (most important!)
    var dietaryProteinDaily: [DailyHealthMetric] = [] // Protein intake (crucial for muscle gain)
}

