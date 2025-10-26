import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'providers/event_provider.dart';
import 'providers/attendee_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/badge_provider.dart';
import 'screens/event_selection_screen.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'models/brother_printer.dart';

// Global navigator key for showing dialogs from providers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Catch all errors during initialization
  runZonedGuarded(() async {
    print('🚀 APP: Starting initialization...');
    
    WidgetsFlutterBinding.ensureInitialized();
    print('✅ APP: Flutter binding initialized');
    
    String? initError;
    
    try {
      // Initialize Hive for local storage
      print('📦 APP: Initializing Hive...');
      await Hive.initFlutter();
      print('✅ APP: Hive initialized');
      
      // Register Hive adapters for Brother printer models
      print('🔧 APP: Registering Hive adapters...');
      Hive.registerAdapter(BrotherPrinterAdapter());
      print('✅ APP: BrotherPrinterAdapter registered');
      
      Hive.registerAdapter(PrinterCapabilitiesAdapter());
      print('✅ APP: PrinterCapabilitiesAdapter registered');
      
      Hive.registerAdapter(LabelSizeAdapter());
      print('✅ APP: LabelSizeAdapter registered');
      
      Hive.registerAdapter(PrinterConnectionTypeAdapter());
      print('✅ APP: PrinterConnectionTypeAdapter registered');
      
      Hive.registerAdapter(PrinterStatusAdapter());
      print('✅ APP: PrinterStatusAdapter registered');
      
      // Initialize SharedPreferences
      print('💾 APP: Initializing SharedPreferences...');
      await SharedPreferences.getInstance();
      print('✅ APP: SharedPreferences initialized');
      
      print('🎉 APP: All initialization complete, launching app...');
    } catch (e, stackTrace) {
      print('❌ APP: Initialization error: $e');
      print('❌ APP: Stack trace: $stackTrace');
      initError = e.toString();
    }
    
    runApp(EventCheckInApp(initializationError: initError));
  }, (error, stackTrace) {
    print('❌ APP: Uncaught error in main: $error');
    print('❌ APP: Stack trace: $stackTrace');
  });
}

class EventCheckInApp extends StatelessWidget {
  final String? initializationError;
  
  const EventCheckInApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    // If there was an initialization error, show error screen
    if (initializationError != null) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: InitializationErrorScreen(error: initializationError!),
      );
    }
    
    // Normal app initialization with error boundary
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating ConnectivityService provider');
          return ConnectivityService();
        }),
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating SyncService provider');
          return SyncService();
        }),
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating EventProvider');
          return EventProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating AttendeeProvider');
          return AttendeeProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating SettingsProvider');
          return SettingsProvider();
        }),
        ChangeNotifierProvider(create: (_) {
          print('🔧 APP: Creating BadgeProvider');
          return BadgeProvider();
        }),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        home: const EventSelectionScreen(),
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        // Global error handler for uncaught widget errors
        builder: (context, widget) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return ErrorDisplayWidget(
              error: errorDetails.exception.toString(),
              stackTrace: errorDetails.stack.toString(),
            );
          };
          return widget ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Error screen shown when app initialization fails
class InitializationErrorScreen extends StatelessWidget {
  final String error;
  
  const InitializationErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 24),
                Text(
                  'App Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'The app encountered an error during startup:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Force restart the app
                    // Note: This is a simplified restart, real restart would require platform channels
                    print('🔄 APP: User requested restart');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check the console for more details',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to display runtime errors
class ErrorDisplayWidget extends StatelessWidget {
  final String error;
  final String stackTrace;
  
  const ErrorDisplayWidget({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Error Occurred'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An error occurred:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: SelectableText(
                error,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stack Trace:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: SelectableText(
                stackTrace,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}