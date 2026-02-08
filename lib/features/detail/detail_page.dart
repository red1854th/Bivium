import 'dart:convert';
import 'package:bivium/services/google_drive_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/utils.dart';
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
    _refreshData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _itemsScrollController.dispose();
    super.dispose();
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

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final id = extractSheetId(widget.setInfo.sheetId);
      final uri = Uri.parse(
        'https://docs.google.com/spreadsheets/d/$id/export?format=csv',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final rawCsv = utf8.decode(res.bodyBytes);
        final parsed = parseCsv(rawCsv);
        final List<Flashcard> latest = [];

        for (int i = 1; i < parsed.length; i++) {
          final row = parsed[i];
          if (row.length > widget.setInfo.frontColIdx) {
            latest.add(
              Flashcard(
                key: row.length > widget.setInfo.keyColIdx
                    ? row[widget.setInfo.keyColIdx]
                    : '',
                front: row[widget.setInfo.frontColIdx],
                back: row[widget.setInfo.backColIdx],
              ),
            );
          }
        }
        if (mounted) {
          setState(() {
            cards = latest;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
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
    // 테마 모드 판별
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = ThemeService.getBackgroundColor(isDark);
    final Color textColor = isDark ? Colors.white : AppColors.cSlate900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
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
            onPressed: _refreshData,
            color: AppColors.cBrand600,
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
