# Xcode Cloud Setup for API Key

## Overview

The API key is configured to work with Xcode Cloud CI/CD using environment variables. The key is **NOT** hardcoded in the source code.

## Setup Steps

### 1. Configure Xcode Cloud Environment Variable

1. Go to [Xcode Cloud Dashboard](https://appstoreconnect.apple.com/cloud)
2. Select your **Workflow**
3. Go to **Environment Variables** section
4. Click **+** to add a new variable:
   - **Name**: `GROQ_API_KEY`
   - **Value**: `YOUR_GROQ_API_KEY_HERE`
   - **Type**: Plain Text (or Secret if available)
5. Save the workflow

### 2. Local Development Setup

For local development, you have two options:

#### Option A: Xcode Build Settings (Recommended)

1. Open `HealthAI.xcodeproj` in Xcode
2. Select the **HealthAI** project
3. Select the **HealthAI** target
4. Go to **Build Settings** tab
5. Search for `GROQ_API_KEY`
6. If not found, add a **User-Defined Setting**:
   - Click `+` → Add User-Defined Setting
   - Name: `GROQ_API_KEY`
   - Value: `YOUR_GROQ_API_KEY_HERE`
7. The project is already configured to use `$(GROQ_API_KEY)` in `INFOPLIST_KEY_GROQ_API_KEY`

#### Option B: Keychain (Alternative)

You can also add the key to Keychain for local development:
- The app will automatically use it as a fallback

### 3. How It Works

1. **Xcode Cloud**: 
   - `ci_pre_xcodebuild.sh` reads `GROQ_API_KEY` environment variable
   - Xcode build settings use `$(GROQ_API_KEY)` to inject it into Info.plist
   - App reads from Info.plist at runtime

2. **Local Development**:
   - Xcode build settings use your local `GROQ_API_KEY` setting
   - Or falls back to Keychain if set

3. **Code Flow**:
   ```
   Info.plist → Environment Variable → Keychain → Empty (graceful failure)
   ```

## Verification

After setting up:

1. **Xcode Cloud**: Check build logs for:
   ```
   ✅ [CI] GROQ_API_KEY found (length: XX chars)
   ✅ [CI] API key will be injected into Info.plist during build
   ```

2. **Local**: Build and run - API features should work

## Security Notes

- ✅ API key is **NOT** in source code
- ✅ API key is **NOT** in git repository
- ✅ Xcode Cloud uses secure environment variables
- ⚠️  API key will be in the compiled binary (normal for client-side APIs)

## Troubleshooting

### Build fails with missing API key
- Check that `GROQ_API_KEY` is set in Xcode Cloud environment variables
- Verify the variable name matches exactly: `GROQ_API_KEY`

### Local build works but Xcode Cloud doesn't
- Ensure `ci_scripts/ci_pre_xcodebuild.sh` is executable (it is)
- Check Xcode Cloud build logs for errors
- Verify environment variable is set in workflow settings

### App runs but API features don't work
- Check console logs for: `⚠️ Groq API key not found`
- Verify the key is correctly set in build settings or environment

