# HealthAI+ - User Flow Summary

The demo video has been attached.

## Initial App Launch

### 1. Splash Screen (20 seconds)

- App displays branded splash screen with logo and loading messages
- Shows "Powered by AI" branding
- Displays "Initializing AI Agent...." message
- Automatically transitions to onboarding (no user action needed)

### 2. Onboarding Process (First-time users only)

**Step 1: Welcome**

- User sees welcome message and taps "Get Started"

**Step 2: Name Entry**

- User enters First Name and Last Name (both required)
- Taps "Continue" to proceed

**Step 3: Health Data Sync & Review**

- App shows loading screen (5+ seconds)
- Requests HealthKit permission (optional)
- If HealthKit data available, auto-populates:
  - Date of Birth
  - Gender
  - Height
  - Weight
- User can review and edit all fields manually
- All fields are editable with sliders/pickers
- Taps "Continue" when ready

**Step 4: Goal Selection**

- User selects one or more fitness goals from grid
- Taps "Finish" to complete setup

### 3. Main Dashboard

- Profile is saved locally
- User lands on main dashboard
- Can start using the app features
- Pull-to-refresh available with improved loading indicators
- Cooldown messaging for refresh limits

## Subsequent Launches

- Splash screen appears (20 seconds)
- User goes directly to Dashboard
- Onboarding is skipped (already completed)

## Key Points

- **All data is editable**: Users can change any information at any time
- **One-time setup**: Onboarding only appears on first launch
- **Local storage**: All data stored on device, no cloud sync required
- **AI-powered insights**: Uses Apple Intelligence on supported devices, Groq AI on older devices

## Privacy & Requirements

**Privacy:**
- All data stored locally on device
- Apple Health read-only access
- On-device AI processing with Apple Intelligence (iOS 26.0+ on A17 Pro+ devices)
- Secure AI processing with Groq AI on older devices—data is not stored or tracked
- No external servers for data storage
- No tracking or data collection

**Requirements:**
- **Minimum**: iOS 17.6+ or iPadOS 17.6+
- **Full Apple Intelligence features**: iOS 26.0+ or iPadOS 26.0+ with A17 Pro chip or newer
- **Backward compatibility**: Older devices use Groq AI for AI-powered insights

