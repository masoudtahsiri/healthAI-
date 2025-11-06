#!/bin/sh

# Xcode Cloud pre-build script
# This script runs before xcodebuild and sets up the API key from environment variables

set -e

echo "🔑 [CI] Setting up API key for Xcode Cloud build..."

# Check if GROQ_API_KEY environment variable is set
if [ -z "$GROQ_API_KEY" ]; then
    echo "⚠️  [CI] WARNING: GROQ_API_KEY environment variable is not set!"
    echo "   The app will build but API features may not work."
    echo "   Set GROQ_API_KEY in Xcode Cloud workflow settings."
else
    echo "✅ [CI] GROQ_API_KEY found (length: ${#GROQ_API_KEY} chars)"
    
    # Export for xcodebuild to use
    export GROQ_API_KEY
    
    # The key will be injected via INFOPLIST_KEY_GROQ_API_KEY = "$(GROQ_API_KEY)" in project settings
    echo "✅ [CI] API key will be injected into Info.plist during build"
fi

echo "✅ [CI] Pre-build script completed"

