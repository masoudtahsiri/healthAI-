import Foundation
import HealthKit

/// AI Core engine for on-device health data analysis
class AICore: ObservableObject {
    
    // MARK: - Public Methods
    
    /// Analyze health data and generate insights for the user
    func analyzeHealthData(
        profile: UserProfile,
        recentWorkouts: [HKWorkout],
        weeklySteps: [DailyMetric],
        weeklyCalories: [DailyMetric],
        weeklyHeartRate: [DailyMetric]
    ) -> HealthInsight {
        
        // Calculate progress metrics
        let progressScore = calculateProgressScore(
            profile: profile,
            recentWorkouts: recentWorkouts,
            weeklySteps: weeklySteps,
            weeklyCalories: weeklyCalories
        )
        
        // Estimate body composition changes
        let bodyComposition = estimateBodyComposition(
            profile: profile,
            recentWorkouts: recentWorkouts,
            weeklyCalories: weeklyCalories
        )
        
        // Generate personalized recommendations
        let recommendations = generateRecommendations(
            profile: profile,
            progressScore: progressScore,
            weeklySteps: weeklySteps,
            weeklyCalories: weeklyCalories
        )
        
        // Calculate weekly summary
        let weeklySummary = generateWeeklySummary(
            steps: weeklySteps,
            calories: weeklyCalories,
            heartRate: weeklyHeartRate,
            workouts: recentWorkouts
        )
        
        return HealthInsight(
            progressScore: progressScore,
            bodyComposition: bodyComposition,
            recommendations: recommendations,
            weeklySummary: weeklySummary,
            estimatedFatLoss: bodyComposition.estimatedFatLoss,
            estimatedMuscleGain: bodyComposition.estimatedMuscleGain
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func calculateProgressScore(
        profile: UserProfile,
        recentWorkouts: [HKWorkout],
        weeklySteps: [DailyMetric],
        weeklyCalories: [DailyMetric]
    ) -> Int {
        var score = 50 // Base score
        
        // Activity level analysis
        let avgSteps = weeklySteps.isEmpty ? 0 : weeklySteps.map { $0.value }.reduce(0, +) / Double(weeklySteps.count)
        if avgSteps > 8000 {
            score += 20
        } else if avgSteps > 5000 {
            score += 10
        }
        
        // Calorie burn analysis
        let avgCalories = weeklyCalories.isEmpty ? 0 : weeklyCalories.map { $0.value }.reduce(0, +) / Double(weeklyCalories.count)
        if avgCalories > 500 {
            score += 15
        } else if avgCalories > 300 {
            score += 8
        }
        
        // Workout consistency
        if recentWorkouts.count >= 4 {
            score += 15
        } else if recentWorkouts.count >= 2 {
            score += 8
        }
        
        return min(100, score)
    }
    
    private func estimateBodyComposition(
        profile: UserProfile,
        recentWorkouts: [HKWorkout],
        weeklyCalories: [DailyMetric]
    ) -> BodyCompositionEstimate {
        let totalCaloriesBurned = weeklyCalories.reduce(0) { $0 + $1.value }
        let avgCaloriesPerDay = weeklyCalories.isEmpty ? 0 : totalCaloriesBurned / Double(weeklyCalories.count)
        
        let maintenanceCalories = calculateMaintenanceCalories(profile: profile)
        let caloricDeficit = maintenanceCalories - avgCaloriesPerDay
        
        var estimatedFatLoss = 0.0
        var estimatedMuscleGain = 0.0
        
        if caloricDeficit > 0 {
            // Calculate estimated fat loss (7700 calories = 1 kg fat)
            estimatedFatLoss = abs(caloricDeficit * 7) / 7700.0
            
            // If user is exercising regularly, preserve muscle
            if recentWorkouts.count > 0 {
                estimatedFatLoss *= 0.9 // Account for muscle preservation
            }
        } else if caloricDeficit < 0 && recentWorkouts.count > 0 {
            // Caloric surplus with exercise = potential muscle gain
            estimatedMuscleGain = abs(caloricDeficit * 7) / 2500.0 // Rough estimate
            
            // Also consider that some will be fat
            if estimatedMuscleGain > 0.5 {
                estimatedMuscleGain *= 0.6 // 60% muscle, 40% fat gain ratio
            }
        }
        
        return BodyCompositionEstimate(
            estimatedFatLoss: estimatedFatLoss,
            estimatedMuscleGain: estimatedMuscleGain,
            currentWeight: profile.weight,
            estimatedCurrentWeight: profile.weight - estimatedFatLoss + estimatedMuscleGain,
            desiredWeight: nil
        )
    }
    
    private func generateRecommendations(
        profile: UserProfile,
        progressScore: Int,
        weeklySteps: [DailyMetric],
        weeklyCalories: [DailyMetric]
    ) -> [String] {
        var recommendations: [String] = []
        
        let avgSteps = weeklySteps.isEmpty ? 0 : weeklySteps.map { $0.value }.reduce(0, +) / Double(weeklySteps.count)
        let avgCalories = weeklyCalories.isEmpty ? 0 : weeklyCalories.map { $0.value }.reduce(0, +) / Double(weeklyCalories.count)
        
        // Step recommendations
        if avgSteps < 5000 {
            recommendations.append("Try to walk 10,000 steps daily. Start with short walks.")
        } else if avgSteps < 8000 {
            recommendations.append("Great progress! Aim for 10,000+ steps for optimal health.")
        }
        
        // Calorie recommendations based on goal
        switch profile.fitnessGoal {
        case .loseWeight, .getToned:
            let _ = calculateMaintenanceCalories(profile: profile)
            if avgCalories < 300 {
                recommendations.append("Increase activity gradually. Aim for 300-500 calories burned daily.")
            } else if avgCalories > 800 {
                recommendations.append("Great calorie burn! Ensure you're eating enough protein to preserve muscle.")
            }
            
        case .gainMuscle, .buildStrength:
            if avgCalories < 500 {
                recommendations.append("For muscle gain, aim for consistent resistance training and higher calories.")
            } else {
                recommendations.append("Excellent! Continue progressive overload and ensure adequate protein intake.")
            }
            
        case .maintain:
            recommendations.append("Your activity level looks balanced. Keep up the good work!")
            
        case .improveFitness, .improveEndurance, .cardiovascularHealth:
            if avgSteps < 8000 {
                recommendations.append("Mix cardio and strength training for overall fitness.")
            }
            
        case .athleticPerformance:
            if avgCalories < 500 {
                recommendations.append("Focus on sport-specific training and adequate recovery for peak performance.")
            }
            
        case .increaseFlexibility:
            recommendations.append("Include stretching and mobility work in your routine for better flexibility.")
            
        case .reduceStress, .mentalWellness:
            recommendations.append("Regular movement helps reduce stress. Aim for consistent, moderate activity.")
            
        case .betterSleep:
            recommendations.append("Regular exercise improves sleep quality. Maintain consistent activity patterns.")
            
        case .injuryRecovery:
            recommendations.append("Follow a gradual return-to-activity plan. Focus on proper form and recovery.")
            
        case .boostEnergy:
            recommendations.append("Regular moderate exercise boosts energy levels. Start with low-intensity activities.")
            
        case .generalHealth:
            if avgSteps < 5000 {
                recommendations.append("Aim for at least 10,000 steps daily for optimal general health.")
            }
        }
        
        // Progress-specific recommendations
        if progressScore < 50 {
            recommendations.append("Start with 3 workouts per week. Consistency is key.")
        } else if progressScore >= 80 {
            recommendations.append("Outstanding progress! Consider periodization for continued gains.")
        }
        
        return recommendations.isEmpty ? ["Keep tracking your progress and stay consistent!"] : recommendations
    }
    
    private func generateWeeklySummary(
        steps: [DailyMetric],
        calories: [DailyMetric],
        heartRate: [DailyMetric],
        workouts: [HKWorkout]
    ) -> WeeklySummary {
        let totalSteps = steps.reduce(0) { $0 + $1.value }
        let avgDailySteps = steps.isEmpty ? 0 : totalSteps / Double(steps.count)
        
        let totalCalories = calories.reduce(0) { $0 + $1.value }
        let avgDailyCalories = calories.isEmpty ? 0 : totalCalories / Double(calories.count)
        
        let avgHeartRate = heartRate.map { $0.value }.filter { $0 > 0 }.reduce(0, +) / Double(max(1, heartRate.filter { $0.value > 0 }.count))
        
        let totalWorkoutMinutes = workouts.reduce(0.0) { total, workout in
            total + workout.duration / 60.0 // Convert to minutes
        }
        
        return WeeklySummary(
            totalSteps: totalSteps,
            avgDailySteps: avgDailySteps,
            totalDistanceKM: 0,
            avgDailyDistanceKM: 0,
            activeCalories: totalCalories,
            totalCalories: totalCalories,
            avgActiveCalories: avgDailyCalories,
            avgTotalCalories: avgDailyCalories,
            avgHeartRate: avgHeartRate > 0 ? avgHeartRate : nil,
            workoutCount: workouts.count,
            totalWorkoutMinutes: totalWorkoutMinutes,
            totalSleepHours: 0,
            avgSleepHours: 0,
            avgBloodOxygen: nil,
            avgCardioFitness: nil
        )
    }
    
    private func calculateMaintenanceCalories(profile: UserProfile) -> Double {
        // Simplified BMR calculation (Mifflin-St Jeor approximation)
        var bmr: Double = 0
        let age = profile.age ?? 30 // Default to 30 if age not available
        
        if profile.gender == .male {
            bmr = 10 * profile.weight + 6.25 * profile.height - 5 * Double(age) + 5
        } else {
            bmr = 10 * profile.weight + 6.25 * profile.height - 5 * Double(age) - 161
        }
        
        // Add activity factor (average active person)
        return bmr * 1.55 // Moderately active
    }
}

// MARK: - Supporting Types

struct DailyMetric {
    let date: Date
    let value: Double
    
    var day: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct HealthInsight {
    let progressScore: Int
    let bodyComposition: BodyCompositionEstimate
    let recommendations: [String]
    let weeklySummary: WeeklySummary
    let estimatedFatLoss: Double
    let estimatedMuscleGain: Double
}

struct BodyCompositionEstimate {
    let estimatedFatLoss: Double
    let estimatedMuscleGain: Double
    let currentWeight: Double
    let estimatedCurrentWeight: Double
    let desiredWeight: Double?
}

struct WeeklySummary {
    // Steps
    let totalSteps: Double
    let avgDailySteps: Double
    
    // Distance
    let totalDistanceKM: Double
    let avgDailyDistanceKM: Double
    
    // Calories
    let activeCalories: Double
    let totalCalories: Double
    let avgActiveCalories: Double
    let avgTotalCalories: Double
    
    // Heart Rate
    let avgHeartRate: Double?
    
    // Workouts
    let workoutCount: Int
    let totalWorkoutMinutes: Double
    
    // Sleep
    let totalSleepHours: Double
    let avgSleepHours: Double
    
    // Blood Oxygen
    let avgBloodOxygen: Double?
    
    // Cardio Fitness (VO2 Max)
    let avgCardioFitness: Double?
}

