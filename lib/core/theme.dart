import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const cSlate50 = Color(0xFFF8FAFC);
  static const cSlate100 = Color(0xFFF1F5F9);
  static const cSlate200 = Color(0xFFE2E8F0);
  static const cSlate300 = Color(0xFFCBD5E1);
  static const cSlate400 = Color(0xFF94A3B8);
  static const cSlate500 = Color(0xFF64748B);
  static const cSlate600 = Color(0xFF475569);
  static const cSlate700 = Color(0xFF334155);
  static const cSlate800 = Color(0xFF1E293B);
  static const cSlate900 = Color(0xFF0F172A);

  static const cBrand50 = Color(0xFFE8FBE9);
  static const cBrand100 = Color(0xFFC4F4C7);
  static const cBrand200 = Color(0xFFA5EBAA);
  static const cBrand600 = Color(0xFF5AE361);
  static const cBrand700 = Color(0xFF4BC952);

  static const cGreen100 = Color(0xFFDCFCE7);
  static const cGreen700 = Color(0xFF15803D);
  static const cRed50 = Color(0xFFFEF2F2);
  static const cRed100 = Color(0xFFFEE2E2);
  static const cRed700 = Color(0xFFB91C1C);

  static const cBg = Colors.white;
  static const cSurface = cSlate50;
  static const cBorder = cSlate200;

  // Centralized background colors for unified management
  static const Color lightBackground = Colors.white;
  static const Color darkBackground = Color(0xFF0F172A);

  // Dark mode colors
  static const cDarkBg = Color(0xFF0F172A);
  static const cDarkSurface = Color(0xFF1E293B);
  static const cDarkBorder = Color(0xFF334155);
}

class ThemeService {
  static const _themeKey = 'theme_mode';

  static bool isDarkMode(SharedPreferences prefs) {
    // No longer async, accepts prefs
    return prefs.getBool(_themeKey) ?? false;
  }

  static Future<void> setDarkMode(SharedPreferences prefs, bool isDark) async {
    // Accepts prefs
    await prefs.setBool(_themeKey, isDark);
  }

  // Get background color based on current theme
  static Color getBackgroundColor(bool isDark) {
    return isDark ? AppColors.darkBackground : AppColors.lightBackground;
  }
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.cBrand600,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.cBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.cBrand600,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.cDarkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cDarkSurface,
      surfaceTintColor: AppColors.cDarkSurface,
      elevation: 0,
    ),
  );
}
