import 'package:flutter/material.dart';
import '../models/brother_printer.dart';
import '../services/direct_brother_printer.dart';

/// Example of how to use direct Brother printing without dialogs
class DirectPrintingExample {
  static final DirectBrotherPrinter _printer = DirectBrotherPrinter();

  /// Example: Print to Bluetooth Brother printer directly
  static Future<void> printToBluetoothExample() async {
    // Create badge data
    final badgeData = BadgeData(
      attendeeId: 'ATT001',
      attendeeName: 'John Doe',
      attendeeEmail: 'john.doe@example.com',
      qrCode: 'QR_CODE_DATA_HERE',
      isVip: false,
      templateData: {
        'eventName': 'Tech Conference 2024',
        'company': 'Example Corp',
      },
    );

    // Print directly to Bluetooth printer (no dialogs)
    final result = await _printer.printToBluetooth(
      badgeData: badgeData,
      bluetoothAddress: '00:11:22:33:44:55', // Replace with actual address
      copies: 1,
      quality: PrintQuality.normal,
      density: 5,
      autoCut: true,
    );

    if (result.success) {
      print('✅ Badge printed successfully in ${result.printTime.inMilliseconds}ms');
    } else {
      print('❌ Print failed: ${result.errorMessage}');
    }
  }

  /// Example: Print to WiFi Brother printer directly
  static Future<void> printToWifiExample() async {
    final badgeData = BadgeData(
      attendeeId: 'ATT002',
      attendeeName: 'Jane Smith',
      attendeeEmail: 'jane.smith@example.com',
      qrCode: 'QR_CODE_DATA_HERE',
      isVip: true,
      vipLogoUrl: 'https://example.com/vip-logo.png',
      templateData: {
        'eventName': 'Tech Conference 2024',
        'company': 'VIP Corp',
      },
    );

    // Print directly to WiFi printer (no dialogs)
    final result = await _printer.printToWifi(
      badgeData: badgeData,
      ipAddress: '192.168.1.100', // Replace with actual IP
      port: 9100,
      copies: 1,
      quality: PrintQuality.high,
      density: 7,
      autoCut: true,
    );

    if (result.success) {
      print('✅ VIP badge printed successfully');
    } else {
      print('❌ Print failed: ${result.errorMessage}');
    }
  }

  /// Example: Print multiple badges directly
  static Future<void> printMultipleBadgesExample() async {
    final badges = [
      BadgeData(
        attendeeId: 'ATT003',
        attendeeName: 'Alice Johnson',
        attendeeEmail: 'alice@example.com',
        qrCode: 'QR_ALICE',
        isVip: false,
        templateData: {'eventName': 'Tech Conference 2024'},
      ),
      BadgeData(
        attendeeId: 'ATT004',
        attendeeName: 'Bob Wilson',
        attendeeEmail: 'bob@example.com',
        qrCode: 'QR_BOB',
        isVip: true,
        templateData: {'eventName': 'Tech Conference 2024'},
      ),
    ];

    // Create print settings for Bluetooth
    final settings = PrintSettings.bluetooth(
      labelSize: LabelSize(
        id: 'ql_62',
        name: '62mm Roll',
        widthMm: 62,
        heightMm: 29,
        isRoll: true,
      ),
      bluetoothAddress: '00:11:22:33:44:55',
      copies: 1,
      quality: PrintQuality.normal,
      density: 5,
      autoCut: true,
    );

    // Print all badges
    final result = await _printer.printMultiple(
      badges: badges,
      settings: settings,
    );

    if (result.success) {
      print('✅ All ${result.labelCount} badges printed successfully');
    } else {
      print('❌ Batch print failed: ${result.errorMessage}');
      if (result.additionalData.containsKey('successCount')) {
        print('   Printed ${result.additionalData['successCount']}/${result.additionalData['totalCount']} badges');
      }
    }
  }

  /// Example: Test connection before printing
  static Future<void> testConnectionExample() async {
    // Test Bluetooth connection
    final bluetoothTest = await _printer.testDirectConnection(
      connectionType: PrinterConnectionType.bluetooth,
      bluetoothAddress: '00:11:22:33:44:55',
      timeout: Duration(seconds: 5),
    );

    if (bluetoothTest) {
      print('✅ Bluetooth printer is reachable');
      await printToBluetoothExample();
    } else {
      print('❌ Bluetooth printer is not reachable');
    }

    // Test WiFi connection
    final wifiTest = await _printer.testDirectConnection(
      connectionType: PrinterConnectionType.wifi,
      ipAddress: '192.168.1.100',
      port: 9100,
      timeout: Duration(seconds: 5),
    );

    if (wifiTest) {
      print('✅ WiFi printer is reachable');
      await printToWifiExample();
    } else {
      print('❌ WiFi printer is not reachable');
    }
  }
}

/// Widget example showing direct printing in a Flutter app
class DirectPrintingWidget extends StatefulWidget {
  @override
  _DirectPrintingWidgetState createState() => _DirectPrintingWidgetState();
}

class _DirectPrintingWidgetState extends State<DirectPrintingWidget> {
  final DirectBrotherPrinter _printer = DirectBrotherPrinter();
  bool _isPrinting = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _initializePrinter();
  }

  Future<void> _initializePrinter() async {
    try {
      await _printer.initialize();
      setState(() {
        _status = 'Printer initialized';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _printDirectly() async {
    if (_isPrinting) return;

    setState(() {
      _isPrinting = true;
      _status = 'Printing...';
    });

    try {
      final badgeData = BadgeData(
        attendeeId: 'DEMO001',
        attendeeName: 'Demo User',
        attendeeEmail: 'demo@example.com',
        qrCode: 'DEMO_QR_CODE',
        isVip: false,
        templateData: {
          'eventName': 'Demo Event',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Print directly to Bluetooth (replace with your printer's address)
      final result = await _printer.printToBluetooth(
        badgeData: badgeData,
        bluetoothAddress: '00:11:22:33:44:55', // Replace with actual address
        quality: PrintQuality.normal,
        density: 5,
      );

      setState(() {
        _status = result.success 
          ? 'Printed successfully in ${result.printTime.inMilliseconds}ms'
          : 'Print failed: ${result.errorMessage}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isPrinting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Direct Brother Printing'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Printing Demo',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This example shows how to print directly to Brother printers without dialogs or setup screens.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isPrinting ? null : _printDirectly,
              child: _isPrinting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Printing...'),
                    ],
                  )
                : Text('Print Demo Badge'),
            ),
            SizedBox(height: 8),
            Text(
              'Note: Update the Bluetooth address in the code to match your Brother printer.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}