import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/brother_printer.dart';

/// MFi authentication status
enum MFiAuthStatus {
  notRequired,
  required,
  inProgress,
  success,
  failed,
  timeout,
  unsupported
}

/// MFi authentication result
class MFiAuthResult {
  final MFiAuthStatus status;
  final String? errorMessage;
  final String? certificateInfo;
  final Duration? authTime;
  final Map<String, dynamic> additionalData;

  MFiAuthResult({
    required this.status,
    this.errorMessage,
    this.certificateInfo,
    this.authTime,
    this.additionalData = const {},
  });

  bool get isSuccess => status == MFiAuthStatus.success;
  bool get isFailure => status == MFiAuthStatus.failed || status == MFiAuthStatus.timeout;
  bool get isInProgress => status == MFiAuthStatus.inProgress;
}

/// MFi authentication service for iOS Brother printers
class MFiAuthenticationService {
  static final MFiAuthenticationService _instance = MFiAuthenticationService._internal();
  factory MFiAuthenticationService() => _instance;
  MFiAuthenticationService._internal();

  static const MethodChannel _channel = MethodChannel('mfi_authentication');
  
  final StreamController<MFiAuthResult> _authController = StreamController<MFiAuthResult>.broadcast();
  final Map<String, MFiAuthResult> _authCache = {};
  
  bool _isInitialized = false;
  Timer? _timeoutTimer;

  /// Stream of authentication results
  Stream<MFiAuthResult> get authStream => _authController.stream;

  /// Initialize MFi authentication service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 Initializing MFi Authentication Service...');

      if (!Platform.isIOS) {
        debugPrint('⚠️ MFi authentication only available on iOS');
        _isInitialized = true;
        return;
      }

      // Initialize native MFi components
      await _channel.invokeMethod('initialize');

      _isInitialized = true;
      debugPrint('✅ MFi Authentication Service initialized');
    } catch (e) {
      debugPrint('❌ MFi Authentication Service initialization failed: $e');
      rethrow;
    }
  }

  /// Check if MFi authentication is required for a printer
  Future<bool> isAuthenticationRequired(BrotherPrinter printer) async {
    if (!Platform.isIOS) {
      return false;
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if printer is MFi certified
      if (!printer.isMfiCertified) {
        debugPrint('📱 Printer ${printer.displayName} is not MFi certified');
        return false;
      }

      // Check if we have cached auth result
      final cachedResult = _authCache[printer.id];
      if (cachedResult != null && cachedResult.isSuccess) {
        debugPrint('✅ Using cached MFi authentication for ${printer.displayName}');
        return false;
      }

      // Check with native layer
      final result = await _channel.invokeMethod('isAuthRequired', {
        'printerId': printer.id,
        'connectionData': printer.connectionData,
      });

      final required = result as bool? ?? false;
      debugPrint('🔍 MFi authentication required for ${printer.displayName}: $required');
      
      return required;
    } catch (e) {
      debugPrint('❌ Error checking MFi auth requirement: $e');
      return false;
    }
  }

  /// Authenticate with MFi printer
  Future<MFiAuthResult> authenticate(BrotherPrinter printer) async {
    if (!Platform.isIOS) {
      return MFiAuthResult(
        status: MFiAuthStatus.unsupported,
        errorMessage: 'MFi authentication only available on iOS',
      );
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🔐 Starting MFi authentication for: ${printer.displayName}');

      // Check cache first
      final cachedResult = _authCache[printer.id];
      if (cachedResult != null && cachedResult.isSuccess) {
        debugPrint('✅ Using cached MFi authentication');
        return cachedResult;
      }

      final startTime = DateTime.now();

      // Start authentication process
      final authResult = MFiAuthResult(
        status: MFiAuthStatus.inProgress,
      );
      _authController.add(authResult);

      // Set timeout
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        final timeoutResult = MFiAuthResult(
          status: MFiAuthStatus.timeout,
          errorMessage: 'MFi authentication timeout',
          authTime: DateTime.now().difference(startTime),
        );
        _authCache[printer.id] = timeoutResult;
        _authController.add(timeoutResult);
      });

      // Perform authentication
      final result = await _performAuthentication(printer);
      _timeoutTimer?.cancel();

      final authTime = DateTime.now().difference(startTime);
      final finalResult = result.copyWith(authTime: authTime);

      // Cache successful results
      if (finalResult.isSuccess) {
        _authCache[printer.id] = finalResult;
      }

      _authController.add(finalResult);
      debugPrint('🔐 MFi authentication completed for ${printer.displayName}: ${finalResult.status}');

      return finalResult;
    } catch (e) {
      _timeoutTimer?.cancel();
      
      final errorResult = MFiAuthResult(
        status: MFiAuthStatus.failed,
        errorMessage: 'MFi authentication error: $e',
      );
      
      _authController.add(errorResult);
      debugPrint('❌ MFi authentication error for ${printer.displayName}: $e');
      
      return errorResult;
    }
  }

  /// Perform the actual authentication process
  Future<MFiAuthResult> _performAuthentication(BrotherPrinter printer) async {
    try {
      final result = await _channel.invokeMethod('authenticate', {
        'printerId': printer.id,
        'connectionType': printer.connectionType.toString().split('.').last,
        'connectionData': printer.connectionData,
      });

      final resultMap = Map<String, dynamic>.from(result);
      final success = resultMap['success'] as bool? ?? false;

      if (success) {
        return MFiAuthResult(
          status: MFiAuthStatus.success,
          certificateInfo: resultMap['certificateInfo'] as String?,
          additionalData: Map<String, dynamic>.from(resultMap['additionalData'] ?? {}),
        );
      } else {
        return MFiAuthResult(
          status: MFiAuthStatus.failed,
          errorMessage: resultMap['error'] as String? ?? 'Authentication failed',
          additionalData: Map<String, dynamic>.from(resultMap['additionalData'] ?? {}),
        );
      }
    } on PlatformException catch (e) {
      return MFiAuthResult(
        status: MFiAuthStatus.failed,
        errorMessage: 'Platform error: ${e.message}',
        additionalData: {'errorCode': e.code},
      );
    }
  }

  /// Validate MFi certificate
  Future<bool> validateCertificate(BrotherPrinter printer) async {
    if (!Platform.isIOS || !printer.isMfiCertified) {
      return true; // Non-MFi printers don't need validation
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🔍 Validating MFi certificate for: ${printer.displayName}');

      final result = await _channel.invokeMethod('validateCertificate', {
        'printerId': printer.id,
        'connectionData': printer.connectionData,
      });

      final isValid = result as bool? ?? false;
      debugPrint('🔍 MFi certificate validation result: $isValid');

      return isValid;
    } catch (e) {
      debugPrint('❌ MFi certificate validation error: $e');
      return false;
    }
  }

  /// Get MFi authentication status for a printer
  MFiAuthResult? getAuthStatus(String printerId) {
    return _authCache[printerId];
  }

  /// Clear authentication cache for a printer
  void clearAuthCache(String printerId) {
    _authCache.remove(printerId);
    debugPrint('🗑️ Cleared MFi auth cache for printer: $printerId');
  }

  /// Clear all authentication cache
  void clearAllAuthCache() {
    _authCache.clear();
    debugPrint('🗑️ Cleared all MFi auth cache');
  }

  /// Get supported MFi protocols
  Future<List<String>> getSupportedProtocols() async {
    if (!Platform.isIOS) {
      return [];
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _channel.invokeMethod('getSupportedProtocols');
      return List<String>.from(result ?? []);
    } catch (e) {
      debugPrint('❌ Error getting supported MFi protocols: $e');
      return [];
    }
  }

  /// Check if device supports MFi
  Future<bool> isMFiSupported() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('isMFiSupported');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Error checking MFi support: $e');
      return false;
    }
  }

  /// Get MFi authentication statistics
  Map<String, dynamic> getAuthStatistics() {
    final stats = <String, dynamic>{
      'totalAuthentications': _authCache.length,
      'successfulAuthentications': _authCache.values.where((r) => r.isSuccess).length,
      'failedAuthentications': _authCache.values.where((r) => r.isFailure).length,
      'averageAuthTime': _calculateAverageAuthTime(),
      'cacheSize': _authCache.length,
    };

    return stats;
  }

  /// Calculate average authentication time
  double _calculateAverageAuthTime() {
    final authTimes = _authCache.values
        .where((r) => r.authTime != null)
        .map((r) => r.authTime!.inMilliseconds)
        .toList();

    if (authTimes.isEmpty) return 0.0;

    final sum = authTimes.reduce((a, b) => a + b);
    return sum / authTimes.length;
  }

  /// Dispose resources
  void dispose() {
    _timeoutTimer?.cancel();
    _authController.close();
    _authCache.clear();
  }
}

/// Extension for MFiAuthResult
extension MFiAuthResultExtension on MFiAuthResult {
  MFiAuthResult copyWith({
    MFiAuthStatus? status,
    String? errorMessage,
    String? certificateInfo,
    Duration? authTime,
    Map<String, dynamic>? additionalData,
  }) {
    return MFiAuthResult(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      certificateInfo: certificateInfo ?? this.certificateInfo,
      authTime: authTime ?? this.authTime,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}