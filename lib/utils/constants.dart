class AppConstants {
  // App Information
  static const String appName = 'Event Check-In';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const bool isDebugMode = true;
  
  // API Configuration
  static const String baseUrl = 'https://lightslategray-donkey-866736.hostingersite.com';
  static const int apiTimeout = 30000; // 30 seconds
  
  // API Endpoints
  static const String eventsEndpoint = '/events';
  static const String attendeesEndpoint = '/attendees';
  static const String checkInEndpoint = '/checkin';
  static const String walkInEndpoint = '/walkin';
  static const String badgeTemplatesEndpoint = '/badges/templates';
  static const String timingEndpoint = '/checkin-timing';
  
  // Local Storage Keys
  static const String selectedEventKey = 'selected_event_id';
  static const String settingsKey = 'app_settings';
  static const String offlineQueueKey = 'offline_queue';
  static const String lastSyncKey = 'last_sync_timestamp';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // QR Scanner Settings
  static const Duration scanCooldown = Duration(seconds: 2);
  static const int maxRecentScans = 10;
  
  // Print Settings
  static const int defaultPrintTimeout = 15; // seconds
  static const int minPrintTimeout = 5;
  static const int maxPrintTimeout = 30;
  
  // Event Status Colors
  static const Map<String, String> statusColors = {
    'live': '#10B981', // Green
    'upcoming': '#3B82F6', // Blue
    'ended': '#6B7280', // Gray
    'draft': '#F59E0B', // Orange
  };
  
  // Check-in Types
  static const String qrScanType = 'qr_scan';
  static const String walkInType = 'walk_in';
  static const String searchType = 'search';
}

enum CheckInType {
  qrScan,
  walkIn,
  manual,
}

class StorageKeys {
  static const String appSettings = 'app_settings';
}

class ApiConstants {
  static const String baseUrl = AppConstants.baseUrl;
}