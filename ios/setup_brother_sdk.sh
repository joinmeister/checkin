#!/bin/bash

# Brother SDK Manual Setup Script for xtool.sh
# This script helps set up the Brother SDK without CocoaPods

echo "🔧 Setting up Brother SDK for iOS with xtool.sh..."

# Create Frameworks directory
mkdir -p Frameworks

echo "📋 Brother SDK Setup Instructions:"
echo ""
echo "1. Download Brother SDK for iOS:"
echo "   - Visit: https://support.brother.com/g/s/es/dev/en/mobilesdk/ios/index.html"
echo "   - Register for a free Brother developer account"
echo "   - Download 'Brother Print SDK for iOS'"
echo "   - Extract the downloaded ZIP file"
echo ""
echo "2. Copy the framework:"
echo "   - Find BRPtouchPrinterKit.framework in the extracted files"
echo "   - Copy it to: $(pwd)/Frameworks/"
echo "   - Command: cp -R /path/to/BRPtouchPrinterKit.framework $(pwd)/Frameworks/"
echo ""
echo "3. Verify installation:"
echo "   - Run: ls -la $(pwd)/Frameworks/BRPtouchPrinterKit.framework/"
echo "   - You should see the framework structure"
echo ""
echo "4. Build with Flutter:"
echo "   - Run: flutter build ios --debug"
echo "   - Install with xtool: xtool install build/ios/iphoneos/Runner.app"
echo ""

# Check if framework already exists
if [ -d "Frameworks/BRPtouchPrinterKit.framework" ]; then
    echo "✅ BRPtouchPrinterKit.framework found!"
    echo "📱 You can now build the iOS app with: flutter build ios --debug"
else
    echo "⚠️  BRPtouchPrinterKit.framework not found."
    echo "📥 Please download and install the Brother SDK as described above."
fi

echo ""
echo "🔗 Alternative: Install CocoaPods and use pod install"
echo "   - The Podfile is configured but Brother SDK isn't in public repos"
echo "   - You'll still need to download the SDK manually"