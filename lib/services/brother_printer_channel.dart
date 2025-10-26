import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Native method channel for Brother printer communication
class BrotherPrinterChannel {
  static const MethodChannel _channel = MethodChannel('brother_printer');
  static const EventChannel _eventChannel = EventChannel('brother_printer_events');
  
  static BrotherPrinterChannel? _instance;
  static BrotherPrinterChannel get instance => _instance ??= BrotherPrinterChannel._();
  
  BrotherPrinterChannel._();
  
  Stream<Map<String, dynamic>>? _eventStream;
  
  /// Get event stream for printer status updates
  Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event));
    return _eventStream!;
  }
  
  /// Initialize Brother SDK
  Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      return result == true;
    } on PlatformException catch (e) {
      print('Brother SDK initialization failed: ${e.message}');
      return false;
    }
  }
  
  /// Discover available Brother printers
  Future<List<Map<String, dynamic>>> discoverPrinters() async {
    try {
      final result = await _channel.invokeMethod('discoverPrinters');
      return List<Map<String, dynamic>>.from(result ?? []);
    } on PlatformException catch (e) {
      print('Printer discovery failed: ${e.message}');
      return [];
    }
  }
  
  /// Connect to a specific Brother printer
  Future<bool> connectToPrinter(String printerId, String connectionType) async {
    try {
      final result = await _channel.invokeMethod('connectToPrinter', {
        'printerId': printerId,
        'connectionType': connectionType,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Printer connection failed: ${e.message}');
      return false;
    }
  }
  
  /// Disconnect from current printer
  Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result == true;
    } on PlatformException catch (e) {
      print('Printer disconnection failed: ${e.message}');
      return false;
    }
  }
  
  /// Print badge data to Brother printer
  Future<Map<String, dynamic>> printBadge({
    required Uint8List imageData,
    required Map<String, dynamic> printSettings,
  }) async {
    try {
      final result = await _channel.invokeMethod('printBadge', {
        'imageData': imageData,
        'printSettings': printSettings,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Unknown error',
        'errorCode': e.code,
      };
    }
  }
  
  /// Get printer status
  Future<Map<String, dynamic>> getPrinterStatus() async {
    try {
      final result = await _channel.invokeMethod('getPrinterStatus');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {
        'connected': false,
        'error': e.message ?? 'Unknown error',
      };
    }
  }
  
  /// Get printer capabilities
  Future<Map<String, dynamic>> getPrinterCapabilities(String printerId) async {
    try {
      final result = await _channel.invokeMethod('getPrinterCapabilities', {
        'printerId': printerId,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {
        'error': e.message ?? 'Unknown error',
      };
    }
  }
  
  /// Test printer connection
  Future<bool> testConnection() async {
    try {
      final result = await _channel.invokeMethod('testConnection');
      return result == true;
    } on PlatformException catch (e) {
      print('Connection test failed: ${e.message}');
      return false;
    }
  }
  
  /// Set print settings
  Future<bool> setPrintSettings(Map<String, dynamic> settings) async {
    try {
      final result = await _channel.invokeMethod('setPrintSettings', settings);
      return result == true;
    } on PlatformException catch (e) {
      print('Setting print settings failed: ${e.message}');
      return false;
    }
  }
  
  /// Connect directly to printer without discovery (for direct printing)
  Future<bool> connectDirectly({
    required String connectionType,
    String? bluetoothAddress,
    String? ipAddress,
    int port = 9100,
    int timeoutMs = 10000,
  }) async {
    try {
      final result = await _channel.invokeMethod('connectDirectly', {
        'connectionType': connectionType,
        'bluetoothAddress': bluetoothAddress,
        'ipAddress': ipAddress,
        'port': port,
        'timeoutMs': timeoutMs,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Direct connection failed: ${e.message}');
      return false;
    }
  }
  
  /// Print directly without prior connection setup (one-shot printing)
  Future<Map<String, dynamic>> printDirectly({
    required Uint8List imageData,
    required Map<String, dynamic> printSettings,
    required String connectionType,
    String? bluetoothAddress,
    String? ipAddress,
    int port = 9100,
    int timeoutMs = 10000,
  }) async {
    try {
      final result = await _channel.invokeMethod('printDirectly', {
        'imageData': imageData,
        'printSettings': printSettings,
        'connectionType': connectionType,
        'bluetoothAddress': bluetoothAddress,
        'ipAddress': ipAddress,
        'port': port,
        'timeoutMs': timeoutMs,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Unknown error',
        'errorCode': e.code,
      };
    }
  }
}