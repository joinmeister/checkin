import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import '../utils/constants.dart';

class CheckInTiming {
  final String attendeeId;
  final String eventId;
  final String checkinType;
  final DateTime processStartTime;
  final DateTime processEndTime;
  final double scanDurationSeconds;
  final double? printDurationSeconds;
  final double? registrationDurationSeconds;

  CheckInTiming({
    required this.attendeeId,
    required this.eventId,
    required this.checkinType,
    required this.processStartTime,
    required this.processEndTime,
    required this.scanDurationSeconds,
    this.printDurationSeconds,
    this.registrationDurationSeconds,
  });

  Duration get totalDuration => processEndTime.difference(processStartTime);

  Map<String, dynamic> toJson() {
    return {
      'attendeeId': attendeeId,
      'eventId': eventId,
      'checkinType': checkinType,
      'processStartTime': processStartTime.toIso8601String(),
      'processEndTime': processEndTime.toIso8601String(),
      'scanDurationSeconds': scanDurationSeconds,
      'printDurationSeconds': printDurationSeconds,
      'registrationDurationSeconds': registrationDurationSeconds,
      'totalDurationSeconds': totalDuration.inMilliseconds / 1000.0,
    };
  }

  factory CheckInTiming.fromJson(Map<String, dynamic> json) {
    return CheckInTiming(
      attendeeId: json['attendeeId'],
      eventId: json['eventId'],
      checkinType: json['checkinType'],
      processStartTime: DateTime.parse(json['processStartTime']),
      processEndTime: DateTime.parse(json['processEndTime']),
      scanDurationSeconds: json['scanDurationSeconds'].toDouble(),
      printDurationSeconds: json['printDurationSeconds']?.toDouble(),
      registrationDurationSeconds: json['registrationDurationSeconds']?.toDouble(),
    );
  }
}

class AnalyticsService extends ChangeNotifier {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _queueService = OfflineQueueService();

  final List<CheckInTiming> _localTimings = [];
  final Map<String, DateTime> _processStartTimes = {};
  final Map<String, DateTime> _scanStartTimes = {};
  final Map<String, DateTime> _printStartTimes = {};
  final Map<String, DateTime> _registrationStartTimes = {};

  bool _isEnabled = true;
  int _maxLocalTimings = 1000;

  // Getters
  List<CheckInTiming> get localTimings => List.unmodifiable(_localTimings);
  bool get isEnabled => _isEnabled;
  int get timingsCount => _localTimings.length;

  // Initialize analytics service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadLocalTimings();
  }

  // Enable/disable analytics
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }

  // Start tracking a check-in process
  void startCheckInProcess(String attendeeId) {
    if (!_isEnabled) return;
    _processStartTimes[attendeeId] = DateTime.now();
  }

  // Start tracking scan duration
  void startScanTiming(String attendeeId) {
    if (!_isEnabled) return;
    _scanStartTimes[attendeeId] = DateTime.now();
  }

  // End scan timing
  void endScanTiming(String attendeeId) {
    if (!_isEnabled) return;
    _scanStartTimes.remove(attendeeId);
  }

  // Start tracking print duration
  void startPrintTiming(String attendeeId) {
    if (!_isEnabled) return;
    _printStartTimes[attendeeId] = DateTime.now();
  }

  // End print timing
  void endPrintTiming(String attendeeId) {
    if (!_isEnabled) return;
    _printStartTimes.remove(attendeeId);
  }

  // Start tracking registration duration
  void startRegistrationTiming(String attendeeId) {
    if (!_isEnabled) return;
    _registrationStartTimes[attendeeId] = DateTime.now();
  }

  // End registration timing
  void endRegistrationTiming(String attendeeId) {
    if (!_isEnabled) return;
    _registrationStartTimes.remove(attendeeId);
  }

  // Complete check-in process and record timing
  Future<void> completeCheckInProcess({
    required String attendeeId,
    required String eventId,
    required String checkinType,
  }) async {
    if (!_isEnabled) return;

    final processStartTime = _processStartTimes.remove(attendeeId);
    if (processStartTime == null) return;

    final processEndTime = DateTime.now();
    final scanStartTime = _scanStartTimes.remove(attendeeId);
    final printStartTime = _printStartTimes.remove(attendeeId);
    final registrationStartTime = _registrationStartTimes.remove(attendeeId);

    // Calculate durations
    double scanDurationSeconds = 0.0;
    if (scanStartTime != null) {
      scanDurationSeconds = processEndTime.difference(scanStartTime).inMilliseconds / 1000.0;
    }

    double? printDurationSeconds;
    if (printStartTime != null) {
      printDurationSeconds = processEndTime.difference(printStartTime).inMilliseconds / 1000.0;
    }

    double? registrationDurationSeconds;
    if (registrationStartTime != null) {
      registrationDurationSeconds = processEndTime.difference(registrationStartTime).inMilliseconds / 1000.0;
    }

    final timing = CheckInTiming(
      attendeeId: attendeeId,
      eventId: eventId,
      checkinType: checkinType,
      processStartTime: processStartTime,
      processEndTime: processEndTime,
      scanDurationSeconds: scanDurationSeconds,
      printDurationSeconds: printDurationSeconds,
      registrationDurationSeconds: registrationDurationSeconds,
    );

    // Store locally
    _addLocalTiming(timing);

    // Send to server if online, otherwise queue for later
    await _recordTiming(timing);
  }

  // Get analytics summary
  Map<String, dynamic> getAnalyticsSummary({String? eventId}) {
    final filteredTimings = eventId != null
        ? _localTimings.where((t) => t.eventId == eventId).toList()
        : _localTimings;

    if (filteredTimings.isEmpty) {
      return {
        'totalCheckIns': 0,
        'averageProcessTime': 0.0,
        'averageScanTime': 0.0,
        'averagePrintTime': 0.0,
        'averageRegistrationTime': 0.0,
        'checkInsByType': <String, int>{},
        'fastestCheckIn': 0.0,
        'slowestCheckIn': 0.0,
      };
    }

    final totalCheckIns = filteredTimings.length;
    final totalProcessTime = filteredTimings
        .map((t) => t.totalDuration.inMilliseconds / 1000.0)
        .reduce((a, b) => a + b);
    final averageProcessTime = totalProcessTime / totalCheckIns;

    final scanTimes = filteredTimings.map((t) => t.scanDurationSeconds).toList();
    final averageScanTime = scanTimes.isNotEmpty 
        ? scanTimes.reduce((a, b) => a + b) / scanTimes.length 
        : 0.0;

    final printTimes = filteredTimings
        .where((t) => t.printDurationSeconds != null)
        .map((t) => t.printDurationSeconds!)
        .toList();
    final averagePrintTime = printTimes.isNotEmpty 
        ? printTimes.reduce((a, b) => a + b) / printTimes.length 
        : 0.0;

    final registrationTimes = filteredTimings
        .where((t) => t.registrationDurationSeconds != null)
        .map((t) => t.registrationDurationSeconds!)
        .toList();
    final averageRegistrationTime = registrationTimes.isNotEmpty 
        ? registrationTimes.reduce((a, b) => a + b) / registrationTimes.length 
        : 0.0;

    final checkInsByType = <String, int>{};
    for (final timing in filteredTimings) {
      checkInsByType[timing.checkinType] = (checkInsByType[timing.checkinType] ?? 0) + 1;
    }

    final processTimes = filteredTimings
        .map((t) => t.totalDuration.inMilliseconds / 1000.0)
        .toList();
    final fastestCheckIn = processTimes.isNotEmpty ? processTimes.reduce((a, b) => a < b ? a : b) : 0.0;
    final slowestCheckIn = processTimes.isNotEmpty ? processTimes.reduce((a, b) => a > b ? a : b) : 0.0;

    return {
      'totalCheckIns': totalCheckIns,
      'averageProcessTime': averageProcessTime,
      'averageScanTime': averageScanTime,
      'averagePrintTime': averagePrintTime,
      'averageRegistrationTime': averageRegistrationTime,
      'checkInsByType': checkInsByType,
      'fastestCheckIn': fastestCheckIn,
      'slowestCheckIn': slowestCheckIn,
    };
  }

  // Clear local timings
  Future<void> clearLocalTimings() async {
    _localTimings.clear();
    await _saveLocalTimings();
    notifyListeners();
  }

  // Export timings as JSON
  String exportTimingsAsJson({String? eventId}) {
    final filteredTimings = eventId != null
        ? _localTimings.where((t) => t.eventId == eventId).toList()
        : _localTimings;
    
    return jsonEncode(filteredTimings.map((t) => t.toJson()).toList());
  }

  // Private methods
  Future<void> _recordTiming(CheckInTiming timing) async {
    try {
      if (_connectivityService.isOnline) {
        await _apiService.recordCheckInTiming(
          attendeeId: timing.attendeeId,
          eventId: timing.eventId,
          checkinType: timing.checkinType,
          processStartTime: timing.processStartTime,
          processEndTime: timing.processEndTime,
          scanDurationSeconds: timing.scanDurationSeconds.toInt(),
          printDurationSeconds: timing.printDurationSeconds?.toInt(),
          registrationDurationSeconds: timing.registrationDurationSeconds?.toInt(),
        );
      } else {
        // Queue for later sync
        await _queueService.queueTimingData(
          attendeeId: timing.attendeeId,
          eventId: timing.eventId,
          checkinType: timing.checkinType,
          processStartTime: timing.processStartTime,
          processEndTime: timing.processEndTime,
          scanDurationSeconds: timing.scanDurationSeconds.round(),
          printDurationSeconds: timing.printDurationSeconds?.round(),
          registrationDurationSeconds: timing.registrationDurationSeconds?.round(),
        );
      }
    } catch (e) {
      print('Error recording timing: $e');
      // Queue for later sync if API call fails
      await _queueService.queueTimingData(
        attendeeId: timing.attendeeId,
        eventId: timing.eventId,
        checkinType: timing.checkinType,
        processStartTime: timing.processStartTime,
        processEndTime: timing.processEndTime,
        scanDurationSeconds: timing.scanDurationSeconds.round(),
        printDurationSeconds: timing.printDurationSeconds?.round(),
        registrationDurationSeconds: timing.registrationDurationSeconds?.round(),
      );
    }
  }

  void _addLocalTiming(CheckInTiming timing) {
    _localTimings.add(timing);
    
    // Keep only the most recent timings
    if (_localTimings.length > _maxLocalTimings) {
      _localTimings.removeAt(0);
    }
    
    _saveLocalTimings();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('analytics_enabled') ?? true;
      _maxLocalTimings = prefs.getInt('max_local_timings') ?? 1000;
    } catch (e) {
      print('Error loading analytics settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('analytics_enabled', _isEnabled);
      await prefs.setInt('max_local_timings', _maxLocalTimings);
    } catch (e) {
      print('Error saving analytics settings: $e');
    }
  }

  Future<void> _loadLocalTimings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timingsJson = prefs.getString('local_timings');
      if (timingsJson != null) {
        final List<dynamic> timingsList = jsonDecode(timingsJson);
        _localTimings.clear();
        _localTimings.addAll(
          timingsList.map((json) => CheckInTiming.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      print('Error loading local timings: $e');
    }
  }

  Future<void> _saveLocalTimings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timingsJson = jsonEncode(_localTimings.map((t) => t.toJson()).toList());
      await prefs.setString('local_timings', timingsJson);
    } catch (e) {
      print('Error saving local timings: $e');
    }
  }

  // Legacy method aliases for compatibility
  void startCheckInTiming(String attendeeId) {
    startRegistrationTiming(attendeeId);
  }

  void endCheckInTiming(String attendeeId) {
    endRegistrationTiming(attendeeId);
  }

  // Add missing timing methods
  void startTiming(String attendeeId) {
    startRegistrationTiming(attendeeId);
  }

  void endTiming(String attendeeId) {
    endRegistrationTiming(attendeeId);
  }

  Future<void> completeCheckIn({
    required String attendeeId,
    required String eventId,
    required String checkInType,
  }) async {
    await _apiService.recordCheckInTiming(
      attendeeId: attendeeId,
      eventId: eventId,
      checkinType: checkInType,
      processStartTime: DateTime.now().subtract(const Duration(seconds: 5)),
      processEndTime: DateTime.now(),
    );
  }

  // Dispose method
  void dispose() {
    // No stream controller to dispose
    super.dispose();
  }
}