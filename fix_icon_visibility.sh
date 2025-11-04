#!/bin/bash

echo "🔧 Fixing App Icon Visibility Issues"
echo "===================================="
echo ""

PROJECT_DIR="/Users/masoudtahsiri/health"
cd "$PROJECT_DIR"

echo "Step 1: Cleaning build artifacts..."
xcodebuild clean -project HealthAI.xcodeproj -scheme HealthAI > /dev/null 2>&1
echo "✓ Cleaned build folder"

echo ""
echo "Step 2: Clearing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/HealthAI-* 2>/dev/null
echo "✓ Cleared derived data"

echo ""
echo "Step 3: Updating asset catalog timestamp..."
touch "HealthAI/Assets.xcassets/AppIcon.appiconset/Contents.json"
touch "HealthAI/Assets.xcassets/Contents.json"
echo "✓ Asset catalog updated"

echo ""
echo "Step 4: Verifying icon files..."
ICON_COUNT=$(ls -1 "HealthAI/Assets.xcassets/AppIcon.appiconset/"*.png 2>/dev/null | wc -l | tr -d ' ')
echo "  Found $ICON_COUNT icon files"

if [ "$ICON_COUNT" -ge "18" ]; then
    echo "✓ All icon files present"
else
    echo "⚠ Warning: Expected 18 icon files, found $ICON_COUNT"
fi

echo ""
echo "Step 5: Checking Contents.json..."
if [ -f "HealthAI/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
    echo "✓ Contents.json exists"
    JSON_ENTRIES=$(python3 -c "import json; f=open('HealthAI/Assets.xcassets/AppIcon.appiconset/Contents.json'); d=json.load(f); print(len(d['images']))" 2>/dev/null)
    echo "  Found $JSON_ENTRIES icon entries in Contents.json"
else
    echo "✗ Contents.json missing!"
fi

echo ""
echo "===================================="
echo "✅ Cleanup complete!"
echo ""
echo "Next steps in Xcode:"
echo "1. Close Xcode completely (Cmd+Q)"
echo "2. Reopen the project"
echo "3. Product → Clean Build Folder (Shift+Cmd+K)"
echo "4. Delete the app from simulator/device (long-press → delete)"
echo "5. Product → Build (Cmd+B)"
echo "6. Product → Run (Cmd+R)"
echo ""
echo "If icons still don't appear:"
echo "- Check Assets.xcassets → AppIcon in Xcode Project Navigator"
echo "- Verify all icon slots show previews (not blank)"
echo "- Try restarting your Mac if persistent"



