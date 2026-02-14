import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/services/google_drive_service.dart';

import '../../core/theme.dart';
import '../../models/flashcard.dart';
import 'tabs/items_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/glossary_tab.dart';
import 'package:bivium/features/home/edit_project_page.dart';
import 'package:bivium/features/detail/edit_card_page.dart';

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
  int _currentIndex = 0; // 하단 탭 인덱스
  int _currentCardPageIndex = 0; // 현재 선택된 카드 리스트 인덱스

  final PageController _pageController = PageController();
  final ScrollController _itemsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _itemsScrollController.dispose();
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

  void _updateLocalCards(List<Flashcard>? updatedList) {
    if (updatedList != null && mounted) {
      setState(() {
        cards = List<Flashcard>.from(updatedList);
      });
    }
  }

  /// 카드 편집 페이지 이동 및 결과 처리 (개편된 로직)
  void _goToEditPage(int index) async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => EditCardPage(
          cards: cards,
          initialCardIndex: index,
          setInfo: widget.setInfo,
          driveService: widget.driveService,
        ),
      ),
    );

    if (result == null || !mounted) return;

    // 데이터 및 마지막 인덱스 상태 갱신
    setState(() {
      if (result['cards'] != null) {
        cards = List<Flashcard>.from(result['cards']);
      }
      if (result['lastIndex'] != null) {
        _currentCardPageIndex = result['lastIndex'];
      }
    });

    // 갱신된 인덱스로 리스트 스크롤 동기화
    _navigateToCard(_currentCardPageIndex);
  }

  /// 특정 인덱스의 카드로 스크롤 및 탭 이동
  void _navigateToCard(int index) {
    if (index < 0 || index >= cards.length) return;

    // 1. 먼저 리스트 탭(0번)으로 이동
    _onTabTapped(0);

    // 2. 탭 전환 애니메이션 시간을 고려하여 지연 후 스크롤 실행
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_itemsScrollController.hasClients) {
        const double itemHeight = 82.0;
        _itemsScrollController.animateTo(
          index * itemHeight,
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
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
      builder: (context) {
        return Dialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        );
      },
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
                  maxLines: 1,
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
                                fontWeight: FontWeight.w400,
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
                        onCardSelected: _goToEditPage, // 개편된 메서드 연결
                        setInfo: widget.setInfo,
                        driveService: widget.driveService,
                        scrollController: _itemsScrollController,
                        onRefresh: (updatedList) async {
                          _updateLocalCards(updatedList);
                        },
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
