import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/features/detail/edit_card_page.dart';
import 'package:bivium/widgets/card_list_common.dart';

class ItemsTab extends StatefulWidget {
  final List<Flashcard> cards;
  final int currentPageIndex;
  final Function(int) onCardSelected; // 탭 이동 시의 선택 동기화용
  final Function(List<Flashcard>, int)? onCardsUpdated; // 데이터 변경 알림용
  final dynamic setInfo;
  final GoogleDriveService? driveService;

  const ItemsTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.driveService,
    required this.currentPageIndex,
    required this.onCardSelected,
    this.onCardsUpdated,
  });

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  late FixedExtentScrollController _wheelController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _displayItems = [];
  final double _itemExtent = 95.0;
  int _selectedDisplayIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateDisplayItems();

    int initialIdx = _findDisplayIndex(widget.currentPageIndex);
    _selectedDisplayIndex = initialIdx;
    _wheelController = FixedExtentScrollController(initialItem: initialIdx);

    _wheelController.addListener(_scrollListener);
  }

  @override
  void didUpdateWidget(ItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDisplayItems();

    // 부모로부터 인덱스가 직접적으로 변경된 경우 (예: 통계 탭 점프)
    if (widget.currentPageIndex != oldWidget.currentPageIndex) {
      _navigateToCard(widget.currentPageIndex);
    }
  }

  void _navigateToCard(int index) {
    if (_wheelController.hasClients) {
      int displayIdx = _findDisplayIndex(index);
      if (_selectedDisplayIndex != displayIdx) {
        _wheelController.animateToItem(
          displayIdx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
        );
      }
    }
  }

  void _scrollListener() {
    if (_wheelController.hasClients) {
      setState(() {});
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

  void _updateDisplayItems({int? targetIndex}) {
    setState(() {
      _displayItems = CardListUtils.getDisplayItems(
        allCards: widget.cards,
        searchQuery: _searchController.text,
        currentTargetIndex: targetIndex ?? widget.currentPageIndex,
      );
    });
  }

  void _onSearchChanged(String query) {
    _updateDisplayItems();
    if (_wheelController.hasClients && _displayItems.isNotEmpty) {
      _wheelController.jumpToItem(0);
    }
  }

  @override
  void dispose() {
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
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cDarkSurface.withValues(alpha: 0.3)
                : AppColors.cDarkSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              CardSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                isDark: isDark,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (_displayItems.isEmpty) {
                      return Center(child: Text("no_search_results".tr()));
                    }

                    // 점프 및 드래그를 처리하는 공통 로직
                    void handleScroll(double localY) {
                      if (_wheelController.hasClients &&
                          _wheelController.position.hasContentDimensions) {
                        final double trackHeight = constraints.maxHeight - 8;
                        final double adjustedY = (localY - 4).clamp(
                          0.0,
                          trackHeight,
                        );
                        final double scrollPercent = adjustedY / trackHeight;
                        final double targetOffset =
                            scrollPercent *
                            _wheelController.position.maxScrollExtent;

                        _wheelController.position.jumpTo(targetOffset);
                      }
                    }

                    return Stack(
                      children: [
                        // 1. 리스트 뷰 및 순정 스크롤바
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: RawScrollbar(
                            controller: _wheelController,
                            minThumbLength: 40.0,
                            mainAxisMargin: 4.0,
                            thumbColor: AppColors.cBrand600.withValues(
                              alpha: 0.8,
                            ),
                            thickness: 8,
                            radius: const Radius.circular(10),
                            thumbVisibility: true,
                            interactive: true,
                            pressDuration: Duration.zero,
                            child: ListWheelScrollView.useDelegate(
                              controller: _wheelController,
                              itemExtent: _itemExtent,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1000,
                              perspective: 0.000001,
                              overAndUnderCenterOpacity: 1.0,
                              onSelectedItemChanged: (index) {
                                setState(() => _selectedDisplayIndex = index);
                                HapticFeedback.selectionClick();

                                // 현재 선택된 리스트 아이템이 Flashcard인 경우 원본 인덱스 추출하여 부모에 알림
                                final item = _displayItems[index];
                                if (item is Flashcard) {
                                  widget.onCardSelected(
                                    widget.cards.indexOf(item),
                                  );
                                }
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
                                  return _buildCardItem(
                                    card,
                                    widget.cards.indexOf(card),
                                    index,
                                    isDark,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // 2. 통합 터치 레이어 (Jump + Drag 유지)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // 터치 즉시 점프
                            onTapDown: (details) {
                              handleScroll(details.localPosition.dy);
                              HapticFeedback.lightImpact();
                            },
                            // 점프 후 손가락을 떼지 않고 움직일 때 (드래그) 처리
                            onVerticalDragUpdate: (details) {
                              handleScroll(details.localPosition.dy);
                            },
                            child: Container(
                              width: 30, // 터치 인식 범위
                              alignment: Alignment.centerRight,
                              color: Colors.transparent,
                              child: Container(
                                width: 6,
                                margin: const EdgeInsets.only(right: 7),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
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
    final Color idleBtnColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return FlashcardFolderHeader(
      parent: parent,
      index: index,
      originalIndex: originalIdx,
      isSelected: _selectedDisplayIndex == index,
      isDark: isDark,
      onTap: () => _goToEditPage(originalIdx), // 바디 클릭: 편집기로 이동
      actions: [
        // Remark 버튼
        Material(
          color: parent.remark.isNotEmpty
              ? AppColors.cBrand600.withValues(alpha: 0.15)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RemarkPage(
                    service: widget.driveService!,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIdx,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: parent.remark,
                  ),
                ),
              );
              if (result != null && result is String) {
                setState(() {
                  parent.remark = result;
                });
                widget.onCardsUpdated?.call(widget.cards, originalIdx);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.history_edu_rounded,
                size: 20,
                color: parent.remark.isNotEmpty
                    ? AppColors.cBrand600
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Flag 버튼
        Material(
          color: parent.isFlagged
              ? Colors.orange.withValues(alpha: 0.15)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () async {
              setState(() {
                parent.isFlagged = !parent.isFlagged;
              });

              if (widget.driveService != null) {
                try {
                  await widget.driveService!.updateFlashcard(
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIdx,
                    setInfo: widget.setInfo,
                    card: parent,
                  );
                  widget.onCardsUpdated?.call(widget.cards, originalIdx);
                } catch (e) {
                  debugPrint('Flag 동기화 실패: $e');
                }
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                parent.isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                size: 20,
                color: parent.isFlagged
                    ? Colors.orange
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
      ],
      onToggle: () async {
        // 아이콘/화살표 클릭: 접기/펼치기 토글
        setState(() {
          parent.isCollapsed = !parent.isCollapsed;
          _updateDisplayItems();
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
    final Color idleBtnColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return FlashcardListItem(
      card: card,
      originalIndex: originalIndex,
      index: index,
      isSelected: _selectedDisplayIndex == index,
      isDark: isDark,
      isParent: _checkHasChildren(originalIndex),
      onTap: () => _goToEditPage(originalIndex),
      actions: [
        // Remark 버튼
        Material(
          color: card.remark.isNotEmpty
              ? AppColors.cBrand600.withValues(alpha: 0.15)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RemarkPage(
                    service: widget.driveService!,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIndex,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: card.remark,
                  ),
                ),
              );
              if (result != null && result is String) {
                setState(() {
                  card.remark = result;
                });
                // 부모 데이터 동기화
                widget.onCardsUpdated?.call(widget.cards, originalIndex);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.history_edu_rounded,
                size: 20,
                color: card.remark.isNotEmpty
                    ? AppColors.cBrand600
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Flag 버튼
        Material(
          color: card.isFlagged
              ? Colors.orange.withValues(alpha: 0.15)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () async {
              setState(() {
                card.isFlagged = !card.isFlagged;
              });

              if (widget.driveService != null) {
                try {
                  await widget.driveService!.updateFlashcard(
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIndex,
                    setInfo: widget.setInfo,
                    card: card,
                  );
                  // 부모 데이터 동기화
                  widget.onCardsUpdated?.call(widget.cards, originalIndex);
                } catch (e) {
                  debugPrint('Flag 동기화 실패: $e');
                }
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                card.isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                size: 20,
                color: card.isFlagged
                    ? Colors.orange
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _goToEditPage(int index) async {
    if (widget.driveService == null) return;
    FocusScope.of(context).unfocus();

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => EditCardPage(
          cards: widget.cards,
          initialCardIndex: index,
          setInfo: widget.setInfo,
          driveService: widget.driveService!,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result['cards'] != null && result['lastIndex'] != null) {
      final List<Flashcard> updatedCards = List<Flashcard>.from(
        result['cards'],
      );
      final int lastIdx = result['lastIndex'];

      // 데이터 갱신 알림
      widget.onCardsUpdated?.call(updatedCards, lastIdx);

      // 리스트 갱신 (lastIdx가 접힌 폴더 안에 있더라도 보이도록 강제)
      _updateDisplayItems(targetIndex: lastIdx);

      // 리스트 갱신 후 즉시 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_wheelController.hasClients) {
          int displayIdx = _findDisplayIndex(lastIdx);
          _wheelController.jumpToItem(displayIdx);
          setState(() => _selectedDisplayIndex = displayIdx);
        }
      });
    }
  }
}
