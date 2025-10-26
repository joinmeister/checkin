import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  String? _error;

  // Getters
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Quick access getters
  bool get directPrintingEnabled => _settings.isDirectPrintingEnabled;
  int get printTimeoutSeconds => _settings.printTimeoutSeconds;
  String? get defaultPrinter => _settings.defaultPrinter;
  bool get hapticFeedbackEnabled => _settings.enableHapticFeedback;
  bool get soundEffectsEnabled => _settings.enableSoundEffects;
  bool get offlineModeEnabled => _settings.enableOfflineMode;
  DateTime? get lastSyncTime => _settings.lastSyncTime;
  String? get selectedEventId => _settings.selectedEventId;
  int get selectedTabIndex => _settings.selectedTabIndex;

  // Initialize settings from SharedPreferences
  Future<void> initializeSettings() async {
    _setLoading(true);
    _setError(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load settings from SharedPreferences
      final settingsJson = prefs.getString(StorageKeys.appSettings);
      if (settingsJson != null) {
        _settings = AppSettings.fromJson(jsonDecode(settingsJson));
      } else {
        // First time launch - save default settings
        await _saveSettings();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load settings: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Update direct printing setting
  Future<void> updateDirectPrinting(bool enabled) async {
    _settings = _settings.copyWith(isDirectPrintingEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }

  // Update print timeout
  Future<void> updatePrintTimeout(int timeoutSeconds) async {
    _settings = _settings.copyWith(printTimeoutSeconds: timeoutSeconds);
    await _saveSettings();
    notifyListeners();
  }

  // Update default printer
  Future<void> updateDefaultPrinter(String? printer) async {
    _settings = _settings.copyWith(defaultPrinter: printer);
    await _saveSettings();
    notifyListeners();
  }

  // Update haptic feedback setting
  Future<void> updateHapticFeedback(bool enabled) async {
    _settings = _settings.copyWith(enableHapticFeedback: enabled);
    await _saveSettings();
    notifyListeners();
  }

  // Update sound effects setting
  Future<void> updateSoundEffects(bool enabled) async {
    _settings = _settings.copyWith(enableSoundEffects: enabled);
    await _saveSettings();
    notifyListeners();
  }

  // Update offline mode setting
  Future<void> updateOfflineMode(bool enabled) async {
    _settings = _settings.copyWith(enableOfflineMode: enabled);
    await _saveSettings();
    notifyListeners();
  }

  // Update last sync time
  Future<void> updateLastSyncTime(DateTime syncTime) async {
    _settings = _settings.copyWith(lastSyncTime: syncTime);
    await _saveSettings();
    notifyListeners();
  }

  // Update selected event ID
  Future<void> updateSelectedEventId(String? eventId) async {
    _settings = _settings.copyWith(selectedEventId: eventId);
    await _saveSettings();
    notifyListeners();
  }

  // Update selected tab index
  Future<void> updateSelectedTabIndex(int tabIndex) async {
    _settings = _settings.copyWith(selectedTabIndex: tabIndex);
    await _saveSettings();
    notifyListeners();
  }

  // Reset settings to defaults
  Future<void> resetToDefaults() async {
    _settings = AppSettings();
    await _saveSettings();
    notifyListeners();
  }

  // Clear all settings
  Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.appSettings);
      _settings = AppSettings();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear settings: ${e.toString()}');
    }
  }

  // Export settings as JSON string
  String exportSettings() {
    return jsonEncode(_settings.toJson());
  }

  // Import settings from JSON string
  Future<bool> importSettings(String jsonString) async {
    try {
      final importedSettings = AppSettings.fromJson(jsonDecode(jsonString));
      _settings = importedSettings;
      await _saveSettings();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to import settings: ${e.toString()}');
      return false;
    }
  }

  // Get available printers (placeholder - would integrate with actual printer discovery)
  Future<List<String>> getAvailablePrinters() async {
    // This would integrate with actual printer discovery APIs
    // For now, return some mock printers
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      'Default Printer',
      'HP LaserJet Pro',
      'Canon PIXMA',
      'Epson EcoTank',
      'Brother HL-L2350DW',
    ];
  }

  // Test printer connection
  Future<bool> testPrinter(String printerName) async {
    try {
      // This would integrate with actual printer testing
      // For now, simulate a test
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success for default printer, random for others
      if (printerName == 'Default Printer') {
        return true;
      }
      
      return DateTime.now().millisecond % 2 == 0;
    } catch (e) {
      return false;
    }
  }

  // Check if settings are valid
  bool get isValid => _settings.isValid;

  // Get validation errors
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (_settings.printTimeoutSeconds < 5) {
      errors.add('Print timeout must be at least 5 seconds');
    }
    
    if (_settings.printTimeoutSeconds > 300) {
      errors.add('Print timeout cannot exceed 5 minutes');
    }
    
    return errors;
  }

  // Private helper methods
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.appSettings, jsonEncode(_settings.toJson()));
    } catch (e) {
      _setError('Failed to save settings: ${e.toString()}');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _setError(null);
  }

  // Legacy method aliases for compatibility
  Future<void> resetSettings() async {
    await resetToDefaults();
  }

  // Badge printing getter
  bool get badgePrintingEnabled => _settings.isDirectPrintingEnabled;
}