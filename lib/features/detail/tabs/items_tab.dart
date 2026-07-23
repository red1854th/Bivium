import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/features/detail/edit_card_page.dart';
import 'package:bivium/widgets/card_list_common.dart';
import 'package:bivium/features/detail/widgets/items_tab_list_view.dart';
import 'package:bivium/features/detail/remark_setting_page.dart';
import 'package:easy_localization/easy_localization.dart';

// ItemsTabMode enum removed

class ItemsTab extends StatefulWidget {
  final List<Flashcard> cards;
  final int currentPageIndex;
  final Function(int) onCardSelected;
  final Function(List<Flashcard>, int)? onCardsUpdated;
  final VoidCallback? onSetUpdated;
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
    this.onSetUpdated,
  });

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  late FixedExtentScrollController _wheelController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchPinned = true;
  bool _isCompact = false;
  // ItemsTabMode _mode removed

  // --- 조합 필터 상태 ---
  bool _filterFlaggedOnly = false;
  bool _filterWithRemarkOnly = false;
  bool _filterWithoutRemarkOnly = false;

  List<dynamic> _displayItems = [];
  double get _itemExtent => _isCompact ? 44.0 : 95.0;
  int _selectedDisplayIndex = 0;
  int _currentCardIndex = 0;
  int _exceptionIndex = 0;
  String? _editingCellId; // "idx_field"

  @override
  void initState() {
    super.initState();

    final searchMgr = SearchManager();
    _isSearchPinned = true;
    if (searchMgr.query.isNotEmpty) {
      _searchController.text = searchMgr.query;
    }

    searchMgr.addListener(_onSearchManagerChanged);

    _isCompact = CompactModeManager().isCompact;
    CompactModeManager().addListener(_onCompactModeChanged);

    _updateDisplayItems();

    int initialIdx = _findDisplayIndex(widget.currentPageIndex);
    _currentCardIndex = widget.currentPageIndex;
    _exceptionIndex = widget.currentPageIndex;
    _selectedDisplayIndex = initialIdx;
    _wheelController = FixedExtentScrollController(initialItem: initialIdx);

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
  void didUpdateWidget(ItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDisplayItems();

    // 부모로부터 인덱스가 직접적으로 변경된 경우 (예: 통계 탭 점프)
    if (widget.currentPageIndex != oldWidget.currentPageIndex) {
      // 외부에서 점프를 요청한 경우에만 예외 인덱스 갱신 (스크롤로 인한 변경은 무시하여 리스트 안정성 유지)
      if (widget.currentPageIndex != _currentCardIndex) {
        _exceptionIndex = widget.currentPageIndex;
        _currentCardIndex = widget.currentPageIndex;
        _navigateToCard(widget.currentPageIndex);
      }
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
        // targetIndex가 명시되면(예: 편집후 리턴) 그것을 사용, 아니면 안정된 예외 인덱스 사용
        currentTargetIndex: targetIndex ?? _exceptionIndex,
        filterFlaggedOnly: _filterFlaggedOnly,
        filterWithRemarkOnly: _filterWithRemarkOnly,
        filterWithoutRemarkOnly: _filterWithoutRemarkOnly,
      );
    });
  }

  void _onSearchChanged(String query) {
    SearchManager().update(query, true);
    _updateDisplayItems();
    if (_wheelController.hasClients && _displayItems.isNotEmpty) {
      _wheelController.jumpToItem(0);
    }
  }

  /// 필터 토글
  void _toggleFilterFlagged() {
    setState(() {
      _filterFlaggedOnly = !_filterFlaggedOnly;
      if (_filterFlaggedOnly) {
        _filterWithRemarkOnly = false;
        _filterWithoutRemarkOnly = false;
      }
    });
    _updateDisplayItems();
  }

  void _toggleFilterWithRemark() {
    setState(() {
      _filterWithRemarkOnly = !_filterWithRemarkOnly;
      if (_filterWithRemarkOnly) {
        _filterFlaggedOnly = false;
        _filterWithoutRemarkOnly = false;
      }
    });
    _updateDisplayItems();
  }

  void _toggleFilterWithoutRemark() {
    setState(() {
      _filterWithoutRemarkOnly = !_filterWithoutRemarkOnly;
      if (_filterWithoutRemarkOnly) {
        _filterFlaggedOnly = false;
        _filterWithRemarkOnly = false;
      }
    });
    _updateDisplayItems();
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
                isPinned: true,
                onPinToggled: () {},
                showPin: false,
                showCompactToggle: true,
                additionalActions: [
                  const SizedBox(width: 8),
                  // Flag 필터 버튼
                  _buildFilterButton(
                    isDark: isDark,
                    isActive: _filterFlaggedOnly,
                    icon: Icons.flag_rounded,
                    tooltip: "filter_flagged".tr(),
                    onTap: _toggleFilterFlagged,
                  ),
                  const SizedBox(width: 8),
                  // Remark 있음 필터 버튼
                  _buildFilterButton(
                    isDark: isDark,
                    isActive: _filterWithRemarkOnly,
                    icon: Icons.history_edu_rounded,
                    tooltip: "filter_with_remark".tr(),
                    onTap: _toggleFilterWithRemark,
                  ),
                  const SizedBox(width: 8),
                  // Remark 없음 필터 버튼
                  _buildFilterButton(
                    isDark: isDark,
                    isActive: _filterWithoutRemarkOnly,
                    icon: Icons.history_edu_outlined,
                    tooltip: "filter_without_remark".tr(),
                    onTap: _toggleFilterWithoutRemark,
                  ),
                ],
              ),
              Expanded(
                child: ItemsTabListView(
                  displayItems: _displayItems,
                  allCards: widget.cards,
                  scrollController: _wheelController,
                  selectedDisplayIndex: _selectedDisplayIndex,
                  isCompact: _isCompact,
                  isDark: isDark,
                  itemExtent: _itemExtent,
                  editingCellId: _editingCellId,
                  onStartEditing: (id) => setState(() => _editingCellId = id),
                  onUpdateCell: _updateCell,
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedDisplayIndex = index);
                    HapticFeedback.selectionClick();
                    final item = _displayItems[index];
                    if (item is Flashcard) {
                      final idx = widget.cards.indexOf(item);
                      _currentCardIndex = idx;
                      widget.onCardSelected(idx);
                    }
                  },
                  buildCardItem: _buildCardItem,
                  buildFolderHeader: _buildFolderHeader,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required bool isDark,
    required bool isActive,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive
          ? AppColors.cBrand600.withValues(alpha: 0.15)
          : (isDark ? AppColors.cSlate800 : AppColors.cSlate100),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: AppColors.cBrand600, width: 1.5)
                : null,
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? AppColors.cBrand600
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFolderHeader(
    Flashcard parent,
    int index,
    bool isDark,
    String? editingCellId,
    Function(String?) onStartEditing,
    Function(Flashcard, int, String, String) onUpdateCell,
  ) {
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
      isSimple: CompactModeManager().isSimple(widget.setInfo.keyColIdx),
      editingCellId: editingCellId,
      onTap: () => _goToEditPage(originalIdx), // 바디 클릭: 편집기로 이동
      actions: [
        // Remark 버튼
        Material(
          color: parent.remark.isNotEmpty
              ? AppColors.cBrand600.withValues(alpha: 0.12)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () async {
              if (widget.setInfo.remarkColIdx == -1) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RemarkSettingPage(
                      service: widget.driveService!,
                      spreadsheetId: widget.setInfo.sheetId,
                      onConfirm: (idx) {
                        setState(() {
                          widget.setInfo.remarkColIdx = idx;
                        });
                        widget.onSetUpdated?.call();
                      },
                    ),
                  ),
                );
                if (widget.setInfo.remarkColIdx == -1) return;
              }
              if (!mounted) return;

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RemarkPage(
                    service: widget.driveService!,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIdx,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: parent.remark,
                    frontText: parent.front,
                    backText: parent.back,
                    cardKey: parent.key,
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
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.history_edu_rounded,
                size: 18,
                color: parent.remark.isNotEmpty
                    ? AppColors.cBrand600
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Flag 버튼
        Material(
          color: parent.isFlagged
              ? Colors.orange.withValues(alpha: 0.12)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(4),
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
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                parent.isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                size: 18,
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
      onStartEditing: onStartEditing,
      onUpdateCell: onUpdateCell,
    );
  }

  Widget _buildCardItem(
    Flashcard card,
    int originalIndex,
    int index,
    bool isDark,
    String? editingCellId,
    Function(String?) onStartEditing,
    Function(Flashcard, int, String, String) onUpdateCell,
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
      isSimple: CompactModeManager().isSimple(widget.setInfo.keyColIdx),
      editingCellId: editingCellId,
      onStartEditing: onStartEditing,
      onUpdateCell: onUpdateCell,
      onTap: () => _goToEditPage(originalIndex),
      actions: [
        // Remark 버튼
        Material(
          color: card.remark.isNotEmpty
              ? AppColors.cBrand600.withValues(alpha: 0.12)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () async {
              if (widget.setInfo.remarkColIdx == -1) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RemarkSettingPage(
                      service: widget.driveService!,
                      spreadsheetId: widget.setInfo.sheetId,
                      onConfirm: (idx) {
                        setState(() {
                          widget.setInfo.remarkColIdx = idx;
                        });
                        widget.onSetUpdated?.call();
                      },
                    ),
                  ),
                );
                if (widget.setInfo.remarkColIdx == -1) return;
              }
              if (!mounted) return;

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RemarkPage(
                    service: widget.driveService!,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIndex,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: card.remark,
                    frontText: card.front,
                    backText: card.back,
                    cardKey: card.key,
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
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.history_edu_rounded,
                size: 18,
                color: card.remark.isNotEmpty
                    ? AppColors.cBrand600
                    : (isDark ? Colors.white38 : Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Flag 버튼
        Material(
          color: card.isFlagged
              ? Colors.orange.withValues(alpha: 0.12)
              : idleBtnColor,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () async {
              card.isFlagged = !card.isFlagged;
              setState(() {});

              if (widget.driveService != null) {
                try {
                  await widget.driveService!.updateFlashcard(
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: originalIndex,
                    setInfo: widget.setInfo,
                    card: card,
                  );
                  widget.onCardsUpdated?.call(widget.cards, originalIndex);
                } catch (e) {
                  debugPrint('Flag 동기화 실패: $e');
                }
              }
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                card.isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                size: 18,
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
          onSetUpdated: widget.onSetUpdated,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result['cards'] != null && result['lastIndex'] != null) {
      final List<Flashcard> updatedCards = List<Flashcard>.from(
        result['cards'],
      );
      final int lastIdx = result['lastIndex'];
      _currentCardIndex = lastIdx;
      _exceptionIndex = lastIdx;

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

  // Unused methods removed

  void _updateCell(
    Flashcard card,
    int originalIdx,
    String field,
    String newValue,
  ) async {
    if (field == 'front' && card.front == newValue) return;
    if (field == 'back' && card.back == newValue) return;
    if (field == 'remark' && card.remark == newValue) return;
    if (field == 'key' && card.key == newValue) return;

    setState(() {
      if (field == 'front') {
        card.front = newValue;
      } else if (field == 'back') {
        card.back = newValue;
      } else if (field == 'remark') {
        card.remark = newValue;
      } else if (field == 'key') {
        card.key = newValue;
      }
    });

    if (widget.driveService != null) {
      try {
        await widget.driveService!.updateFlashcard(
          spreadsheetId: widget.setInfo.sheetId,
          cardIndex: originalIdx,
          setInfo: widget.setInfo,
          card: card,
        );
        widget.onCardsUpdated?.call(widget.cards, originalIdx);
      } catch (e) {
        debugPrint('셀 업데이트 실패: $e');
      }
    }
  }
}
