# iOS Brother SDK Setup

The iOS Brother SDK is automatically managed through CocoaPods.

## Installation Steps:

1. Navigate to the iOS directory:
```bash
cd ios
```

2. Install CocoaPods dependencies:
```bash
pod install
```

3. If you encounter issues, update the pod repository:
```bash
pod repo update
pod install
```

## Verification:

After running `pod install`, you should see:
- `ios/Pods/BRPtouchPrinterKit/` directory
- Updated `ios/Podfile.lock` file

## Supported Features:

- ✅ Bluetooth Classic printing
- ✅ Bluetooth LE printing  
- ✅ WiFi network printing
- ✅ MFi (Made for iPhone) authentication
- ✅ External Accessory framework integration

## MFi Configuration:

The following MFi protocols are already configured in Info.plist:
- `com.brother.ptcbp` - Brother P-touch Communication Protocol
- `com.brother.mfp` - Brother MFi Protocol

## Testing:

Use a physical iOS device for testing (simulator won't work for Bluetooth/MFi).

Supported Brother printers with MFi:
- QL-820NWB
- QL-1110NWB  
- PT-P750W
- PT-P710BT