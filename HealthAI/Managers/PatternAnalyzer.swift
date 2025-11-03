import Foundation
import HealthKit

// MARK: - Pattern Insight Models

struct PatternInsights {
    let bestPerformingDays: [DayPerformance]
    let comparisons: ComparisonInsights
    let activeInactivePattern: ActiveInactivePattern
    let efficiencyScore: EfficiencyMetrics
    let consistencyHeatmap: ConsistencyHeatmap
    let plateauStatus: PlateauStatus
}

struct DayPerformance {
    let dayOfWeek: DayOfWeek
    let averageActivity: Double // Combined score
    let totalDays: Int
    let rank: Int // 1 = best, 7 = worst
    let percentageAboveAverage: Double
}

enum DayOfWeek: String, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

struct ActiveInactivePattern {
    let activeDaysCount: Int
    let inactiveDaysCount: Int
    let totalDays: Int
    let activePercentage: Double
    let longestActiveStreak: Int
    let longestInactiveStreak: Int
    let timeOfDayActivity: TimeOfDayActivity
    let trend: TrendDirection
}

struct TimeOfDayActivity {
    let morning: Double // 6 AM - 12 PM
    let afternoon: Double // 12 PM - 6 PM
    let evening: Double // 6 PM - 10 PM
    let night: Double // 10 PM - 6 AM
    let mostActivePeriod: String
}

enum TrendDirection {
    case improving
    case stable
    case declining
}

struct EfficiencyMetrics {
    let workoutEfficiency: Double // Calories per workout minute
    let heartHealthEfficiency: Double? // Heart rate improvement (bpm/hour if workouts, bpm/day if no workouts)
    let fitnessGains: Double? // VO2 Max improvement (per workout if workouts exist, per day if no workouts)
    let sleepEfficiency: Double? // Sleep improvement per day (hours/day) compared to previous period
    let hasWorkouts: Bool // Whether workouts exist in the period (to determine display units)
    let overallScore: Int // 0-100
    let insight: String
    let categorizedInsights: EfficiencyInsights? // Categorized AI insights
    let isLoadingInsights: Bool // Loading state for AI insights
}

struct EfficiencyInsights {
    let overallAssessment: String
    let areasForImprovement: [String] // List of specific improvements with actionable plans
    let whatIsWorkingWell: String
    let isValid: Bool // Whether this is a valid AI response (not fallback)
}

struct ConsistencyHeatmap {
    let days: [HeatmapDay]
    let weeks: Int
    let consistencyScore: Double // 0-100
}

struct HeatmapDay {
    let date: Date
    let activityLevel: ActivityLevel
    let value: Double // Combined activity score
}

enum ActivityLevel {
    case inactive
    case low
    case medium
    case high
    case veryHigh
    
    var color: String {
        switch self {
        case .inactive: return "gray"
        case .low: return "yellow"
        case .medium: return "green"
        case .high: return "darkGreen"
        case .veryHigh: return "darkestGreen"
        }
    }
}

struct PlateauStatus {
    let isPlateau: Bool
    let daysInPlateau: Int
    let severity: PlateauSeverity
    let suggestedActions: [String]
    let confidence: Double // 0-1
}

enum PlateauSeverity {
    case none
    case mild
    case moderate
    case severe
}

// MARK: - Comparison Models

struct ComparisonInsights {
    let periodLabel: String // e.g., "Day vs Yesterday", "Week vs Last Week"
    let metrics: [MetricComparison]
    let caloriesByWorkoutType: [WorkoutCaloriesComparison]
}

struct MetricComparison {
    let name: String
    let current: Double?
    let previous: Double?
    let absoluteChange: Double?
    let percentChange: Double?
    let direction: TrendDirection // improving/stable/declining
}

struct WorkoutCaloriesComparison {
    let type: String
    let currentKcal: Double
    let previousKcal: Double
    let absoluteChange: Double
    let percentChange: Double?
    let direction: TrendDirection
}

// MARK: - Pattern Analyzer

class PatternAnalyzer {
    
    // Activity thresholds
    private let activeDayThreshold = 5000.0 // steps
    private let activeCalorieThreshold = 300.0 // active calories
    private let workoutThreshold = 1 // at least 1 workout
    
    // MARK: - Main Analysis
    
    func analyzePatterns(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date,
        rangeType: DateRangeType,
        profile: UserProfile,
        bodyCompositionPrediction: BodyCompositionPrediction,
        healthKitManager: HealthKitManager?
    ) async -> PatternInsights {
        
        let filteredData = cache.filterByDateRange(startDate: startDate, endDate: endDate)
        
        // Get detailed daily data
        let dailyData = getDailyData(
            cache: cache,
            startDate: startDate,
            endDate: endDate
        )
        
        return PatternInsights(
            bestPerformingDays: analyzeBestPerformingDays(dailyData: dailyData),
            comparisons: analyzeComparisons(
                cache: cache,
                startDate: startDate,
                endDate: endDate,
                filteredCurrent: filteredData,
                rangeType: rangeType
            ),
            activeInactivePattern: analyzeActiveInactivePattern(
                dailyData: dailyData,
                workouts: filteredData.workouts,
                previousPeriodData: getPreviousPeriodData(
                    cache: cache,
                    startDate: startDate,
                    endDate: endDate
                )
            ),
            efficiencyScore: await calculateEfficiency(
                cache: cache,
                startDate: startDate,
                endDate: endDate,
                rangeType: rangeType,
                filteredData: filteredData,
                bodyCompositionPrediction: bodyCompositionPrediction,
                dayCount: filteredData.dayCount,
                healthKitManager: healthKitManager
            ),
            consistencyHeatmap: generateHeatmap(
                dailyData: dailyData,
                startDate: startDate,
                endDate: endDate
            ),
            plateauStatus: detectPlateau(
                cache: cache,
                startDate: startDate,
                endDate: endDate,
                profile: profile,
                bodyCompositionPrediction: bodyCompositionPrediction
            )
        )
    }
    
    // MARK: - Period Comparisons
    
    private func analyzeComparisons(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date,
        filteredCurrent: FilteredHealthData,
        rangeType: DateRangeType
    ) -> ComparisonInsights {
        let calendar = Calendar.current
        let now = Date()
        let currentStart = startDate
        // Use end exclusive; clamp to now for "so far"
        let currentEnd = min(endDate, now)
        let elapsed = currentEnd.timeIntervalSince(currentStart)
        
        // Compute previous window using same-time/day/date semantics
        let previousStartDate: Date
        let previousEndDate: Date
        switch rangeType {
        case .daily:
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart.addingTimeInterval(-86400)
            previousStartDate = yesterdayStart
            previousEndDate = yesterdayStart.addingTimeInterval(elapsed)
        case .weekly:
            // Week starts at local week start; compare Mon->now vs last week Mon->same weekday/time
            let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart.addingTimeInterval(-7*86400)
            previousStartDate = lastWeekStart
            previousEndDate = lastWeekStart.addingTimeInterval(elapsed)
        case .monthly:
            // Month-to-date vs same date/time last month; fallback to elapsed seconds from last month start clamped to last month end
            let comps = calendar.dateComponents([.year, .month], from: currentStart)
            let lastMonthStart = calendar.date(byAdding: DateComponents(month: -1), to: calendar.date(from: comps) ?? currentStart) ?? currentStart
            let nextMonthStart = calendar.date(byAdding: DateComponents(month: 1), to: lastMonthStart) ?? lastMonthStart
            let candidateEnd = lastMonthStart.addingTimeInterval(elapsed)
            previousStartDate = lastMonthStart
            previousEndDate = min(candidateEnd, nextMonthStart)
        case .sixMonths:
            // To-date vs same date/time 6 months ago start; approximate by shifting start back 6 months and applying elapsed
            let sixMonthsAgoStart = calendar.date(byAdding: DateComponents(month: -6), to: currentStart) ?? currentStart
            previousStartDate = sixMonthsAgoStart
            previousEndDate = sixMonthsAgoStart.addingTimeInterval(elapsed)
        case .yearly:
            // Year-to-date vs same date/time last year
            let lastYearStart = calendar.date(byAdding: DateComponents(year: -1), to: currentStart) ?? currentStart
            previousStartDate = lastYearStart
            previousEndDate = lastYearStart.addingTimeInterval(elapsed)
        }
        
        let filteredPrevious = cache.filterByDateRange(startDate: previousStartDate, endDate: previousEndDate)
        
        let periodLabel = makePeriodLabel(
            currentStart: currentStart,
            currentEnd: currentEnd,
            previousStart: previousStartDate,
            previousEnd: previousEndDate,
            rangeType: rangeType
        )
        
        var metrics: [MetricComparison] = []
        
        func compare(_ name: String, _ current: Double?, _ previous: Double?, higherIsBetter: Bool = true) {
            // Handle asymmetric presence/absence as directional signals with capped percent (±100)
            let cVal = current ?? 0
            let pVal = previous ?? 0
            if (current == nil || cVal == 0), (previous != nil && pVal > 0) {
                let dir: TrendDirection = higherIsBetter ? .declining : .improving
                metrics.append(MetricComparison(name: name, current: current, previous: previous, absoluteChange: cVal - pVal, percentChange: -100, direction: dir))
                return
            }
            if (previous == nil || pVal == 0), (current != nil && cVal > 0) {
                let dir: TrendDirection = higherIsBetter ? .improving : .declining
                metrics.append(MetricComparison(name: name, current: current, previous: previous, absoluteChange: cVal - pVal, percentChange: 100, direction: dir))
                return
            }
            // If both missing or both zero, stable
            if (current == nil && previous == nil) || (cVal == 0 && pVal == 0) {
                metrics.append(MetricComparison(name: name, current: current, previous: previous, absoluteChange: nil, percentChange: nil, direction: .stable))
                return
            }
            // Both present and at least one non-zero → compute normally
            guard let c = current, let p = previous else {
                metrics.append(MetricComparison(name: name, current: current, previous: previous, absoluteChange: nil, percentChange: nil, direction: .stable))
                return
            }
            let absChange = c - p
            let rawPct = p != 0 ? (absChange / p) * 100.0 : 0
            let pct = max(-100, min(100, rawPct))
            let isUp = absChange > 0.0001
            let isDown = absChange < -0.0001
            let dir: TrendDirection
            if isUp {
                dir = higherIsBetter ? .improving : .declining
            } else if isDown {
                dir = higherIsBetter ? .declining : .improving
            } else {
                dir = .stable
            }
            metrics.append(MetricComparison(name: name, current: c, previous: p, absoluteChange: absChange, percentChange: pct, direction: dir))
        }
        
        // Totals and averages available in cache
        compare("Total Energy (kcal)", filteredCurrent.totalCalories, filteredPrevious.totalCalories)
        compare("Active Energy (kcal)", filteredCurrent.activeCalories, filteredPrevious.activeCalories)
        compare("Workout Duration (Min)", filteredCurrent.totalWorkoutMinutes, filteredPrevious.totalWorkoutMinutes)
        compare("Total Sleep (hrs)", filteredCurrent.totalSleepHours, filteredPrevious.totalSleepHours)
        compare("Steps", filteredCurrent.totalSteps, filteredPrevious.totalSteps)
        compare("Distance (km)", filteredCurrent.distanceKM, filteredPrevious.distanceKM)
        // Heart metrics: lower resting HR is better, HRV/VO2 higher is better
        compare("Avg Heart Rate (bpm)", filteredCurrent.avgHeartRate, filteredPrevious.avgHeartRate, higherIsBetter: false)
        // Blood oxygen is stored as decimal (0.0-1.0) in HealthKit, convert to percentage (0-100) for comparison
        compare("Blood Oxygen (%)", 
                filteredCurrent.avgBloodOxygen.map { $0 * 100.0 }, 
                filteredPrevious.avgBloodOxygen.map { $0 * 100.0 })
        compare("VO₂ Max", filteredCurrent.avgCardioFitness, filteredPrevious.avgCardioFitness)
        
        // Calories by workout type
        let currentByType = caloriesByWorkoutType(workouts: filteredCurrent.workouts)
        let previousByType = caloriesByWorkoutType(workouts: filteredPrevious.workouts)
        let allTypes = Set(currentByType.keys).union(previousByType.keys)
        var caloriesByTypeComparisons: [WorkoutCaloriesComparison] = []
        for type in allTypes {
            let c = currentByType[type] ?? 0
            let p = previousByType[type] ?? 0
            let absChange = c - p
            let pct: Double? = {
                if p == 0 && c > 0 { return 100 }
                if p > 0 && c == 0 { return -100 }
                if p == 0 && c == 0 { return 0 }
                let raw = (absChange / p) * 100.0
                return max(-100, min(100, raw))
            }()
            let dir: TrendDirection = absChange > 0.0001 ? .improving : absChange < -0.0001 ? .declining : .stable
            caloriesByTypeComparisons.append(WorkoutCaloriesComparison(type: type, currentKcal: c, previousKcal: p, absoluteChange: absChange, percentChange: pct, direction: dir))
        }
        
        return ComparisonInsights(
            periodLabel: periodLabel,
            metrics: metrics,
            caloriesByWorkoutType: caloriesByTypeComparisons.sorted { $0.currentKcal > $1.currentKcal }
        )
    }
    
    private func makePeriodLabel(currentStart: Date, currentEnd: Date, previousStart: Date, previousEnd: Date, rangeType: DateRangeType) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        switch rangeType {
        case .daily:
            // Day: "Yesterday / Today" or "Oct 14 / Oct 15"
            dateFormatter.dateFormat = "MMM d"
            let currentStr = dateFormatter.string(from: currentStart)
            let previousStr = dateFormatter.string(from: previousStart)
            let currentYearVal = calendar.component(.year, from: currentStart)
            
            if currentYearVal != currentYear {
                dateFormatter.dateFormat = "MMM d, yyyy"
                return "\(dateFormatter.string(from: previousStart)) / \(dateFormatter.string(from: currentStart))"
            }
            return "\(previousStr) / \(currentStr)"
            
        case .weekly:
            // Week: "Last Week / This Week" or "Oct 6-12 / Oct 13-19"
            dateFormatter.dateFormat = "MMM d"
            let currentStartStr = dateFormatter.string(from: currentStart)
            let currentEndStr = dateFormatter.string(from: currentEnd)
            let previousStartStr = dateFormatter.string(from: previousStart)
            let previousEndStr = dateFormatter.string(from: previousEnd)
            
            let currentMonth = calendar.component(.month, from: currentStart)
            let currentEndMonth = calendar.component(.month, from: currentEnd)
            let previousMonth = calendar.component(.month, from: previousStart)
            let previousEndMonth = calendar.component(.month, from: previousEnd)
            
            let currentRange: String
            if currentMonth == currentEndMonth {
                let endDay = calendar.component(.day, from: currentEnd)
                currentRange = "\(currentStartStr)-\(endDay)"
            } else {
                currentRange = "\(currentStartStr) - \(currentEndStr)"
            }
            
            let previousRange: String
            if previousMonth == previousEndMonth {
                let endDay = calendar.component(.day, from: previousEnd)
                previousRange = "\(previousStartStr)-\(endDay)"
            } else {
                previousRange = "\(previousStartStr) - \(previousEndStr)"
            }
            
            return "\(previousRange) / \(currentRange)"
            
        case .monthly:
            // Month: "Sep 1-15 / Oct 1-15" (no parentheses)
            dateFormatter.dateFormat = "MMM"
            let currentMonthName = dateFormatter.string(from: currentStart)
            let previousMonthName = dateFormatter.string(from: previousStart)
            let currentStartDay = calendar.component(.day, from: currentStart)
            let currentEndDay = calendar.component(.day, from: currentEnd)
            let previousStartDay = calendar.component(.day, from: previousStart)
            let previousEndDay = calendar.component(.day, from: previousEnd)
            
            var currentRange = "\(currentMonthName) \(currentStartDay)-\(currentEndDay)"
            var previousRange = "\(previousMonthName) \(previousStartDay)-\(previousEndDay)"
            
            let currentYearVal = calendar.component(.year, from: currentStart)
            let previousYearVal = calendar.component(.year, from: previousStart)
            
            if previousYearVal != currentYear {
                previousRange = "\(previousMonthName) \(previousStartDay)-\(previousEndDay), \(previousYearVal)"
            }
            if currentYearVal != currentYear {
                currentRange = "\(currentMonthName) \(currentStartDay)-\(currentEndDay), \(currentYearVal)"
            }
            
            return "\(previousRange) / \(currentRange)"
            
        case .sixMonths:
            // 6 Months: "Oct 2023 - Mar 2024 / Apr-Oct 2024" (previous / current)
            dateFormatter.dateFormat = "MMM"
            let currentStartMonth = dateFormatter.string(from: currentStart)
            let currentEndMonth = dateFormatter.string(from: currentEnd)
            let previousStartMonth = dateFormatter.string(from: previousStart)
            let previousEndMonth = dateFormatter.string(from: previousEnd)
            
            let currentStartYear = calendar.component(.year, from: currentStart)
            let currentEndYear = calendar.component(.year, from: currentEnd)
            let previousStartYear = calendar.component(.year, from: previousStart)
            let previousEndYear = calendar.component(.year, from: previousEnd)
            
            let currentRange: String
            if currentStartYear == currentEndYear {
                if currentStartMonth == currentEndMonth {
                    currentRange = "\(currentStartMonth) \(currentStartYear)"
                } else {
                    currentRange = "\(currentStartMonth)-\(currentEndMonth) \(currentEndYear)"
                }
            } else {
                currentRange = "\(currentStartMonth) \(currentStartYear) - \(currentEndMonth) \(currentEndYear)"
            }
            
            let previousRange: String
            if previousStartYear == previousEndYear {
                if previousStartMonth == previousEndMonth {
                    previousRange = "\(previousStartMonth) \(previousStartYear)"
                } else {
                    previousRange = "\(previousStartMonth)-\(previousEndMonth) \(previousEndYear)"
                }
            } else {
                previousRange = "\(previousStartMonth) \(previousStartYear) - \(previousEndMonth) \(previousEndYear)"
            }
            
            return "\(previousRange) / \(currentRange)"
            
        case .yearly:
            // Year: "Jan-Dec 2023 / Jan-Oct 2024" or full year format
            dateFormatter.dateFormat = "MMM"
            let currentStartMonthName = dateFormatter.string(from: currentStart)
            let currentEndMonthName = dateFormatter.string(from: currentEnd)
            let previousStartMonthName = dateFormatter.string(from: previousStart)
            let previousEndMonthName = dateFormatter.string(from: previousEnd)
            
            let currentStartYear = calendar.component(.year, from: currentStart)
            let previousStartYear = calendar.component(.year, from: previousStart)
            
            let currentStartMonth = calendar.component(.month, from: currentStart)
            let currentEndMonth = calendar.component(.month, from: currentEnd)
            let previousStartMonth = calendar.component(.month, from: previousStart)
            let previousEndMonth = calendar.component(.month, from: previousEnd)
            
            // Format current period
            let currentRange: String
            if currentStartMonth == 1 && currentEndMonth == 12 {
                currentRange = "\(currentStartYear)"
            } else if currentStartMonth == currentEndMonth {
                currentRange = "\(currentStartMonthName) \(currentStartYear)"
            } else {
                currentRange = "\(currentStartMonthName)-\(currentEndMonthName) \(currentStartYear)"
            }
            
            // Format previous period
            let previousRange: String
            if previousStartMonth == 1 && previousEndMonth == 12 {
                previousRange = "\(previousStartYear)"
            } else if previousStartMonth == previousEndMonth {
                previousRange = "\(previousStartMonthName) \(previousStartYear)"
            } else {
                previousRange = "\(previousStartMonthName)-\(previousEndMonthName) \(previousStartYear)"
            }
            
            return "\(previousRange) / \(currentRange)"
        }
    }
    
    private func caloriesByWorkoutType(workouts: [HKWorkout]) -> [String: Double] {
        var map: [String: Double] = [:]
        for w in workouts {
            let typeName = String(describing: w.workoutActivityType)
            // Get energy burned using protocol to suppress deprecation warning
            // totalEnergyBurned is deprecated for query-level statistics in iOS 18+,
            // but still valid for individual workout object access
            let kcal = (w as WorkoutEnergyAccess).totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            map[typeName, default: 0] += kcal
        }
        return map
    }

    // MARK: - Best Performing Days
    
    private func analyzeBestPerformingDays(dailyData: [DailyActivityData]) -> [DayPerformance] {
        var dayGroups: [DayOfWeek: [DailyActivityData]] = [:]
        
        // Group by day of week
        for day in dailyData {
            let weekday = getDayOfWeek(from: day.date)
            dayGroups[weekday, default: []].append(day)
        }
        
        // Calculate average activity for each day
        var performances: [DayPerformance] = []
        let overallAverage = dailyData.map { $0.combinedScore }.reduce(0, +) / Double(max(1, dailyData.count))
        
        for (_, dayOfWeek) in DayOfWeek.allCases.enumerated() {
            if let days = dayGroups[dayOfWeek], !days.isEmpty {
                let averageActivity = days.map { $0.combinedScore }.reduce(0, +) / Double(days.count)
                let percentageAboveAverage = overallAverage > 0 ? ((averageActivity - overallAverage) / overallAverage) * 100 : 0
                
                performances.append(DayPerformance(
                    dayOfWeek: dayOfWeek,
                    averageActivity: averageActivity,
                    totalDays: days.count,
                    rank: 0, // Will be set after sorting
                    percentageAboveAverage: percentageAboveAverage
                ))
            }
        }
        
        // Sort by average activity (best first)
        performances.sort { $0.averageActivity > $1.averageActivity }
        
        // Assign ranks
        for (index, _) in performances.enumerated() {
            performances[index] = DayPerformance(
                dayOfWeek: performances[index].dayOfWeek,
                averageActivity: performances[index].averageActivity,
                totalDays: performances[index].totalDays,
                rank: index + 1,
                percentageAboveAverage: performances[index].percentageAboveAverage
            )
        }
        
        return performances
    }
    
    // MARK: - Active/Inactive Pattern
    
    private func analyzeActiveInactivePattern(
        dailyData: [DailyActivityData],
        workouts: [HKWorkout],
        previousPeriodData: [DailyActivityData]
    ) -> ActiveInactivePattern {
        
        var activeDays = 0
        var inactiveDays = 0
        var currentActiveStreak = 0
        var currentInactiveStreak = 0
        var longestActiveStreak = 0
        var longestInactiveStreak = 0
        
        let sortedData = dailyData.sorted { $0.date < $1.date }
        
        // Calculate streaks and counts
        for day in sortedData {
            let isActive = day.isActiveDay
            
            if isActive {
                activeDays += 1
                currentActiveStreak += 1
                currentInactiveStreak = 0
                longestActiveStreak = max(longestActiveStreak, currentActiveStreak)
            } else {
                inactiveDays += 1
                currentInactiveStreak += 1
                currentActiveStreak = 0
                longestInactiveStreak = max(longestInactiveStreak, currentInactiveStreak)
            }
        }
        
        let totalDays = activeDays + inactiveDays
        let activePercentage = totalDays > 0 ? (Double(activeDays) / Double(totalDays)) * 100 : 0
        
        // Analyze time of day activity
        let timeOfDay = analyzeTimeOfDayActivity(workouts: workouts)
        
        // Determine trend
        let trend = calculateTrend(current: dailyData, previous: previousPeriodData)
        
        return ActiveInactivePattern(
            activeDaysCount: activeDays,
            inactiveDaysCount: inactiveDays,
            totalDays: totalDays,
            activePercentage: activePercentage,
            longestActiveStreak: longestActiveStreak,
            longestInactiveStreak: longestInactiveStreak,
            timeOfDayActivity: timeOfDay,
            trend: trend
        )
    }
    
    private func analyzeTimeOfDayActivity(workouts: [HKWorkout]) -> TimeOfDayActivity {
        var morning = 0.0
        var afternoon = 0.0
        var evening = 0.0
        var night = 0.0
        var morningCount = 0
        var afternoonCount = 0
        var eveningCount = 0
        var nightCount = 0
        
        for workout in workouts {
            let hour = Calendar.current.component(.hour, from: workout.startDate)
            let duration = workout.duration / 60 // minutes
            
            if hour >= 6 && hour < 12 {
                morning += duration
                morningCount += 1
            } else if hour >= 12 && hour < 18 {
                afternoon += duration
                afternoonCount += 1
            } else if hour >= 18 && hour < 22 {
                evening += duration
                eveningCount += 1
            } else {
                night += duration
                nightCount += 1
            }
        }
        
        let avgMorning = morningCount > 0 ? morning / Double(morningCount) : 0
        let avgAfternoon = afternoonCount > 0 ? afternoon / Double(afternoonCount) : 0
        let avgEvening = eveningCount > 0 ? evening / Double(eveningCount) : 0
        let avgNight = nightCount > 0 ? night / Double(nightCount) : 0
        
        let values = [("Morning", avgMorning), ("Afternoon", avgAfternoon), ("Evening", avgEvening), ("Night", avgNight)]
        let mostActive = values.max(by: { $0.1 < $1.1 })?.0 ?? "Evening"
        
        return TimeOfDayActivity(
            morning: avgMorning,
            afternoon: avgAfternoon,
            evening: avgEvening,
            night: avgNight,
            mostActivePeriod: mostActive
        )
    }
    
    private func calculateTrend(current: [DailyActivityData], previous: [DailyActivityData]) -> TrendDirection {
        guard !current.isEmpty && !previous.isEmpty else { return .stable }
        
        let currentAvg = current.map { $0.combinedScore }.reduce(0, +) / Double(current.count)
        let previousAvg = previous.map { $0.combinedScore }.reduce(0, +) / Double(previous.count)
        
        let difference = currentAvg - previousAvg
        let percentChange = previousAvg > 0 ? (difference / previousAvg) * 100 : 0
        
        if percentChange > 5 {
            return .improving
        } else if percentChange < -5 {
            return .declining
        } else {
            return .stable
        }
    }
    
    // MARK: - Efficiency Score
    
    private func calculateEfficiency(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date,
        rangeType: DateRangeType,
        filteredData: FilteredHealthData,
        bodyCompositionPrediction: BodyCompositionPrediction,
        dayCount: Int,
        healthKitManager: HealthKitManager?
    ) async -> EfficiencyMetrics {
        
        // Get previous period data for comparisons (same logic as analyzeComparisons)
        let calendar = Calendar.current
        let now = Date()
        let currentStart = startDate
        let currentEnd = min(endDate, now)
        _ = currentEnd.timeIntervalSince(currentStart)
        
        switch rangeType {
        case .daily:
            _ = calendar.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart.addingTimeInterval(-86400)
        case .weekly:
            _ = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart.addingTimeInterval(-7*86400)
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: currentStart)
            _ = calendar.date(byAdding: DateComponents(month: -1), to: calendar.date(from: comps) ?? currentStart) ?? currentStart
        case .sixMonths:
            _ = calendar.date(byAdding: DateComponents(month: -6), to: currentStart) ?? currentStart
        case .yearly:
            _ = calendar.date(byAdding: DateComponents(year: -1), to: currentStart) ?? currentStart
        }
        
        // Debug: Log data availability
        print("📊 [Efficiency] Current period - HR: \(filteredData.avgHeartRate?.description ?? "nil"), VO2: \(filteredData.avgCardioFitness?.description ?? "nil")")
        
        // 1. Workout Efficiency: Calories per workout minute
        let totalWorkoutMinutes = filteredData.totalWorkoutMinutes
        let totalCalories = filteredData.activeCalories
        let workoutEfficiency = totalWorkoutMinutes > 0 ? totalCalories / totalWorkoutMinutes : 0
        
        // 2. Heart Health Efficiency: HR recovery rate (bpm/min)
        // Use direct HR recovery data from HealthKit (heartRateRecoveryOneMinute quantity type)
        var heartHealthEfficiency: Double? = nil
        if let hrRecovery = filteredData.avgHeartRateRecovery, hrRecovery > 0 {
            // HR recovery is already in bpm drop per minute (from 1-minute recovery)
            // This is the official HealthKit metric for HR recovery
            heartHealthEfficiency = hrRecovery
        } else if filteredData.workoutCount > 0,
                  let healthKitManager = healthKitManager {
            // Fallback: query actual HR samples if recovery data not available
            let restingHR = filteredData.avgRestingHeartRate ?? filteredData.avgHeartRate ?? 0
            heartHealthEfficiency = await healthKitManager.calculateHRRecoveryRate(
                for: filteredData.workouts,
                restingHR: restingHR
            )
        }
        
        // 3. Fitness Gains: VO2 Max per active day or per workout
        // Calculate VO2 Max divided by active days (days with workouts) or workout count
        var fitnessGains: Double? = nil
        if let vo2Max = filteredData.avgCardioFitness {
            if filteredData.workoutCount > 0 {
                // Show per workout
                fitnessGains = vo2Max / Double(filteredData.workoutCount)
            } else {
                // Show per active day (days with any activity)
                // Estimate active days: days with steps > 3000 or workouts
                let activeDays = max(1, filteredData.dayCount)
                fitnessGains = vo2Max / Double(activeDays)
            }
        }
        
        // 4. Sleep Efficiency: Sleep efficiency % (time asleep / time in bed)
        // Calculate using actual time in bed data from HealthKit
        // Only calculate if we have actual "in bed" data - don't estimate
        var sleepEfficiency: Double? = nil
        if filteredData.avgSleepHours > 0 && filteredData.avgSleepInBedHours > 0 {
            // Sleep efficiency = (time asleep / time in bed) * 100
            let timeInBed = filteredData.avgSleepInBedHours
            if timeInBed > 0 {
                sleepEfficiency = (filteredData.avgSleepHours / timeInBed) * 100.0
                // Clamp to 0-100%
                sleepEfficiency = min(100.0, max(0.0, sleepEfficiency ?? 0))
            }
        }
        
        // Overall Score (0-100)
        var score = 50 // Base score
        
        // Workout efficiency scoring
        if workoutEfficiency >= 10 {
            score += 20
        } else if workoutEfficiency >= 7 {
            score += 15
        } else if workoutEfficiency >= 5 {
            score += 10
        }
        
        // Heart health efficiency bonus (faster recovery is better)
        if let hrRecovery = heartHealthEfficiency {
            // Higher HR recovery rate indicates better cardiovascular fitness
            // Good recovery: >15 bpm/min, Excellent: >25 bpm/min
            if hrRecovery > 25 {
                score += 15 // Excellent recovery
            } else if hrRecovery > 15 {
                score += 8 // Good recovery
            }
        }
        
        // Fitness gains bonus (higher VO2 per workout/day is better)
        if let fitness = fitnessGains {
            // Higher VO2 per workout indicates better fitness efficiency
            if fitness > 1.0 {
                score += 15 // High VO2 efficiency
            } else if fitness > 0.5 {
                score += 8 // Moderate VO2 efficiency
            }
        }
        
        // Sleep efficiency bonus (higher % is better)
        if let sleepEff = sleepEfficiency {
            if sleepEff >= 85 {
                score += 20 // Excellent sleep efficiency (>85%)
            } else if sleepEff >= 75 {
                score += 10 // Good sleep efficiency (75-85%)
            } else if sleepEff < 65 {
                score -= 10 // Poor sleep efficiency (<65%)
            }
        }
        
        let finalScore = min(100, max(0, score))
        
        var insight = ""
        if workoutEfficiency >= 10 && (heartHealthEfficiency ?? 0) > 20 && (sleepEfficiency ?? 0) >= 85 {
            insight = "Excellent overall efficiency - maximizing health gains across all metrics"
        } else if workoutEfficiency >= 7 && (sleepEfficiency ?? 0) >= 75 {
            insight = "Good efficiency - maintain consistency for continued improvements"
        } else {
            insight = "Focus on workout quality and recovery for better efficiency"
        }
        
        return EfficiencyMetrics(
            workoutEfficiency: workoutEfficiency,
            heartHealthEfficiency: heartHealthEfficiency,
            fitnessGains: fitnessGains,
            sleepEfficiency: sleepEfficiency,
            hasWorkouts: totalWorkoutMinutes > 0,
            overallScore: finalScore,
            insight: insight,
            categorizedInsights: nil, // Will be populated by AI later
            isLoadingInsights: false
        )
    }
    
    // MARK: - Consistency Heatmap
    
    private func generateHeatmap(
        dailyData: [DailyActivityData],
        startDate: Date,
        endDate: Date
    ) -> ConsistencyHeatmap {
        
        let sortedData = dailyData.sorted { $0.date < $1.date }
        let days = sortedData.map { day in
            HeatmapDay(
                date: day.date,
                activityLevel: getActivityLevel(score: day.combinedScore),
                value: day.combinedScore
            )
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
        let weeks = max(1, components.weekOfYear ?? 1)
        
        // Calculate consistency score (0-100)
        let activeDays = days.filter { $0.activityLevel != .inactive }.count
        let consistencyScore = days.isEmpty ? 0 : (Double(activeDays) / Double(days.count)) * 100
        
        return ConsistencyHeatmap(
            days: days,
            weeks: weeks,
            consistencyScore: consistencyScore
        )
    }
    
    // MARK: - Plateau Detection
    
    private func detectPlateau(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date,
        profile: UserProfile,
        bodyCompositionPrediction: BodyCompositionPrediction
    ) -> PlateauStatus {
        
        // Check recent weight trend (would need weight history)
        // For now, check if net weight change is minimal
        let netChange = abs(bodyCompositionPrediction.netWeightChange)
        let dayCount = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 7)
        
        // Consider it a plateau if:
        // - Weight change is very small (< 0.2kg in 2+ weeks)
        // - Activity is consistent but no progress
        let weeks = Double(dayCount) / 7.0
        let weeklyChange = netChange / weeks
        
        let isPlateau = dayCount >= 14 && netChange < 0.2 && weeklyChange < 0.1
        
        var severity: PlateauSeverity = .none
        var daysInPlateau = 0
        var actions: [String] = []
        
        if isPlateau {
            daysInPlateau = dayCount
            
            if netChange < 0.1 {
                severity = .severe
            } else if netChange < 0.15 {
                severity = .moderate
            } else {
                severity = .mild
            }
            
            // Generate suggestions
            if bodyCompositionPrediction.strengthWorkoutCount == 0 {
                actions.append("Add strength training to boost metabolism")
            }
            if bodyCompositionPrediction.totalWorkoutMinutes < 150 {
                actions.append("Increase workout duration or frequency")
            }
            if bodyCompositionPrediction.avgSleepHours < 7 {
                actions.append("Prioritize sleep for better recovery")
            }
            actions.append("Consider varying your routine to break plateaus")
        }
        
        return PlateauStatus(
            isPlateau: isPlateau,
            daysInPlateau: daysInPlateau,
            severity: severity,
            suggestedActions: actions,
            confidence: isPlateau ? 0.8 : 0.1
        )
    }
    
    // MARK: - Helper Methods
    
    private func getDailyData(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date
    ) -> [DailyActivityData] {
        
        var dailyDataMap: [Date: DailyActivityData] = [:]
        
        // Process steps
        for metric in cache.stepsDaily {
            if metric.date >= startDate && metric.date <= endDate {
                let dayStart = Calendar.current.startOfDay(for: metric.date)
                if dailyDataMap[dayStart] == nil {
                    dailyDataMap[dayStart] = DailyActivityData(date: dayStart, steps: 0, calories: 0, workouts: [])
                }
                dailyDataMap[dayStart]?.steps += metric.value
            }
        }
        
        // Process calories
        for metric in cache.activeCaloriesDaily {
            if metric.date >= startDate && metric.date <= endDate {
                let dayStart = Calendar.current.startOfDay(for: metric.date)
                if dailyDataMap[dayStart] == nil {
                    dailyDataMap[dayStart] = DailyActivityData(date: dayStart, steps: 0, calories: 0, workouts: [])
                }
                dailyDataMap[dayStart]?.calories += metric.value
            }
        }
        
        // Process workouts
        for workout in cache.workouts {
            // Include workouts that overlap with the date range
            if workout.startDate <= endDate && workout.endDate >= startDate {
                let dayStart = Calendar.current.startOfDay(for: workout.startDate)
                if dailyDataMap[dayStart] == nil {
                    dailyDataMap[dayStart] = DailyActivityData(date: dayStart, steps: 0, calories: 0, workouts: [])
                }
                dailyDataMap[dayStart]?.workouts.append(workout)
            }
        }
        
        // Convert to array and calculate combined scores
        return dailyDataMap.values.map { data in
            var mutable = data
            mutable.calculateCombinedScore()
            mutable.determineActiveDay(thresholds: (steps: activeDayThreshold, calories: activeCalorieThreshold))
            return mutable
        }
    }
    
    private func getPreviousPeriodData(
        cache: HealthDataCache,
        startDate: Date,
        endDate: Date
    ) -> [DailyActivityData] {
        
        let duration = endDate.timeIntervalSince(startDate)
        let previousEndDate = startDate
        let previousStartDate = previousEndDate.addingTimeInterval(-duration)
        
        return getDailyData(cache: cache, startDate: previousStartDate, endDate: previousEndDate)
    }
    
    private func getDayOfWeek(from date: Date) -> DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        case 1: return .sunday
        default: return .monday
        }
    }
    
    private func getActivityLevel(score: Double) -> ActivityLevel {
        if score < 1000 {
            return .inactive
        } else if score < 3000 {
            return .low
        } else if score < 6000 {
            return .medium
        } else if score < 10000 {
            return .high
        } else {
            return .veryHigh
        }
    }
}

// MARK: - Workout Energy Access Protocol

// Protocol to access deprecated property without warning
private protocol WorkoutEnergyAccess {
    var totalEnergyBurned: HKQuantity? { get }
}

extension HKWorkout: WorkoutEnergyAccess {}

// MARK: - Daily Activity Data Model

struct DailyActivityData {
    let date: Date
    var steps: Double
    var calories: Double
    var workouts: [HKWorkout]
    
    var combinedScore: Double = 0
    var isActiveDay: Bool = false
    
    mutating func calculateCombinedScore() {
        // Normalize and combine metrics
        // Steps: divide by 1000 to get reasonable scale
        // Calories: keep as is
        // Workouts: add 1000 per workout
        let normalizedSteps = steps / 10 // Scale down
        let workoutBonus = Double(workouts.count) * 200
        combinedScore = normalizedSteps + calories + workoutBonus
    }
    
    mutating func determineActiveDay(thresholds: (steps: Double, calories: Double)) {
        isActiveDay = steps >= thresholds.steps || 
                      calories >= thresholds.calories || 
                      !workouts.isEmpty
    }
}

