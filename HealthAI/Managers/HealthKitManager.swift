import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    // Health data types we'll read - COMPREHENSIVE
    private let typesToRead: Set<HKObjectType> = [
        // Body measurements
        // According to Apple HealthKit documentation:
        // https://developer.apple.com/documentation/healthkit
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,           // Weight
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!, // Body fat % (requires smart scale/manual entry)
        HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,     // Lean body mass (requires specialized device)
        HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,     // BMI (calculated from weight/height)
        HKObjectType.quantityType(forIdentifier: .height)!,            // Height
        HKObjectType.quantityType(forIdentifier: .waistCircumference)!, // Waist circumference (optional)
        
        // Activity
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
        HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
        HKObjectType.quantityType(forIdentifier: .cyclingCadence)!,
        HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount)!,
        
        // Heart & Circulatory
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .vo2Max)!,
        HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)!,
        
        // Vital Signs
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        
        // Sleep
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        
        // Nutrition
        // CRITICAL: Dietary energy consumed - this would make fat loss calculations MUCH more accurate
        // Currently we only know calories burned, not calories consumed (the other half of the equation)
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!, // Total calories consumed
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,         // Protein (crucial for muscle gain)
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,   // Carbs (energy)
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,        // Total fat
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)!,
        
        // Additional health metrics that could improve accuracy
        HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,        // Affects metabolism/recovery
        HKObjectType.quantityType(forIdentifier: .uvExposure)!,            // Affects recovery/health
        
        // Mindfulness
        HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        
        // Workouts
        HKObjectType.workoutType()
    ]
    
    var isAuthorized: Bool {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return true
    }
    
    // Request authorization
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    // Read user profile data from HealthKit
    // Note: HealthKit doesn't provide first/last name - users should enter this manually
    func readUserProfileData() async -> (firstName: String?, lastName: String?, dateOfBirth: Date?, height: Double?, weight: Double?, gender: Gender?) {
        return await withTaskGroup(of: (String, Any?).self, returning: (String?, String?, Date?, Double?, Double?, Gender?).self) { group in
            var results: [String: Any?] = [:]
            
            // First name and last name are not available from HealthKit
            // Users will enter this manually during onboarding
            results["firstName"] = nil
            results["lastName"] = nil
            
            // Read date of birth
            group.addTask {
                if let dob = try? self.healthStore.dateOfBirthComponents(),
                   let date = Calendar.current.date(from: dob) {
                    return ("dateOfBirth", date)
                }
                return ("dateOfBirth", nil)
            }
            
            // Read height (most recent)
            group.addTask {
                guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
                    return ("height", nil)
                }
                
                return await withCheckedContinuation { continuation in
                    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    let query = HKSampleQuery(
                        sampleType: heightType,
                        predicate: nil,
                        limit: 1,
                        sortDescriptors: [sortDescriptor]
                    ) { _, samples, error in
                        if let error = error {
                            print("Error reading height: \(error)")
                            continuation.resume(returning: ("height", nil))
                            return
                        }
                        
                        if let sample = samples?.first as? HKQuantitySample {
                            // Convert to centimeters
                            let heightInCm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                            continuation.resume(returning: ("height", heightInCm))
                        } else {
                            continuation.resume(returning: ("height", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            // Read current weight (most recent)
            group.addTask {
                guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                    return ("weight", nil)
                }
                
                return await withCheckedContinuation { continuation in
                    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    let query = HKSampleQuery(
                        sampleType: weightType,
                        predicate: nil,
                        limit: 1,
                        sortDescriptors: [sortDescriptor]
                    ) { _, samples, error in
                        if let error = error {
                            print("Error reading weight: \(error)")
                            continuation.resume(returning: ("weight", nil))
                            return
                        }
                        
                        if let sample = samples?.first as? HKQuantitySample {
                            // Convert to kilograms
                            let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                            continuation.resume(returning: ("weight", weightInKg))
                        } else {
                            continuation.resume(returning: ("weight", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            // Read gender/biological sex
            group.addTask {
                if let biologicalSex = try? self.healthStore.biologicalSex() {
                    let gender: Gender
                    switch biologicalSex.biologicalSex {
                    case .male:
                        gender = .male
                    case .female:
                        gender = .female
                    default:
                        gender = .other
                    }
                    return ("gender", gender)
                }
                return ("gender", nil)
            }
            
            for await (key, value) in group {
                results[key] = value
            }
            
            return (
                results["firstName"] as? String,
                results["lastName"] as? String,
                results["dateOfBirth"] as? Date,
                results["height"] as? Double,
                results["weight"] as? Double,
                results["gender"] as? Gender
            )
        }
    }
    
    // Read workouts
    func readWorkouts(limit: Int = 100) async -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("Error reading workouts: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read steps for a date range
    func readSteps(startDate: Date, endDate: Date) async -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate
            ) { _, result, error in
                if let error = error {
                    // HealthKit error code 11 means "no data available" - this is not an error
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        // No data available - return 0
                        continuation.resume(returning: 0)
                    } else {
                        // Actual error
                        print("Error reading steps: \(error)")
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                // Use the appropriate unit for steps
                // Steps are stored as counts
                if let sum = result?.sumQuantity() {
                    let value = sum.doubleValue(for: .count())
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read active calories for a date range
    func readActiveCalories(startDate: Date, endDate: Date) async -> Double {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate
            ) { _, result, error in
                if let error = error {
                    // HealthKit error code 11 means "no data available" - this is not an error
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        // No data available - return 0
                        continuation.resume(returning: 0)
                    } else {
                        // Actual error
                        print("Error reading calories: \(error)")
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                // Use the appropriate unit for active calories
                // Active calories are stored in kilocalories
                if let sum = result?.sumQuantity() {
                    let value = sum.doubleValue(for: .kilocalorie())
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read average heart rate for a date range
    func readAverageHeartRate(startDate: Date, endDate: Date) async -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate
            ) { _, result, error in
                if let error = error {
                    // HealthKit error code 11 means "no data available" - return nil
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        // No data available - return nil
                        continuation.resume(returning: nil)
                    } else {
                        // Actual error
                        print("Error reading heart rate: \(error)")
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                // Safely convert heart rate units
                // HKQuantity doesn't expose its unit, so we try conversion and validate
                var avg: Double? = nil
                if let avgQuantity = result?.averageQuantity() {
                    let targetUnit = HKUnit(from: "count/min")
                    let value = avgQuantity.doubleValue(for: targetUnit)
                    
                    // Validate the result - if conversion fails, value will be invalid
                    if !value.isNaN && value > 0 {
                        avg = value
                    } else {
                        print("⚠️ [Heart Rate] Invalid value after unit conversion, skipping")
                        avg = nil
                    }
                }
                continuation.resume(returning: avg)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read sleep data for a date range
    func readSleepHours(startDate: Date, endDate: Date) async -> TimeInterval {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    // HealthKit error code 11 means "no data available" - return 0
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        // No data available - return 0
                        continuation.resume(returning: 0)
                    } else {
                        // Actual error
                        print("Error reading sleep: \(error)")
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                var totalSleep: TimeInterval = 0
                samples?.forEach { sample in
                    if let categorySample = sample as? HKCategorySample {
                        // Only count actual sleep (not in bed, etc.)
                        if categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                            totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                        }
                    }
                }
                
                continuation.resume(returning: totalSleep)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read basal calories (total)
    func readBasalCalories(startDate: Date, endDate: Date) async -> Double {
        return await readSample(for: .basalEnergyBurned, startDate: startDate, endDate: endDate)
    }
    
    // Read distance in kilometers
    func readDistance(startDate: Date, endDate: Date) async -> Double {
        // readSample already returns kilometers because defaultUnit for distance is .meterUnit(with: .kilo)
        return await readSample(for: .distanceWalkingRunning, startDate: startDate, endDate: endDate)
    }
    
    // Read average blood oxygen
    func readAverageBloodOxygen(startDate: Date, endDate: Date) async -> Double? {
        return await readAverage(for: .oxygenSaturation, startDate: startDate, endDate: endDate)
    }
    
    // Read average cardio fitness (VO2 Max)
    func readAverageCardioFitness(startDate: Date, endDate: Date) async -> Double? {
        return await readAverage(for: .vo2Max, startDate: startDate, endDate: endDate)
    }
    
    // Read most recent body fat percentage (latest value, not average)
    func readMostRecentBodyFatPercentage() async -> Double? {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: bodyFatType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        continuation.resume(returning: nil)
                    } else {
                        print("Error reading body fat percentage: \(error)")
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Body fat % is stored as a percentage (0-100)
                    let bodyFatPercent = sample.quantity.doubleValue(for: .percent())
                    continuation.resume(returning: bodyFatPercent)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // Read most recent lean body mass (latest value)
    func readMostRecentLeanBodyMass() async -> Double? {
        guard let leanBodyMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: leanBodyMassType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        continuation.resume(returning: nil)
                    } else {
                        print("Error reading lean body mass: \(error)")
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Convert to kilograms
                    let leanBodyMass = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    continuation.resume(returning: leanBodyMass)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Read body composition data at start and end of date range for actual measured changes
    func readBodyCompositionForDateRange(startDate: Date, endDate: Date) async -> (startBodyFat: Double?, endBodyFat: Double?, startLeanMass: Double?, endLeanMass: Double?, startWeight: Double?, endWeight: Double?, startWaist: Double?, endWaist: Double?) {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
              let leanMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let waistType = HKQuantityType.quantityType(forIdentifier: .waistCircumference) else {
            return (nil, nil, nil, nil, nil, nil, nil, nil)
        }
        
        // Read values at start of range (most recent before or at startDate)
        let startPredicate = HKQuery.predicateForSamples(withStart: nil, end: startDate, options: .strictEndDate)
        let startSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Read values at end of range (most recent before or at endDate)
        let endPredicate = HKQuery.predicateForSamples(withStart: nil, end: endDate, options: .strictEndDate)
        let endSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withTaskGroup(of: (String, Double?).self, returning: (Double?, Double?, Double?, Double?, Double?, Double?, Double?, Double?).self) { group in
            var results: [String: Double?] = [:]
            
            // Start values
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: bodyFatType,
                        predicate: startPredicate,
                        limit: 1,
                        sortDescriptors: [startSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: .percent())
                            continuation.resume(returning: ("startBodyFat", value))
                        } else {
                            continuation.resume(returning: ("startBodyFat", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: leanMassType,
                        predicate: startPredicate,
                        limit: 1,
                        sortDescriptors: [startSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                            continuation.resume(returning: ("startLeanMass", value))
                        } else {
                            continuation.resume(returning: ("startLeanMass", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: weightType,
                        predicate: startPredicate,
                        limit: 1,
                        sortDescriptors: [startSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                            continuation.resume(returning: ("startWeight", value))
                        } else {
                            continuation.resume(returning: ("startWeight", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: waistType,
                        predicate: startPredicate,
                        limit: 1,
                        sortDescriptors: [startSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                            continuation.resume(returning: ("startWaist", value))
                        } else {
                            continuation.resume(returning: ("startWaist", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            // End values
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: bodyFatType,
                        predicate: endPredicate,
                        limit: 1,
                        sortDescriptors: [endSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: .percent())
                            continuation.resume(returning: ("endBodyFat", value))
                        } else {
                            continuation.resume(returning: ("endBodyFat", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: leanMassType,
                        predicate: endPredicate,
                        limit: 1,
                        sortDescriptors: [endSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                            continuation.resume(returning: ("endLeanMass", value))
                        } else {
                            continuation.resume(returning: ("endLeanMass", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: weightType,
                        predicate: endPredicate,
                        limit: 1,
                        sortDescriptors: [endSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                            continuation.resume(returning: ("endWeight", value))
                        } else {
                            continuation.resume(returning: ("endWeight", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            group.addTask {
                await withCheckedContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: waistType,
                        predicate: endPredicate,
                        limit: 1,
                        sortDescriptors: [endSort]
                    ) { _, samples, error in
                        if let sample = samples?.first as? HKQuantitySample {
                            let value = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
                            continuation.resume(returning: ("endWaist", value))
                        } else {
                            continuation.resume(returning: ("endWaist", nil))
                        }
                    }
                    self.healthStore.execute(query)
                }
            }
            
            for await (key, value) in group {
                results[key] = value
            }
            
            return (
                results["startBodyFat"] as? Double,
                results["endBodyFat"] as? Double,
                results["startLeanMass"] as? Double,
                results["endLeanMass"] as? Double,
                results["startWeight"] as? Double,
                results["endWeight"] as? Double,
                results["startWaist"] as? Double,
                results["endWaist"] as? Double
            )
        }
    }
    
    // MARK: - Comprehensive Data Collection
    
    // Read all health data for a specific date range
    func readAllHealthData(startDate: Date, endDate: Date) async -> [String: Any] {
        print("📊 [HealthKit] Reading ALL available health data...")
        
        let metrics: [String: Any] = await [
            "steps": readSteps(startDate: startDate, endDate: endDate),
            "activeCalories": readActiveCalories(startDate: startDate, endDate: endDate),
            "sleepHours": readSleepHours(startDate: startDate, endDate: endDate),
            "heartRate": readAverageHeartRate(startDate: startDate, endDate: endDate) as Any,
            "workouts": readWorkouts(limit: 100),
            
            // Body measurements
            "weight": await readSample(for: .bodyMass, startDate: startDate, endDate: endDate),
            "bodyFat": await readSample(for: .bodyFatPercentage, startDate: startDate, endDate: endDate),
            "bmi": await readSample(for: .bodyMassIndex, startDate: startDate, endDate: endDate),
            "height": await readSample(for: .height, startDate: startDate, endDate: endDate),
            
            // Activity metrics
            "distanceWalking": await readSample(for: .distanceWalkingRunning, startDate: startDate, endDate: endDate),
            "distanceCycling": await readSample(for: .distanceCycling, startDate: startDate, endDate: endDate),
            "distanceSwimming": await readSample(for: .distanceSwimming, startDate: startDate, endDate: endDate),
            "exerciseTime": await readSample(for: .appleExerciseTime, startDate: startDate, endDate: endDate),
            "standTime": await readSample(for: .appleStandTime, startDate: startDate, endDate: endDate),
            "flightsClimbed": await readSample(for: .flightsClimbed, startDate: startDate, endDate: endDate),
            "basalEnergy": await readSample(for: .basalEnergyBurned, startDate: startDate, endDate: endDate),
            "cyclingCadence": await readAverage(for: .cyclingCadence, startDate: startDate, endDate: endDate) as Any,
            "swimmingStrokeCount": await readSample(for: .swimmingStrokeCount, startDate: startDate, endDate: endDate),
            
            // Heart metrics
            "restingHeartRate": await readAverage(for: .restingHeartRate, startDate: startDate, endDate: endDate) as Any,
            "walkingHeartRate": await readAverage(for: .walkingHeartRateAverage, startDate: startDate, endDate: endDate) as Any,
            "heartRateVariability": await readAverage(for: .heartRateVariabilitySDNN, startDate: startDate, endDate: endDate) as Any,
            "vo2Max": await readAverage(for: .vo2Max, startDate: startDate, endDate: endDate) as Any,
            
            // Vital signs
            "bloodPressure": await readBloodPressure(startDate: startDate, endDate: endDate),
            "respiratoryRate": await readAverage(for: .respiratoryRate, startDate: startDate, endDate: endDate) as Any,
            "oxygenSaturation": await readAverage(for: .oxygenSaturation, startDate: startDate, endDate: endDate) as Any,
            
            // Nutrition - CRITICAL for accurate body composition
            "dietaryEnergyConsumed": await readSample(for: .dietaryEnergyConsumed, startDate: startDate, endDate: endDate),
            "dietaryProtein": await readSample(for: .dietaryProtein, startDate: startDate, endDate: endDate),
            "dietaryCarbohydrates": await readSample(for: .dietaryCarbohydrates, startDate: startDate, endDate: endDate),
            "dietaryFatTotal": await readSample(for: .dietaryFatTotal, startDate: startDate, endDate: endDate),
            "dietaryWater": await readSample(for: .dietaryWater, startDate: startDate, endDate: endDate),
            "dietaryCaffeine": await readSample(for: .dietaryCaffeine, startDate: startDate, endDate: endDate),
            
            // Additional health metrics
            "bodyTemperature": await readAverage(for: .bodyTemperature, startDate: startDate, endDate: endDate) as Any,
            "uvExposure": await readSample(for: .uvExposure, startDate: startDate, endDate: endDate),
            
            // Mindfulness
            "mindfulMinutes": await readMindfulMinutes(startDate: startDate, endDate: endDate)
        ]
        
        // Log collected data
        for (key, value) in metrics {
            if let num = value as? Double, num > 0 {
                print("   ✅ \(key): \(num)")
            } else if let array = value as? Array<Any>, !array.isEmpty {
                print("   ✅ \(key): \(array.count) entries")
            } else if value is [String: Any] {
                print("   ✅ \(key): collected")
            }
        }
        
        return metrics
    }
    
    // MARK: - Generic Helper Methods
    
    private func readSample(for identifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate
            ) { _, result, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        continuation.resume(returning: 0)
                    } else {
                        print("Error reading \(identifier.rawValue): \(error)")
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                // Use the default unit for this quantity type
                if let sum = result?.sumQuantity() {
                    let defaultUnit = HKUnit.defaultUnit(for: identifier)
                    let value = sum.doubleValue(for: defaultUnit)
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func readAverage(for identifier: HKQuantityTypeIdentifier, startDate: Date, endDate: Date) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate
            ) { _, result, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        continuation.resume(returning: nil)
                    } else {
                        print("Error reading \(identifier.rawValue): \(error)")
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                // Try to get average value
                var avg: Double? = nil
                if let avgQuantity = result?.averageQuantity() {
                    let defaultUnit = HKUnit.defaultUnit(for: identifier)
                    // For VO2 Max, try default unit and fallback to alternatives if needed
                    if identifier == .vo2Max {
                        // Try default unit first
                        var vo2Value = avgQuantity.doubleValue(for: defaultUnit)
                        // If conversion gives invalid result, try alternative construction
                        if vo2Value.isNaN || vo2Value <= 0 {
                            // Construct mL/kg·min programmatically
                            let altUnit = HKUnit.literUnit(with: .milli)
                                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
                                .unitDivided(by: HKUnit.minute())
                            let altValue = avgQuantity.doubleValue(for: altUnit)
                            if !altValue.isNaN && altValue > 0 {
                                vo2Value = altValue
                            }
                        }
                        avg = (vo2Value.isNaN || vo2Value <= 0) ? nil : vo2Value
                    } else {
                        // For other metrics, use default unit
                        avg = avgQuantity.doubleValue(for: defaultUnit)
                    }
                }
                continuation.resume(returning: avg)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func readBloodPressure(startDate: Date, endDate: Date) async -> [String: Any] {
        return await withCheckedContinuation { continuation in
            let readings: [[String: Any]] = []
            
            // This would need to be implemented with correlation type queries
            // For now, return empty
            continuation.resume(returning: ["readings": readings, "count": readings.count])
        }
    }
    
    private func readMindfulMinutes(startDate: Date, endDate: Date) async -> Double {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.healthkit" && nsError.code == 11 {
                        continuation.resume(returning: 0)
                    } else {
                        print("Error reading mindful sessions: \(error)")
                        continuation.resume(returning: 0)
                    }
                    return
                }
                
                var totalMinutes: Double = 0
                samples?.forEach { sample in
                    totalMinutes += sample.endDate.timeIntervalSince(sample.startDate) / 60
                }
                
                continuation.resume(returning: totalMinutes)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - HKUnit Extension
extension HKUnit {
    static func defaultUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .bodyMass: return .gramUnit(with: .kilo)
        case .bodyFatPercentage: return .percent()
        case .bodyMassIndex: return HKUnit.count()
        case .height: return .meterUnit(with: .centi)
        case .leanBodyMass: return .gramUnit(with: .kilo)
        case .waistCircumference: return .meterUnit(with: .centi)
        case .stepCount, .swimmingStrokeCount, .flightsClimbed: return .count()
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming: return .meterUnit(with: .kilo)
        case .activeEnergyBurned, .basalEnergyBurned: return .kilocalorie()
        case .appleExerciseTime, .appleStandTime: return .minute()
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .respiratoryRate, .heartRateRecoveryOneMinute: return HKUnit(from: "count/min")
        case .heartRateVariabilitySDNN: return .secondUnit(with: .milli)
        case .oxygenSaturation: return .percent()
        case .dietaryEnergyConsumed: return .kilocalorie()
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal: return .gramUnit(with: .kilo)
        case .dietaryWater: return .literUnit(with: .milli)
        case .dietaryCaffeine: return .gramUnit(with: .milli)
        case .bodyTemperature: return .degreeCelsius()
        case .uvExposure: return .count() // Index value
        case .vo2Max: 
            // VO2 Max: milliliters per kilogram per minute (mL/(kg·min))
            // Construct the unit programmatically: mL / kg / min = mL/(kg·min)
            return HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
                .unitDivided(by: HKUnit.minute())
        case .cyclingCadence: return .count().unitDivided(by: .minute())
        default: return .count()
        }
    }
}

