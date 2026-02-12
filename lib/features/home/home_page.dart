import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'add_set_dialog.dart';
import 'setting_page.dart';
import 'package:bivium/features/detail/detail_page.dart';
import 'package:bivium/features/home/edit_project_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:styled_text/styled_text.dart';

List<FlashcardSet> _parseFlashcardSets(String setsJson) {
  final List<dynamic> decoded = jsonDecode(setsJson);
  return decoded.map((item) => FlashcardSet.fromJson(item)).toList();
}

class HomePage extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs;

  const HomePage({super.key, this.onThemeChanged, required this.prefs});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FlashcardSet> _sets = [];
  bool _isLoading = true;
  late final GoogleDriveService _driveService;
  late final SharedPreferences _prefs;
  int? _lastViewedIndex;

  @override
  void initState() {
    super.initState();
    _driveService = GoogleDriveService();
    _prefs = widget.prefs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _showEasterEgg() async {
    try {
      if (!mounted) return;
      final String currentLocale = context.locale.toString().replaceFirst(
        '_',
        '-',
      );

      final String fixedRes = await rootBundle.loadString(
        'assets/data/quotes.json',
      );
      if (!mounted) return;

      final Map<String, dynamic> fixedJson = json.decode(fixedRes);
      final List<dynamic> fixedBlocks = fixedJson['quotes'] ?? [];

      List<dynamic> langBlocks = [];
      try {
        final String langPath = 'assets/data/quotes_$currentLocale.json';
        final String langRes = await rootBundle.loadString(langPath);

        if (!mounted) return;

        final Map<String, dynamic> langJson = json.decode(langRes);
        langBlocks = langJson['lang_quotes'] ?? [];
      } catch (e) {
        debugPrint(
          "Language file ($currentLocale) load failed, trying en-US: $e",
        );

        // 현재 로케일이 en-US가 아닐 때만 기본값으로 en-US 로드 시도
        if (currentLocale != 'en-US') {
          try {
            final String fallbackRes = await rootBundle.loadString(
              'assets/data/quotes_en-US.json',
            );
            if (!mounted) return;
            final Map<String, dynamic> fallbackJson = json.decode(fallbackRes);
            langBlocks = fallbackJson['lang_quotes'] ?? [];
          } catch (fallbackError) {
            debugPrint("Fallback en-US load failed: $fallbackError");
          }
        }
      }

      if (fixedBlocks.isEmpty) return;
      if (!mounted) return;

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

        // 원문과 번역문이 동일하면 translation을 비움 (중복 출력 방지)
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
                        child: Image.asset(
                          'assets/icon/app_logo.png',
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
                      // translation이 비어있지 않을 때만 출력
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

  // ... (이하 _buildQuotationText, _loadData, _saveData, build 등 기존 코드와 동일)

  Widget _buildQuotationText(
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

  String uniquifyTitle(String title, List<String> existingTitles) {
    if (!existingTitles.contains(title)) return title;
    int counter = 1;
    String newTitle = "$title ($counter)";
    while (existingTitles.contains(newTitle)) {
      counter++;
      newTitle = "$title ($counter)";
    }
    return newTitle;
  }

  Future<void> _loadData() async {
    final String? setsJson = _prefs.getString('flashcard_sets');
    if (setsJson != null) {
      final List<FlashcardSet> loadedSets = await compute(
        _parseFlashcardSets,
        setsJson,
      );
      loadedSets.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
      if (!mounted) return;
      setState(() {
        _sets = loadedSets;
        _isLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    final String encoded = jsonEncode(_sets.map((s) => s.toJson()).toList());
    await _prefs.setString('flashcard_sets', encoded);
    await _prefs.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showEasterEgg,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icon/app_logo.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 12),
                        StyledText(
                          text: "app_name".tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                          tags: {
                            'sub': StyledTextTag(
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.cSlate900.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingPage(
                            service: _driveService,
                            onThemeChanged: widget.onThemeChanged,
                            prefs: _prefs,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    "projects".tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cSlate900,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 48,
                            color: isDark
                                ? AppColors.cSlate600
                                : AppColors.cSlate300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "no_projects".tr(),
                            style: TextStyle(color: AppColors.cSlate400),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAddDialog(context),
                            child: Text("create_first".tr()),
                          ),
                        ],
                      ),
                    )
                  : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _sets.length,
      itemBuilder: (context, index) {
        final s = _sets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _navigateToDetail(s, index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cDarkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cBrand50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: AppColors.cBrand600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${"last_synced".tr()}: ${s.lastSynced.month}/${s.lastSynced.day}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.cSlate400
                                : AppColors.cSlate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.cSlate400,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProjectPage(
                            set: s,
                            allTitles: _sets.map((e) => e.title).toList(),
                            onUpdate: (t, d) {
                              setState(() {
                                s.title = t;
                                s.description = d;
                              });
                              _saveData();
                            },
                            onDelete: () {
                              setState(() {
                                _sets.removeWhere((item) => item.id == s.id);
                              });
                              _saveData();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToDetail(FlashcardSet s, int index) async {
    setState(() => _sets[index].lastAccessed = DateTime.now());
    await _saveData();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          setInfo: s,
          allTitles: _sets.map((e) => e.title).toList(),
          onUpdate: () => _saveData(),
          onDelete: () {
            setState(() {
              _sets.removeWhere((item) => item.id == s.id);
            });
            _saveData();
          },
          driveService: _driveService,
        ),
      ),
    );
    setState(() {
      _sets.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    });
  }

  void _showAddDialog(BuildContext context) {
    final titles = _sets.map((s) => s.title).toList();
    showDialog(
      context: context,
      builder: (_) => AddSetDialog(
        onAdd: (n) {
          n.title = uniquifyTitle(n.title, titles);
          setState(() => _sets.add(n));
          _saveData();
        },
        allTitles: titles,
        driveService: _driveService,
      ),
    );
  }
}
