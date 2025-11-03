# Apple Intelligence Logging Guide

## Overview

The `AppleIntelligence` class now includes comprehensive logging using Apple's `OSLog` framework. This allows you to monitor and debug AI operations in real-time.

## What's Being Logged

### 1. Initialization Logs
```swift
logger.info("Initializing Apple Intelligence with Foundation Models")
logger.info("ModelProvider initialized successfully")
```

### 2. Analysis Start
```swift
logger.info("Starting AI analysis for profile: \(profile.name)")
logger.debug("User goal: \(profile.fitnessGoal)")
logger.debug("Average steps: \(steps), Calories: \(calories)")
```

### 3. Foundation Models Status
```swift
logger.info("Foundation Models available - using AI-powered analysis")
// OR
logger.warning("Foundation Models not available - using rule-based fallback")
```

### 4. Processing Steps
```swift
logger.debug("Basic pattern analysis completed")
logger.debug("Starting Foundation Models pattern analysis")
logger.debug("Prompt prepared for Foundation Models (length: \(count) chars)")
```

### 5. Completion & Performance
```swift
logger.info("AI analysis completed in 0.52s")
```

## Log Levels

### Info Level (`.info`)
- Major operations: initialization, analysis start/end
- Overall flow tracking
- Performance metrics

### Debug Level (`.debug`)
- Detailed operation steps
- Data values
- Intermediate states
- Prompt details

### Warning Level (`.warning`)
- Fallback scenarios
- Missing features
- Degraded functionality

### Error Level (`.error`)
- Failed operations
- Exceptions
- Critical issues

## How to View Logs

### Method 1: Console.app (macOS)

1. **Open Console.app** (Applications > Utilities)
2. **Select your device** in the sidebar
3. **Search for "HealthAI"** or filter by `subsystem:com.healthai.app`
4. **Filter by category**: `category:AppleIntelligence`

### Method 2: Xcode Console

1. **Run your app** in Xcode
2. **View the Debug Console** (Cmd + Shift + Y)
3. **Filter logs**: Type `AppleIntelligence` in the filter box
4. **See real-time logs** as the app runs

### Method 3: Terminal (Command Line)

```bash
# Stream logs for your device
log stream --predicate 'subsystem == "com.healthai.app"' --level=info

# Show only AppleIntelligence logs
log stream --predicate 'subsystem == "com.healthai.app" AND category == "AppleIntelligence"'

# Filter for specific level
log stream --predicate 'subsystem == "com.healthai.app" AND level >= warning'
```

### Method 4: iOS Device (Export Logs)

1. **Settings** → **Privacy & Security** → **Analytics & Improvements**
2. **Analytics Data** → Search for `HealthAI`
3. **Tap the log file** → Share
4. **Open on Mac** in Console.app

## Example Log Output

```
[2024-01-15 10:30:15] INFO  AppleIntelligence: Initializing Apple Intelligence with Foundation Models
[2024-01-15 10:30:15] INFO  AppleIntelligence: ModelProvider initialized successfully
[2024-01-15 10:30:20] INFO  AppleIntelligence: Starting AI analysis for profile: John
[2024-01-15 10:30:20] DEBUG AppleIntelligence: User goal: Lose Weight
[2024-01-15 10:30:20] DEBUG AppleIntelligence: Average steps: 7500, Calories: 450
[2024-01-15 10:30:20] DEBUG AppleIntelligence: Basic pattern analysis completed
[2024-01-15 10:30:21] INFO  AppleIntelligence: Foundation Models available - using AI-powered analysis
[2024-01-15 10:30:21] DEBUG AppleIntelligence: Starting Foundation Models pattern analysis
[2024-01-15 10:30:21] DEBUG AppleIntelligence: Prompt prepared for Foundation Models (length: 234 chars)
[2024-01-15 10:30:22] DEBUG AppleIntelligence: Foundation Models response received
[2024-01-15 10:30:22] DEBUG AppleIntelligence: Parsed insights successfully
[2024-01-15 10:30:22] INFO  AppleIntelligence: Foundation Models analysis completed
[2024-01-15 10:30:22] INFO  AppleIntelligence: AI analysis completed in 2.34s
```

## Privacy-Aware Logging

The logging system uses privacy-aware string interpolation:

```swift
// ✅ Private data is masked automatically
logger.info("Starting AI analysis for profile: \(profile.name, privacy: .public)")

// Data is replaced with "<private>" in logs
// Output: "Starting AI analysis for profile: <private>"
```

**Personal data is automatically masked** unless explicitly marked as `.public`.

## Debugging Specific Issues

### AI Not Using Foundation Models?

Check for this log:
```
WARNING: Foundation Models not available - using rule-based fallback
```

**Why this happens:**
- Framework not linked in Xcode
- Running on simulator without Foundation Models
- iOS version < 26.0

### Slow Performance?

Check duration logs:
```
INFO: AI analysis completed in 15.67s
```

If analysis takes > 10 seconds:
- Check Foundation Models API implementation
- Verify prompt size
- Consider optimization

### Missing Data?

Check debug logs for input values:
```
DEBUG: Average steps: 5000, Calories: 350
```

Verify HealthKit data is being read correctly.

## Adding Custom Logs

To add your own logging:

```swift
import OSLog

class YourClass {
    private let logger = Logger(subsystem: "com.healthai.app", category: "YourCategory")
    
    func yourMethod() {
        logger.info("Important event happened")
        logger.debug("Value: \(someValue)")
        logger.error("Something went wrong: \(error.localizedDescription)")
    }
}
```

## Log Retention

- **Device logs**: Retained for several days
- **Archived logs**: Available in Console.app indefinitely
- **Privacy**: All personal data is masked by default

## Performance Considerations

### Logging Overhead
- **Production**: Only `.info` and `.error` levels
- **Debug**: All levels enabled
- **Zero overhead** when device is not connected

### Disable Logging in Production

```swift
#if DEBUG
    logger.debug("Detailed debug info")
#endif
```

## Best Practices

1. **Use appropriate log levels**
   - `.info` for high-level flow
   - `.debug` for detailed debugging
   - `.warning` for unusual but recoverable states
   - `.error` for failures

2. **Include context**
   ```swift
   logger.info("Analysis started for goal: \(goal.rawValue)")
   ```

3. **Measure performance**
   ```swift
   let startTime = Date()
   // ... operation ...
   let duration = Date().timeIntervalSince(startTime)
   logger.info("Operation completed in \(duration)s")
   ```

4. **Don't log sensitive data**
   ```swift
   // ❌ Bad
   logger.debug("User's weight: \(userWeight)")
   
   // ✅ Good (privacy-aware)
   logger.debug("User's weight: \(userWeight, privacy: .private)")
   ```

## Troubleshooting

### No Logs Appearing?

1. Check you're running on a **connected device**
2. Verify **Console.app** is filtering correctly
3. Ensure **subsystem** matches: `com.healthai.app`
4. Check log level settings

### Too Many Logs?

Filter by category:
```
category:AppleIntelligence AND level:info
```

### Want More Detail?

Lower log level in Console.app:
```
Level: All
```

## Integration with Other Tools

### Exporting Logs
- **Console.app** → Select logs → File → Export
- Save as `.logarchive` for analysis

### Analyzing Performance
- Search for: `AI analysis completed in`
- Calculate average processing time
- Identify slow operations

### Monitoring Errors
- Filter by: `level:error`
- Track error frequency
- Identify problematic patterns

## Resources

- [OSLog Documentation](https://developer.apple.com/documentation/os/oslog)
- [Console.app Guide](https://developer.apple.com/documentation/os/logging)
- [Privacy in Logging](https://developer.apple.com/documentation/os/oslogprivacymask)

---

**Subsystem:** `com.healthai.app`  
**Category:** `AppleIntelligence`  
**Enabled:** ✅ In Debug & Release builds


