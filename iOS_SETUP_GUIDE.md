# iOS Setup Guide

## Issues Fixed

### 1. ✅ Module 'connectivity_plus' not found
**Status**: RESOLVED
- Cleaned Flutter dependencies
- Regenerated iOS project files
- Podfile configured correctly

### 2. ❌ Code Signing Issue
**Status**: REQUIRES MANUAL SETUP

## Code Signing Setup (Required on macOS)

### Option A: Automatic Signing (Recommended for Development)

1. **Open Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select Runner Project**:
   - Click on "Runner" in the project navigator
   - Select "Signing & Capabilities" tab

3. **Enable Automatic Signing**:
   - Check "Automatically manage signing"
   - Select your Apple ID team from dropdown
   - Xcode will automatically configure signing

### Option B: Manual Signing (For Production)

1. **Get Apple Developer Account**:
   - Sign up at https://developer.apple.com
   - Pay $99/year for individual account

2. **Create App ID**:
   - Go to Apple Developer Portal
   - Create new App ID: `com.example.event_checkin_mobile`

3. **Create Provisioning Profile**:
   - Create development/distribution profiles
   - Download and install

4. **Configure in Xcode**:
   - Set Team to your developer account
   - Select correct provisioning profile

## Build Commands (Run on macOS)

### 1. Install CocoaPods Dependencies
```bash
cd ios
pod install
cd ..
```

### 2. Build for iOS Simulator
```bash
flutter run -d ios
```

### 3. Build for Physical Device
```bash
flutter run -d ios --device-id=YOUR_DEVICE_ID
```

### 4. Build Release Version
```bash
flutter build ios
```

## Troubleshooting

### If Pod Install Fails:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### If Build Fails:
```bash
flutter clean
flutter pub get
cd ios
pod install
flutter run -d ios
```

### If Code Signing Still Fails:
1. Check Apple ID is signed in to Xcode
2. Verify team is selected in project settings
3. Try cleaning build folder: `Product > Clean Build Folder`

## Current Status

- ✅ iOS project created
- ✅ Permissions configured
- ✅ Dependencies cleaned
- ✅ Podfile ready
- ❌ Code signing needs Apple Developer setup
- ❌ Must run on macOS with Xcode

## Next Steps

1. **Transfer project to macOS**
2. **Open in Xcode**
3. **Configure code signing**
4. **Run `pod install`**
5. **Build and test**

The app is ready for iOS once code signing is configured!
