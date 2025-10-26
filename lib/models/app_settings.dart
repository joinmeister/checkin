import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings {
  @HiveField(0)
  final bool isDirectPrintingEnabled;
  
  @HiveField(1)
  final int printTimeoutSeconds;
  
  @HiveField(2)
  final String? defaultPrinter;
  
  @HiveField(3)
  final bool enableHapticFeedback;
  
  @HiveField(4)
  final bool enableSoundEffects;
  
  @HiveField(5)
  final bool enableOfflineMode;
  
  @HiveField(6)
  final DateTime? lastSyncTime;
  
  @HiveField(7)
  final String? selectedEventId;
  
  @HiveField(8)
  final int selectedTabIndex;

  AppSettings({
    this.isDirectPrintingEnabled = true,
    this.printTimeoutSeconds = 15,
    this.defaultPrinter,
    this.enableHapticFeedback = true,
    this.enableSoundEffects = false,
    this.enableOfflineMode = true,
    this.lastSyncTime,
    this.selectedEventId,
    this.selectedTabIndex = 0,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isDirectPrintingEnabled: json['isDirectPrintingEnabled'] as bool? ?? true,
      printTimeoutSeconds: json['printTimeoutSeconds'] as int? ?? 15,
      defaultPrinter: json['defaultPrinter'] as String?,
      enableHapticFeedback: json['enableHapticFeedback'] as bool? ?? true,
      enableSoundEffects: json['enableSoundEffects'] as bool? ?? false,
      enableOfflineMode: json['enableOfflineMode'] as bool? ?? true,
      lastSyncTime: json['lastSyncTime'] != null 
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      selectedEventId: json['selectedEventId'] as String?,
      selectedTabIndex: json['selectedTabIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isDirectPrintingEnabled': isDirectPrintingEnabled,
      'printTimeoutSeconds': printTimeoutSeconds,
      'defaultPrinter': defaultPrinter,
      'enableHapticFeedback': enableHapticFeedback,
      'enableSoundEffects': enableSoundEffects,
      'enableOfflineMode': enableOfflineMode,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'selectedEventId': selectedEventId,
      'selectedTabIndex': selectedTabIndex,
    };
  }

  AppSettings copyWith({
    bool? isDirectPrintingEnabled,
    int? printTimeoutSeconds,
    String? defaultPrinter,
    bool? enableHapticFeedback,
    bool? enableSoundEffects,
    bool? enableOfflineMode,
    DateTime? lastSyncTime,
    String? selectedEventId,
    int? selectedTabIndex,
  }) {
    return AppSettings(
      isDirectPrintingEnabled: isDirectPrintingEnabled ?? this.isDirectPrintingEnabled,
      printTimeoutSeconds: printTimeoutSeconds ?? this.printTimeoutSeconds,
      defaultPrinter: defaultPrinter ?? this.defaultPrinter,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableSoundEffects: enableSoundEffects ?? this.enableSoundEffects,
      enableOfflineMode: enableOfflineMode ?? this.enableOfflineMode,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      selectedEventId: selectedEventId ?? this.selectedEventId,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
    );
  }

  // Helper method to check if settings are valid
  bool get isValid {
    return printTimeoutSeconds >= 5 && printTimeoutSeconds <= 30;
  }

  // Helper method to get formatted last sync time
  String? get formattedLastSyncTime {
    if (lastSyncTime == null) return null;
    
    final now = DateTime.now();
    final diff = now.difference(lastSyncTime!);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  // Legacy getter aliases for compatibility
  bool get directPrinting => isDirectPrintingEnabled;
  int get printTimeout => printTimeoutSeconds;
  bool get hapticFeedback => enableHapticFeedback;
  bool get soundEffects => enableSoundEffects;
  bool get offlineMode => enableOfflineMode;

  @override
  String toString() {
    return 'AppSettings(directPrint: $isDirectPrintingEnabled, timeout: $printTimeoutSeconds, haptic: $enableHapticFeedback)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.isDirectPrintingEnabled == isDirectPrintingEnabled &&
        other.printTimeoutSeconds == printTimeoutSeconds &&
        other.defaultPrinter == defaultPrinter &&
        other.enableHapticFeedback == enableHapticFeedback &&
        other.enableSoundEffects == enableSoundEffects &&
        other.enableOfflineMode == enableOfflineMode &&
        other.selectedEventId == selectedEventId &&
        other.selectedTabIndex == selectedTabIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      isDirectPrintingEnabled,
      printTimeoutSeconds,
      defaultPrinter,
      enableHapticFeedback,
      enableSoundEffects,
      enableOfflineMode,
      selectedEventId,
      selectedTabIndex,
    );
  }
}