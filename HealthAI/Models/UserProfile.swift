import Foundation

struct UserProfile: Codable {
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    var gender: Gender
    var weight: Double // in kg
    var height: Double // in cm
    var fitnessGoals: [FitnessGoal] // Changed to array for multi-select
    var createdAt: Date
    
    init(firstName: String = "", lastName: String = "", dateOfBirth: Date? = nil, gender: Gender = .male, weight: Double = 70.0, height: Double = 170.0, fitnessGoals: [FitnessGoal] = []) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.weight = weight
        self.height = height
        self.fitnessGoals = fitnessGoals.isEmpty ? [.loseWeight] : fitnessGoals
        self.createdAt = Date()
    }
    
    // Computed property for full name
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    // Computed property for age (calculated from dateOfBirth)
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let ageComponents = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
    
    var bmi: Double {
        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }
    
    var targetWeight: Double {
        // Use primary goal if available, otherwise average across goals
        let primaryGoal = fitnessGoals.first ?? .loseWeight
        
        switch primaryGoal {
        case .loseWeight, .getToned:
            return weight * 0.95 // 5% reduction target
        case .gainMuscle, .buildStrength, .athleticPerformance:
            return weight * 1.05 // 5% increase target
        case .maintain:
            return weight
        case .improveFitness, .improveEndurance, .cardiovascularHealth:
            return weight * 0.97 // slight reduction for better composition
        case .increaseFlexibility, .reduceStress, .betterSleep, .generalHealth, .injuryRecovery, .boostEnergy, .mentalWellness:
            return weight // maintain current weight for these goals
        }
    }
    
    // Legacy property for backward compatibility (uses first goal)
    var fitnessGoal: FitnessGoal {
        return fitnessGoals.first ?? .loseWeight
    }
}

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
}

enum FitnessGoal: String, Codable, CaseIterable {
    case loseWeight = "Lose Weight"
    case gainMuscle = "Gain Muscle"
    case maintain = "Maintain Weight"
    case improveFitness = "Improve Fitness"
    case buildStrength = "Build Strength"
    case improveEndurance = "Improve Endurance"
    case increaseFlexibility = "Increase Flexibility"
    case reduceStress = "Reduce Stress"
    case betterSleep = "Better Sleep"
    case generalHealth = "General Health"
    case athleticPerformance = "Athletic Performance"
    case injuryRecovery = "Injury Recovery"
    case boostEnergy = "Boost Energy"
    case cardiovascularHealth = "Cardiovascular Health"
    case getToned = "Get Toned"
    case mentalWellness = "Mental Wellness"
    
    var emoji: String {
        switch self {
        case .loseWeight: return "🔥"
        case .gainMuscle: return "💪"
        case .maintain: return "⚖️"
        case .improveFitness: return "🏃"
        case .buildStrength: return "🏋️"
        case .improveEndurance: return "🚴"
        case .increaseFlexibility: return "🧘"
        case .reduceStress: return "😌"
        case .betterSleep: return "😴"
        case .generalHealth: return "❤️"
        case .athleticPerformance: return "🏅"
        case .injuryRecovery: return "🩹"
        case .boostEnergy: return "⚡"
        case .cardiovascularHealth: return "🫀"
        case .getToned: return "✨"
        case .mentalWellness: return "🧠"
        }
    }
}

