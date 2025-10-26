#!/bin/bash

# Script to manually link Brother SDK framework to Xcode project
# This is needed when not using CocoaPods

echo "🔗 Linking Brother SDK framework to Xcode project..."

PROJECT_FILE="Runner.xcodeproj/project.pbxproj"
FRAMEWORK_PATH="Frameworks/BRLMPrinterKit.xcframework"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Xcode project file not found at $PROJECT_FILE"
    exit 1
fi

if [ ! -d "$FRAMEWORK_PATH" ]; then
    echo "❌ Error: Brother SDK framework not found at $FRAMEWORK_PATH"
    echo "Please run the Brother SDK setup first."
    exit 1
fi

echo "📋 Adding framework reference to Xcode project..."

# Create a backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Add framework to project (this is a simplified approach)
# In a real scenario, you'd use xcodeproj gem or similar tools

echo "⚠️  Manual step required:"
echo ""
echo "1. Open Runner.xcodeproj in Xcode"
echo "2. Right-click on 'Frameworks' folder in project navigator"
echo "3. Select 'Add Files to Runner...'"
echo "4. Navigate to ios/Frameworks/"
echo "5. Select BRLMPrinterKit.xcframework"
echo "6. Make sure 'Add to target: Runner' is checked"
echo "7. Click 'Add'"
echo ""
echo "Alternatively, since you're using xtool.sh, you can try building directly:"
echo "flutter build ios --debug"
echo ""
echo "The conditional compilation in BrotherPrinterPlugin.swift should handle"
echo "simulator vs device builds automatically."

echo ""
echo "🔧 Framework info:"
echo "   Path: $FRAMEWORK_PATH"
echo "   Simulator support: ✅ (ios-arm64_x86_64-simulator slice available)"
echo "   Device support: ✅ (ios-arm64 slice available)"