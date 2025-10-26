import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/brother_printer.dart';
import 'brother_printer_channel.dart';

/// Connection event types
enum ConnectionEventType {
  discovered,
  connected,
  disconnected,
  error,
  statusChanged,
  permissionRequired
}

/// Connection event data
class ConnectionEvent {
  final ConnectionEventType type;
  final String? printerId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ConnectionEvent({
    required this.type,
    this.printerId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Printer connection information
class PrinterConnection {
  final String id;
  final String printerId;
  final PrinterConnectionType type;
  final ConnectionStatus status;
  final DateTime lastActivity;
  final Map<String, dynamic> connectionData;
  final Duration? connectionTime;

  PrinterConnection({
    required this.id,
    required this.printerId,
    required this.type,
    required this.status,
    required this.lastActivity,
    required this.connectionData,
    this.connectionTime,
  });

  PrinterConnection copyWith({
    String? id,
    String? printerId,
    PrinterConnectionType? type,
    ConnectionStatus? status,
    DateTime? lastActivity,
    Map<String, dynamic>? connectionData,
    Duration? connectionTime,
  }) {
    return PrinterConnection(
      id: id ?? this.id,
      printerId: printerId ?? this.printerId,
      type: type ?? this.type,
      status: status ?? this.status,
      lastActivity: lastActivity ?? this.lastActivity,
      connectionData: connectionData ?? this.connectionData,
      connectionTime: connectionTime ?? this.connectionTime,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => status == ConnectionStatus.error;
}

/// Connection status
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  authenticating
}

/// Abstract interface for connection management
abstract class ConnectionManager {
  Future<void> initializeConnections();
  Future<List<PrinterConnection>> scanForPrinters();
  Future<PrinterConnection> establishConnection(BrotherPrinter printer);
  Future<bool> testConnection(String connectionId);
  Stream<ConnectionEvent> get connectionEvents;
  Future<void> closeConnection(String connectionId);
  Future<bool> requestPermissions();
}

/// Concrete implementation of connection manager
class ConnectionManagerImpl implements ConnectionManager {
  static final ConnectionManagerImpl _instance = ConnectionManagerImpl._internal();
  factory ConnectionManagerImpl() => _instance;
  ConnectionManagerImpl._internal();

  final BrotherPrinterChannel _channel = BrotherPrinterChannel.instance;
  final StreamController<ConnectionEvent> _eventController = StreamController<ConnectionEvent>.broadcast();
  
  final Map<String, PrinterConnection> _activeConnections = {};
  final Map<String, BrotherPrinter> _discoveredPrinters = {};
  
  bool _isInitialized = false;
  bool _isScanning = false;
  Timer? _healthCheckTimer;
  Timer? _discoveryTimer;

  @override
  Stream<ConnectionEvent> get connectionEvents => _eventController.stream;

  Map<String, PrinterConnection> get activeConnections => Map.unmodifiable(_activeConnections);
  Map<String, BrotherPrinter> get discoveredPrinters => Map.unmodifiable(_discoveredPrinters);

  @override
  Future<void> initializeConnections() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 Initializing Connection Manager...');

      // Initialize the Brother printer channel
      await _channel.initialize();

      // Request necessary permissions
      await requestPermissions();

      // Listen to printer events
      _channel.eventStream.listen(_handlePrinterEvent);

      // Start periodic health checks
      _startHealthMonitoring();

      // Start periodic discovery
      _startPeriodicDiscovery();

      _isInitialized = true;
      debugPrint('✅ Connection Manager initialized successfully');

      _sendEvent(ConnectionEventType.discovered, data: {'initialized': true});
    } catch (e) {
      debugPrint('❌ Connection Manager initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔐 Requesting permissions...');

      final permissions = <Permission>[];

      if (Platform.isAndroid) {
        permissions.addAll([
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.location,
          Permission.locationWhenInUse,
        ]);
      } else if (Platform.isIOS) {
        permissions.addAll([
          Permission.bluetooth,
          Permission.location,
          Permission.locationWhenInUse,
        ]);
      }

      final statuses = await permissions.request();
      
      bool allGranted = true;
      for (final permission in permissions) {
        final status = statuses[permission];
        if (status != PermissionStatus.granted) {
          debugPrint('❌ Permission denied: $permission');
          allGranted = false;
        }
      }

      if (!allGranted) {
        _sendEvent(ConnectionEventType.permissionRequired, data: {
          'message': 'Bluetooth and location permissions are required for printer discovery'
        });
      }

      debugPrint(allGranted ? '✅ All permissions granted' : '⚠️ Some permissions denied');
      return allGranted;
    } catch (e) {
      debugPrint('❌ Permission request failed: $e');
      return false;
    }
  }

  @override
  Future<List<PrinterConnection>> scanForPrinters() async {
    if (!_isInitialized) {
      await initializeConnections();
    }

    if (_isScanning) {
      debugPrint('🔍 Scan already in progress...');
      return _activeConnections.values.toList();
    }

    try {
      debugPrint('🔍 Starting printer scan...');
      _isScanning = true;

      // Clear old discovered printers
      _discoveredPrinters.clear();

      // Discover printers using the native channel
      final printerData = await _channel.discoverPrinters();
      
      final connections = <PrinterConnection>[];

      for (final data in printerData) {
        try {
          final printer = BrotherPrinter.fromJson(data);
          _discoveredPrinters[printer.id] = printer;

          final connection = PrinterConnection(
            id: 'conn_${printer.id}',
            printerId: printer.id,
            type: printer.connectionType,
            status: ConnectionStatus.disconnected,
            lastActivity: DateTime.now(),
            connectionData: printer.connectionData,
          );

          connections.add(connection);
          
          _sendEvent(ConnectionEventType.discovered, 
            printerId: printer.id,
            data: printer.toJson()
          );

          debugPrint('📱 Discovered: ${printer.displayName} (${printer.connectionType})');
        } catch (e) {
          debugPrint('⚠️ Failed to parse printer data: $e');
        }
      }

      debugPrint('✅ Scan complete: ${connections.length} printers found');
      return connections;
    } catch (e) {
      debugPrint('❌ Printer scan failed: $e');
      return [];
    } finally {
      _isScanning = false;
    }
  }

  @override
  Future<PrinterConnection> establishConnection(BrotherPrinter printer) async {
    if (!_isInitialized) {
      await initializeConnections();
    }

    final connectionId = 'conn_${printer.id}';
    
    try {
      debugPrint('🔗 Establishing connection to: ${printer.displayName}');

      // Create connection object
      var connection = PrinterConnection(
        id: connectionId,
        printerId: printer.id,
        type: printer.connectionType,
        status: ConnectionStatus.connecting,
        lastActivity: DateTime.now(),
        connectionData: printer.connectionData,
      );

      _activeConnections[connectionId] = connection;
      
      _sendEvent(ConnectionEventType.statusChanged,
        printerId: printer.id,
        data: {'status': 'connecting'}
      );

      final startTime = DateTime.now();

      // Attempt connection based on type
      final success = await _connectByType(printer);

      final connectionTime = DateTime.now().difference(startTime);

      if (success) {
        connection = connection.copyWith(
          status: ConnectionStatus.connected,
          lastActivity: DateTime.now(),
          connectionTime: connectionTime,
        );
        
        _activeConnections[connectionId] = connection;
        
        _sendEvent(ConnectionEventType.connected,
          printerId: printer.id,
          data: {
            'connectionTime': connectionTime.inMilliseconds,
            'connectionType': printer.connectionType.toString().split('.').last,
          }
        );

        debugPrint('✅ Connected to: ${printer.displayName} in ${connectionTime.inMilliseconds}ms');
        return connection;
      } else {
        connection = connection.copyWith(
          status: ConnectionStatus.error,
          lastActivity: DateTime.now(),
        );
        
        _activeConnections[connectionId] = connection;
        
        _sendEvent(ConnectionEventType.error,
          printerId: printer.id,
          data: {'error': 'Connection failed'}
        );

        debugPrint('❌ Failed to connect to: ${printer.displayName}');
        return connection;
      }
    } catch (e) {
      final connection = PrinterConnection(
        id: connectionId,
        printerId: printer.id,
        type: printer.connectionType,
        status: ConnectionStatus.error,
        lastActivity: DateTime.now(),
        connectionData: printer.connectionData,
      );
      
      _activeConnections[connectionId] = connection;
      
      _sendEvent(ConnectionEventType.error,
        printerId: printer.id,
        data: {'error': e.toString()}
      );

      debugPrint('❌ Connection error for ${printer.displayName}: $e');
      return connection;
    }
  }

  @override
  Future<bool> testConnection(String connectionId) async {
    final connection = _activeConnections[connectionId];
    if (connection == null || !connection.isConnected) {
      return false;
    }

    try {
      debugPrint('🔍 Testing connection: $connectionId');
      
      final result = await _channel.testConnection();
      
      if (result) {
        // Update last activity
        _activeConnections[connectionId] = connection.copyWith(
          lastActivity: DateTime.now(),
        );
        debugPrint('✅ Connection test passed: $connectionId');
      } else {
        debugPrint('❌ Connection test failed: $connectionId');
        
        // Mark connection as error
        _activeConnections[connectionId] = connection.copyWith(
          status: ConnectionStatus.error,
          lastActivity: DateTime.now(),
        );
        
        _sendEvent(ConnectionEventType.error,
          printerId: connection.printerId,
          data: {'error': 'Connection test failed'}
        );
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Connection test error for $connectionId: $e');
      return false;
    }
  }

  @override
  Future<void> closeConnection(String connectionId) async {
    final connection = _activeConnections[connectionId];
    if (connection == null) {
      return;
    }

    try {
      debugPrint('🔌 Closing connection: $connectionId');
      
      await _channel.disconnect();
      
      _activeConnections[connectionId] = connection.copyWith(
        status: ConnectionStatus.disconnected,
        lastActivity: DateTime.now(),
      );
      
      _sendEvent(ConnectionEventType.disconnected,
        printerId: connection.printerId,
        data: {'connectionId': connectionId}
      );

      debugPrint('✅ Connection closed: $connectionId');
    } catch (e) {
      debugPrint('❌ Error closing connection $connectionId: $e');
    }
  }

  /// Connect to printer based on connection type
  Future<bool> _connectByType(BrotherPrinter printer) async {
    switch (printer.connectionType) {
      case PrinterConnectionType.bluetooth:
      case PrinterConnectionType.bluetoothLE:
        return await _connectBluetooth(printer);
      case PrinterConnectionType.wifi:
        return await _connectWifi(printer);
      case PrinterConnectionType.usb:
        return await _connectUsb(printer);
      case PrinterConnectionType.mfi:
        return await _connectMfi(printer);
    }
  }

  /// Connect via Bluetooth
  Future<bool> _connectBluetooth(BrotherPrinter printer) async {
    try {
      debugPrint('📱 Connecting via Bluetooth: ${printer.bluetoothAddress}');
      
      return await _channel.connectToPrinter(
        printer.id,
        'bluetooth',
      );
    } catch (e) {
      debugPrint('❌ Bluetooth connection error: $e');
      return false;
    }
  }

  /// Connect via WiFi
  Future<bool> _connectWifi(BrotherPrinter printer) async {
    try {
      debugPrint('📶 Connecting via WiFi: ${printer.ipAddress}');
      
      return await _channel.connectToPrinter(
        printer.id,
        'wifi',
      );
    } catch (e) {
      debugPrint('❌ WiFi connection error: $e');
      return false;
    }
  }

  /// Connect via USB
  Future<bool> _connectUsb(BrotherPrinter printer) async {
    try {
      debugPrint('🔌 Connecting via USB');
      
      return await _channel.connectToPrinter(
        printer.id,
        'usb',
      );
    } catch (e) {
      debugPrint('❌ USB connection error: $e');
      return false;
    }
  }

  /// Connect via MFi
  Future<bool> _connectMfi(BrotherPrinter printer) async {
    try {
      debugPrint('🍎 Connecting via MFi');
      
      return await _channel.connectToPrinter(
        printer.id,
        'mfi',
      );
    } catch (e) {
      debugPrint('❌ MFi connection error: $e');
      return false;
    }
  }

  /// Handle printer events from native layer
  void _handlePrinterEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>?;

    switch (eventType) {
      case 'statusChanged':
        _handleStatusChanged(data);
        break;
      case 'printerDiscovered':
        _handlePrinterDiscovered(data);
        break;
      case 'connectionLost':
        _handleConnectionLost(data);
        break;
      default:
        debugPrint('🔔 Unknown connection event: $eventType');
    }
  }

  /// Handle status change events
  void _handleStatusChanged(Map<String, dynamic>? data) {
    if (data == null) return;

    final status = data['status'] as String?;
    if (status == null) return;

    // Update all active connections with the new status
    for (final entry in _activeConnections.entries) {
      final connection = entry.value;
      ConnectionStatus newStatus;

      switch (status) {
        case 'connected':
          newStatus = ConnectionStatus.connected;
          break;
        case 'disconnected':
          newStatus = ConnectionStatus.disconnected;
          break;
        case 'error':
          newStatus = ConnectionStatus.error;
          break;
        case 'connecting':
          newStatus = ConnectionStatus.connecting;
          break;
        case 'authenticating':
          newStatus = ConnectionStatus.authenticating;
          break;
        default:
          continue;
      }

      _activeConnections[entry.key] = connection.copyWith(
        status: newStatus,
        lastActivity: DateTime.now(),
      );

      _sendEvent(ConnectionEventType.statusChanged,
        printerId: connection.printerId,
        data: {'status': status}
      );
    }
  }

  /// Handle printer discovered events
  void _handlePrinterDiscovered(Map<String, dynamic>? data) {
    if (data == null) return;

    try {
      final printer = BrotherPrinter.fromJson(data);
      _discoveredPrinters[printer.id] = printer;

      _sendEvent(ConnectionEventType.discovered,
        printerId: printer.id,
        data: printer.toJson()
      );

      debugPrint('📱 New printer discovered: ${printer.displayName}');
    } catch (e) {
      debugPrint('⚠️ Failed to parse discovered printer: $e');
    }
  }

  /// Handle connection lost events
  void _handleConnectionLost(Map<String, dynamic>? data) {
    debugPrint('🔌 Connection lost detected');

    // Mark all connections as disconnected
    for (final entry in _activeConnections.entries) {
      final connection = entry.value;
      if (connection.isConnected) {
        _activeConnections[entry.key] = connection.copyWith(
          status: ConnectionStatus.disconnected,
          lastActivity: DateTime.now(),
        );

        _sendEvent(ConnectionEventType.disconnected,
          printerId: connection.printerId,
          data: {'reason': 'connection_lost'}
        );
      }
    }
  }

  /// Start periodic health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      for (final entry in _activeConnections.entries) {
        final connection = entry.value;
        if (connection.isConnected) {
          await testConnection(entry.key);
        }
      }
    });
  }

  /// Start periodic discovery
  void _startPeriodicDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!_isScanning) {
        try {
          await scanForPrinters();
        } catch (e) {
          debugPrint('⚠️ Periodic discovery failed: $e');
        }
      }
    });
  }

  /// Send connection event
  void _sendEvent(ConnectionEventType type, {String? printerId, required Map<String, dynamic> data}) {
    final event = ConnectionEvent(
      type: type,
      printerId: printerId,
      data: data,
    );
    _eventController.add(event);
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _discoveryTimer?.cancel();
    _eventController.close();
  }
}