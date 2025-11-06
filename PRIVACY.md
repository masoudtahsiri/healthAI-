# HealthAI Privacy Policy

**Last Updated: November 6, 2025**

## Overview

HealthAI is committed to protecting your privacy. This policy explains how we handle your health data and what information is shared with third-party services.

## Data Collection

### Health Data from HealthKit

HealthAI reads the following types of health data from Apple HealthKit:

- Workouts (type, duration, calories burned)
- Steps and activity data
- Heart rate and heart rate recovery
- Sleep data
- Active and basal calories
- Distance traveled
- Body composition data (if available)

**All health data is stored locally on your device.** We do not upload your health data to our servers.

## Third-Party Services

### Groq API

On devices that don't support Apple Intelligence (iOS 26.0+ with A17 Pro+ chip), HealthAI uses Groq API to generate AI-powered health insights and recommendations.

**What data is sent to Groq:**
- Aggregated health metrics (workout efficiency, steps, calories, heart rate patterns)
- Your fitness goals and profile information (age, gender, weight, height)
- Time range context (e.g., "This Week", "Last Month")

**What Groq does with your data:**
- Processes the data to generate personalized health insights
- Does NOT store your data permanently
- Does NOT use your data for training or tracking
- Does NOT share your data with third parties

**Data Security:**
- All communication with Groq API is encrypted (HTTPS)
- Your API key is securely stored and never exposed to users

### Apple Intelligence (iOS 26.0+)

On supported devices (iPhone 15 Pro or newer with iOS 26.0+), HealthAI uses Apple's Foundation Models Framework for on-device AI processing.

**When using Apple Intelligence:**
- **No data leaves your device** - all AI processing happens locally
- **Complete privacy** - your health data never reaches external servers
- **No internet connection required** for AI features

## Data Storage

### Local Storage

All health data and user preferences are stored locally on your device:
- HealthKit data remains in Apple HealthKit
- User profile and preferences stored in UserDefaults
- AI-generated insights cached locally for performance

### No Cloud Storage

HealthAI does not:
- Upload your health data to cloud servers
- Sync data across devices
- Store data on external servers

## Data Sharing

HealthAI does NOT:
- Sell your data to third parties
- Share your data with advertisers
- Use your data for tracking across apps or websites
- Store your health data on external servers

## Third-Party Domains

The app communicates with the following third-party domain:
- **api.groq.com** - Used only for AI insight generation (on devices without Apple Intelligence)

## Your Rights

You have full control over your data:
- **Delete Data**: Uninstall the app to remove all local data
- **HealthKit Permissions**: Manage HealthKit permissions in iOS Settings
- **No Account Required**: HealthAI doesn't require an account or login

## Children's Privacy

HealthAI is not intended for children under 13. We do not knowingly collect data from children.

## Changes to This Policy

We may update this privacy policy from time to time. The "Last Updated" date at the top indicates when changes were made.

## Contact

For questions about this privacy policy, please contact us through the app or visit our GitHub repository.

## Compliance

This privacy policy complies with:
- Apple's App Store privacy requirements
- iOS Privacy Manifest specifications
- GDPR principles (for EU users)

---

**Note**: This privacy policy reflects the current implementation of HealthAI. The app uses Groq API as a fallback when Apple Intelligence is not available, and all health data processing is done to provide you with personalized health insights.

