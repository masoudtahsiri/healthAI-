import Foundation
import HealthKit

/**
 * BODY COMPOSITION CALCULATOR - COMPREHENSIVE GUIDE
 * 
 * This calculator estimates body composition changes based on actual health data.
 * Body composition refers to the proportion of fat, muscle, bone, and water in your body.
 * 
 * KEY METRICS EXPLAINED:
 * 
 * 1. FAT LOSS (kg)
 *    - What it is: Reduction in body fat mass
 *    - How calculated: Based on calorie deficit (7700 calories = 1kg fat)
 *    - Modified by: Sleep quality and workout consistency
 *    - Formula: (Calorie Deficit / 7700) × Sleep Modifier × Consistency Modifier
 * 
 * 2. MUSCLE GAIN (kg)
 *    - What it is: Increase in lean muscle tissue
 *    - How calculated: Requires calorie surplus AND strength training
 *    - Only occurs when: In calorie surplus + doing strength workouts
 *    - Modified by: Sleep, age, gender, consistency, recovery, workout balance
 *    - Formula: (Surplus × 0.35 / 2500) × All Modifiers
 *    - Efficiency: Only 35% of surplus calories convert to muscle
 * 
 * 3. MUSCLE LOSS (kg)
 *    - What it is: Reduction in muscle tissue during calorie deficit
 *    - How calculated: Percentage of fat loss that is muscle
 *    - With strength training: 10% of fat loss is muscle
 *    - Without strength training: 25% of fat loss is muscle
 *    - Formula: Fat Loss × Loss Ratio × (1 / Recovery Modifier)
 *    - Note: Better recovery = less muscle loss
 * 
 * 4. NET WEIGHT CHANGE (kg)
 *    - What it is: Overall weight change (positive = gain, negative = loss)
 *    - How calculated: Fat loss - Muscle loss + Muscle gain
 *    - Example: If you lose 2kg fat, lose 0.2kg muscle, gain 0kg muscle = -2.2kg
 * 
 * 5. LEAN BODY MASS CHANGE (kg)
 *    - What it is: Total change in muscle/lean tissue (gain - loss)
 *    - How calculated: Muscle Gain - Muscle Loss
 *    - Positive = gained muscle, Negative = lost muscle
 * 
 * 6. BODY FAT MASS CHANGE (kg)
 *    - What it is: Total change in fat tissue
 *    - How calculated: -Fat Loss (negative because loss is positive value)
 *    - Negative = lost fat, Positive = gained fat
 * 
 * 7. BODY FAT PERCENTAGE CHANGE (%)
 *    - What it is: Change in percentage of body weight that is fat
 *    - How calculated: (New Fat Mass / New Weight) - Current Body Fat %
 *    - Requires: Current body fat percentage measurement
 *    - Example: If you go from 20% to 18% = -2% change
 * 
 * 8. BMR INCREASE (calories/day)
 *    - What it is: Increase in Basal Metabolic Rate from muscle gain
 *    - Why: Muscle tissue burns more calories at rest than fat
 *    - How calculated: Muscle Gain × 13 calories/kg/day
 *    - Example: Gaining 1kg muscle = +13 calories/day BMR
 * 
 * 9. NEW MAINTENANCE CALORIES (calories/day)
 *    - What it is: Updated maintenance calories after muscle changes
 *    - How calculated: Original Maintenance + BMR Increase
 *    - Impact: More muscle = higher maintenance calories
 * 
 * MODIFIERS EXPLAINED:
 * 
 * - Sleep Modifier: Quality sleep (7-9 hours) = optimal fat loss/muscle gain
 * - Age Modifier: Younger age = better muscle gain efficiency
 * - Gender Modifier: Males typically have 15% better muscle gain (hormonal differences)
 * - Consistency Modifier: Regular workouts (4-6/week) = better results
 * - Recovery Modifier: Optimal rest days (1-2 days) = better muscle retention/gain
 * - Workout Balance Modifier: More strength training (60%+) = better muscle gain
 * 
 * FITNESS METRICS:
 * 
 * - Strength Gain (%): Estimated increase in strength from workouts + muscle gain
 * - Endurance Gain (%): Estimated cardiovascular improvement from cardio
 * - VO2 Max Improvement: Estimated improvement in maximum oxygen consumption
 * - Recovery Quality Score: 0-100 score based on sleep, recovery, and workout frequency
 * - Energy Level Improvement: 0-100 score based on sleep, activity, and recovery
 * - Overall Composition Score: 0-100 score aligned with your fitness goals
 */

/// Calculates body composition changes based on actual health data
struct BodyCompositionPrediction {
    // MARK: - Primary Metrics (always calculated)
    
    /// Fat loss in kilograms
    /// Calculated from calorie deficit (7700 cal = 1kg fat)
    let fatLoss: Double
    
    /// Muscle gain in kilograms
    /// Only occurs in calorie surplus with strength training
    let muscleGain: Double
    
    /// Muscle loss in kilograms
    /// Occurs during calorie deficit (10-25% of fat loss depending on training)
    let muscleLoss: Double
    
    /// Net weight change in kilograms
    /// Formula: Fat Loss - Muscle Loss + Muscle Gain
    let netWeightChange: Double
    
    // MARK: - Metabolic Impact
    
    /// Increase in Basal Metabolic Rate (calories/day)
    /// Formula: Muscle Gain × 13 cal/kg/day
    /// More muscle = higher metabolism at rest
    let bmrIncrease: Double
    
    /// Updated daily maintenance calories after body composition changes
    /// Formula: Original Maintenance + BMR Increase
    let newMaintenanceCalories: Double
    
    // MARK: - Fitness Improvements
    
    /// Estimated strength increase as a percentage
    /// Based on strength training volume and muscle gain (1kg muscle ≈ 5% strength)
    let strengthGain: Double
    
    /// Recovery quality score (0-100)
    /// Based on sleep hours, recovery days between workouts, and workout frequency
    let recoveryQualityScore: Double
    
    /// Risk of overtraining based on recovery metrics
    let overtrainingRisk: OvertrainingRisk
    
    /// Energy level improvement score (0-100)
    /// Based on sleep quality, activity level, and recovery
    let energyLevelImprovement: Double
    
    /// Overall composition score (0-100) aligned with fitness goals
    /// Higher score = better progress toward your specific goals
    let overallCompositionScore: Double
    
    // MARK: - Body Composition Changes
    
    /// Change in lean body mass (muscle + organs + water) in kilograms
    /// Formula: Muscle Gain - Muscle Loss
    /// Positive = gained lean mass, Negative = lost lean mass
    let leanBodyMassChange: Double
    
    /// Change in body fat mass in kilograms
    /// Formula: -Fat Loss
    /// Negative = lost fat, Positive = gained fat
    let bodyFatMassChange: Double
    
    // MARK: - Optional Metrics (only calculated if data available)
    
    /// Change in body fat percentage (%)
    /// Only calculated if current body fat percentage is provided
    /// Formula: (New Fat Mass / New Weight) - Current Body Fat %
    let bodyFatPercentageChange: Double?
    
    /// Current lean body mass in kilograms (if measured)
    let currentLeanBodyMass: Double?
    
    /// VO2 Max improvement in mL/kg/min (if cardio fitness data available)
    /// Estimated improvement: ~0.3 mL/kg/min per hour of cardio per week
    let vo2MaxImprovement: Double?
    
    /// Endurance gain as a percentage
    /// Estimated from cardio workout volume (~2% per hour of cardio per week)
    let enduranceGain: Double
    
    /// Waist circumference change in centimeters (if measured)
    /// Indicates abdominal fat change - better health indicator than overall weight
    /// Negative = waist reduced (good), Positive = waist increased
    let waistCircumferenceChange: Double?
    
    // Supporting data
    let calorieDeficit: Double
    let calorieSurplus: Double
    let maintenanceCalories: Double
    let avgCaloriesBurned: Double
    let dayCount: Int
    
    // Modifiers used (for transparency)
    let sleepModifier: Double
    let ageModifier: Double
    let genderModifier: Double
    let consistencyModifier: Double
    let recoveryModifier: Double
    let workoutBalanceModifier: Double
    
    // Workout analysis
    let strengthWorkoutCount: Int
    let cardioWorkoutCount: Int
    let totalWorkoutMinutes: Double
    let avgSleepHours: Double
}

enum OvertrainingRisk {
    case low
    case moderate
    case high
}

/// Comprehensive body composition calculator using real health data
class BodyCompositionCalculator {
    
    // MARK: - Scientific Constants
    
    /// Calories required to lose 1kg of fat
    /// Based on energy density of body fat tissue
    private static let caloriesPerKgFat = 7700.0
    
    /// Calories required to gain 1kg of muscle
    /// Accounts for protein synthesis, glycogen storage, and water
    private static let caloriesPerKgMuscle = 2500.0
    
    /// Efficiency of converting calorie surplus to muscle tissue
    /// Only 35% of surplus calories can become muscle (rest is fat/stored energy)
    private static let muscleEfficiencyFactor = 0.35
    
    /// Percentage of fat loss that is muscle when doing strength training
    /// Strength training preserves muscle during calorie deficit
    private static let muscleLossWithStrength = 0.10
    
    /// Percentage of fat loss that is muscle without strength training
    /// Without strength training, body loses more muscle during deficit
    private static let muscleLossWithoutStrength = 0.25
    
    /// Calories burned per kg of muscle per day (for BMR calculation)
    /// Muscle tissue is metabolically active and burns calories at rest
    private static let caloriesPerKgMuscleForBMR = 13.0
    
    /// Calculate comprehensive body composition prediction
    /// Prioritizes actual HealthKit measurements when available, uses calculations as fallback
    static func calculate(
        profile: UserProfile,
        filteredData: FilteredHealthData,
        workouts: [HKWorkout],
        currentBodyFatPercentage: Double? = nil,
        currentLeanBodyMass: Double? = nil,
        avgVO2Max: Double? = nil,
        // Actual HealthKit measurements for date range (use when available)
        startBodyFat: Double? = nil,
        endBodyFat: Double? = nil,
        startLeanMass: Double? = nil,
        endLeanMass: Double? = nil,
        startWeight: Double? = nil,
        endWeight: Double? = nil,
        startWaistCircumference: Double? = nil, // Waist circumference at start (cm)
        endWaistCircumference: Double? = nil    // Waist circumference at end (cm)
    ) -> BodyCompositionPrediction {
        
        // ===== STEP 1: Calculate BMR & Maintenance Calories =====
        // PRIORITY: Use HealthKit basalEnergyBurned first, fallback to calculation
        // BMR (Basal Metabolic Rate): Calories burned at complete rest
        let bmr: Double
        if let healthKitBMR = filteredData.avgBasalCalories, healthKitBMR > 0 {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured BMR (most accurate)
            bmr = healthKitBMR
            print("✅ [Body Composition] Using HealthKit BMR: \(Int(bmr)) cal/day")
        } else {
            // 📊 FALLBACK: Calculate BMR using Mifflin-St Jeor equation (when HealthKit data not available)
            bmr = calculateBMR(profile: profile)
            print("📊 [Body Composition] Using calculated BMR (no HealthKit basal energy data): \(Int(bmr)) cal/day")
        }
        // Maintenance = BMR × Activity Factor
        // 1.55 = moderately active (accounts for daily non-exercise movement + 3-5 workouts/week)
        // This estimates total daily energy expenditure including all activities
        let maintenanceCalories = bmr * 1.55
        
        // ===== STEP 2: Calculate Calorie Deficit/Surplus =====
        // CRITICAL: If we have dietary calories consumed, we can calculate ACTUAL deficit/surplus
        // Otherwise, we estimate based on calorie burn vs maintenance
        let avgCaloriesBurned = filteredData.avgTotalCalories // Total = Basal + Active
        let avgCaloriesConsumed = filteredData.avgDietaryCalories // From HealthKit (if user tracks nutrition)
        
        let dailyDifference: Double
        let totalDifference: Double
        
        if let consumed = avgCaloriesConsumed, consumed > 0 {
            // ACTUAL deficit/surplus calculation (much more accurate!)
            // Deficit = Calories Consumed - Calories Burned (negative = deficit, positive = surplus)
            dailyDifference = consumed - avgCaloriesBurned
            totalDifference = dailyDifference * Double(filteredData.dayCount)
            print("✅ [Body Composition] Using ACTUAL calorie tracking: Consumed \(Int(consumed)) cal/day, Burned \(Int(avgCaloriesBurned)) cal/day")
        } else {
            // ESTIMATED deficit/surplus (fallback when nutrition not tracked)
            // Estimate by comparing burn vs maintenance (less accurate)
            dailyDifference = avgCaloriesBurned - maintenanceCalories
            totalDifference = dailyDifference * Double(filteredData.dayCount)
            print("📊 [Body Composition] Using ESTIMATED deficit (no nutrition data): Burn \(Int(avgCaloriesBurned)) vs Maintenance \(Int(maintenanceCalories)) cal/day")
        }
        
        // For deficit: negative difference = actual deficit (consuming less than burning)
        // For surplus: positive difference = actual surplus (consuming more than burning)
        let totalSurplus = dailyDifference > 0 ? totalDifference : 0
        let effectiveDeficit = dailyDifference < 0 ? abs(totalDifference) : 0
        
        // ===== STEP 3: Analyze Workouts =====
        let strengthWorkouts = workouts.filter { isStrengthTraining($0) }
        let cardioWorkouts = workouts.filter { isCardio($0) }
        let strengthCount = strengthWorkouts.count
        let cardioCount = cardioWorkouts.count
        let totalWorkoutMinutes = filteredData.totalWorkoutMinutes
        
        // Calculate workout balance
        let totalWorkouts = Double(strengthCount + cardioCount)
        let strengthRatio = totalWorkouts > 0 ? Double(strengthCount) / totalWorkouts : 0
        
        // ===== STEP 4: Calculate Modifiers =====
        let avgSleepHours = filteredData.avgSleepHours
        let age = profile.age ?? 30
        
        let sleepModifier = calculateSleepModifier(avgSleepHours)
        let ageModifier = calculateAgeModifier(age)
        let genderModifier = profile.gender == .male ? 1.0 : 0.85
        let consistencyModifier = calculateConsistencyModifier(totalWorkouts: totalWorkouts, dayCount: filteredData.dayCount)
        let recoveryModifier = calculateRecoveryModifier(
            workouts: workouts,
            dayCount: filteredData.dayCount,
            avgRestingHeartRate: filteredData.avgRestingHeartRate,
            avgHRV: filteredData.avgHRV
        )
        let workoutBalanceModifier = calculateWorkoutBalanceModifier(strengthRatio: strengthRatio)
        
        // ===== STEP 5: Calculate Fat Loss =====
        // PRIORITY: Use HealthKit data first (bodyFatPercentage + weight), fallback to calculation
        let fatLoss: Double
        if let startBF = startBodyFat, let endBF = endBodyFat, let startW = startWeight, let endW = endWeight {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured fat loss (most accurate)
            // Calculated from: start fat mass - end fat mass
            // Requires: Smart scale with body fat % or manual entry
            let startFatMass = startW * (startBF / 100.0)
            let endFatMass = endW * (endBF / 100.0)
            fatLoss = startFatMass - endFatMass // Positive = fat loss
            print("✅ [Body Composition] Using HealthKit fat loss (smart scale data): \(startFatMass) → \(endFatMass) = \(fatLoss) kg")
        } else {
            // 📊 FALLBACK: Calculate from calorie deficit (when HealthKit data not available)
            // Fat Loss Formula: Calorie Deficit ÷ 7700 calories/kg
            // Modified by sleep quality and workout consistency
            let baseFatLoss = effectiveDeficit > 0 ? effectiveDeficit / caloriesPerKgFat : 0
            fatLoss = baseFatLoss * sleepModifier * consistencyModifier
            print("📊 [Body Composition] Using calculated fat loss from activity data (no body composition measurements available): \(fatLoss) kg")
        }
        
        // ===== STEP 6: Calculate Muscle Loss (during calorie deficit) =====
        // PRIORITY: Use HealthKit leanBodyMass first, fallback to calculation
        let muscleLoss: Double
        if let startLBM = startLeanMass, let endLBM = endLeanMass, endLBM < startLBM {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured muscle loss (most accurate)
            // Requires: Specialized device (DEXA, smart scale with BIA) or manual entry
            muscleLoss = startLBM - endLBM
            print("✅ [Body Composition] Using HealthKit lean body mass (specialized device data): \(startLBM) → \(endLBM) = \(muscleLoss) kg")
        } else if effectiveDeficit > 0 {
            // 📊 FALLBACK: Estimate muscle loss during calorie deficit (when HealthKit data not available)
            // During weight loss, some muscle is inevitably lost
            // Strength training reduces muscle loss from 25% to 10% of fat loss
            // Better recovery = less muscle loss (inverse of recovery modifier)
            let lossRatio = strengthCount > 0 ? muscleLossWithStrength : muscleLossWithoutStrength
            let baseMuscleLoss = fatLoss * lossRatio
            // Better recovery = less muscle loss
            muscleLoss = baseMuscleLoss * (1.0 / recoveryModifier)
            print("📊 [Body Composition] Using calculated muscle loss: \(muscleLoss) kg")
        } else {
            muscleLoss = 0 // No deficit = no muscle loss
        }
        
        // ===== STEP 7: Calculate Muscle Gain (requires surplus + strength training) =====
        // PRIORITY: Use HealthKit leanBodyMass first, fallback to calculation
        let muscleGain: Double
        if let startLBM = startLeanMass, let endLBM = endLeanMass, endLBM > startLBM {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured muscle gain (most accurate)
            // Requires: Specialized device (DEXA, smart scale with BIA) or manual entry
            muscleGain = endLBM - startLBM
            print("✅ [Body Composition] Using HealthKit lean body mass (specialized device data): \(startLBM) → \(endLBM) = \(muscleGain) kg")
        } else if totalSurplus > 0 && strengthCount > 0 {
            // 📊 FALLBACK: Estimate muscle gain from calorie surplus + strength training (when HealthKit data not available)
            // Muscle gain ONLY happens when:
            // 1. In calorie surplus (eating more than maintenance)
            // 2. Doing strength training workouts
            // Only 35% of surplus converts to muscle (rest becomes fat)
            // Base calculation: (Surplus × 35% efficiency) ÷ 2500 cal/kg muscle
            let baseMuscleGain = (totalSurplus * muscleEfficiencyFactor) / caloriesPerKgMuscle
            
            // BONUS: If we have protein data, adjust for protein intake
            // Adequate protein (1.6-2.2g/kg body weight) significantly improves muscle gain
            let proteinModifier: Double
            if let avgProtein = filteredData.avgDietaryProtein, avgProtein > 0 {
                let bodyWeightInKg = profile.weight
                let targetProteinMin = bodyWeightInKg * 1.6 // Minimum for muscle gain
                let targetProteinMax = bodyWeightInKg * 2.2 // Optimal for muscle gain
                
                if avgProtein >= targetProteinMin && avgProtein <= targetProteinMax {
                    proteinModifier = 1.15 // 15% boost for adequate protein
                } else if avgProtein >= targetProteinMax {
                    proteinModifier = 1.10 // Slight boost for high protein (diminishing returns)
                } else if avgProtein >= targetProteinMin * 0.8 {
                    proteinModifier = 1.0 // Okay protein
                } else {
                    proteinModifier = 0.85 // Low protein reduces muscle gain efficiency
                }
                print("📊 [Body Composition] Protein intake: \(String(format: "%.1f", avgProtein))g/day (target: \(String(format: "%.1f", targetProteinMin))-\(String(format: "%.1f", targetProteinMax))g) - modifier: \(proteinModifier)")
            } else {
                proteinModifier = 1.0 // No protein data - use base efficiency
            }
            
            // Apply all modifiers for realistic estimation
            muscleGain = baseMuscleGain *
                sleepModifier *      // Better sleep = better muscle synthesis
                ageModifier *        // Younger = better muscle building
                genderModifier *     // Males typically build muscle faster
                consistencyModifier * // Regular workouts = better adaptation
                recoveryModifier *    // Better recovery = better gains
                workoutBalanceModifier * // More strength vs cardio = better gains
                proteinModifier      // Adequate protein = better muscle gain
            print("📊 [Body Composition] Using calculated muscle gain: \(muscleGain) kg")
        } else {
            muscleGain = 0 // Need surplus + strength training to gain muscle
        }
        
        // ===== STEP 8: Calculate Net Weight Change =====
        // PRIORITY: Use HealthKit weight data first, fallback to calculation
        let netWeightChange: Double
        if let startW = startWeight, let endW = endWeight {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured weight change (most accurate)
            netWeightChange = endW - startW // Positive = gain, Negative = loss
            print("✅ [Body Composition] Using HealthKit net weight change: \(startW) → \(endW) = \(netWeightChange) kg")
        } else {
            // 📊 FALLBACK: Calculate from composition changes (when HealthKit weight data not available)
            // Overall weight change accounts for fat loss, muscle loss, and muscle gain
            // Positive = weight gain, Negative = weight loss
            netWeightChange = fatLoss - muscleLoss + muscleGain
            print("📊 [Body Composition] Using calculated net weight change: \(netWeightChange) kg")
        }
        
        // ===== STEP 9: Calculate Metabolic Impact =====
        // Muscle tissue increases metabolism: 1kg muscle burns ~13 cal/day at rest
        // This means gaining muscle increases your maintenance calories
        let bmrIncrease = muscleGain * caloriesPerKgMuscleForBMR
        let newMaintenanceCalories = maintenanceCalories + bmrIncrease
        
        // ===== STEP 10: Calculate Strength Improvements =====
        let strengthGain = calculateStrengthGain(
            strengthWorkouts: strengthWorkouts,
            muscleGain: muscleGain,
            dayCount: filteredData.dayCount
        )
        
        // ===== STEP 11: Calculate Endurance Improvements =====
        let (enduranceGain, vo2MaxImprovement) = calculateEnduranceGain(
            cardioWorkouts: cardioWorkouts,
            vo2Max: avgVO2Max,
            dayCount: filteredData.dayCount
        )
        
        // ===== STEP 12: Calculate Recovery & Energy Metrics =====
        let workoutFrequency = totalWorkouts / Double(filteredData.dayCount) * 7
        let (recoveryScore, overtrainingRisk) = calculateRecoveryScore(
            avgSleepHours: avgSleepHours,
            recoveryModifier: recoveryModifier,
            workoutFrequency: workoutFrequency,
            avgRestingHeartRate: filteredData.avgRestingHeartRate,
            avgHRV: filteredData.avgHRV
        )
        
        let energyImprovement = calculateEnergyImprovement(
            sleepHours: avgSleepHours,
            activityLevel: filteredData.avgActiveCalories,
            recoveryScore: recoveryScore
        )
        
        // ===== STEP 13: Calculate Body Composition Metrics =====
        // NOTE: Most users won't have HealthKit body composition data (requires smart scales/specialized devices)
        // Calculations from activity data are the PRIMARY method for most users
        
        // Lean Body Mass Change: PRIORITY - Use HealthKit data first, fallback to calculation
        let leanBodyMassChange: Double
        if let startLBM = startLeanMass, let endLBM = endLeanMass {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured change (most accurate)
            leanBodyMassChange = endLBM - startLBM
            print("✅ [Body Composition] Using HealthKit lean body mass (specialized device): \(startLBM) → \(endLBM) = \(leanBodyMassChange) kg")
        } else {
            // 📊 FALLBACK: Calculate from muscle gain/loss estimates (when HealthKit data not available)
            leanBodyMassChange = muscleGain - muscleLoss
            print("📊 [Body Composition] Using calculated lean body mass change (no measurements available): \(leanBodyMassChange) kg")
        }
        
        // Body Fat Mass Change: PRIORITY - Use HealthKit data first, fallback to calculation
        let bodyFatMassChange: Double
        if let startBF = startBodyFat, let endBF = endBodyFat, let startW = startWeight, let endW = endWeight {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured fat mass change (most accurate)
            let startFatMass = startW * (startBF / 100.0)
            let endFatMass = endW * (endBF / 100.0)
            bodyFatMassChange = endFatMass - startFatMass
            print("✅ [Body Composition] Using HealthKit fat mass change: \(startFatMass) → \(endFatMass) = \(bodyFatMassChange) kg")
        } else {
            // 📊 FALLBACK: Calculate estimate (negative of fat loss) (when HealthKit data not available)
            bodyFatMassChange = -fatLoss
            print("📊 [Body Composition] Using calculated fat mass change: \(bodyFatMassChange) kg")
        }
        
        // Body Fat Percentage Change: PRIORITY - Use HealthKit data first, fallback to calculation
        let bodyFatPercentageChange: Double?
        if let startBF = startBodyFat, let endBF = endBodyFat {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured change (most accurate)
            let bfChange = endBF - startBF
            bodyFatPercentageChange = bfChange
            print("✅ [Body Composition] Using HealthKit body fat % change: \(startBF)% → \(endBF)% = \(bfChange)%")
        } else if let currentBF = currentBodyFatPercentage {
            // 📊 FALLBACK: Calculate estimate based on current BF% (when HealthKit data not available)
            bodyFatPercentageChange = calculateBodyFatPercentageChange(
                currentWeight: profile.weight,
                netWeightChange: netWeightChange,
                fatLoss: fatLoss,
                currentBodyFatPercentage: currentBF
            )
            print("📊 [Body Composition] Using calculated body fat % change based on current measurement")
        } else {
            bodyFatPercentageChange = nil
            print("⚠️ [Body Composition] No body fat % data available")
        }
        
        // Waist Circumference Change: PRIORITY - Use HealthKit data first, fallback to nil
        let waistCircumferenceChange: Double?
        if let startWaist = startWaistCircumference, let endWaist = endWaistCircumference {
            // ✅ HEALTHKIT DATA AVAILABLE: Use actual measured change (most accurate)
            let change = endWaist - startWaist // Positive = increased, Negative = decreased
            waistCircumferenceChange = change
            print("✅ [Body Composition] Using HealthKit waist circumference change: \(String(format: "%.1f", startWaist))cm → \(String(format: "%.1f", endWaist))cm = \(String(format: "%.1f", change))cm")
        } else {
            // 📊 FALLBACK: No waist data available (when HealthKit data not available)
            waistCircumferenceChange = nil
            print("📊 [Body Composition] No waist circumference data available")
        }
        
        // ===== STEP 14: Calculate Overall Composition Score =====
        let compositionScore = calculateCompositionScore(
            bodyFatChange: bodyFatPercentageChange,
            muscleGain: muscleGain,
            fatLoss: fatLoss,
            muscleLoss: muscleLoss,
            fitnessGoal: profile.fitnessGoals.first ?? .loseWeight
        )
        
        return BodyCompositionPrediction(
            fatLoss: fatLoss,
            muscleGain: muscleGain,
            muscleLoss: muscleLoss,
            netWeightChange: netWeightChange,
            bmrIncrease: bmrIncrease,
            newMaintenanceCalories: newMaintenanceCalories,
            strengthGain: strengthGain,
            recoveryQualityScore: recoveryScore,
            overtrainingRisk: overtrainingRisk,
            energyLevelImprovement: energyImprovement,
            overallCompositionScore: compositionScore,
            leanBodyMassChange: leanBodyMassChange,
            bodyFatMassChange: bodyFatMassChange,
            bodyFatPercentageChange: bodyFatPercentageChange,
            currentLeanBodyMass: currentLeanBodyMass,
            vo2MaxImprovement: vo2MaxImprovement,
            enduranceGain: enduranceGain,
            waistCircumferenceChange: waistCircumferenceChange,
            calorieDeficit: effectiveDeficit, // Total estimated deficit over period
            calorieSurplus: totalSurplus, // Total estimated surplus over period
            maintenanceCalories: maintenanceCalories,
            avgCaloriesBurned: avgCaloriesBurned,
            dayCount: filteredData.dayCount,
            sleepModifier: sleepModifier,
            ageModifier: ageModifier,
            genderModifier: genderModifier,
            consistencyModifier: consistencyModifier,
            recoveryModifier: recoveryModifier,
            workoutBalanceModifier: workoutBalanceModifier,
            strengthWorkoutCount: strengthCount,
            cardioWorkoutCount: cardioCount,
            totalWorkoutMinutes: totalWorkoutMinutes,
            avgSleepHours: avgSleepHours
        )
    }
    
    // MARK: - Helper Calculations
    
    /// Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor Equation
    /// BMR = calories burned at complete rest (just to maintain basic body functions)
    /// 
    /// Formula:
    /// - Male: (10 × weight_kg) + (6.25 × height_cm) - (5 × age) + 5
    /// - Female: (10 × weight_kg) + (6.25 × height_cm) - (5 × age) - 161
    /// 
    /// This is the most accurate BMR estimation equation for general population
    private static func calculateBMR(profile: UserProfile) -> Double {
        let age = profile.age ?? 30
        if profile.gender == .male {
            return (10 * profile.weight) + (6.25 * profile.height) - (5 * Double(age)) + 5
        } else {
            return (10 * profile.weight) + (6.25 * profile.height) - (5 * Double(age)) - 161
        }
    }
    
    private static func isStrengthTraining(_ workout: HKWorkout) -> Bool {
        switch workout.workoutActivityType {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining:
            return true
        default:
            return false
        }
    }
    
    private static func isCardio(_ workout: HKWorkout) -> Bool {
        switch workout.workoutActivityType {
        case .running, .walking, .cycling, .swimming,
             .rowing, .elliptical, .hiking, .crossTraining,
             .crossCountrySkiing, .mixedCardio:
            return true
        default:
            return false
        }
    }
    
    /// Sleep Quality Modifier
    /// Sleep is critical for:
    /// - Muscle protein synthesis (muscle repair/growth)
    /// - Hormone production (growth hormone, testosterone)
    /// - Fat metabolism (cortisol regulation)
    /// 
    /// Optimal: 7-9 hours provides best results
    /// Less than 6 hours significantly reduces efficiency
    private static func calculateSleepModifier(_ sleepHours: Double) -> Double {
        switch sleepHours {
        case 0..<6: return 0.75   // Poor sleep reduces efficiency by 25%
        case 6..<7: return 0.90   // Below optimal reduces by 10%
        case 7..<8: return 1.0    // Optimal range
        case 8..<9: return 1.05   // Slightly above optimal (5% bonus)
        case 9...: return 1.0      // Too much sleep (no additional benefit)
        default: return 1.0
        }
    }
    
    /// Age Modifier for Muscle Gain Efficiency
    /// Muscle building efficiency decreases with age due to:
    /// - Reduced growth hormone and testosterone production
    /// - Slower protein synthesis rates
    /// - Decreased recovery capacity
    /// 
    /// Peak efficiency: Under 30 years old
    /// Gradual decline: ~5% per decade after 30
    private static func calculateAgeModifier(_ age: Int) -> Double {
        switch age {
        case 0..<30: return 1.0   // Peak muscle-building efficiency
        case 30..<40: return 0.95 // 5% reduction
        case 40..<50: return 0.85 // 15% reduction
        case 50..<60: return 0.75 // 25% reduction
        default: return 0.65      // 35% reduction (60+)
        }
    }
    
    private static func calculateConsistencyModifier(totalWorkouts: Double, dayCount: Int) -> Double {
        let workoutFrequency = totalWorkouts / Double(dayCount) * 7 // workouts per week
        switch workoutFrequency {
        case 0..<2: return 0.70   // Low consistency
        case 2..<4: return 0.90   // Good consistency
        case 4..<6: return 1.0    // Excellent consistency
        case 6...: return 0.95    // Slightly lower (may be overtraining)
        default: return 0.80
        }
    }
    
    /// Calculate recovery modifier based on workout spacing and HealthKit recovery metrics
    /// Uses actual HealthKit data (resting heart rate, HRV) when available for more accurate assessment
    private static func calculateRecoveryModifier(
        workouts: [HKWorkout],
        dayCount: Int,
        avgRestingHeartRate: Double?,
        avgHRV: Double?
    ) -> Double {
        var baseModifier = 1.0
        
        // Base calculation from workout spacing
        if workouts.count > 1 {
            let sortedWorkouts = workouts.sorted { $0.startDate < $1.startDate }
            var totalRestDays = 0
            var restPeriodCount = 0
            
            for i in 1..<sortedWorkouts.count {
                let daysBetween = Calendar.current.dateComponents(
                    [.day],
                    from: sortedWorkouts[i-1].endDate,
                    to: sortedWorkouts[i].startDate
                ).day ?? 0
                
                if daysBetween > 0 {
                    totalRestDays += daysBetween
                    restPeriodCount += 1
                }
            }
            
            let avgRestDays = restPeriodCount > 0 ? Double(totalRestDays) / Double(restPeriodCount) : 0
            
            // Optimal is 1-2 days rest
            if avgRestDays >= 1.0 && avgRestDays <= 2.0 {
                baseModifier = 1.0   // Optimal recovery
            } else if avgRestDays < 1.0 {
                baseModifier = 0.75  // Insufficient rest (overtraining risk)
            } else if avgRestDays <= 3.0 {
                baseModifier = 0.95 // Slightly too much rest
            } else {
                baseModifier = 0.85  // Too much rest (losing momentum)
            }
        }
        
        // HEALTHKIT ENHANCEMENT: Adjust based on actual resting heart rate if available
        // Lower resting heart rate = better recovery/fitness = better body composition outcomes
        if let rhr = avgRestingHeartRate, rhr > 0 {
            // Normal resting heart rate range: 60-100 bpm
            // Athletes/fit individuals: 40-60 bpm
            // Higher than baseline = stress/overtraining = reduced recovery
            let rhrModifier: Double
            if rhr < 50 {
                rhrModifier = 1.05  // Excellent recovery (very fit)
            } else if rhr < 60 {
                rhrModifier = 1.02  // Good recovery (fit)
            } else if rhr < 70 {
                rhrModifier = 1.0   // Normal recovery
            } else if rhr < 80 {
                rhrModifier = 0.95  // Slightly elevated (may indicate stress)
            } else {
                rhrModifier = 0.85  // Elevated (likely stress/overtraining)
            }
            baseModifier = baseModifier * rhrModifier
            print("📊 [Body Composition] Resting HR: \(Int(rhr)) bpm - modifier: \(rhrModifier)")
        }
        
        // HEALTHKIT ENHANCEMENT: Adjust based on HRV (Heart Rate Variability) if available
        // Higher HRV = better recovery/stress resilience = better body composition outcomes
        // Typical HRV (SDNN): 20-50ms for general population, 50-100ms+ for athletes
        if let hrv = avgHRV, hrv > 0 {
            let hrvModifier: Double
            if hrv >= 60 {
                hrvModifier = 1.05  // Excellent recovery (high variability = good)
            } else if hrv >= 40 {
                hrvModifier = 1.02  // Good recovery
            } else if hrv >= 25 {
                hrvModifier = 1.0   // Normal recovery
            } else if hrv >= 15 {
                hrvModifier = 0.95  // Lower variability (may indicate stress/fatigue)
            } else {
                hrvModifier = 0.85  // Very low variability (stress/overtraining)
            }
            baseModifier = baseModifier * hrvModifier
            print("📊 [Body Composition] HRV: \(String(format: "%.1f", hrv))ms - modifier: \(hrvModifier)")
        }
        
        return min(1.10, max(0.70, baseModifier)) // Clamp to reasonable range
    }
    
    private static func calculateWorkoutBalanceModifier(strengthRatio: Double) -> Double {
        if strengthRatio >= 0.60 {
            return 1.0   // Optimal for muscle
        } else if strengthRatio >= 0.40 {
            return 0.90
        } else if strengthRatio >= 0.20 {
            return 0.75
        } else {
            return 0.60 // Mostly cardio, minimal muscle gain
        }
    }
    
    private static func calculateStrengthGain(
        strengthWorkouts: [HKWorkout],
        muscleGain: Double,
        dayCount: Int
    ) -> Double {
        let totalStrengthMinutes = strengthWorkouts.reduce(0) { $0 + $1.duration / 60 }
        let weeklyMinutes = dayCount > 0 ? totalStrengthMinutes / Double(dayCount) * 7 : 0
        
        // 0.1-0.3% strength gain per 60 minutes of training per week
        let workoutBasedGain = (weeklyMinutes / 60.0) * 0.2 // 0.2% per hour
        
        // Muscle gain also contributes: 1kg muscle ≈ 5% strength increase
        let muscleBasedGain = muscleGain * 5.0
        
        return workoutBasedGain + muscleBasedGain
    }
    
    private static func calculateEnduranceGain(
        cardioWorkouts: [HKWorkout],
        vo2Max: Double?,
        dayCount: Int
    ) -> (enduranceGain: Double, vo2MaxImprovement: Double?) {
        let totalCardioMinutes = cardioWorkouts.reduce(0) { $0 + $1.duration / 60 }
        let weeklyCardioMinutes = dayCount > 0 ? totalCardioMinutes / Double(dayCount) * 7 : 0
        
        // 1-3% endurance gain per hour of cardio per week
        let enduranceGain = (weeklyCardioMinutes / 60.0) * 2.0 // 2% per hour
        
        // VO2 Max improvement (if available)
        var vo2MaxImprovement: Double? = nil
        if vo2Max != nil {
            // VO2 Max can improve ~0.5-1.0 mL/kg/min per month with consistent training
            let monthsOfData = Double(dayCount) / 30.0
            vo2MaxImprovement = (weeklyCardioMinutes / 60.0) * 0.3 * monthsOfData
        }
        
        return (enduranceGain, vo2MaxImprovement)
    }
    
    /// Calculate recovery quality score using HealthKit data when available
    /// Uses actual measured recovery metrics (resting HR, HRV) for more accurate assessment
    private static func calculateRecoveryScore(
        avgSleepHours: Double,
        recoveryModifier: Double,
        workoutFrequency: Double,
        avgRestingHeartRate: Double?,
        avgHRV: Double?
    ) -> (score: Double, risk: OvertrainingRisk) {
        var score = 0.0
        
        // Sleep component (30 points - reduced since we now have HRV/RHR data)
        let sleepScore = min(30, (avgSleepHours / 8.0) * 30)
        score += sleepScore
        
        // Recovery modifier component (30 points)
        let recoveryScore = recoveryModifier * 30
        score += recoveryScore
        
        // Workout frequency balance (20 points)
        let frequencyScore: Double
        if workoutFrequency >= 3 && workoutFrequency <= 5 {
            frequencyScore = 20 // Optimal
        } else if workoutFrequency < 3 {
            frequencyScore = 15 // Too little
        } else {
            frequencyScore = 10 // May be too much
        }
        score += frequencyScore
        
        // HEALTHKIT ENHANCEMENT: Add points based on resting heart rate (10 points)
        if let rhr = avgRestingHeartRate, rhr > 0 {
            let rhrScore: Double
            if rhr < 50 {
                rhrScore = 10  // Excellent (very fit)
            } else if rhr < 60 {
                rhrScore = 8   // Good (fit)
            } else if rhr < 70 {
                rhrScore = 6   // Normal
            } else if rhr < 80 {
                rhrScore = 4   // Slightly elevated
            } else {
                rhrScore = 2   // Elevated (stress)
            }
            score += rhrScore
            print("📊 [Body Composition] Resting HR score: \(rhrScore) pts (RHR: \(Int(rhr)) bpm)")
        }
        
        // HEALTHKIT ENHANCEMENT: Add points based on HRV (10 points)
        if let hrv = avgHRV, hrv > 0 {
            let hrvScore: Double
            if hrv >= 60 {
                hrvScore = 10  // Excellent recovery
            } else if hrv >= 40 {
                hrvScore = 8   // Good recovery
            } else if hrv >= 25 {
                hrvScore = 6   // Normal
            } else if hrv >= 15 {
                hrvScore = 4   // Lower (stress/fatigue)
            } else {
                hrvScore = 2   // Very low (overtraining)
            }
            score += hrvScore
            print("📊 [Body Composition] HRV score: \(hrvScore) pts (HRV: \(String(format: "%.1f", hrv))ms)")
        }
        
        // Determine risk based on total score
        let risk: OvertrainingRisk
        if score >= 85 {
            risk = .low
        } else if score >= 70 {
            risk = .moderate
        } else {
            risk = .high
        }
        
        return (min(100, score), risk)
    }
    
    private static func calculateEnergyImprovement(
        sleepHours: Double,
        activityLevel: Double,
        recoveryScore: Double
    ) -> Double {
        var score = 50.0 // Baseline
        
        // Sleep impact (30 points)
        if sleepHours >= 7 && sleepHours <= 9 {
            score += 30
        } else if sleepHours >= 6 && sleepHours < 7 {
            score += 15
        } else {
            score -= 10
        }
        
        // Activity impact (10 points) - moderate activity improves energy
        if activityLevel >= 300 && activityLevel <= 600 {
            score += 10
        } else if activityLevel > 600 {
            score += 5 // May be fatiguing
        }
        
        // Recovery impact (10 points)
        score += (recoveryScore / 100) * 10
        
        return min(100, max(0, score))
    }
    
    /// Calculate Body Fat Percentage Change
    /// 
    /// Body Fat Percentage = (Fat Mass / Total Weight) × 100
    /// 
    /// Example Calculation:
    /// Starting: 80kg weight, 20% body fat = 16kg fat mass, 64kg lean mass
    /// After: Lost 2kg fat, lost 0.2kg muscle, new weight = 77.8kg
    ///   New fat mass = 16kg - 2kg = 14kg
    ///   New weight = 80kg - 2.2kg = 77.8kg
    ///   New BF% = (14 / 77.8) × 100 = 18.0%
    ///   Change = 18.0% - 20.0% = -2.0%
    /// 
    /// Returns nil if current body fat percentage is not provided
    private static func calculateBodyFatPercentageChange(
        currentWeight: Double,
        netWeightChange: Double,
        fatLoss: Double,
        currentBodyFatPercentage: Double?
    ) -> Double? {
        guard let currentBF = currentBodyFatPercentage else {
            return nil // Can't calculate without starting BF%
        }
        
        // Calculate current fat mass in kg
        let currentFatMass = currentWeight * (currentBF / 100)
        
        // Calculate new weight after changes
        let newWeight = currentWeight - netWeightChange
        guard newWeight > 0 else { return nil } // Safety check
        
        // Calculate new fat mass
        let newFatMass = currentFatMass - fatLoss
        guard newFatMass >= 0 else { return nil } // Safety check
        
        // Calculate new body fat percentage
        let newBodyFatPercent = (newFatMass / newWeight) * 100
        
        // Calculate change (negative = reduced BF%, positive = increased BF%)
        let bodyFatPercentChange = newBodyFatPercent - currentBF
        
        return bodyFatPercentChange
    }
    
    private static func calculateCompositionScore(
        bodyFatChange: Double?,
        muscleGain: Double,
        fatLoss: Double,
        muscleLoss: Double,
        fitnessGoal: FitnessGoal
    ) -> Double {
        var score = 50.0
        
        // Based on goal alignment
        switch fitnessGoal {
        case .loseWeight, .getToned:
            score += (fatLoss * 10) // More fat loss = better
            score -= (muscleLoss * 5) // Muscle loss = bad
            
        case .gainMuscle, .buildStrength, .athleticPerformance:
            score += (muscleGain * 15) // Muscle gain = good
            if fatLoss > 0 {
                score += (fatLoss * 3) // Some fat loss is good
            }
            
        case .improveFitness, .improveEndurance, .cardiovascularHealth:
            score += (fatLoss * 7)
            score += (muscleGain * 8)
            
        case .maintain:
            // Small changes are best
            let totalChange = abs(fatLoss) + abs(muscleGain)
            score += (2.0 - totalChange) * 10
            
        case .increaseFlexibility, .reduceStress, .betterSleep, .generalHealth, .injuryRecovery, .boostEnergy, .mentalWellness:
            // These goals don't focus on body composition changes
            score += (fatLoss * 3) // Some fat loss is always good
            score += (muscleGain * 3) // Some muscle gain is always good
        }
        
        // Body fat % improvement (if available)
        if let bfChange = bodyFatChange, bfChange < 0 {
            score += abs(bfChange) * 5 // Fat % reduction is good
        }
        
        return min(100, max(0, score))
    }
}

// MARK: - Tooltip Explanations

/// Tooltip explanations for all body composition metrics
struct BodyCompositionTooltips {
    
    /// Get tooltip text for a metric by its title
    static func tooltip(for metricTitle: String) -> String {
        switch metricTitle.lowercased() {
        // Primary Metrics
        case "fat loss":
            return "Fat Loss measures the estimated reduction in body fat mass based on your calorie deficit. It's calculated from your calorie deficit divided by 7,700 calories per kilogram of fat. The result is modified by sleep quality (optimal sleep of 7-9 hours improves fat loss) and workout consistency (4-6 workouts per week is optimal). Higher values indicate effective fat loss progress."
        case "muscle gain":
            return "Muscle Gain measures the estimated increase in lean muscle tissue. This only occurs when you're in a calorie surplus AND doing strength training workouts - both conditions must be met. Only 35% of your calorie surplus converts to muscle tissue, with the rest potentially becoming fat. Higher values indicate successful muscle building when combined with proper nutrition and strength training."
        case "muscle loss":
            return "Muscle Loss measures the estimated reduction in muscle tissue during weight loss periods. When losing weight, some muscle loss is inevitable. With strength training, only about 10% of fat loss comes from muscle. Without strength training, that number increases to 25%. Better recovery (adequate rest and sleep) helps minimize muscle loss during fat loss periods."
        case "net weight change":
            return "Net Weight Change measures your overall body weight change calculated as Fat Loss minus Muscle Loss plus Muscle Gain. Negative values indicate weight loss, while positive values indicate weight gain. This metric shows the total scale weight change, which is the combined result of fat loss, muscle loss, and muscle gain."
        case "lean body mass change":
            return "Lean Body Mass Change measures the change in non-fat tissue (muscle, organs, and water) calculated as Muscle Gain minus Muscle Loss. Positive values indicate you've gained lean tissue, while negative values indicate you've lost lean tissue. This metric is important for understanding body composition changes beyond just scale weight."
        case "body fat mass change":
            return "Body Fat Mass Change measures the change in fat tissue mass, calculated as the negative of fat loss. Negative values indicate you've lost fat (which is positive for health), while positive values indicate you've gained fat. This metric helps track fat-specific changes separate from overall weight changes."
        case "body fat % change":
            return "Body Fat Percentage Change measures the change in your body fat percentage, calculated as the difference between your new body fat percentage and your current body fat percentage. It's computed using your new fat mass divided by your new total weight. Negative values indicate a reduction in body fat percentage (good for health), while positive values indicate an increase. This metric requires a current body fat percentage measurement to calculate."
        case "waist circumference change":
            return "Waist Circumference Change measures the change in your waist circumference in centimeters, which is a better health indicator than overall weight for tracking abdominal fat changes. It's calculated from measurements in the Apple Health app when available. Negative values indicate a reduction in waist size (good for health), while positive values indicate an increase. This metric helps track changes in abdominal fat specifically."
        case "current lean body mass":
            return "Current Lean Body Mass measures your current lean body mass in kilograms, which includes muscle, organs, and water but excludes fat. This value comes from measurements in the Apple Health app when available from specialized devices like smart scales with bioelectrical impedance analysis or DEXA scans. Higher values indicate more muscle and lean tissue, which is beneficial for metabolism and overall health."
            
        // Metabolic Impact
        case "calorie base":
            return "Calorie Base measures your daily maintenance calories needed to maintain your current weight. It's calculated as your Basal Metabolic Rate (BMR) multiplied by 1.55 (accounting for moderately active lifestyle). This represents the calories needed to maintain your current weight with your activity level. Eating above this creates a surplus, while eating below creates a deficit."
        case "new calorie base":
            return "New Calorie Base measures your updated maintenance calories after accounting for muscle changes. Muscle tissue burns approximately 13 calories per kilogram per day at rest, so gaining muscle increases your maintenance calories. Higher values indicate you can eat more while maintaining your weight due to increased muscle mass and metabolism."
        case "calorie burn":
            return "Calorie Burn measures your total calorie deficit over the period. It's calculated by subtracting your maintenance calories from your average daily calories burned, then multiplying by the number of days. This total deficit is used to estimate fat loss, with 7,700 calories equaling approximately 1 kilogram of fat."
        case "calorie gain":
            return "Calorie Gain measures your total calorie surplus over the period, calculated when you're eating above your maintenance calories. Positive surplus values combined with strength training create the opportunity for muscle gain. Higher values with proper strength training indicate better potential for muscle building, though only 35% of surplus converts to muscle."
        case "bmr increase":
            return "BMR Increase measures the increase in your Basal Metabolic Rate from muscle gain. It's calculated as Muscle Gain (in kilograms) multiplied by 13 calories per kilogram per day. This represents how many more calories your body burns at rest due to increased muscle mass. Higher values indicate a higher metabolism and the ability to eat more while maintaining weight."
            
        // Fitness Improvements
        case "strength gain":
            return "Strength Gain measures your estimated strength increase from both training and muscle gain. It's calculated based on your weekly strength training minutes (0.2% per hour of training) plus muscle gain contributions (approximately 5% per kilogram of muscle gained). Higher values indicate better strength progress from your training program."
        case "endurance gain":
            return "Endurance Gain measures your estimated cardiovascular improvement from cardio workouts. It's calculated as approximately 2% improvement per hour of cardio training per week. Higher values indicate better cardiovascular fitness development and improved aerobic capacity from your cardio exercise."
        case "vo₂ max improvement", "vo2 max improvement":
            return "VO₂ Max Improvement measures your estimated improvement in maximum oxygen consumption in milliliters per kilogram per minute. It's calculated as approximately 0.3 mL/kg/min per hour of cardio per week. Higher values indicate better cardiovascular fitness. This metric is only shown if VO₂ Max data is available from the Apple Health app."
        case "energy level":
            return "Energy Level measures your energy improvement score from 0 to 100 based on sleep quality, activity level, and recovery. Optimal sleep of 7-9 hours adds 30 points, moderate activity of 300-600 calories adds 10 points, and your recovery score contributes additional points. Higher values indicate better overall energy and vitality."
            
        // Recovery & Health
        case "recovery score":
            return "Recovery Score measures your recovery quality on a scale of 0 to 100. It uses Apple Health app data when available for more accurate assessment. Components include sleep hours (30 points), recovery days between workouts (30 points), workout frequency balance (20 points), resting heart rate from Apple Health (10 points), and heart rate variability (HRV) from Apple Health (10 points). Lower resting heart rate and higher HRV indicate better recovery. Higher scores (85+) indicate excellent recovery."
        case "overtraining risk":
            return "Overtraining Risk measures your risk of overtraining based on recovery score using Apple Health app data. Scores of 85+ indicate Low risk, scores of 70-84 indicate Moderate risk, and scores below 70 indicate High risk. The assessment uses actual resting heart rate and HRV measurements when available from the Apple Health app for more accurate risk evaluation."
            
        // Activity Summary
        case "strength workouts":
            return "Strength Workouts counts the total number of traditional and functional strength training workouts in the period. These workouts are critical for muscle gain when combined with a calorie surplus. Higher counts indicate more consistent strength training."
        case "cardio workouts":
            return "Cardio Workouts counts the total number of cardiovascular workouts (running, cycling, swimming, etc.) in the period. These workouts improve cardiovascular fitness and endurance. Higher counts indicate more consistent cardiovascular training."
        case "workout minutes":
            return "Workout Minutes measures the total minutes of all workouts combined in the period. This includes both strength training and cardio workouts. Higher values indicate more total exercise time and training volume."
        case "avg sleep hours":
            return "Average Sleep Hours measures your average hours of sleep per night over the period. Optimal sleep of 7-9 hours is essential for best fat loss and muscle gain results, as it supports muscle recovery, hormone production, and metabolic function. Lower sleep hours can reduce the effectiveness of your training and nutrition efforts."
            
        default:
            return "Metric calculation explanation"
        }
    }
    
    /// Get detailed calculation breakdown for advanced users
    static func detailedCalculation(for metricTitle: String) -> String? {
        switch metricTitle.lowercased() {
        case "fat loss":
            return """
            Calculation Steps:
            1. Calculate daily deficit: Avg Calories Burned - Maintenance Calories
            2. Multiply by days in period
            3. Convert to fat: Total Deficit ÷ 7,700 cal/kg
            4. Apply modifiers:
               - Sleep modifier: 0.75-1.05 (7-9hrs = 1.0)
               - Consistency modifier: 0.70-1.0 (4-6 workouts/week = 1.0)
            
            Example: 500 cal/day deficit × 7 days = 3,500 cal ÷ 7,700 = 0.45kg fat loss
            """
        case "muscle gain":
            return """
            Calculation Steps:
            1. Requires: Calorie Surplus AND Strength Workouts (both needed)
            2. Calculate base gain: (Surplus × 0.35 efficiency) ÷ 2,500 cal/kg
            3. Apply modifiers:
               - Sleep (0.75-1.05), Age (0.65-1.0), Gender (0.85-1.0)
               - Consistency (0.70-1.0), Recovery (0.75-1.0), Workout Balance (0.60-1.0)
            
            Example: 500 cal/day surplus × 7 days × 0.35 = 1,225 cal ÷ 2,500 = 0.49kg × modifiers
            """
        case "muscle loss":
            return """
            Calculation Steps:
            1. Only occurs during calorie deficit
            2. Loss ratio: With strength training = 10% of fat loss, Without = 25%
            3. Apply recovery modifier: Better recovery = less loss (inverse)
            
            Example: 1kg fat loss × 10% = 0.1kg muscle loss (with training)
            Without training: 1kg fat loss × 25% = 0.25kg muscle loss
            """
        case "body fat % change":
            return """
            Calculation Steps:
            1. Current fat mass = Current Weight × (Body Fat % ÷ 100)
            2. New fat mass = Current Fat Mass - Fat Loss
            3. New weight = Current Weight - Net Weight Change
            4. New BF% = (New Fat Mass ÷ New Weight) × 100
            5. Change = New BF% - Current BF%
            
            Example: 80kg @ 20% = 16kg fat. Lose 2kg fat → 14kg fat, 78kg weight = 17.9% BF (-2.1%)
            """
        default:
            return nil
        }
    }
}

