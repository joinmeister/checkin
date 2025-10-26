import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/attendee.dart';
import '../utils/constants.dart';

enum QueueActionType {
  checkInByQR,
  checkInById,
  walkInRegistration,
  timingData,
}

class QueuedAction {
  final String id;
  final QueueActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  QueuedAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id: json['id'],
    type: QueueActionType.values.firstWhere((e) => e.name == json['type']),
    data: Map<String, dynamic>.from(json['data']),
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'] ?? 0,
  );

  QueuedAction copyWith({
    String? id,
    QueueActionType? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) => QueuedAction(
    id: id ?? this.id,
    type: type ?? this.type,
    data: data ?? this.data,
    timestamp: timestamp ?? this.timestamp,
    retryCount: retryCount ?? this.retryCount,
  );
}

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final Uuid _uuid = const Uuid();
  List<QueuedAction> _queue = [];

  List<QueuedAction> get queue => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  bool get hasQueuedActions => _queue.isNotEmpty;

  // Initialize and load queue from storage
  Future<void> initialize() async {
    await _loadQueue();
  }

  // Add check-in by QR to queue
  Future<String> queueCheckInByQR({
    required String eventId,
    required String qrCode,
    required DateTime timestamp,
  }) async {
    final action = QueuedAction(
      id: _uuid.v4(),
      type: QueueActionType.checkInByQR,
      data: {
        'eventId': eventId,
        'qrCode': qrCode,
        'timestamp': timestamp.toIso8601String(),
      },
      timestamp: timestamp,
    );

    await _addToQueue(action);
    return action.id;
  }

  // Add check-in by ID to queue
  Future<String> queueCheckInById({
    required String eventId,
    required String attendeeId,
    required DateTime timestamp,
  }) async {
    final action = QueuedAction(
      id: _uuid.v4(),
      type: QueueActionType.checkInById,
      data: {
        'eventId': eventId,
        'attendeeId': attendeeId,
        'timestamp': timestamp.toIso8601String(),
      },
      timestamp: timestamp,
    );

    await _addToQueue(action);
    return action.id;
  }

  // Add walk-in registration to queue
  Future<String> queueWalkInRegistration({
    required String eventId,
    required String firstName,
    required String lastName,
    required String email,
    required String ticketType,
    required bool isVip,
    required DateTime timestamp,
  }) async {
    final action = QueuedAction(
      id: _uuid.v4(),
      type: QueueActionType.walkInRegistration,
      data: {
        'eventId': eventId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'ticketType': ticketType,
        'isVip': isVip,
        'timestamp': timestamp.toIso8601String(),
      },
      timestamp: timestamp,
    );

    await _addToQueue(action);
    return action.id;
  }

  // Add timing data to queue
  Future<String> queueTimingData({
    required String attendeeId,
    required String eventId,
    required String checkinType,
    required DateTime processStartTime,
    required DateTime processEndTime,
    int? scanDurationSeconds,
    int? printDurationSeconds,
    int? registrationDurationSeconds,
  }) async {
    final action = QueuedAction(
      id: _uuid.v4(),
      type: QueueActionType.timingData,
      data: {
        'attendeeId': attendeeId,
        'eventId': eventId,
        'checkinType': checkinType,
        'processStartTime': processStartTime.toIso8601String(),
        'processEndTime': processEndTime.toIso8601String(),
        'scanDurationSeconds': scanDurationSeconds,
        'printDurationSeconds': printDurationSeconds,
        'registrationDurationSeconds': registrationDurationSeconds,
      },
      timestamp: DateTime.now(),
    );

    await _addToQueue(action);
    return action.id;
  }

  // Remove action from queue
  Future<void> removeFromQueue(String actionId) async {
    _queue.removeWhere((action) => action.id == actionId);
    await _saveQueue();
  }

  // Update action retry count
  Future<void> incrementRetryCount(String actionId) async {
    final index = _queue.indexWhere((action) => action.id == actionId);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        retryCount: _queue[index].retryCount + 1,
      );
      await _saveQueue();
    }
  }

  // Get actions by type
  List<QueuedAction> getActionsByType(QueueActionType type) {
    return _queue.where((action) => action.type == type).toList();
  }

  // Get oldest action
  QueuedAction? getOldestAction() {
    if (_queue.isEmpty) return null;
    _queue.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _queue.first;
  }

  // Clear all queued actions
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
  }

  // Get queue statistics
  Map<String, int> getQueueStats() {
    final stats = <String, int>{};
    for (final type in QueueActionType.values) {
      stats[type.name] = _queue.where((action) => action.type == type).length;
    }
    return stats;
  }

  // Private methods
  Future<void> _addToQueue(QueuedAction action) async {
    _queue.add(action);
    await _saveQueue();
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(AppConstants.offlineQueueKey);
      
      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _queue = queueList
            .map((json) => QueuedAction.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Error loading offline queue: $e');
      _queue = [];
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((action) => action.toJson()).toList());
      await prefs.setString(AppConstants.offlineQueueKey, queueJson);
    } catch (e) {
      print('Error saving offline queue: $e');
    }
  }
}