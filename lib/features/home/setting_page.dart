import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../../core/theme.dart';
import '../../services/google_drive_service.dart';

class SettingPage extends StatefulWidget {
  final GoogleDriveService service;
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs; // Add this field

  const SettingPage({
    super.key,
    required this.service,
    this.onThemeChanged,
    required this.prefs,
  }); // Modify constructor

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoading = true;
  GoogleSignInAccount? _account;
  bool _isDarkMode = false;
  late final SharedPreferences _prefs; // Add this field

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs; // Initialize prefs from widget
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

  Future<void> _loadThemeMode() async {
    final isDark = ThemeService.isDarkMode(_prefs); // Use _prefs, no await
    setState(() {
      _isDarkMode = isDark;
    });
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
    await ThemeService.setDarkMode(_prefs, value); // Pass _prefs
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
          'Settings',
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
                  // Dark Mode Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cDarkSurface : Colors.white,
                      border: Border.all(
                        color: isDark
                            ? AppColors.cDarkBorder
                            : AppColors.cSlate200,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dark_mode,
                          color: isDark ? Colors.white : AppColors.cSlate600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.cSlate900,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isDarkMode,
                          onChanged: _toggleDarkMode,
                          activeThumbColor: AppColors.cBrand600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Account Section
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cDarkSurface : Colors.white,
                      border: Border.all(
                        color: isDark
                            ? AppColors.cDarkBorder
                            : AppColors.cSlate200,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark
                              ? AppColors.cSlate700
                              : AppColors.cSlate100,
                          backgroundImage: (account?.photoUrl != null)
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
                                account?.displayName ?? 'Not signed in',
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
                                account?.email ??
                                    'Sign in to manage your account',
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
                  if (account == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cBrand600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Sign in with Google',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _signOut,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : AppColors.cSlate900,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.cDarkBorder
                                : AppColors.cSlate200,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
