import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
      final String response = await rootBundle.loadString(
        'assets/data/quotes.txt',
      );

      final List<String> blocks = response
          .split('\t\t')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (blocks.isEmpty) return;

      Map<String, String> getRandomQuote() {
        int nextIndex;
        do {
          nextIndex = Random().nextInt(blocks.length);
        } while (nextIndex == _lastViewedIndex && blocks.length > 1);

        _lastViewedIndex = nextIndex;

        final parts = blocks[nextIndex].split('\t');
        return {
          "original": parts.isNotEmpty ? parts[0].trim() : "",
          "translation": parts.length > 1 ? parts[1].trim() : "번역 누락",
          "author": parts.length > 2 ? parts[2].trim() : "작자 미상",
          "extra": parts.length > 3 ? parts[3].trim() : "",
        };
      }

      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
        context: context,
        builder: (context) {
          // 토글 상태 변수 제거 및 데이터 고정
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
                      // 로고 클릭 시에만 새로운 명언 로드
                      GestureDetector(
                        onTap: () => setDialogState(() {
                          currentData = getRandomQuote();
                        }),
                        child: Image.asset(
                          'assets/icon/app_logo.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 원문 (항상 상단 배치)
                      if (currentData['original']!.isNotEmpty)
                        _buildQuotationText(
                          currentData['original']!,
                          isDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),

                      // 번역문 (항상 원문 아래 작게 배치)
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

                      // 저자 및 기타 정보
                      Text(
                        "- ${currentData['author']}",
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
      debugPrint("인용구 로드 실패: $e");
    }
  }

  Widget _buildQuotationText(
    String text,
    bool isDark, {
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    // 1. RTL 언어 감지
    final bool hasRtl = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u0590-\u05FF]',
    ).hasMatch(text);
    // 2. 공백 포함 여부 확인 (중국어, 일본어 등 띄어쓰기 없는 언어 판별)
    final bool hasSpace = text.contains(' ');

    // RTL 언어이거나 띄어쓰기가 없는 언어(중국어, 일본어 등)인 경우
    if (hasRtl || !hasSpace) {
      return SizedBox(
        width: double.infinity,
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: hasRtl ? TextDirection.rtl : TextDirection.ltr,
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

    // 일반적인 띄어쓰기 언어(한국어, 영어 등)인 경우
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4.0,
      runSpacing: 4.0,
      children: text.split(' ').map((word) {
        return Text(
          word,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color ?? (isDark ? Colors.white : AppColors.cSlate900),
            letterSpacing: -0.2,
          ),
        );
      }).toList(),
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
      setState(() {
        _sets = loadedSets;
        _isLoading = false;
      });
    } else {
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
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "BIVIUM",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                            letterSpacing: -0.5,
                          ),
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
                    "PROJECTS",
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
                          const Text(
                            "No projects yet",
                            style: TextStyle(
                              color: AppColors.cSlate400,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAddDialog(context),
                            child: const Text("Create your first project"),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Last synced: ${s.lastSynced.month}/${s.lastSynced.day} ${s.lastSynced.hour}:${s.lastSynced.minute}",
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
                            onUpdate: (newTitle, newDescription) {
                              setState(() {
                                s.title = newTitle;
                                s.description = newDescription;
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
        onAdd: (newSet) {
          newSet.title = uniquifyTitle(newSet.title, titles);
          setState(() => _sets.add(newSet));
          _saveData();
        },
        allTitles: titles,
        driveService: _driveService,
      ),
    );
  }
}
