import 'package:flutter/material.dart';

class AppLocale {
  final Locale locale;
  final String displayName;

  const AppLocale(this.locale, this.displayName);

  static const List<AppLocale> supported = [
    AppLocale(Locale('ko', 'KR'), '한국어'),
    AppLocale(Locale('en', 'US'), 'English'),
    AppLocale(Locale('ja', 'JP'), '日本語'),
    AppLocale(Locale('zh', 'CN'), '简体中文'),
  ];

  static List<Locale> get locales => supported.map((e) => e.locale).toList();
}
