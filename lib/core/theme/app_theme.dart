import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color primaryNavy = Color(0xFF182A43);
  static const Color accentTeal = Color(0xFF117D72);
  static const Color paleBackground = Color(0xFFF3F6F8);
  static const Color dangerRed = Color(0xFFC65054);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFD6DFE6);
  static const Color textMuted = Color(0xFF5A6E85);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryNavy,
      onPrimary: Colors.white,
      secondary: accentTeal,
      onSecondary: Colors.white,
      error: dangerRed,
      onError: Colors.white,
      surface: surfaceWhite,
      onSurface: primaryNavy,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paleBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accentTeal,
        unselectedItemColor: textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accentTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: dangerRed),
        ),
        isDense: true,
      ),
    );
  }
}
