import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'card_editor.dart';
import 'package:bivium/widgets/card_jump_dialog.dart';
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';
import 'package:bivium/features/editor/text_editor.dart';

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
  bool _isEditorSettingsOpen = false;
  bool _isVertical = true;
  EditorSettings _settings = EditorSettings(
    fontSize: 19.0,
    lineHeight: 1.4,
    fontFamily: 'Pretendard',
  );

  ZebraHighlightController? _activeController;
  UndoHistoryController? _activeUndoController;
  bool _isFrontActive = true;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialCardIndex.clamp(
      0,
      widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isVertical = prefs.getBool('is_editor_vertical') ?? true;
      _settings = EditorSettings(
        fontSize: prefs.getDouble('editor_font_size') ?? 19.0,
        lineHeight: prefs.getDouble('editor_line_height') ?? 1.4,
        fontFamily: prefs.getString('editor_font_family') ?? 'Pretendard',
      );
    });
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

  void _toggleLayout() async {
    setState(() => _isVertical = !_isVertical);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_editor_vertical', _isVertical);
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
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      scrollDirection: _scrollDirection,
                      itemCount: widget.cards.length,
                      onPageChanged: (idx) {
                        _saveChanges(_currentPageIndex);
                        if (mounted) {
                          setState(() {
                            _currentPageIndex = idx;
                            // 활성 컨트롤러 초기화 (새 카드로 넘어갈 때)
                            _activeController = null;
                            _activeUndoController = null;
                          });
                        }
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
                                isVertical: _isVertical,
                                settings: _settings,
                                onSetUpdated: widget.onSetUpdated,
                                onLayoutToggle: _toggleLayout,
                                onSettingsToggle: () => setState(
                                  () => _isEditorSettingsOpen = true,
                                ),
                                onFocusChanged:
                                    ({
                                      controller,
                                      undoController,
                                      required isFront,
                                    }) {
                                      setState(() {
                                        _activeController = controller;
                                        _activeUndoController = undoController;
                                        _isFrontActive = isFront;
                                      });
                                    },
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (!_isEditorSettingsOpen) ...[
                      _buildEdgeHandle(isLeft: true),
                      _buildEdgeHandle(isLeft: false),
                    ],
                    if (_isEditorSettingsOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _isEditorSettingsOpen = false),
                          child: Container(color: Colors.black45),
                        ),
                      ),
                    EditorSettingsPanel(
                      isVisible: _isEditorSettingsOpen,
                      currentSettings: _settings,
                      card: widget.cards[_currentPageIndex],
                      cardIndex: _currentPageIndex,
                      onSettingsChanged: (s) => setState(() => _settings = s),
                      onClose: () =>
                          setState(() => _isEditorSettingsOpen = false),
                    ),
                  ],
                ),
              ),
              _buildFixedBottomToolbar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFixedBottomToolbar(bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {},
      child: Material(
        elevation: 5,
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              _toolbarAction(
                icon: Icons.undo_rounded,
                color: _activeUndoController?.value.canUndo == true
                    ? AppColors.cBrand600
                    : Colors.grey.withValues(alpha: 0.5),
                onTap: _activeUndoController?.value.canUndo == true
                    ? () => _handleUndo()
                    : null,
              ),
              _toolbarAction(
                icon: Icons.redo_rounded,
                color: _activeUndoController?.value.canRedo == true
                    ? AppColors.cBrand600
                    : Colors.grey.withValues(alpha: 0.5),
                onTap: _activeUndoController?.value.canRedo == true
                    ? () => _activeUndoController?.redo()
                    : null,
              ),
              const VerticalDivider(width: 20, indent: 12, endIndent: 12),
              _toolbarAction(
                icon: Icons.add_box_outlined,
                color: AppColors.cBrand600,
                onTap: () => _insertTag("[ ]"),
              ),

              const Spacer(),

              _toolbarAction(
                icon: Icons.arrow_back_ios_new_rounded,
                color: AppColors.cBrand600,
                onTap: () => _moveCursor(-1),
              ),
              _toolbarAction(
                icon: Icons.arrow_forward_ios_rounded,
                color: AppColors.cBrand600,
                onTap: () => _moveCursor(1),
              ),
              const VerticalDivider(width: 20, indent: 12, endIndent: 12),
              _toolbarAction(
                icon: Icons.keyboard_hide_rounded,
                color: AppColors.cBrand600,
                onTap: () => FocusScope.of(context).unfocus(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarAction({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
    );
  }

  void _moveCursor(int offset) {
    if (_activeController == null) return;
    final newOffset = _activeController!.selection.extentOffset + offset;
    if (newOffset >= 0 && newOffset <= _activeController!.text.length) {
      _activeController!.selection = TextSelection.collapsed(offset: newOffset);
    }
  }

  void _insertTag(String tag) {
    if (_activeController == null) return;
    final selection = _activeController!.selection;
    final text = _activeController!.text;
    final newText = text.replaceRange(selection.start, selection.end, tag);

    _activeController!.value = _activeController!.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + tag.length),
    );

    // 현재 카드 데이터 업데이트
    final card = widget.cards[_currentPageIndex];
    if (_isFrontActive) {
      card.front = newText;
    } else {
      card.back = newText;
    }
  }

  void _handleUndo() {
    if (_activeUndoController == null || _activeController == null) return;
    _activeUndoController!.undo();

    // 현재 카드 데이터 업데이트
    final card = widget.cards[_currentPageIndex];
    if (_isFrontActive) {
      card.front = _activeController!.text;
    } else {
      card.back = _activeController!.text;
    }
  }

  Widget _buildEdgeHandle({required bool isLeft}) {
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 60, // 하단 바 영역과 겹치지 않게 조정
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
