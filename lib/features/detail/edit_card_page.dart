import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'card_editor.dart';
import 'package:bivium/widgets/card_jump_dialog.dart';

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
  Axis _scrollDirection = Axis.horizontal;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialCardIndex.clamp(
      0,
      widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 데이터 변경 사항을 구글 드라이브(시트)에 저장
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
        .catchError((e) => debugPrint('${'background_save_failed'.tr()}: $e'));
  }

  /// 이전 화면(DetailPage)으로 돌아갈 때 데이터와 인덱스를 전달
  void _handlePop() {
    // 키보드 포커스 해제 (먹통 방지 핵심)
    FocusScope.of(context).unfocus();

    // 현재 페이지 변경사항 저장
    _saveChanges(_currentPageIndex);

    if (mounted) {
      // DetailPage의 Navigator.push가 기다리는 결과값(result) 반환
      Navigator.of(
        context,
      ).pop({'cards': widget.cards, 'lastIndex': _currentPageIndex});
    }
  }

  void _showCardJumpDialog() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? hasChanges = await showDialog<bool>(
      context: context,
      barrierColor: isDark ? Colors.white10 : Colors.black45,
      builder: (context) {
        return CardJumpDialog(
          cards: widget.cards,
          currentPageIndex: _currentPageIndex,
          onCardSelected: (index) {
            _pageController.jumpToPage(index);
          },
          setInfo: widget.setInfo,
          driveService: widget.driveService,
        );
      },
    );

    // 다이얼로그에서 폴더 접기/펼치기 변경이 있었다면 UI 갱신
    if (hasChanges == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // 시스템 뒤로가기를 수동으로 제어
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate50,
        appBar: AppBar(
          toolbarHeight: 40,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handlePop,
          ),
          title: InkWell(
            onTap: _showCardJumpDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                '${_currentPageIndex + 1}/${widget.cards.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _scrollDirection == Axis.horizontal
                    ? Icons.swap_vert_rounded
                    : Icons.swap_horiz_rounded,
                size: 22,
              ),
              onPressed: () => setState(
                () => _scrollDirection = _scrollDirection == Axis.horizontal
                    ? Axis.vertical
                    : Axis.horizontal,
              ),
            ),
            const SizedBox(width: 8),
          ],
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: _scrollDirection,
                itemCount: widget.cards.length,
                onPageChanged: (idx) {
                  _saveChanges(_currentPageIndex); // 이전 페이지 저장
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
              _buildEdgeHandle(isLeft: true),
              _buildEdgeHandle(isLeft: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle({required bool isLeft}) {
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: 40,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (MediaQuery.of(context).viewInsets.bottom == 0) {
            if (isLeft && _currentPageIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (!isLeft && _currentPageIndex < widget.cards.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        },
      ),
    );
  }
}
