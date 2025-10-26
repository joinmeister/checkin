import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/brother_printer.dart';
import 'connection_manager.dart';
import 'brother_printer_service.dart';

/// Connection health status
enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
  disconnected,
  reconnecting
}

/// Health check result
class HealthCheckResult {
  final String connectionId;
  final HealthStatus status;
  final Duration responseTime;
  final String? errorMessage;
  final DateTime timestamp;
  final Map<String, dynamic> metrics;

  HealthCheckResult({
    required this.connectionId,
    required this.status,
    required this.responseTime,
    this.errorMessage,
    DateTime? timestamp,
    this.metrics = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHealthy => status == HealthStatus.healthy;
  bool get needsAttention => status == HealthStatus.degraded || status == HealthStatus.unhealthy;
  bool get isDisconnected => status == HealthStatus.disconnected;
}

/// Reconnection attempt result
class ReconnectionResult {
  final bool success;
  final Duration attemptTime;
  final int attemptNumber;
  final String? errorMessage;
  final DateTime timestamp;

  ReconnectionResult({
    required this.success,
    required this.attemptTime,
    required this.attemptNumber,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Connection health monitoring and auto-reconnection service
class ConnectionHealthMonitor {
  static final ConnectionHealthMonitor _instance = ConnectionHealthMonitor._internal();
  factory ConnectionHealthMonitor() => _instance;
  ConnectionHealthMonitor._internal();

  final ConnectionManagerImpl _connectionManager = ConnectionManagerImpl();
  final BrotherPrinterServiceImpl _printerService = BrotherPrinterServiceImpl();

  final StreamController<HealthCheckResult> _healthController = StreamController<HealthCheckResult>.broadcast();
  final StreamController<ReconnectionResult> _reconnectionController = StreamController<ReconnectionResult>.broadcast();

  final Map<String, HealthCheckResult> _lastHealthChecks = {};
  final Map<String, Timer> _healthTimers = {};
  final Map<String, Timer> _reconnectionTimers = {};
  final Map<String, int> _reconnectionAttempts = {};
  final Map<String, List<HealthCheckResult>> _healthHistory = {};

  bool _isMonitoring = false;
  Timer? _globalHealthTimer;

  // Configuration
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _reconnectionDelay = Duration(seconds: 5);
  static const Duration _maxReconnectionDelay = Duration(minutes: 5);
  static const int _maxReconnectionAttempts = 10;
  static const Duration _healthCheckTimeout = Duration(seconds: 10);
  static const int _maxHealthHistorySize = 50;

  /// Stream of health check results
  Stream<HealthCheckResult> get healthStream => _healthController.stream;

  /// Stream of reconnection results
  Stream<ReconnectionResult> get reconnectionStream => _reconnectionController.stream;

  /// Get current health status for all connections
  Map<String, HealthCheckResult> get currentHealth => Map.unmodifiable(_lastHealthChecks);

  /// Start monitoring all connections
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      debugPrint('🔧 Starting connection health monitoring...');

      // Listen to connection events
      _connectionManager.connectionEvents.listen(_handleConnectionEvent);

      // Start global health monitoring
      _startGlobalHealthMonitoring();

      // Monitor existing connections
      for (final connection in _connectionManager.activeConnections.values) {
        if (connection.isConnected) {
          _startMonitoringConnection(connection.id);
        }
      }

      _isMonitoring = true;
      debugPrint('✅ Connection health monitoring started');
    } catch (e) {
      debugPrint('❌ Failed to start health monitoring: $e');
      rethrow;
    }
  }

  /// Stop monitoring all connections
  void stopMonitoring() {
    if (!_isMonitoring) return;

    debugPrint('🛑 Stopping connection health monitoring...');

    _globalHealthTimer?.cancel();
    
    for (final timer in _healthTimers.values) {
      timer.cancel();
    }
    _healthTimers.clear();

    for (final timer in _reconnectionTimers.values) {
      timer.cancel();
    }
    _reconnectionTimers.clear();

    _isMonitoring = false;
    debugPrint('✅ Connection health monitoring stopped');
  }

  /// Start monitoring a specific connection
  void _startMonitoringConnection(String connectionId) {
    if (_healthTimers.containsKey(connectionId)) {
      return; // Already monitoring
    }

    debugPrint('👁️ Starting health monitoring for connection: $connectionId');

    // Perform initial health check
    _performHealthCheck(connectionId);

    // Schedule periodic health checks
    _healthTimers[connectionId] = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck(connectionId);
    });
  }

  /// Stop monitoring a specific connection
  void _stopMonitoringConnection(String connectionId) {
    debugPrint('👁️ Stopping health monitoring for connection: $connectionId');

    _healthTimers[connectionId]?.cancel();
    _healthTimers.remove(connectionId);

    _reconnectionTimers[connectionId]?.cancel();
    _reconnectionTimers.remove(connectionId);

    _reconnectionAttempts.remove(connectionId);
  }

  /// Perform health check on a connection
  Future<void> _performHealthCheck(String connectionId) async {
    final connection = _connectionManager.activeConnections[connectionId];
    if (connection == null) {
      _stopMonitoringConnection(connectionId);
      return;
    }

    try {
      debugPrint('🔍 Performing health check for: $connectionId');

      final startTime = DateTime.now();
      
      // Test the connection
      final isHealthy = await _connectionManager.testConnection(connectionId)
          .timeout(_healthCheckTimeout);
      
      final responseTime = DateTime.now().difference(startTime);

      // Determine health status
      HealthStatus status;
      String? errorMessage;

      if (isHealthy) {
        if (responseTime.inMilliseconds < 1000) {
          status = HealthStatus.healthy;
        } else if (responseTime.inMilliseconds < 3000) {
          status = HealthStatus.degraded;
        } else {
          status = HealthStatus.unhealthy;
          errorMessage = 'Slow response time: ${responseTime.inMilliseconds}ms';
        }
      } else {
        status = HealthStatus.disconnected;
        errorMessage = 'Connection test failed';
      }

      // Create health check result
      final result = HealthCheckResult(
        connectionId: connectionId,
        status: status,
        responseTime: responseTime,
        errorMessage: errorMessage,
        metrics: {
          'responseTimeMs': responseTime.inMilliseconds,
          'connectionType': connection.type.toString().split('.').last,
          'lastActivity': connection.lastActivity.toIso8601String(),
        },
      );

      // Store result
      _lastHealthChecks[connectionId] = result;
      _addToHealthHistory(connectionId, result);
      _healthController.add(result);

      debugPrint('🔍 Health check result for $connectionId: ${status.toString().split('.').last} (${responseTime.inMilliseconds}ms)');

      // Handle unhealthy connections
      if (status == HealthStatus.disconnected) {
        _handleUnhealthyConnection(connectionId, connection);
      }

    } catch (e) {
      debugPrint('❌ Health check failed for $connectionId: $e');

      final result = HealthCheckResult(
        connectionId: connectionId,
        status: HealthStatus.disconnected,
        responseTime: _healthCheckTimeout,
        errorMessage: 'Health check timeout: $e',
      );

      _lastHealthChecks[connectionId] = result;
      _addToHealthHistory(connectionId, result);
      _healthController.add(result);

      _handleUnhealthyConnection(connectionId, connection);
    }
  }

  /// Handle unhealthy connection
  void _handleUnhealthyConnection(String connectionId, PrinterConnection connection) {
    // Don't start reconnection if already in progress
    if (_reconnectionTimers.containsKey(connectionId)) {
      return;
    }

    final attempts = _reconnectionAttempts[connectionId] ?? 0;
    if (attempts >= _maxReconnectionAttempts) {
      debugPrint('❌ Max reconnection attempts reached for: $connectionId');
      return;
    }

    debugPrint('🔄 Scheduling reconnection for: $connectionId (attempt ${attempts + 1})');

    // Calculate exponential backoff delay
    final delay = _calculateReconnectionDelay(attempts);

    _reconnectionTimers[connectionId] = Timer(delay, () {
      _attemptReconnection(connectionId, connection);
    });
  }

  /// Attempt to reconnect to a printer
  Future<void> _attemptReconnection(String connectionId, PrinterConnection connection) async {
    final printer = _connectionManager.discoveredPrinters[connection.printerId];
    if (printer == null) {
      debugPrint('❌ Printer not found for reconnection: ${connection.printerId}');
      return;
    }

    final attemptNumber = (_reconnectionAttempts[connectionId] ?? 0) + 1;
    _reconnectionAttempts[connectionId] = attemptNumber;

    debugPrint('🔄 Attempting reconnection $attemptNumber for: ${printer.displayName}');

    // Update health status to reconnecting
    final reconnectingResult = HealthCheckResult(
      connectionId: connectionId,
      status: HealthStatus.reconnecting,
      responseTime: Duration.zero,
    );
    _lastHealthChecks[connectionId] = reconnectingResult;
    _healthController.add(reconnectingResult);

    final startTime = DateTime.now();

    try {
      // Attempt to establish new connection
      final newConnection = await _connectionManager.establishConnection(printer);
      final attemptTime = DateTime.now().difference(startTime);

      if (newConnection.isConnected) {
        // Reconnection successful
        debugPrint('✅ Reconnection successful for: ${printer.displayName}');

        _reconnectionAttempts.remove(connectionId);
        _reconnectionTimers.remove(connectionId);

        final result = ReconnectionResult(
          success: true,
          attemptTime: attemptTime,
          attemptNumber: attemptNumber,
        );
        _reconnectionController.add(result);

        // Perform immediate health check
        _performHealthCheck(connectionId);

      } else {
        // Reconnection failed
        debugPrint('❌ Reconnection failed for: ${printer.displayName}');

        final result = ReconnectionResult(
          success: false,
          attemptTime: attemptTime,
          attemptNumber: attemptNumber,
          errorMessage: 'Connection establishment failed',
        );
        _reconnectionController.add(result);

        // Schedule next attempt if not at max
        if (attemptNumber < _maxReconnectionAttempts) {
          _handleUnhealthyConnection(connectionId, connection);
        }
      }

    } catch (e) {
      final attemptTime = DateTime.now().difference(startTime);
      
      debugPrint('❌ Reconnection error for ${printer.displayName}: $e');

      final result = ReconnectionResult(
        success: false,
        attemptTime: attemptTime,
        attemptNumber: attemptNumber,
        errorMessage: e.toString(),
      );
      _reconnectionController.add(result);

      // Schedule next attempt if not at max
      if (attemptNumber < _maxReconnectionAttempts) {
        _handleUnhealthyConnection(connectionId, connection);
      }
    }
  }

  /// Calculate reconnection delay with exponential backoff
  Duration _calculateReconnectionDelay(int attemptNumber) {
    final baseDelay = _reconnectionDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, attemptNumber);
    final cappedDelay = min(exponentialDelay.toInt(), _maxReconnectionDelay.inMilliseconds);
    
    // Add some jitter to avoid thundering herd
    final jitter = Random().nextInt(1000);
    
    return Duration(milliseconds: cappedDelay + jitter);
  }

  /// Handle connection events
  void _handleConnectionEvent(ConnectionEvent event) {
    switch (event.type) {
      case ConnectionEventType.connected:
        if (event.printerId != null) {
          final connectionId = 'conn_${event.printerId}';
          _startMonitoringConnection(connectionId);
          _reconnectionAttempts.remove(connectionId);
        }
        break;

      case ConnectionEventType.disconnected:
        if (event.printerId != null) {
          final connectionId = 'conn_${event.printerId}';
          _stopMonitoringConnection(connectionId);
        }
        break;

      case ConnectionEventType.error:
        if (event.printerId != null) {
          final connectionId = 'conn_${event.printerId}';
          final connection = _connectionManager.activeConnections[connectionId];
          if (connection != null) {
            _handleUnhealthyConnection(connectionId, connection);
          }
        }
        break;

      default:
        // Handle other events if needed
        break;
    }
  }

  /// Start global health monitoring
  void _startGlobalHealthMonitoring() {
    _globalHealthTimer?.cancel();
    _globalHealthTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _performGlobalHealthCheck();
    });
  }

  /// Perform global health check
  void _performGlobalHealthCheck() {
    final now = DateTime.now();
    final staleConnections = <String>[];

    // Check for stale connections
    for (final entry in _lastHealthChecks.entries) {
      final timeSinceLastCheck = now.difference(entry.value.timestamp);
      if (timeSinceLastCheck > Duration(minutes: 5)) {
        staleConnections.add(entry.key);
      }
    }

    // Clean up stale connections
    for (final connectionId in staleConnections) {
      debugPrint('🧹 Cleaning up stale connection: $connectionId');
      _stopMonitoringConnection(connectionId);
      _lastHealthChecks.remove(connectionId);
      _healthHistory.remove(connectionId);
    }

    // Log health statistics
    _logHealthStatistics();
  }

  /// Add result to health history
  void _addToHealthHistory(String connectionId, HealthCheckResult result) {
    _healthHistory.putIfAbsent(connectionId, () => <HealthCheckResult>[]);
    final history = _healthHistory[connectionId]!;
    
    history.add(result);
    
    // Keep only recent history
    if (history.length > _maxHealthHistorySize) {
      history.removeAt(0);
    }
  }

  /// Get health history for a connection
  List<HealthCheckResult> getHealthHistory(String connectionId) {
    return List.unmodifiable(_healthHistory[connectionId] ?? []);
  }

  /// Get health statistics
  Map<String, dynamic> getHealthStatistics() {
    final stats = <String, dynamic>{
      'totalConnections': _lastHealthChecks.length,
      'healthyConnections': _lastHealthChecks.values.where((r) => r.status == HealthStatus.healthy).length,
      'degradedConnections': _lastHealthChecks.values.where((r) => r.status == HealthStatus.degraded).length,
      'unhealthyConnections': _lastHealthChecks.values.where((r) => r.status == HealthStatus.unhealthy).length,
      'disconnectedConnections': _lastHealthChecks.values.where((r) => r.status == HealthStatus.disconnected).length,
      'reconnectingConnections': _lastHealthChecks.values.where((r) => r.status == HealthStatus.reconnecting).length,
      'averageResponseTime': _calculateAverageResponseTime(),
      'totalReconnectionAttempts': _reconnectionAttempts.values.fold(0, (sum, attempts) => sum + attempts),
      'activeReconnections': _reconnectionTimers.length,
    };

    return stats;
  }

  /// Calculate average response time
  double _calculateAverageResponseTime() {
    final responseTimes = _lastHealthChecks.values
        .where((r) => r.status != HealthStatus.disconnected)
        .map((r) => r.responseTime.inMilliseconds)
        .toList();

    if (responseTimes.isEmpty) return 0.0;

    final sum = responseTimes.reduce((a, b) => a + b);
    return sum / responseTimes.length;
  }

  /// Log health statistics
  void _logHealthStatistics() {
    final stats = getHealthStatistics();
    debugPrint('📊 Health Statistics: ${stats['healthyConnections']}/${stats['totalConnections']} healthy, '
        'avg response: ${stats['averageResponseTime'].toStringAsFixed(1)}ms, '
        'reconnections: ${stats['activeReconnections']}');
  }

  /// Force reconnection for a connection
  Future<void> forceReconnection(String connectionId) async {
    final connection = _connectionManager.activeConnections[connectionId];
    if (connection == null) {
      debugPrint('❌ Connection not found for forced reconnection: $connectionId');
      return;
    }

    debugPrint('🔄 Forcing reconnection for: $connectionId');

    // Cancel existing reconnection timer
    _reconnectionTimers[connectionId]?.cancel();
    _reconnectionTimers.remove(connectionId);

    // Reset attempt counter
    _reconnectionAttempts[connectionId] = 0;

    // Attempt immediate reconnection
    _attemptReconnection(connectionId, connection);
  }

  /// Reset reconnection attempts for a connection
  void resetReconnectionAttempts(String connectionId) {
    _reconnectionAttempts.remove(connectionId);
    debugPrint('🔄 Reset reconnection attempts for: $connectionId');
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _healthController.close();
    _reconnectionController.close();
    _lastHealthChecks.clear();
    _healthHistory.clear();
  }
}