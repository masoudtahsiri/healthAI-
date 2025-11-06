# HealthAI - iOS Health Tracking App

A privacy-first health tracking app that uses HealthKit and Apple's Foundation Models Framework to provide personalized health insights.

## Features

- **User Profile Management**: Track name, age, gender, weight, height, and fitness goals
- **HealthKit Integration**: Read workouts, steps, heart rate, sleep, and calories
- **AI-Powered Insights**: On-device analysis using Apple Intelligence (iOS 26.0+) or Groq API fallback
- **Beautiful UI**: SwiftUI interface with interactive charts
- **Privacy-Focused**: On-device processing when possible, transparent third-party usage when needed

## Requirements

- **iOS 17.6+** and **iPadOS 17.6+** (minimum deployment target)
- **Xcode 18.0+** (latest development tools)
- **Swift 6.0+**
- **A17 chip or newer** (for Apple Intelligence features on iOS 26.0+)
- **Foundation Models Framework** (included with iOS 26+, optional - app falls back to Groq API)

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

HealthAI prioritizes your privacy while providing AI-powered insights:

- **Apple Intelligence (iOS 26.0+)**: On supported devices (A17 Pro+), all AI processing happens entirely on-device using Apple's Foundation Models Framework - no data leaves your device
- **Groq API Fallback**: On older devices or iOS versions, the app uses Groq API for AI analysis. Health data is sent to Groq's servers to generate insights, but is not stored or used for tracking
- **No Tracking**: HealthAI does not track users across apps or websites
- **Local Storage**: All health data is stored locally on your device

For detailed privacy information, see our [Privacy Policy](PRIVACY.md).

## App Capabilities

- HealthKit integration for reading health metrics
- Local storage for user preferences and cached data
- Apple Intelligence with Foundation Models Framework for on-device AI (iOS 26.0+ with A17 Pro+)
- Groq API integration for AI insights on older devices
- Smart caching to minimize API calls and preserve privacy

## Documentation

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup instructions
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [FEATURES.md](FEATURES.md) - Complete feature list
- [APPLE_INTELLIGENCE.md](APPLE_INTELLIGENCE.md) - AI features guide
- [FoundationModels_Integration.md](FoundationModels_Integration.md) - Framework integration

## References

- [Foundation Models Framework Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Apple Intelligence](https://www.apple.com/apple-intelligence/)
