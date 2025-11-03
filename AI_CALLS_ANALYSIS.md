# AI Calls Analysis

## Overview
This document outlines all AI/Foundation Models API calls made in the HealthAI app, their sequence, timing, and operation titles.

## Total AI Calls Per Dashboard Load

**Total: 4-5 AI calls** (depending on retries)

**Note**: Recommendations are NOT a separate AI call - they're extracted from the "pattern analysis" call!

### Call Sequence & Flow

```
Dashboard Load → loadDataFromCache()
    │
    ├─→ 1. generateEfficiencyInsight() [SEQUENTIAL]
    │   └─→ Internal: "efficiency insight" (operation title)
    │   └─→ May retry: "efficiency insight retry" (up to 2 retries)
    │
    └─→ 2. analyzeWithAppleIntelligence() [SEQUENTIAL]
        │
        ├─→ 2a. analyzeWithFoundationModels()
        │   └─→ Internal: "pattern analysis" (operation title)
        │
        └─→ 2b. generateFoundationModelPredictions()
            └─→ Internal: "predictions" (operation title)
            └─→ Uses a FRESH session (new LanguageModelSession)
    
    └─→ 3. calculateDesiredWeight() [SEQUENTIAL]
        └─→ Internal: "desired weight" (operation title)
    
    └─→ 4. getProgressPredictions() [SEQUENTIAL]
        └─→ Internal: "body composition assessment" (operation title)
        └─→ Uses a NEW session (LanguageModelSession created in DashboardView)
```

## Detailed Call Breakdown

### 1. Efficiency Insight Call
- **Function**: `generateEfficiencyInsight()`
- **Operation Title**: `"efficiency insight"`
- **When**: Called during pattern analysis (early in load sequence)
- **Location**: `DashboardView.swift:350`
- **Retries**: Yes, up to 2 retries if invalid response
  - Retry operation title: `"efficiency insight retry"`
- **Session Used**: Main `AppleIntelligence.session`
- **Purpose**: Generate categorized efficiency insights (overall, improvements, what's working)

### 2a. Pattern Analysis Call (INCLUDES RECOMMENDATIONS)
- **Function**: `analyzeWithFoundationModels()`
- **Operation Title**: `"pattern analysis"`
- **When**: Called inside `analyzeWithAppleIntelligence()`
- **Location**: `AppleIntelligence.swift:312`
- **Retries**: No
- **Session Used**: Main `AppleIntelligence.session`
- **Purpose**: AI-powered health pattern analysis **AND generates recommendations**
- **Recommendations Generated**: 
  - Daily protein (grams)
  - Daily water (liters)
  - Workout adjustments
  - Daily calories needed
  - Macro breakdown (protein/carbs/fat %)
  - Sleep optimization
  - Progress summary with actionable changes
- **How Recommendations Are Used**:
  - Parsed from AI response in `parseFoundationModelInsights()` (line 875)
  - Extracted in `generateRecommendationsFromAI()` (line 840 in DashboardView)
  - Displayed in `RecommendationsCard` component

### 2b. Predictions Call
- **Function**: `generateFoundationModelPredictions()`
- **Operation Title**: `"predictions"`
- **When**: Called inside `analyzeWithAppleIntelligence()`
- **Location**: `AppleIntelligence.swift:324`
- **Retries**: No
- **Session Used**: **FRESH session** (new `LanguageModelSession` created internally)
- **Purpose**: Generate 30-day weight projections, goal timeline, performance forecasts

### 3. Desired Weight Call
- **Function**: `calculateDesiredWeight()`
- **Operation Title**: `"desired weight"`
- **When**: Called after `analyzeWithAppleIntelligence()`
- **Location**: `DashboardView.swift:510`
- **Retries**: No
- **Session Used**: Main `AppleIntelligence.session`
- **Purpose**: Calculate ideal weight based on goals, height, age, activity level

### 4. Body Composition Assessment Call
- **Function**: `getProgressPredictions()`
- **Operation Title**: `"body composition assessment"`
- **When**: Called after desired weight calculation
- **Location**: `DashboardView.swift:519`
- **Retries**: No
- **Session Used**: **NEW session** (created in DashboardView line 518)
- **Purpose**: Assess timeline to goal, warnings, and dimension scores (body composition, activity, recovery, goal progress)

## Session Usage

### Sessions Created:
1. **Main Session**: Created once in `AppleIntelligence.init()` - used for most calls
2. **Fresh Session (Predictions)**: Created in `generateFoundationModelPredictions()` - line 775
3. **New Session (Assessment)**: Created in `DashboardView.loadDataFromCache()` - line 518

### Why Multiple Sessions?
- **Predictions call** uses a fresh session to avoid context window issues
- **Assessment call** uses a separate session because it's passed as a parameter from DashboardView

## Call Timing & Concurrency

### ⚠️ **All Calls Are SEQUENTIAL (Not Concurrent)**

The calls happen **one after another** using `await`:

```swift
// 1. First call (pattern insights)
var categorizedInsights = await appleAI.generateEfficiencyInsight(...)

// 2. Second call (main analysis)
let aiInsight = await appleAI.analyzeWithAppleIntelligence(...)
    ├─ await analyzeWithFoundationModels(...)      // 2a
    └─ await generateFoundationModelPredictions(...) // 2b

// 3. Third call (desired weight)
let desiredWeight = await appleAI.calculateDesiredWeight(...)

// 4. Fourth call (progress predictions)
let predictions = await appleAI.getProgressPredictions(...)
```

### Safety Mechanism
All calls use `safeRespond()` helper which:
- Checks `session.isResponding` before making a call
- Waits up to 5 seconds if session is busy
- Prevents concurrent calls to the same session

## Operation Titles Summary

| # | Operation Title | Function | Session | Includes Recommendations? |
|---|----------------|----------|---------|---------------------------|
| 1 | `"efficiency insight"` | `generateEfficiencyInsight()` | Main | ❌ No (efficiency insights only) |
| 1b | `"efficiency insight retry"` | (retry) | Main | ❌ No |
| 2a | `"pattern analysis"` | `analyzeWithFoundationModels()` | Main | ✅ **YES - This generates recommendations!** |
| 2b | `"predictions"` | `generateFoundationModelPredictions()` | Fresh | ❌ No |
| 3 | `"desired weight"` | `calculateDesiredWeight()` | Main | ❌ No |
| 4 | `"body composition assessment"` | `getProgressPredictions()` | New | ❌ No |

## How Recommendations Work

### ❌ **NOT a Separate AI Call**

Recommendations are **extracted** from the existing "pattern analysis" AI call:

1. **AI Call**: `"pattern analysis"` includes in its prompt (lines 764-771):
   ```
   Provide concise recommendations:
   1. Daily protein (grams)
   2. Daily water (liters)
   3. Workout adjustments
   4. Daily calories needed
   5. Macro breakdown (protein/carbs/fat %)
   6. Sleep optimization
   7. Progress summary with actionable changes
   ```

2. **Parsing**: The AI response is parsed in `parseFoundationModelInsights()` (line 875):
   - Looks for protein/water/calorie recommendations
   - Extracts numbered or bulleted lists
   - Populates `improvementAreas` array

3. **Extraction**: `generateRecommendationsFromAI()` (line 840) extracts:
   - `insight.insights.improvementAreas` ← From AI response
   - `insight.insights.optimalTiming` ← From AI response
   - `insight.predictions.performanceForecast` ← From predictions call
   - `insight.personalizedPlan.dailyTargets` ← Calculated values

4. **Display**: Shown in `RecommendationsCard` component

### Recommendation Sources:
- **AI-Generated**: From "pattern analysis" call (protein, water, workouts, calories, macros, sleep)
- **AI-Generated**: From "predictions" call (performance forecast)
- **Calculated**: Daily targets (steps, calories) from personalized plan

## Potential Issues

1. **Sequential Bottleneck**: All 4-5 calls happen sequentially, which can be slow
2. **Multiple Sessions**: 3 different sessions are used, which might cause confusion
3. **No Concurrent Calls**: Calls could potentially be parallelized for faster loading
4. **Recommendations Mixed**: Recommendations come from multiple sources (pattern analysis + predictions), which may be confusing

## Recommendations

1. **Consider Parallel Calls**: Calls 2, 3, and 4 could potentially run concurrently if they use different sessions
2. **Session Management**: Consider using a session pool or clarifying which calls need separate sessions
3. **Caching**: Some calls (like desired weight) could be cached and reused if user profile hasn't changed

