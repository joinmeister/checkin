#!/bin/bash

# Brother SDK Setup Script for Flutter Event Check-in App
# This script helps set up the Brother SDK for both Android and iOS

set -e

echo "🔧 Brother SDK Setup Script"
echo "=========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "Please run this script from the Flutter project root directory"
    exit 1
fi

print_status "Setting up Brother SDK for Flutter Event Check-in App..."

# Step 1: Check for Brother SDK JAR file
print_status "Checking Android Brother SDK..."
if [ -f "android/app/libs/BrotherPrintLibrary.jar" ]; then
    print_success "Brother SDK JAR file found"
else
    print_warning "Brother SDK JAR file not found"
    echo "Please download BrotherPrintLibrary.jar from:"
    echo "https://support.brother.com/g/s/es/dev/en/mobilesdk/android/index.html"
    echo "And place it in: android/app/libs/"
    echo ""
    echo "The setup will continue, but Android builds will fail until the JAR is added."
fi

# Step 2: Flutter dependencies
print_status "Installing Flutter dependencies..."
flutter pub get
if [ $? -eq 0 ]; then
    print_success "Flutter dependencies installed"
else
    print_error "Failed to install Flutter dependencies"
    exit 1
fi

# Step 3: iOS CocoaPods setup
print_status "Setting up iOS CocoaPods..."
if command -v pod &> /dev/null; then
    cd ios
    print_status "Updating CocoaPods repository..."
    pod repo update --silent
    
    print_status "Installing iOS dependencies..."
    pod install
    
    if [ $? -eq 0 ]; then
        print_success "iOS dependencies installed successfully"
        
        # Check if Brother SDK was installed
        if [ -d "Pods/BRPtouchPrinterKit" ]; then
            print_success "Brother iOS SDK (BRPtouchPrinterKit) installed"
        else
            print_warning "Brother iOS SDK not found in Pods"
        fi
    else
        print_error "Failed to install iOS dependencies"
        cd ..
        exit 1
    fi
    cd ..
else
    print_warning "CocoaPods not found. Please install it first:"
    echo "sudo gem install cocoapods"
fi

# Step 4: Generate Hive adapters
print_status "Generating Hive type adapters..."
flutter packages pub run build_runner build --delete-conflicting-outputs
if [ $? -eq 0 ]; then
    print_success "Hive adapters generated"
else
    print_warning "Failed to generate Hive adapters (this may be normal if models aren't ready)"
fi

# Step 5: Verify permissions
print_status "Verifying Android permissions..."
if grep -q "android.permission.BLUETOOTH" android/app/src/main/AndroidManifest.xml; then
    print_success "Android Bluetooth permissions configured"
else
    print_error "Android Bluetooth permissions missing"
fi

print_status "Verifying iOS permissions..."
if grep -q "NSBluetoothAlwaysUsageDescription" ios/Runner/Info.plist; then
    print_success "iOS Bluetooth permissions configured"
else
    print_error "iOS Bluetooth permissions missing"
fi

# Step 6: Check MFi configuration
print_status "Checking iOS MFi configuration..."
if grep -q "com.brother.ptcbp" ios/Runner/Info.plist; then
    print_success "iOS MFi protocols configured"
else
    print_error "iOS MFi protocols missing"
fi

# Step 7: Clean and prepare for build
print_status "Cleaning project..."
flutter clean

print_success "Brother SDK setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. If you haven't already, download BrotherPrintLibrary.jar and place it in android/app/libs/"
echo "2. Connect a Brother printer (QL-820NWB, QL-1110NWB, etc.)"
echo "3. Run the app on a physical device: flutter run"
echo "4. Navigate to Brother Printer Setup to test the integration"
echo ""
echo "📱 Supported Printers:"
echo "   • QL-820NWB (Bluetooth/WiFi)"
echo "   • QL-1110NWB (Bluetooth/WiFi)"
echo "   • QL-800 (USB)"
echo "   • PT-P750W (WiFi)"
echo "   • PT-P710BT (Bluetooth)"
echo ""
echo "🔗 Brother Developer Portal:"
echo "   https://support.brother.com/g/s/es/dev/"
echo ""
print_success "Setup complete! 🎉"