import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';

class CardJumpDialog extends StatefulWidget {
  final List<Flashcard> cards;
  final int currentPageIndex;
  final Function(int) onCardSelected;

  const CardJumpDialog({
    super.key,
    required this.cards,
    required this.currentPageIndex,
    required this.onCardSelected,
  });

  @override
  State<CardJumpDialog> createState() => _CardJumpDialogState();
}

class _CardJumpDialogState extends State<CardJumpDialog> {
  late FixedExtentScrollController _wheelController;
  final TextEditingController _searchController = TextEditingController();

  List<int> _filteredIndices = [];
  double _scrollOffset = 0.0;
  final double _itemExtent = 85.0;

  @override
  void initState() {
    super.initState();
    // 1. 검색용 인덱스 리스트 초기화
    _filteredIndices = List.generate(widget.cards.length, (index) => index);

    // 2. 컨트롤러 설정 (보고 있던 카드로 시작)
    _wheelController = FixedExtentScrollController(
      initialItem: widget.currentPageIndex,
    );

    // 3. [복구] 초기 스크롤 바 위치가 맨 위로 튀지 않도록 현재 위치 저장
    _scrollOffset = widget.currentPageIndex.toDouble();

    _wheelController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_wheelController.hasClients) {
      setState(() {
        _scrollOffset = _wheelController.offset / _itemExtent;
      });
    }
  }

  void _updateScrollPosition(Offset localPosition, double trackHeight) {
    if (_filteredIndices.length <= 1) return;
    final double percentage = (localPosition.dy / trackHeight).clamp(0.0, 1.0);
    final int targetIndex = (percentage * (_filteredIndices.length - 1))
        .round();

    if (_wheelController.hasClients) {
      _wheelController.jumpToItem(targetIndex);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.toLowerCase();
      _filteredIndices = widget.cards
          .asMap()
          .entries
          .where((entry) {
            final card = entry.value;
            return card.front.toLowerCase().contains(q) ||
                card.back.toLowerCase().contains(q) ||
                card.key.toLowerCase().contains(q);
          })
          .map((entry) => entry.key)
          .toList();

      if (_wheelController.hasClients && _filteredIndices.isNotEmpty) {
        _wheelController.jumpToItem(0);
      }
    });
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
                ? AppColors.cDarkSurface.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.5),
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
                        _filteredIndices.isEmpty
                            ? Center(child: Text("no_search_results".tr()))
                            : ListWheelScrollView.useDelegate(
                                controller: _wheelController,
                                itemExtent: _itemExtent,
                                physics: const FixedExtentScrollPhysics(),
                                diameterRatio: 2.5,
                                onSelectedItemChanged: (_) =>
                                    HapticFeedback.selectionClick(),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: _filteredIndices.length,
                                  builder: (context, index) => _buildCardItem(
                                    widget.cards[_filteredIndices[index]],
                                    _filteredIndices[index],
                                    index,
                                    isDark,
                                  ),
                                ),
                              ),
                        if (_filteredIndices.length > 1)
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

  Widget _buildCurveIndicator(bool isDark, double trackHeight) {
    if (_filteredIndices.isEmpty) return const SizedBox.shrink();

    final int totalItems = _filteredIndices.length;
    final double progress = totalItems > 1
        ? (_scrollOffset / (totalItems - 1)).clamp(0.0, 1.0)
        : 0.0;

    return CustomPaint(
      size: Size(50, trackHeight),
      painter: HighlightTrackPainter(
        progress: progress,
        angleRange: math.pi / 2,
        radius: trackHeight * 0.2,
        yRange: trackHeight / 1.7,
        baseColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: AppColors.cBrand600,
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
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.cSlate100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
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
    return AnimatedBuilder(
      animation: _wheelController,
      builder: (context, child) {
        double offset = _wheelController.hasClients
            ? (_wheelController.selectedItem - index).abs().toDouble()
            : (widget.currentPageIndex - index).abs().toDouble();

        return Transform.scale(
          scale: math.max(0.85, 1.0 - (offset * 0.05)),
          child: Opacity(
            opacity: math.max(0.4, 1.0 - (offset * 0.2)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onCardSelected(originalIndex);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // 플래그된 카드는 요청하신 배경색 적용
              color: card.isFlagged
                  ? const Color(0xFF4D4000)
                  : (isDark ? AppColors.cSlate900 : AppColors.cSlate50),
              border: Border.all(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
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
                    Flexible(
                      child: Text(
                        card.key.isEmpty ? "" : card.key,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 플래그 아이콘 위치를 다시 이전처럼 텍스트 바로 옆으로 복구
                    if (card.isFlagged) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.flag, size: 12, color: Colors.orange),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.front.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '|',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        card.back.replaceAll('\n', ' '),
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
        ..strokeWidth = 5.0,
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
        ..strokeWidth = 7.0,
    );
  }

  @override
  bool shouldRepaint(HighlightTrackPainter old) => old.progress != progress;
}
