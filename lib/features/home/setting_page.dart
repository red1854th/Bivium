import 'package:flutter/cupertino.dart'; // Cupertino 스타일 추가
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
    final account = widget.service.currentUser;
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

  // 언어 선택 시트 호출 함수
  void _showLanguagePicker(BuildContext context, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('language_settings'.tr()),
        actions: AppLocale.supported.map((appLocale) {
          final isSelected = context.locale == appLocale.locale;
          return CupertinoActionSheetAction(
            onPressed: () {
              context.setLocale(appLocale.locale);
              Navigator.pop(context);
            },
            // 현재 선택된 언어는 볼드체로 강조
            child: Text(
              appLocale.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.cBrand600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 현재 설정된 언어의 표시 이름 찾기
    final currentLanguageName = AppLocale.supported
        .firstWhere(
          (e) => e.locale == context.locale,
          orElse: () => AppLocale.supported.first,
        )
        .displayName;

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

                  // 언어 설정 (Dropdown 대신 모달 호출 방식)
                  _buildSettingTile(
                    isDark,
                    icon: Icons.language,
                    label: 'language_settings'.tr(),
                    onTap: () => _showLanguagePicker(context, isDark),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentLanguageName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.cSlate400
                                : AppColors.cSlate500,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.cSlate400,
                        ),
                      ],
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

  // InkWell을 추가하여 타일 전체 클릭 가능하게 변경
  Widget _buildSettingTile(
    bool isDark, {
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // vertical 패딩을 줄이거나 조정하여 고정 높이 내에서 중앙 정렬되게 합니다.
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 타일의 최소 높이를 56으로 고정 (Switch의 기본 높이와 유사하게 맞춤)
        constraints: const BoxConstraints(minHeight: 70),
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
            // trailing 위젯이 중앙에 오도록 배치
            Center(child: trailing),
          ],
        ),
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
