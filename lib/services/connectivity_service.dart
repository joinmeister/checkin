import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

enum ConnectivityStatus {
  online,
  offline,
  checking,
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final ApiService _apiService = ApiService();
  
  ConnectivityStatus _status = ConnectivityStatus.checking;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _connectionTestTimer;
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;

  // Getters
  ConnectivityStatus get status => _status;
  bool get isOnline => _status == ConnectivityStatus.online;
  bool get isOffline => _status == ConnectivityStatus.offline;
  bool get isChecking => _status == ConnectivityStatus.checking;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;

  // Duration since last online/offline
  Duration? get timeSinceLastOnline {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  Duration? get timeSinceLastOffline {
    if (_lastOfflineTime == null) return null;
    return DateTime.now().difference(_lastOfflineTime!);
  }

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('Connectivity stream error: $error');
        _updateStatus(ConnectivityStatus.offline);
      },
    );

    // Start periodic connection testing
    _startPeriodicConnectionTest();
  }

  // Manual connectivity check
  Future<void> checkConnectivity() async {
    _updateStatus(ConnectivityStatus.checking);
    await _checkConnectivity();
  }

  // Test API connection
  Future<bool> testApiConnection() async {
    try {
      return await _apiService.testConnection();
    } catch (e) {
      print('API connection test failed: $e');
      return false;
    }
  }

  // Private methods
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      await _onConnectivityChanged(connectivityResult);
    } catch (e) {
      print('Error checking connectivity: $e');
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    print('🌐 CONNECTIVITY: Network status changed to: $result');
    
    if (result == ConnectivityResult.none) {
      print('🌐 CONNECTIVITY: No network connection detected');
      _updateStatus(ConnectivityStatus.offline);
      return;
    }

    // We have network connectivity, but let's test if we can reach the API
    print('🌐 CONNECTIVITY: Network available, testing API connection...');
    _updateStatus(ConnectivityStatus.checking);
    
    try {
      final canReachApi = await _apiService.testConnection();
      print('🌐 CONNECTIVITY: API test result: $canReachApi');
      _updateStatus(canReachApi ? ConnectivityStatus.online : ConnectivityStatus.offline);
    } catch (e) {
      print('❌ CONNECTIVITY: API connectivity test failed: $e');
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      final previousStatus = _status;
      _status = newStatus;
      
      print('🌐 CONNECTIVITY: Status changed from $previousStatus to $newStatus');
      
      // Update timestamps
      if (newStatus == ConnectivityStatus.online && previousStatus != ConnectivityStatus.online) {
        _lastOnlineTime = DateTime.now();
        print('✅ CONNECTIVITY: Connection restored at ${_lastOnlineTime}');
      } else if (newStatus == ConnectivityStatus.offline && previousStatus != ConnectivityStatus.offline) {
        _lastOfflineTime = DateTime.now();
        print('❌ CONNECTIVITY: Connection lost at ${_lastOfflineTime}');
      }
      
      notifyListeners();
    } else {
      print('🌐 CONNECTIVITY: Status unchanged: $newStatus');
    }
  }

  void _startPeriodicConnectionTest() {
    // Test connection every 30 seconds when offline
    _connectionTestTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_status == ConnectivityStatus.offline) {
        await _checkConnectivity();
      }
    });
  }

  // Get connectivity status as string
  String get statusString {
    switch (_status) {
      case ConnectivityStatus.online:
        return 'Online';
      case ConnectivityStatus.offline:
        return 'Offline';
      case ConnectivityStatus.checking:
        return 'Checking...';
    }
  }

  // Get connectivity status color
  String get statusColor {
    switch (_status) {
      case ConnectivityStatus.online:
        return '#10B981'; // Green
      case ConnectivityStatus.offline:
        return '#EF4444'; // Red
      case ConnectivityStatus.checking:
        return '#F59E0B'; // Orange
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionTestTimer?.cancel();
    super.dispose();
  }
}