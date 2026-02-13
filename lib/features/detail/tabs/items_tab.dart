import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';

class ItemsTab extends StatefulWidget {
  final List<Flashcard> cards;
  final int currentPageIndex;
  final Function(int) onCardSelected;
  final dynamic setInfo;
  final GoogleDriveService? driveService;
  final ScrollController? scrollController;
  final Future<void> Function(List<Flashcard>)? onRefresh;

  const ItemsTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.driveService,
    required this.currentPageIndex,
    required this.onCardSelected,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  late FixedExtentScrollController _wheelController;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _displayItems = [];
  final double _itemExtent = 85.0;
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
    // cards 리스트나 개별 카드의 isCollapsed 상태가 변경되었을 수 있으므로
    // 항상 displayItems를 재계산
    _updateDisplayItems();
  }

  void _scrollListener() {
    if (_wheelController.hasClients) {
      setState(() {});
    }
  }

  int _findDisplayIndex(int originalIdx) {
    if (originalIdx < 0 || originalIdx >= widget.cards.length) return 0;
    final targetCard = widget.cards[originalIdx];
    for (int i = 0; i < _displayItems.length; i++) {
      final item = _displayItems[i];
      if (item is Flashcard && item == targetCard) return i;
      if (item is Map &&
          item['type'] == 'group_header' &&
          item['parent'] == targetCard) {
        return i;
      }
    }
    return 0;
  }

  bool _checkHasChildren(int index) {
    if (index >= widget.cards.length - 1) return false;
    return widget.cards[index + 1].groupDepth > widget.cards[index].groupDepth;
  }

  void _updateDisplayItems() {
    final query = _searchController.text.toLowerCase();
    List<dynamic> result = [];

    if (query.isNotEmpty) {
      for (int i = 0; i < widget.cards.length; i++) {
        final card = widget.cards[i];
        if (card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query) ||
            card.key.toLowerCase().contains(query)) {
          result.add(card);
        }
      }
    } else {
      int? skipDepth;

      for (int i = 0; i < widget.cards.length; i++) {
        final card = widget.cards[i];

        if (skipDepth != null) {
          if (card.groupDepth > skipDepth) continue;
          skipDepth = null;
        }

        final bool isParent = _checkHasChildren(i);

        if (isParent) {
          result.add({
            'type': 'group_header',
            'parent': card,
            'originalIndex': i,
          });

          if (card.isCollapsed) {
            skipDepth = card.groupDepth;
            continue;
          }
        }
        result.add(card);
      }
    }
    setState(() => _displayItems = result);
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
              _buildSearchField(isDark),
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
    final int depth = parent.groupDepth;
    final bool isSelected = _selectedDisplayIndex == index;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (int i = 0; i < depth; i++)
            const SizedBox(
              width: 16,
              child: Center(
                child: Text(
                  '↳',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Material(
              color: (parent.isFlagged
                  ? (isDark ? const Color(0xFF4D4000) : const Color(0xFFFFF9C4))
                  : (isDark ? AppColors.cSlate900 : AppColors.cSlate50)),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () async {
                  // 로컬 UI 업데이트
                  setState(() {
                    parent.isCollapsed = !parent.isCollapsed;
                    _updateDisplayItems();
                  });

                  if (widget.driveService != null) {
                    // [중요] depth와 range가 모두 유효한지 최종 검증
                    // 로드부가 완벽하더라도, 전송 직전에 이 값이 '단일 행'이 아닌지 확인해야 합니다.
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
                          depth: parent.controlGroupDepth, // 컨트롤하는 그룹의 depth
                        );
                      } catch (e) {
                        debugPrint('동기화 실패: $e');
                      }
                    } else {
                      debugPrint(
                        'Warning: 잘못된 그룹 범위 전송 시도 - ${parent.groupStartIndex}:${parent.groupEndIndex}',
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 82.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? AppColors.cBrand600
                          : (isDark
                                ? AppColors.cDarkBorder
                                : AppColors.cSlate300),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        parent.isCollapsed
                            ? Icons.folder_rounded
                            : Icons.folder_open_rounded,
                        color: AppColors.cBrand600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.key,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    parent.front.replaceAll('\n', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '|',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    parent.back.replaceAll('\n', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.cSlate400
                                          : AppColors.cSlate600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(
    Flashcard card,
    int originalIndex,
    int index,
    bool isDark,
  ) {
    final int depth = card.groupDepth;
    final bool isParent = _checkHasChildren(originalIndex);
    final bool isSelected = _selectedDisplayIndex == index;

    // 비활성 상태 버튼 배경색 정의
    final Color idleBtnColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          for (int i = 0; i < depth; i++)
            const SizedBox(
              width: 16,
              child: Center(
                child: Text(
                  '↳',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isParent)
            const SizedBox(
              width: 16,
              child: Center(
                child: Text(
                  '↳',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onCardSelected(originalIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (card.isFlagged
                      ? (isDark
                            ? const Color(0xFF4D4000)
                            : const Color(0xFFFFF9C4))
                      : (isDark ? AppColors.cSlate900 : AppColors.cSlate50)),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.cBrand600
                        : (isDark
                              ? AppColors.cDarkBorder
                              : AppColors.cSlate300),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          Text(
                            '#${originalIndex + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cBrand600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              card.key,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Remark 버튼 (비활성 시에도 배경색 유지)
                          Material(
                            color: card.remark.isNotEmpty
                                ? AppColors.cBrand600.withValues(alpha: 0.1)
                                : idleBtnColor,
                            borderRadius: BorderRadius.circular(8),
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
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.history_edu_rounded,
                                  size: 18,
                                  color: card.remark.isNotEmpty
                                      ? AppColors.cBrand600
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Flag 버튼 (비활성 시에도 배경색 유지)
                          Material(
                            color: card.isFlagged
                                ? Colors.orange.withValues(alpha: 0.1)
                                : idleBtnColor,
                            borderRadius: BorderRadius.circular(8),
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
                                  } catch (e) {
                                    debugPrint('Flag 동기화 실패: $e');
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  card.isFlagged
                                      ? Icons.flag
                                      : Icons.flag_outlined,
                                  size: 18,
                                  color: card.isFlagged
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.front.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '|',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            card.back.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.cSlate400
                                  : AppColors.cSlate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: "search".tr(),
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: isDark ? AppColors.cSlate800 : AppColors.cSlate100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class HighlightTrackPainter extends CustomPainter {
  final double progress;
  final double angleRange;
  final double radius;
  final double yRange;
  final Color baseColor;
  final Color highlightColor;

  HighlightTrackPainter({
    required this.progress,
    required this.angleRange,
    required this.radius,
    required this.yRange,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width - 8.0;
    final double centerY = size.height / 2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    for (double p = 0.0; p <= 1.0; p += 0.01) {
      final double angle = (p - 0.5) * angleRange;
      final double x = (1 - math.cos(angle)) * radius;
      final double y = math.sin(angle) * yRange + centerY;
      p == 0.0 ? path.moveTo(centerX - x, y) : path.lineTo(centerX - x, y);
    }
    canvas.drawPath(
      path,
      paint
        ..color = baseColor
        ..strokeWidth = 4.0,
    );

    final Path highlight = Path();
    final double hStart = (progress - 0.04).clamp(0.0, 1.0);
    final double hEnd = (progress + 0.04).clamp(0.0, 1.0);
    for (double p = hStart; p <= hEnd; p += 0.01) {
      final double angle = (p - 0.5) * angleRange;
      final double x = (1 - math.cos(angle)) * radius;
      final double y = math.sin(angle) * yRange + centerY;
      p == hStart
          ? highlight.moveTo(centerX - x, y)
          : highlight.lineTo(centerX - x, y);
    }
    canvas.drawPath(
      highlight,
      paint
        ..color = highlightColor
        ..strokeWidth = 6.0,
    );
  }

  @override
  bool shouldRepaint(HighlightTrackPainter old) => old.progress != progress;
}
