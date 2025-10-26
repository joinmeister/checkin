import 'package:hive/hive.dart';

part 'brother_printer.g.dart';

/// Brother printer connection types
@HiveType(typeId: 13)
enum PrinterConnectionType {
  @HiveField(0)
  bluetooth,
  @HiveField(1)
  bluetoothLE,
  @HiveField(2)
  wifi,
  @HiveField(3)
  usb,
  @HiveField(4)
  mfi
}

/// Brother printer status
@HiveType(typeId: 14)
enum PrinterStatus {
  @HiveField(0)
  disconnected,
  @HiveField(1)
  connecting,
  @HiveField(2)
  connected,
  @HiveField(3)
  printing,
  @HiveField(4)
  error,
  @HiveField(5)
  lowBattery,
  @HiveField(6)
  outOfLabels,
  @HiveField(7)
  coverOpen
}

/// Print job priority levels
enum JobPriority {
  low,
  normal,
  high,
  urgent
}

/// Print quality settings
enum PrintQuality {
  draft,
  normal,
  high,
  best
}

@HiveType(typeId: 10)
class BrotherPrinter extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String model;

  @HiveField(3)
  final PrinterConnectionType connectionType;

  @HiveField(4)
  final PrinterCapabilities capabilities;

  @HiveField(5)
  final bool isMfiCertified;

  @HiveField(6)
  final String? bluetoothAddress;

  @HiveField(7)
  final String? ipAddress;

  @HiveField(8)
  final PrinterStatus status;

  @HiveField(9)
  final DateTime lastSeen;

  @HiveField(10)
  final Map<String, dynamic> connectionData;

  BrotherPrinter({
    required this.id,
    required this.name,
    required this.model,
    required this.connectionType,
    required this.capabilities,
    required this.isMfiCertified,
    this.bluetoothAddress,
    this.ipAddress,
    required this.status,
    required this.lastSeen,
    required this.connectionData,
  });

  factory BrotherPrinter.fromJson(Map<String, dynamic> json) {
    return BrotherPrinter(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      model: json['model'] ?? '',
      connectionType: PrinterConnectionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['connectionType'],
        orElse: () => PrinterConnectionType.bluetooth,
      ),
      capabilities: PrinterCapabilities.fromJson(json['capabilities'] ?? {}),
      isMfiCertified: json['isMfiCertified'] ?? false,
      bluetoothAddress: json['bluetoothAddress'],
      ipAddress: json['ipAddress'],
      status: PrinterStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PrinterStatus.disconnected,
      ),
      lastSeen: DateTime.tryParse(json['lastSeen'] ?? '') ?? DateTime.now(),
      connectionData: Map<String, dynamic>.from(json['connectionData'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'connectionType': connectionType.toString().split('.').last,
      'capabilities': capabilities.toJson(),
      'isMfiCertified': isMfiCertified,
      'bluetoothAddress': bluetoothAddress,
      'ipAddress': ipAddress,
      'status': status.toString().split('.').last,
      'lastSeen': lastSeen.toIso8601String(),
      'connectionData': connectionData,
    };
  }

  BrotherPrinter copyWith({
    String? id,
    String? name,
    String? model,
    PrinterConnectionType? connectionType,
    PrinterCapabilities? capabilities,
    bool? isMfiCertified,
    String? bluetoothAddress,
    String? ipAddress,
    PrinterStatus? status,
    DateTime? lastSeen,
    Map<String, dynamic>? connectionData,
  }) {
    return BrotherPrinter(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      connectionType: connectionType ?? this.connectionType,
      capabilities: capabilities ?? this.capabilities,
      isMfiCertified: isMfiCertified ?? this.isMfiCertified,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      connectionData: connectionData ?? this.connectionData,
    );
  }

  bool get isConnected => status == PrinterStatus.connected || status == PrinterStatus.printing;
  bool get isAvailable => status != PrinterStatus.error && status != PrinterStatus.outOfLabels;
  String get displayName => name.isNotEmpty ? name : model;
}

@HiveType(typeId: 11)
class PrinterCapabilities extends HiveObject {
  @HiveField(0)
  final List<LabelSize> supportedLabelSizes;

  @HiveField(1)
  final int maxResolutionDpi;

  @HiveField(2)
  final bool supportsColor;

  @HiveField(3)
  final bool supportsCutting;

  @HiveField(4)
  final int maxPrintWidth;

  @HiveField(5)
  final List<String> supportedFormats;

  @HiveField(6)
  final bool supportsBluetooth;

  @HiveField(7)
  final bool supportsWifi;

  @HiveField(8)
  final bool supportsUsb;

  PrinterCapabilities({
    required this.supportedLabelSizes,
    required this.maxResolutionDpi,
    required this.supportsColor,
    required this.supportsCutting,
    required this.maxPrintWidth,
    required this.supportedFormats,
    required this.supportsBluetooth,
    required this.supportsWifi,
    required this.supportsUsb,
  });

  factory PrinterCapabilities.fromJson(Map<String, dynamic> json) {
    return PrinterCapabilities(
      supportedLabelSizes: (json['supportedLabelSizes'] as List<dynamic>?)
          ?.map((e) => LabelSize.fromJson(e))
          .toList() ?? [],
      maxResolutionDpi: json['maxResolutionDpi'] ?? 300,
      supportsColor: json['supportsColor'] ?? false,
      supportsCutting: json['supportsCutting'] ?? true,
      maxPrintWidth: json['maxPrintWidth'] ?? 62,
      supportedFormats: List<String>.from(json['supportedFormats'] ?? ['PNG', 'BMP']),
      supportsBluetooth: json['supportsBluetooth'] ?? true,
      supportsWifi: json['supportsWifi'] ?? false,
      supportsUsb: json['supportsUsb'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supportedLabelSizes': supportedLabelSizes.map((e) => e.toJson()).toList(),
      'maxResolutionDpi': maxResolutionDpi,
      'supportsColor': supportsColor,
      'supportsCutting': supportsCutting,
      'maxPrintWidth': maxPrintWidth,
      'supportedFormats': supportedFormats,
      'supportsBluetooth': supportsBluetooth,
      'supportsWifi': supportsWifi,
      'supportsUsb': supportsUsb,
    };
  }
}

@HiveType(typeId: 12)
class LabelSize extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double widthMm;

  @HiveField(3)
  final double heightMm;

  @HiveField(4)
  final bool isRoll;

  LabelSize({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.isRoll,
  });

  factory LabelSize.fromJson(Map<String, dynamic> json) {
    return LabelSize(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      widthMm: (json['widthMm'] ?? 0).toDouble(),
      heightMm: (json['heightMm'] ?? 0).toDouble(),
      isRoll: json['isRoll'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'isRoll': isRoll,
    };
  }

  String get displaySize => '${widthMm.toInt()}mm x ${heightMm.toInt()}mm';
}

class PrintJob {
  final String id;
  final String printerId;
  final BadgeData badgeData;
  final PrintSettings settings;
  final DateTime createdAt;
  final JobPriority priority;
  final int retryCount;
  final int maxRetries;

  PrintJob({
    required this.id,
    required this.printerId,
    required this.badgeData,
    required this.settings,
    required this.createdAt,
    this.priority = JobPriority.normal,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  PrintJob copyWith({
    String? id,
    String? printerId,
    BadgeData? badgeData,
    PrintSettings? settings,
    DateTime? createdAt,
    JobPriority? priority,
    int? retryCount,
    int? maxRetries,
  }) {
    return PrintJob(
      id: id ?? this.id,
      printerId: printerId ?? this.printerId,
      badgeData: badgeData ?? this.badgeData,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  bool get canRetry => retryCount < maxRetries;
}

class BadgeData {
  final String attendeeId;
  final String attendeeName;
  final String attendeeEmail;
  final String qrCode;
  final String? vipLogoUrl;
  final bool isVip;
  final Map<String, dynamic> templateData;

  BadgeData({
    required this.attendeeId,
    required this.attendeeName,
    required this.attendeeEmail,
    required this.qrCode,
    this.vipLogoUrl,
    required this.isVip,
    required this.templateData,
  });
}

class PrintSettings {
  final LabelSize labelSize;
  final int copies;
  final bool autoCut;
  final PrintQuality quality;
  final bool mirror;
  final int density;
  final bool halfCut;
  
  // Direct Brother SDK connection settings
  final PrinterConnectionType? connectionType;
  final String? bluetoothAddress;
  final String? ipAddress;
  final int? port;
  final bool directPrint; // Skip dialogs and connect directly
  final Duration connectionTimeout;
  final bool autoReconnect;

  PrintSettings({
    required this.labelSize,
    this.copies = 1,
    this.autoCut = true,
    this.quality = PrintQuality.normal,
    this.mirror = false,
    this.density = 5,
    this.halfCut = false,
    // Direct connection settings
    this.connectionType,
    this.bluetoothAddress,
    this.ipAddress,
    this.port,
    this.directPrint = true, // Default to direct printing
    this.connectionTimeout = const Duration(seconds: 10),
    this.autoReconnect = true,
  });

  /// Create settings for direct Bluetooth printing
  factory PrintSettings.bluetooth({
    required LabelSize labelSize,
    required String bluetoothAddress,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) {
    return PrintSettings(
      labelSize: labelSize,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
      connectionType: PrinterConnectionType.bluetooth,
      bluetoothAddress: bluetoothAddress,
      directPrint: true,
    );
  }

  /// Create settings for direct WiFi printing
  factory PrintSettings.wifi({
    required LabelSize labelSize,
    required String ipAddress,
    int port = 9100,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) {
    return PrintSettings(
      labelSize: labelSize,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
      connectionType: PrinterConnectionType.wifi,
      ipAddress: ipAddress,
      port: port,
      directPrint: true,
    );
  }

  /// Create settings for direct MFi printing
  factory PrintSettings.mfi({
    required LabelSize labelSize,
    required String bluetoothAddress,
    int copies = 1,
    PrintQuality quality = PrintQuality.normal,
    int density = 5,
    bool autoCut = true,
  }) {
    return PrintSettings(
      labelSize: labelSize,
      copies: copies,
      quality: quality,
      density: density,
      autoCut: autoCut,
      connectionType: PrinterConnectionType.mfi,
      bluetoothAddress: bluetoothAddress,
      directPrint: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'labelSize': labelSize.toJson(),
      'copies': copies,
      'autoCut': autoCut,
      'quality': quality.toString().split('.').last,
      'mirror': mirror,
      'density': density,
      'halfCut': halfCut,
      // Connection settings
      'connectionType': connectionType?.toString().split('.').last,
      'bluetoothAddress': bluetoothAddress,
      'ipAddress': ipAddress,
      'port': port,
      'directPrint': directPrint,
      'connectionTimeoutMs': connectionTimeout.inMilliseconds,
      'autoReconnect': autoReconnect,
    };
  }

  PrintSettings copyWith({
    LabelSize? labelSize,
    int? copies,
    bool? autoCut,
    PrintQuality? quality,
    bool? mirror,
    int? density,
    bool? halfCut,
    PrinterConnectionType? connectionType,
    String? bluetoothAddress,
    String? ipAddress,
    int? port,
    bool? directPrint,
    Duration? connectionTimeout,
    bool? autoReconnect,
  }) {
    return PrintSettings(
      labelSize: labelSize ?? this.labelSize,
      copies: copies ?? this.copies,
      autoCut: autoCut ?? this.autoCut,
      quality: quality ?? this.quality,
      mirror: mirror ?? this.mirror,
      density: density ?? this.density,
      halfCut: halfCut ?? this.halfCut,
      connectionType: connectionType ?? this.connectionType,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      directPrint: directPrint ?? this.directPrint,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      autoReconnect: autoReconnect ?? this.autoReconnect,
    );
  }

  /// Check if this is a direct connection (no dialogs)
  bool get isDirectConnection => directPrint && connectionType != null;
  
  /// Get connection identifier for logging
  String get connectionIdentifier {
    switch (connectionType) {
      case PrinterConnectionType.bluetooth:
      case PrinterConnectionType.mfi:
        return bluetoothAddress ?? 'Unknown Bluetooth';
      case PrinterConnectionType.wifi:
        return '$ipAddress:${port ?? 9100}';
      case PrinterConnectionType.usb:
        return 'USB Connection';
      default:
        return 'Unknown Connection';
    }
  }
}

class PrintResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final Duration printTime;
  final int labelCount;
  final Map<String, dynamic> additionalData;

  PrintResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    required this.printTime,
    this.labelCount = 1,
    this.additionalData = const {},
  });

  factory PrintResult.success({
    Duration? printTime,
    int labelCount = 1,
    Map<String, dynamic> additionalData = const {},
  }) {
    return PrintResult(
      success: true,
      printTime: printTime ?? Duration.zero,
      labelCount: labelCount,
      additionalData: additionalData,
    );
  }

  factory PrintResult.failure({
    required String errorMessage,
    String? errorCode,
    Duration? printTime,
    Map<String, dynamic> additionalData = const {},
  }) {
    return PrintResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      printTime: printTime ?? Duration.zero,
      additionalData: additionalData,
    );
  }
}