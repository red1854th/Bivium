import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/services/google_drive_service.dart';

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

  List<dynamic> _displayItems = [];
  double _scrollOffset = 0.0;
  final double _itemExtent = 85.0;
  int _selectedDisplayIndex = 0;
  bool _hasChanges = false; // 폴더 접기/펼치기 변경사항 추적

  @override
  void initState() {
    super.initState();
    _updateDisplayItems();

    int initialIdx = _findDisplayIndex(widget.currentPageIndex);
    _wheelController = FixedExtentScrollController(initialItem: initialIdx);
    _scrollOffset = initialIdx.toDouble();
    _selectedDisplayIndex = initialIdx;
    _wheelController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_wheelController.hasClients) {
      setState(() {
        _scrollOffset = _wheelController.offset / _itemExtent;
      });
    }
  }

  int _findDisplayIndex(int originalIdx) {
    for (int i = 0; i < _displayItems.length; i++) {
      final item = _displayItems[i];

      // 1. 일반 카드인 경우 비교
      if (item is Flashcard && widget.cards.indexOf(item) == originalIdx) {
        return i;
      }

      // 2. [추가] 가상 헤더(Map)인 경우 내부에 저장된 originalIndex와 비교
      if (item is Map && item['originalIndex'] == originalIdx) {
        return i + 1;
      }
    }
    return 0; // 여전히 못 찾으면 첫 항목으로 보냄
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
      bool skippingMode = false;
      int skipDepth = 0;

      for (int i = 0; i < widget.cards.length; i++) {
        final card = widget.cards[i];
        final bool isParent = _checkHasChildren(i);
        final bool isCurrentTarget = (i == widget.currentPageIndex);

        // 1. 가상 헤더 추가 (폴더 상단 디자인)
        if (isParent) {
          result.add({
            'type': 'group_header',
            'parent': card,
            'originalIndex': i,
          });
        }

        // 2. 스킵 모드 처리
        if (skippingMode) {
          if (isCurrentTarget) {
            result.add(card); // 접혀있어도 현재 보고 있는 카드면 예외 노출
          }

          if (card.groupDepth > skipDepth) continue;
          skippingMode = false;
        }

        // 3. 실제 카드 아이템 추가
        // 부모 카드(폴더)일 경우, 펼쳐져 있을 때만 본체 카드를 헤더 아래에 추가
        if (!isParent || (isParent && !card.isCollapsed)) {
          result.add(card);
        }

        // 4. 스킵 모드 진입 설정
        if (isParent && card.isCollapsed) {
          skippingMode = true;
          skipDepth = card.groupDepth;
        }
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
              _buildSearchField(isDark),
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
    final int depth = parent.groupDepth;
    final bool isSelected = _selectedDisplayIndex == index;

    return AnimatedBuilder(
      animation: _wheelController,
      builder: (context, child) {
        // 현재 선택된 아이템과의 거리에 따른 변형 효과 계산
        double offset = _wheelController.hasClients
            ? (_wheelController.selectedItem - index).abs().toDouble()
            : 0.0;

        return Transform.scale(
          scale: math.max(0.85, 1.0 - (offset * 0.05)),
          child: Opacity(
            opacity: math.max(0.4, 1.0 - (offset * 0.2)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            // 계층 구조 시각화를 위한 ↳ 기호 영역
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
            // 메인 폴더 헤더 디자인
            Expanded(
              child: Material(
                color: (parent.isFlagged
                    ? (isDark
                          ? const Color(0xFF4D4000)
                          : const Color(0xFFFFF9C4))
                    : (isDark ? AppColors.cSlate900 : AppColors.cSlate50)),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    // 로컬 UI 업데이트
                    setState(() {
                      parent.isCollapsed = !parent.isCollapsed;
                      _updateDisplayItems();
                      _hasChanges = true; // 변경사항 기록
                    });

                    if (widget.driveService != null) {
                      // [중요] depth와 range가 모두 유효한지 최종 검증
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
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
                        Icon(
                          parent.isCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.expand_more_rounded,
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

    return AnimatedBuilder(
      animation: _wheelController,
      builder: (context, child) {
        double offset = _wheelController.hasClients
            ? (_wheelController.selectedItem - index).abs().toDouble()
            : 0.0;

        return Transform.scale(
          scale: math.max(0.85, 1.0 - (offset * 0.05)),
          child: Opacity(
            opacity: math.max(0.4, 1.0 - (offset * 0.2)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            // 계층 구조 시각화를 위한 ↳ 기호 영역 (카드용)
            for (int i = 0; i < (isParent ? depth : depth); i++)
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
            // 부모 카드일 경우 추가 들여쓰기 공간에도 ↳ 기호 적용
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
                onTap: () {
                  Navigator.pop(context, _hasChanges); // 변경사항 여부 반환
                  widget.onCardSelected(originalIndex);
                },
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
                        height: 20,
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
                            if (card.remark.isNotEmpty)
                              const Icon(
                                Icons.history_edu_rounded,
                                size: 18,
                                color: AppColors.cBrand600,
                              ),
                            if (card.isFlagged)
                              const Icon(
                                Icons.flag,
                                size: 18,
                                color: Colors.orange,
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
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
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
