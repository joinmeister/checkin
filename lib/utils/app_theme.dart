import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors (matching web app)
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color neutralGray = Color(0xFF6B7280);
  
  // Background Colors
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color cardBackground = Colors.white;
  static const Color surfaceColor = Color(0xFFF3F4F6);
  
  // Text Colors
  static const Color primaryText = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color lightText = Color(0xFF9CA3AF);
  
  // Status Colors
  static const Color liveEventColor = Color(0xFF10B981);
  static const Color upcomingEventColor = Color(0xFF3B82F6);
  static const Color endedEventColor = Color(0xFF6B7280);
  static const Color draftEventColor = Color(0xFFF59E0B);
  
  // Legacy color aliases for compatibility
  static const Color primaryColor = primaryBlue;
  static const Color successColor = successGreen;
  static const Color errorColor = errorRed;
  static const Color warningColor = warningOrange;
  static const Color textColor = primaryText;
  static const Color textSecondaryColor = secondaryText;
  static const Color borderColor = Color(0xFFE5E7EB);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryText,
        elevation: 1,
        shadowColor: Color(0x1A000000),
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x1A000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: neutralGray,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryBlue.withOpacity(0.1),
        labelStyle: const TextStyle(color: primaryText),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: primaryText,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        bodySmall: TextStyle(
          color: secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Scaffold Background
      scaffoldBackgroundColor: backgroundColor,
    );
  }
  
  // Status Badge Colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return liveEventColor;
      case 'upcoming':
        return upcomingEventColor;
      case 'ended':
        return endedEventColor;
      case 'draft':
        return draftEventColor;
      default:
        return neutralGray;
    }
  }
  
  // Status Badge Background Colors (lighter versions)
  static Color getStatusBackgroundColor(String status) {
    return getStatusColor(status).withOpacity(0.1);
  }
}