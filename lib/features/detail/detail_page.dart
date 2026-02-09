import 'package:bivium/services/google_drive_service.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import 'tabs/items_tab.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/glossary_tab.dart';

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
  int _currentIndex = 0;

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

  /// 초기 데이터 로드 (네트워크 호출)
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
      debugPrint('데이터 로드 실패: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// 로컬 상태 업데이트 (수정 페이지에서 돌아올 때 호출됨)
  void _updateLocalCards(List<Flashcard>? updatedList) {
    if (updatedList != null && mounted) {
      setState(() {
        // 깊은 복사를 통해 참조를 끊고 새 리스트 할당
        cards = List<Flashcard>.from(updatedList);
      });
    }
  }

  void _navigateToCard(int index) {
    if (index < 0 || index >= cards.length) return;
    _onTabTapped(0);
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.cDarkBg : AppColors.cBg;
    final Color textColor = isDark ? Colors.white : AppColors.cSlate900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.setInfo.title,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.onDelete(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cBrand600),
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              children: [
                ItemsTab(
                  cards: cards,
                  setInfo: widget.setInfo,
                  driveService: widget.driveService,
                  scrollController: _itemsScrollController,
                  // [중요] 수정 완료 후 리스트를 전달받아 UI를 갱신함
                  onRefresh: (updatedList) => _updateLocalCards(updatedList),
                ),
                StatisticsTab(
                  cards: cards,
                  setInfo: widget.setInfo,
                  onCardTap: _navigateToCard,
                ),
                GlossaryTab(cards: cards),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: bgColor,
        selectedItemColor: AppColors.cBrand600,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Items'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Glossary'),
        ],
      ),
    );
  }
}
