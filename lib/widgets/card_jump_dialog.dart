import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/widgets/card_list_common.dart';

class CardJumpDialog extends StatefulWidget {
  final List<Flashcard> cards;
  final int currentPageIndex;
  final Function(int) onCardSelected;
  final dynamic setInfo;
  final GoogleDriveService? driveService;

  const CardJumpDialog({
    super.key,
    required this.cards,
    required this.currentPageIndex,
    required this.onCardSelected,
    required this.setInfo,
    required this.driveService,
  });

  @override
  State<CardJumpDialog> createState() => _CardJumpDialogState();
}

class _CardJumpDialogState extends State<CardJumpDialog> {
  late FixedExtentScrollController _wheelController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchPinned = false;
  bool _isCompact = false;

  List<dynamic> _displayItems = [];
  double _scrollOffset = 0.0;
  double get _itemExtent => _isCompact ? 44.0 : 95.0;
  int _selectedDisplayIndex = 0;
  bool _hasChanges = false; // 폴더 접기/펼치기 변경사항 추적

  @override
  void initState() {
    super.initState();

    final searchMgr = SearchManager();
    _isSearchPinned = searchMgr.isPinned;
    if (_isSearchPinned) {
      _searchController.text = searchMgr.query;
    }
    searchMgr.addListener(_onSearchManagerChanged);

    _isCompact = CompactModeManager().isCompact;
    CompactModeManager().addListener(_onCompactModeChanged);

    _updateDisplayItems();

    int initialIdx = _findDisplayIndex(widget.currentPageIndex);
    _wheelController = FixedExtentScrollController(initialItem: initialIdx);

    // 비율로 초기화 (0.0 ~ 1.0)
    if (_displayItems.length > 1) {
      _scrollOffset = initialIdx / (_displayItems.length - 1);
    } else {
      _scrollOffset = 0.0;
    }

    _selectedDisplayIndex = initialIdx;
    _wheelController.addListener(_scrollListener);

    // 처음 열릴 때 Painter가 즉시 그려지도록 강제 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollListener();
      }
    });
  }

  void _onSearchManagerChanged() {
    final searchMgr = SearchManager();
    if (searchMgr.isPinned && _searchController.text != searchMgr.query) {
      setState(() {
        _isSearchPinned = searchMgr.isPinned;
        _searchController.text = searchMgr.query;
      });
      _updateDisplayItems();
    } else if (_isSearchPinned != searchMgr.isPinned) {
      setState(() {
        _isSearchPinned = searchMgr.isPinned;
      });
    }
  }

  void _scrollListener() {
    if (_wheelController.hasClients) {
      setState(() {
        // 단순히 offset / itemExtent를 하면 소수점이 발생하여
        // 마지막 아이템에서 정확히 1.0(100%)에 도달하지 못할 수 있습니다.
        // 실제 최대 스크롤 가능 범위로 나누어 비율을 구합니다.
        double maxScroll = (_displayItems.length - 1) * _itemExtent;
        if (maxScroll <= 0) {
          _scrollOffset = 0.0;
        } else {
          _scrollOffset = (_wheelController.offset / maxScroll).clamp(0.0, 1.0);
        }
      });
    }
  }

  int _findDisplayIndex(int originalIdx) {
    return CardListUtils.findDisplayIndex(
      originalIdx: originalIdx,
      displayItems: _displayItems,
      allCards: widget.cards,
    );
  }

  bool _checkHasChildren(int index) {
    return CardListUtils.checkHasChildren(index, widget.cards);
  }

  void _updateDisplayItems() {
    setState(() {
      _displayItems = CardListUtils.getDisplayItems(
        allCards: widget.cards,
        searchQuery: _searchController.text,
        currentTargetIndex: widget.currentPageIndex,
      );
    });
  }

  void _onSearchChanged(String query) {
    if (_isSearchPinned) {
      SearchManager().update(query, true);
    }
    _updateDisplayItems();
    if (_wheelController.hasClients && _displayItems.isNotEmpty) {
      _wheelController.jumpToItem(0);
    }
  }

  void _onPinToggled() {
    setState(() {
      _isSearchPinned = !_isSearchPinned;
      SearchManager().update(_searchController.text, _isSearchPinned);
    });
  }

  void _updateScrollPosition(Offset localPosition, double trackHeight) {
    if (_displayItems.length <= 1) return;
    final double activeRange = trackHeight / 1.3;
    final double center = trackHeight / 2;

    double relativeDy = localPosition.dy - (center - activeRange / 2);
    final double percentage = (relativeDy / activeRange).clamp(0.0, 1.0);
    final int targetIndex = (percentage * (_displayItems.length - 1)).round();

    if (_wheelController.hasClients) {
      _wheelController.jumpToItem(targetIndex);
    }
  }

  void _onCompactModeChanged() {
    final compact = CompactModeManager().isCompact;
    if (_isCompact != compact) {
      final currentIdx = _wheelController.hasClients
          ? _wheelController.selectedItem
          : _selectedDisplayIndex;

      final oldController = _wheelController;
      _wheelController = FixedExtentScrollController(initialItem: currentIdx);
      _wheelController.addListener(_scrollListener);

      setState(() {
        _isCompact = compact;
        _selectedDisplayIndex = currentIdx;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_wheelController.hasClients) {
          _wheelController.jumpToItem(currentIdx);
        }
        oldController.removeListener(_scrollListener);
        oldController.dispose();
      });
    }
  }

  @override
  void dispose() {
    SearchManager().removeListener(_onSearchManagerChanged);
    CompactModeManager().removeListener(_onCompactModeChanged);
    _wheelController.removeListener(_scrollListener);
    _wheelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cDarkSurface.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              CardSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                isDark: isDark,
                isPinned: _isSearchPinned,
                onPinToggled: _onPinToggled,
                showCompactToggle: true,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        _displayItems.isEmpty
                            ? Center(child: Text("no_search_results".tr()))
                            : ListWheelScrollView.useDelegate(
                                key: ValueKey(_isCompact),
                                controller: _wheelController,
                                itemExtent: _itemExtent,
                                physics: const FixedExtentScrollPhysics(),
                                diameterRatio: 2.5,
                                onSelectedItemChanged: (index) {
                                  setState(() => _selectedDisplayIndex = index);
                                  HapticFeedback.selectionClick();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: _displayItems.length,
                                  builder: (context, index) {
                                    final item = _displayItems[index];

                                    if (item is Map &&
                                        item['type'] == 'group_header') {
                                      return _buildFolderHeader(
                                        item['parent'],
                                        index,
                                        isDark,
                                      );
                                    }

                                    final Flashcard card = item as Flashcard;
                                    final int originalIndex = widget.cards
                                        .indexOf(card);
                                    return _buildCardItem(
                                      card,
                                      originalIndex,
                                      index,
                                      isDark,
                                    );
                                  },
                                ),
                              ),
                        if (_displayItems.length > 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragDown: (details) =>
                                  _updateScrollPosition(
                                    details.localPosition,
                                    constraints.maxHeight,
                                  ),
                              onVerticalDragUpdate: (details) =>
                                  _updateScrollPosition(
                                    details.localPosition,
                                    constraints.maxHeight,
                                  ),
                              child: _buildCurveIndicator(
                                isDark,
                                constraints.maxHeight,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderHeader(Flashcard parent, int index, bool isDark) {
    final int originalIdx = widget.cards.indexOf(parent);
    double offset = _wheelController.hasClients
        ? (_wheelController.selectedItem - index).abs().toDouble()
        : 0.0;

    return FlashcardFolderHeader(
      parent: parent,
      index: index,
      originalIndex: originalIdx,
      isSelected: _selectedDisplayIndex == index,
      isDark: isDark,
      isSimple: CompactModeManager().isSimple(widget.setInfo.keyColIdx),
      scale: math.max(0.85, 1.0 - (offset * 0.05)),
      opacity: math.max(0.4, 1.0 - (offset * 0.2)),
      onTap: () {
        // 바디 클릭: 해당 카드로 이동하며 다이얼로그 닫기
        Navigator.pop(context, _hasChanges);
        widget.onCardSelected(originalIdx);
      },
      onToggle: () async {
        // 아이콘/화살표 클릭: 접기/펼치기 토글
        setState(() {
          parent.isCollapsed = !parent.isCollapsed;
          _updateDisplayItems();
          _hasChanges = true;
        });

        if (widget.driveService != null) {
          bool isValidGroupRange =
              (parent.groupEndIndex - parent.groupStartIndex) > 1;
          if (isValidGroupRange) {
            try {
              await widget.driveService!.updateRowGroupExpansion(
                spreadsheetId: widget.setInfo.sheetId,
                sheetId: widget.setInfo.gid,
                collapse: parent.isCollapsed,
                startIndex: parent.groupStartIndex,
                endIndex: parent.groupEndIndex,
                depth: parent.controlGroupDepth,
              );
            } catch (e) {
              debugPrint('동기화 실패: $e');
            }
          }
        }
      },
    );
  }

  Widget _buildCardItem(
    Flashcard card,
    int originalIndex,
    int index,
    bool isDark,
  ) {
    double offset = _wheelController.hasClients
        ? (_wheelController.selectedItem - index).abs().toDouble()
        : 0.0;

    return FlashcardListItem(
      card: card,
      originalIndex: originalIndex,
      index: index,
      isSelected: _selectedDisplayIndex == index,
      isDark: isDark,
      isParent: _checkHasChildren(originalIndex),
      isSimple: CompactModeManager().isSimple(widget.setInfo.keyColIdx),
      scale: math.max(0.85, 1.0 - (offset * 0.05)),
      opacity: math.max(0.4, 1.0 - (offset * 0.2)),
      onTap: () {
        Navigator.pop(context, _hasChanges);
        widget.onCardSelected(originalIndex);
      },
    );
  }

  Widget _buildCurveIndicator(bool isDark, double trackHeight) {
    if (_displayItems.isEmpty) return const SizedBox.shrink();

    // _scrollListener에서 이미 비율로 계산했으므로 progress에 바로 대입
    final double progress = _scrollOffset;

    return CustomPaint(
      size: Size(40, trackHeight),
      painter: HighlightTrackPainter(
        progress: progress, // 0.0 ~ 1.0
        angleRange: math.pi / 2.2,
        radius: trackHeight * 0.25,
        yRange: trackHeight / 1.8,
        baseColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: AppColors.cBrand600,
      ),
    );
  }
}
