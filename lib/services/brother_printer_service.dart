import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/brother_printer.dart';
import '../models/attendee.dart';
import '../models/badge_template.dart';
import 'brother_printer_channel.dart';
import 'badge_optimization_engine.dart';

/// Abstract interface for Brother printer service
abstract class BrotherPrinterService {
  Future<void> initialize();
  Future<List<BrotherPrinter>> discoverPrinters();
  Future<bool> connectToPrinter(String printerId);
  Future<PrintResult> printBadge(BadgeData badgeData);
  Future<PrintResult> printMultipleBadges(List<BadgeData> badges);
  Stream<PrinterStatus> get statusStream;
  Future<void> disconnect();
  Future<bool> testConnection();
  Future<PrinterCapabilities?> getPrinterCapabilities(String printerId);
}

/// Concrete implementation of Brother printer service
class BrotherPrinterServiceImpl implements BrotherPrinterService {
  static final BrotherPrinterServiceImpl _instance = BrotherPrinterServiceImpl._internal();
  factory BrotherPrinterServiceImpl() => _instance;
  BrotherPrinterServiceImpl._internal();

  final BrotherPrinterChannel _channel = BrotherPrinterChannel.instance;
  final BadgeOptimizationEngine _optimizationEngine = BadgeOptimizationEngine();
  
  BrotherPrinter? _connectedPrinter;
  final StreamController<PrinterStatus> _statusController = StreamController<PrinterStatus>.broadcast();
  final List<BrotherPrinter> _discoveredPrinters = [];
  
  bool _isInitialized = false;
  Timer? _statusTimer;

  /// Check if running in iOS simulator or mock mode
  static bool get isSimulator {
    if (!Platform.isIOS) return false;
    
    // Check for simulator environment variables
    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
           Platform.environment.containsKey('SIMULATOR_UDID') ||
           Platform.environment['FLUTTER_TEST'] == 'true';
  }
  
  /// Check if Brother SDK is in mock mode (temporarily always true)
  static bool get isMockMode => Platform.isIOS;

  @override
  Stream<PrinterStatus> get statusStream => _statusController.stream;

  BrotherPrinter? get connectedPrinter => _connectedPrinter;
  List<BrotherPrinter> get discoveredPrinters => List.unmodifiable(_discoveredPrinters);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (isMockMode) {
        debugPrint('🔧 Initializing Brother Printer Service (Mock Mode)...');
        debugPrint('⚠️ Running in Mock Mode - Brother SDK features are mocked');
      } else {
        debugPrint('🔧 Initializing Brother Printer Service...');
      }
      
      // Initialize the native channel
      final success = await _channel.initialize();
      if (!success) {
        if (isSimulator) {
          debugPrint('⚠️ Brother SDK initialization failed in simulator - this is expected');
          // Continue with mock initialization for simulator
        } else {
          throw Exception('Failed to initialize Brother SDK');
        }
      }

      // Initialize optimization engine
      await _optimizationEngine.initialize();

      // Listen to printer events
      _channel.eventStream.listen(_handlePrinterEvent);

      // Start periodic status monitoring (skip in simulator)
      if (!isSimulator) {
        _startStatusMonitoring();
      }

      _isInitialized = true;
      
      if (isSimulator) {
        debugPrint('✅ Brother Printer Service initialized successfully (Simulator Mode)');
        debugPrint('📱 Simulator mode: Mock printers and print operations will be available');
      } else {
        debugPrint('✅ Brother Printer Service initialized successfully');
      }
    } catch (e) {
      debugPrint('❌ Brother Printer Service initialization failed: $e');
      if (isSimulator) {
        debugPrint('⚠️ Continuing with simulator mode despite initialization error');
        _isInitialized = true;
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<List<BrotherPrinter>> discoverPrinters() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (isSimulator) {
        debugPrint('🔍 Discovering Brother printers (Simulator Mode)...');
        return _getSimulatorMockPrinters();
      }
      
      debugPrint('🔍 Discovering Brother printers...');
      
      final printerData = await _channel.discoverPrinters();
      _discoveredPrinters.clear();
      
      for (final data in printerData) {
        try {
          final printer = BrotherPrinter.fromJson(data);
          _discoveredPrinters.add(printer);
          debugPrint('📱 Found printer: ${printer.displayName} (${printer.connectionType})');
        } catch (e) {
          debugPrint('⚠️ Failed to parse printer data: $e');
        }
      }

      debugPrint('✅ Discovery complete: ${_discoveredPrinters.length} printers found');
      return List.from(_discoveredPrinters);
    } catch (e) {
      debugPrint('❌ Printer discovery failed: $e');
      
      if (isSimulator) {
        debugPrint('🔄 Falling back to simulator mock printers');
        return _getSimulatorMockPrinters();
      }
      
      return [];
    }
  }

  @override
  Future<bool> connectToPrinter(String printerId) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final printer = _discoveredPrinters.firstWhere(
        (p) => p.id == printerId,
        orElse: () => throw Exception('Printer not found: $printerId'),
      );

      if (isSimulator) {
        debugPrint('🔗 Connecting to printer: $printerId (Simulator Mode)');
        
        // Simulate connection delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        _connectedPrinter = printer.copyWith(status: PrinterStatus.connected);
        _statusController.add(PrinterStatus.connected);
        debugPrint('✅ Connected to printer: ${printer.displayName} (Simulator)');
        return true;
      }
      
      debugPrint('🔗 Connecting to printer: $printerId');

      final success = await _channel.connectToPrinter(
        printerId,
        printer.connectionType.toString().split('.').last,
      );

      if (success) {
        _connectedPrinter = printer.copyWith(status: PrinterStatus.connected);
        _statusController.add(PrinterStatus.connected);
        debugPrint('✅ Connected to printer: ${printer.displayName}');
        return true;
      } else {
        debugPrint('❌ Failed to connect to printer: ${printer.displayName}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_connectedPrinter != null) {
        debugPrint('🔌 Disconnecting from printer: ${_connectedPrinter!.displayName}');
        
        await _channel.disconnect();
        _connectedPrinter = _connectedPrinter!.copyWith(status: PrinterStatus.disconnected);
        _statusController.add(PrinterStatus.disconnected);
        _connectedPrinter = null;
        
        debugPrint('✅ Disconnected from printer');
      }
    } catch (e) {
      debugPrint('❌ Disconnection error: $e');
    }
  }

  @override
  Future<PrintResult> printBadge(BadgeData badgeData) async {
    return printBadgeWithSettings(badgeData, null);
  }

  /// Print badge with custom settings (supports direct printing)
  Future<PrintResult> printBadgeWithSettings(BadgeData badgeData, PrintSettings? customSettings) async {
    try {
      if (isSimulator) {
        debugPrint('🖨️ Printing badge for: ${badgeData.attendeeName} (Simulator Mode)');
        return _simulatePrintBadge(badgeData);
      }
      
      debugPrint('🖨️ Printing badge for: ${badgeData.attendeeName}');
      final startTime = DateTime.now();

      // Use custom settings or create default settings
      PrintSettings printSettings;
      if (customSettings != null) {
        printSettings = customSettings;
      } else if (_connectedPrinter != null) {
        printSettings = PrintSettings(
          labelSize: _getOptimalLabelSize(_connectedPrinter!.capabilities),
          copies: 1,
          autoCut: true,
          quality: PrintQuality.normal,
        );
      } else {
        return PrintResult.failure(
          errorMessage: 'No printer connected and no connection settings provided',
          errorCode: 'NO_PRINTER',
        );
      }

      // Handle direct printing (no dialogs)
      if (printSettings.isDirectConnection) {
        debugPrint('🔗 Direct printing to ${printSettings.connectionIdentifier}');
        
        // Connect directly using settings
        final connected = await _connectDirectly(printSettings);
        if (!connected) {
          return PrintResult.failure(
            errorMessage: 'Failed to connect directly to ${printSettings.connectionIdentifier}',
            errorCode: 'DIRECT_CONNECTION_FAILED',
          );
        }
      } else if (_connectedPrinter == null) {
        return PrintResult.failure(
          errorMessage: 'No printer connected',
          errorCode: 'NO_PRINTER',
        );
      }

      _statusController.add(PrinterStatus.printing);

      // Optimize badge for Brother printer
      final capabilities = _connectedPrinter?.capabilities ?? _getDefaultCapabilities();
      final optimizedBadge = await _optimizationEngine.optimizeBadge(
        badgeData,
        capabilities,
      );

      // Send print job to native layer
      final result = await _channel.printBadge(
        imageData: optimizedBadge.imageData,
        printSettings: printSettings.toJson(),
      );

      final printTime = DateTime.now().difference(startTime);

      if (result['success'] == true) {
        _statusController.add(PrinterStatus.connected);
        debugPrint('✅ Badge printed successfully in ${printTime.inMilliseconds}ms');
        
        return PrintResult.success(
          printTime: printTime,
          labelCount: 1,
        );
      } else {
        _statusController.add(PrinterStatus.error);
        debugPrint('❌ Print failed: ${result['error']}');
        
        return PrintResult.failure(
          errorMessage: result['error'] ?? 'Unknown print error',
          errorCode: result['errorCode'],
          printTime: printTime,
        );
      }
    } catch (e) {
      _statusController.add(PrinterStatus.error);
      debugPrint('❌ Print error: $e');
      
      return PrintResult.failure(
        errorMessage: e.toString(),
        errorCode: 'PRINT_EXCEPTION',
      );
    }
  }

  @override
  Future<PrintResult> printMultipleBadges(List<BadgeData> badges) async {
    if (_connectedPrinter == null) {
      return PrintResult.failure(
        errorMessage: 'No printer connected',
        errorCode: 'NO_PRINTER',
      );
    }

    try {
      debugPrint('🖨️ Printing ${badges.length} badges...');
      _statusController.add(PrinterStatus.printing);

      final startTime = DateTime.now();
      int successCount = 0;
      String? lastError;

      for (int i = 0; i < badges.length; i++) {
        final badge = badges[i];
        debugPrint('🖨️ Printing badge ${i + 1}/${badges.length}: ${badge.attendeeName}');

        final result = await printBadge(badge);
        if (result.success) {
          successCount++;
        } else {
          lastError = result.errorMessage;
          debugPrint('❌ Failed to print badge for ${badge.attendeeName}: ${result.errorMessage}');
        }
      }

      final printTime = DateTime.now().difference(startTime);
      _statusController.add(PrinterStatus.connected);

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
      _statusController.add(PrinterStatus.error);
      debugPrint('❌ Batch print error: $e');
      
      return PrintResult.failure(
        errorMessage: e.toString(),
        errorCode: 'BATCH_PRINT_EXCEPTION',
      );
    }
  }

  @override
  Future<bool> testConnection() async {
    if (_connectedPrinter == null) {
      return false;
    }

    try {
      if (isSimulator) {
        debugPrint('🔍 Testing printer connection (Simulator Mode)...');
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('✅ Connection test passed (Simulator)');
        return true;
      }
      
      debugPrint('🔍 Testing printer connection...');
      final result = await _channel.testConnection();
      debugPrint(result ? '✅ Connection test passed' : '❌ Connection test failed');
      return result;
    } catch (e) {
      debugPrint('❌ Connection test error: $e');
      
      if (isSimulator) {
        debugPrint('🔄 Returning mock success for simulator');
        return true;
      }
      
      return false;
    }
  }

  @override
  Future<PrinterCapabilities?> getPrinterCapabilities(String printerId) async {
    try {
      final result = await _channel.getPrinterCapabilities(printerId);
      if (result.containsKey('error')) {
        debugPrint('❌ Failed to get printer capabilities: ${result['error']}');
        return null;
      }
      return PrinterCapabilities.fromJson(result);
    } catch (e) {
      debugPrint('❌ Error getting printer capabilities: $e');
      return null;
    }
  }

  /// Handle printer events from native layer
  void _handlePrinterEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>?;

    switch (eventType) {
      case 'statusChanged':
        final statusString = data?['status'] as String?;
        if (statusString != null) {
          final status = PrinterStatus.values.firstWhere(
            (e) => e.toString().split('.').last == statusString,
            orElse: () => PrinterStatus.disconnected,
          );
          _statusController.add(status);
          
          if (_connectedPrinter != null) {
            _connectedPrinter = _connectedPrinter!.copyWith(status: status);
          }
        }
        break;
      
      case 'printerDiscovered':
        if (data != null) {
          try {
            final printer = BrotherPrinter.fromJson(data);
            if (!_discoveredPrinters.any((p) => p.id == printer.id)) {
              _discoveredPrinters.add(printer);
              debugPrint('📱 New printer discovered: ${printer.displayName}');
            }
          } catch (e) {
            debugPrint('⚠️ Failed to parse discovered printer: $e');
          }
        }
        break;
      
      case 'connectionLost':
        debugPrint('🔌 Connection lost to printer');
        _statusController.add(PrinterStatus.disconnected);
        if (_connectedPrinter != null) {
          _connectedPrinter = _connectedPrinter!.copyWith(status: PrinterStatus.disconnected);
        }
        break;
      
      default:
        debugPrint('🔔 Unknown printer event: $eventType');
    }
  }

  /// Start periodic status monitoring
  void _startStatusMonitoring() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_connectedPrinter != null) {
        final status = await _channel.getPrinterStatus();
        if (status.containsKey('connected') && status['connected'] == false) {
          _statusController.add(PrinterStatus.disconnected);
          if (_connectedPrinter != null) {
            _connectedPrinter = _connectedPrinter!.copyWith(status: PrinterStatus.disconnected);
          }
        }
      }
    });
  }

  /// Connect directly using print settings (no dialogs)
  Future<bool> _connectDirectly(PrintSettings settings) async {
    if (!settings.isDirectConnection) {
      return false;
    }

    try {
      debugPrint('🔗 Connecting directly via ${settings.connectionType} to ${settings.connectionIdentifier}');
      
      // Create a temporary printer object for direct connection
      final directPrinter = BrotherPrinter(
        id: 'direct_${settings.connectionType}_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Direct Connection',
        model: 'Unknown',
        connectionType: settings.connectionType!,
        capabilities: _getDefaultCapabilities(),
        isMfiCertified: settings.connectionType == PrinterConnectionType.mfi,
        bluetoothAddress: settings.bluetoothAddress,
        ipAddress: settings.ipAddress,
        status: PrinterStatus.connecting,
        lastSeen: DateTime.now(),
        connectionData: {
          'port': settings.port,
          'timeout': settings.connectionTimeout.inMilliseconds,
          'autoReconnect': settings.autoReconnect,
        },
      );

      // Use native channel to connect directly
      final success = await _channel.connectDirectly(
        connectionType: settings.connectionType!.toString().split('.').last,
        bluetoothAddress: settings.bluetoothAddress,
        ipAddress: settings.ipAddress,
        port: settings.port ?? 9100,
        timeoutMs: settings.connectionTimeout.inMilliseconds,
      );

      if (success) {
        _connectedPrinter = directPrinter.copyWith(status: PrinterStatus.connected);
        _statusController.add(PrinterStatus.connected);
        debugPrint('✅ Direct connection established');
        return true;
      } else {
        debugPrint('❌ Direct connection failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Direct connection error: $e');
      return false;
    }
  }

  /// Get default capabilities for unknown printers
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

  /// Get optimal label size for the printer
  LabelSize _getOptimalLabelSize(PrinterCapabilities capabilities) {
    // Default to first available label size or create a default
    if (capabilities.supportedLabelSizes.isNotEmpty) {
      return capabilities.supportedLabelSizes.first;
    }
    
    // Default Brother QL label size (62mm x 29mm)
    return LabelSize(
      id: 'default',
      name: 'Default Label',
      widthMm: 62,
      heightMm: 29,
      isRoll: true,
    );
  }

  /// Get mock printers for simulator mode
  List<BrotherPrinter> _getSimulatorMockPrinters() {
    _discoveredPrinters.clear();
    
    final mockPrinters = [
      BrotherPrinter(
        id: 'simulator_ql820nwb',
        name: 'Brother QL-820NWB (Simulator)',
        model: 'QL-820NWB',
        connectionType: PrinterConnectionType.wifi,
        capabilities: _getDefaultCapabilities(),
        isMfiCertified: false,
        ipAddress: '192.168.1.100',
        status: PrinterStatus.disconnected,
        lastSeen: DateTime.now(),
        connectionData: {
          'simulatorMode': true,
          'mockDevice': true,
        },
      ),
      BrotherPrinter(
        id: 'simulator_ql810w',
        name: 'Brother QL-810W (Simulator)',
        model: 'QL-810W',
        connectionType: PrinterConnectionType.bluetooth,
        capabilities: _getDefaultCapabilities(),
        isMfiCertified: false,
        bluetoothAddress: '00:00:00:00:00:00',
        status: PrinterStatus.disconnected,
        lastSeen: DateTime.now(),
        connectionData: {
          'simulatorMode': true,
          'mockDevice': true,
        },
      ),
    ];
    
    _discoveredPrinters.addAll(mockPrinters);
    
    debugPrint('📱 Created ${mockPrinters.length} mock printers for simulator');
    for (final printer in mockPrinters) {
      debugPrint('   - ${printer.displayName} (${printer.connectionType})');
    }
    
    return List.from(_discoveredPrinters);
  }

  /// Simulate printing a badge in simulator mode
  Future<PrintResult> _simulatePrintBadge(BadgeData badgeData) async {
    final startTime = DateTime.now();
    
    _statusController.add(PrinterStatus.printing);
    
    // Simulate print processing time
    await Future.delayed(const Duration(milliseconds: 800));
    
    final printTime = DateTime.now().difference(startTime);
    _statusController.add(PrinterStatus.connected);
    
    debugPrint('✅ Badge printed successfully in simulator mode (${printTime.inMilliseconds}ms)');
    debugPrint('📱 Simulated printing badge for: ${badgeData.attendeeName}');
    
    return PrintResult.success(
      printTime: printTime,
      labelCount: 1,
      additionalData: {
        'simulatorMode': true,
        'mockPrint': true,
        'attendeeName': badgeData.attendeeName,
      },
    );
  }

  /// Dispose resources
  void dispose() {
    _statusTimer?.cancel();
    _statusController.close();
  }
}