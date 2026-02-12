import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/locales.dart';
import '../../services/google_drive_service.dart';

class SettingPage extends StatefulWidget {
  final GoogleDriveService service;
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs;

  const SettingPage({
    super.key,
    required this.service,
    this.onThemeChanged,
    required this.prefs,
  });

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoading = true;
  GoogleSignInAccount? _account;
  bool _isDarkMode = false;
  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs;
    _loadAccount();
    _loadThemeMode();
  }

  Future<void> _loadAccount() async {
    setState(() => _isLoading = true);
    final account = await widget.service.signInSilently();
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _loadThemeMode() {
    final isDark = ThemeService.isDarkMode(_prefs);
    setState(() {
      _isDarkMode = isDark;
    });
    return Future.value();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final account = await widget.service.signIn();
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    await widget.service.signOut();
    setState(() {
      _account = null;
      _isLoading = false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    await ThemeService.setDarkMode(_prefs, value);
    widget.onThemeChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        surfaceTintColor: ThemeService.getBackgroundColor(isDark),
        elevation: 0,
        title: Text(
          'settings'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 다크 모드 설정
                  _buildSettingTile(
                    isDark,
                    icon: Icons.dark_mode,
                    label: 'dark_mode'.tr(),
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: _toggleDarkMode,
                      activeThumbColor: AppColors.cBrand600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 언어 설정 (AppLocale 활용)
                  _buildSettingTile(
                    isDark,
                    icon: Icons.language,
                    label: 'language_settings'.tr(),
                    trailing: DropdownButton<Locale>(
                      value: context.locale,
                      onChanged: (Locale? newLocale) {
                        if (newLocale != null) context.setLocale(newLocale);
                      },
                      underline: const SizedBox(),
                      // AppLocale.supported 리스트를 직접 사용하여 UI 구성
                      items: AppLocale.supported.map((appLocale) {
                        return DropdownMenuItem(
                          value: appLocale.locale,
                          child: Text(
                            appLocale.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.cSlate900,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'account'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 계정 정보 섹션
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _tileDecoration(isDark),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark
                              ? AppColors.cSlate700
                              : AppColors.cSlate100,
                          backgroundImage: account?.photoUrl != null
                              ? NetworkImage(account!.photoUrl!)
                              : null,
                          child: account?.photoUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: isDark
                                      ? AppColors.cSlate400
                                      : AppColors.cSlate600,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account?.displayName ?? 'not_signed_in'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.cSlate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account?.email ?? 'sign_in_desc'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.cSlate400
                                      : AppColors.cSlate500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 로그인/로그아웃 버튼
                  SizedBox(
                    width: double.infinity,
                    child: account == null
                        ? ElevatedButton(
                            onPressed: _signIn,
                            style: _buttonStyle(isDark, isPrimary: true),
                            child: Text(
                              'sign_in_with_google'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _signOut,
                            style: _buttonStyle(isDark, isPrimary: false),
                            child: Text(
                              'sign_out'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingTile(
    bool isDark, {
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _tileDecoration(isDark),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : AppColors.cSlate600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.cSlate900,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  BoxDecoration _tileDecoration(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.cDarkSurface : Colors.white,
    border: Border.all(
      color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
    ),
    borderRadius: BorderRadius.circular(12),
  );

  ButtonStyle _buttonStyle(bool isDark, {required bool isPrimary}) {
    if (isPrimary) {
      return ElevatedButton.styleFrom(
        backgroundColor: AppColors.cBrand600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: isDark ? Colors.white : AppColors.cSlate900,
      side: BorderSide(
        color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
