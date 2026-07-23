import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/core/responsive.dart';
import 'package:bivium/core/keyboard_shortcuts.dart';
import 'card_editor.dart';
import 'package:bivium/widgets/card_jump_dialog.dart';
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';
import 'package:bivium/features/editor/text_editor.dart';
import 'package:bivium/models/toolbar_item.dart';
import 'package:bivium/features/detail/toolbar_customize_page.dart';
import 'dart:ui' as ui;
import 'package:bivium/widgets/card_list_common.dart';

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
  bool _isEditorSettingsOpen = false;
  bool _isVertical = false;

  // Drawing Mode Setup
  bool _isDrawingMode = false;
  final Map<int, List<DrawingPath>> _paths = {};
  DrawingPath? _currentPath;
  Color _selectedColor = Colors.red;

  EditorSettings _settings = EditorSettings(
    fontSize: 19.0,
    lineHeight: 1.4,
    fontFamily: 'Pretendard',
  );

  ZebraHighlightController? _activeController;
  UndoHistoryController? _activeUndoController;
  bool _isFrontActive = true;

  // 커스텀 툴바 아이템
  List<ToolbarItem> _toolbarItems = [
    ToolbarItem(type: ToolbarItemType.undo),
    ToolbarItem(type: ToolbarItemType.redo),
    ToolbarItem(type: ToolbarItemType.insertCheckbox),
    ToolbarItem(type: ToolbarItemType.moveLeft),
    ToolbarItem(type: ToolbarItemType.moveRight),
    ToolbarItem(type: ToolbarItemType.hideKeyboard),
  ];
  // 툴바 스와이프 페이지 컨트롤러
  late PageController _toolbarPageController;
  static const int _toolbarPageSize = 10; // 버튼 넉넉히 들어가게 수정

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialCardIndex.clamp(
      0,
      widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
    _toolbarPageController = PageController();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    // 저장된 툴바 설정 불러오기
    List<ToolbarItem> loadedItems = [];
    final savedJson = prefs.getString('toolbar_items');
    if (savedJson != null) {
      try {
        final List decoded = jsonDecode(savedJson);
        loadedItems = decoded
            .map((e) => ToolbarItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        // 새로 추가된 타입이 있으면 끝에 붙이기
        final existingTypes = loadedItems.map((e) => e.type).toSet();
        for (final type in ToolbarItemType.values) {
          if (!existingTypes.contains(type)) {
            loadedItems.add(ToolbarItem(type: type));
          }
        }
      } catch (_) {
        loadedItems = [];
      }
    }
    setState(() {
      _isVertical = prefs.getBool('is_editor_vertical') ?? false;
      _settings = EditorSettings(
        fontSize: prefs.getDouble('editor_font_size') ?? 19.0,
        lineHeight: prefs.getDouble('editor_line_height') ?? 1.4,
        fontFamily: prefs.getString('editor_font_family') ?? 'Pretendard',
      );
      if (loadedItems.isNotEmpty) {
        _toolbarItems = loadedItems;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _toolbarPageController.dispose();
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

  void _openToolbarCustomize() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolbarCustomizePage(
          items: _toolbarItems,
          onSave: (items) async {
            setState(() => _toolbarItems = items);
            final prefs = await SharedPreferences.getInstance();
            final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
            await prefs.setString('toolbar_items', encoded);
          },
        ),
      ),
    );
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
    final bool isDesktop = Responsive.isDesktop(context);

    return BiviumShortcuts(
      bindings: {
        AppShortcuts.save: () => _saveChanges(_currentPageIndex),
        AppShortcuts.nextCard: () {
          if (_currentPageIndex < widget.cards.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        AppShortcuts.prevCard: () {
          if (_currentPageIndex > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        AppShortcuts.search: () =>
            SearchManager().showSearchDialog(context, widget.cards, (idx) {
              if (idx != -1) _pageController.jumpToPage(idx);
            }),
        AppShortcuts.toggleFlag: () {
          setState(() {
            widget.cards[_currentPageIndex].isFlagged =
                !widget.cards[_currentPageIndex].isFlagged;
          });
          _saveChanges(_currentPageIndex);
        },
        AppShortcuts.jumpTo: _showCardJumpDialog,
        AppShortcuts.close: _handlePop,
      },
      child: PopScope(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_currentPageIndex + 1}/${widget.cards.length}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: isDark
                            ? AppColors.cSlate200
                            : AppColors.cSlate800,
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
                              (isDark
                                      ? AppColors.cSlate200
                                      : AppColors.cSlate800)
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
                  _isDrawingMode ? Icons.draw : Icons.draw_outlined,
                  color: _isDrawingMode ? AppColors.cBrand600 : null,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _isDrawingMode = !_isDrawingMode),
                tooltip: "drawing_mode".tr(),
              ),
              const SizedBox(width: 8),
            ],
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop) _buildSidePanel(isDark),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              scrollDirection: Axis.horizontal,
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
                                        ? (_pageController.page ??
                                              index.toDouble())
                                        : index.toDouble();
                                    double angle =
                                        (page - index) * (math.pi / 35);
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
                                        onToolbarCustomize:
                                            _openToolbarCustomize,
                                        onFocusChanged:
                                            ({
                                              controller,
                                              undoController,
                                              required isFront,
                                            }) {
                                              setState(() {
                                                _activeController = controller;
                                                _activeUndoController =
                                                    undoController;
                                                _isFrontActive = isFront;
                                              });
                                            },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            // Drawing Canvas Overlay
                            if (_isDrawingMode)
                              Positioned.fill(
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    setState(() {
                                      _currentPath = DrawingPath(
                                        points: [details.localPosition],
                                        color: _selectedColor,
                                      );
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    if (_currentPath != null) {
                                      setState(() {
                                        _currentPath!.points.add(
                                          details.localPosition,
                                        );
                                      });
                                    }
                                  },
                                  onPanEnd: (details) {
                                    if (_currentPath != null) {
                                      setState(() {
                                        _paths
                                            .putIfAbsent(
                                              _currentPageIndex,
                                              () => [],
                                            )
                                            .add(_currentPath!);
                                        _currentPath = null;
                                      });
                                    }
                                  },
                                  child: CustomPaint(
                                    painter: ScreenPainter(
                                      paths: _paths[_currentPageIndex] ?? [],
                                      currentPath: _currentPath,
                                    ),
                                  ),
                                ),
                              ),
                            // Drawing Toolbar
                            if (_isDrawingMode)
                              Positioned(
                                top: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.cDarkSurface
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ...[
                                        Colors.red,
                                        Colors.blue,
                                        Colors.green,
                                        Colors.orange,
                                        AppColors.cSlate800,
                                      ].map(
                                        (c) => GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedColor = c,
                                          ),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _selectedColor == c
                                                    ? AppColors.cBrand600
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                          () => _paths[_currentPageIndex]
                                              ?.clear(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!_isEditorSettingsOpen &&
                                !_isDrawingMode &&
                                !isDesktop) ...[
                              _buildEdgeHandle(isLeft: true),
                              _buildEdgeHandle(isLeft: false),
                            ],
                            if (_isEditorSettingsOpen)
                              Positioned.fill(
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _isEditorSettingsOpen = false,
                                  ),
                                  child: Container(color: Colors.black45),
                                ),
                              ),
                            EditorSettingsPanel(
                              isVisible: _isEditorSettingsOpen,
                              currentSettings: _settings,
                              card: widget.cards[_currentPageIndex],
                              cardIndex: _currentPageIndex,
                              onSettingsChanged: (s) =>
                                  setState(() => _settings = s),
                              onToolbarCustomize:
                                  _openToolbarCustomize, // 콜백 전달
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(bool isDark) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cDarkBg : AppColors.cBg,
        border: Border(
          right: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.list, size: 20),
                const SizedBox(width: 8),
                Text(
                  "items_tab".tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.cards.length,
              itemExtent: 44,
              itemBuilder: (context, index) {
                final card = widget.cards[index];
                final isSelected = index == _currentPageIndex;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.cBrand600.withValues(alpha: 0.1),
                  leading: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  title: Text(
                    card.key.isNotEmpty ? card.key : card.front,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: card.isFlagged
                      ? const Icon(Icons.flag, size: 14, color: Colors.orange)
                      : null,
                  onTap: () => _pageController.jumpToPage(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 각 ToolbarItem 타입에 맞는 아이콘/색상/액션 반환
  Widget _buildToolbarButton(ToolbarItem item, bool isDark) {
    Color color;
    VoidCallback? onTap;
    switch (item.type) {
      case ToolbarItemType.undo:
        final canUndo = _activeUndoController?.value.canUndo == true;
        color = canUndo
            ? AppColors.cBrand600
            : Colors.grey.withValues(alpha: 0.5);
        onTap = canUndo ? _handleUndo : null;
        break;
      case ToolbarItemType.redo:
        final canRedo = _activeUndoController?.value.canRedo == true;
        color = canRedo
            ? AppColors.cBrand600
            : Colors.grey.withValues(alpha: 0.5);
        onTap = canRedo ? () => _activeUndoController?.redo() : null;
        break;
      case ToolbarItemType.insertCheckbox:
        color = AppColors.cBrand600;
        onTap = () => _insertTag('[ ]');
        break;
      case ToolbarItemType.moveLeft:
        color = AppColors.cBrand600;
        onTap = () => _moveCursor(-1);
        break;
      case ToolbarItemType.moveRight:
        color = AppColors.cBrand600;
        onTap = () => _moveCursor(1);
        break;
      case ToolbarItemType.hideKeyboard:
        color = AppColors.cBrand600;
        onTap = () => FocusScope.of(context).unfocus();
        break;
    }
    return _toolbarAction(icon: item.icon, color: color, onTap: onTap);
  }

  Widget _buildFixedBottomToolbar(bool isDark) {
    final visibleItems = _toolbarItems.where((e) => e.isVisible).toList();
    final totalPages = (visibleItems.length / _toolbarPageSize).ceil().clamp(
      1,
      99,
    );

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
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _toolbarPageController,
                physics: const BouncingScrollPhysics(),
                itemCount: totalPages,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * _toolbarPageSize;
                  final end = (start + _toolbarPageSize).clamp(
                    0,
                    visibleItems.length,
                  );
                  final pageItems = visibleItems.sublist(start, end);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ...pageItems.map(
                        (item) => _buildToolbarButton(item, isDark),
                      ),
                      const Spacer(),
                      // if (totalPages > 1) SizedBox(width: 48), // 페이지 인디케이터 공간
                    ],
                  );
                },
              ),
              // 스와이프 페이지 인디케이터 제거 (걸리적거린다는 요청 반영)
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

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingPath({required this.points, required this.color, this.width = 3.0});
}

class ScreenPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final DrawingPath? currentPath;

  ScreenPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final path in paths) {
      paint.color = path.color;
      paint.strokeWidth = path.width;
      paint.style = PaintingStyle.stroke;
      if (path.points.length > 1) {
        final ui.Path drawPath = ui.Path();
        drawPath.moveTo(path.points[0].dx, path.points[0].dy);
        for (int i = 1; i < path.points.length; i++) {
          drawPath.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(drawPath, paint);
      } else if (path.points.length == 1) {
        canvas.drawCircle(
          path.points[0],
          path.width / 2,
          paint..style = PaintingStyle.fill,
        );
      }
    }

    if (currentPath != null && currentPath!.points.length > 1) {
      paint.color = currentPath!.color;
      paint.strokeWidth = currentPath!.width;
      paint.style = PaintingStyle.stroke;
      final ui.Path drawPath = ui.Path();
      drawPath.moveTo(currentPath!.points[0].dx, currentPath!.points[0].dy);
      for (int i = 1; i < currentPath!.points.length; i++) {
        drawPath.lineTo(currentPath!.points[i].dx, currentPath!.points[i].dy);
      }
      canvas.drawPath(drawPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
