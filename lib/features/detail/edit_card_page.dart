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
  final VoidCallback? onSetUpdated;

  const EditCardPage({
    super.key,
    required this.cards,
    required this.initialCardIndex,
    required this.setInfo,
    required this.driveService,
    this.onSetUpdated,
  });

  @override
  State<EditCardPage> createState() => _EditCardPageState();
}

class _EditCardPageState extends State<EditCardPage> {
  late PageController _pageController;
  late int _currentPageIndex;
  Axis _scrollDirection = Axis.horizontal;
  bool _isEditorSettingsOpen = false; // 설정창 열림 상태 추적

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

  void _handlePop() {
    FocusScope.of(context).unfocus();
    _saveChanges(_currentPageIndex);

    if (mounted) {
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

    if (hasChanges == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentPageIndex + 1}/${widget.cards.length}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
                    ),
                  ),
                  if (widget.setInfo.keyColIdx != -1 &&
                      widget.cards[_currentPageIndex].key.isNotEmpty)
                    Text(
                      widget.cards[_currentPageIndex].key,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.0,
                        color:
                            (isDark ? AppColors.cSlate200 : AppColors.cSlate800)
                                .withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
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
              // [레이어 0] 에디터 페이지 뷰를 아래에 배치
              PageView.builder(
                controller: _pageController,
                scrollDirection: _scrollDirection,
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
                          onSetUpdated: widget.onSetUpdated,
                          onSettingsToggle: (isOpen) {
                            setState(() {
                              _isEditorSettingsOpen = isOpen;
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              // [레이어 1] 이동 핸들을 가장 위에 배치 (에디터 위에서 터치를 가로챔)
              if (!_isEditorSettingsOpen) ...[
                _buildEdgeHandle(isLeft: true),
                _buildEdgeHandle(isLeft: false),
              ],
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
        behavior: HitTestBehavior.translucent, // 에디터 위의 투명한 영역에서도 터치 감지
        onTap: () {
          // 키보드가 닫혀있을 때만 작동
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
