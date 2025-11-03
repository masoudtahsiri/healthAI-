import Foundation
import HealthKit

/// Caches health data for fast retrieval and filtering
class HealthDataCache {
    
    // MARK: - Cached Data
    
    var workouts: [HKWorkout] = []
    var stepsDaily: [DailyHealthMetric] = [] // Each day's total steps
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
    
    // Nutrition data (if user tracks food intake)
    var dietaryCaloriesDaily: [DailyHealthMetric] = [] // Calories consumed per day
    var dietaryProteinDaily: [DailyHealthMetric] = [] // Protein per day (grams)
    
    var lastFetchedDate: Date?
    var isDataLoaded: Bool = false
    
    // MARK: - Filter Methods
    
    /// Filter cached data by date range and return aggregated totals
    func filterByDateRange(startDate: Date, endDate: Date) -> FilteredHealthData {
        let filteredWorkouts = workouts.filter { $0.startDate >= startDate && $0.endDate <= endDate }
        
        let filteredSteps = stepsDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalSteps = filteredSteps.reduce(0) { $0 + $1.value }
        let avgSteps = filteredSteps.isEmpty ? 0 : totalSteps / Double(filteredSteps.count)
        
        let filteredActiveCalories = activeCaloriesDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalActiveCalories = filteredActiveCalories.reduce(0) { $0 + $1.value }
        let avgActiveCalories = filteredActiveCalories.isEmpty ? 0 : totalActiveCalories / Double(filteredActiveCalories.count)
        
        let filteredTotalCalories = totalCaloriesDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalCalorieValue = filteredTotalCalories.reduce(0) { $0 + $1.value }
        let avgTotalCalories = filteredTotalCalories.isEmpty ? 0 : totalCalorieValue / Double(filteredTotalCalories.count)
        
        let filteredBasalCalories = basalCaloriesDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalBasalCalories = filteredBasalCalories.reduce(0) { $0 + $1.value }
        let avgBasalCalories = filteredBasalCalories.isEmpty ? nil : totalBasalCalories / Double(filteredBasalCalories.count)
        
        let filteredDistance = distanceDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalDistance = filteredDistance.reduce(0) { $0 + $1.value }
        let avgDistance = filteredDistance.isEmpty ? 0 : totalDistance / Double(filteredDistance.count)
        
        let filteredSleep = sleepDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalSleep = filteredSleep.reduce(0) { $0 + $1.value }
        let avgSleep = filteredSleep.isEmpty ? 0 : totalSleep / Double(filteredSleep.count)
        
        let filteredSleepInBed = sleepInBedDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalSleepInBed = filteredSleepInBed.reduce(0) { $0 + $1.value }
        let avgSleepInBed = filteredSleepInBed.isEmpty ? 0 : totalSleepInBed / Double(filteredSleepInBed.count)
        
        let filteredHeartRate = heartRateDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgHeartRate = filteredHeartRate.isEmpty ? nil : filteredHeartRate.reduce(0) { $0 + $1.value } / Double(filteredHeartRate.count)
        
        let filteredRestingHeartRate = restingHeartRateDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgRestingHeartRate = filteredRestingHeartRate.isEmpty ? nil : filteredRestingHeartRate.reduce(0) { $0 + $1.value } / Double(filteredRestingHeartRate.count)
        
        let filteredHRV = hrvDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgHRV = filteredHRV.isEmpty ? nil : filteredHRV.reduce(0) { $0 + $1.value } / Double(filteredHRV.count)
        
        let filteredHeartRateRecovery = heartRateRecoveryDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgHeartRateRecovery = filteredHeartRateRecovery.isEmpty ? nil : filteredHeartRateRecovery.reduce(0) { $0 + $1.value } / Double(filteredHeartRateRecovery.count)
        
        let filteredBloodOxygen = bloodOxygenDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgBloodOxygen = filteredBloodOxygen.isEmpty ? nil : filteredBloodOxygen.reduce(0) { $0 + $1.value } / Double(filteredBloodOxygen.count)
        
        let filteredCardioFitness = cardioFitnessDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let avgCardioFitness = filteredCardioFitness.isEmpty ? nil : filteredCardioFitness.reduce(0) { $0 + $1.value } / Double(filteredCardioFitness.count)
        
        // Nutrition data (CRITICAL for accurate body composition)
        let filteredDietaryCalories = dietaryCaloriesDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalDietaryCalories = filteredDietaryCalories.reduce(0) { $0 + $1.value }
        let avgDietaryCalories = filteredDietaryCalories.isEmpty ? nil : totalDietaryCalories / Double(filteredDietaryCalories.count)
        
        let filteredDietaryProtein = dietaryProteinDaily.filter { $0.date >= startDate && $0.date <= endDate }
        let totalDietaryProtein = filteredDietaryProtein.reduce(0) { $0 + $1.value }
        let avgDietaryProtein = filteredDietaryProtein.isEmpty ? nil : totalDietaryProtein / Double(filteredDietaryProtein.count)
        
        let totalWorkoutMinutes = filteredWorkouts.reduce(0) { $0 + $1.duration } / 60
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 7)
        
        return FilteredHealthData(
            workouts: filteredWorkouts,
            totalSteps: totalSteps,
            avgSteps: avgSteps,
            activeCalories: totalActiveCalories,
            totalCalories: totalCalorieValue,
            avgActiveCalories: avgActiveCalories,
            avgTotalCalories: avgTotalCalories,
            avgBasalCalories: avgBasalCalories,
            distanceKM: totalDistance,
            avgDistance: avgDistance,
            avgHeartRate: avgHeartRate,
            avgRestingHeartRate: avgRestingHeartRate,
            avgHRV: avgHRV,
            avgHeartRateRecovery: avgHeartRateRecovery,
            workoutCount: filteredWorkouts.count,
            totalWorkoutMinutes: totalWorkoutMinutes,
            totalSleepHours: totalSleep,
            avgSleepHours: avgSleep,
            avgSleepInBedHours: avgSleepInBed,
            avgBloodOxygen: avgBloodOxygen,
            avgCardioFitness: avgCardioFitness,
            dayCount: dayCount,
            avgDietaryCalories: avgDietaryCalories,
            avgDietaryProtein: avgDietaryProtein,
            totalDietaryCalories: totalDietaryCalories
        )
    }
    
    // MARK: - Merge Methods
    
    /// Merge newly fetched daily metrics into the cache without duplicates, keeping latest values on conflict
    func merge(allMetrics: AllDailyMetrics, fetchedAt: Date) {
        // Workouts: merge by startDate/endDate identifier
        var existingWorkoutKeys: Set<String> = Set(workouts.map { workoutKey($0) })
        for w in allMetrics.workouts {
            let key = workoutKey(w)
            if !existingWorkoutKeys.contains(key) {
                workouts.append(w)
                existingWorkoutKeys.insert(key)
            }
        }
        
        stepsDaily = mergeDaily(stepsDaily, with: allMetrics.stepsDaily)
        activeCaloriesDaily = mergeDaily(activeCaloriesDaily, with: allMetrics.activeCaloriesDaily)
        basalCaloriesDaily = mergeDaily(basalCaloriesDaily, with: allMetrics.basalCaloriesDaily)
        totalCaloriesDaily = mergeDaily(totalCaloriesDaily, with: allMetrics.totalCaloriesDaily)
        distanceDaily = mergeDaily(distanceDaily, with: allMetrics.distanceDaily)
        heartRateDaily = mergeDaily(heartRateDaily, with: allMetrics.heartRateDaily)
        restingHeartRateDaily = mergeDaily(restingHeartRateDaily, with: allMetrics.restingHeartRateDaily)
        hrvDaily = mergeDaily(hrvDaily, with: allMetrics.hrvDaily)
        heartRateRecoveryDaily = mergeDaily(heartRateRecoveryDaily, with: allMetrics.heartRateRecoveryDaily)
        sleepDaily = mergeDaily(sleepDaily, with: allMetrics.sleepDaily)
        sleepInBedDaily = mergeDaily(sleepInBedDaily, with: allMetrics.sleepInBedDaily)
        bloodOxygenDaily = mergeDaily(bloodOxygenDaily, with: allMetrics.bloodOxygenDaily)
        cardioFitnessDaily = mergeDaily(cardioFitnessDaily, with: allMetrics.cardioFitnessDaily)
        dietaryCaloriesDaily = mergeDaily(dietaryCaloriesDaily, with: allMetrics.dietaryCaloriesDaily)
        dietaryProteinDaily = mergeDaily(dietaryProteinDaily, with: allMetrics.dietaryProteinDaily)
        
        isDataLoaded = true
        lastFetchedDate = fetchedAt
    }
    
    private func workoutKey(_ w: HKWorkout) -> String {
        "\(w.startDate.timeIntervalSince1970)-\(w.endDate.timeIntervalSince1970)-\(w.workoutActivityType.rawValue)"
    }
    
    private func mergeDaily(_ existing: [DailyHealthMetric], with incoming: [DailyHealthMetric]) -> [DailyHealthMetric] {
        var map: [Date: Double] = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0.value) })
        for m in incoming { map[m.date] = m.value }
        return map.keys.sorted().map { DailyHealthMetric(date: $0, value: map[$0] ?? 0) }
    }
    
    /// Clear all cached data
    func clearCache() {
        workouts = []
        stepsDaily = []
        activeCaloriesDaily = []
        basalCaloriesDaily = []
        totalCaloriesDaily = []
        distanceDaily = []
        heartRateDaily = []
        restingHeartRateDaily = []
        hrvDaily = []
        heartRateRecoveryDaily = []
        sleepDaily = []
        sleepInBedDaily = []
        bloodOxygenDaily = []
        cardioFitnessDaily = []
        dietaryCaloriesDaily = []
        dietaryProteinDaily = []
        isDataLoaded = false
        lastFetchedDate = nil
    }
    
    /// Check if data needs to be refreshed (older than 1 hour)
    func needsRefresh() -> Bool {
        guard let lastFetched = lastFetchedDate else { return true }
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return lastFetched < oneHourAgo
    }
}

// MARK: - Supporting Types

struct DailyHealthMetric {
    let date: Date
    let value: Double
    
    var day: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct FilteredHealthData {
    let workouts: [HKWorkout]
    let totalSteps: Double
    let avgSteps: Double
    let activeCalories: Double
    let totalCalories: Double
    let avgActiveCalories: Double
    let avgTotalCalories: Double
    let avgBasalCalories: Double? // Average basal (resting) calories from HealthKit
    let distanceKM: Double
    let avgDistance: Double
    let avgHeartRate: Double?
    let avgRestingHeartRate: Double?
    let avgHRV: Double? // Heart Rate Variability (SDNN) in milliseconds - higher = better recovery
    let avgHeartRateRecovery: Double?
    let workoutCount: Int
    let totalWorkoutMinutes: Double
    let totalSleepHours: Double
    let avgSleepHours: Double
    let avgSleepInBedHours: Double
    let avgBloodOxygen: Double?
    let avgCardioFitness: Double?
    let dayCount: Int
    
    // Nutrition data (if available - improves body composition accuracy)
    let avgDietaryCalories: Double? // Average calories consumed per day
    let avgDietaryProtein: Double? // Average protein per day (grams)
    let totalDietaryCalories: Double // Total calories consumed over period
}

