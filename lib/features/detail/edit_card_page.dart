import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'card_editor.dart';

class EditCardPage extends StatefulWidget {
  final List<Flashcard> cards;
  final int initialCardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;

  const EditCardPage({
    super.key,
    required this.cards,
    required this.initialCardIndex,
    required this.setInfo,
    required this.driveService,
  });

  @override
  State<EditCardPage> createState() => _EditCardPageState();
}

class _EditCardPageState extends State<EditCardPage> {
  late PageController _pageController;
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialCardIndex.clamp(
      0,
      widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  void _saveChanges(int index) {
    if (index < 0 || index >= widget.cards.length) return;
    final card = widget.cards[index];
    widget.driveService
        .updateFlashcard(
          spreadsheetId: widget.setInfo.sheetId,
          cardIndex: index,
          setInfo: widget.setInfo,
          card: card,
        )
        .catchError((e) => debugPrint('백그라운드 저장 실패: $e'));
  }

  void _handlePop() {
    FocusManager.instance.primaryFocus?.unfocus();
    _saveChanges(_currentPageIndex);
    if (mounted) Navigator.of(context).pop(widget.cards);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate50,
        appBar: AppBar(
          toolbarHeight: 30,
          leadingWidth: 48,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          leading: Transform.translate(
            offset: const Offset(4, -6),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handlePop,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
          ),
          title: Text(
            '${_currentPageIndex + 1}/${widget.cards.length}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // 메인 카드 뷰
              PageView.builder(
                controller: _pageController,
                itemCount: widget.cards.length,
                onPageChanged: (idx) {
                  _saveChanges(_currentPageIndex);
                  if (mounted) setState(() => _currentPageIndex = idx);
                },
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double page = _pageController.hasClients
                          ? (_pageController.page ?? index.toDouble())
                          : index.toDouble();
                      double angle = (page - index) * (math.pi / 35);
                      return Transform.rotate(
                        angle: angle,
                        child: CardEditor(
                          key: ValueKey(
                            'editor_${widget.cards[index].key}_$index',
                          ),
                          card: widget.cards[index],
                          cardIndex: index,
                          setInfo: widget.setInfo,
                          driveService: widget.driveService,
                        ),
                      );
                    },
                  );
                },
              ),

              // 왼쪽 핸들
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // 키보드가 닫혀 있을 때만(viewInsets.bottom == 0) 작동
                    if (MediaQuery.of(context).viewInsets.bottom == 0 &&
                        _currentPageIndex > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),

              // 오른쪽 핸들
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    // 키보드가 닫혀 있을 때만(viewInsets.bottom == 0) 작동
                    if (MediaQuery.of(context).viewInsets.bottom == 0 &&
                        _currentPageIndex < widget.cards.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
