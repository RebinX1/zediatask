import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Updated to match logo's dark blue/teal theme but keeping white UI
  static const Color primaryColor = Color(0xFF0A3A4A); // Dark teal blue
  static const Color accentColor = Color(0xFF2C5063); // Medium teal blue
  static const Color secondaryColor = Color(0xFF163E52); // Teal blue
  static const Color backgroundColor = Color(0xFF0A1C24); // Very dark blue background
  static const Color contentBackgroundColor = Colors.white; // White background for content areas
  static const Color cardColor = Colors.white; // White card background
  
  // Task priority colors
  static const Color highPriorityColor = Color(0xFFE74C3C); // Red
  static const Color mediumPriorityColor = Color(0xFFF39C12); // Orange
  static const Color lowPriorityColor = Color(0xFF27AE60); // Green
  
  // Task status colors
  static const Color pendingStatusColor = Color(0xFFF39C12); // Orange
  static const Color acceptedStatusColor = Color(0xFF3498DB); // Blue
  static const Color completedStatusColor = Color(0xFF27AE60); // Green
  
  // Text colors
  static const Color textPrimaryColor = Color(0xFF2C3E50); // Dark text for white backgrounds
  static const Color textSecondaryColor = Color(0xFF7F8C8D); // Gray text
  static const Color textLightColor = Color(0xFFBDC3C7); // Light gray
  static const Color textOnDarkColor = Colors.white; // White text for dark backgrounds
  
  // Error and success colors
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF1C40F);
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: contentBackgroundColor,
      surface: cardColor,
      onPrimary: textOnDarkColor,
      onSecondary: textOnDarkColor,
      onBackground: textPrimaryColor,
      onSurface: textPrimaryColor,
    ),
    scaffoldBackgroundColor: contentBackgroundColor,
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: textPrimaryColor),
        displayMedium: TextStyle(color: textPrimaryColor),
        displaySmall: TextStyle(color: textPrimaryColor),
        headlineMedium: TextStyle(color: textPrimaryColor),
        headlineSmall: TextStyle(color: textPrimaryColor),
        titleLarge: TextStyle(color: textPrimaryColor),
        titleMedium: TextStyle(color: textPrimaryColor),
        titleSmall: TextStyle(color: textPrimaryColor),
        bodyLarge: TextStyle(color: textPrimaryColor),
        bodyMedium: TextStyle(color: textPrimaryColor),
        bodySmall: TextStyle(color: textSecondaryColor),
        labelLarge: TextStyle(color: primaryColor),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: textLightColor),
      labelStyle: const TextStyle(color: textSecondaryColor),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
    ),
    iconTheme: const IconThemeData(
      color: primaryColor,
    ),
  );

  // Task priority color
  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return highPriorityColor;
      case 'medium':
        return mediumPriorityColor;
      case 'low':
        return lowPriorityColor;
      default:
        return mediumPriorityColor;
    }
  }

  // Task status color
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return pendingStatusColor;
      case 'accepted':
        return acceptedStatusColor;
      case 'completed':
        return completedStatusColor;
      default:
        return pendingStatusColor;
    }
  }
} 