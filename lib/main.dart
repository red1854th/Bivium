import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'features/home/home_page.dart';
import 'core/theme.dart';
import 'core/locales.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 코드 추가
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await EasyLocalization.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocale.locales,
      path: 'assets/localization',
      fallbackLocale: const Locale('en', 'US'),
      child: BiviumApp(prefs: prefs),
    ),
  );

  FlutterNativeSplash.remove();
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
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        onThemeChanged: _refreshTheme,
        prefs: _prefs,
      ), // Pass prefs to HomePage
    );
  }
}
