import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'features/home/home_page.dart';
import 'core/theme.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final SharedPreferences prefs = await SharedPreferences.getInstance(); // Initialize once
  runApp(BiviumApp(prefs: prefs)); // Pass prefs to BiviumApp
  FlutterNativeSplash.remove(); // Dismiss splash screen as soon as the app starts rendering
}

class BiviumApp extends StatefulWidget {
  final SharedPreferences prefs; // Add this field
  const BiviumApp({super.key, required this.prefs}); // Modify constructor

  @override
  State<BiviumApp> createState() => _BiviumAppState();
}

class _BiviumAppState extends State<BiviumApp> {
  bool _isDarkMode = false;
  late final SharedPreferences _prefs; // Declare prefs

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs; // Initialize prefs from widget
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    // Pass the initialized prefs instance to ThemeService
    final isDark = ThemeService.isDarkMode(_prefs); // No await
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  Future<void> _refreshTheme() async {
    await _loadThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bivium',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(onThemeChanged: _refreshTheme, prefs: _prefs), // Pass prefs to HomePage
    );
  }
}