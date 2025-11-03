# Quick Start Guide

Get HealthAI up and running in 5 minutes!

## Prerequisites

- Mac with Xcode 18.0+
- iOS 26.0+ or iPadOS 26.0+ device with A17 chip or newer
- Apple Developer account (for device deployment)
- Requires Apple Intelligence capable hardware

## Installation

1. **Open the project**
   ```bash
   open HealthAI.xcodeproj
   ```

2. **Select your team** (in Xcode)
   - Select target "HealthAI"
   - Go to "Signing & Capabilities"
   - Enable "Automatically manage signing"
   - Select your Apple Developer Team

3. **Connect your device**
   - Plug in iPhone/iPad via USB
   - Select device from Xcode toolbar
   - Or use simulator (limited HealthKit data)

4. **Build and run**
   - Press ⌘R or click Run button
   - Wait for app to install and launch

## First Launch

1. **Welcome screen** - Click "Get Started"
2. **Enter your info** - Name, age, gender
3. **Set your stats** - Use sliders for weight/height
4. **Choose your goal** - Pick a fitness goal
5. **Grant permissions** - Allow HealthKit access
6. **View dashboard** - See your AI insights!

## Using the App

### Onboarding
- Complete all 4 steps
- Profile is saved automatically
- Can skip and complete later

### Dashboard
- View overall progress score
- See weekly statistics
- Check body composition estimates
- Read AI recommendations
- Tap run icon to refresh data

### Health Data
The app reads from Apple Health:
- **Steps**: From iPhone or Apple Watch
- **Calories**: Active energy burned
- **Workouts**: All workout types
- **Heart rate**: From Apple Watch
- **Sleep**: From Apple Watch

## Troubleshooting

### "No Health Data"
- Open Apple Health app
- Add some sample data for testing
- Or wait for Health app to collect data naturally

### "Permission Denied"
- Go to Settings → Health → Data Access
- Enable "HealthAI" access to health data
- Restart the app

### "Build Failed"
- Clean build folder: ⌘⇧K
- Restart Xcode
- Check iOS deployment target is 26.0+ (iPadOS 26.0+)
- Verify device supports Apple Intelligence (A17+)

### "Simulator Has No Data"
- Simulator has limited health data
- Use a physical device for full functionality
- Or manually add data in Health app

## Tips

### For Best Results
1. **Use with Apple Watch** - More accurate data
2. **Wear watch while sleeping** - Heart rate data
3. **Track workouts** - Start workouts in Workout app
4. **Update weight regularly** - Better body composition estimates

### Testing
- Add sample data in Health app settings
- Test with different fitness goals
- Check insights update after new workouts

## Next Steps

After setup:
- Review SETUP_GUIDE.md for detailed configuration
- Read ARCHITECTURE.md to understand the system
- Check FEATURES.md for all capabilities
- Customize AI analysis in AICore.swift
- Modify UI in view files

## Support

Common issues:
1. **Not seeing data** - Check HealthKit permissions
2. **Progress score low** - Exercise more to see improvement
3. **No recommendations** - Profile completed correctly?

For more details, see README.md or other documentation files.

---

**Enjoy your AI-powered health journey! 💪❤️**

