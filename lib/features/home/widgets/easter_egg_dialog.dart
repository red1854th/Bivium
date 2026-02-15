import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EasterEggDialog {
  static int? _lastViewedIndex;

  static Future<void> show(BuildContext context) async {
    try {
      final String currentLocale = context.locale.toString().replaceFirst(
        '_',
        '-',
      );

      final String fixedRes = await rootBundle.loadString(
        'assets/data/quotes.json',
      );

      final Map<String, dynamic> fixedJson = json.decode(fixedRes);
      final List<dynamic> fixedBlocks = fixedJson['quotes'] ?? [];

      List<dynamic> langBlocks = [];
      try {
        final String langPath = 'assets/data/quotes_$currentLocale.json';
        final String langRes = await rootBundle.loadString(langPath);

        final Map<String, dynamic> langJson = json.decode(langRes);
        langBlocks = langJson['lang_quotes'] ?? [];
      } catch (e) {
        debugPrint(
          "Language file ($currentLocale) load failed, trying en-US: $e",
        );

        if (currentLocale != 'en-US') {
          try {
            final String fallbackRes = await rootBundle.loadString(
              'assets/data/quotes_en-US.json',
            );
            final Map<String, dynamic> fallbackJson = json.decode(fallbackRes);
            langBlocks = fallbackJson['lang_quotes'] ?? [];
          } catch (fallbackError) {
            debugPrint("Fallback en-US load failed: $fallbackError");
          }
        }
      }

      if (fixedBlocks.isEmpty) return;

      Map<String, String> getRandomQuote() {
        int nextIndex;
        do {
          nextIndex = Random().nextInt(fixedBlocks.length);
        } while (nextIndex == _lastViewedIndex && fixedBlocks.length > 1);
        _lastViewedIndex = nextIndex;

        final fixed = fixedBlocks[nextIndex];
        final lang = (nextIndex < langBlocks.length)
            ? langBlocks[nextIndex]
            : null;

        String original = fixed['original']?.toString() ?? "";
        String translation = lang?['target']?.toString() ?? "";

        if (original.trim() == translation.trim()) {
          translation = "";
        }

        return {
          "original": original,
          "extra": fixed['source']?.toString() ?? "",
          "translation": translation,
          "author": lang?['author']?.toString() ?? "",
        };
      }

      if (!context.mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
        context: context,
        builder: (context) {
          var currentData = getRandomQuote();
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setDialogState(
                          () => currentData = getRandomQuote(),
                        ),
                        child: SvgPicture.asset(
                          'assets/icon/app_logo.svg',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (currentData['original']!.isNotEmpty)
                        _buildQuotationText(
                          currentData['original']!,
                          isDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      if (currentData['translation']!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildQuotationText(
                          currentData['translation']!,
                          isDark,
                          fontSize: 11,
                          color: isDark
                              ? AppColors.cSlate400
                              : AppColors.cSlate500,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        "${currentData['author']}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.cSlate300
                              : AppColors.cSlate700,
                        ),
                      ),
                      if (currentData['extra']!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          currentData['extra']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.cSlate500
                                : AppColors.cSlate400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint("Easter egg error: $e");
    }
  }

  static Widget _buildQuotationText(
    String text,
    bool isDark, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    final bool hasRtl = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u0590-\u05FF]',
    ).hasMatch(text);
    final bool hasSpace = text.contains(' ');
    if (hasRtl || !hasSpace) {
      return SizedBox(
        width: double.infinity,
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: hasRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color ?? (isDark ? Colors.white : AppColors.cSlate900),
            letterSpacing: -0.2,
            height: 1.4,
          ),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4.0,
      runSpacing: 4.0,
      children: text
          .split(' ')
          .map(
            (word) => Text(
              word,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: color ?? (isDark ? Colors.white : AppColors.cSlate900),
                letterSpacing: -0.2,
              ),
            ),
          )
          .toList(),
    );
  }
}
