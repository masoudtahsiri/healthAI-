# API Key Setup Instructions

The API key is configured using build-time configuration via Info.plist.

## Current Setup

1. **Info.plist** has been created at `HealthAI/Info.plist` with the API key
2. **Code** has been updated to read from Info.plist first, then fallback to Keychain

## Next Steps (Required in Xcode)

You need to configure Xcode to use the custom Info.plist file:

### Option 1: Use Custom Info.plist (Recommended)

1. Open `HealthAI.xcodeproj` in Xcode
2. Select the **HealthAI** project in the navigator
3. Select the **HealthAI** target
4. Go to **Build Settings** tab
5. Search for `INFOPLIST_FILE`
6. Set it to: `HealthAI/Info.plist`
7. Search for `GENERATE_INFOPLIST_FILE`
8. Set it to: `NO`

### Option 2: Keep Auto-Generated Info.plist (Alternative)

If you prefer to keep auto-generation, you can:

1. In Xcode, go to **Build Settings**
2. Add a **User-Defined Setting**:
   - Click the `+` button → Add User-Defined Setting
   - Name: `GROQ_API_KEY`
   - Value: `YOUR_GROQ_API_KEY_HERE`
3. In **Info** tab, add a custom key:
   - Key: `GROQ_API_KEY`
   - Type: `String`
   - Value: `$(GROQ_API_KEY)`

## Verification

After setup, the app should automatically load the API key from Info.plist when built.

## Security Note

- The API key is in `Info.plist` (not in source code)
- `Info.plist` is currently in `.gitignore` (commented out)
- If you want to commit it to git, remove the comment from `.gitignore`
- The key will still be in the compiled binary (this is normal for client-side APIs)

