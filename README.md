# HealthAI - iOS Health Tracking App

A privacy-first health tracking app that uses HealthKit and Apple's Foundation Models Framework to provide personalized health insights.

## Features

- **User Profile Management**: Track name, age, gender, weight, height, and fitness goals
- **HealthKit Integration**: Read workouts, steps, heart rate, sleep, and calories
- **AI-Powered Insights**: On-device analysis using Apple Intelligence for progress tracking and recommendations
- **Beautiful UI**: SwiftUI interface with interactive charts
- **Privacy First**: All processing happens on-device

## Requirements

- **iOS 26.0+** and **iPadOS 26.0+** (Apple Intelligence support)
- **Xcode 18.0+** (latest development tools)
- **Swift 6.0+**
- **A17 chip or newer** (for full Apple Intelligence features)
- **Foundation Models Framework** (included with iOS 26+)

## Setup

1. Open `HealthAI.xcodeproj` in Xcode
2. Configure your Apple Developer Team
3. Enable HealthKit capability in Signing & Capabilities
4. Run on device with iOS 26.0+ or iPadOS 26.0+ and A17 chip (Apple Intelligence enabled)

## Apple Intelligence Integration

This app uses Apple's advanced on-device AI capabilities (iOS 26+ and iPadOS 26+) powered by the [Foundation Models Framework](https://developer.apple.com/documentation/foundationmodels) for:

- **Pattern Recognition**: Analyze your health trends and patterns
- **Predictive Insights**: Forecast progress and goal achievement
- **Personalized Plans**: Custom workout and nutrition recommendations
- **Smart Analysis**: Foundation Models Framework integration
- **Complete Privacy**: All AI processing happens locally on your device

Requires iOS 26.0+ or iPadOS 26.0+, and A17 chip or newer for full Apple Intelligence features.

## Privacy

All health data remains on your device. No external APIs or cloud services are used.

## App Capabilities

- HealthKit integration for reading health metrics
- Local storage for user preferences
- Apple Intelligence with Foundation Models Framework for analysis
- On-device AI processing

## Documentation

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup instructions
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [FEATURES.md](FEATURES.md) - Complete feature list
- [APPLE_INTELLIGENCE.md](APPLE_INTELLIGENCE.md) - AI features guide
- [FoundationModels_Integration.md](FoundationModels_Integration.md) - Framework integration

## References

- [Foundation Models Framework Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Apple Intelligence](https://www.apple.com/apple-intelligence/)
