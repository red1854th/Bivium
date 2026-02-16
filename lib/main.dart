import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/home/home_page.dart';
import 'core/theme.dart';
import 'core/locales.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/google_drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await EasyLocalization.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final driveService = GoogleDriveService();

  // 1. 로컬 저장소 값 확인 (로그인 의향 플래그)
  bool isLoggedInFlag = prefs.getBool('is_logged_in') ?? false;

  debugPrint("초기 로그인 의향 상태: $isLoggedInFlag");

  runApp(
    EasyLocalization(
      supportedLocales: AppLocale.locales,
      path: 'assets/localization',
      fallbackLocale: const Locale('en', 'US'),
      child: BiviumApp(
        prefs: prefs,
        driveService: driveService,
        initialAuth: isLoggedInFlag,
      ),
    ),
  );

  // [핵심] 앱 실행 후 백그라운드에서 세션 복구 시도
  if (isLoggedInFlag) {
    // Web/App 모두 드라이버 서비스가 알아서 처리하도록 위임
    driveService.signInSilentlyCheck();
  }
}

class BiviumApp extends StatefulWidget {
  final SharedPreferences prefs;
  final GoogleDriveService driveService;
  final bool initialAuth;

  const BiviumApp({
    super.key,
    required this.prefs,
    required this.driveService,
    required this.initialAuth,
  });

  @override
  State<BiviumApp> createState() => _BiviumAppState();
}

class _BiviumAppState extends State<BiviumApp> {
  bool _isDarkMode = false;
  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs;
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final isDark = ThemeService.isDarkMode(_prefs);
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
        driveService: widget.driveService,
        initialAuth: widget.initialAuth,
      ),
    );
  }
}
