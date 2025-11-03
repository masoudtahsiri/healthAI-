# App Icon Troubleshooting Guide

If you can't see the app icon, try these steps:

## Quick Fixes

1. **Clean Build Folder**
   - In Xcode: Product → Clean Build Folder (Shift+Cmd+K)
   - Or run: `xcodebuild clean -project HealthAI.xcodeproj -scheme HealthAI`

2. **Delete Derived Data**
   - Xcode → Preferences → Locations → Derived Data → Delete folder
   - Or delete: `~/Library/Developer/Xcode/DerivedData/HealthAI-*`

3. **Restart Xcode**
   - Quit Xcode completely and reopen the project

4. **Rebuild the App**
   - Product → Build (Cmd+B)
   - Then run on simulator/device

5. **Check Asset Catalog in Xcode**
   - Open `Assets.xcassets` in Xcode
   - Click on `AppIcon`
   - You should see all icon sizes with previews
   - If any are blank/missing, the files might not be properly linked

## Verify Icon Files

All icons should be in:
```
HealthAI/Assets.xcassets/AppIcon.appiconset/
```

There should be 18 icon files total.

## Check Icon Preview

To preview the icon:
1. Open Xcode
2. Navigate to `Assets.xcassets` in Project Navigator
3. Click on `AppIcon`
4. You should see all icon sizes with previews

## If Still Not Working

1. **Re-add AppIcon to Project** (if needed):
   - In Xcode, right-click on `Assets.xcassets`
   - Select "New Image Set" or verify `AppIcon` exists
   - Ensure it's named exactly `AppIcon` (not `AppIcon.appiconset`)

2. **Check Build Settings**:
   - Target → Build Settings
   - Search for "Asset Catalog"
   - Ensure asset catalog compiler is enabled

3. **Verify Contents.json**:
   - Open `AppIcon.appiconset/Contents.json`
   - Ensure all filenames match actual files

4. **Test with a simple icon**:
   - Try replacing one icon file with a simple colored square
   - Rebuild and see if it appears

## Icon Design

Current icon features:
- Blue-to-teal gradient background
- White medical cross symbol
- AI circuit pattern (on larger icons)
- RGB format (no transparency)

The icon should be visible against light backgrounds. If you need a different design, the generation script can be modified.

