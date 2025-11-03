# HealthAI Setup Guide

## Overview

HealthAI is an iOS health tracking app that uses HealthKit for data collection and on-device AI for personalized health insights.

## Project Structure

```
HealthAI/
├── HealthAIApp.swift          # App entry point
├── ContentView.swift          # Main view coordinator
├── Models/
│   └── UserProfile.swift      # User data models
├── Managers/
│   ├── HealthKitManager.swift # HealthKit integration
│   └── AICore.swift           # AI analysis engine
├── Views/
│   ├── OnboardingView.swift   # User onboarding flow
│   └── DashboardView.swift    # Main dashboard with insights
└── HealthAI.entitlements      # HealthKit permissions

```

## Features

### 1. User Onboarding
- Collects: name, age, gender, weight, height, fitness goals
- Beautiful gradient UI with step-by-step flow
- Saves profile to UserDefaults

### 2. HealthKit Integration
Reads health data including:
- Weight tracking
- Workouts (duration, type, calories)
- Steps count
- Active calories burned
- Heart rate
- Sleep analysis

### 3. AI-Powered Insights
On-device analysis provides:
- **Progress Score**: Overall fitness progress (0-100)
- **Body Composition Estimates**: Fat loss and muscle gain projections
- **Personalized Recommendations**: Based on goal and activity level
- **Weekly Summaries**: Steps, calories, heart rate, workouts

### 4. Dashboard
- Circular progress indicator
- Weekly statistics cards
- Body composition tracking
- AI recommendations list

## Setup Instructions

### 1. Open Project in Xcode
```bash
open HealthAI.xcodeproj
```

### 2. Configure Signing
1. Select the HealthAI target
2. Go to "Signing & Capabilities"
3. Enable "Automatically manage signing"
4. Select your Apple Developer Team

### 3. Enable HealthKit
The HealthKit capability should already be configured in:
- `HealthAI.entitlements`
- Target Capabilities in Xcode

Verify it's added:
1. Select target → Signing & Capabilities
2. Click "+ Capability"
3. Add "HealthKit" if not already added

### 4. Info.plist Permissions
Privacy descriptions are already configured in `project.pbxproj`:
- `NSHealthShareUsageDescription`: "We need access to your health data to provide personalized insights."
- `NSHealthUpdateUsageDescription`: "We'll save your fitness goals and progress to HealthKit."

### 5. Build and Run
- **Minimum iOS Version**: iOS 26.0
- **Minimum iPadOS Version**: iPadOS 26.0
- **Swift Version**: 6.0+
- **Xcode**: 18.0+
- **Hardware**: A17 chip or newer for Apple Intelligence

## Testing

### On Simulator
- Limited health data available
- Use simulator settings to simulate health data:
  1. Settings → Health → Health Data
  2. Add sample data for testing

### On Device
- Full HealthKit access
- Real workout data from Apple Watch, iPhone, etc.
- Best experience with Apple Watch

## Privacy

- **All processing on-device**: No external APIs
- **Health data stays local**: Never sent to cloud
- **UserDefaults only**: Profile data stored locally
- **HealthKit privacy**: Uses iOS privacy controls

## Architecture

### Data Flow
1. User completes onboarding → Profile saved
2. App requests HealthKit authorization
3. Dashboard loads → Fetches health data
4. AI Core analyzes → Generates insights
5. Dashboard displays → Beautiful UI updates

### Key Classes
- `AppState`: Global app state management
- `HealthKitManager`: Handles all HealthKit operations
- `AICore`: On-device AI analysis engine
- `UserProfile`: User data model

## Customization

### Modify AI Analysis
Edit `AICore.swift`:
- Adjust progress scoring algorithm
- Change body composition estimation
- Update recommendation logic

### UI Customization
Edit view files:
- `OnboardingView.swift`: Onboarding flow
- `DashboardView.swift`: Dashboard layout
- `ContentView.swift`: Navigation structure

### Goals & Metrics
Edit `UserProfile.swift`:
- Add new fitness goals
- Modify BMI calculation
- Add new user metrics

## Future Enhancements

Potential features to add:
1. Charts visualization (integrate Charts framework)
2. Historical trend analysis
3. Meal tracking integration
4. Water intake tracking
5. Export health reports (PDF)
6. Widget for home screen
7. Watch companion app
8. Social sharing (on-device only)

## Troubleshooting

### HealthKit Authorization Issues
- Check entitlements file
- Verify Info.plist privacy descriptions
- Ensure you're running on device (simulator has limitations)

### No Data Showing
- Grant HealthKit permissions when prompted
- Check if health data exists in Health app
- Some data requires Apple Watch (heart rate, etc.)

### Build Errors
- Clean build folder: Cmd+Shift+K
- Reset derived data
- Ensure minimum iOS version is set correctly

## Support

For issues or questions:
1. Check that HealthKit capability is enabled
2. Verify iOS version compatibility
3. Test on physical device for full functionality

---

Built with ❤️ using SwiftUI and HealthKit

