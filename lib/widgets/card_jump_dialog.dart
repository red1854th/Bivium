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

  List<dynamic> _displayItems = [];
  double _scrollOffset = 0.0;
  final double _itemExtent = 95.0;
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

    _updateDisplayItems();

    int initialIdx = _findDisplayIndex(widget.currentPageIndex);
    _wheelController = FixedExtentScrollController(initialItem: initialIdx);
    _scrollOffset = initialIdx.toDouble();
    _selectedDisplayIndex = initialIdx;
    _wheelController.addListener(_scrollListener);
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
        _scrollOffset = _wheelController.offset / _itemExtent;
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
    final double percentage = (localPosition.dy / trackHeight).clamp(0.0, 1.0);
    final int targetIndex = (percentage * (_displayItems.length - 1)).round();

    if (_wheelController.hasClients) {
      _wheelController.jumpToItem(targetIndex);
    }
  }

  @override
  void dispose() {
    SearchManager().removeListener(_onSearchManagerChanged);
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
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        _displayItems.isEmpty
                            ? Center(child: Text("no_search_results".tr()))
                            : ListWheelScrollView.useDelegate(
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
    final double progress = _displayItems.length > 1
        ? (_scrollOffset / (_displayItems.length - 1)).clamp(0.0, 1.0)
        : 0.0;
    return CustomPaint(
      size: Size(40, trackHeight),
      painter: HighlightTrackPainter(
        progress: progress,
        angleRange: math.pi / 2.2,
        radius: trackHeight * 0.25,
        yRange: trackHeight / 1.8,
        baseColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: AppColors.cBrand600,
      ),
    );
  }
}
