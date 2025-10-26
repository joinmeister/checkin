# Brother SDK Setup Guide

This guide will help you download and configure the Brother SDK for both Android and iOS platforms.

## Prerequisites

1. Brother Developer Account (free registration required)
2. Xcode (for iOS development)
3. Android Studio (for Android development)

## Step 1: Download Brother SDK

### For Android:
1. Visit: https://support.brother.com/g/s/es/dev/en/mobilesdk/android/index.html
2. Register for a free developer account
3. Download the latest Brother Print SDK for Android
4. Extract the downloaded ZIP file
5. Copy `BrotherPrintLibrary.jar` to `android/app/libs/`

### For iOS:
1. Visit: https://support.brother.com/g/s/es/dev/en/mobilesdk/ios/index.html
2. Register for a free developer account
3. Download the latest Brother Print SDK for iOS
4. The iOS SDK will be automatically downloaded via CocoaPods (already configured)

## Step 2: Configure Android

The Android configuration is already set up in your project:

- `android/app/build.gradle.kts` includes the Brother SDK dependency
- `android/app/src/main/AndroidManifest.xml` has the required permissions
- `android/app/src/main/res/xml/device_filter.xml` configures USB device filters

## Step 3: Configure iOS

The iOS configuration is already set up in your project:

- `ios/Podfile` includes the BRPtouchPrinterKit dependency
- `ios/Runner/Info.plist` has the required permissions and MFi protocols
- Native Swift code is already implemented

## Step 4: Install Dependencies

After downloading the Brother SDK files:

### Android:
```bash
# Place BrotherPrintLibrary.jar in android/app/libs/
# Then run:
flutter clean
flutter pub get
cd android && ./gradlew clean
cd .. && flutter build apk --debug
```

### iOS:
```bash
# Run CocoaPods to install Brother SDK:
cd ios
pod install
cd ..
flutter clean
flutter pub get
flutter build ios --debug
```

## Step 5: Test the Implementation

1. Connect a Brother printer (QL-820NWB, QL-1110NWB, etc.)
2. Run the app on a physical device (required for Bluetooth/USB)
3. Navigate to Brother Printer Setup
4. Test printer discovery and connection

## Supported Brother Printers

### QL Series (Label Printers):
- QL-820NWB (Bluetooth/WiFi)
- QL-1110NWB (Bluetooth/WiFi)
- QL-800 (USB)
- QL-810W (WiFi)

### PT Series (Label Makers):
- PT-P750W (WiFi)
- PT-P710BT (Bluetooth)

### TD Series (Desktop Printers):
- TD-4420TN (Network)
- TD-4520TN (Network)

## Troubleshooting

### Android Issues:
1. **SDK Not Found**: Ensure `BrotherPrintLibrary.jar` is in `android/app/libs/`
2. **Permission Denied**: Grant Bluetooth and Location permissions
3. **USB Not Working**: Enable USB debugging and check device filters

### iOS Issues:
1. **Pod Install Fails**: Run `pod repo update` then `pod install`
2. **MFi Not Working**: Ensure printer is MFi certified
3. **Bluetooth Issues**: Check iOS Bluetooth permissions

## License Notes

- Brother SDK requires acceptance of their license terms
- Commercial use may require additional licensing
- Check Brother's developer portal for latest license information

## Support

- Brother Developer Portal: https://support.brother.com/g/s/es/dev/
- Brother SDK Documentation: Available after SDK download
- Technical Support: Contact Brother developer support

## File Locations

After setup, you should have:

```
android/app/libs/
├── BrotherPrintLibrary.jar

ios/Pods/
├── BRPtouchPrinterKit/
```

The native implementation code is already in place and ready to use once the SDK files are properly installed.