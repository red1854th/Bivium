import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme.dart';

class GoogleLoginPage extends StatefulWidget {
  final VoidCallback onLoginPressed;

  const GoogleLoginPage({super.key, required this.onLoginPressed});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  bool _isLoading = false; // 로딩 상태 추가

  void _handlePress() {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    widget.onLoginPressed();

    // 비정상적인 중단 상황을 대비해 일정 시간 후 로딩 해제 (옵션)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cBrand50.withValues(
                    alpha: isDark ? 0.1 : 1.0,
                  ),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icon/app_logo.svg',
                  colorFilter: ColorFilter.mode(
                    isDark ? AppColors.cBrand600 : AppColors.cBrand700,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // App Title
              Text(
                "app_name".tr(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.cSlate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Welcome Message
              Text(
                "welcome_message".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading
                        ? AppColors.cSlate300
                        : AppColors.cBrand600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 가능하면 Google G 로고 SVG를 사용하는 것을 추천드립니다.
                            const Icon(Icons.login_rounded),
                            const SizedBox(width: 12),
                            Text(
                              'sign_in_with_google'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
