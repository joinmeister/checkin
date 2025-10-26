import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import '../utils/constants.dart';

enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

class SyncResult {
  final bool success;
  final int processedActions;
  final int failedActions;
  final List<String> errors;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.processedActions,
    required this.failedActions,
    required this.errors,
    required this.timestamp,
  });
}

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _queueService = OfflineQueueService();

  SyncStatus _status = SyncStatus.idle;
  SyncResult? _lastSyncResult;
  DateTime? _lastSyncTime;
  // No subscription needed for ChangeNotifier
  bool _autoSyncEnabled = true;
  Timer? _periodicSyncTimer;
  
  // Sync completion callbacks
  final List<Function(SyncResult)> _syncCompletionCallbacks = [];

  // Getters
  SyncStatus get status => _status;
  SyncResult? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get hasQueuedActions => _queueService.hasQueuedActions;
  int get queueLength => _queueService.queueLength;
  
  // Add sync completion callback
  void addSyncCompletionCallback(Function(SyncResult) callback) {
    _syncCompletionCallbacks.add(callback);
  }
  
  // Remove sync completion callback
  void removeSyncCompletionCallback(Function(SyncResult) callback) {
    _syncCompletionCallbacks.remove(callback);
  }
  
  // Notify sync completion
  void _notifySyncCompletion(SyncResult result) {
    print('🔄 SYNC: Notifying ${_syncCompletionCallbacks.length} callbacks');
    for (final callback in _syncCompletionCallbacks) {
      try {
        callback(result);
      } catch (e) {
        print('❌ SYNC: Error in sync completion callback: $e');
      }
    }
  }

  // Initialize sync service
  Future<void> initialize() async {
    await _loadLastSyncTime();
    
    // Listen for connectivity changes
    _connectivityService.addListener(_onConnectivityChanged);
    
    // Start periodic sync when online
    _startPeriodicSync();
  }

  // Manual sync trigger
  Future<SyncResult> sync({bool force = false}) async {
    if (_status == SyncStatus.syncing && !force) {
      throw Exception('Sync already in progress');
    }

    if (!_connectivityService.isOnline && !force) {
      throw Exception('Cannot sync while offline');
    }

    _updateStatus(SyncStatus.syncing);

    try {
      final result = await _performSync();
      _lastSyncResult = result;
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      
      _updateStatus(result.success ? SyncStatus.completed : SyncStatus.failed);
      
      // Notify callbacks about sync completion
      _notifySyncCompletion(result);
      
      // Reset to idle after a short delay
      Timer(const Duration(seconds: 2), () {
        _updateStatus(SyncStatus.idle);
      });

      return result;
    } catch (e) {
      print('Sync error: $e');
      final errorResult = SyncResult(
        success: false,
        processedActions: 0,
        failedActions: _queueService.queueLength,
        errors: [e.toString()],
        timestamp: DateTime.now(),
      );
      
      _lastSyncResult = errorResult;
      _updateStatus(SyncStatus.failed);
      
      // Notify callbacks even on failure
      _notifySyncCompletion(errorResult);
      
      Timer(const Duration(seconds: 2), () {
        _updateStatus(SyncStatus.idle);
      });

      return errorResult;
    }
  }

  // Enable/disable auto-sync
  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled = enabled;
    if (enabled) {
      _startPeriodicSync();
    } else {
      _stopPeriodicSync();
    }
    notifyListeners();
  }

  // Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'queueLength': _queueService.queueLength,
      'queueStats': _queueService.getQueueStats(),
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'lastSyncResult': _lastSyncResult != null ? {
        'success': _lastSyncResult!.success,
        'processedActions': _lastSyncResult!.processedActions,
        'failedActions': _lastSyncResult!.failedActions,
        'timestamp': _lastSyncResult!.timestamp.toIso8601String(),
      } : null,
      'autoSyncEnabled': _autoSyncEnabled,
      'status': _status.name,
    };
  }

  // Private methods
  Future<SyncResult> _performSync() async {
    final queue = _queueService.queue;
    if (queue.isEmpty) {
      return SyncResult(
        success: true,
        processedActions: 0,
        failedActions: 0,
        errors: [],
        timestamp: DateTime.now(),
      );
    }

    int processedActions = 0;
    int failedActions = 0;
    final List<String> errors = [];

    // Sort queue by timestamp (oldest first)
    final sortedQueue = List.from(queue)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final action in sortedQueue) {
      try {
        final success = await _processQueuedAction(action);
        if (success) {
          await _queueService.removeFromQueue(action.id);
          processedActions++;
        } else {
          await _queueService.incrementRetryCount(action.id);
          failedActions++;
          errors.add('Failed to process action ${action.id}');
        }
      } catch (e) {
        await _queueService.incrementRetryCount(action.id);
        failedActions++;
        errors.add('Error processing action ${action.id}: $e');
        print('Error processing queued action ${action.id}: $e');
      }

      // Small delay between actions to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return SyncResult(
      success: failedActions == 0,
      processedActions: processedActions,
      failedActions: failedActions,
      errors: errors,
      timestamp: DateTime.now(),
    );
  }

  Future<bool> _processQueuedAction(QueuedAction action) async {
    try {
      switch (action.type) {
        case QueueActionType.checkInByQR:
          final result = await _apiService.checkInAttendeeByQR(
            action.data['qrCode'],
          );
          return result['success'] == true;

        case QueueActionType.checkInById:
          final result = await _apiService.checkInAttendeeById(
            action.data['eventId'],
            action.data['attendeeId'],
          );
          return result['success'] == true;

        case QueueActionType.walkInRegistration:
          final result = await _apiService.addWalkIn(
            eventId: action.data['eventId'],
            firstName: action.data['firstName'],
            lastName: action.data['lastName'],
            email: action.data['email'],
            ticketType: action.data['ticketType'],
            isVip: action.data['isVip'],
          );
          return result['success'] == true;

        case QueueActionType.timingData:
          await _apiService.recordCheckInTiming(
            attendeeId: action.data['attendeeId'],
            eventId: action.data['eventId'],
            checkinType: action.data['checkinType'],
            processStartTime: DateTime.parse(action.data['processStartTime']),
            processEndTime: DateTime.parse(action.data['processEndTime']),
            scanDurationSeconds: action.data['scanDurationSeconds'],
            printDurationSeconds: action.data['printDurationSeconds'],
            registrationDurationSeconds: action.data['registrationDurationSeconds'],
          );
          return true; // Timing data doesn't return success/failure
      }
    } catch (e) {
      print('Error processing action ${action.id}: $e');
      return false;
    }
  }

  void _onConnectivityChanged() {
    if (_connectivityService.isOnline && _autoSyncEnabled && _queueService.hasQueuedActions) {
      // Delay sync slightly to ensure connection is stable
      Timer(const Duration(seconds: 2), () {
        if (_connectivityService.isOnline) {
          sync().catchError((e) {
            print('Auto-sync failed: $e');
          });
        }
      });
    }
  }

  void _startPeriodicSync() {
    _stopPeriodicSync();
    if (_autoSyncEnabled) {
      _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        if (_connectivityService.isOnline && _queueService.hasQueuedActions) {
          sync().catchError((e) {
            print('Periodic sync failed: $e');
          });
        }
      });
    }
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  void _updateStatus(SyncStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(AppConstants.lastSyncKey);
      if (lastSyncString != null) {
        _lastSyncTime = DateTime.parse(lastSyncString);
      }
    } catch (e) {
      print('Error loading last sync time: $e');
    }
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSyncTime != null) {
        await prefs.setString(AppConstants.lastSyncKey, _lastSyncTime!.toIso8601String());
      }
    } catch (e) {
      print('Error saving last sync time: $e');
    }
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    _stopPeriodicSync();
    super.dispose();
  }
}