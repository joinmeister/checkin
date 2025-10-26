import 'package:flutter/foundation.dart';
import '../models/brother_printer.dart';

/// Brother printer error types
enum BrotherErrorType {
  connection,
  authentication,
  printing,
  hardware,
  configuration,
  permission,
  network,
  unknown
}

/// Brother printer error codes
class BrotherErrorCodes {
  static const String connectionFailed = 'CONNECTION_FAILED';
  static const String connectionTimeout = 'CONNECTION_TIMEOUT';
  static const String connectionLost = 'CONNECTION_LOST';
  static const String authenticationFailed = 'AUTH_FAILED';
  static const String mfiAuthFailed = 'MFI_AUTH_FAILED';
  static const String printFailed = 'PRINT_FAILED';
  static const String printerBusy = 'PRINTER_BUSY';
  static const String outOfLabels = 'OUT_OF_LABELS';
  static const String coverOpen = 'COVER_OPEN';
  static const String lowBattery = 'LOW_BATTERY';
  static const String printerJam = 'PRINTER_JAM';
  static const String invalidSettings = 'INVALID_SETTINGS';
  static const String unsupportedFormat = 'UNSUPPORTED_FORMAT';
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String bluetoothDisabled = 'BLUETOOTH_DISABLED';
  static const String wifiDisconnected = 'WIFI_DISCONNECTED';
  static const String printerNotFound = 'PRINTER_NOT_FOUND';
  static const String sdkError = 'SDK_ERROR';
}

/// Detailed Brother printer error
class BrotherError {
  final BrotherErrorType type;
  final String code;
  final String message;
  final String? technicalDetails;
  final String? userSolution;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final bool isRecoverable;
  final List<String> troubleshootingSteps;

  BrotherError({
    required this.type,
    required this.code,
    required this.message,
    this.technicalDetails,
    this.userSolution,
    this.context = const {},
    DateTime? timestamp,
    this.isRecoverable = true,
    this.troubleshootingSteps = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'BrotherError(type: $type, code: $code, message: $message)';
  }
}

/// Brother printer error handler and troubleshooting guide
class BrotherErrorHandler {
  static final BrotherErrorHandler _instance = BrotherErrorHandler._internal();
  factory BrotherErrorHandler() => _instance;
  BrotherErrorHandler._internal();

  final List<BrotherError> _errorHistory = [];
  static const int _maxErrorHistory = 100;

  /// Parse and categorize Brother printer errors
  BrotherError parseError(
    String errorMessage, {
    String? errorCode,
    Map<String, dynamic> context = const {},
    Exception? originalException,
  }) {
    debugPrint('🔍 Parsing Brother error: $errorMessage (code: $errorCode)');

    final type = _determineErrorType(errorMessage, errorCode);
    final code = errorCode ?? _extractErrorCode(errorMessage);
    final error = _createDetailedError(type, code, errorMessage, context);

    // Add to error history
    _addToHistory(error);

    debugPrint('📋 Categorized as: ${error.type} (${error.code})');
    return error;
  }

  /// Get troubleshooting steps for an error
  List<String> getTroubleshootingSteps(BrotherError error) {
    switch (error.type) {
      case BrotherErrorType.connection:
        return _getConnectionTroubleshootingSteps(error);
      case BrotherErrorType.authentication:
        return _getAuthenticationTroubleshootingSteps(error);
      case BrotherErrorType.printing:
        return _getPrintingTroubleshootingSteps(error);
      case BrotherErrorType.hardware:
        return _getHardwareTroubleshootingSteps(error);
      case BrotherErrorType.configuration:
        return _getConfigurationTroubleshootingSteps(error);
      case BrotherErrorType.permission:
        return _getPermissionTroubleshootingSteps(error);
      case BrotherErrorType.network:
        return _getNetworkTroubleshootingSteps(error);
      default:
        return _getGeneralTroubleshootingSteps();
    }
  }

  /// Get user-friendly error message
  String getUserFriendlyMessage(BrotherError error) {
    switch (error.code) {
      case BrotherErrorCodes.connectionFailed:
        return 'Unable to connect to the Brother printer. Please check that the printer is powered on and within range.';
      case BrotherErrorCodes.connectionTimeout:
        return 'Connection to the printer timed out. The printer may be busy or out of range.';
      case BrotherErrorCodes.connectionLost:
        return 'Connection to the printer was lost. Please check the printer and try reconnecting.';
      case BrotherErrorCodes.authenticationFailed:
        return 'Failed to authenticate with the printer. Please check your printer settings.';
      case BrotherErrorCodes.mfiAuthFailed:
        return 'MFi authentication failed. Please ensure you\'re using a certified Brother printer.';
      case BrotherErrorCodes.printFailed:
        return 'Print job failed. Please check the printer status and try again.';
      case BrotherErrorCodes.printerBusy:
        return 'The printer is currently busy. Please wait and try again.';
      case BrotherErrorCodes.outOfLabels:
        return 'The printer is out of labels. Please replace the label roll and try again.';
      case BrotherErrorCodes.coverOpen:
        return 'The printer cover is open. Please close the cover and try again.';
      case BrotherErrorCodes.lowBattery:
        return 'The printer battery is low. Please charge the printer or connect to power.';
      case BrotherErrorCodes.printerJam:
        return 'There is a paper jam in the printer. Please clear the jam and try again.';
      case BrotherErrorCodes.invalidSettings:
        return 'Invalid printer settings. Please check your label size and print quality settings.';
      case BrotherErrorCodes.unsupportedFormat:
        return 'The image format is not supported by this printer. Please try a different format.';
      case BrotherErrorCodes.permissionDenied:
        return 'Permission denied. Please grant Bluetooth and location permissions in your device settings.';
      case BrotherErrorCodes.bluetoothDisabled:
        return 'Bluetooth is disabled. Please enable Bluetooth in your device settings.';
      case BrotherErrorCodes.wifiDisconnected:
        return 'WiFi is disconnected. Please check your network connection.';
      case BrotherErrorCodes.printerNotFound:
        return 'Brother printer not found. Please ensure the printer is powered on and discoverable.';
      default:
        return error.message;
    }
  }

  /// Get error recovery suggestions
  List<String> getRecoveryActions(BrotherError error) {
    switch (error.code) {
      case BrotherErrorCodes.connectionFailed:
      case BrotherErrorCodes.connectionTimeout:
        return [
          'Check printer power and status',
          'Move closer to the printer',
          'Restart the printer',
          'Try reconnecting',
        ];
      case BrotherErrorCodes.connectionLost:
        return [
          'Check printer connection',
          'Verify network/Bluetooth status',
          'Reconnect to printer',
        ];
      case BrotherErrorCodes.authenticationFailed:
      case BrotherErrorCodes.mfiAuthFailed:
        return [
          'Verify printer compatibility',
          'Check MFi certification',
          'Reset printer settings',
          'Contact support if issue persists',
        ];
      case BrotherErrorCodes.outOfLabels:
        return [
          'Replace label roll',
          'Check label alignment',
          'Close printer cover',
          'Retry printing',
        ];
      case BrotherErrorCodes.coverOpen:
        return [
          'Close printer cover securely',
          'Check for obstructions',
          'Retry printing',
        ];
      case BrotherErrorCodes.lowBattery:
        return [
          'Charge printer battery',
          'Connect to power adapter',
          'Wait for sufficient charge',
          'Retry printing',
        ];
      case BrotherErrorCodes.printerJam:
        return [
          'Turn off printer',
          'Open cover and remove jammed labels',
          'Check label path is clear',
          'Close cover and restart printer',
        ];
      case BrotherErrorCodes.permissionDenied:
        return [
          'Open device Settings',
          'Grant Bluetooth permission',
          'Grant Location permission',
          'Restart the app',
        ];
      case BrotherErrorCodes.bluetoothDisabled:
        return [
          'Open device Settings',
          'Enable Bluetooth',
          'Return to app and retry',
        ];
      default:
        return [
          'Check printer status',
          'Restart the printer',
          'Try reconnecting',
          'Contact support if issue persists',
        ];
    }
  }

  /// Check if error is recoverable
  bool isRecoverable(BrotherError error) {
    switch (error.code) {
      case BrotherErrorCodes.connectionFailed:
      case BrotherErrorCodes.connectionTimeout:
      case BrotherErrorCodes.connectionLost:
      case BrotherErrorCodes.printerBusy:
      case BrotherErrorCodes.outOfLabels:
      case BrotherErrorCodes.coverOpen:
      case BrotherErrorCodes.lowBattery:
      case BrotherErrorCodes.printerJam:
      case BrotherErrorCodes.permissionDenied:
      case BrotherErrorCodes.bluetoothDisabled:
      case BrotherErrorCodes.wifiDisconnected:
        return true;
      case BrotherErrorCodes.authenticationFailed:
      case BrotherErrorCodes.mfiAuthFailed:
      case BrotherErrorCodes.unsupportedFormat:
      case BrotherErrorCodes.sdkError:
        return false;
      default:
        return error.isRecoverable;
    }
  }

  /// Get error history
  List<BrotherError> getErrorHistory() {
    return List.unmodifiable(_errorHistory);
  }

  /// Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
    debugPrint('🗑️ Cleared Brother error history');
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStatistics() {
    final stats = <String, dynamic>{
      'totalErrors': _errorHistory.length,
      'errorsByType': <String, int>{},
      'errorsByCode': <String, int>{},
      'recoverableErrors': 0,
      'recentErrors': 0,
    };

    final recentCutoff = DateTime.now().subtract(const Duration(hours: 24));

    for (final error in _errorHistory) {
      // Count by type
      final typeKey = error.type.toString().split('.').last;
      stats['errorsByType'][typeKey] = (stats['errorsByType'][typeKey] ?? 0) + 1;

      // Count by code
      stats['errorsByCode'][error.code] = (stats['errorsByCode'][error.code] ?? 0) + 1;

      // Count recoverable
      if (error.isRecoverable) {
        stats['recoverableErrors']++;
      }

      // Count recent
      if (error.timestamp.isAfter(recentCutoff)) {
        stats['recentErrors']++;
      }
    }

    return stats;
  }

  /// Determine error type from message and code
  BrotherErrorType _determineErrorType(String message, String? code) {
    final lowerMessage = message.toLowerCase();
    
    if (code != null) {
      switch (code) {
        case BrotherErrorCodes.connectionFailed:
        case BrotherErrorCodes.connectionTimeout:
        case BrotherErrorCodes.connectionLost:
          return BrotherErrorType.connection;
        case BrotherErrorCodes.authenticationFailed:
        case BrotherErrorCodes.mfiAuthFailed:
          return BrotherErrorType.authentication;
        case BrotherErrorCodes.printFailed:
        case BrotherErrorCodes.printerBusy:
          return BrotherErrorType.printing;
        case BrotherErrorCodes.outOfLabels:
        case BrotherErrorCodes.coverOpen:
        case BrotherErrorCodes.lowBattery:
        case BrotherErrorCodes.printerJam:
          return BrotherErrorType.hardware;
        case BrotherErrorCodes.invalidSettings:
        case BrotherErrorCodes.unsupportedFormat:
          return BrotherErrorType.configuration;
        case BrotherErrorCodes.permissionDenied:
        case BrotherErrorCodes.bluetoothDisabled:
          return BrotherErrorType.permission;
        case BrotherErrorCodes.wifiDisconnected:
        case BrotherErrorCodes.printerNotFound:
          return BrotherErrorType.network;
      }
    }

    // Fallback to message analysis
    if (lowerMessage.contains('connection') || lowerMessage.contains('connect')) {
      return BrotherErrorType.connection;
    } else if (lowerMessage.contains('auth') || lowerMessage.contains('mfi')) {
      return BrotherErrorType.authentication;
    } else if (lowerMessage.contains('print') || lowerMessage.contains('job')) {
      return BrotherErrorType.printing;
    } else if (lowerMessage.contains('battery') || lowerMessage.contains('jam') || 
               lowerMessage.contains('cover') || lowerMessage.contains('label')) {
      return BrotherErrorType.hardware;
    } else if (lowerMessage.contains('permission') || lowerMessage.contains('bluetooth')) {
      return BrotherErrorType.permission;
    } else if (lowerMessage.contains('network') || lowerMessage.contains('wifi')) {
      return BrotherErrorType.network;
    } else {
      return BrotherErrorType.unknown;
    }
  }

  /// Extract error code from message
  String _extractErrorCode(String message) {
    // Try to extract error codes from common patterns
    final patterns = [
      RegExp(r'error[:\s]+(\w+)', caseSensitive: false),
      RegExp(r'code[:\s]+(\w+)', caseSensitive: false),
      RegExp(r'\[(\w+)\]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    return 'UNKNOWN_ERROR';
  }

  /// Create detailed error object
  BrotherError _createDetailedError(
    BrotherErrorType type,
    String code,
    String message,
    Map<String, dynamic> context,
  ) {
    return BrotherError(
      type: type,
      code: code,
      message: message,
      technicalDetails: message,
      userSolution: getUserFriendlyMessage(BrotherError(
        type: type,
        code: code,
        message: message,
      )),
      context: context,
      isRecoverable: isRecoverable(BrotherError(
        type: type,
        code: code,
        message: message,
      )),
      troubleshootingSteps: getTroubleshootingSteps(BrotherError(
        type: type,
        code: code,
        message: message,
      )),
    );
  }

  /// Add error to history
  void _addToHistory(BrotherError error) {
    _errorHistory.add(error);
    
    // Keep history size manageable
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  /// Get connection troubleshooting steps
  List<String> _getConnectionTroubleshootingSteps(BrotherError error) {
    return [
      'Verify the printer is powered on and ready',
      'Check that Bluetooth is enabled on your device',
      'Ensure you are within range of the printer (typically 10 meters)',
      'Try turning the printer off and on again',
      'Clear Bluetooth cache in device settings',
      'Forget and re-pair the printer if previously connected',
      'Check for interference from other Bluetooth devices',
    ];
  }

  /// Get authentication troubleshooting steps
  List<String> _getAuthenticationTroubleshootingSteps(BrotherError error) {
    return [
      'Verify the printer supports MFi (Made for iPhone/iPad)',
      'Check that the printer firmware is up to date',
      'Ensure the printer is certified for your device',
      'Try resetting the printer to factory defaults',
      'Contact Brother support for MFi certification issues',
    ];
  }

  /// Get printing troubleshooting steps
  List<String> _getPrintingTroubleshootingSteps(BrotherError error) {
    return [
      'Check that labels are loaded correctly',
      'Verify the label size matches your template',
      'Ensure the printer cover is closed securely',
      'Check for paper jams or obstructions',
      'Verify print quality settings are appropriate',
      'Try printing a test page from the printer menu',
    ];
  }

  /// Get hardware troubleshooting steps
  List<String> _getHardwareTroubleshootingSteps(BrotherError error) {
    return [
      'Check printer status lights for error indicators',
      'Ensure labels are loaded and aligned properly',
      'Verify the printer cover is closed',
      'Check battery level and charge if necessary',
      'Clear any paper jams or obstructions',
      'Clean the print head if print quality is poor',
      'Consult the printer manual for specific error codes',
    ];
  }

  /// Get configuration troubleshooting steps
  List<String> _getConfigurationTroubleshootingSteps(BrotherError error) {
    return [
      'Verify label size settings match your actual labels',
      'Check print quality and density settings',
      'Ensure the image format is supported (PNG, BMP)',
      'Verify the image resolution is appropriate',
      'Check that the template dimensions are correct',
      'Try using default settings first',
    ];
  }

  /// Get permission troubleshooting steps
  List<String> _getPermissionTroubleshootingSteps(BrotherError error) {
    return [
      'Open your device Settings app',
      'Navigate to Apps > Event Check-in > Permissions',
      'Enable Bluetooth permission',
      'Enable Location permission (required for Bluetooth scanning)',
      'Restart the app after granting permissions',
      'Check that Bluetooth is enabled system-wide',
    ];
  }

  /// Get network troubleshooting steps
  List<String> _getNetworkTroubleshootingSteps(BrotherError error) {
    return [
      'Check that your device is connected to WiFi',
      'Verify the printer is on the same network',
      'Check the printer\'s IP address and network settings',
      'Try restarting your WiFi router',
      'Ensure firewall settings allow printer communication',
      'Check for network interference or congestion',
    ];
  }

  /// Get general troubleshooting steps
  List<String> _getGeneralTroubleshootingSteps() {
    return [
      'Restart the Brother printer',
      'Close and reopen the app',
      'Check for app updates',
      'Verify printer compatibility',
      'Contact technical support if the issue persists',
    ];
  }
}