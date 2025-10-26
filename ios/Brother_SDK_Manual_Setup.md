# Manual Brother SDK Setup for xtool.sh

Since you're using xtool.sh instead of Xcode, here's how to set up the Brother SDK manually:

## Option 1: Install CocoaPods (Recommended)

```bash
# Install Ruby and CocoaPods
sudo apt install ruby-rubygems
sudo gem install cocoapods

# Then install Brother SDK
cd ios
pod install
cd ..
```

## Option 2: Manual Framework Installation

If you prefer not to install CocoaPods:

1. **Download Brother SDK for iOS:**
   - Visit: https://support.brother.com/g/s/es/dev/en/mobilesdk/ios/index.html
   - Register for free Brother developer account
   - Download "Brother Print SDK for iOS"
   - Extract the ZIP file

2. **Copy Framework:**
   ```bash
   # Create Frameworks directory
   mkdir -p ios/Frameworks
   
   # Copy BRPtouchPrinterKit.framework from downloaded SDK
   cp -R /path/to/downloaded/BRPtouchPrinterKit.framework ios/Frameworks/
   ```

3. **Update Build Configuration:**
   The project is already configured to link the framework.

## Option 3: Use xtool with CocoaPods Alternative

```bash
# Install minimal Ruby for CocoaPods
curl -sSL https://get.rvm.io | bash
source ~/.rvm/scripts/rvm
rvm install ruby-3.0.0
rvm use ruby-3.0.0 --default
gem install cocoapods

# Then proceed with normal setup
cd ios
pod install
cd ..
```

## Verification

After setup, verify the Brother SDK is available:

```bash
# Check if framework exists
ls -la ios/Pods/BRPtouchPrinterKit/ || ls -la ios/Frameworks/BRPtouchPrinterKit.framework/

# Build with xtool
flutter build ios --debug
```

## xtool.sh Compatibility

✅ **SETUP COMPLETE!** The Brother SDK is now properly configured for xtool.sh:

- ✅ BRLMPrinterKit.xcframework installed in `ios/Frameworks/`
- ✅ CocoaPods dependencies installed
- ✅ iOS Swift plugin updated for new SDK API
- ✅ Info.plist configured with MFi protocols and permissions

## Building with xtool.sh

1. Build the iOS app:
   ```bash
   # For device (ARM64)
   flutter build ios --release
   
   # Or use xtool directly on the iOS project
   cd ios
   xtool build Runner.xcworkspace --scheme Runner --configuration Release
   ```

2. Install on device using xtool:
   ```bash
   xtool install build/ios/iphoneos/Runner.app
   ```

3. Test Brother printer functionality on physical device.

## Verification

The setup includes:
- **BRLMPrinterKit.xcframework**: Latest Brother SDK (v4.1.30)
- **Bluetooth + Network support**: Full BT_Net version installed
- **MFi authentication**: Configured for certified Brother printers
- **Cross-platform compatibility**: Works with xtool.sh build system

## Troubleshooting

- **Framework not found**: Ensure BRPtouchPrinterKit is in ios/Pods/ or ios/Frameworks/
- **Build errors**: Check that Info.plist has MFi protocols configured
- **Runtime errors**: Test on physical device (not simulator) with actual Brother printer