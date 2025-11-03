# HealthAI Architecture

## System Overview

HealthAI is an iOS health tracking application that provides personalized insights through on-device AI analysis of HealthKit data. The app prioritizes privacy, with all processing happening locally on the device.

## Core Technologies

- **SwiftUI**: Modern declarative UI framework
- **HealthKit**: Apple's health data framework
- **Foundation/UserDefaults**: Local data storage
- **async/await**: Modern concurrency API
- **Combine**: Reactive state management

## Architecture Pattern

**MVVM (Model-View-ViewModel)**

### Models
- `UserProfile`: User demographic and goal data
- `DailyMetric`: Time-series health data points
- `HealthInsight`: AI-generated analysis results
- `BodyCompositionEstimate`: Body composition projections
- `WeeklySummary`: Aggregated weekly statistics

### Views
- `ContentView`: Root coordinator view
- `OnboardingView`: Multi-step user profile creation
- `DashboardView`: Main health insights dashboard with cards

### ViewModels/Managers
- `AppState`: Central app state management (ObservableObject)
- `HealthKitManager`: HealthKit data fetching and authorization
- `AICore`: On-device AI analysis engine

## Data Flow

```
┌─────────────────────────────────────────────────────┐
│                    User Interaction                   │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                   OnboardingView                     │
│  - Collects user info                               │
│  - Saves to UserDefaults                            │
│  - Creates UserProfile                              │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                      AppState                        │
│  - @Published userProfile                           │
│  - @Published hasCompletedOnboarding                 │
│  - HealthKitManager instance                        │
│  - AICore instance                                   │
└────────────────────────┬─────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                   DashboardView                      │
│  - Requests HealthKit authorization                 │
│  - Fetches health data (async)                      │
│  - Calls AICore for analysis                        │
│  - Displays insights                                │
└────────────────────────┬─────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│ HealthKitManager │          │      AICore       │
│  - Read steps    │          │  - Analyze data   │
│  - Read calories │◄─────────┤  - Generate insights
│  - Read workouts │          │  - Recommendations│
│  - Read heart    │          └──────────────────┘
│  - Read sleep    │                   │
└──────────────────┘                   │
                                       ▼
                            ┌────────────────────┐
                            │   HealthInsight    │
                            │   - Displayed to   │
                            │     user in cards  │
                            └────────────────────┘
```

## Key Components

### 1. AppleIntelligence (iOS 18+)
**Responsibilities**:
- Use Apple's Foundation Models Framework for advanced analysis
- Pattern recognition and trend detection
- Predictive health forecasting
- Personalized fitness and nutrition plans
- Smart workout and timing recommendations

**Key Methods**:
```swift
func analyzeWithAppleIntelligence(
    profile: UserProfile,
    healthData: HealthMetrics
) -> EnhancedHealthInsight
```

**Features**:
- Activity trend analysis (improving/stable/declining)
- Consistency level evaluation
- Optimal workout timing detection
- 30-day weight projections
- Goal achievement timeline estimates
- Custom workout and nutrition plans

### 2. AICore
**Responsibilities**:
- Basic health data analysis (fallback for older iOS)
- Progress scoring
- Body composition estimation
- Generate recommendations
- Weekly summaries

### 3. HealthKitManager

**Responsibilities**:
- Request and manage HealthKit authorization
- Read health data types (steps, calories, workouts, heart rate, sleep)
- Handle async operations with modern concurrency
- Error handling for HealthKit operations

**Key Methods**:
```swift
func requestAuthorization() async -> Bool
func readWorkouts(limit: Int) async -> [HKWorkout]
func readSteps(startDate: Date, endDate: Date) async -> Double
func readActiveCalories(startDate: Date, endDate: Date) async -> Double
func readAverageHeartRate(startDate: Date, endDate: Date) async -> Double?
func readSleepHours(startDate: Date, endDate: Date) async -> TimeInterval
```

### 2. AICore

**Responsibilities**:
- Analyze health data for insights
- Calculate progress scores
- Estimate body composition changes
- Generate personalized recommendations
- Create weekly summaries

**Key Methods**:
```swift
func analyzeHealthData(
    profile: UserProfile,
    recentWorkouts: [HKWorkout],
    weeklySteps: [DailyMetric],
    weeklyCalories: [DailyMetric],
    weeklyHeartRate: [DailyMetric]
) -> HealthInsight
```

**Analysis Algorithms**:
- **Progress Score**: Combines activity level, calorie burn, and workout consistency
- **Body Composition**: Estimates fat loss/muscle gain based on caloric deficit/surplus
- **Recommendations**: Goal-specific advice based on activity patterns

### 3. UserProfile Model

**Data Structure**:
```swift
struct UserProfile: Codable {
    var name: String
    var age: Int
    var gender: Gender
    var weight: Double // kg
    var height: Double // cm
    var fitnessGoal: FitnessGoal
    var createdAt: Date
}
```

**Computed Properties**:
- `bmi`: Body Mass Index calculation
- `targetWeight`: Goal-specific target weight

### 4. OnboardingFlow

**Steps**:
1. Welcome screen
2. Personal info (name, age, gender)
3. Physical stats (weight, height with sliders)
4. Goal selection (emoji-based UI)

**State Management**:
- Uses `@State` for form inputs
- Saves to `UserDefaults` via `AppState`
- Auto-advances to dashboard on completion

### 5. Dashboard UI

**Components**:
- `ProgressScoreCard`: Circular progress indicator (0-100)
- `WeeklySummaryCard`: Steps, calories, heart rate, workouts
- `BodyCompositionCard`: Fat loss/muscle gain estimates
- `RecommendationsCard`: AI-generated personalized tips

**Data Loading**:
- Fetches last 7 days of health data
- Handles loading states and errors
- Async/await for concurrent data fetching

## State Management

### ObservableObject Pattern
```swift
class AppState: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var hasCompletedOnboarding = false
}
```

### EnvironmentObject Injection
```swift
ContentView()
    .environmentObject(AppState())
```

## Concurrency Model

### Async/Await Pattern
- All HealthKit operations use `async` functions
- Data fetching runs in background tasks
- UI updates on `MainActor`

Example:
```swift
Task {
    await requestHealthKitAccess()
    let workouts = await manager.readWorkouts(limit: 50)
    await MainActor.run {
        // Update UI
    }
}
```

## Privacy Architecture

### On-Device Processing
- No external API calls
- No cloud services
- No data transmission

### Data Storage
- **UserDefaults**: User profile only
- **HealthKit**: All health data (managed by iOS)
- **Memory**: AI analysis results (temporary)

### Permissions
- HealthKit read-only access
- Requests specific data types
- User controls authorization in Settings

## Extensibility

### Adding New Health Metrics
1. Add type to `HealthKitManager.typesToRead`
2. Create read method in `HealthKitManager`
3. Update `AICore` analysis
4. Add UI component in `DashboardView`

### Adding New Analysis
1. Add method to `AICore`
2. Update `HealthInsight` model
3. Create new card in `DashboardView`
4. Update recommendations logic

### Adding New Goals
1. Add case to `FitnessGoal` enum
2. Update recommendation logic in `AICore`
3. Add emoji to `FitnessGoal.emoji`

## Performance Considerations

### Optimization Strategies
- Lazy data loading on dashboard
- Concurrent fetching with async/await
- Memory-efficient data structures
- Minimal re-renders with `@Published`

### Scalability
- Can handle years of health data
- Efficient querying with predicates
- Chunked data for large result sets

## Testing Strategy

### Unit Tests (Recommended)
- Test `AICore` analysis algorithms
- Test `UserProfile` computed properties
- Test data transformation logic

### Integration Tests
- Test HealthKit data fetching
- Test async operations
- Test UI state changes

### Manual Testing
- Test onboarding flow
- Test HealthKit permissions
- Test dashboard data loading
- Test on physical device

## Future Enhancements

### Technical Improvements
1. Core Data for offline caching
2. Charts framework integration
3. WidgetKit for home screen widgets
4. WatchKit for Apple Watch
5. ML models for enhanced predictions

### Features
1. Historical trends and graphs
2. Export health reports (PDF)
3. Social sharing (on-device)
4. Meal tracking integration
5. Water intake tracking
6. Exercise library
7. Challenges and goals

---

**Designed for**: iOS 26.0+ & iPadOS 26.0+ | Apple Intelligence | Privacy-First | On-Device AI | SwiftUI

