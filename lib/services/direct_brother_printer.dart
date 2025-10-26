import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/brother_printer.dart';
import 'brother_printer_channel.dart';
import 'badge_optimization_engine.dart';

/// Direct Brother printer service for printing without dialogs or setup screens
class DirectBrotherPrinter {
  static final DirectBrotherPrinter _instance = DirectBrotherPrinter._internal();
  factory DirectBrotherPrinter() => _instance;
  DirectBrotherPrinter._internal();

  final BrotherPrinterChannel _channel = BrotherPrinterChannel.instance;
  final BadgeOptimizationEngine _optimizationEngine = BadgeOptimizationEngine();
  
  bool _isInitialized = false;

  /// Initialize the direct printer service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 Initializing Direct Brother Printer...');
      
      final success = await _channel.initialize();
      if (!success) {
        throw Exception('Failed to initialize Brother SDK');
      }

      await _optimizationEngine.initialize();
      _isInitialized = true;
      
      debugPrint('✅ Direct Brother Printer initialized');
    } catch (e) {
      debugPrint('❌ Direct Brother Printer initialization failed: $e');
      rethrow;
    }
  }

  /// Print directly to Bluetooth Brother printer
  Future<PrintResult> printToBluetooth({
    required BadgeData badgeData,
    required String bluetoothAddress,
    LabelSize? labelSize,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final settings = PrintSettings.bluetooth(
      labelSize: labelSize ?? _getDefaultLabelSize(),
      bluetoothAddress: bluetoothAddress,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
    );

    return _printDirectly(badgeData, settings);
  }

  /// Print directly to WiFi Brother printer
  Future<PrintResult> printToWifi({
    required BadgeData badgeData,
    required String ipAddress,
    int port = 9100,
    LabelSize? labelSize,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final settings = PrintSettings.wifi(
      labelSize: labelSize ?? _getDefaultLabelSize(),
      ipAddress: ipAddress,
      port: port,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
    );

    return _printDirectly(badgeData, settings);
  }

  /// Print directly to MFi Brother printer
  Future<PrintResult> printToMfi({
    required BadgeData badgeData,
    required String bluetoothAddress,
    LabelSize? labelSize,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final settings = PrintSettings.mfi(
      labelSize: labelSize ?? _getDefaultLabelSize(),
      bluetoothAddress: bluetoothAddress,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
    );

    return _printDirectly(badgeData, settings);
  }

  /// Print multiple badges directly
  Future<PrintResult> printMultiple({
    required List<BadgeData> badges,
    required PrintSettings settings,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🖨️ Direct printing ${badges.length} badges to ${settings.connectionIdentifier}');
      final startTime = DateTime.now();
      
      int successCount = 0;
      String? lastError;

      for (int i = 0; i < badges.length; i++) {
        final badge = badges[i];
        debugPrint('🖨️ Printing badge ${i + 1}/${badges.length}: ${badge.attendeeName}');

        final result = await _printDirectly(badge, settings);
        if (result.success) {
          successCount++;
        } else {
          lastError = result.errorMessage;
          debugPrint('❌ Failed to print badge for ${badge.attendeeName}: ${result.errorMessage}');
        }
      }

      final printTime = DateTime.now().difference(startTime);

      if (successCount == badges.length) {
        debugPrint('✅ All ${badges.length} badges printed successfully');
        return PrintResult.success(
          printTime: printTime,
          labelCount: successCount,
        );
      } else {
        debugPrint('⚠️ Printed $successCount/${badges.length} badges');
        return PrintResult.failure(
          errorMessage: 'Printed $successCount/${badges.length} badges. Last error: $lastError',
          errorCode: 'PARTIAL_SUCCESS',
          printTime: printTime,
          additionalData: {'successCount': successCount, 'totalCount': badges.length},
        );
      }
    } catch (e) {
      debugPrint('❌ Batch direct print error: $e');
      return PrintResult.failure(
        errorMessage: e.toString(),
        errorCode: 'BATCH_PRINT_EXCEPTION',
      );
    }
  }

  /// Internal method to handle direct printing
  Future<PrintResult> _printDirectly(BadgeData badgeData, PrintSettings settings) async {
    try {
      debugPrint('🖨️ Direct printing badge for: ${badgeData.attendeeName} to ${settings.connectionIdentifier}');
      final startTime = DateTime.now();

      // Optimize badge for Brother printer
      final capabilities = _getDefaultCapabilities();
      final optimizedBadge = await _optimizationEngine.optimizeBadge(
        badgeData,
        capabilities,
      );

      // Print directly using native channel
      final result = await _channel.printDirectly(
        imageData: optimizedBadge.imageData,
        printSettings: settings.toJson(),
        connectionType: settings.connectionType!.toString().split('.').last,
        bluetoothAddress: settings.bluetoothAddress,
        ipAddress: settings.ipAddress,
        port: settings.port ?? 9100,
        timeoutMs: settings.connectionTimeout.inMilliseconds,
      );

      final printTime = DateTime.now().difference(startTime);

      if (result['success'] == true) {
        debugPrint('✅ Badge printed directly in ${printTime.inMilliseconds}ms');
        return PrintResult.success(
          printTime: printTime,
          labelCount: 1,
        );
      } else {
        debugPrint('❌ Direct print failed: ${result['error']}');
        return PrintResult.failure(
          errorMessage: result['error'] ?? 'Unknown print error',
          errorCode: result['errorCode'],
          printTime: printTime,
        );
      }
    } catch (e) {
      debugPrint('❌ Direct print error: $e');
      return PrintResult.failure(
        errorMessage: e.toString(),
        errorCode: 'DIRECT_PRINT_EXCEPTION',
      );
    }
  }

  /// Get default label size
  LabelSize _getDefaultLabelSize() {
    return LabelSize(
      id: 'ql_62',
      name: '62mm Roll',
      widthMm: 62,
      heightMm: 29,
      isRoll: true,
    );
  }

  /// Get default capabilities
  PrinterCapabilities _getDefaultCapabilities() {
    return PrinterCapabilities(
      supportedLabelSizes: [
        LabelSize(id: 'ql_62', name: '62mm Roll', widthMm: 62, heightMm: 29, isRoll: true),
        LabelSize(id: 'ql_29', name: '29mm Roll', widthMm: 29, heightMm: 90, isRoll: true),
        LabelSize(id: 'ql_38', name: '38mm Roll', widthMm: 38, heightMm: 90, isRoll: true),
      ],
      maxResolutionDpi: 300,
      supportsColor: false,
      supportsCutting: true,
      maxPrintWidth: 62,
      supportedFormats: ['PNG', 'BMP'],
      supportsBluetooth: true,
      supportsWifi: true,
      supportsUsb: false,
    );
  }

  /// Test direct connection without printing
  Future<bool> testDirectConnection({
    required PrinterConnectionType connectionType,
    String? bluetoothAddress,
    String? ipAddress,
    int port = 9100,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🔍 Testing direct connection to ${connectionType}');
      
      final success = await _channel.connectDirectly(
        connectionType: connectionType.toString().split('.').last,
        bluetoothAddress: bluetoothAddress,
        ipAddress: ipAddress,
        port: port,
        timeoutMs: timeout.inMilliseconds,
      );

      if (success) {
        // Disconnect after test
        await _channel.disconnect();
        debugPrint('✅ Direct connection test passed');
        return true;
      } else {
        debugPrint('❌ Direct connection test failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Direct connection test error: $e');
      return false;
    }
  }
}