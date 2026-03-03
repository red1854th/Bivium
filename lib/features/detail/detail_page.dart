import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import '../home/edit_project_page.dart';
import 'tabs/items_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/glossary_tab.dart';
import '../../widgets/card_list_common.dart';

class DetailPage extends StatefulWidget {
  final FlashcardSet setInfo;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final List<String> allTitles;
  final GoogleDriveService driveService;

  const DetailPage({
    super.key,
    required this.setInfo,
    required this.onUpdate,
    required this.onDelete,
    required this.allTitles,
    required this.driveService,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<Flashcard> cards = [];
  bool isLoading = true;
  bool isExpanded = false;
  int _currentIndex = 0;
  int _currentCardPageIndex = 0;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    SearchManager().reset();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final List<Flashcard> latest = await widget.driveService.getFlashcards(
        widget.setInfo,
      );

      if (mounted) {
        setState(() {
          cards = latest;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('${'data_load_failed'.tr()}: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 복원 로직 ---

  // --- 복원 로직 ---

  /// 메타데이터 존재 여부 확인
  bool _hasExportMetadata() {
    return widget.setInfo.metadata != null &&
        widget.setInfo.metadata!.containsKey('regex_suffix');
  }

  /// 원본 구조 복원 및 내보내기 핸들러
  void _handleExport() {
    try {
      final meta = widget.setInfo.metadata!;

      // 이스케이프된 제어 문자를 실제 문자로 변환하는 내부 함수
      String decode(dynamic val) {
        if (val == null) return "";
        String s = val.toString();
        return s
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\\', r'\');
      }

      // 1. 각 구성 요소 복원
      final String filePre = decode(meta['file_prefix']);
      final String regPre = decode(meta['regex_prefix']);
      final String s1 = decode(meta['sep1']);
      final String s2 = decode(meta['sep2']);
      final String regSuf = decode(meta['regex_suffix']);
      final String fileSuf = decode(meta['file_suffix']);

      StringBuffer buffer = StringBuffer();

      // 2. 파일 시작부(Header) 작성
      buffer.write(filePre);

      // 3. 카드 데이터 반복 조립
      for (int i = 0; i < cards.length; i++) {
        final card = cards[i];

        // 카드별 접두사 (예: "Q: ")
        buffer.write(regPre);

        // Key 컬럼 복원 (존재 시)
        if (widget.setInfo.keyColIdx != -1) {
          buffer.write(card.key);
          buffer.write(s1);
        }

        // 앞면(Source) 복원
        buffer.write(card.front);

        // 뒷면(Target) 복원 (존재 시)
        if (widget.setInfo.backColIdx != -1) {
          buffer.write(s2);
          buffer.write(card.back);
        }

        // 카드별 접미사 (보통 \n 또는 특정 구분자)
        buffer.write(regSuf);
      }

      // 4. 파일 종료부(Footer) 작성
      buffer.write(fileSuf);

      // 5. 프리뷰 시트 출력
      _showExportSheet(buffer.toString());
    } catch (e) {
      debugPrint("Export Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('export_failed'.tr())));
      }
    }
  }

  /// 복원된 텍스트 프리뷰 및 복사 시트
  void _showExportSheet(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "export_preview".tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('copied_to_clipboard'.tr())),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded),
                  label: Text("copy".tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCard(int index) {
    if (index < 0 || index >= cards.length) return;
    setState(() => _currentCardPageIndex = index);
    _onTabTapped(0);
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showFullDescription(
    BuildContext context,
    Color textColor,
    Color bgColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'description_label'.tr(),
                style: const TextStyle(
                  color: AppColors.cBrand600,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.setInfo.description,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'close'.tr(),
                    style: const TextStyle(color: AppColors.cBrand600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.cDarkBg : AppColors.cBg;
    final Color textColor = isDark ? Colors.white : AppColors.cSlate900;
    final Color subTextColor = isDark ? Colors.white70 : AppColors.cSlate600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: () => setState(() => isExpanded = !isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.setInfo.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                duration: const Duration(milliseconds: 250),
                turns: isExpanded ? 0.5 : 0,
                child: Icon(Icons.expand_more, size: 24, color: textColor),
              ),
            ],
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_hasExportMetadata())
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              onPressed: _handleExport,
              color: AppColors.cBrand600,
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _fetchInitialData,
            color: AppColors.cBrand600,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? 130 : 0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              border: Border(
                bottom: BorderSide(
                  color: isExpanded
                      ? (isDark ? Colors.white10 : Colors.black12)
                      : Colors.transparent,
                ),
              ),
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.setInfo.description.isNotEmpty) {
                            _showFullDescription(context, textColor, bgColor);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'description_label'.tr(),
                              style: const TextStyle(
                                color: AppColors.cBrand600,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.setInfo.description.isEmpty
                                  ? 'no_description_msg'.tr()
                                  : widget.setInfo.description,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(24, -19),
                      child: IconButton(
                        icon: Icon(
                          Icons.settings_outlined,
                          size: 20,
                          color: subTextColor.withValues(alpha: 0.6),
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditProjectPage(
                                set: widget.setInfo,
                                allTitles: widget.allTitles,
                                onUpdate: (newTitle, newDescription) {
                                  setState(() {
                                    widget.setInfo.title = newTitle;
                                    widget.setInfo.description = newDescription;
                                  });
                                  widget.onUpdate();
                                },
                                onDelete: widget.onDelete,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.cBrand600,
                    ),
                  )
                : PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    children: [
                      ItemsTab(
                        cards: cards,
                        currentPageIndex: _currentCardPageIndex,
                        onCardSelected: (index) =>
                            setState(() => _currentCardPageIndex = index),
                        onCardsUpdated: (updatedList, lastIndex) {
                          setState(() {
                            cards = updatedList;
                            _currentCardPageIndex = lastIndex;
                          });
                        },
                        onSetUpdated: () {
                          widget.onUpdate();
                          _fetchInitialData();
                        },
                        setInfo: widget.setInfo,
                        driveService: widget.driveService,
                      ),
                      StatisticsTab(
                        cards: cards,
                        setInfo: widget.setInfo,
                        onCardTap: _navigateToCard,
                      ),
                      GlossaryTab(cards: cards),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: bgColor,
        selectedItemColor: AppColors.cBrand600,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt_rounded),
            label: 'items_tab'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics_outlined),
            label: 'stats_tab'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_stories_outlined),
            label: 'glossary_tab'.tr(),
          ),
        ],
      ),
    );
  }
}
